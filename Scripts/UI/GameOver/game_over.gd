extends Control

@onready var _result_card: PanelContainer = %ResultCard
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_earned_label: Label = %CoinsEarnedLabel
@onready var _new_high_label: Label = %NewHighLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


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
	_high_score_label.text = "Best  %d" % GameManager.high_score
	_coins_earned_label.text = "+%d coins" % coins_earned
	_new_high_label.visible = GameManager.is_new_high_score


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
	GameManager.start_new_run()


func _on_menu() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()
