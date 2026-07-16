class_name Pet
extends Node2D

enum Mood { IDLE, EXCITED, WORRIED, SAD }

const PET_TEXTURES := {
	&"pet_cat": preload("res://Assets/UI/Mascot.png"),
	&"pet_strawberry_cat": preload("res://Assets/Pets/Strawberry Cat.png"),
	&"pet_watermelon_pup": preload("res://Assets/Pets/Watermelon Pup.png"),
	&"pet_peach_bunny": preload("res://Assets/Pets/Peach Bunny.png"),
	&"pet_pineapple_meow": preload("res://Assets/Pets/Pineapple Meow.png"),
	&"pet_melon_bear": preload("res://Assets/Pets/Melon Bear.png"),
	&"pet_banana_fox": preload("res://Assets/Pets/Banana Fox.png"),
	&"pet_berry_hamster": preload("res://Assets/Pets/Berry Hamster.png"),
	&"pet_cherry_bird": preload("res://Assets/Pets/Cherry Bird.png"),
	&"pet_lemon_frog": preload("res://Assets/Pets/Lemon Frog.png"),
}

@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 2.0
@export var squash_amount: float = 0.2

var current_mood: Mood = Mood.IDLE
var _base_y: float
var _base_scale: Vector2 = Vector2.ONE
var _bob_time: float = 0.0
var _target_squash: float = 1.0
var _current_squash: float = 1.0
var _excited_timer: float = 0.0
var _worried_timer: float = 0.0

@onready var _sprite: Sprite2D = %Sprite2D


func _ready() -> void:
	var equipped_pet := EconomyManager.get_equipped_item(&"pet")
	if _sprite and PET_TEXTURES.has(equipped_pet):
		_sprite.texture = PET_TEXTURES[equipped_pet]
	if _sprite:
		_base_y = _sprite.position.y
		_base_scale = _sprite.scale

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
		_sprite.scale = _base_scale * Vector2(1.0 + (_current_squash - 1.0), 1.0 - (_current_squash - 1.0) * 0.5)


func _on_merge(tier: int, _pos: Vector2, _score: int) -> void:
	_target_squash = 1.0 + squash_amount
	if tier >= Enums.FruitTier.ORANGE:
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
