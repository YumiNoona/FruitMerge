class_name MobileSafeArea
extends RefCounted


static func get_viewport_insets(viewport: Viewport) -> Vector4:
	# Desktop safe areas describe the monitor/work area (including taskbar), not
	# a notch inside the game window. Applying that rectangle to an embedded or
	# resized PC game pushes controls outside the portrait viewport.
	if OS.get_name() not in ["Android", "iOS"]:
		return Vector4.ZERO
	var visible := viewport.get_visible_rect()
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	if safe.size == Vector2i.ZERO or window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var scale_x := visible.size.x / float(window_size.x)
	var scale_y := visible.size.y / float(window_size.y)
	var left := float(safe.position.x) * scale_x
	var top := float(safe.position.y) * scale_y
	var right := float(window_size.x - safe.end.x) * scale_x
	var bottom := float(window_size.y - safe.end.y) * scale_y
	return Vector4(left, top, right, bottom)


static func apply_top_inset(control: Control, base_top: float) -> void:
	var insets := get_viewport_insets(control.get_viewport())
	control.position.y = base_top + insets.y


static func apply_bottom_inset(control: Control, base_bottom_offset: float) -> void:
	var insets := get_viewport_insets(control.get_viewport())
	control.position.y = base_bottom_offset - insets.w
