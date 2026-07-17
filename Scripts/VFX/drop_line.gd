extends Node2D

@export var line_width: float = 2.0
@export var color: Color = Color(1, 1, 1, 0.3)
@export var duration: float = 0.3
@export var length: float = 200.0

var _t: float = 0.0

@onready var _line: Line2D = $Line2D


func _ready() -> void:
	_line.width = line_width
	_line.default_color = color
	_line.add_point(Vector2(0, 0))
	_line.add_point(Vector2(0, length))


func _process(delta: float) -> void:
	_t += delta
	var p := _t / duration
	modulate.a = 1.0 - p
	if _t >= duration:
		queue_free()
