class_name Pet
extends Node2D

enum Mood { IDLE, EXCITED, WORRIED, SAD }

signal ability_pressed

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
@export_category("Companion ability")
@export_range(36.0, 82.0, 1.0, "suffix:px") var ability_ring_radius := 57.0
@export_range(2.0, 8.0, 0.5, "suffix:px") var ability_ring_width := 5.0

var current_mood: Mood = Mood.IDLE
var _base_y: float
var _base_scale: Vector2 = Vector2.ONE
var _bob_time: float = 0.0
var _target_squash: float = 1.0
var _current_squash: float = 1.0
var _excited_timer: float = 0.0
var _worried_timer: float = 0.0
var _ability_data: PetAbilityData
var _ability_enabled := false
var _ability_charge_ratio := 0.0
var _ability_ready := false
var _ability_has_uses := true
var _ability_jump_offset := 0.0
var _ability_scale := 1.0
var _ability_rotation := 0.0
var _ability_ring_time := 0.0
var _ability_tween: Tween
var _status_tween: Tween
var _base_rotation := 0.0

@onready var _sprite: Sprite2D = %Sprite2D
@onready var _touch_area: Area2D = %TouchArea
@onready var _ability_label: Label = %AbilityLabel


func _ready() -> void:
	var equipped_pet := EconomyManager.get_equipped_item(&"pet")
	if _sprite and PET_TEXTURES.has(equipped_pet):
		_sprite.texture = PET_TEXTURES[equipped_pet]
	if _sprite:
		_base_y = _sprite.position.y
		_base_scale = _sprite.scale
		_base_rotation = _sprite.rotation
	_touch_area.input_event.connect(_on_touch_area_input_event)
	_ability_label.visible = false

	EventBus.fruit_merged.connect(_on_merge)
	EventBus.game_over.connect(_on_game_over)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.danger_line_exited.connect(_on_danger_exited)
	EventBus.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	_bob_time += delta * bob_speed
	_ability_ring_time += delta
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
		_sprite.position.y = _base_y + offset + _ability_jump_offset
		_sprite.scale = _base_scale * _ability_scale * Vector2(1.0 + (_current_squash - 1.0), 1.0 - (_current_squash - 1.0) * 0.5)
		_sprite.rotation = _base_rotation + _ability_rotation
	if _ability_ready:
		queue_redraw()


func _draw() -> void:
	if not _ability_enabled or not _ability_data \
		or _ability_data.activation != PetAbilityData.Activation.CHARGED_TAP \
		or not _ability_has_uses:
		return
	var radius := ability_ring_radius + (sin(_ability_ring_time * 5.0) * 2.0 if _ability_ready else 0.0)
	var background := Color(0.26, 0.16, 0.08, 0.24)
	var accent := _ability_data.accent_color
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, background, ability_ring_width, true)
	if _ability_charge_ratio > 0.0:
		var start := -PI * 0.5
		draw_arc(Vector2.ZERO, radius, start, start + TAU * _ability_charge_ratio, 48, accent, ability_ring_width, true)
	if _ability_ready:
		var glow := accent
		glow.a = 0.22 + sin(_ability_ring_time * 5.0) * 0.08
		draw_circle(Vector2.ZERO, radius - 4.0, glow)


func configure_ability(data: PetAbilityData, gameplay_enabled: bool) -> void:
	_ability_data = data
	_ability_enabled = gameplay_enabled and data != null
	_touch_area.input_pickable = _ability_enabled
	_ability_charge_ratio = 0.0
	_ability_ready = false
	_ability_has_uses = true
	_ability_label.visible = false
	queue_redraw()


func set_ability_charge(ratio: float, is_ready: bool, has_uses: bool) -> void:
	_ability_charge_ratio = clampf(ratio, 0.0, 1.0)
	_ability_ready = is_ready
	_ability_has_uses = has_uses
	queue_redraw()


func play_ready_animation() -> void:
	show_ability_status("TAP PET!", 1.25)
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	var ready_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ready_tween.tween_property(self, "_ability_scale", 1.14, 0.12)
	ready_tween.tween_property(self, "_ability_scale", 1.0, 0.22)


func play_ability(callout: String) -> void:
	show_ability_status(callout, 1.35)
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	if _ability_tween and _ability_tween.is_valid():
		_ability_tween.kill()
	_ability_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ability_tween.tween_property(self, "_ability_jump_offset", -30.0, 0.14)
	_ability_tween.parallel().tween_property(self, "_ability_scale", 1.18, 0.14)
	_ability_tween.parallel().tween_property(self, "_ability_rotation", deg_to_rad(-8.0), 0.14)
	_ability_tween.tween_property(self, "_ability_jump_offset", 4.0, 0.18)
	_ability_tween.parallel().tween_property(self, "_ability_scale", 0.94, 0.18)
	_ability_tween.parallel().tween_property(self, "_ability_rotation", deg_to_rad(6.0), 0.18)
	_ability_tween.tween_property(self, "_ability_jump_offset", 0.0, 0.2)
	_ability_tween.parallel().tween_property(self, "_ability_scale", 1.0, 0.2)
	_ability_tween.parallel().tween_property(self, "_ability_rotation", 0.0, 0.2)


func show_ability_status(text: String, hold_time := 1.1) -> void:
	if not _ability_label:
		return
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()
	_ability_label.text = text
	_ability_label.visible = true
	_ability_label.modulate.a = 0.0
	_ability_label.scale = Vector2(0.76, 0.76)
	_ability_label.pivot_offset = _ability_label.size * 0.5
	_status_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_status_tween.tween_property(_ability_label, "modulate:a", 1.0, 0.12)
	_status_tween.parallel().tween_property(_ability_label, "scale", Vector2.ONE, 0.18)
	_status_tween.tween_interval(maxf(hold_time, 0.2))
	_status_tween.tween_property(_ability_label, "modulate:a", 0.0, 0.22)
	_status_tween.tween_callback(func(): _ability_label.visible = false)


func _on_touch_area_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	ability_pressed.emit()


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
