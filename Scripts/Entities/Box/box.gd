class_name Box
extends StaticBody2D

@export var danger_settle_time: float = 2.0
@export var danger_warning_delay: float = 0.45
@export var danger_settled_speed: float = 70.0
@export var danger_recovery_multiplier: float = 2.5
@export var danger_line_y: float = -400.0
@export var container_half_width: float = 250.0

var _danger_timer: float = 0.0
var _danger_active: bool = false
var _game_over_triggered: bool = false
var _entered_container: Dictionary = {}
var _danger_dwell: Dictionary = {}
var _worried_fruit: Fruit


func _ready() -> void:
	var wall_mat := load("res://Data/Resources/wall_physics.tres") as PhysicsMaterial
	if wall_mat:
		physics_material_override = wall_mat
	queue_redraw()


func _draw() -> void:
	var calm := Color(0.84, 0.42, 0.28, 0.58)
	var alert := Color(1.0, 0.3, 0.22, 0.95)
	var line_color := calm.lerp(alert, get_danger_ratio())
	draw_dashed_line(Vector2(-242, danger_line_y), Vector2(242, danger_line_y), line_color, 4.0, 14.0, true)


func _physics_process(delta: float) -> void:
	if _game_over_triggered:
		return
	var danger_world_y := global_position.y + danger_line_y
	var live_ids: Dictionary = {}
	var highest_dwell := 0.0
	var most_at_risk: Fruit
	for node in get_tree().get_nodes_in_group("fruits"):
		if not node is Fruit or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var fruit := node as Fruit
		var fruit_id := fruit.get_instance_id()
		live_ids[fruit_id] = true
		var tier := fruit.data.tier as int if fruit.data else -1
		var half_width := FruitDatabase.get_collision_radius(tier)
		var inside_width := absf(fruit.global_position.x - global_position.x) <= container_half_width + half_width
		var fruit_bottom := fruit.global_position.y + FruitDatabase.get_collision_bottom_extent(tier)
		if inside_width and fruit_bottom >= danger_world_y:
			_entered_container[fruit_id] = true

		var fruit_top := fruit.global_position.y - FruitDatabase.get_collision_top_extent(tier)
		var is_candidate := inside_width and is_danger_candidate(
			bool(_entered_container.get(fruit_id, false)),
			fruit.freeze,
			fruit.is_merging,
			fruit_top,
			danger_world_y,
			fruit.linear_velocity,
			fruit.sleeping,
			danger_settled_speed
		)
		var dwell := float(_danger_dwell.get(fruit_id, 0.0))
		if is_candidate:
			dwell += delta
		else:
			dwell = maxf(0.0, dwell - delta * danger_recovery_multiplier)
		_danger_dwell[fruit_id] = dwell
		if dwell > highest_dwell:
			highest_dwell = dwell
			most_at_risk = fruit

	_cleanup_missing_fruits(live_ids)
	_danger_timer = highest_dwell
	_update_warning_state(highest_dwell >= danger_warning_delay, most_at_risk)
	if highest_dwell >= danger_settle_time:
		_game_over_triggered = true
		GameManager.change_state(Enums.GameState.GAME_OVER)
	queue_redraw()


static func is_danger_candidate(
		has_entered: bool,
		is_frozen: bool,
		is_merging: bool,
		fruit_top_y: float,
		line_y: float,
		velocity: Vector2,
		is_sleeping: bool,
		settled_speed: float
) -> bool:
	return (
		has_entered
		and not is_frozen
		and not is_merging
		and fruit_top_y <= line_y
		and (is_sleeping or velocity.length() <= settled_speed)
	)


func _update_warning_state(should_warn: bool, most_at_risk: Fruit) -> void:
	if should_warn:
		if is_instance_valid(most_at_risk) and most_at_risk != _worried_fruit:
			_restore_worried_fruit()
			_worried_fruit = most_at_risk
			_worried_fruit.set_emotion(Enums.FruitEmotion.WORRIED)
		if not _danger_active:
			_danger_active = true
			EventBus.danger_line_entered.emit()
	elif _danger_active:
		_danger_active = false
		_restore_worried_fruit()
		EventBus.danger_line_exited.emit()


func _restore_worried_fruit() -> void:
	if is_instance_valid(_worried_fruit) and not _worried_fruit.is_merging:
		_worried_fruit.set_emotion(Enums.FruitEmotion.IDLE)
	_worried_fruit = null


func _cleanup_missing_fruits(live_ids: Dictionary) -> void:
	for fruit_id in _danger_dwell.keys():
		if not live_ids.has(fruit_id):
			_danger_dwell.erase(fruit_id)
			_entered_container.erase(fruit_id)


func _reset_danger_state() -> void:
	_danger_timer = 0.0
	_danger_dwell.clear()
	_entered_container.clear()
	if _danger_active:
		_danger_active = false
		EventBus.danger_line_exited.emit()
	_restore_worried_fruit()
	queue_redraw()


func get_danger_ratio() -> float:
	return clampf(_danger_timer / maxf(danger_settle_time, 0.01), 0.0, 1.0)
