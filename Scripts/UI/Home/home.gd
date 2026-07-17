extends Control

const MAIN_MENU_MUSIC: AudioStream = preload("res://Audio/Music/Main Menu.wav")
const ACHIEVEMENTS_MUSIC: AudioStream = preload("res://Audio/Music/Achievements.wav")

@onready var _best_score_label: Label = %BestScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _tickets_label: Label = $TicketPanel/TicketRow/TicketLabel
@onready var _mascot: TextureRect = %Mascot
@onready var _play_button: TextureButton = %PlayButton
@onready var _home_button: TextureButton = %HomeButton
@onready var _achievements_button: TextureButton = %AchievementsButton
@onready var _shop_button: TextureButton = %ShopButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _no_ads_button: TextureButton = %NoAdsButton
@onready var _info_overlay: Control = %InfoOverlay
@onready var _info_title: Label = %InfoTitle
@onready var _info_body: Label = %InfoBody
@onready var _settings_controls: VBoxContainer = %SettingsControls
@onready var _close_info_button: Button = %CloseInfoButton
@onready var _settings_menu = $SettingsMenu
@onready var _no_ads_purchase: NoAdsPurchase = $NoAdsPurchase


func _ready() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	AudioManager.play_music(MAIN_MENU_MUSIC)
	_best_score_label.text = "%d" % GameManager.high_score
	_update_coins(EconomyManager.coins)
	_update_tickets(EconomyManager.tickets)
	EventBus.coins_changed.connect(_update_coins)
	EventBus.tickets_changed.connect(_update_tickets)
	AdManager.no_ads_changed.connect(_on_no_ads_changed)
	_no_ads_button.visible = not AdManager.has_no_ads()

	_play_button.pressed.connect(_start_game)
	_home_button.pressed.connect(_on_home_pressed)
	_achievements_button.pressed.connect(_show_achievements)
	_shop_button.pressed.connect(_open_shop)
	_settings_button.pressed.connect(_show_settings)
	_no_ads_button.pressed.connect(_show_no_ads_purchase)
	_close_info_button.pressed.connect(_hide_info)

	_play_intro.call_deferred()


func _update_coins(amount: int) -> void:
	_coins_label.text = "%d" % amount


func _update_tickets(amount: int) -> void:
	_tickets_label.text = "%d" % amount


func _start_game() -> void:
	_play_button.disabled = true
	GameManager.start_new_run()


func _open_shop() -> void:
	_shop_button.disabled = true
	GameManager.change_state(Enums.GameState.SHOP)
	get_tree().change_scene_to_file("res://Scenes/UI/Shop/shop.tscn")


func _on_home_pressed() -> void:
	_hide_info()
	var bounce := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_mascot, "scale", Vector2(1.04, 0.96), 0.1)
	bounce.tween_property(_mascot, "scale", Vector2.ONE, 0.2)


func _show_achievements() -> void:
	AudioManager.play_music(ACHIEVEMENTS_MUSIC)
	_info_title.text = "ACHIEVEMENTS"
	_info_body.text = "Best score: %d\n\nFruit discovered: %d / %d\n\nReach the watermelon to complete your first cozy collection!" % [
		GameManager.high_score,
		mini(GameManager.highest_tier_reached + 1, FruitDatabase.get_tier_count()),
		FruitDatabase.get_tier_count(),
	]
	_settings_controls.visible = false
	_show_info()


func _show_settings() -> void:
	_hide_info()
	_settings_menu.open()


func _show_no_ads_purchase() -> void:
	_no_ads_purchase.open()


func _on_no_ads_changed(owned: bool) -> void:
	_no_ads_button.visible = not owned


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
	if _info_overlay.visible:
		AudioManager.play_music(MAIN_MENU_MUSIC)
	_info_overlay.visible = false


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
