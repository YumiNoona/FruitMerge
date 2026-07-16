extends Control

var text: String = ""
var _duration: float = 1.2

@onready var _label: Label = %Label


func set_text(val: String) -> void:
	text = val


func _ready() -> void:
	if _label:
		_label.text = text
	pivot_offset = size * 0.5
	modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - 86.0, _duration)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.16)
	tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_delay(0.16)
	tween.tween_property(self, "rotation", deg_to_rad(randf_range(-4.0, 4.0)), 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(_duration - 0.4)
	tween.finished.connect(queue_free)
