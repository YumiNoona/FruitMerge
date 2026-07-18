class_name CozyButton
extends Button

@export var hover_scale: float = 1.025
@export var pressed_scale: float = 0.965

var _motion_tween: Tween


func _ready() -> void:
	resized.connect(_refresh_pivot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_refresh_pivot()


func _refresh_pivot() -> void:
	pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	if not disabled:
		_animate_scale(Vector2.ONE * hover_scale, 0.12)


func _on_mouse_exited() -> void:
	_animate_scale(Vector2.ONE, 0.14)


func _on_button_down() -> void:
	if not disabled:
		HapticManager.pulse(HapticManager.Feedback.TAP)
		_animate_scale(Vector2.ONE * pressed_scale, 0.07)


func _on_button_up() -> void:
	var target := Vector2.ONE * hover_scale if is_hovered() else Vector2.ONE
	_animate_scale(target, 0.12)


func _animate_scale(target: Vector2, duration: float) -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "scale", target, duration)
