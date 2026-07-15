class_name Fruit
extends RigidBody2D

@export var data: FruitData
@export var merge_cooldown: float = 0.4

var is_merging: bool = false
var _just_spawned: bool = true
var _contact_pairs: Array[Fruit] = []

@onready var _sprite: Sprite2D = %Sprite2D
@onready var _collision: CollisionShape2D = %CollisionShape2D
@onready var _wake_timer: Timer = %WakeTimer
@onready var _anim_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sleeping_state_changed.connect(_on_sleeping_state_changed)
	_apply_data()
	_play_spawn_animation()
	if _wake_timer:
		_wake_timer.timeout.connect(_wake_up_check)


func _apply_data() -> void:
	if not data:
		return
	if _sprite and data.sprite:
		_sprite.texture = data.sprite
	if _sprite:
		_sprite.self_modulate = data.color
	if _collision:
		var shape := CircleShape2D.new()
		shape.radius = data.radius
		_collision.shape = shape
	if freeze:
		freeze = true
	mass = data.mass
	call_deferred("_clear_just_spawned")


func _clear_just_spawned() -> void:
	await get_tree().create_timer(0.1).timeout
	_just_spawned = false


func _play_spawn_animation() -> void:
	if not _anim_player:
		return
	if _anim_player.has_animation_library("fruit_lib"):
		_anim_player.play("fruit_lib/spawn")
		return
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 0.3
	var track := anim.add_track(Animation.TYPE_VALUE)
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
	var lib := _anim_player.get_animation_library("fruit_lib")
	if not lib or lib.has_animation("land"):
		return
	var anim := Animation.new()
	anim.length = 0.2
	var track := anim.add_track(Animation.TYPE_VALUE)
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
	var lib := _anim_player.get_animation_library("fruit_lib")
	if not lib or lib.has_animation("merge_exit"):
		on_complete.call()
		return
	var anim := Animation.new()
	anim.length = 0.2
	var track_s := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_s, ".:scale")
	anim.track_insert_key(track_s, 0.0, Vector2(1.0, 1.0))
	anim.track_insert_key(track_s, 0.2, Vector2(0.0, 0.0))
	var track_m := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_m, ".:modulate")
	anim.track_insert_key(track_m, 0.0, Color.WHITE)
	anim.track_insert_key(track_m, 0.2, Color(1, 1, 1, 0))
	lib.add_animation("merge_exit", anim)
	_anim_player.play("fruit_lib/merge_exit")
	_anim_player.animation_finished.connect(on_complete.bind(), CONNECT_ONE_SHOT)


func start_merge_exit() -> void:
	play_merge_exit_animation(func(): queue_free())


func _on_body_entered(body: Node) -> void:
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


# ── wake-from-sleep re-check ──

func _on_sleeping_state_changed() -> void:
	if _wake_timer and sleeping:
		_wake_timer.start(0.4)


func wake_up_check() -> void:
	for pair in _contact_pairs:
		if is_instance_valid(pair) and not pair.sleeping and not pair._just_spawned:
			if _should_initiate_merge(pair):
				MergeService.try_merge(self, pair)
				return
