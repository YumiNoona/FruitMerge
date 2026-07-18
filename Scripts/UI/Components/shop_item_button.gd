extends Button

const COIN_ICON: Texture2D = preload("res://Assets/Menu/Coin.png")
const TICKET_ICON: Texture2D = preload("res://Assets/UI/Ticket.png")
const ShopItemDisplayRulesScript = preload("res://Scripts/UI/Components/shop_item_display_rules.gd")

var shop_item: ShopItemData

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _cost_label: Label = %CostLabel
@onready var _icon_rect: TextureRect = %IconRect
@onready var _currency_glyph: TextureRect = %CurrencyGlyph
@onready var _count_label: Label = %CountLabel
@onready var _price_panel: PanelContainer = %PricePanel


func _ready() -> void:
	pressed.connect(_on_pressed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	if shop_item:
		_apply_item()


func setup(item: ShopItemData) -> void:
	shop_item = item
	if is_node_ready():
		_apply_item()


func _apply_item() -> void:
	_name_label.text = shop_item.display_name
	_description_label.text = shop_item.description
	var is_pet := not ShopItemDisplayRulesScript.should_show_description(shop_item.category)
	_description_label.visible = not is_pet
	_icon_rect.custom_minimum_size.y = 200.0 if is_pet else 150.0
	_icon_rect.texture = shop_item.icon
	_icon_rect.visible = shop_item.icon != null
	_currency_glyph.texture = TICKET_ICON if shop_item.currency == &"tickets" else COIN_ICON
	_update_button_state()


func _update_button_state() -> void:
	if not shop_item:
		return
	var is_consumable := shop_item.category == &"powerup"
	var owned := EconomyManager.owns_item(shop_item.id)
	var equipped := EconomyManager.is_item_equipped(shop_item.id, shop_item.category)
	var powerup_count := EconomyManager.get_powerup_count(shop_item.id)

	_count_label.visible = is_consumable and ShopItemDisplayRulesScript.should_show_inventory_count(powerup_count)
	_count_label.text = "x%d" % powerup_count

	if is_consumable:
		_cost_label.text = "%d" % shop_item.cost
	elif owned:
		_cost_label.text = "SELECT" if not equipped else "ACTIVE"
	else:
		_cost_label.text = "FREE" if shop_item.cost == 0 else "%d" % shop_item.cost

	var is_price_visible := is_consumable or not owned
	_currency_glyph.visible = is_price_visible and shop_item.cost > 0
	var can_afford := EconomyManager.can_afford(shop_item.currency, shop_item.cost)
	var action_style := &"ShopActionReady"
	if not is_price_visible:
		action_style = &"ShopActionActive" if equipped else &"ShopActionSelect"
	elif not can_afford:
		action_style = &"ShopActionLocked"
	_price_panel.theme_type_variation = action_style
	_cost_label.modulate = Color.WHITE
	if is_price_visible and not can_afford:
		tooltip_text = "Need %d %s" % [shop_item.cost, "tickets" if shop_item.currency == &"tickets" else "coins"]
	elif equipped:
		tooltip_text = "%s is active" % shop_item.display_name
	elif owned:
		tooltip_text = "Tap to select %s" % shop_item.display_name
	elif is_consumable:
		tooltip_text = "Buy one %s" % shop_item.display_name
	else:
		tooltip_text = "Unlock %s" % shop_item.display_name


func _on_coins_changed(_amount: int) -> void:
	_update_button_state()


func _on_tickets_changed(_amount: int) -> void:
	_update_button_state()


func _on_pressed() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if not shop_item:
		return
	var is_consumable := shop_item.category == &"powerup"
	if is_consumable:
		if not EconomyManager.can_afford(shop_item.currency, shop_item.cost):
			_show_not_enough_currency()
			return
		if EconomyManager.try_purchase(shop_item):
			_update_button_state()
		return

	if EconomyManager.owns_item(shop_item.id):
		EconomyManager.equip_item(shop_item.id, shop_item.category)
		_update_button_state()
		return

	if not EconomyManager.can_afford(shop_item.currency, shop_item.cost):
		_show_not_enough_currency()
		return

	if EconomyManager.try_purchase(shop_item):
		EconomyManager.equip_item(shop_item.id, shop_item.category)
		_update_button_state()


func _show_not_enough_currency() -> void:
	var pulse := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_cost_label, "scale", Vector2(1.12, 1.12), 0.1)
	pulse.parallel().tween_property(_cost_label, "modulate", Color(1.0, 0.88, 0.58, 1.0), 0.1)
	pulse.tween_property(_cost_label, "scale", Vector2.ONE, 0.18)
	pulse.parallel().tween_property(_cost_label, "modulate", Color.WHITE, 0.18)
