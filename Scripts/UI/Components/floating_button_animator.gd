extends RefCounted

const DEFAULT_FLOAT_HEIGHT := 8.0
const DEFAULT_TRAVEL_DURATION := 1.1
const DEFAULT_TILT_RADIANS := 0.028
const FLOAT_TWEEN_META := &"floating_button_tween"


static func start(
	host: Node,
	button: Control,
	reduced_motion := false,
	float_height := DEFAULT_FLOAT_HEIGHT,
	travel_duration := DEFAULT_TRAVEL_DURATION
) -> Tween:
	if not is_instance_valid(host) or not is_instance_valid(button):
		return null
	var previous = button.get_meta(FLOAT_TWEEN_META) if button.has_meta(FLOAT_TWEEN_META) else null
	if previous is Tween and previous.is_valid():
		previous.kill()

	button.pivot_offset = button.size * 0.5
	var base_y := button.position.y
	var base_scale := button.scale
	var base_rotation := button.rotation
	if reduced_motion:
		return null

	var tween := host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta(FLOAT_TWEEN_META, tween)

	tween.tween_property(button, "position:y", base_y - float_height, travel_duration)
	tween.parallel().tween_property(button, "rotation", base_rotation - DEFAULT_TILT_RADIANS, travel_duration)
	tween.parallel().tween_property(button, "scale", base_scale * 1.035, travel_duration)

	tween.tween_property(button, "position:y", base_y + float_height * 0.2, travel_duration * 1.08)
	tween.parallel().tween_property(button, "rotation", base_rotation + DEFAULT_TILT_RADIANS * 0.75, travel_duration * 1.08)
	tween.parallel().tween_property(button, "scale", base_scale * 0.99, travel_duration * 1.08)

	tween.tween_property(button, "position:y", base_y, travel_duration * 0.5)
	tween.parallel().tween_property(button, "rotation", base_rotation, travel_duration * 0.5)
	tween.parallel().tween_property(button, "scale", base_scale, travel_duration * 0.5)
	return tween
