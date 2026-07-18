class_name FruitFaceFactory
extends RefCounted

const FACE_SIZE := 24
static var _cached_frames: SpriteFrames


static func get_frames() -> SpriteFrames:
	if _cached_frames:
		return _cached_frames
	_cached_frames = SpriteFrames.new()
	for emotion in Enums.FruitEmotion.size():
		var image := _make_emotion_image(emotion as Enums.FruitEmotion)
		var texture := ImageTexture.create_from_image(image)
		var animation_name: String = Enums.FruitEmotion.keys()[emotion].to_lower()
		_cached_frames.add_animation(animation_name)
		_cached_frames.set_animation_speed(animation_name, 1.0)
		_cached_frames.set_animation_loop(animation_name, false)
		_cached_frames.add_frame(animation_name, texture)
	return _cached_frames


static func _make_emotion_image(emotion: Enums.FruitEmotion) -> Image:
	var image := Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var dark := Color.BLACK
	match emotion:
		Enums.FruitEmotion.IDLE:
			_draw_eye(image, 6, 8, dark, false); _draw_eye(image, 16, 8, dark, false); _draw_smile(image, 9, 15, dark)
		Enums.FruitEmotion.HAPPY:
			_draw_eye(image, 5, 7, dark, true); _draw_eye(image, 17, 7, dark, true); _draw_smile(image, 9, 15, dark)
			_draw_rect(image, 9, 12, 3, 2, Color(1, 0.5, 0.6, 0.5))
		Enums.FruitEmotion.EXCITED:
			_draw_star_eye(image, 6, 8, dark); _draw_star_eye(image, 16, 8, dark); _draw_rect(image, 9, 14, 6, 3, dark)
		Enums.FruitEmotion.DIZZY:
			_draw_x_eye(image, 5, 7, 4, dark); _draw_x_eye(image, 15, 7, 4, dark); _draw_wavy_mouth(image, 9, 15, dark)
		Enums.FruitEmotion.WORRIED:
			_draw_rect(image, 5, 7, 4, 4, Color.WHITE); _draw_rect(image, 15, 7, 4, 4, Color.WHITE)
			_draw_pixel(image, 6, 8, dark); _draw_pixel(image, 7, 8, dark); _draw_pixel(image, 16, 8, dark); _draw_pixel(image, 17, 8, dark)
			_draw_pixel(image, 11, 17, dark); _draw_pixel(image, 12, 17, dark)
		Enums.FruitEmotion.SLEEPY:
			_draw_rect(image, 5, 8, 4, 1, dark); _draw_rect(image, 15, 8, 4, 1, dark); _draw_smile(image, 9, 16, dark)
	return image


static func _draw_eye(image: Image, x: int, y: int, color: Color, happy: bool) -> void:
	if happy:
		_draw_pixel(image, x + 1, y, color); _draw_pixel(image, x, y + 1, color); _draw_pixel(image, x + 2, y + 1, color)
	else:
		_draw_rect(image, x, y, 2, 2, color)


static func _draw_star_eye(image: Image, x: int, y: int, color: Color) -> void:
	for dx in 3:
		for dy in 3:
			if dx + dy == 0 or dx + dy == 2: _draw_pixel(image, x + dx, y + dy, color)


static func _draw_x_eye(image: Image, x: int, y: int, size: int, color: Color) -> void:
	for index in size:
		_draw_pixel(image, x + index, y + index, color); _draw_pixel(image, x + index, y + size - 1 - index, color)


static func _draw_smile(image: Image, x: int, y: int, color: Color) -> void:
	_draw_pixel(image, x, y, color); _draw_pixel(image, x + 1, y + 1, color)
	for index in 4: _draw_pixel(image, x + 2 + index, y + 2, color)
	_draw_pixel(image, x + 4, y + 1, color); _draw_pixel(image, x + 5, y, color)


static func _draw_wavy_mouth(image: Image, x: int, y: int, color: Color) -> void:
	for index in 6: _draw_pixel(image, x + index, y - posmod(index, 2), color)


static func _draw_pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < FACE_SIZE and y >= 0 and y < FACE_SIZE: image.set_pixel(x, y, color)


static func _draw_rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for dx in width:
		for dy in height: _draw_pixel(image, x + dx, y + dy, color)
