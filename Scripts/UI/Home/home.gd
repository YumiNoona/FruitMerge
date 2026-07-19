extends Control

const FloatingButtonAnimatorScript = preload("res://Scripts/UI/Components/floating_button_animator.gd")
const COIN_ICON: Texture2D = preload("res://Assets/Menu/Coin.png")
const TICKET_ICON: Texture2D = preload("res://Assets/UI/Ticket.png")
const CurrencyFormatterScript = preload("res://Scripts/UI/Components/currency_formatter.gd")

@onready var _best_score_label: Label = %BestScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _tickets_label: Label = $TicketPanel/TicketRow/TicketLabel
@onready var _coin_panel: PanelContainer = $CoinPanel
@onready var _ticket_panel: PanelContainer = $TicketPanel
@onready var _coin_icon: TextureRect = $CoinPanel/CoinRow/CoinIcon
@onready var _ticket_icon: TextureRect = $TicketPanel/TicketRow/TicketIcon
@onready var _mascot: TextureRect = %Mascot
@onready var _play_button: TextureButton = %PlayButton
@onready var _home_button: TextureButton = %HomeButton
@onready var _achievements_button: TextureButton = %AchievementsButton
@onready var _shop_button: TextureButton = %ShopButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _no_ads_button: TextureButton = %NoAdsButton
@onready var _rewards_button: TextureButton = %RewardsButton
@onready var _info_overlay: Control = %InfoOverlay
@onready var _info_title: Label = %InfoTitle
@onready var _info_body: Label = %InfoBody
@onready var _close_info_button: Button = %CloseInfoButton
@onready var _settings_menu = $SettingsMenu
@onready var _no_ads_purchase: NoAdsPurchase = $NoAdsPurchase
@onready var _mode_button: Button = %ModeButton
@onready var _run_setup: RunSetupPanel = $RunSetup

var _pending_wallet_rewards: Array[Dictionary] = []


func _ready() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	_pending_wallet_rewards = RewardPresentationManager.take_pending_wallet_rewards()
	var display_coins := EconomyManager.coins
	var display_tickets := EconomyManager.tickets
	for reward in _pending_wallet_rewards:
		var amount := maxi(0, int(reward.get("amount", 0)))
		match StringName(reward.get("currency", &"")):
			&"coins": display_coins = maxi(0, display_coins - amount)
			&"tickets": display_tickets = maxi(0, display_tickets - amount)
	_best_score_label.text = "%d" % GameManager.high_score
	_update_coins(display_coins)
	_update_tickets(display_tickets)
	EventBus.coins_changed.connect(_update_coins)
	EventBus.tickets_changed.connect(_update_tickets)
	AdManager.no_ads_changed.connect(_on_no_ads_changed)
	_no_ads_button.visible = not AdManager.has_no_ads()
	_apply_equipped_background()
	_apply_safe_area()

	_play_button.pressed.connect(_start_game)
	_home_button.pressed.connect(_on_home_pressed)
	_achievements_button.pressed.connect(_show_achievements)
	_shop_button.pressed.connect(_open_shop)
	_settings_button.pressed.connect(_show_settings)
	_no_ads_button.pressed.connect(_show_no_ads_purchase)
	_rewards_button.pressed.connect(_open_daily_reward)
	_mode_button.pressed.connect(_cycle_mode)
	_run_setup.closed.connect(func(): _play_button.disabled = false)
	_close_info_button.pressed.connect(_hide_info)

	FloatingButtonAnimatorScript.start(
		self,
		_play_button,
		bool(SaveManager.get_setting("reduced_motion", false))
	)
	_play_intro.call_deferred()
	_run_entry_presentation.call_deferred()


func _run_entry_presentation() -> void:
	await get_tree().process_frame
	await _play_pending_wallet_rewards()
	_show_first_run_tutorial()


func _play_pending_wallet_rewards() -> void:
	for reward in _pending_wallet_rewards:
		await _play_wallet_reward(reward)
	_pending_wallet_rewards.clear()


func _play_wallet_reward(reward: Dictionary) -> void:
	var currency := StringName(reward.get("currency", &""))
	var amount := maxi(0, int(reward.get("amount", 0)))
	if amount <= 0 or currency not in [&"coins", &"tickets"]:
		return

	var target_panel: PanelContainer = _ticket_panel if currency == &"tickets" else _coin_panel
	var target_icon: TextureRect = _ticket_icon if currency == &"tickets" else _coin_icon
	var texture: Texture2D = TICKET_ICON if currency == &"tickets" else COIN_ICON
	if bool(SaveManager.get_setting("reduced_motion", false)):
		_finish_wallet_reward(currency, target_panel)
		return

	var reward_bundle := Control.new()
	reward_bundle.name = "WalletRewardFlyover"
	reward_bundle.size = Vector2(112, 112)
	reward_bundle.position = Vector2(size.x * 0.5, size.y * 0.46) - reward_bundle.size * 0.5
	reward_bundle.pivot_offset = reward_bundle.size * 0.5
	reward_bundle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_bundle.z_index = 250
	add_child(reward_bundle)

	var glow := TextureRect.new()
	glow.position = Vector2(4, 4)
	glow.size = Vector2(104, 104)
	glow.pivot_offset = glow.size * 0.5
	glow.texture = texture
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.modulate = Color(1.0, 0.86, 0.42, 0.24)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_bundle.add_child(glow)

	var reward_icon := TextureRect.new()
	reward_icon.position = Vector2(14, 14)
	reward_icon.size = Vector2(84, 84)
	reward_icon.pivot_offset = reward_icon.size * 0.5
	reward_icon.texture = texture
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_bundle.add_child(reward_icon)

	reward_bundle.scale = Vector2(0.32, 0.32)
	reward_bundle.rotation = -0.1
	reward_bundle.modulate.a = 0.0
	var pop := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(reward_bundle, "scale", Vector2.ONE, 0.3)
	pop.tween_property(reward_bundle, "rotation", 0.0, 0.3)
	pop.tween_property(reward_bundle, "modulate:a", 1.0, 0.16)
	pop.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.3)
	await pop.finished

	var resting_position := reward_bundle.position
	var hover := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover.tween_property(reward_bundle, "position:y", resting_position.y - 9.0, 0.28)
	hover.tween_property(reward_bundle, "position:y", resting_position.y, 0.28)
	await hover.finished

	var destination := target_icon.get_global_rect().get_center() - reward_bundle.size * 0.5
	var lift_position := Vector2(
		lerpf(reward_bundle.position.x, destination.x, 0.34),
		reward_bundle.position.y - 74.0
	)
	var flight := create_tween()
	flight.tween_property(reward_bundle, "position", lift_position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.parallel().tween_property(reward_bundle, "rotation", 0.12 if destination.x > reward_bundle.position.x else -0.12, 0.16)
	flight.tween_property(reward_bundle, "position", destination, 0.46).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	flight.parallel().tween_property(reward_bundle, "scale", Vector2(0.42, 0.42), 0.46)
	await flight.finished

	reward_bundle.queue_free()
	_finish_wallet_reward(currency, target_panel)


func _finish_wallet_reward(currency: StringName, target_panel: PanelContainer) -> void:
	if currency == &"tickets":
		_update_tickets(EconomyManager.tickets)
	else:
		_update_coins(EconomyManager.coins)
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	target_panel.pivot_offset = target_panel.size * 0.5
	var impact := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact.tween_property(target_panel, "scale", Vector2(1.12, 1.12), 0.12)
	impact.tween_property(target_panel, "scale", Vector2.ONE, 0.2)


func _update_coins(amount: int) -> void:
	_coins_label.text = CurrencyFormatterScript.format_amount(amount)
	_coins_label.tooltip_text = "%d coins" % amount


func _update_tickets(amount: int) -> void:
	_tickets_label.text = CurrencyFormatterScript.format_amount(amount)
	_tickets_label.tooltip_text = "%d tickets" % amount


func _start_game() -> void:
	_play_button.disabled = true
	_run_setup.open()


func _open_shop() -> void:
	_shop_button.disabled = true
	GameManager.change_state(Enums.GameState.SHOP)
	SceneRouter.go_shop()


func _on_home_pressed() -> void:
	_hide_info()
	var bounce := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(_mascot, "scale", Vector2(1.04, 0.96), 0.1)
	bounce.tween_property(_mascot, "scale", Vector2.ONE, 0.2)


func _show_achievements() -> void:
	_info_title.text = "ACHIEVEMENTS"
	var stats := GameManager.statistics
	_info_body.text = "Best score: %d\nFruit discovered: %d / %d\nDrops: %d   Merges: %d   Best combo: %d\nWatermelons: %d   Runs: %d\n\nACHIEVEMENTS\n%s\n\nDAILY MISSIONS\n%s" % [
		GameManager.high_score,
		GameManager.discovered_tiers.size(),
		FruitDatabase.get_tier_count(),
		int(stats.get("fruits_dropped", 0)),
		int(stats.get("total_merges", 0)),
		int(stats.get("largest_combo", 0)),
		int(stats.get("watermelons_created", 0)),
		int(stats.get("runs_completed", 0)),
		AchievementManager.get_summary(),
		DailyMissionManager.get_summary(),
	]
	_show_info()


func _show_settings() -> void:
	_hide_info()
	_settings_menu.open()


func _show_no_ads_purchase() -> void:
	_no_ads_purchase.open()


func _open_daily_reward() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_rewards_button.disabled = true
	SceneRouter.go_daily_reward()


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


func _cycle_mode() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_run_setup.open()


func _apply_equipped_background() -> void:
	$Background.modulate = Color(0.92, 1.0, 0.92, 1.0) if EconomyManager.get_equipped_item(&"background") == &"background_garden" else Color.WHITE


func _apply_safe_area() -> void:
	for control in [$BestPanel, $CoinPanel, $TicketPanel]:
		MobileSafeArea.apply_top_inset(control, control.position.y)
	for control in [$Dock, _home_button, _achievements_button, _play_button, _shop_button, _settings_button, _mode_button]:
		MobileSafeArea.apply_bottom_inset(control, control.position.y)


func _show_first_run_tutorial() -> void:
	# Interactive onboarding begins from Mission 1 on the first Play press.
	pass


func _hide_info() -> void:
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
