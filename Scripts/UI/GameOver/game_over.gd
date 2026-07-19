extends Control

@onready var _result_card: PanelContainer = %ResultCard
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_earned_label: Label = %CoinsEarnedLabel
@onready var _new_high_label: Label = %NewHighLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _title: Label = $Center/ResultCard/Content/Title
@onready var _encouragement: Label = $Center/ResultCard/Content/Encouragement


func _ready() -> void:
	_restart_button.pressed.connect(_on_restart)
	_menu_button.pressed.connect(_on_menu)
	EventBus.game_over.connect(_on_game_over)
	_populate(GameManager.score)


func _on_game_over(final_score: int) -> void:
	HapticManager.pulse(HapticManager.Feedback.GAME_OVER)
	_populate(final_score)
	visible = true
	_play_intro.call_deferred()


func _populate(score: int) -> void:
	var coins_earned := int(score * 0.1)
	_final_score_label.text = "%d" % score
	_high_score_label.text = "Best  %d" % GameManager.get_current_high_score()
	_coins_earned_label.text = "+%d coins" % coins_earned
	_new_high_label.visible = GameManager.is_new_high_score
	_restart_button.text = "PLAY AGAIN"
	match GameManager.current_mode:
		Enums.GameMode.MISSIONS:
			_populate_mission_result()
		Enums.GameMode.TIME_ATTACK:
			_title.text = "TIME'S UP!"
			_encouragement.text = "Your best two-minute harvest is saved"
		_:
			_title.text = "FRUIT BASKET FULL"
			_encouragement.text = "Every drop grows your garden"


func _populate_mission_result() -> void:
	var definition := MissionManager.active_definition
	var completed := GameManager.run_end_reason == "mission_complete"
	_title.text = "MISSION COMPLETE!" if completed else "MISSION FAILED"
	_new_high_label.visible = false
	_high_score_label.text = "Level %d" % definition.level if definition else "Mission"
	if completed and definition:
		_coins_earned_label.text = "+%d coins  +%d tickets" % [definition.reward_coins, definition.reward_tickets]
		_encouragement.text = "A new lesson is ready!" if definition.level < 7 else "All modes are now unlocked!"
		_restart_button.text = "NEXT MISSION" if definition.level < 7 else "CONTINUE"
	else:
		_coins_earned_label.text = "Try the guided hint again"
		_encouragement.text = "You can retry without losing tutorial power"
		_restart_button.text = "RETRY MISSION"


func _play_intro() -> void:
	_result_card.pivot_offset = _result_card.size * 0.5
	_result_card.scale = Vector2(0.76, 0.76)
	_result_card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_result_card, "scale", Vector2.ONE, 0.42)
	tween.tween_property(_result_card, "modulate:a", 1.0, 0.24)


func _on_restart() -> void:
	_restart_button.disabled = true
	if GameManager.current_mode == Enums.GameMode.MISSIONS:
		var definition := MissionManager.active_definition
		if GameManager.run_end_reason == "mission_complete" and definition and definition.level < 7:
			MissionManager.start_mission(definition.level + 1)
		elif GameManager.run_end_reason != "mission_complete":
			MissionManager.restart_active_mission()
		else:
			GameManager.change_state(Enums.GameState.MENU)
			SceneRouter.go_home()
		return
	PowerLoadoutManager.prepare_standard_run()
	GameManager.start_new_run()


func _on_menu() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()
