extends Control

const CATALOG: ShopCatalogData = preload("res://Data/ShopCatalog.tres")
const FloatingButtonAnimatorScript = preload("res://Scripts/UI/Components/floating_button_animator.gd")
const CurrencyFormatterScript = preload("res://Scripts/UI/Components/currency_formatter.gd")

var _current_category: StringName = &"pet"
var _shop_items: Array[ShopItemData] = []

@onready var _shop_list: GridContainer = %ShopList
@onready var _empty_label: Label = %EmptyLabel
@onready var _shop_item_scene: PackedScene = preload("res://Scenes/UI/Components/shop_item_button.tscn")
@onready var _shop_coins_label: Label = %ShopCoinsLabel
@onready var _shop_tickets_label: Label = %ShopTicketsLabel
@onready var _rewarded_ad_button: Button = %RewardedAdButton
@onready var _play_button: TextureButton = %PlayButton
@onready var _tab_skins: Button = %TabSkins
@onready var _tab_pets: Button = %TabPets
@onready var _tab_powerups: Button = %TabPowerups
@onready var _shop_header: TextureRect = $ShopHeader
@onready var _settings_menu = $SettingsMenu
@onready var _run_setup: RunSetupPanel = $RunSetup


func _ready() -> void:
	GameManager.change_state(Enums.GameState.SHOP)
	_load_items()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	EventBus.shop_item_purchased.connect(_on_catalog_changed)
	EventBus.item_equipped.connect(_on_catalog_changed)
	EventBus.powerup_count_changed.connect(_on_powerup_count_changed)
	_on_coins_changed(EconomyManager.coins)
	_on_tickets_changed(EconomyManager.tickets)
	%HomeButton.pressed.connect(_on_back_pressed)
	%AchievementsButton.pressed.connect(_on_back_pressed)
	%SettingsButton.pressed.connect(_open_settings)
	%ShopButton.pressed.connect(_bounce_shop_header)
	_play_button.pressed.connect(_on_play_pressed)
	_run_setup.closed.connect(func(): _play_button.disabled = false)
	_rewarded_ad_button.pressed.connect(_on_rewarded_ad_pressed)
	AdManager.ad_message.connect(_on_ad_message)
	AdManager.rewarded_ad_availability_changed.connect(_on_rewarded_ad_availability_changed)
	_on_rewarded_ad_availability_changed(AdManager.is_rewarded_ad_available(), AdManager.get_rewarded_ad_message())
	_apply_safe_area()
	FloatingButtonAnimatorScript.start(
		self,
		_play_button,
		bool(SaveManager.get_setting("reduced_motion", false))
	)
	_connect_tabs()
	_filter_category(&"pet")
	_play_intro.call_deferred()


func _load_items() -> void:
	_shop_items.assign(CATALOG.items)


func _connect_tabs() -> void:
	_tab_skins.pressed.connect(func(): _filter_category(&"skin"))
	_tab_pets.pressed.connect(func(): _filter_category(&"pet"))
	_tab_powerups.pressed.connect(func(): _filter_category(&"powerup"))


func _filter_category(category: StringName) -> void:
	_current_category = category
	_tab_skins.button_pressed = category == &"skin"
	_tab_pets.button_pressed = category == &"pet"
	_tab_powerups.button_pressed = category == &"powerup"
	_populate_shop()


func _populate_shop() -> void:
	for child in _shop_list.get_children():
		child.free()

	var visible_items := 0
	for item in _shop_items:
		if item.category != _current_category and not (_current_category == &"skin" and item.category == &"background"):
			continue
		var card := _shop_item_scene.instantiate()
		_shop_list.add_child(card)
		card.setup(item)
		visible_items += 1
	_empty_label.visible = visible_items == 0


func _on_coins_changed(amount: int) -> void:
	_shop_coins_label.text = CurrencyFormatterScript.format_amount(amount)
	_shop_coins_label.tooltip_text = "%d coins" % amount


func _on_tickets_changed(amount: int) -> void:
	_shop_tickets_label.text = CurrencyFormatterScript.format_amount(amount)
	_shop_tickets_label.tooltip_text = "%d tickets" % amount


func _on_rewarded_ad_pressed() -> void:
	AdManager.request_rewarded_ticket(1)


func _on_rewarded_ad_availability_changed(available: bool, message: String) -> void:
	_rewarded_ad_button.disabled = not available
	_rewarded_ad_button.text = "WATCH AD  +1" if available else "ADS SOON"
	_rewarded_ad_button.tooltip_text = message


func _on_ad_message(message: String) -> void:
	_rewarded_ad_button.tooltip_text = message


func _on_catalog_changed(_item_id: StringName) -> void:
	_populate_shop.call_deferred()


func _on_powerup_count_changed(_item_id: StringName, _count: int) -> void:
	if _current_category == &"powerup":
		_populate_shop.call_deferred()


func _on_back_pressed() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()


func _on_play_pressed() -> void:
	_play_button.disabled = true
	_run_setup.open()


func _open_settings() -> void:
	_settings_menu.open()


func _bounce_shop_header() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shop_header, "scale", Vector2(1.04, 0.96), 0.1)
	tween.tween_property(_shop_header, "scale", Vector2.ONE, 0.18)


func _play_intro() -> void:
	_shop_header.pivot_offset = _shop_header.size * 0.5
	_shop_header.scale = Vector2(0.82, 0.82)
	_shop_header.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_shop_header, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_shop_header, "modulate:a", 1.0, 0.25)


func _apply_safe_area() -> void:
	for control in [$CoinPanel, $TicketPanel, $RewardedAdButton, $ShopHeader, $ShopTitle]:
		MobileSafeArea.apply_top_inset(control, control.position.y)
	for control in [$Dock, %HomeButton, %AchievementsButton, _play_button, %ShopButton, %SettingsButton]:
		MobileSafeArea.apply_bottom_inset(control, control.position.y)
