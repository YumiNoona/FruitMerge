extends Control

const ITEM_PATHS: PackedStringArray = [
	"res://data/shop_items/pet_strawberry_cat.tres",
	"res://data/shop_items/pet_watermelon_pup.tres",
	"res://data/shop_items/pet_peach_bunny.tres",
	"res://data/shop_items/pet_pineapple_meow.tres",
	"res://data/shop_items/pet_melon_bear.tres",
	"res://data/shop_items/pet_banana_fox.tres",
	"res://data/shop_items/pet_berry_hamster.tres",
	"res://data/shop_items/pet_cherry_bird.tres",
	"res://data/shop_items/pet_lemon_frog.tres",
	"res://data/shop_items/skin_default.tres",
	"res://data/shop_items/skin_pastel.tres",
	"res://data/shop_items/skin_pineapple.tres",
	"res://data/shop_items/powerup_level_up.tres",
	"res://data/shop_items/powerup_shake_box.tres",
	"res://data/shop_items/powerup_remove_smallest.tres",
]

var _current_category: StringName = &"pet"
var _shop_items: Array[ShopItemData] = []

@onready var _shop_list: GridContainer = %ShopList
@onready var _empty_label: Label = %EmptyLabel
@onready var _shop_item_scene: PackedScene = preload("res://ui/components/shop_item_button.tscn")
@onready var _shop_coins_label: Label = %ShopCoinsLabel
@onready var _close_button: TextureButton = %CloseButton
@onready var _play_button: TextureButton = %PlayButton
@onready var _tab_skins: Button = %TabSkins
@onready var _tab_pets: Button = %TabPets
@onready var _tab_powerups: Button = %TabPowerups
@onready var _shop_header: TextureRect = $ShopHeader


func _ready() -> void:
	GameManager.change_state(Enums.GameState.SHOP)
	_load_items()
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.shop_item_purchased.connect(_on_catalog_changed)
	EventBus.item_equipped.connect(_on_catalog_changed)
	EventBus.powerup_count_changed.connect(_on_powerup_count_changed)
	_on_coins_changed(EconomyManager.coins)
	_close_button.pressed.connect(_on_back_pressed)
	%HomeNavButton.pressed.connect(_on_back_pressed)
	%QuestsNavButton.pressed.connect(_on_back_pressed)
	%SettingsNavButton.pressed.connect(_on_back_pressed)
	%ShopNavButton.pressed.connect(_bounce_shop_header)
	_play_button.pressed.connect(_on_play_pressed)
	_connect_tabs()
	_filter_category(&"pet")
	_play_intro.call_deferred()


func _load_items() -> void:
	_shop_items.clear()
	for path in ITEM_PATHS:
		var item := load(path) as ShopItemData
		if item:
			_shop_items.append(item)


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
		child.queue_free()

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
	_shop_coins_label.text = "%d" % amount


func _on_catalog_changed(_item_id: StringName) -> void:
	_populate_shop.call_deferred()


func _on_powerup_count_changed(_item_id: StringName, _count: int) -> void:
	if _current_category == &"powerup":
		_populate_shop.call_deferred()


func _on_back_pressed() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://ui/home/home.tscn")


func _on_play_pressed() -> void:
	GameManager.start_new_run()


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
