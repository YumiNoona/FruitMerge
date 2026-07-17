extends Node2D

const GAMEPLAY_MUSIC: AudioStream = preload("res://Audio/Music/Gameplay.wav")
const POWERUP_LEVEL_UP: StringName = &"powerup_level_up"
const POWERUP_SHAKE_BOX: StringName = &"powerup_shake_box"
const POWERUP_REMOVE_SMALLEST: StringName = &"powerup_remove_smallest"

@export var box_scene: PackedScene
@export var spawner_scene: PackedScene
@export var pet_scene: PackedScene
@export var merge_burst_scene: PackedScene

@onready var _box_container: Node2D = %BoxContainer
@onready var _spawner_container: Node2D = %SpawnerContainer
@onready var _pet_container: Node2D = %PetContainer
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _container_art: Sprite2D = $ContainerArt

var _box: Box
var _spawner: Spawner
var _pet: Pet
var _particle_pool: Array[GPUParticles2D] = []
var _pool_index: int = 0
var _pending_powerup: StringName = &""
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


func _spawn_merge_burst(tier: int, world_pos: Vector2) -> void:
	if merge_burst_scene:
		var burst: Node2D = merge_burst_scene.instantiate()
		burst.global_position = world_pos
		if burst.has_method("configure"):
			burst.call("configure", tier)
		add_child(burst)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_powerup_targeting or _pending_powerup != POWERUP_LEVEL_UP:
		return
	var pressed := false
	var screen_position := get_viewport().get_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		screen_position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		screen_position = event.position
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	_try_level_up_at(world_position)


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


func _shake_box() -> void:
	var fruits := _get_active_fruits()
	if fruits.is_empty() or not EconomyManager.consume_powerup(POWERUP_SHAKE_BOX):
		return
	for fruit in fruits:
		fruit.sleeping = false
		fruit.apply_central_impulse(Vector2(randf_range(-170.0, 170.0), randf_range(-230.0, -105.0)))
		fruit.angular_velocity += randf_range(-4.5, 4.5)
	_animate_box_shake(_box_container, _box_container.position)
	_animate_box_shake(_container_art, _container_art.position)
	_apply_screen_shake(Enums.FruitTier.WATERMELON)


func _animate_box_shake(node: Node2D, origin: Vector2) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for step in 8:
		var strength := 11.0 * (1.0 - float(step) / 10.0)
		var direction := -1.0 if step % 2 == 0 else 1.0
		tween.tween_property(node, "position", origin + Vector2(strength * direction, randf_range(-3.0, 3.0)), 0.045)
	tween.tween_property(node, "position", origin, 0.08)


func _remove_smallest_fruit() -> void:
	var fruits := _get_active_fruits()
	if fruits.is_empty():
		return
	var smallest := fruits[0]
	for fruit in fruits:
		if fruit.data.tier < smallest.data.tier:
			smallest = fruit
	if not EconomyManager.consume_powerup(POWERUP_REMOVE_SMALLEST):
		return
	var tier := smallest.data.tier as int
	var world_position := smallest.global_position
	smallest.is_merging = true
	_spawn_powerup_effect(tier, world_position)
	AudioManager.play_merge_sfx(tier, null, world_position)
	smallest.start_merge_exit()


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


func _apply_screen_shake(tier: int) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var tier_span: int = maxi(1, Enums.FruitTier.WATERMELON - Enums.FruitTier.ORANGE)
	var shake_ratio := clampf(float(tier - Enums.FruitTier.ORANGE) / float(tier_span), 0.0, 1.0)
	var shake_strength: float = lerpf(2.0, 7.0, shake_ratio)
	var shakes := 8
	var t := create_tween()
	var orig := cam.position
	for i in shakes:
		var offset := Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		t.tween_property(cam, "position", orig + offset, 0.03)
	t.tween_property(cam, "position", orig, 0.04)


func _on_game_over(_score: int) -> void:
	if _game_over_panel:
		_game_over_panel.visible = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SaveManager.save_game()
