extends Node

var coins: int = 0
var owned_items: Array[StringName] = []
var powerup_counts: Dictionary = {}

func add_coins(amount: int) -> void:
	coins += amount
	EventBus.coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	EventBus.coins_changed.emit(coins)
	return true

func try_purchase(item: ShopItemData) -> bool:
	if item.category == &"powerup":
		return try_purchase_consumable(item)
	if item.id in owned_items:
		return false
	if coins < item.cost:
		return false
	coins -= item.cost
	owned_items.append(item.id)
	EventBus.coins_changed.emit(coins)
	EventBus.shop_item_purchased.emit(item.id)
	return true

func try_purchase_consumable(item: ShopItemData) -> bool:
	if coins < item.cost:
		return false
	coins -= item.cost
	var current := powerup_counts.get(item.id, 0)
	powerup_counts[item.id] = current + 1
	EventBus.coins_changed.emit(coins)
	EventBus.shop_item_purchased.emit(item.id)
	return true

func consume_powerup(item_id: StringName) -> bool:
	var count: int = powerup_counts.get(item_id, 0)
	if count <= 0:
		return false
	powerup_counts[item_id] = count - 1
	return true

func get_powerup_count(item_id: StringName) -> int:
	return powerup_counts.get(item_id, 0)

func owns_item(item_id: StringName) -> bool:
	return item_id in owned_items

func is_item_equipped(item_id: StringName, equip_slot: StringName) -> bool:
	var key := "equipped_" + equip_slot
	return SaveManager.get_setting(key, "") == item_id

func equip_item(item_id: StringName, equip_slot: StringName) -> void:
	SaveManager.set_setting("equipped_" + equip_slot, item_id)

func get_equipped_item(equip_slot: StringName) -> StringName:
	var key := "equipped_" + equip_slot
	return SaveManager.get_setting(key, "")

func award_coins_for_score(score_gained: int) -> int:
	var coins_earned := max(1, int(score_gained * 0.1))
	add_coins(coins_earned)
	return coins_earned
