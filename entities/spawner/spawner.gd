class_name Spawner
extends Node2D

const SPAWN_TIERS: Array[Enums.FruitTier] = [
	Enums.FruitTier.CHERRY,
	Enums.FruitTier.BERRIES,
	Enums.FruitTier.STRAWBERRY,
	Enums.FruitTier.GRAPE,
]
const GUIDE_DASH_LENGTH: float = 18.0
const GUIDE_GAP_LENGTH: float = 13.0
const GUIDE_SPEED: float = 72.0
const GUIDE_FOREGROUND := Color(1.0, 0.96, 0.76, 0.94)
const GUIDE_SHADOW := Color(0.55, 0.29, 0.09, 0.22)

@export var drop_cooldown: float = 0.55
@export var max_x_spread: float = 238.0

var _can_drop: bool = true
var _is_aiming: bool = false
var _aim_start: Vector2
var _guide_phase: float = 0.0
var _current_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var _next_tier: Enums.FruitTier = Enums.FruitTier.CHERRY

@onready var _cooldown_timer: Timer = $CooldownTimer
@onready var _preview: Sprite2D = $Preview


func _ready() -> void:
	_cooldown_timer.timeout.connect(_on_cooldown_ready)
	_update_tiers()
	EventBus.state_changed.connect(_on_state_changed)
	_refresh_preview()


func _process(delta: float) -> void:
	if not _can_drop or GameManager.current_state != Enums.GameState.PLAYING:
		queue_redraw()
		return
	var target_x := _clamp_x(get_global_mouse_position().x)
	_preview.position.x = target_x - global_position.x
	_guide_phase = fmod(_guide_phase + GUIDE_SPEED * delta, GUIDE_DASH_LENGTH + GUIDE_GAP_LENGTH)
	queue_redraw()


func _draw() -> void:
	if not _can_drop or GameManager.current_state != Enums.GameState.PLAYING or not _preview.visible:
		return
	var radius := FruitDatabase.get_collision_radius(_current_tier)
	var start := Vector2(_preview.position.x, _preview.position.y + radius + 9.0)
	var end := to_local(_raycast_to_floor(to_global(start)))
	_draw_animated_guide(start, end)


func _draw_animated_guide(start: Vector2, end: Vector2) -> void:
	var distance := end.y - start.y
	if distance <= 4.0:
		return
	var cycle := GUIDE_DASH_LENGTH + GUIDE_GAP_LENGTH
	var cursor := _guide_phase - cycle
	while cursor < distance:
		var segment_start := maxf(cursor, 0.0)
		var segment_end := minf(cursor + GUIDE_DASH_LENGTH, distance)
		if segment_end > segment_start:
			var from := Vector2(start.x, start.y + segment_start)
			var to := Vector2(start.x, start.y + segment_end)
			draw_line(from, to, GUIDE_SHADOW, 7.0, true)
			draw_line(from, to, GUIDE_FOREGROUND, 4.0, true)
		cursor += cycle


func _on_state_changed(state: Enums.GameState) -> void:
	_can_drop = state == Enums.GameState.PLAYING and _cooldown_timer.is_stopped()
	_preview.visible = state == Enums.GameState.PLAYING and _can_drop
	if state != Enums.GameState.PLAYING:
		_is_aiming = false
	queue_redraw()


func _update_tiers() -> void:
	_current_tier = _next_tier
	_next_tier = _get_random_spawn_tier()
	GameManager.next_fruit_tier = _next_tier
	_refresh_preview()


func _refresh_preview() -> void:
	var data := FruitDatabase.get_fruit(_current_tier)
	if data and data.sprite:
		_preview.texture = data.sprite
		var texture_width := data.sprite_visual_width if data.sprite_visual_width > 0.0 else float(data.sprite.get_width())
		if texture_width > 0.0:
			var visual_scale := (data.radius * 2.0) / texture_width
			_preview.scale = Vector2.ONE * visual_scale
	_preview.position.y = -16.0


func _get_random_spawn_tier() -> Enums.FruitTier:
	return SPAWN_TIERS[randi() % SPAWN_TIERS.size()]


static func spawn_at(fruit_data: FruitData, world_pos: Vector2) -> Fruit:
	if not fruit_data:
		return null
	var fruit: Fruit = FruitDatabase.create_fruit(fruit_data.tier)
	if not fruit:
		return null
	fruit.data = fruit_data
	fruit.global_position = world_pos
	fruit.sleeping = false
	fruit.linear_velocity = Vector2(0, -70)
	fruit.angular_velocity = _random_drop_spin()

	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.call_deferred("add_child", fruit)
	return fruit


func _unhandled_input(event: InputEvent) -> void:
	if not _can_drop or GameManager.current_state != Enums.GameState.PLAYING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim()
		elif _is_aiming:
			_end_aim(get_global_mouse_position())
	elif event is InputEventMouseMotion and _is_aiming:
		_update_aim(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_aim()
			_update_aim(get_global_mouse_position())
		elif _is_aiming:
			_end_aim(get_global_mouse_position())
	elif event is InputEventScreenDrag and _is_aiming:
		_update_aim(get_global_mouse_position())


func _begin_aim() -> void:
	_is_aiming = true
	_aim_start = get_global_mouse_position()
	_aim_start.x = _clamp_x(_aim_start.x)


func _end_aim(release_pos: Vector2) -> void:
	_is_aiming = false
	var drop_x := _clamp_x(release_pos.x)
	if absf(drop_x - _aim_start.x) < 10.0:
		drop_x = _aim_start.x
	_drop_at(drop_x)


func _update_aim(mouse_pos: Vector2) -> void:
	var target_x := _clamp_x(mouse_pos.x)
	_preview.position.x = target_x - global_position.x
	queue_redraw()


func _clamp_x(value: float) -> float:
	var radius := FruitDatabase.get_collision_radius(_current_tier)
	var left_limit := global_position.x - max_x_spread + radius
	var right_limit := global_position.x + max_x_spread - radius
	return clampf(value, left_limit, right_limit)


func _raycast_to_floor(from: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 1200))
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	if not result.is_empty():
		return result.position
	return from + Vector2(0, 1200)

func _drop_at(x: float) -> void:
	if not _can_drop:
		return
	var fruit_data := FruitDatabase.get_fruit(_current_tier)
	if not fruit_data:
		return
	var dropped_tier := _current_tier

	_can_drop = false
	_preview.visible = false
	_cooldown_timer.start(drop_cooldown)

	var spawn_position := Vector2(x, global_position.y - 20.0)
	var fruit: Fruit = FruitDatabase.create_fruit(fruit_data.tier)
	if not fruit:
		_can_drop = true
		_preview.visible = true
		return
	fruit.data = fruit_data
	fruit.freeze = true
	fruit.linear_velocity = Vector2(0, 35)
	fruit.angular_velocity = _random_drop_spin()
	get_parent().add_child(fruit)
	fruit.global_position = spawn_position

	await get_tree().physics_frame
	if is_instance_valid(fruit):
		fruit.freeze = false
		fruit.sleeping = false

	_update_tiers()
	EventBus.fruit_dropped.emit(dropped_tier)


func _on_cooldown_ready() -> void:
	_can_drop = GameManager.current_state == Enums.GameState.PLAYING
	_preview.visible = _can_drop
	queue_redraw()


static func _random_drop_spin() -> float:
	var spin := randf_range(-0.9, 0.9)
	if absf(spin) < 0.28:
		spin = 0.28 if randf() > 0.5 else -0.28
	return spin
