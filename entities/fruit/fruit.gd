class_name Fruit
extends RigidBody2D

const FACE_SIZE: int = 24
const DIZZY_IMPACT: float = 280.0
const SLEEPY_IDLE_MIN: float = 8.0
const SLEEPY_IDLE_MAX: float = 12.0

@export var data: FruitData
@export var merge_cooldown: float = 0.4
@export var face_frames: SpriteFrames

var is_merging: bool = false
var _just_spawned: bool = true
var _contact_pairs: Array[Fruit] = []
var _prev_velocity: Vector2
var _last_activity_time: float = 0.0

@onready var _sprite: Sprite2D = %Sprite2D
@onready var _collision: CollisionShape2D = %CollisionShape2D
@onready var _wake_timer: Timer = %WakeTimer
@onready var _idle_timer: Timer = %IdleTimer
@onready var _anim_player: AnimationPlayer = %AnimationPlayer
@onready var face: AnimatedSprite2D = %Face


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	_apply_data()
	_setup_face()
	_play_spawn_animation()
	set_emotion(Enums.FruitEmotion.HAPPY, 0.5)
	if _wake_timer:
		_wake_timer.timeout.connect(_wake_up_check)
	if _idle_timer:
		_idle_timer.timeout.connect(_on_idle_timeout)
	_reset_idle_timer()
	_last_activity_time = Time.get_ticks_msec() / 1000.0


# ── data application ──

func _apply_data() -> void:
	if not data:
		return
	if _sprite and data.sprite:
		_sprite.texture = data.sprite
	if _sprite:
		_sprite.self_modulate = data.color
	if _collision:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = data.radius
		_collision.shape = shape
	if freeze:
		freeze = true
	mass = data.mass
	call_deferred("_clear_just_spawned")


func _clear_just_spawned() -> void:
	await get_tree().create_timer(0.1).timeout
	_just_spawned = false


# ── emotion system ──

func _setup_face() -> void:
	if not face:
		return
	if face_frames:
		face.sprite_frames = face_frames
	else:
		face.sprite_frames = _build_procedural_frames()
	face.play("idle")


func _build_procedural_frames() -> SpriteFrames:
	var sf: SpriteFrames = SpriteFrames.new()
	var emotions: Array[Enums.FruitEmotion] = [
		Enums.FruitEmotion.IDLE,
		Enums.FruitEmotion.HAPPY,
		Enums.FruitEmotion.EXCITED,
		Enums.FruitEmotion.DIZZY,
		Enums.FruitEmotion.WORRIED,
		Enums.FruitEmotion.SLEEPY,
	]
	for em: Enums.FruitEmotion in emotions:
		var img: Image = _make_emotion_image(em)
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		var anim_name: String = Enums.FruitEmotion.keys()[em].to_lower()
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 1.0)
		sf.set_animation_loop(anim_name, false)
		sf.add_frame(anim_name, tex)
	return sf


func _make_emotion_image(emotion: Enums.FruitEmotion) -> Image:
	var img: Image = Image.create(FACE_SIZE, FACE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var c: Color = Color.BLACK
	var w: Color = Color.WHITE
	match emotion:
		Enums.FruitEmotion.IDLE:
			_draw_eye(img, 6, 8, c, false)
			_draw_eye(img, 16, 8, c, false)
			_draw_smile(img, 9, 15, c)
		Enums.FruitEmotion.HAPPY:
			_draw_eye(img, 5, 7, c, true)
			_draw_eye(img, 17, 7, c, true)
			_draw_smile(img, 9, 15, c)
			# blush
			_draw_rect(img, 9, 12, 3, 2, Color(1, 0.5, 0.6, 0.5))
		Enums.FruitEmotion.EXCITED:
			_draw_star_eye(img, 6, 8, c)
			_draw_star_eye(img, 16, 8, c)
			_draw_rect(img, 9, 14, 6, 3, c)
		Enums.FruitEmotion.DIZZY:
			# X eyes
			_draw_x_eye(img, 5, 7, 4, c)
			_draw_x_eye(img, 15, 7, 4, c)
			_draw_wavy_mouth(img, 9, 15, 6, c)
		Enums.FruitEmotion.WORRIED:
			_draw_rect(img, 5, 7, 4, 4, w)
			_draw_pixel(img, 6, 8, c)
			_draw_pixel(img, 7, 8, c)
			_draw_rect(img, 15, 7, 4, 4, w)
			_draw_pixel(img, 16, 8, c)
			_draw_pixel(img, 17, 8, c)
			_draw_pixel(img, 11, 17, c)
			_draw_pixel(img, 12, 17, c)
		Enums.FruitEmotion.SLEEPY:
			# Closed eyes (horizontal lines)
			_draw_rect(img, 5, 8, 4, 1, c)
			_draw_rect(img, 15, 8, 4, 1, c)
			_draw_smile(img, 9, 16, c)
	return img


func _draw_eye(img: Image, x: int, y: int, col: Color, happy: bool) -> void:
	if happy:
		# ^ shape for happy: two pixels wide
		_draw_pixel(img, x + 1, y, col)
		_draw_pixel(img, x, y + 1, col)
		_draw_pixel(img, x + 2, y + 1, col)
	else:
		_draw_rect(img, x, y, 2, 2, col)


func _draw_star_eye(img: Image, x: int, y: int, col: Color) -> void:
	var offsets: Array[int] = [0, 1, 2]
	for dx: int in offsets:
		for dy: int in offsets:
			var sum: int = dx + dy
			if sum == 0 or sum == 2:
				_draw_pixel(img, x + dx, y + dy, col)


func _draw_x_eye(img: Image, x: int, y: int, s: int, col: Color) -> void:
	for i: int in range(s):
		_draw_pixel(img, x + i, y + i, col)
		_draw_pixel(img, x + i, y + s - 1 - i, col)


func _draw_smile(img: Image, x: int, y: int, col: Color) -> void:
	_draw_pixel(img, x, y, col)
	_draw_pixel(img, x + 1, y + 1, col)
	for i: int in range(4):
		_draw_pixel(img, x + 2 + i, y + 2, col)
	_draw_pixel(img, x + 4, y + 1, col)
	_draw_pixel(img, x + 5, y, col)


func _draw_wavy_mouth(img: Image, x: int, y: int, _w: int, col: Color) -> void:
	_draw_pixel(img, x, y, col)
	_draw_pixel(img, x + 1, y - 1, col)
	_draw_pixel(img, x + 2, y, col)
	_draw_pixel(img, x + 3, y - 1, col)
	_draw_pixel(img, x + 4, y, col)
	_draw_pixel(img, x + 5, y - 1, col)


func _draw_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < FACE_SIZE and y >= 0 and y < FACE_SIZE:
		img.set_pixel(x, y, col)


func _draw_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for dx: int in range(w):
		for dy: int in range(h):
			_draw_pixel(img, x + dx, y + dy, col)


func set_emotion(emotion: Enums.FruitEmotion, hold_time: float = -1.0) -> void:
	if not face or is_merging:
		return
	var anim_name: String = Enums.FruitEmotion.keys()[emotion].to_lower()
	if not face.sprite_frames or not face.sprite_frames.has_animation(anim_name):
		return
	face.play(anim_name)
	if hold_time > 0.0:
		await get_tree().create_timer(hold_time).timeout
		if is_instance_valid(self) and not is_merging:
			face.play("idle")


func _reset_idle_timer() -> void:
	_last_activity_time = Time.get_ticks_msec() / 1000.0
	if _idle_timer:
		_idle_timer.start(randf_range(SLEEPY_IDLE_MIN, SLEEPY_IDLE_MAX))


func _on_idle_timeout() -> void:
	if sleeping and not is_merging:
		set_emotion(Enums.FruitEmotion.SLEEPY)
		if _idle_timer:
			_idle_timer.start(randf_range(SLEEPY_IDLE_MIN, SLEEPY_IDLE_MAX))


# ── impact detection ──

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var vel: Vector2 = state.linear_velocity
	var prev_len: float = _prev_velocity.length()
	var curr_len: float = vel.length()
	if prev_len - curr_len > DIZZY_IMPACT and curr_len < 100.0 and not _just_spawned:
		_on_hard_landing(prev_len - curr_len)
	_prev_velocity = vel


func _on_hard_landing(impact: float) -> void:
	play_land_squash()
	if impact > DIZZY_IMPACT + 150.0:
		set_emotion(Enums.FruitEmotion.DIZZY, 1.0)
		_reset_idle_timer()


# ── merge ──

func _on_body_entered(body: Node) -> void:
	_reset_idle_timer()
	if _just_spawned:
		return
	if body is Fruit and body != self:
		if not _contact_pairs.has(body):
			_contact_pairs.append(body)
		if _should_initiate_merge(body):
			MergeService.try_merge(self, body)


func _should_initiate_merge(body: Fruit) -> bool:
	if body.get_instance_id() < get_instance_id():
		return false
	if _just_spawned or body._just_spawned:
		return false
	return true


func _on_body_exited(body: Node) -> void:
	if body is Fruit:
		_contact_pairs.erase(body)


# ── wake-from-sleep ──

func _on_sleeping_state_changed() -> void:
	if not sleeping:
		_reset_idle_timer()
		if face and face.animation == "sleepy":
			set_emotion(Enums.FruitEmotion.IDLE)
	if _wake_timer and sleeping:
		_wake_timer.start(0.4)


func _wake_up_check() -> void:
	for pair in _contact_pairs:
		if is_instance_valid(pair) and not pair.sleeping and not pair._just_spawned:
			if _should_initiate_merge(pair):
				MergeService.try_merge(self, pair)
				return


# ── animations ──

func _play_spawn_animation() -> void:
	if not _anim_player:
		return
	if _anim_player.has_animation_library("fruit_lib"):
		_anim_player.play("fruit_lib/spawn")
		return
	var lib: AnimationLibrary = AnimationLibrary.new()
	var anim: Animation = Animation.new()
	anim.length = 0.3
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, ".:scale")
	anim.track_insert_key(track, 0.0, Vector2(0.7, 0.7))
	anim.track_insert_key(track, 0.15, Vector2(1.15, 0.85))
	anim.track_insert_key(track, 0.3, Vector2(1.0, 1.0))
	lib.add_animation("spawn", anim)
	_anim_player.add_animation_library("fruit_lib", lib)
	_anim_player.play("fruit_lib/spawn")


func play_land_squash() -> void:
	if not _anim_player:
		return
	var lib: AnimationLibrary = _anim_player.get_animation_library("fruit_lib")
	if not lib:
		return
	if not lib.has_animation("land"):
		var anim: Animation = Animation.new()
		anim.length = 0.2
		var track: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track, ".:scale")
		anim.track_insert_key(track, 0.0, Vector2(1.0, 1.0))
		anim.track_insert_key(track, 0.05, Vector2(1.2, 0.8))
		anim.track_insert_key(track, 0.2, Vector2(1.0, 1.0))
		lib.add_animation("land", anim)
	_anim_player.play("fruit_lib/land")


func play_merge_exit_animation(on_complete: Callable) -> void:
	if not _anim_player:
		on_complete.call()
		return
	var lib: AnimationLibrary = _anim_player.get_animation_library("fruit_lib")
	if not lib:
		on_complete.call()
		return
	if not lib.has_animation("merge_exit"):
		var anim: Animation = Animation.new()
		anim.length = 0.2
		var track_s: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_s, ".:scale")
		anim.track_insert_key(track_s, 0.0, Vector2(1.0, 1.0))
		anim.track_insert_key(track_s, 0.2, Vector2(0.0, 0.0))
		var track_m: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_m, ".:modulate")
		anim.track_insert_key(track_m, 0.0, Color.WHITE)
		anim.track_insert_key(track_m, 0.2, Color(1, 1, 1, 0))
		lib.add_animation("merge_exit", anim)
	_anim_player.play("fruit_lib/merge_exit")
	_anim_player.animation_finished.connect(on_complete.bind(), CONNECT_ONE_SHOT)


func start_merge_exit() -> void:
	play_merge_exit_animation(func(): queue_free())
