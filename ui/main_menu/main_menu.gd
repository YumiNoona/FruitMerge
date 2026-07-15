extends Control

@onready var _play_button: Button = %PlayButton
@onready var _shop_button: Button = %ShopButton
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel


func _ready() -> void:
	if _play_button:
		_play_button.pressed.connect(_on_play_pressed)
	if _shop_button:
		_shop_button.pressed.connect(_on_shop_pressed)

	EventBus.coins_changed.connect(_on_coins_changed)
	_update_high_score()
	_update_coins(EconomyManager.coins)


func _update_high_score() -> void:
	if _high_score_label:
		_high_score_label.text = "High Score: %d" % GameManager.high_score


func _update_coins(amount: int) -> void:
	if _coins_label:
		_coins_label.text = str(amount)


func _on_coins_changed(amount: int) -> void:
	_update_coins(amount)


func _on_play_pressed() -> void:
	GameManager.start_new_run()


func _on_shop_pressed() -> void:
	GameManager.change_state(Enums.GameState.SHOP)
	get_tree().change_scene_to_file("res://ui/shop/shop.tscn")
