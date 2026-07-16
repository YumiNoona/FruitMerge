extends Control

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _next_fruit_icon: TextureRect = %NextFruitIcon
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _danger_warning: Label = %DangerWarning
@onready var _combo_label: Label = %ComboLabel
@onready var _score_pop_container: Control = %ScorePopContainer
@onready var _pause_button: Button = %PauseButton
@onready var _pause_overlay: Control = %PauseOverlay
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton

var _danger_tween: Tween


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
	_danger_overlay.modulate.a = 0.0
	_update_score(GameManager.score)
	_update_high_score(GameManager.high_score)
	_update_coins(EconomyManager.coins)
	_update_next_fruit()


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
		_combo_label.text = "x%d  COMBO!" % GameManager.active_combo
		_combo_label.visible = true
		_combo_label.scale = Vector2(0.7, 0.7)
		_combo_label.modulate.a = 1.0
		var combo_tween := create_tween().set_parallel(true)
		combo_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.2)
		combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 1.2).set_delay(0.45)
		combo_tween.chain().tween_callback(func(): _combo_label.visible = false)
	_spawn_score_pop(pos, score_gained)


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
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")


func _update_score(value: int) -> void:
	_score_label.text = "%d" % value
	_score_label.self_modulate = Color(1.0, 0.65, 0.18) if GameManager.is_new_high_score else Color.WHITE


func _update_high_score(value: int) -> void:
	_high_score_label.text = "Best  %d" % value


func _update_coins(value: int) -> void:
	_coins_label.text = "%d" % value


func _update_next_fruit() -> void:
	var data := FruitDatabase.get_fruit(GameManager.next_fruit_tier)
	if data and data.sprite:
		_next_fruit_icon.texture = data.sprite


func _spawn_score_pop(world_pos: Vector2, score: int) -> void:
	var pop_scene := load("res://ui/components/score_pop.tscn") as PackedScene
	if not pop_scene:
		return
	var pop: Control = pop_scene.instantiate()
	pop.text = "+%d" % score
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	pop.position = screen_pos
	_score_pop_container.add_child(pop)
