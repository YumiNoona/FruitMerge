extends Control

@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_earned_label: Label = %CoinsEarnedLabel
@onready var _new_high_label: Label = %NewHighLabel
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	var score := GameManager.score
	var high := GameManager.high_score
	var coins_earned := int(score * 0.1)

	if _final_score_label:
		_final_score_label.text = str(score)
	if _high_score_label:
		_high_score_label.text = "Best: %d" % high
	if _coins_earned_label:
		_coins_earned_label.text = "+%d" % coins_earned
	if _new_high_label:
		_new_high_label.visible = GameManager.is_new_high_score
	if _restart_button:
		_restart_button.pressed.connect(_on_restart)
	if _menu_button:
		_menu_button.pressed.connect(_on_menu)


func _on_restart() -> void:
	GameManager.start_new_run()


func _on_menu() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
