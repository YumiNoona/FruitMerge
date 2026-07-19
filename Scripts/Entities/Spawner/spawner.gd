class_name Spawner
extends Node2D

const FruitFactoryScript = preload("res://Scripts/Entities/Fruit/fruit_factory.gd")

const SPAWN_TIERS: Array[Enums.FruitTier] = [
	Enums.FruitTier.CHERRY,
	Enums.FruitTier.BERRIES,
	Enums.FruitTier.STRAWBERRY,
	Enums.FruitTier.GRAPE,
]
const GUIDE_FALLBACK_COLOR := Color(1.0, 0.72, 0.2, 1.0)
const SAFE_LANE_COLOR := Color(0.50, 0.92, 0.35, 0.92)
const UI_FONT: FontFile = preload("res://Assets/Fonts/NERILLKID Trial.ttf")

@export var drop_cooldown: float = 0.55
@export var max_x_spread: float = 238.0
@export_category("Drop guide")
@export var guide_use_fruit_color: bool = true
@export var guide_override_color: Color = GUIDE_FALLBACK_COLOR
@export_range(4.0, 48.0, 1.0) var guide_dash_length: float = 16.0
@export_range(2.0, 40.0, 1.0) var guide_gap_length: float = 12.0
@export_range(0.0, 180.0, 1.0) var guide_scroll_speed: float = 64.0
@export_range(0.5, 8.0, 0.25) var guide_shadow_width: float = 4.5
@export_range(0.5, 8.0, 0.25) var guide_glow_width: float = 3.0
@export_range(0.5, 5.0, 0.25) var guide_core_width: float = 1.5
@export_range(0.0, 1.0, 0.01) var guide_shadow_opacity: float = 0.22
@export_range(0.0, 1.0, 0.01) var guide_glow_opacity: float = 0.30
@export_range(0.0, 1.0, 0.01) var guide_core_opacity: float = 0.94
@export_range(0.0, 1.0, 0.01) var guide_shadow_darkening: float = 0.62
@export_range(0.0, 1.0, 0.01) var guide_core_lightening: float = 0.14

var _can_drop: bool = true
var _is_aiming: bool = false
var _aim_start: Vector2
var _guide_phase: float = 0.0
var _guide_color: Color = GUIDE_FALLBACK_COLOR
var _current_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var _next_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var _reserve_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var _show_second_preview := false
var _safe_lane_timer := 0.0
var _safe_lane_global_x := 0.0
var _fruit_parent: Node

@onready var _cooldown_timer: Timer = $CooldownTimer
@onready var _preview: Sprite2D = $Preview


func _ready() -> void:
	_cooldown_timer.timeout.connect(_on_cooldown_ready)
	_next_tier = _get_random_spawn_tier()
	_reserve_tier = _get_random_spawn_tier()
	_publish_upcoming_fruits()
	EventBus.state_changed.connect(_on_state_changed)
	_refresh_preview()


func configure(fruit_parent: Node, playfield_half_width: float = -1.0) -> void:
	_fruit_parent = fruit_parent
	if playfield_half_width > 0.0:
		set_playfield_half_width(playfield_half_width)


func set_playfield_half_width(playfield_half_width: float) -> void:
	max_x_spread = maxf(40.0, playfield_half_width - 11.0)


func _process(delta: float) -> void:
	if _safe_lane_timer > 0.0:
		_safe_lane_timer = maxf(0.0, _safe_lane_timer - delta)
		queue_redraw()
	if GameManager.is_powerup_targeting:
		_preview.visible = false
		queue_redraw()
		return
	if not _can_drop or not GameManager.can_accept_gameplay_input():
		queue_redraw()
		return
	_preview.visible = true
	var target_x := _clamp_x(get_global_mouse_position().x)
	_preview.position.x = target_x - global_position.x
	var guide_cycle := maxf(guide_dash_length + guide_gap_length, 1.0)
	_guide_phase = fmod(_guide_phase + guide_scroll_speed * delta, guide_cycle)
	queue_redraw()


func _draw() -> void:
	if _safe_lane_timer > 0.0:
		_draw_safe_lane_hint()
	if GameManager.is_powerup_targeting or not _can_drop or not GameManager.can_accept_gameplay_input() or not _preview.visible:
		return
	var bottom_extent := FruitDatabase.get_collision_bottom_extent(_current_tier)
	var start := Vector2(_preview.position.x, _preview.position.y + bottom_extent + 9.0)
	var end := to_local(_raycast_to_floor(to_global(start)))
	_draw_animated_guide(start, end)


func _draw_animated_guide(start: Vector2, end: Vector2) -> void:
	var distance := end.y - start.y
	if distance <= 4.0:
		return
	var cycle := maxf(guide_dash_length + guide_gap_length, 1.0)
	var cursor := _guide_phase - cycle
	var guide_shadow := _guide_color.darkened(guide_shadow_darkening)
	guide_shadow.a = guide_shadow_opacity
	var guide_glow := _guide_color
	guide_glow.a = guide_glow_opacity
	var guide_core := _guide_color.lightened(guide_core_lightening)
	guide_core.a = guide_core_opacity
	while cursor < distance:
		var segment_start := maxf(cursor, 0.0)
		var segment_end := minf(cursor + guide_dash_length, distance)
		if segment_end > segment_start:
			var from := Vector2(start.x, start.y + segment_start)
			var to := Vector2(start.x, start.y + segment_end)
			draw_line(from, to, guide_shadow, guide_shadow_width, true)
			draw_line(from, to, guide_glow, guide_glow_width, true)
			draw_line(from, to, guide_core, guide_core_width, true)
		cursor += cycle


func _on_state_changed(state: Enums.GameState) -> void:
	_can_drop = state == Enums.GameState.PLAYING and _cooldown_timer.is_stopped()
	_preview.visible = state == Enums.GameState.PLAYING and _can_drop
	if state != Enums.GameState.PLAYING:
		_is_aiming = false
		_safe_lane_timer = 0.0
	queue_redraw()


func _update_tiers() -> void:
	_current_tier = _next_tier
	_next_tier = _reserve_tier
	_reserve_tier = _get_random_spawn_tier()
	_publish_upcoming_fruits()
	_refresh_preview()


func _publish_upcoming_fruits() -> void:
	GameManager.next_fruit_tier = _next_tier
	GameManager.second_next_fruit_tier = _reserve_tier
	GameManager.show_second_next_preview = _show_second_preview
	EventBus.next_fruit_changed.emit(_next_tier, _reserve_tier, _show_second_preview)


func set_second_preview_enabled(enabled: bool) -> void:
	_show_second_preview = enabled
	_publish_upcoming_fruits()


func reroll_next_fruit() -> bool:
	if GameManager.current_mode == Enums.GameMode.MISSIONS:
		return false
	var previous := _next_tier
	for _attempt in 5:
		_next_tier = SPAWN_TIERS[GameManager.get_random_spawn_index(SPAWN_TIERS.size())]
		if _next_tier != previous:
			break
	_publish_upcoming_fruits()
	return _next_tier != previous


func get_current_tier() -> int:
	return _current_tier


func show_safe_lane_hint(duration: float) -> void:
	_safe_lane_global_x = _find_safest_lane_x()
	_safe_lane_timer = maxf(duration, 0.1)
	queue_redraw()


func _find_safest_lane_x() -> float:
	var best_x := global_position.x
	var best_score := -INF
	var samples := 7
	for sample in samples:
		var ratio := float(sample) / float(samples - 1)
		var candidate_x := global_position.x + lerpf(-max_x_spread * 0.82, max_x_spread * 0.82, ratio)
		var pile_peak := global_position.y + 980.0
		for node in get_tree().get_nodes_in_group("fruits"):
			if not node is Fruit or not is_instance_valid(node) or node.is_merging:
				continue
			var fruit := node as Fruit
			if absf(fruit.global_position.x - candidate_x) > 62.0:
				continue
			var tier := fruit.data.tier as int if fruit.data else 0
			pile_peak = minf(pile_peak, fruit.global_position.y - FruitDatabase.get_collision_top_extent(tier))
		var center_preference := absf(candidate_x - global_position.x) * 0.025
		var score := pile_peak - center_preference
		if score > best_score:
			best_score = score
			best_x = candidate_x
	return best_x


func _draw_safe_lane_hint() -> void:
	var local_x := to_local(Vector2(_safe_lane_global_x, global_position.y)).x
	var fade := clampf(_safe_lane_timer / 0.35, 0.0, 1.0)
	var color := SAFE_LANE_COLOR
	color.a *= fade
	draw_string(UI_FONT, Vector2(local_x - 23.0, 118.0), "SAFE", HORIZONTAL_ALIGNMENT_CENTER, 46.0, 17, color)
	for index in 4:
		var y := 136.0 + float(index) * 28.0
		var arrow := PackedVector2Array([
			Vector2(local_x - 11.0, y),
			Vector2(local_x, y + 9.0),
			Vector2(local_x + 11.0, y),
		])
		draw_polyline(arrow, color, 3.0, true)


func _refresh_preview() -> void:
	_preview.texture = FruitDatabase.get_visual_texture(_current_tier)
	_preview.scale = FruitDatabase.get_visual_scale(_current_tier)
	_preview.position.y = -16.0
	_guide_color = FruitDatabase.get_guide_color(_current_tier) if guide_use_fruit_color else guide_override_color
	queue_redraw()


func _get_random_spawn_tier() -> Enums.FruitTier:
	var fallback := SPAWN_TIERS[GameManager.get_random_spawn_index(SPAWN_TIERS.size())]
	return MissionManager.take_spawn_tier(fallback) as Enums.FruitTier


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_powerup_targeting or not _can_drop or not GameManager.can_accept_gameplay_input():
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
	fruit.angular_velocity = FruitFactoryScript.random_drop_spin()
	var parent := _fruit_parent if is_instance_valid(_fruit_parent) else get_parent()
	parent.add_child(fruit)
	fruit.global_position = spawn_position
	EventBus.fruit_spawned.emit(fruit)

	await get_tree().physics_frame
	if is_instance_valid(fruit):
		fruit.freeze = false
		fruit.sleeping = false

	_update_tiers()
	GameManager.record_drop(dropped_tier)
	HapticManager.pulse(HapticManager.Feedback.DROP)
	EventBus.fruit_dropped.emit(dropped_tier)


func _on_cooldown_ready() -> void:
	_can_drop = GameManager.can_accept_gameplay_input()
	_preview.visible = _can_drop
	queue_redraw()
