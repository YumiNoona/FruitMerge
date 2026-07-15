extends Control

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _next_fruit_icon: TextureRect = %NextFruitIcon
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _combo_label: Label = %ComboLabel
@onready var _score_pop_container: Control = %ScorePopContainer
@onready var _pause_button: Button = %PauseButton


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.high_score_changed.connect(_on_high_score_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.fruit_dropped.connect(_on_fruit_dropped)
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.danger_line_exited.connect(_on_danger_exited)
	EventBus.game_over.connect(_on_game_over)
	if _pause_button:
		_pause_button.pressed.connect(_on_pause_pressed)

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
	_update_next_fruit()


func _on_fruit_merged(_tier: int, pos: Vector2, score_gained: int) -> void:
	if GameManager.active_combo > 1:
		_combo_label.text = "x%d Combo!" % GameManager.active_combo
		_combo_label.visible = true
		_combo_label.modulate.a = 1.0
		var t := create_tween()
		t.tween_property(_combo_label, "modulate:a", 0.0, 1.5)
		t.finished.connect(func(): _combo_label.visible = false)
	_spawn_score_pop(pos, score_gained)


func _on_danger_entered() -> void:
	if _danger_overlay:
		var t := create_tween()
		t.tween_property(_danger_overlay, "modulate:a", 0.3, 0.3)


func _on_danger_exited() -> void:
	if _danger_overlay:
		var t := create_tween()
		t.tween_property(_danger_overlay, "modulate:a", 0.0, 0.5)


func _on_game_over(_score: int) -> void:
	pass


func _on_pause_pressed() -> void:
	GameManager.change_state(Enums.GameState.PAUSED)


func _update_score(s: int) -> void:
	if _score_label:
		_score_label.text = str(s)
		if GameManager.is_new_high_score:
			_score_label.self_modulate = Color.GOLD
		else:
			_score_label.self_modulate = Color.WHITE


func _update_high_score(s: int) -> void:
	if _high_score_label:
		_high_score_label.text = "Best: %d" % s


func _update_coins(c: int) -> void:
	if _coins_label:
		_coins_label.text = str(c)


func _update_next_fruit() -> void:
	if _next_fruit_icon:
		var data := FruitDatabase.get_fruit(GameManager.next_fruit_tier)
		if data and data.sprite:
			_next_fruit_icon.texture = data.sprite


func _spawn_score_pop(pos: Vector2, score: int) -> void:
	var pop_scene := load("res://ui/components/score_pop.tscn")
	if not pop_scene:
		return
	var pop: Control = pop_scene.instantiate()
	pop.text = "+%d" % score
	pop.global_position = pos
	if _score_pop_container:
		_score_pop_container.add_child(pop)
	else:
		add_child(pop)
