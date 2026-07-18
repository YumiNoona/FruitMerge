class_name PowerupController
extends Node2D

const LEVEL_UP := &"powerup_level_up"
const SHAKE_BOX := &"powerup_shake_box"
const REMOVE_SMALLEST := &"powerup_remove_smallest"
const GRAB := &"powerup_grab_em"
const HAMMER := &"powerup_hammer"
const BOMB := &"powerup_bomb"
const CROSSHAIR_TEXTURE := preload("res://Assets/UI/Crosshair.png")
const FruitFactoryScript = preload("res://Scripts/Entities/Fruit/fruit_factory.gd")
const POWERUP_PATHS := {
	LEVEL_UP: "res://Data/ShopItems/powerup_level_up.tres",
	SHAKE_BOX: "res://Data/ShopItems/powerup_shake_box.tres",
	REMOVE_SMALLEST: "res://Data/ShopItems/powerup_remove_smallest.tres",
	GRAB: "res://Data/ShopItems/powerup_grab_em.tres",
	HAMMER: "res://Data/ShopItems/powerup_hammer.tres",
	BOMB: "res://Data/ShopItems/powerup_bomb.tres",
}
const SHAKE_PATH := [
	Vector2(-1.0, 0.08),
	Vector2(1.0, -0.08),
	Vector2(0.0, -0.82),
	Vector2(0.0, 0.78),
	Vector2(-0.88, -0.62),
	Vector2(0.92, 0.66),
	Vector2(0.86, -0.64),
	Vector2(-0.9, 0.62),
	Vector2(-0.72, 0.0),
	Vector2(0.7, 0.0),
	Vector2(0.0, -0.52),
	Vector2(0.0, 0.42),
]

var box: Box
var box_container: Node2D
var container_art: Sprite2D
var fruit_container: Node
var juice: GameplayJuice
var pending: StringName = &""
var grabbed_fruit: Fruit
var _grabbed_sprite_scale := Vector2.ONE
var _grabbed_collision_layer := 1
var _grabbed_collision_mask := 1
var _grab_last_position := Vector2.ZERO
var _grab_velocity := Vector2.ZERO
var _ring_phase := 0.0
var _powerup_data: Dictionary = {}
var _sequence_active := false
var _container_shake_tween: Tween
var _box_container_origin := Vector2.ZERO
var _container_art_origin := Vector2.ZERO
var _shake_sequence_id := 0


func configure(game_box: Box, box_node: Node2D, art: Sprite2D, fruits: Node, feedback: GameplayJuice) -> void:
	box = game_box
	box_container = box_node
	container_art = art
	fruit_container = fruits
	juice = feedback
	_box_container_origin = box_container.position if box_container else Vector2.ZERO
	_container_art_origin = container_art.position if container_art else Vector2.ZERO
	EventBus.powerup_requested.connect(_on_requested)
	EventBus.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	if is_instance_valid(grabbed_fruit):
		_ring_phase = fmod(_ring_phase + delta * _data_value(GRAB, "grab_ring_speed", 5.5), TAU)
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(grabbed_fruit):
		return
	var center := to_local(grabbed_fruit.global_position)
	var radius := FruitDatabase.get_collision_radius(grabbed_fruit.data.tier) + 14.0
	draw_circle(center, radius, Color(1.0, 0.77, 0.12, 0.18))
	draw_arc(center, radius, _ring_phase, _ring_phase + TAU * 0.74, 28, Color(1.0, 0.88, 0.28, 0.92), 4.0, true)
	draw_arc(center, radius + 7.0, -_ring_phase * 0.7, -_ring_phase * 0.7 + TAU * 0.42, 22, Color(0.5, 0.9, 1.0, 0.72), 2.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_powerup_targeting:
		return
	if pending == GRAB:
		_handle_grab_input(event)
		return
	if pending not in [LEVEL_UP, HAMMER, BOMB] or not _event_is_press(event):
		return
	get_viewport().set_input_as_handled()
	var pointer_world_position := _event_world_position(event)
	match pending:
		LEVEL_UP: _level_up_at(pointer_world_position)
		HAMMER: _hammer_at(pointer_world_position)
		BOMB: _bomb_at(pointer_world_position)


func _on_requested(item_id: StringName) -> void:
	if GameManager.current_state != Enums.GameState.PLAYING or EconomyManager.get_powerup_count(item_id) <= 0:
		return
	if item_id == SHAKE_BOX:
		cancel_targeting()
		_shake_box()
		return
	if item_id == REMOVE_SMALLEST:
		cancel_targeting()
		_remove_smallest()
		return
	if item_id not in [LEVEL_UP, GRAB, HAMMER, BOMB]:
		return
	if GameManager.is_powerup_targeting and pending == item_id:
		cancel_targeting()
		return
	cancel_targeting()
	pending = item_id
	GameManager.is_powerup_targeting = true
	EventBus.powerup_targeting_changed.emit(true, _targeting_message(item_id))


func _targeting_message(item_id: StringName) -> String:
	match item_id:
		LEVEL_UP: return "Tap a fruit to level it up!"
		GRAB: return "Hold and drag a fruit anywhere in the box!"
		HAMMER: return "Tap one fruit to smash it!"
		BOMB: return "Tap a cluster to blast nearby fruit!"
		_: return "Choose a fruit"


func _level_up_at(world_position: Vector2) -> void:
	var fruit := _get_fruit_at(world_position)
	if not fruit:
		_show_hint("Tap directly on a fruit inside the box")
		return
	var next_data := FruitDatabase.get_next_fruit(fruit.data.tier)
	if not next_data:
		_show_hint("That fruit is already fully grown!")
		return
	if not EconomyManager.consume_powerup(LEVEL_UP):
		return
	cancel_targeting()
	var position_before := fruit.global_position
	var velocity := fruit.linear_velocity * 0.35 + Vector2(0, -85)
	var spin := fruit.angular_velocity * 0.4
	var source_tier := fruit.data.tier as int
	var parent := fruit.get_parent()
	fruit.is_merging = true
	fruit.start_merge_exit()
	juice.powerup_feedback(source_tier, position_before)
	var upgraded: Fruit = FruitFactoryScript.create(next_data, position_before, parent)
	if upgraded:
		upgraded.linear_velocity = velocity
		upgraded.angular_velocity = spin
		GameManager.register_fruit_discovered(next_data.tier)


func _hammer_at(world_position: Vector2) -> void:
	var fruit := _get_fruit_at(world_position)
	if not fruit:
		_show_hint("Tap the fruit you want to smash")
		return
	if EconomyManager.consume_powerup(HAMMER):
		cancel_targeting()
		_remove_fruit(fruit, 0.55)


func _bomb_at(world_position: Vector2) -> void:
	var target := _get_fruit_at(world_position)
	if not target:
		_show_hint("Tap a fruit at the center of the blast")
		return
	if not EconomyManager.consume_powerup(BOMB):
		return
	cancel_targeting()
	var radius := _data_value(BOMB, "blast_radius", 150.0)
	var center := target.global_position
	var targets: Array[Fruit] = []
	for fruit in get_active_fruits():
		if fruit.global_position.distance_to(center) <= radius and fruit.data.tier <= target.data.tier + 1:
			targets.append(fruit)
	juice.powerup_feedback(target.data.tier, center, 0.9)
	for index in targets.size():
		var fruit := targets[index]
		if is_instance_valid(fruit):
			fruit.is_merging = true
			_delayed_remove(fruit, float(index) * 0.035)


func _delayed_remove(fruit: Fruit, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if is_instance_valid(fruit):
		fruit.start_merge_exit()


func _shake_box() -> void:
	var fruits := get_active_fruits()
	if fruits.is_empty() or not EconomyManager.consume_powerup(SHAKE_BOX):
		return
	var impulse := _data_value(SHAKE_BOX, "fruit_impulse_strength", 235.0)
	var spin := _data_value(SHAKE_BOX, "fruit_spin_strength", 6.0)
	var motion_strength := _data_value(SHAKE_BOX, "container_motion_strength", 28.0)
	var motion_duration := _data_value(SHAKE_BOX, "container_motion_duration", 1.15)
	var followup_ratio := _data_value(SHAKE_BOX, "fruit_followup_impulse_ratio", 0.4)
	_shake_sequence_id += 1
	_apply_initial_shake_impulse(fruits, impulse, spin)
	_apply_followup_shake_impulse(
		fruits,
		impulse * followup_ratio,
		spin * followup_ratio,
		motion_duration * 0.18,
		_shake_sequence_id
	)
	_animate_container_shake(motion_strength, motion_duration)
	juice.powerup_feedback(
		Enums.FruitTier.WATERMELON,
		box.global_position,
		_data_value(SHAKE_BOX, "camera_shake_strength", 0.78),
		_data_value(SHAKE_BOX, "camera_shake_duration", 1.45)
	)


func _apply_initial_shake_impulse(fruits: Array[Fruit], impulse: float, spin: float) -> void:
	for fruit in fruits:
		if not is_instance_valid(fruit) or fruit.freeze:
			continue
		fruit.sleeping = false
		fruit.apply_central_impulse(Vector2(
			randf_range(-impulse, impulse),
			randf_range(-impulse * 1.45, -impulse * 0.72)
		))
		fruit.angular_velocity += randf_range(-spin, spin)


func _apply_followup_shake_impulse(
	fruits: Array[Fruit],
	impulse: float,
	spin: float,
	delay: float,
	sequence_id: int
) -> void:
	await get_tree().create_timer(delay).timeout
	if sequence_id != _shake_sequence_id or GameManager.current_state != Enums.GameState.PLAYING:
		return
	for fruit in fruits:
		if not is_instance_valid(fruit) or not fruit.is_inside_tree() or fruit.is_merging or fruit.freeze:
			continue
		fruit.sleeping = false
		fruit.apply_central_impulse(Vector2(
			randf_range(-impulse, impulse),
			randf_range(-impulse * 0.28, impulse * 0.12)
		))
		fruit.angular_velocity += randf_range(-spin, spin)
	HapticManager.pulse(HapticManager.Feedback.POWERUP)


func _animate_container_shake(strength: float, duration: float) -> void:
	_stop_container_shake()
	if bool(SaveManager.get_setting("reduced_motion", false)) or strength <= 0.0 or duration <= 0.0:
		return
	if not is_instance_valid(box_container) and not is_instance_valid(container_art):
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_container_shake_tween = tween
	var step_duration := duration / float(SHAKE_PATH.size() + 1)
	for index in SHAKE_PATH.size():
		var progress := float(index) / float(maxi(SHAKE_PATH.size() - 1, 1))
		var offset: Vector2 = SHAKE_PATH[index] * strength * lerpf(1.0, 0.48, progress)
		_tween_container_positions(tween, _box_container_origin + offset, _container_art_origin + offset, step_duration)
	_tween_container_positions(tween, _box_container_origin, _container_art_origin, step_duration)
	tween.finished.connect(_restore_container_positions)


func _tween_container_positions(tween: Tween, box_position: Vector2, art_position: Vector2, duration: float) -> void:
	if is_instance_valid(box_container):
		tween.tween_property(box_container, "position", box_position, duration)
		if is_instance_valid(container_art):
			tween.parallel().tween_property(container_art, "position", art_position, duration)
	elif is_instance_valid(container_art):
		tween.tween_property(container_art, "position", art_position, duration)


func _stop_container_shake() -> void:
	if _container_shake_tween and _container_shake_tween.is_valid():
		_container_shake_tween.kill()
	_restore_container_positions()


func _restore_container_positions() -> void:
	if is_instance_valid(box_container):
		box_container.position = _box_container_origin
	if is_instance_valid(container_art):
		container_art.position = _container_art_origin


func _remove_smallest() -> void:
	if _sequence_active:
		return
	var fruits := get_active_fruits()
	if fruits.is_empty():
		return
	var smallest_tier: int = fruits[0].data.tier as int
	for fruit in fruits:
		smallest_tier = mini(smallest_tier, fruit.data.tier as int)
	var candidates: Array[Fruit] = []
	for fruit in fruits:
		if fruit.data.tier as int == smallest_tier:
			candidates.append(fruit)
	if candidates.is_empty() or not EconomyManager.consume_powerup(REMOVE_SMALLEST):
		return
	_sequence_active = true
	var target: Fruit = candidates.pick_random() as Fruit
	var markers: Array[Sprite2D] = []
	for fruit in candidates:
		markers.append(_attach_crosshair(fruit))
	await get_tree().create_timer(_data_value(REMOVE_SMALLEST, "target_marker_hold_time", 0.52)).timeout
	for marker in markers:
		if is_instance_valid(marker): marker.queue_free()
	if is_instance_valid(target):
		_remove_fruit(target, 0.45)
	_sequence_active = false


func _attach_crosshair(fruit: Fruit) -> Sprite2D:
	var marker := Sprite2D.new()
	marker.texture = CROSSHAIR_TEXTURE
	marker.z_index = 40
	marker.modulate = Color(1, 0.86, 0.3, 0)
	var target_scale := Vector2.ONE * FruitDatabase.get_collision_radius(fruit.data.tier) * 2.55 / float(CROSSHAIR_TEXTURE.get_width())
	marker.scale = target_scale * 0.35
	fruit.add_child(marker)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(marker, "scale", target_scale, 0.2)
	tween.tween_property(marker, "modulate:a", 0.94, 0.14)
	tween.tween_property(marker, "rotation", deg_to_rad(15), 0.2)
	return marker


func _remove_fruit(fruit: Fruit, shake: float) -> void:
	if not is_instance_valid(fruit) or fruit.is_merging:
		return
	fruit.is_merging = true
	juice.powerup_feedback(fruit.data.tier, fruit.global_position, shake)
	fruit.start_merge_exit()


func _handle_grab_input(event: InputEvent) -> void:
	if _event_is_press(event):
		get_viewport().set_input_as_handled()
		_begin_grab(_event_world_position(event))
	elif _event_is_release(event):
		get_viewport().set_input_as_handled()
		_release_grab(_event_world_position(event))
	elif _event_is_drag(event) and is_instance_valid(grabbed_fruit):
		get_viewport().set_input_as_handled()
		_update_grab(_event_world_position(event))


func _begin_grab(world_position: Vector2) -> void:
	if is_instance_valid(grabbed_fruit): return
	var fruit := _get_fruit_at(world_position)
	if not fruit:
		_show_hint("Touch directly on a fruit to grab it")
		return
	if not EconomyManager.consume_powerup(GRAB): return
	grabbed_fruit = fruit
	_grabbed_collision_layer = fruit.collision_layer
	_grabbed_collision_mask = fruit.collision_mask
	var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
	_grabbed_sprite_scale = sprite.scale if sprite else Vector2.ONE
	fruit.freeze = true
	fruit.collision_layer = 0
	fruit.collision_mask = 0
	fruit.z_index = 60
	_grab_last_position = fruit.global_position
	_grab_velocity = Vector2.ZERO
	_pulse_sprite(fruit, true)
	juice.powerup_feedback(fruit.data.tier, fruit.global_position, 0.2)
	_show_hint("Drag your fruit onto a matching friend!")


func _update_grab(world_position: Vector2) -> void:
	if not is_instance_valid(grabbed_fruit): return
	var radius := FruitDatabase.get_collision_radius(grabbed_fruit.data.tier)
	var clamped := Vector2(
		clampf(world_position.x, box.global_position.x - 248 + radius, box.global_position.x + 248 - radius),
		clampf(world_position.y, box.global_position.y - 800 + radius, box.global_position.y - 16 - radius)
	)
	_grab_velocity = (clamped - _grab_last_position) * 8.0
	_grab_last_position = clamped
	grabbed_fruit.global_position = clamped
	queue_redraw()


func _release_grab(world_position: Vector2) -> void:
	if not is_instance_valid(grabbed_fruit):
		cancel_targeting()
		return
	_update_grab(world_position)
	var fruit := grabbed_fruit
	var merge_target := _get_fruit_at(fruit.global_position, fruit)
	fruit.collision_layer = _grabbed_collision_layer
	fruit.collision_mask = _grabbed_collision_mask
	fruit.z_index = 10
	fruit.freeze = false
	fruit.sleeping = false
	fruit.linear_velocity = _grab_velocity.limit_length(_data_value(GRAB, "grab_release_speed", 180.0))
	fruit.angular_velocity = clampf(_grab_velocity.x * 0.012, -2.5, 2.5)
	_pulse_sprite(fruit, false)
	grabbed_fruit = null
	cancel_targeting()
	if is_instance_valid(merge_target) and merge_target.data.tier == fruit.data.tier:
		MergeService.try_merge(fruit, merge_target)


func _pulse_sprite(fruit: Fruit, held: bool) -> void:
	var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
	if not sprite: return
	var target_sprite_scale := _grabbed_sprite_scale * _data_value(GRAB, "grab_held_scale", 1.13) if held else _grabbed_sprite_scale
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(sprite, "scale", target_sprite_scale, 0.16)


func _get_fruit_at(world_position: Vector2, ignored: Fruit = null) -> Fruit:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = 1
	query.collide_with_bodies = true
	var hits := get_world_2d().direct_space_state.intersect_point(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Fruit and collider != ignored and not collider.is_merging:
			return collider as Fruit
	return null


func get_active_fruits() -> Array[Fruit]:
	var fruits: Array[Fruit] = []
	for node in get_tree().get_nodes_in_group("fruits"):
		if node is Fruit and is_instance_valid(node) and node.is_inside_tree() and not node.is_merging:
			fruits.append(node)
	return fruits


func cancel_targeting() -> void:
	if is_instance_valid(grabbed_fruit):
		_release_grab(grabbed_fruit.global_position)
	pending = &""
	if GameManager.is_powerup_targeting:
		GameManager.is_powerup_targeting = false
		EventBus.powerup_targeting_changed.emit(false, "")


func _on_state_changed(state: Enums.GameState) -> void:
	if state != Enums.GameState.PLAYING:
		cancel_targeting()


func _show_hint(text: String) -> void:
	EventBus.powerup_targeting_changed.emit(true, text)


func _get_data(item_id: StringName) -> ShopItemData:
	if not _powerup_data.has(item_id):
		_powerup_data[item_id] = load(POWERUP_PATHS.get(item_id, "")) as ShopItemData
	return _powerup_data[item_id]


func _data_value(item_id: StringName, property: StringName, fallback: float) -> float:
	var data := _get_data(item_id)
	if not data:
		return fallback
	var value = data.get(property)
	return float(value) if value != null else fallback


func _event_world_position(event: InputEvent) -> Vector2:
	var screen := get_viewport().get_mouse_position()
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		screen = event.position
	return get_viewport().get_canvas_transform().affine_inverse() * screen


func _event_is_press(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)


func _event_is_release(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)


func _event_is_drag(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag
