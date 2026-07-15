extends Node2D

@export var duration: float = 0.4

var _t: float = 0.0


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_t += delta
	var p: float = _t / duration
	var s: float = 1.0 + sin(p * PI) * 0.5
	scale = Vector2(s, s)
	modulate.a = 1.0 - p

	if _t >= duration:
		queue_free()
