extends Node

var coins: int = 0
var tickets: int = 0
var owned_items: Array[StringName] = []
var powerup_counts: Dictionary = {}


func set_debug_powerups(amount: int) -> void:
	# Kept out of the save file: every debug launch gets a clean test set.
	for item_id: StringName in [
		&"powerup_level_up",
		&"powerup_shake_box",
		&"powerup_remove_smallest",
		&"powerup_grab_em",
		&"powerup_hammer",
		&"powerup_bomb",
	]:
		powerup_counts[item_id] = amount
		EventBus.powerup_count_changed.emit(item_id, amount)


func set_debug_wallet(coin_amount: int, ticket_amount: int) -> void:
	# Debug-only launch seed. Bootstrap reapplies it after loading the profile.
	coins = maxi(0, coin_amount)
	tickets = maxi(0, ticket_amount)
	EventBus.coins_changed.emit(coins)
	EventBus.tickets_changed.emit(tickets)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	EventBus.coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	EventBus.coins_changed.emit(coins)
	return true


func add_tickets(amount: int) -> void:
	if amount <= 0:
		return
	tickets += amount
	EventBus.tickets_changed.emit(tickets)


func spend_tickets(amount: int) -> bool:
	if amount < 0 or tickets < amount:
		return false
	tickets -= amount
	EventBus.tickets_changed.emit(tickets)
	return true


func get_currency_balance(currency: StringName) -> int:
	match currency:
		&"coins": return coins
		&"tickets": return tickets
		_: return -1


func can_afford(currency: StringName, amount: int) -> bool:
	return amount >= 0 and get_currency_balance(currency) >= amount


func spend_currency(currency: StringName, amount: int) -> bool:
	match currency:
		&"coins": return spend_coins(amount)
		&"tickets": return spend_tickets(amount)
		_: return false

func try_purchase(item: ShopItemData) -> bool:
	if item.category == &"powerup":
		return try_purchase_consumable(item)
	if item.id in owned_items:
		return false
	if not can_afford(item.currency, item.cost):
		return false
	if not spend_currency(item.currency, item.cost):
		return false
	owned_items.append(item.id)
	EventBus.shop_item_purchased.emit(item.id)
	SaveManager.save_game()
	return true

func try_purchase_consumable(item: ShopItemData) -> bool:
	if not can_afford(item.currency, item.cost):
		return false
	if not spend_currency(item.currency, item.cost):
		return false
	var current: int = powerup_counts.get(item.id, 0)
	powerup_counts[item.id] = current + 1
	EventBus.shop_item_purchased.emit(item.id)
	EventBus.powerup_count_changed.emit(item.id, current + 1)
	SaveManager.save_game()
	return true


func try_purchase_powerup_refill(item: ShopItemData) -> bool:
	if not item or item.category != &"powerup" or item.refill_ticket_cost <= 0:
		return false
	if not spend_tickets(item.refill_ticket_cost):
		return false
	if not grant_powerup(item.id, 1, false):
		add_tickets(item.refill_ticket_cost)
		return false
	EventBus.shop_item_purchased.emit(item.id)
	SaveManager.save_game()
	return true


func grant_powerup(item_id: StringName, amount: int = 1, save_immediately := true) -> bool:
	var item := PowerLoadoutManager.get_item_data(item_id)
	if not item or amount <= 0:
		return false
	var current := get_powerup_count(item_id)
	powerup_counts[item_id] = current + amount
	EventBus.powerup_count_changed.emit(item_id, current + amount)
	if save_immediately:
		SaveManager.save_game()
	return true


func consume_powerup(item_id: StringName) -> bool:
	var count: int = powerup_counts.get(item_id, 0)
	if count <= 0:
		return false
	powerup_counts[item_id] = count - 1
	GameManager.record_powerup_used()
	EventBus.powerup_count_changed.emit(item_id, count - 1)
	SaveManager.save_game()
	return true

func get_powerup_count(item_id: StringName) -> int:
	return powerup_counts.get(item_id, 0)

func owns_item(item_id: StringName) -> bool:
	return item_id in owned_items

func is_item_equipped(item_id: StringName, equip_slot: StringName) -> bool:
	var key: String = "equipped_" + equip_slot
	return SaveManager.get_setting(key, "") == item_id

func equip_item(item_id: StringName, equip_slot: StringName) -> void:
	SaveManager.set_setting("equipped_" + equip_slot, item_id)
	EventBus.item_equipped.emit(item_id)

func get_equipped_item(equip_slot: StringName) -> StringName:
	var key: String = "equipped_" + equip_slot
	return SaveManager.get_setting(key, "")

func award_coins_for_score(score_gained: int) -> int:
	var coins_earned: int = max(1, int(score_gained * 0.1))
	add_coins(coins_earned)
	return coins_earned
