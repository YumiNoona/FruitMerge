class_name Fruit
extends RigidBody2D

const FruitFaceFactoryScript = preload("res://Scripts/Entities/Fruit/fruit_face_factory.gd")
const DIZZY_IMPACT: float = 280.0
const SLEEPY_IDLE_MIN: float = 8.0
const SLEEPY_IDLE_MAX: float = 12.0
const MERGE_EXIT_DURATION: float = 0.10

@export var data: FruitData
@export_range(0.0, 0.5, 0.005) var spawn_merge_lock_time: float = 0.10
@export var face_frames: SpriteFrames
@export var use_procedural_face: bool = false
@export_category("Scene-owned setup")
@export var use_scene_visuals: bool = false
@export var use_scene_collision: bool = false

var is_merging: bool = false
var _just_spawned: bool = true
var _contact_pairs: Array[Fruit] = []
var _prev_velocity: Vector2
var _last_activity_time: float = 0.0
var _visual_base_scale: Vector2 = Vector2.ONE
var _visual_tween: Tween

@onready var _sprite: Sprite2D = %Sprite2D
@onready var _collision: CollisionShape2D = %CollisionShape2D
@onready var _wake_timer: Timer = %WakeTimer
@onready var _idle_timer: Timer = %IdleTimer
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
	if _sprite:
		if use_scene_visuals:
			if not _sprite.texture and data.sprite:
				_sprite.texture = data.sprite
			_visual_base_scale = _sprite.scale
		elif data.sprite:
			_sprite.texture = data.sprite
			var tex_w: float = data.sprite_visual_width if data.sprite_visual_width > 0.0 else float(data.sprite.get_width())
			if tex_w > 0.0:
				var s: float = (data.radius * 2.0) / tex_w
				_visual_base_scale = Vector2(s, s)
				_sprite.scale = _visual_base_scale
				if face:
					face.scale = _visual_base_scale
	if _sprite:
		_sprite.self_modulate = data.color
		match EconomyManager.get_equipped_item(&"skin"):
			&"skin_pastel": _sprite.self_modulate *= Color(1.0, 0.88, 1.0, 1.0)
			&"skin_pineapple": _sprite.self_modulate *= Color(1.0, 0.93, 0.62, 1.0)
	if _collision and not use_scene_collision:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = data.radius
		_collision.shape = shape
	mass = data.mass
	call_deferred("_clear_just_spawned")


func _clear_just_spawned() -> void:
	await get_tree().create_timer(spawn_merge_lock_time).timeout
	_just_spawned = false
	_check_contacts_for_merge()


# ── emotion system ──

func _setup_face() -> void:
	if not face:
		return
	face.visible = use_procedural_face
	if not use_procedural_face:
		return
	if face_frames:
		face.sprite_frames = face_frames
	else:
		face.sprite_frames = FruitFaceFactoryScript.get_frames()
	face.play("idle")


func set_emotion(emotion: Enums.FruitEmotion, hold_time: float = -1.0) -> void:
	if not use_procedural_face or not face or is_merging:
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
	if body is Fruit and body != self:
		if not _contact_pairs.has(body):
			_contact_pairs.append(body)
		if _just_spawned:
			return
		if _should_initiate_merge(body):
			MergeService.try_merge(self, body)


func _check_contacts_for_merge() -> void:
	for body in _contact_pairs:
		if is_instance_valid(body) and _should_initiate_merge(body):
			MergeService.try_merge(self, body)
			return


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
	if not _sprite:
		return
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	_sprite.scale = _visual_base_scale * 0.72
	_visual_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(_sprite, "scale", _visual_base_scale, 0.28)


func play_land_squash() -> void:
	if not _sprite or is_merging:
		return
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(_sprite, "scale", _visual_base_scale * Vector2(1.12, 0.88), 0.06)
	_visual_tween.tween_property(_sprite, "scale", _visual_base_scale, 0.14).set_trans(Tween.TRANS_BACK)


func play_merge_exit_animation(on_complete: Callable) -> void:
	if not _sprite:
		on_complete.call()
		return
	_collision.set_deferred("disabled", true)
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	_visual_tween = create_tween().set_parallel(true)
	_visual_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_visual_tween.tween_property(_sprite, "scale", Vector2.ZERO, MERGE_EXIT_DURATION)
	_visual_tween.tween_property(_sprite, "modulate:a", 0.0, MERGE_EXIT_DURATION * 0.85)
	_visual_tween.chain().tween_callback(on_complete)


func start_merge_exit() -> void:
	play_merge_exit_animation(func(): queue_free())
