class_name Pet
extends Node2D

enum Mood { IDLE, EXCITED, WORRIED, SAD }

@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 2.0
@export var squash_amount: float = 0.2

var current_mood: Mood = Mood.IDLE
var _base_y: float
var _bob_time: float = 0.0
var _target_squash: float = 1.0
var _current_squash: float = 1.0
var _excited_timer: float = 0.0
var _worried_timer: float = 0.0

@onready var _sprite: Sprite2D = %Sprite2D


func _ready() -> void:
	if _sprite:
		_base_y = _sprite.position.y

	EventBus.fruit_merged.connect(_on_merge)
	EventBus.game_over.connect(_on_game_over)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.danger_line_exited.connect(_on_danger_exited)
	EventBus.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	_bob_time += delta * bob_speed
	var offset: float = sin(_bob_time) * bob_amplitude

	match current_mood:
		Mood.EXCITED:
			_excited_timer -= delta
			if _excited_timer <= 0.0:
				current_mood = Mood.IDLE
			offset *= 1.8
		Mood.WORRIED:
			_worried_timer -= delta
			if _worried_timer <= 0.0:
				current_mood = Mood.IDLE
			offset *= 0.4
		Mood.SAD:
			offset *= 0.15

	_current_squash = lerpf(_current_squash, _target_squash, delta * 6.0)
	_target_squash = lerpf(_target_squash, 1.0, delta * 3.0)

	if _sprite:
		_sprite.position.y = _base_y + offset
		_sprite.scale = Vector2(1.0 + (_current_squash - 1.0), 1.0 - (_current_squash - 1.0) * 0.5)


func _on_merge(tier: int, _pos: Vector2, _score: int) -> void:
	_target_squash = 1.0 + squash_amount
	if tier >= Enums.FruitTier.CABBAGE:
		current_mood = Mood.EXCITED
		_excited_timer = 1.2


func _on_game_over(_score: int) -> void:
	current_mood = Mood.SAD
	_target_squash = 0.7


func _on_danger_entered() -> void:
	current_mood = Mood.WORRIED
	_worried_timer = 99.0
	_target_squash = 0.85


func _on_danger_exited() -> void:
	current_mood = Mood.IDLE
	_target_squash = 1.1


func _on_state_changed(state: Enums.GameState) -> void:
	match state:
		Enums.GameState.PLAYING:
			modulate = Color.WHITE
			current_mood = Mood.IDLE
		Enums.GameState.GAME_OVER:
			modulate = Color(0.7, 0.7, 0.7)
			current_mood = Mood.SAD
