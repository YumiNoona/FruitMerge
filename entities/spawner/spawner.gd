class_name Spawner
extends Node2D

const SPAWN_TIERS: Array[Enums.FruitTier] = [
	Enums.FruitTier.CHERRY,
	Enums.FruitTier.STRAWBERRY,
	Enums.FruitTier.GRAPE,
	Enums.FruitTier.RADISH,
	Enums.FruitTier.CAPSICUM,
]

@export var drop_cooldown: float = 0.5
@export var max_x_spread: float = 80.0
@export var drop_line_scene: PackedScene
@export var fruit_scene: PackedScene

var _can_drop: bool = true
var _is_aiming: bool = false
var _aim_start: Vector2
var _aim_line: Line2D

var _current_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var _next_tier: Enums.FruitTier = Enums.FruitTier.CHERRY

@onready var _cooldown_timer: Timer = $CooldownTimer
@onready var _preview: Sprite2D = $Preview


func _ready() -> void:
	if _cooldown_timer:
		_cooldown_timer.timeout.connect(_on_cooldown_ready)
	_update_tiers()
	EventBus.state_changed.connect(_on_state_changed)
	_refresh_preview()

func _process(_delta: float) -> void:
	if not _can_drop or not _is_aiming:
		return
	var mx := _clamp_x(get_global_mouse_position().x)
	_preview.position.x = mx - position.x


func _on_state_changed(state: Enums.GameState) -> void:
	_can_drop = (state == Enums.GameState.PLAYING)
	_preview.visible = _can_drop


func _update_tiers() -> void:
	_current_tier = _next_tier
	_next_tier = _get_random_spawn_tier()
	GameManager.next_fruit_tier = _next_tier
	_refresh_preview()


func _refresh_preview() -> void:
	var d := FruitDatabase.get_fruit(_current_tier)
	if d:
		_preview.texture = d.sprite
	_preview.position = Vector2(0, -20)


func _get_random_spawn_tier() -> Enums.FruitTier:
	return SPAWN_TIERS[randi() % SPAWN_TIERS.size()]


# ── static spawn (called by MergeService) ──

static func spawn_at(fruit_data: FruitData, world_pos: Vector2) -> Fruit:
	var scene := load("res://entities/fruit/fruit.tscn") as PackedScene
	var fruit: Fruit = scene.instantiate()
	fruit.data = fruit_data
	fruit.global_position = world_pos
	fruit.linear_velocity = Vector2(0, -150)

	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.call_deferred("add_child", fruit)

	return fruit


# ── input ──

func _input(event: InputEvent) -> void:
	if not _can_drop:
		return
	if GameManager.current_state != Enums.GameState.PLAYING:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_aim()
			elif _is_aiming:
				_end_aim(get_global_mouse_position())

	if event is InputEventMouseMotion and _is_aiming:
		_update_aim(get_global_mouse_position())


func _begin_aim() -> void:
	_is_aiming = true
	_aim_start = get_global_mouse_position()
	_aim_start.x = _clamp_x(_aim_start.x)
	_create_aim_line()


func _end_aim(release_pos: Vector2) -> void:
	_is_aiming = false
	var drop_x := _clamp_x(release_pos.x)
	var dist: float = abs(drop_x - _aim_start.x)
	if dist < 10.0:
		drop_x = _aim_start.x
	_drop_at(drop_x)
	_clear_aim_line()


func _update_aim(mouse_pos: Vector2) -> void:
	var target_x := _clamp_x(mouse_pos.x)
	_update_aim_line(Vector2(target_x, mouse_pos.y))


func _clamp_x(x: float) -> float:
	var data := FruitDatabase.get_fruit(_current_tier)
	var r := data.radius if data else 28.0
	var left_limit := position.x - max_x_spread + r
	var right_limit := position.x + max_x_spread - r
	return clampf(x, left_limit, right_limit)


# ── aim line (raycast-based) ──

func _create_aim_line() -> void:
	_aim_line = Line2D.new()
	_aim_line.width = 2.0
	_aim_line.default_color = Color(1, 1, 1, 0.35)
	_aim_line.z_index = 100
	add_child(_aim_line)


func _update_aim_line(target: Vector2) -> void:
	_aim_line.clear_points()
	_aim_line.add_point(Vector2(target.x, position.y))

	var cast_end := _raycast_to_floor(Vector2(target.x, position.y))
	_aim_line.add_point(cast_end)

	if target.distance_to(cast_end) > 20.0:
		_mark_dashed(cast_end, target.distance_to(cast_end))


func _raycast_to_floor(from: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 1000))
	query.collision_mask = 1
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return result.position
	return from + Vector2(0, 1000)


func _mark_dashed(_hit_point: Vector2, _dist: float) -> void:
	pass


func _clear_aim_line() -> void:
	if _aim_line:
		_aim_line.queue_free()
		_aim_line = null


# ── drop ──

func _drop_at(x: float) -> void:
	if not _can_drop:
		return

	var fruit_data := FruitDatabase.get_fruit(_current_tier)
	if not fruit_data:
		return

	_can_drop = false
	_preview.visible = false
	if _cooldown_timer:
		_cooldown_timer.start(drop_cooldown)

	var spawn_pos := Vector2(x, position.y - 20.0)

	var fruit: Fruit = fruit_scene.instantiate()
	fruit.data = fruit_data
	fruit.global_position = spawn_pos
	fruit.freeze = true
	get_parent().add_child(fruit)

	await get_tree().create_timer(0.02).timeout
	if is_instance_valid(fruit):
		fruit.freeze = false
		fruit.sleeping = false

	EventBus.fruit_dropped.emit(_current_tier)
	_spawn_drop_line(x)
	_update_tiers()


func _spawn_drop_line(target_x: float) -> void:
	if not drop_line_scene:
		return
	var line: Node2D = drop_line_scene.instantiate()
	line.global_position = Vector2(target_x, position.y)
	get_parent().add_child(line)


func _on_cooldown_ready() -> void:
	_can_drop = true
	_preview.visible = true
