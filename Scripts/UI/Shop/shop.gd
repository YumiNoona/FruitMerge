extends Control

const CATALOG: ShopCatalogData = preload("res://Data/ShopCatalog.tres")
const CurrencyFormatterScript = preload("res://Scripts/UI/Components/currency_formatter.gd")
const CATEGORIES: Array[StringName] = [&"pet", &"powerup", &"skin", &"background"]

var _current_category: StringName = &"pet"
var _shop_items: Array[ShopItemData] = []

@onready var _shop_list: GridContainer = %ShopList
@onready var _empty_label: Label = %EmptyLabel
@onready var _shop_item_scene: PackedScene = preload("res://Scenes/UI/Components/shop_item_button.tscn")
@onready var _shop_coins_label: Label = %ShopCoinsLabel
@onready var _shop_tickets_label: Label = %ShopTicketsLabel
@onready var _no_ads_button: TextureButton = %NoAdsButton
@onready var _tab_skins: TextureButton = %TabSkins
@onready var _tab_pets: TextureButton = %TabPets
@onready var _tab_powerups: TextureButton = %TabPowerups
@onready var _tab_themes: TextureButton = %TabThemes
@onready var _no_ads_purchase: NoAdsPurchase = $NoAdsPurchase
@onready var _frame_art: TextureRect = %FrameArt
@onready var _shop_title: Label = $ShopTitle
@onready var _category_row: HBoxContainer = $HBoxContainer
@onready var _catalog_margin: MarginContainer = $CatalogMargin


func _ready() -> void:
	GameManager.change_state(Enums.GameState.SHOP)
	_load_items()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	EventBus.shop_item_purchased.connect(_on_catalog_changed)
	EventBus.item_equipped.connect(_on_catalog_changed)
	EventBus.powerup_count_changed.connect(_on_powerup_count_changed)
	AdManager.no_ads_changed.connect(_on_no_ads_changed)
	%CloseButton.pressed.connect(_on_back_pressed)
	_no_ads_button.pressed.connect(_no_ads_purchase.open)
	_connect_tabs()
	_on_coins_changed(EconomyManager.coins)
	_on_tickets_changed(EconomyManager.tickets)
	_on_no_ads_changed(AdManager.has_no_ads())
	_apply_safe_area()
	_filter_category(SceneRouter.take_shop_entry_category())
	_play_intro.call_deferred()


func _load_items() -> void:
	_shop_items.assign(CATALOG.items)


func _connect_tabs() -> void:
	_tab_skins.pressed.connect(func(): _filter_category(&"skin"))
	_tab_pets.pressed.connect(func(): _filter_category(&"pet"))
	_tab_powerups.pressed.connect(func(): _filter_category(&"powerup"))
	_tab_themes.pressed.connect(func(): _filter_category(&"background"))


func _filter_category(category: StringName) -> void:
	_current_category = category if category in CATEGORIES else &"pet"
	_refresh_tab_visuals()
	_populate_shop()


func _refresh_tab_visuals() -> void:
	var tabs := {
		&"pet": _tab_pets,
		&"powerup": _tab_powerups,
		&"skin": _tab_skins,
		&"background": _tab_themes,
	}
	for category in tabs:
		var button := tabs[category] as TextureButton
		var active: bool = category == _current_category
		button.set_pressed_no_signal(active)
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE * (1.06 if active else 0.92)
		button.modulate = Color.WHITE if active else Color(0.61, 0.74, 0.84, 0.78)


func _populate_shop() -> void:
	for child in _shop_list.get_children():
		child.free()
	var visible_items := 0
	for item in _shop_items:
		if item.category != _current_category:
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


func _on_no_ads_changed(owned: bool) -> void:
	_no_ads_button.visible = not owned


func _on_catalog_changed(_item_id: StringName) -> void:
	_populate_shop.call_deferred()


func _on_powerup_count_changed(_item_id: StringName, _count: int) -> void:
	if _current_category == &"powerup":
		_populate_shop.call_deferred()


func _on_back_pressed() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()


func _play_intro() -> void:
	_frame_art.modulate.a = 0.0
	_shop_title.pivot_offset = _shop_title.size * 0.5
	_shop_title.scale = Vector2(0.82, 0.82)
	_shop_title.modulate.a = 0.0
	_catalog_margin.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_frame_art, "modulate:a", 1.0, 0.28)
	tween.tween_property(_shop_title, "scale", Vector2.ONE, 0.38)
	tween.tween_property(_shop_title, "modulate:a", 1.0, 0.20)
	tween.tween_property(_catalog_margin, "modulate:a", 1.0, 0.24).set_delay(0.08)


func _apply_safe_area() -> void:
	for control in [$ShopTitle, $CloseButton, $CoinPanel, $TicketPanel, $NoAdsButton]:
		MobileSafeArea.apply_top_inset(control, control.position.y)
	MobileSafeArea.apply_bottom_inset(_category_row, _category_row.position.y)
