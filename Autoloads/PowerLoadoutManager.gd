extends Node

const ALL_POWERUPS: Array[StringName] = [
	&"powerup_level_up",
	&"powerup_shake_box",
	&"powerup_remove_smallest",
	&"powerup_grab_em",
	&"powerup_hammer",
	&"powerup_bomb",
]
const DEFAULT_LOADOUT: Array[StringName] = [
	&"powerup_level_up",
	&"powerup_shake_box",
	&"powerup_remove_smallest",
]

var selected_loadout: Array[StringName] = DEFAULT_LOADOUT.duplicate()
var active_loadout: Array[StringName] = DEFAULT_LOADOUT.duplicate()


func load_from_save(settings: Dictionary) -> void:
	var saved = settings.get("power_loadout", [])
	var candidate: Array[StringName] = []
	if saved is Array:
		for value in saved:
			var item_id := StringName(str(value))
			if item_id in ALL_POWERUPS and item_id not in candidate:
				candidate.append(item_id)
	selected_loadout = candidate if candidate.size() == 3 else DEFAULT_LOADOUT.duplicate()
	active_loadout = selected_loadout.duplicate()


func set_selected_loadout(items: Array[StringName]) -> bool:
	if items.size() != 3:
		return false
	var clean: Array[StringName] = []
	for item_id in items:
		if item_id not in ALL_POWERUPS or item_id in clean:
			return false
		clean.append(item_id)
	selected_loadout = clean
	active_loadout = clean.duplicate()
	SaveManager.set_setting("power_loadout", clean.map(func(id): return String(id)))
	EventBus.power_loadout_changed.emit(active_loadout)
	return true


func prepare_standard_run() -> void:
	active_loadout = selected_loadout.duplicate()
	EventBus.power_loadout_changed.emit(active_loadout)


func prepare_mission_run(required_powerup: StringName) -> void:
	active_loadout.clear()
	if not required_powerup.is_empty():
		active_loadout.append(required_powerup)
	EventBus.power_loadout_changed.emit(active_loadout)


func is_selected(item_id: StringName) -> bool:
	return item_id in active_loadout


func get_available_count(item_id: StringName) -> int:
	if not is_selected(item_id):
		return 0
	return MissionManager.get_temporary_count(item_id) + EconomyManager.get_powerup_count(item_id)


func consume_powerup(item_id: StringName) -> bool:
	if not is_selected(item_id):
		return false
	if MissionManager.consume_temporary_powerup(item_id):
		GameManager.record_powerup_used()
		EventBus.powerup_used.emit(item_id)
		EventBus.powerup_count_changed.emit(item_id, get_available_count(item_id))
		return true
	if EconomyManager.consume_powerup(item_id):
		EventBus.powerup_used.emit(item_id)
		return true
	return false


func get_display_name(item_id: StringName) -> String:
	var names := {
		&"powerup_level_up": "Level Up",
		&"powerup_shake_box": "Shake Box",
		&"powerup_remove_smallest": "Remove Smallest",
		&"powerup_grab_em": "Grab 'Em",
		&"powerup_hammer": "Hammer",
		&"powerup_bomb": "Juice Bomb",
	}
	return str(names.get(item_id, String(item_id).capitalize()))


func get_item_data(item_id: StringName) -> ShopItemData:
	if item_id not in ALL_POWERUPS:
		return null
	return load("res://Data/ShopItems/%s.tres" % String(item_id)) as ShopItemData


func get_icon(item_id: StringName) -> Texture2D:
	var data := get_item_data(item_id)
	return data.icon if data else null
