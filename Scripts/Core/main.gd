extends Node2D

const GAMEPLAY_MUSIC: AudioStream = preload("res://Audio/Music/Gameplay.wav")
const POWERUP_LEVEL_UP: StringName = &"powerup_level_up"
const POWERUP_SHAKE_BOX: StringName = &"powerup_shake_box"
const POWERUP_REMOVE_SMALLEST: StringName = &"powerup_remove_smallest"
const POWERUP_GRAB_EM: StringName = &"powerup_grab_em"
const CROSSHAIR_TEXTURE: Texture2D = preload("res://Assets/UI/Crosshair.png")
const POWERUP_DATA_PATHS := {
	POWERUP_LEVEL_UP: "res://Data/ShopItems/powerup_level_up.tres",
	POWERUP_SHAKE_BOX: "res://Data/ShopItems/powerup_shake_box.tres",
	POWERUP_REMOVE_SMALLEST: "res://Data/ShopItems/powerup_remove_smallest.tres",
	POWERUP_GRAB_EM: "res://Data/ShopItems/powerup_grab_em.tres",
}
const BOX_SHAKE_DIRECTIONS := [
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(-0.72, -0.72),
	Vector2(0.72, 0.72),
	Vector2(0.72, -0.72),
	Vector2(-0.72, 0.72),
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
]
const HIGH_TIER_TICKET_REWARDS := {
	Enums.FruitTier.PINEAPPLE: 1,
	Enums.FruitTier.DRAGONFRUIT: 2,
	Enums.FruitTier.WATERMELON: 3,
}

@export var box_scene: PackedScene
@export var spawner_scene: PackedScene
@export var pet_scene: PackedScene
@export var merge_burst_scene: PackedScene

@onready var _box_container: Node2D = %BoxContainer
@onready var _spawner_container: Node2D = %SpawnerContainer
@onready var _pet_container: Node2D = %PetContainer
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _container_art: Sprite2D = $ContainerArt
@onready var _hud: Control = %HUD

var _box: Box
var _spawner: Spawner
var _pet: Pet
var _particle_pool: Array[GPUParticles2D] = []
var _pool_index: int = 0
var _pending_powerup: StringName = &""
var _grabbed_fruit: Fruit
var _grabbed_sprite_scale := Vector2.ONE
var _grabbed_collision_layer := 1
var _grabbed_collision_mask := 1
var _grab_last_world_position := Vector2.ZERO
var _grab_drag_velocity := Vector2.ZERO
var _grab_ring_phase := 0.0
var _camera_shake_tween: Tween
var _camera_shake_camera: Camera2D
var _camera_shake_origin := Vector2.ZERO
var _box_shake_tweens: Array[Tween] = []
var _box_shake_origins: Dictionary = {}
var _remove_sequence_active := false
var _powerup_data: Dictionary = {}
const PARTICLE_POOL_SIZE := 6


func _ready() -> void:
	AudioManager.play_music(GAMEPLAY_MUSIC)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.game_over.connect(_on_game_over)
	EventBus.powerup_requested.connect(_on_powerup_requested)

	_setup_box()
	_setup_spawner()
	_setup_pet()
	_setup_particle_pool()

	if _game_over_panel:
		_game_over_panel.visible = false


func _process(delta: float) -> void:
	if is_instance_valid(_grabbed_fruit):
		var grab_data := _get_powerup_data(POWERUP_GRAB_EM)
		var ring_speed := grab_data.grab_ring_speed if grab_data else 5.5
		_grab_ring_phase = fmod(_grab_ring_phase + delta * ring_speed, TAU)
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_grabbed_fruit):
		return
	var center := to_local(_grabbed_fruit.global_position)
	var radius := FruitDatabase.get_collision_radius(_grabbed_fruit.data.tier) + 14.0
	var glow := Color(1.0, 0.77, 0.12, 0.18)
	var ring := Color(1.0, 0.88, 0.28, 0.92)
	draw_circle(center, radius, glow)
	draw_arc(center, radius, _grab_ring_phase, _grab_ring_phase + TAU * 0.74, 28, ring, 4.0, true)
	draw_arc(center, radius + 7.0, -_grab_ring_phase * 0.7, -_grab_ring_phase * 0.7 + TAU * 0.42, 22, Color(0.5, 0.9, 1.0, 0.72), 2.0, true)


func _setup_box() -> void:
	if box_scene:
		_box = box_scene.instantiate()
		_box_container.add_child(_box)


func _setup_spawner() -> void:
	if spawner_scene:
		_spawner = spawner_scene.instantiate()
		_spawner_container.add_child(_spawner)


func _setup_pet() -> void:
	if pet_scene and not EconomyManager.get_equipped_item(&"pet").is_empty():
		_pet = pet_scene.instantiate()
		_pet_container.add_child(_pet)


func _setup_particle_pool() -> void:
	for i in PARTICLE_POOL_SIZE:
		var particles := GPUParticles2D.new()
		particles.one_shot = true
		particles.amount = 14
		particles.lifetime = 0.5
		particles.explosiveness = 1.0
		particles.process_material = _create_particle_material()
		particles.emitting = false
		particles.visible = false
		add_child(particles)
		_particle_pool.append(particles)


func _create_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 200, 0)
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 180.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 90.0
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1, 0.9, 0.3, 1)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.95, 0.4, 1.0))
	grad.set_color(1, Color(1, 0.6, 0.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex
	return mat


func _on_state_changed(state: Enums.GameState) -> void:
	if state != Enums.GameState.PLAYING:
		_cancel_powerup_targeting()
	match state:
		Enums.GameState.GAME_OVER:
			if _game_over_panel:
				_game_over_panel.visible = true
		Enums.GameState.PLAYING:
			if _game_over_panel:
				_game_over_panel.visible = false


func _on_fruit_merged(tier: int, world_pos: Vector2, _score: int) -> void:
	_spawn_merge_burst(tier, world_pos)
	_spawn_pooled_particles(world_pos)
	if tier >= Enums.FruitTier.ORANGE:
		_apply_screen_shake(tier)
	_award_high_tier_ticket(tier + 1)


func _award_high_tier_ticket(created_tier: int) -> void:
	if not HIGH_TIER_TICKET_REWARDS.has(created_tier):
		return
	var ticket_amount: int = HIGH_TIER_TICKET_REWARDS[created_tier]
	EconomyManager.add_tickets(ticket_amount)
	SaveManager.save_game()
	if _hud and _hud.has_method("show_tier_ticket_reward"):
		_hud.call("show_tier_ticket_reward", created_tier, ticket_amount)


func _spawn_merge_burst(tier: int, world_pos: Vector2) -> void:
	if merge_burst_scene:
		var burst: Node2D = merge_burst_scene.instantiate()
		burst.global_position = world_pos
		if burst.has_method("configure"):
			burst.call("configure", tier)
		add_child(burst)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_powerup_targeting:
		return
	if _pending_powerup == POWERUP_GRAB_EM:
		_handle_grab_input(event)
		return
	if _pending_powerup != POWERUP_LEVEL_UP:
		return
	var pressed := _event_is_press(event)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_try_level_up_at(_event_world_position(event))


func _on_powerup_requested(item_id: StringName) -> void:
	if GameManager.current_state != Enums.GameState.PLAYING:
		return
	if EconomyManager.get_powerup_count(item_id) <= 0:
		return
	match item_id:
		POWERUP_LEVEL_UP:
			if GameManager.is_powerup_targeting:
				_cancel_powerup_targeting()
			else:
				_pending_powerup = POWERUP_LEVEL_UP
				GameManager.is_powerup_targeting = true
				EventBus.powerup_targeting_changed.emit(true, "Tap a fruit to level it up!")
		POWERUP_SHAKE_BOX:
			_cancel_powerup_targeting()
			_shake_box()
		POWERUP_REMOVE_SMALLEST:
			_cancel_powerup_targeting()
			_remove_smallest_fruit()
		POWERUP_GRAB_EM:
			if GameManager.is_powerup_targeting:
				_cancel_powerup_targeting()
			else:
				_pending_powerup = POWERUP_GRAB_EM
				GameManager.is_powerup_targeting = true
				EventBus.powerup_targeting_changed.emit(true, "Grab a fruit, then place it anywhere!")


func _try_level_up_at(world_position: Vector2) -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := get_world_2d().direct_space_state.intersect_point(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Fruit and not collider.is_merging:
			var fruit := collider as Fruit
			var next_data := FruitDatabase.get_next_fruit(fruit.data.tier)
			if not next_data:
				EventBus.powerup_targeting_changed.emit(true, "That fruit is already fully grown!")
				return
			if EconomyManager.consume_powerup(POWERUP_LEVEL_UP):
				_cancel_powerup_targeting()
				_level_up_fruit(fruit, next_data)
			return
	EventBus.powerup_targeting_changed.emit(true, "Tap directly on a fruit inside the box")


func _level_up_fruit(fruit: Fruit, next_data: FruitData) -> void:
	if not is_instance_valid(fruit) or fruit.is_merging:
		return
	var world_position := fruit.global_position
	var carried_velocity := fruit.linear_velocity * 0.35 + Vector2(0, -85)
	var carried_spin := fruit.angular_velocity * 0.4
	var source_tier := fruit.data.tier as int
	fruit.is_merging = true
	fruit.set_emotion(Enums.FruitEmotion.EXCITED)
	fruit.start_merge_exit()
	_spawn_powerup_effect(source_tier, world_position)
	AudioManager.play_merge_sfx(source_tier, next_data.merge_sfx, world_position)
	var upgraded := Spawner.spawn_at(next_data, world_position)
	if upgraded:
		upgraded.linear_velocity = carried_velocity
		upgraded.angular_velocity = carried_spin
		GameManager.highest_tier_reached = maxi(GameManager.highest_tier_reached, next_data.tier)
		var juice := _get_powerup_data(POWERUP_LEVEL_UP)
		if juice:
			_apply_screen_shake(source_tier, juice.camera_shake_strength, juice.camera_shake_duration)


func _shake_box() -> void:
	var fruits := _get_active_fruits()
	if fruits.is_empty() or not EconomyManager.consume_powerup(POWERUP_SHAKE_BOX):
		return
	var juice := _get_powerup_data(POWERUP_SHAKE_BOX)
	var impulse_strength := juice.fruit_impulse_strength if juice else 235.0
	var spin_strength := juice.fruit_spin_strength if juice else 6.0
	for fruit in fruits:
		fruit.sleeping = false
		fruit.apply_central_impulse(Vector2(
			randf_range(-impulse_strength, impulse_strength),
			randf_range(-impulse_strength * 1.35, -impulse_strength * 0.55)
		))
		fruit.angular_velocity += randf_range(-spin_strength, spin_strength)
	_reset_box_shake()
	var motion_strength := juice.container_motion_strength if juice else 17.0
	var motion_duration := juice.container_motion_duration if juice else 1.45
	_animate_box_shake(_box_container, _box_container.position, motion_strength, motion_duration)
	_animate_box_shake(_container_art, _container_art.position, motion_strength, motion_duration)
	# The camera moves less than the box so the shake feels weighty, not dizzy.
	_apply_screen_shake(
		Enums.FruitTier.WATERMELON,
		juice.camera_shake_strength if juice else 0.58,
		juice.camera_shake_duration if juice else 1.8
	)


func _animate_box_shake(node: Node2D, origin: Vector2, strength: float, duration: float) -> void:
	_box_shake_origins[node] = origin
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_box_shake_tweens.append(tween)
	var step_duration := duration / float(BOX_SHAKE_DIRECTIONS.size() + 1)
	for step in BOX_SHAKE_DIRECTIONS.size():
		var falloff := 1.0 - float(step) / float(BOX_SHAKE_DIRECTIONS.size() + 3)
		var direction: Vector2 = BOX_SHAKE_DIRECTIONS[step]
		tween.tween_property(node, "position", origin + direction * strength * falloff, step_duration)
	tween.tween_property(node, "position", origin, step_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		_box_shake_tweens.erase(tween)
		_box_shake_origins.erase(node)
	)


func _reset_box_shake() -> void:
	for tween in _box_shake_tweens:
		if tween and tween.is_valid():
			tween.kill()
	for node in _box_shake_origins:
		if is_instance_valid(node):
			node.position = _box_shake_origins[node]
	_box_shake_tweens.clear()
	_box_shake_origins.clear()


func _remove_smallest_fruit() -> void:
	if _remove_sequence_active:
		return
	var fruits := _get_active_fruits()
	if fruits.is_empty():
		return
	var smallest_tier := fruits[0].data.tier
	for fruit in fruits:
		if fruit.data.tier < smallest_tier:
			smallest_tier = fruit.data.tier
	var smallest_fruits: Array[Fruit] = []
	for fruit in fruits:
		if fruit.data.tier == smallest_tier:
			smallest_fruits.append(fruit)
	if not EconomyManager.consume_powerup(POWERUP_REMOVE_SMALLEST):
		return
	_remove_sequence_active = true
	_play_remove_smallest_sequence(smallest_fruits, _get_powerup_data(POWERUP_REMOVE_SMALLEST))


func _play_remove_smallest_sequence(smallest_fruits: Array[Fruit], juice: ShopItemData) -> void:
	# Every matching smallest fruit is marked first, making it clear what this
	# power is about before one of them is removed.
	var crosshairs: Dictionary = {}
	for fruit in smallest_fruits:
		if not is_instance_valid(fruit) or fruit.is_merging:
			continue
		crosshairs[fruit] = _attach_remove_crosshair(fruit, juice)
	if crosshairs.is_empty():
		_remove_sequence_active = false
		return

	await get_tree().create_timer(juice.target_marker_hold_time if juice else 0.52).timeout
	var target: Fruit = crosshairs.keys().pick_random() as Fruit
	var target_crosshair: Sprite2D = crosshairs.get(target) as Sprite2D
	if is_instance_valid(target_crosshair):
		var lock_tween_time := juice.effect_duration if juice else 0.16
		var target_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		target_tween.tween_property(target_crosshair, "scale", target_crosshair.scale * 1.28, lock_tween_time)
		target_tween.parallel().tween_property(target_crosshair, "modulate", Color(1.0, 0.48, 0.18, 1.0), lock_tween_time)
	await get_tree().create_timer(juice.target_lock_time if juice else 0.17).timeout

	for crosshair in crosshairs.values():
		if is_instance_valid(crosshair):
			crosshair.queue_free()
	if is_instance_valid(target) and not target.is_merging:
		var tier := target.data.tier as int
		var world_position := target.global_position
		target.is_merging = true
		_spawn_powerup_effect(tier, world_position)
		AudioManager.play_merge_sfx(tier, null, world_position)
		target.start_merge_exit()
		_apply_screen_shake(
			tier,
			juice.camera_shake_strength if juice else 0.32,
			juice.camera_shake_duration if juice else 0.72
		)
	_remove_sequence_active = false


func _attach_remove_crosshair(fruit: Fruit, juice: ShopItemData) -> Sprite2D:
	var crosshair := Sprite2D.new()
	crosshair.texture = CROSSHAIR_TEXTURE
	crosshair.z_index = 40
	crosshair.modulate = Color(1.0, 0.86, 0.3, 0.0)
	var marker_scale := juice.target_marker_scale if juice else 2.55
	var base_scale := Vector2.ONE * (FruitDatabase.get_collision_radius(fruit.data.tier) * marker_scale / float(CROSSHAIR_TEXTURE.get_width()))
	crosshair.scale = base_scale * 0.35
	fruit.add_child(crosshair)
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var intro_time := juice.effect_duration if juice else 0.2
	tween.tween_property(crosshair, "scale", base_scale, intro_time)
	tween.tween_property(crosshair, "modulate:a", 0.94, intro_time * 0.7)
	tween.tween_property(crosshair, "rotation", deg_to_rad(15.0), intro_time)
	return crosshair


func _handle_grab_input(event: InputEvent) -> void:
	if _event_is_press(event):
		get_viewport().set_input_as_handled()
		_begin_grab_at(_event_world_position(event))
		return
	if _event_is_release(event):
		get_viewport().set_input_as_handled()
		_release_grab(_event_world_position(event))
		return
	if _event_is_drag(event) and is_instance_valid(_grabbed_fruit):
		get_viewport().set_input_as_handled()
		_update_grab_position(_event_world_position(event))


func _begin_grab_at(world_position: Vector2) -> void:
	if is_instance_valid(_grabbed_fruit):
		return
	var fruit := _get_fruit_at(world_position)
	if not fruit:
		EventBus.powerup_targeting_changed.emit(true, "Tap directly on a fruit to grab it")
		return
	if not EconomyManager.consume_powerup(POWERUP_GRAB_EM):
		_cancel_powerup_targeting()
		return
	_grabbed_fruit = fruit
	_grabbed_collision_layer = fruit.collision_layer
	_grabbed_collision_mask = fruit.collision_mask
	_grabbed_sprite_scale = _get_fruit_sprite_scale(fruit)
	fruit.freeze = true
	fruit.linear_velocity = Vector2.ZERO
	fruit.angular_velocity = 0.0
	fruit.collision_layer = 0
	fruit.collision_mask = 0
	fruit.z_index = 60
	fruit.set_emotion(Enums.FruitEmotion.EXCITED)
	_grab_last_world_position = fruit.global_position
	_grab_drag_velocity = Vector2.ZERO
	_pulse_grabbed_fruit(fruit, true)
	_spawn_powerup_effect(fruit.data.tier, fruit.global_position)
	EventBus.powerup_targeting_changed.emit(true, "Drag your fruit onto a matching friend!")
	queue_redraw()


func _update_grab_position(world_position: Vector2) -> void:
	if not is_instance_valid(_grabbed_fruit):
		return
	var clamped := _clamp_grab_position(_grabbed_fruit, world_position)
	_grab_drag_velocity = (clamped - _grab_last_world_position) * 8.0
	_grab_last_world_position = clamped
	_grabbed_fruit.global_position = clamped
	queue_redraw()


func _release_grab(world_position: Vector2) -> void:
	if not is_instance_valid(_grabbed_fruit):
		_cancel_powerup_targeting()
		return
	_update_grab_position(world_position)
	var fruit := _grabbed_fruit
	var merge_target := _get_fruit_at(fruit.global_position, fruit)
	fruit.collision_layer = _grabbed_collision_layer
	fruit.collision_mask = _grabbed_collision_mask
	fruit.z_index = 10
	fruit.freeze = false
	fruit.sleeping = false
	var grab_data := _get_powerup_data(POWERUP_GRAB_EM)
	var release_speed := grab_data.grab_release_speed if grab_data else 180.0
	fruit.linear_velocity = _grab_drag_velocity.limit_length(release_speed)
	fruit.angular_velocity = clampf(_grab_drag_velocity.x * 0.012, -2.5, 2.5)
	_pulse_grabbed_fruit(fruit, false)
	_spawn_powerup_effect(fruit.data.tier, fruit.global_position)
	_grabbed_fruit = null
	queue_redraw()
	_cancel_powerup_targeting()
	if is_instance_valid(merge_target) and merge_target.data.tier == fruit.data.tier:
		MergeService.try_merge(fruit, merge_target)


func _get_fruit_at(world_position: Vector2, ignore_fruit: Fruit = null) -> Fruit:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := get_world_2d().direct_space_state.intersect_point(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Fruit and collider != ignore_fruit:
			var fruit := collider as Fruit
			if not fruit.is_merging:
				return fruit
	return null


func _clamp_grab_position(fruit: Fruit, world_position: Vector2) -> Vector2:
	var radius := FruitDatabase.get_collision_radius(fruit.data.tier)
	var floor_y := _box.global_position.y - 16.0
	var top_y := _box.global_position.y - 800.0
	return Vector2(
		clampf(world_position.x, -248.0 + radius, 248.0 - radius),
		clampf(world_position.y, top_y + radius, floor_y - radius)
	)


func _get_fruit_sprite_scale(fruit: Fruit) -> Vector2:
	var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
	return sprite.scale if sprite else Vector2.ONE


func _pulse_grabbed_fruit(fruit: Fruit, held: bool) -> void:
	var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	var grab_data := _get_powerup_data(POWERUP_GRAB_EM)
	var held_scale := grab_data.grab_held_scale if grab_data else 1.13
	var target := _grabbed_sprite_scale * held_scale if held else _grabbed_sprite_scale
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", target, grab_data.effect_duration if grab_data else 0.16)


func _event_world_position(event: InputEvent) -> Vector2:
	var screen_position := get_viewport().get_mouse_position()
	if event is InputEventMouseButton:
		screen_position = event.position
	elif event is InputEventMouseMotion:
		screen_position = event.position
	elif event is InputEventScreenTouch:
		screen_position = event.position
	elif event is InputEventScreenDrag:
		screen_position = event.position
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position


func _event_is_press(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)


func _event_is_release(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)


func _event_is_drag(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag


func _get_powerup_data(item_id: StringName) -> ShopItemData:
	if _powerup_data.has(item_id):
		return _powerup_data[item_id] as ShopItemData
	var path := String(POWERUP_DATA_PATHS.get(item_id, ""))
	if path.is_empty():
		return null
	var data := load(path) as ShopItemData
	_powerup_data[item_id] = data
	return data


func _get_active_fruits() -> Array[Fruit]:
	var fruits: Array[Fruit] = []
	for node in get_tree().get_nodes_in_group("fruits"):
		if node is Fruit and is_instance_valid(node) and node.is_inside_tree() and not node.is_merging:
			fruits.append(node as Fruit)
	return fruits


func _spawn_powerup_effect(tier: int, world_position: Vector2) -> void:
	_spawn_merge_burst(tier, world_position)
	_spawn_pooled_particles(world_position)


func _cancel_powerup_targeting() -> void:
	if is_instance_valid(_grabbed_fruit):
		_release_grab(_grabbed_fruit.global_position)
	_pending_powerup = &""
	if GameManager.is_powerup_targeting:
		GameManager.is_powerup_targeting = false
		EventBus.powerup_targeting_changed.emit(false, "")


func _spawn_pooled_particles(pos: Vector2) -> void:
	var particles := _particle_pool[_pool_index]
	_pool_index = wrapi(_pool_index + 1, 0, PARTICLE_POOL_SIZE)
	particles.global_position = pos
	particles.visible = true
	particles.emitting = true
	particles.restart()


func _apply_screen_shake(tier: int, intensity: float = 1.0, duration_scale: float = 1.0) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	if _camera_shake_tween and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()
	if is_instance_valid(_camera_shake_camera):
		_camera_shake_camera.position = _camera_shake_origin
	_camera_shake_camera = cam
	_camera_shake_origin = cam.position
	var tier_span: int = maxi(1, Enums.FruitTier.WATERMELON - Enums.FruitTier.ORANGE)
	var shake_ratio := clampf(float(tier - Enums.FruitTier.ORANGE) / float(tier_span), 0.0, 1.0)
	var shake_strength: float = lerpf(2.0, 7.0, shake_ratio) * intensity
	var shakes := maxi(4, roundi(8.0 * duration_scale))
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_shake_tween = t
	var orig := cam.position
	for i in shakes:
		var falloff := 1.0 - float(i) / float(shakes + 2)
		var offset := Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength)) * falloff
		t.tween_property(cam, "position", orig + offset, 0.038 * duration_scale)
	t.tween_property(cam, "position", orig, 0.08 * duration_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.finished.connect(func():
		if is_instance_valid(cam):
			cam.position = orig
		if _camera_shake_tween == t:
			_camera_shake_tween = null
	)


func _on_game_over(_score: int) -> void:
	if _game_over_panel:
		_game_over_panel.visible = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SaveManager.save_game()
