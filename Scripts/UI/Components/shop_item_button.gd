extends Button

const COIN_ICON: Texture2D = preload("res://Assets/Menu/Coin.png")
const TICKET_ICON: Texture2D = preload("res://Assets/UI/Ticket.png")

var shop_item: ShopItemData

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _cost_label: Label = %CostLabel
@onready var _icon_rect: TextureRect = %IconRect
@onready var _currency_glyph: TextureRect = %CurrencyGlyph
@onready var _owned_badge: PanelContainer = %OwnedBadge
@onready var _status_label: Label = %StatusLabel
@onready var _count_label: Label = %CountLabel


static func should_show_inventory_count(count: int) -> bool:
	return count > 1


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

	_owned_badge.visible = owned and not is_consumable
	_status_label.text = "EQUIPPED" if equipped else "OWNED"
	_count_label.visible = is_consumable and should_show_inventory_count(powerup_count)
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
	if is_price_visible and not can_afford:
		_cost_label.modulate = Color(1.0, 0.75, 0.7, 1.0)
		tooltip_text = "Need %d %s" % [shop_item.cost, "tickets" if shop_item.currency == &"tickets" else "coins"]
	else:
		_cost_label.modulate = Color.WHITE
		tooltip_text = shop_item.description


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
	_cost_label.modulate = Color(1.0, 0.45, 0.36, 1.0)
	var pulse := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_cost_label, "scale", Vector2(1.16, 1.16), 0.1)
	pulse.tween_property(_cost_label, "scale", Vector2.ONE, 0.18)
