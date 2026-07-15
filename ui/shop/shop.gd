extends Control

var _current_category: StringName = &"all"

@export var shop_items: Array[ShopItemData] = []

@onready var _shop_list: Container = %ShopList
@onready var _shop_item_scene: PackedScene = preload("res://ui/components/shop_item_button.tscn")
@onready var _shop_coins_label: Label = %ShopCoinsLabel
@onready var _back_button: Button = %BackButton
@onready var _tab_skins: Button = %TabSkins
@onready var _tab_pets: Button = %TabPets
@onready var _tab_powerups: Button = %TabPowerups
@onready var _tab_backgrounds: Button = %TabBackgrounds
@onready var _tab_all: Button = $"TabBar/TabAll"


func _ready() -> void:
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.shop_item_purchased.connect(_on_item_purchased)
	_on_coins_changed(EconomyManager.coins)
	_populate_shop()
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	_connect_tabs()


func _connect_tabs() -> void:
	if _tab_all:
		_tab_all.pressed.connect(func(): _filter_category(&"all"))
	if _tab_skins:
		_tab_skins.pressed.connect(func(): _filter_category(&"skin"))
	if _tab_pets:
		_tab_pets.pressed.connect(func(): _filter_category(&"pet"))
	if _tab_powerups:
		_tab_powerups.pressed.connect(func(): _filter_category(&"powerup"))
	if _tab_backgrounds:
		_tab_backgrounds.pressed.connect(func(): _filter_category(&"background"))


func _filter_category(cat: StringName) -> void:
	_current_category = cat
	_populate_shop()


func _populate_shop() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	for item in shop_items:
		if _current_category != &"all" and item.category != _current_category:
			continue
		var btn: Button = _shop_item_scene.instantiate()
		btn.setup(item)
		_shop_list.add_child(btn)


func _on_coins_changed(amount: int) -> void:
	if _shop_coins_label:
		_shop_coins_label.text = str(amount)


func _on_item_purchased(_item_id: StringName) -> void:
	_populate_shop()


func _on_back_pressed() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
