extends Control

const ITEM_PATHS: PackedStringArray = [
	"res://data/shop_items/skin_default.tres",
	"res://data/shop_items/skin_pastel.tres",
	"res://data/shop_items/skin_pineapple.tres",
	"res://data/shop_items/pet_cat.tres",
	"res://data/shop_items/powerup_hammer.tres",
	"res://data/shop_items/powerup_bomb.tres",
	"res://data/shop_items/background_garden.tres",
]

var _current_category: StringName = &"all"
var _shop_items: Array[ShopItemData] = []

@onready var _shop_list: GridContainer = %ShopList
@onready var _shop_item_scene: PackedScene = preload("res://ui/components/shop_item_button.tscn")
@onready var _shop_coins_label: Label = %ShopCoinsLabel
@onready var _back_button: Button = %BackButton
@onready var _play_button: Button = %PlayButton
@onready var _tab_all: Button = %TabAll
@onready var _tab_skins: Button = %TabSkins
@onready var _tab_pets: Button = %TabPets
@onready var _tab_powerups: Button = %TabPowerups
@onready var _tab_backgrounds: Button = %TabBackgrounds


func _ready() -> void:
	_load_items()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.shop_item_purchased.connect(_on_item_purchased)
	_on_coins_changed(EconomyManager.coins)
	_back_button.pressed.connect(_on_back_pressed)
	$BottomNav/BottomRow/HomeButton.pressed.connect(_on_back_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_connect_tabs()
	_populate_shop()


func _load_items() -> void:
	_shop_items.clear()
	for path in ITEM_PATHS:
		var item := load(path) as ShopItemData
		if item:
			_shop_items.append(item)


func _connect_tabs() -> void:
	_tab_all.pressed.connect(func(): _filter_category(&"all"))
	_tab_skins.pressed.connect(func(): _filter_category(&"skin"))
	_tab_pets.pressed.connect(func(): _filter_category(&"pet"))
	_tab_powerups.pressed.connect(func(): _filter_category(&"powerup"))
	_tab_backgrounds.pressed.connect(func(): _filter_category(&"background"))


func _filter_category(category: StringName) -> void:
	_current_category = category
	_tab_all.button_pressed = category == &"all"
	_tab_skins.button_pressed = category == &"skin"
	_tab_pets.button_pressed = category == &"pet"
	_tab_powerups.button_pressed = category == &"powerup"
	_tab_backgrounds.button_pressed = category == &"background"
	_populate_shop()


func _populate_shop() -> void:
	for child in _shop_list.get_children():
		child.queue_free()

	for item in _shop_items:
		if _current_category != &"all" and item.category != _current_category:
			continue
		var card := _shop_item_scene.instantiate()
		_shop_list.add_child(card)
		card.setup(item)


func _on_coins_changed(amount: int) -> void:
	_shop_coins_label.text = "%d" % amount


func _on_item_purchased(_item_id: StringName) -> void:
	# Individual cards refresh themselves; keep the scroll position stable.
	pass


func _on_back_pressed() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/home/home.tscn")


func _on_play_pressed() -> void:
	GameManager.start_new_run()
