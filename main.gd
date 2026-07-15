extends Node2D

const SHAKE_TIERS: Array[Enums.FruitTier] = [
	Enums.FruitTier.PEACH,
	Enums.FruitTier.PINEAPPLE,
	Enums.FruitTier.MELON,
	Enums.FruitTier.WATERMELON,
]

@export var box_scene: PackedScene
@export var spawner_scene: PackedScene
@export var pet_scene: PackedScene
@export var merge_burst_scene: PackedScene

@onready var _box_container: Node2D = %BoxContainer
@onready var _spawner_container: Node2D = %SpawnerContainer
@onready var _pet_container: Node2D = %PetContainer
@onready var _game_over_panel: Control = %GameOverPanel

var _box: Box
var _spawner: Spawner
var _pet: Pet
var _particle_pool: Array[GPUParticles2D] = []
var _pool_index: int = 0
const PARTICLE_POOL_SIZE := 6


func _ready() -> void:
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.game_over.connect(_on_game_over)

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
	if pet_scene:
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
	match state:
		Enums.GameState.GAME_OVER:
			if _game_over_panel:
				_game_over_panel.visible = true
		Enums.GameState.PLAYING:
			if _game_over_panel:
				_game_over_panel.visible = false


func _on_fruit_merged(tier: int, world_pos: Vector2, _score: int) -> void:
	if merge_burst_scene:
		var burst: Node2D = merge_burst_scene.instantiate()
		burst.global_position = world_pos
		add_child(burst)
	_spawn_pooled_particles(world_pos)
	if tier >= Enums.FruitTier.PEACH:
		_apply_screen_shake(tier)


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
	var shake_strength: float = lerpf(2.0, 8.0, float(tier - Enums.FruitTier.PEACH) / 3.0)
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
