extends Control

@onready var _play_button: Button = %PlayButton
@onready var _shop_button: Button = %ShopButton
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _mascot: TextureRect = %Mascot


func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_shop_button.pressed.connect(_on_shop_pressed)
	EventBus.coins_changed.connect(_on_coins_changed)
	_update_high_score()
	_update_coins(EconomyManager.coins)
	_play_intro()


func _play_intro() -> void:
	_mascot.pivot_offset = _mascot.size * 0.5
	_mascot.scale = Vector2(0.82, 0.82)
	_mascot.modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_mascot, "scale", Vector2.ONE, 0.55)
	intro.tween_property(_mascot, "modulate:a", 1.0, 0.3)
	await intro.finished
	var bob := create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_mascot, "position:y", _mascot.position.y - 8.0, 1.4)
	bob.tween_property(_mascot, "position:y", _mascot.position.y, 1.4)


func _update_high_score() -> void:
	_high_score_label.text = "%d" % GameManager.high_score


func _update_coins(amount: int) -> void:
	_coins_label.text = "%d" % amount


func _on_coins_changed(amount: int) -> void:
	_update_coins(amount)


func _on_play_pressed() -> void:
	_play_button.disabled = true
	GameManager.start_new_run()


func _on_shop_pressed() -> void:
	_shop_button.disabled = true
	GameManager.change_state(Enums.GameState.SHOP)
	get_tree().change_scene_to_file("res://ui/shop/shop.tscn")
