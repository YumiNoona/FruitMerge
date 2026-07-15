extends Button

var shop_item: ShopItemData

@onready var _name_label: Label = %NameLabel
@onready var _cost_label: Label = %CostLabel
@onready var _icon_rect: TextureRect = %IconRect
@onready var _owned_badge: Control = %OwnedBadge
@onready var _count_label: Label = %CountLabel


func setup(item: ShopItemData) -> void:
	shop_item = item
	if _name_label:
		_name_label.text = item.display_name
	if _icon_rect and item.icon:
		_icon_rect.texture = item.icon
	_update_button_state()
	pressed.connect(_on_pressed)


func _update_button_state() -> void:
	var is_consumable := shop_item.category == &"powerup"
	var owned := EconomyManager.owns_item(shop_item.id)
	var pw_count := EconomyManager.get_powerup_count(shop_item.id)

	if _cost_label:
		if is_consumable:
			if pw_count > 0:
				_cost_label.text = "x%d" % pw_count
				_cost_label.self_modulate = Color.GREEN
			else:
				_cost_label.text = "%d" % shop_item.cost
				_cost_label.self_modulate = Color.GOLD if EconomyManager.coins >= shop_item.cost else Color.RED
		elif owned:
			_cost_label.text = "OWNED"
			_cost_label.self_modulate = Color.GREEN
		else:
			_cost_label.text = "%d" % shop_item.cost
			_cost_label.self_modulate = Color.GOLD if EconomyManager.coins >= shop_item.cost else Color.RED

	if _owned_badge:
		_owned_badge.visible = owned and not is_consumable

	if _count_label:
		if is_consumable and pw_count > 0:
			_count_label.visible = true
			_count_label.text = "x%d" % pw_count
		else:
			_count_label.visible = false


func _on_pressed() -> void:
	var is_consumable := shop_item.category == &"powerup"
	if is_consumable:
		if EconomyManager.coins >= shop_item.cost:
			EconomyManager.try_purchase(shop_item)
			_update_button_state()
		return

	if EconomyManager.owns_item(shop_item.id):
		EconomyManager.equip_item(shop_item.id, shop_item.category)
		return

	if EconomyManager.try_purchase(shop_item):
		_update_button_state()
