extends Node

const MISSIONS := [
	{"key": "daily_fruits_dropped", "label": "Drop 25 fruits", "target": 25, "currency": &"coins", "reward": 40},
	{"key": "daily_merges", "label": "Make 12 merges", "target": 12, "currency": &"tickets", "reward": 1},
	{"key": "daily_powerups_used", "label": "Use 2 power-ups", "target": 2, "currency": &"tickets", "reward": 1},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.statistics_changed.connect(_check_missions)
	_initialize_day.call_deferred()


func _initialize_day() -> void:
	var today := Time.get_date_string_from_system()
	if str(GameManager.mission_data.get("date", "")) != today:
		GameManager.mission_data = {"date": today, "claimed": []}
		GameManager.statistics["daily_fruits_dropped"] = 0
		GameManager.statistics["daily_merges"] = 0
		GameManager.statistics["daily_powerups_used"] = 0
		SaveManager.request_save()
	_check_missions()


func _check_missions() -> void:
	var claimed: Array = GameManager.mission_data.get("claimed", [])
	var changed := false
	for index in MISSIONS.size():
		if index in claimed:
			continue
		var mission: Dictionary = MISSIONS[index]
		if int(GameManager.statistics.get(mission.key, 0)) >= int(mission.target):
			claimed.append(index)
			if mission.currency == &"tickets":
				EconomyManager.add_tickets(int(mission.reward))
			else:
				EconomyManager.add_coins(int(mission.reward))
			HapticManager.pulse(HapticManager.Feedback.REWARD)
			changed = true
	GameManager.mission_data["claimed"] = claimed
	if changed:
		EventBus.daily_missions_changed.emit()
		SaveManager.request_save()


func get_summary() -> String:
	var lines: PackedStringArray = []
	var claimed: Array = GameManager.mission_data.get("claimed", [])
	for index in MISSIONS.size():
		var mission: Dictionary = MISSIONS[index]
		var progress := mini(int(GameManager.statistics.get(mission.key, 0)), int(mission.target))
		var suffix := "CLAIMED" if index in claimed else "%d/%d" % [progress, int(mission.target)]
		lines.append("%s  -  %s" % [mission.label, suffix])
	return "\n".join(lines)
