extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 3

var _settings: Dictionary = {}
var _loaded: bool = false

func _ready() -> void:
	pass

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"coins": EconomyManager.coins if is_instance_valid(EconomyManager) else 0,
		"tickets": EconomyManager.tickets if is_instance_valid(EconomyManager) else 0,
		"owned_items": _serialize_owned(),
		"powerup_counts": _serialize_powerups(),
		"high_score": GameManager.high_score if is_instance_valid(GameManager) else 0,
		"settings": _settings,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var data: Dictionary = JSON.parse_string(text)
	if data == null:
		return
	_load_data(data)

func _load_data(data: Dictionary) -> void:
	if is_instance_valid(EconomyManager):
		EconomyManager.coins = data.get("coins", 0)
		EconomyManager.tickets = data.get("tickets", 0)
		var owned: Array = str_to_var(data.get("owned_items", "[]"))
		EconomyManager.owned_items.assign(owned if owned else [])
		var pw = data.get("powerup_counts", {})
		if pw is Dictionary:
			EconomyManager.powerup_counts = pw
	if is_instance_valid(GameManager):
		GameManager.high_score = data.get("high_score", 0)
	_settings = data.get("settings", {})
	_loaded = true

func save_run_result(run_score: int) -> void:
	var coins_earned := int(run_score * 0.1)
	if is_instance_valid(EconomyManager):
		EconomyManager.add_coins(coins_earned)
	save_game()

func get_setting(key: String, default = null):
	return _settings.get(key, default)

func set_setting(key: String, value) -> void:
	_settings[key] = value
	save_game()

func is_loaded() -> bool:
	return _loaded

func _serialize_owned() -> String:
	if is_instance_valid(EconomyManager):
		return var_to_str(EconomyManager.owned_items)
	return "[]"

func _serialize_powerups() -> Dictionary:
	if is_instance_valid(EconomyManager):
		return EconomyManager.powerup_counts.duplicate()
	return {}
