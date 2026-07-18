extends Node

const ACHIEVEMENTS := [
	{"id": &"first_merge", "label": "First Merge", "stat": &"total_merges", "target": 1, "tickets": 1},
	{"id": &"combo_five", "label": "Combo 5", "stat": &"largest_combo", "target": 5, "tickets": 2},
	{"id": &"drop_hundred", "label": "Fruit Fan", "stat": &"fruits_dropped", "target": 100, "tickets": 2},
	{"id": &"first_watermelon", "label": "Watermelon!", "stat": &"watermelons_created", "target": 1, "tickets": 3},
]


func _ready() -> void:
	EventBus.statistics_changed.connect(_check)
	_check.call_deferred()


func _check() -> void:
	var unlocked: Array = GameManager.achievement_data.get("unlocked", [])
	var changed := false
	for achievement in ACHIEVEMENTS:
		if achievement.id in unlocked:
			continue
		if int(GameManager.statistics.get(achievement.stat, 0)) >= int(achievement.target):
			unlocked.append(achievement.id)
			EconomyManager.add_tickets(int(achievement.tickets))
			HapticManager.pulse(HapticManager.Feedback.REWARD)
			changed = true
	GameManager.achievement_data["unlocked"] = unlocked
	if changed:
		SaveManager.request_save()


func get_summary() -> String:
	var unlocked: Array = GameManager.achievement_data.get("unlocked", [])
	var lines: PackedStringArray = []
	for achievement in ACHIEVEMENTS:
		var progress := mini(int(GameManager.statistics.get(achievement.stat, 0)), int(achievement.target))
		lines.append("%s  %s" % [achievement.label, "DONE" if achievement.id in unlocked else "%d/%d" % [progress, int(achievement.target)]])
	return "   ".join(lines)
