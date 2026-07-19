class_name Fruit
extends RigidBody2D

const FruitFaceFactoryScript = preload("res://Scripts/Entities/Fruit/fruit_face_factory.gd")
const DIZZY_IMPACT: float = 280.0
const DEFAULT_IMPACT_MIN_SPEED: float = 85.0
const DEFAULT_IMPACT_FULL_SPEED: float = 430.0
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
@export_category("Impact feel")
@export_range(40.0, 240.0, 5.0, "suffix:px/s") var impact_min_speed := DEFAULT_IMPACT_MIN_SPEED
@export_range(240.0, 700.0, 10.0, "suffix:px/s") var impact_full_speed := DEFAULT_IMPACT_FULL_SPEED
@export_range(0.0, 30.0, 0.5, "suffix:px/s") var impact_side_velocity := 17.0
@export_range(0.0, 24.0, 0.5, "suffix:px/s") var impact_lift_velocity := 9.0
@export_range(0.0, 2.0, 0.05, "suffix:rad/s") var impact_spin_velocity := 0.75
@export_range(0.02, 0.18, 0.005, "suffix:s") var impact_compress_time := 0.055
@export_range(0.08, 0.4, 0.01, "suffix:s") var impact_recover_time := 0.22
@export_range(0.0, 1.0, 0.01) var impact_visual_strength := 0.10
@export_range(0.05, 0.3, 0.01, "suffix:s") var impact_cooldown := 0.12
@export_range(0.0, 1.0, 0.01) var lively_linear_damp := 0.18
@export_range(0.0, 1.5, 0.01) var lively_angular_damp := 0.32

var is_merging: bool = false
var _just_spawned: bool = true
var _contact_pairs: Array[Fruit] = []
var _prev_velocity: Vector2
var _last_activity_time: float = 0.0
var _visual_base_scale: Vector2 = Vector2.ONE
var _visual_base_rotation := 0.0
var _visual_tween: Tween
var _last_impact_msec := -1000
var _base_gravity_scale := 1.0
var _base_linear_damp := 0.0
var _base_angular_damp := 0.0
var _temporary_physics_token := 0

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
	_base_gravity_scale = gravity_scale
	_base_linear_damp = linear_damp
	_base_angular_damp = angular_damp
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
		_visual_base_rotation = _sprite.rotation
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
	linear_damp = lively_linear_damp
	angular_damp = lively_angular_damp
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
		var other := body as Fruit
		if not _contact_pairs.has(other):
			_contact_pairs.append(other)
		_handle_fruit_impact(other)
		if _just_spawned:
			return
		if _should_initiate_merge(other):
			MergeService.try_merge(self, other)


func _handle_fruit_impact(other: Fruit) -> void:
	if not is_instance_valid(other) or is_merging or other.is_merging:
		return
	if get_instance_id() > other.get_instance_id():
		return
	if data and other.data and data.tier == other.data.tier:
		# Matching contacts immediately become a merge and already have stronger juice.
		return
	var previous_relative := _prev_velocity - other._prev_velocity
	var current_relative := linear_velocity - other.linear_velocity
	var relative_speed := maxf(previous_relative.length(), current_relative.length())
	var minimum_speed := minf(impact_min_speed, other.impact_min_speed)
	var full_speed := maxf(minimum_speed + 1.0, minf(impact_full_speed, other.impact_full_speed))
	var strength := calculate_impact_strength(relative_speed, minimum_speed, full_speed)
	if strength <= 0.0:
		return
	var source: Fruit = self if _prev_velocity.length_squared() >= other._prev_velocity.length_squared() else other
	var receiver: Fruit = other if source == self else self
	var direction_sign := signf(receiver.global_position.x - source.global_position.x)
	if is_zero_approx(direction_sign):
		direction_sign = -1.0 if receiver.get_instance_id() % 2 == 0 else 1.0
	if receiver._receive_fruit_impact(strength, direction_sign, source.mass):
		source._play_impact_wobble(strength * 0.82, -direction_sign)
		var tier := mini(data.tier as int, other.data.tier as int) if data and other.data else 0
		AudioManager.play_fruit_impact(relative_speed, tier, (global_position + other.global_position) * 0.5)
		if strength >= 0.62 and GameManager.current_state == Enums.GameState.PLAYING:
			HapticManager.pulse(HapticManager.Feedback.DROP)


func _receive_fruit_impact(strength: float, direction_sign: float, source_mass: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_impact_msec < roundi(impact_cooldown * 1000.0):
		return false
	_last_impact_msec = now
	_play_impact_wobble(strength, direction_sign)
	if strength < 0.12 or freeze or is_merging:
		return true
	sleeping = false
	var mass_ratio := clampf(sqrt(maxf(source_mass, 0.01) / maxf(mass, 0.01)), 0.55, 1.45)
	var delta_velocity := Vector2(
		direction_sign * impact_side_velocity * strength * mass_ratio,
		-impact_lift_velocity * strength * mass_ratio
	)
	apply_central_impulse(delta_velocity * mass)
	angular_velocity += direction_sign * impact_spin_velocity * strength * mass_ratio
	return true


static func calculate_impact_strength(relative_speed: float, minimum_speed: float, full_speed: float) -> float:
	if relative_speed <= minimum_speed:
		return 0.0
	return smoothstep(minimum_speed, maxf(minimum_speed + 1.0, full_speed), relative_speed)


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
	_sprite.rotation = _visual_base_rotation
	_visual_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(_sprite, "scale", _visual_base_scale, 0.28)


func play_land_squash() -> void:
	if not _sprite or is_merging:
		return
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	_play_impact_wobble(1.0, -1.0 if angular_velocity > 0.0 else 1.0)


func apply_gentle_landing(duration: float, gravity_ratio: float) -> void:
	_temporary_physics_token += 1
	var token := _temporary_physics_token
	gravity_scale = clampf(gravity_ratio, 0.25, 0.9)
	linear_damp = maxf(_base_linear_damp, 1.25)
	angular_damp = maxf(_base_angular_damp, 2.4)
	linear_velocity.x *= 0.58
	angular_velocity *= 0.32
	_restore_temporary_physics(duration, token)


func apply_temporary_calm(duration: float, velocity_retained: float) -> void:
	_temporary_physics_token += 1
	var token := _temporary_physics_token
	var retained := clampf(velocity_retained, 0.15, 0.85)
	linear_velocity *= retained
	angular_velocity *= retained * 0.7
	linear_damp = maxf(_base_linear_damp, 3.2)
	angular_damp = maxf(_base_angular_damp, 5.0)
	sleeping = false
	_restore_temporary_physics(duration, token)


func _restore_temporary_physics(duration: float, token: int) -> void:
	await get_tree().create_timer(maxf(duration, 0.05)).timeout
	if not is_instance_valid(self) or token != _temporary_physics_token:
		return
	gravity_scale = _base_gravity_scale
	linear_damp = _base_linear_damp
	angular_damp = _base_angular_damp


func _play_impact_wobble(strength: float, direction_sign: float) -> void:
	if not _sprite or is_merging or bool(SaveManager.get_setting("reduced_motion", false)):
		return
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	var amount := clampf(strength, 0.0, 1.0) * impact_visual_strength
	var tilt := direction_sign * deg_to_rad(5.0) * clampf(strength, 0.0, 1.0)
	var compressed := _visual_base_scale * Vector2(1.0 + amount, 1.0 - amount * 0.82)
	var rebound := _visual_base_scale * Vector2(1.0 - amount * 0.34, 1.0 + amount * 0.42)
	_visual_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(_sprite, "scale", compressed, impact_compress_time)
	_visual_tween.parallel().tween_property(_sprite, "rotation", _visual_base_rotation + tilt, impact_compress_time)
	_visual_tween.tween_property(_sprite, "scale", rebound, impact_recover_time * 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_visual_tween.parallel().tween_property(_sprite, "rotation", _visual_base_rotation - tilt * 0.32, impact_recover_time * 0.38)
	_visual_tween.tween_property(_sprite, "scale", _visual_base_scale, impact_recover_time * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_visual_tween.parallel().tween_property(_sprite, "rotation", _visual_base_rotation, impact_recover_time * 0.62)


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
