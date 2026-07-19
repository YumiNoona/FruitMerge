extends Node

const SAVE_PATH := "user://savegame.json"
const TEMP_PATH := "user://savegame.tmp"
const BACKUP_PATH := "user://savegame.backup.json"
const SAVE_VERSION := 8

var _settings: Dictionary = {}
var _loaded := false
var _save_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func save_game() -> bool:
	_save_queued = false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not file:
		push_error("Could not open temporary save file: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(_build_save_data(), "\t"))
	file.flush()
	file.close()

	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.copy_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			push_warning("Could not create save backup: %s" % error_string(backup_error))
		DirAccess.remove_absolute(save_absolute)
	var rename_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if rename_error != OK:
		push_error("Could not commit save file: %s" % error_string(rename_error))
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.copy_absolute(backup_absolute, save_absolute)
		return false
	return true


func request_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	_save_after_frame.call_deferred()


func _save_after_frame() -> void:
	await get_tree().process_frame
	if _save_queued:
		save_game()


func load_game() -> void:
	var data := _read_save(SAVE_PATH)
	if data.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		data = _read_save(BACKUP_PATH)
	if not data.is_empty():
		_load_data(_migrate_data(data))
	else:
		_apply_new_profile_defaults()
	_loaded = true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Could not read save file %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		push_warning("Save file %s is invalid; trying backup/defaults" % path)
		return {}
	return parsed as Dictionary


func _build_save_data() -> Dictionary:
	var owned: Array[String] = []
	for item_id in EconomyManager.owned_items:
		owned.append(String(item_id))
	var powerups := {}
	for item_id in EconomyManager.powerup_counts:
		powerups[String(item_id)] = maxi(0, int(EconomyManager.powerup_counts[item_id]))
	return {
		"version": SAVE_VERSION,
		"coins": maxi(0, EconomyManager.coins),
		"tickets": maxi(0, EconomyManager.tickets),
		"owned_items": owned,
		"powerup_counts": powerups,
		"high_score": maxi(0, GameManager.high_score),
		"time_attack_high_score": maxi(0, GameManager.time_attack_high_score),
		"lifetime_highest_tier": maxi(0, GameManager.lifetime_highest_tier),
		"discovered_tiers": GameManager.discovered_tiers.duplicate(),
		"statistics": GameManager.statistics.duplicate(true),
		"mission_data": GameManager.mission_data.duplicate(true),
		"daily_mission_data": GameManager.daily_mission_data.duplicate(true),
		"achievement_data": GameManager.achievement_data.duplicate(true),
		"settings": _settings.duplicate(true),
	}


func _migrate_data(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := int(migrated.get("version", 1))
	if version < 4:
		var owned_value = migrated.get("owned_items", [])
		if owned_value is String:
			var parsed_owned = str_to_var(owned_value)
			migrated["owned_items"] = parsed_owned if parsed_owned is Array else []
		migrated["lifetime_highest_tier"] = 0
		migrated["discovered_tiers"] = [0]
		migrated["statistics"] = {}
	if version < 5:
		migrated["mission_data"] = {}
	if version < 6:
		migrated["achievement_data"] = {}
	var settings_value = migrated.get("settings", {})
	if settings_value is not Dictionary:
		migrated["settings"] = {}
	if version < 7:
		var cleaned_settings: Dictionary = migrated.get("settings", {}).duplicate(true)
		for retired_key in ["theme", "feedback_level", "music_restore_volume", "sfx_restore_volume"]:
			cleaned_settings.erase(retired_key)
		cleaned_settings["haptic_strength"] = 1.0
		cleaned_settings["screen_shake_strength"] = 1.0
		cleaned_settings["reduced_motion"] = false
		migrated["settings"] = cleaned_settings
	if version < 8:
		var legacy_daily = migrated.get("mission_data", {})
		migrated["daily_mission_data"] = legacy_daily.duplicate(true) if legacy_daily is Dictionary else {}
		migrated["mission_data"] = {
			"highest_unlocked": 7,
			"completed_levels": [1, 2, 3, 4, 5, 6, 7],
			"onboarding_started": true,
			"onboarding_completed": true,
		}
		migrated["time_attack_high_score"] = 0
		var loadout_settings: Dictionary = migrated.get("settings", {}).duplicate(true)
		loadout_settings["power_loadout"] = ["powerup_level_up", "powerup_shake_box", "powerup_remove_smallest"]
		migrated["settings"] = loadout_settings
	migrated["version"] = SAVE_VERSION
	return migrated


func _load_data(data: Dictionary) -> void:
	EconomyManager.coins = maxi(0, int(data.get("coins", 0)))
	EconomyManager.tickets = maxi(0, int(data.get("tickets", 0)))
	EconomyManager.owned_items.clear()
	var owned_value = data.get("owned_items", [])
	if owned_value is Array:
		for value in owned_value:
			var item_id := StringName(str(value))
			if not item_id.is_empty() and item_id not in EconomyManager.owned_items:
				EconomyManager.owned_items.append(item_id)
	EconomyManager.powerup_counts.clear()
	var powerup_value = data.get("powerup_counts", {})
	if powerup_value is Dictionary:
		for key in powerup_value:
			EconomyManager.powerup_counts[StringName(str(key))] = maxi(0, int(powerup_value[key]))
	GameManager.high_score = maxi(0, int(data.get("high_score", 0)))
	GameManager.time_attack_high_score = maxi(0, int(data.get("time_attack_high_score", 0)))
	GameManager.lifetime_highest_tier = clampi(int(data.get("lifetime_highest_tier", 0)), 0, Enums.FruitTier.WATERMELON)
	GameManager.discovered_tiers.clear()
	var discoveries = data.get("discovered_tiers", [0])
	if discoveries is Array:
		for tier in discoveries:
			var checked_tier := clampi(int(tier), 0, Enums.FruitTier.WATERMELON)
			if checked_tier not in GameManager.discovered_tiers:
				GameManager.discovered_tiers.append(checked_tier)
	if GameManager.discovered_tiers.is_empty():
		GameManager.discovered_tiers.append(Enums.FruitTier.CHERRY)
	GameManager.discovered_tiers.sort()
	GameManager.statistics = GameManager.sanitize_statistics(data.get("statistics", {}))
	GameManager.mission_data = data.get("mission_data", {}) if data.get("mission_data", {}) is Dictionary else {}
	GameManager.daily_mission_data = data.get("daily_mission_data", {}) if data.get("daily_mission_data", {}) is Dictionary else {}
	GameManager.achievement_data = data.get("achievement_data", {}) if data.get("achievement_data", {}) is Dictionary else {}
	_settings = data.get("settings", {}).duplicate(true)
	_ensure_default_ownership()
	PowerLoadoutManager.load_from_save(_settings)
	MissionManager.load_progress(GameManager.mission_data, false)


func _apply_new_profile_defaults() -> void:
	_settings = {
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"vibration_enabled": true,
		"haptic_strength": 1.0,
		"screen_shake_strength": 1.0,
		"reduced_motion": false,
		"locale": "en",
		"power_loadout": ["powerup_level_up", "powerup_shake_box", "powerup_remove_smallest"],
	}
	GameManager.high_score = 0
	GameManager.time_attack_high_score = 0
	GameManager.discovered_tiers = [Enums.FruitTier.CHERRY]
	GameManager.statistics = GameManager.default_statistics()
	GameManager.mission_data = {}
	GameManager.daily_mission_data = {}
	GameManager.achievement_data = {}
	_ensure_default_ownership()
	PowerLoadoutManager.load_from_save(_settings)
	MissionManager.load_progress({}, true)


func _ensure_default_ownership() -> void:
	if &"skin_default" not in EconomyManager.owned_items:
		EconomyManager.owned_items.append(&"skin_default")
	if EconomyManager.get_equipped_item(&"skin").is_empty():
		_settings["equipped_skin"] = &"skin_default"


func save_run_result(run_score: int) -> void:
	if GameManager.run_reward_claimed:
		return
	GameManager.run_reward_claimed = true
	EconomyManager.add_coins(maxi(0, int(run_score * 0.1)))
	GameManager.statistics["runs_completed"] = int(GameManager.statistics.get("runs_completed", 0)) + 1
	save_game()


func get_setting(key: String, default = null):
	return _settings.get(key, default)


func set_setting(key: String, value, save_immediately := true) -> void:
	_settings[key] = value
	if save_immediately:
		request_save()


func set_settings(values: Dictionary) -> void:
	for key in values:
		_settings[key] = values[key]
	request_save()


func is_loaded() -> bool:
	return _loaded


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _loaded:
			save_game()
