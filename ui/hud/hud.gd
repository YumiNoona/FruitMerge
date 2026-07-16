extends Control

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _next_fruit_icon: TextureRect = %NextFruitIcon
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _danger_warning: Label = %DangerWarning
@onready var _combo_banner: Control = %ComboBanner
@onready var _combo_multiplier: Label = %ComboMultiplier
@onready var _combo_callout: Label = %ComboCallout
@onready var _score_pop_container: Control = %ScorePopContainer
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton
@onready var _level_up_button: TextureButton = %LevelUpButton
@onready var _shake_button: TextureButton = %ShakeButton
@onready var _remove_button: TextureButton = %RemoveButton
@onready var _level_up_count: Label = %LevelUpCount
@onready var _shake_count: Label = %ShakeCount
@onready var _remove_count: Label = %RemoveCount
@onready var _powerup_hint: Label = %PowerupHint

var _danger_tween: Tween
var _combo_tween: Tween
var _combo_base_position: Vector2


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.high_score_changed.connect(_on_high_score_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.fruit_dropped.connect(_on_fruit_dropped)
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.danger_line_exited.connect(_on_danger_exited)
	_pause_button.pressed.connect(_on_pause_pressed)
	_resume_button.pressed.connect(_on_resume_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_level_up_button.pressed.connect(func(): _request_powerup(&"powerup_level_up"))
	_shake_button.pressed.connect(func(): _request_powerup(&"powerup_shake_box"))
	_remove_button.pressed.connect(func(): _request_powerup(&"powerup_remove_smallest"))
	EventBus.powerup_count_changed.connect(_on_powerup_count_changed)
	EventBus.powerup_targeting_changed.connect(_on_powerup_targeting_changed)
	_danger_overlay.modulate.a = 0.0
	_combo_base_position = _combo_banner.position
	_update_score(GameManager.score)
	_update_high_score(GameManager.high_score)
	_update_coins(EconomyManager.coins)
	_update_next_fruit()
	_update_powerup_buttons()


func _on_score_changed(new_score: int) -> void:
	_update_score(new_score)


func _on_high_score_changed(new_high: int) -> void:
	_update_high_score(new_high)


func _on_coins_changed(new_amount: int) -> void:
	_update_coins(new_amount)


func _on_fruit_dropped(_tier: int) -> void:
	_update_next_fruit.call_deferred()


func _on_fruit_merged(_tier: int, pos: Vector2, score_gained: int) -> void:
	if GameManager.active_combo > 1:
		_show_combo(GameManager.active_combo)
	_spawn_score_pop(pos, score_gained)


func _show_combo(combo: int) -> void:
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_multiplier.text = "x%d" % combo
	_combo_callout.text = _get_combo_callout(combo)
	_combo_banner.visible = true
	_combo_banner.pivot_offset = _combo_banner.size * 0.5
	_combo_banner.position = _combo_base_position
	_combo_banner.scale = Vector2(0.52, 0.52)
	_combo_banner.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	_combo_banner.modulate.a = 1.0
	_combo_tween = create_tween().set_parallel(true)
	_combo_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(_combo_banner, "scale", Vector2.ONE, 0.24)
	_combo_tween.tween_property(_combo_banner, "rotation", 0.0, 0.22)
	_combo_tween.tween_property(_combo_banner, "position:y", _combo_base_position.y - 26.0, 0.9).set_delay(0.18)
	_combo_tween.tween_property(_combo_banner, "modulate:a", 0.0, 0.38).set_delay(0.78)
	_combo_tween.chain().tween_callback(func(): _combo_banner.visible = false)


func _get_combo_callout(combo: int) -> String:
	if combo >= 5:
		return "MEGA MERGE!"
	if combo == 4:
		return "FRUIT FRENZY!"
	if combo == 3:
		return "SWEET STREAK!"
	return "JUICY COMBO!"


func _on_danger_entered() -> void:
	if _danger_tween and _danger_tween.is_valid():
		_danger_tween.kill()
	_danger_warning.visible = true
	_danger_warning.modulate.a = 1.0
	_danger_tween = create_tween().set_loops()
	_danger_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.8, 0.45)
	_danger_tween.parallel().tween_property(_danger_warning, "modulate:a", 0.55, 0.45)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.28, 0.45)
	_danger_tween.parallel().tween_property(_danger_warning, "modulate:a", 1.0, 0.45)


func _on_danger_exited() -> void:
	if _danger_tween and _danger_tween.is_valid():
		_danger_tween.kill()
	_danger_tween = create_tween().set_parallel(true)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.0, 0.35)
	_danger_tween.tween_property(_danger_warning, "modulate:a", 0.0, 0.25)
	_danger_tween.chain().tween_callback(func(): _danger_warning.visible = false)


func _on_pause_pressed() -> void:
	_pause_overlay.visible = true
	GameManager.change_state(Enums.GameState.PAUSED)


func _on_resume_pressed() -> void:
	_pause_overlay.visible = false
	GameManager.change_state(Enums.GameState.PLAYING)


func _on_menu_pressed() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/home/home.tscn")


func _request_powerup(item_id: StringName) -> void:
	if EconomyManager.get_powerup_count(item_id) <= 0:
		return
	EventBus.powerup_requested.emit(item_id)


func _on_powerup_count_changed(_item_id: StringName, _count: int) -> void:
	_update_powerup_buttons()


func _update_powerup_buttons() -> void:
	_update_powerup_button(_level_up_button, _level_up_count, &"powerup_level_up")
	_update_powerup_button(_shake_button, _shake_count, &"powerup_shake_box")
	_update_powerup_button(_remove_button, _remove_count, &"powerup_remove_smallest")


func _update_powerup_button(button: TextureButton, count_label: Label, item_id: StringName) -> void:
	var count := EconomyManager.get_powerup_count(item_id)
	count_label.text = "x%d" % count
	button.disabled = count <= 0
	button.modulate = Color.WHITE if count > 0 else Color(0.62, 0.62, 0.62, 0.52)


func _on_powerup_targeting_changed(active: bool, message: String) -> void:
	_powerup_hint.visible = active
	_powerup_hint.text = message
	_level_up_button.modulate = Color(1.12, 1.12, 0.78, 1.0) if active else (Color.WHITE if EconomyManager.get_powerup_count(&"powerup_level_up") > 0 else Color(0.62, 0.62, 0.62, 0.52))


func _update_score(value: int) -> void:
	_score_label.text = "%d" % value
	_score_label.self_modulate = Color(1.0, 0.65, 0.18) if GameManager.is_new_high_score else Color.WHITE


func _update_high_score(value: int) -> void:
	_high_score_label.text = "Best  %d" % value


func _update_coins(value: int) -> void:
	_coins_label.text = "%d" % value


func _update_next_fruit() -> void:
	var texture := FruitDatabase.get_visual_texture(GameManager.next_fruit_tier)
	if texture:
		_next_fruit_icon.texture = texture


func _spawn_score_pop(world_pos: Vector2, score: int) -> void:
	var pop_scene := load("res://ui/components/score_pop.tscn") as PackedScene
	if not pop_scene:
		return
	var pop: Control = pop_scene.instantiate()
	pop.text = "+%d" % score
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	pop.position = screen_pos
	_score_pop_container.add_child(pop)
