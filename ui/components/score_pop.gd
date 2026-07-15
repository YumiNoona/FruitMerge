extends Control

var text: String = ""
var _t: float = 0.0
var _duration: float = 1.2

@onready var _label: Label = %Label


func set_text(val: String) -> void:
	text = val


func _ready() -> void:
	if _label:
		_label.text = text
	pivot_offset = size * 0.5
	modulate.a = 1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - 60.0, _duration).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.15).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(_duration - 0.4)
	t.finished.connect(queue_free)
