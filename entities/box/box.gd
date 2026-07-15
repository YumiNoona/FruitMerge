class_name Box
extends StaticBody2D

@export var danger_settle_time: float = 2.0
@export var danger_line_y: float = -400.0
@export var overflow_line_y: float = 40.0

var _danger_area: Area2D
var _danger_timer: float = 0.0
var _fruits_in_danger: int = 0
var _danger_active: bool = false
var _game_over_triggered: bool = false


func _ready() -> void:
	var wall_mat := load("res://data/resources/wall_physics.tres") as PhysicsMaterial
	if wall_mat:
		physics_material_override = wall_mat
	_setup_danger_area()


func _setup_danger_area() -> void:
	_danger_area = Area2D.new()
	_danger_area.name = "DangerArea"
	_danger_area.position = Vector2(0, danger_line_y)
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(500, 20)
	collision.shape = rect
	collision.position = Vector2(0, 0)
	_danger_area.add_child(collision)
	_danger_area.body_entered.connect(_on_body_entered_danger)
	_danger_area.body_exited.connect(_on_body_exited_danger)
	add_child(_danger_area)


func _process(delta: float) -> void:
	if _game_over_triggered:
		return
	if _danger_active:
		_danger_timer += delta
		if _danger_timer >= danger_settle_time:
			_game_over_triggered = true
			GameManager.change_state(Enums.GameState.GAME_OVER)
	else:
		_danger_timer = max(0.0, _danger_timer - delta * 0.5)


func _on_body_entered_danger(body: Node) -> void:
	if body is Fruit:
		_fruits_in_danger += 1
		body.set_emotion(Enums.FruitEmotion.WORRIED)
		if _fruits_in_danger == 1 and not _danger_active:
			_danger_active = true
			EventBus.danger_line_entered.emit()


func _on_body_exited_danger(body: Node) -> void:
	if body is Fruit:
		_fruits_in_danger = max(0, _fruits_in_danger - 1)
		if is_instance_valid(body) and not body.is_merging:
			body.set_emotion(Enums.FruitEmotion.IDLE)
		if _fruits_in_danger == 0 and _danger_active:
			_danger_active = false
			_danger_timer = 0.0
			EventBus.danger_line_exited.emit()


func _check_overflow() -> void:
	for fruit in get_tree().get_nodes_in_group("fruits"):
		if not is_instance_valid(fruit):
			continue
		if fruit.global_position.y <= overflow_line_y:
			_game_over_triggered = true
			GameManager.change_state(Enums.GameState.GAME_OVER)
			return


func get_danger_ratio() -> float:
	return clampf(_danger_timer / danger_settle_time, 0.0, 1.0)
