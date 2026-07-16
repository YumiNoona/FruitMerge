extends Control

@onready var _best_score_label: Label = %BestScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _mascot: TextureRect = %Mascot
@onready var _play_button: TextureButton = %PlayButton
@onready var _home_button: TextureButton = %HomeButton
@onready var _achievements_button: TextureButton = %AchievementsButton
@onready var _shop_button: TextureButton = %ShopButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _info_overlay: Control = %InfoOverlay
@onready var _info_title: Label = %InfoTitle
@onready var _info_body: Label = %InfoBody
@onready var _settings_controls: VBoxContainer = %SettingsControls
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _close_info_button: Button = %CloseInfoButton


func _ready() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	_best_score_label.text = "%d" % GameManager.high_score
	_update_coins(EconomyManager.coins)
	EventBus.coins_changed.connect(_update_coins)

	_play_button.pressed.connect(_start_game)
	_home_button.pressed.connect(_on_home_pressed)
	_achievements_button.pressed.connect(_show_achievements)
	_shop_button.pressed.connect(_open_shop)
	_settings_button.pressed.connect(_show_settings)
	_close_info_button.pressed.connect(_hide_info)

	_music_slider.value = AudioManager.music_vol
	_sfx_slider.value = AudioManager.sfx_vol
	_music_slider.value_changed.connect(func(value: float): AudioManager.music_vol = value)
	_sfx_slider.value_changed.connect(func(value: float): AudioManager.sfx_vol = value)
	_music_slider.drag_ended.connect(_save_audio_settings)
	_sfx_slider.drag_ended.connect(_save_audio_settings)
	_play_intro.call_deferred()


func _update_coins(amount: int) -> void:
	_coins_label.text = "%d" % amount


func _start_game() -> void:
	_play_button.disabled = true
	GameManager.start_new_run()


func _open_shop() -> void:
	_shop_button.disabled = true
	GameManager.change_state(Enums.GameState.SHOP)
	get_tree().change_scene_to_file("res://ui/shop/shop.tscn")


func _on_home_pressed() -> void:
	_hide_info()
	var bounce := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_mascot, "scale", Vector2(1.04, 0.96), 0.1)
	bounce.tween_property(_mascot, "scale", Vector2.ONE, 0.2)


func _show_achievements() -> void:
	_info_title.text = "ACHIEVEMENTS"
	_info_body.text = "Best score: %d\n\nFruit discovered: %d / %d\n\nReach the watermelon to complete your first cozy collection!" % [
		GameManager.high_score,
		mini(GameManager.highest_tier_reached + 1, FruitDatabase.get_tier_count()),
		FruitDatabase.get_tier_count(),
	]
	_settings_controls.visible = false
	_show_info()


func _show_settings() -> void:
	_info_title.text = "SETTINGS"
	_info_body.text = "Make the kitchen sound just right."
	_settings_controls.visible = true
	_music_slider.value = AudioManager.music_vol
	_sfx_slider.value = AudioManager.sfx_vol
	_show_info()


func _show_info() -> void:
	_info_overlay.visible = true
	_info_overlay.modulate.a = 0.0
	var panel := _info_overlay.get_node("Center/Panel") as Control
	panel.scale = Vector2(0.86, 0.86)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_info_overlay, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28)


func _hide_info() -> void:
	_info_overlay.visible = false


func _save_audio_settings(_value_changed: bool) -> void:
	SaveManager.set_setting("music_volume", AudioManager.music_vol)
	SaveManager.set_setting("sfx_volume", AudioManager.sfx_vol)


func _play_intro() -> void:
	_mascot.pivot_offset = _mascot.size * 0.5
	_mascot.scale = Vector2(0.9, 0.9)
	_mascot.modulate.a = 0.0
	var intro := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_mascot, "scale", Vector2.ONE, 0.5)
	intro.tween_property(_mascot, "modulate:a", 1.0, 0.25)
	await intro.finished
	var bob := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_mascot, "position:y", _mascot.position.y - 7.0, 1.5)
	bob.tween_property(_mascot, "position:y", _mascot.position.y, 1.5)
