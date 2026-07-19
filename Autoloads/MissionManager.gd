extends Node

const MISSION_PATHS := [
	"res://Data/Missions/mission_01.tres",
	"res://Data/Missions/mission_02.tres",
	"res://Data/Missions/mission_03.tres",
	"res://Data/Missions/mission_04.tres",
	"res://Data/Missions/mission_05.tres",
	"res://Data/Missions/mission_06.tres",
	"res://Data/Missions/mission_07.tres",
]

var definitions: Array[MissionDefinition] = []
var highest_unlocked := 1
var completed_levels: Array[int] = []
var onboarding_started := false
var onboarding_completed := false
var active_definition: MissionDefinition
var objective_progress := 0
var required_power_used := false
var tutorial_hidden := false

var _temporary_counts: Dictionary = {}
var _spawn_cursor := 0
var _is_completing := false
var _seeded_fruits: Array[Fruit] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in MISSION_PATHS:
		var definition := load(path) as MissionDefinition
		if definition:
			definitions.append(definition)
	EventBus.fruit_created.connect(_on_fruit_created)
	EventBus.fruit_dropped.connect(_on_fruit_dropped)
	EventBus.powerup_used.connect(_on_powerup_used)


func load_progress(data: Dictionary, is_new_profile: bool) -> void:
	if is_new_profile:
		highest_unlocked = 1
		completed_levels.clear()
		onboarding_started = false
		onboarding_completed = false
	else:
		highest_unlocked = clampi(int(data.get("highest_unlocked", 7)), 1, 7)
		completed_levels.clear()
		for value in data.get("completed_levels", [1, 2, 3, 4, 5, 6, 7]):
			var level := clampi(int(value), 1, 7)
			if level not in completed_levels:
				completed_levels.append(level)
		onboarding_started = bool(data.get("onboarding_started", true))
		onboarding_completed = bool(data.get("onboarding_completed", true))
	_sync_save_data()


func get_definition(level: int) -> MissionDefinition:
	for definition in definitions:
		if definition.level == level:
			return definition
	return null


func start_mission(level: int) -> bool:
	var definition := get_definition(level)
	if not definition or level > highest_unlocked:
		return false
	active_definition = definition
	objective_progress = 0
	required_power_used = definition.required_powerup.is_empty()
	tutorial_hidden = false
	_spawn_cursor = 0
	_is_completing = false
	_seeded_fruits.clear()
	_temporary_counts.clear()
	if not definition.required_powerup.is_empty():
		_temporary_counts[definition.required_powerup] = definition.temporary_charges
	onboarding_started = true
	PowerLoadoutManager.prepare_mission_run(definition.required_powerup)
	_sync_save_data()
	SaveManager.request_save()
	GameManager.start_new_run(Enums.GameMode.MISSIONS)
	return true


func restart_active_mission() -> bool:
	return start_mission(active_definition.level) if active_definition else false


func attach_gameplay(fruit_parent: Node) -> void:
	if GameManager.current_mode != Enums.GameMode.MISSIONS or not active_definition:
		return
	_seed_scenario.call_deferred(fruit_parent)
	_emit_progress()
	_emit_instruction()


func _seed_scenario(fruit_parent: Node) -> void:
	await get_tree().physics_frame
	if not is_instance_valid(fruit_parent) or not active_definition:
		return
	for index in active_definition.starting_tiers.size():
		var tier := active_definition.starting_tiers[index]
		var fruit := FruitDatabase.create_fruit(tier)
		if not fruit:
			continue
		fruit.freeze = true
		fruit_parent.add_child(fruit)
		fruit.global_position = active_definition.starting_positions[index]
		_seeded_fruits.append(fruit)
	await get_tree().physics_frame
	for fruit in _seeded_fruits:
		if is_instance_valid(fruit):
			fruit.freeze = false
			fruit.sleeping = false
	_highlight_scenario_target()


func take_spawn_tier(fallback_tier: int) -> int:
	if GameManager.current_mode != Enums.GameMode.MISSIONS or not active_definition:
		return fallback_tier
	if active_definition.spawn_sequence.is_empty():
		return fallback_tier
	var tier := active_definition.spawn_sequence[_spawn_cursor % active_definition.spawn_sequence.size()]
	_spawn_cursor += 1
	return tier


func get_temporary_count(item_id: StringName) -> int:
	return maxi(0, int(_temporary_counts.get(item_id, 0)))


func consume_temporary_powerup(item_id: StringName) -> bool:
	var count := get_temporary_count(item_id)
	if count <= 0:
		return false
	_temporary_counts[item_id] = count - 1
	return true


func is_classic_unlocked() -> bool:
	return onboarding_completed or 1 in completed_levels


func is_time_attack_unlocked() -> bool:
	return onboarding_completed or 7 in completed_levels


func has_started_onboarding() -> bool:
	return onboarding_started


func get_progress_text() -> String:
	if not active_definition:
		return ""
	var fruit := FruitDatabase.get_fruit(active_definition.target_tier)
	var fruit_name := fruit.display_name if fruit else "target fruit"
	var objective := "Create %d %s" % [active_definition.target_count, fruit_name]
	if not active_definition.required_powerup.is_empty():
		var status := "done" if required_power_used else "not used"
		objective += "  |  %s: %s" % [PowerLoadoutManager.get_display_name(active_definition.required_powerup), status]
	return objective


func hide_tutorial_hint() -> void:
	tutorial_hidden = true
	EventBus.mission_instruction_changed.emit("", "", -1)


func _on_fruit_created(tier: int, _world_pos: Vector2) -> void:
	if not _is_active_run() or tier != active_definition.target_tier:
		return
	objective_progress = mini(active_definition.target_count, objective_progress + 1)
	_emit_progress()
	_emit_instruction()
	_check_completion()


func _on_fruit_dropped(_tier: int) -> void:
	if _is_active_run() and not tutorial_hidden and active_definition.level == 1 and objective_progress == 0:
		EventBus.mission_instruction_changed.emit(
			"MATCH THE FRUIT",
			"Aim the next matching fruit onto its twin. Identical fruit merge automatically.",
			active_definition.target_tier - 1
		)


func _on_powerup_used(item_id: StringName) -> void:
	if not _is_active_run() or item_id != active_definition.required_powerup:
		return
	required_power_used = true
	_emit_progress()
	_emit_instruction()
	_check_completion()


func _check_completion() -> void:
	if _is_completing or not _is_active_run():
		return
	if objective_progress < active_definition.target_count or not required_power_used:
		return
	_is_completing = true
	var completed_level := active_definition.level
	if completed_level not in completed_levels:
		completed_levels.append(completed_level)
	completed_levels.sort()
	highest_unlocked = mini(7, maxi(highest_unlocked, completed_level + 1))
	if completed_level >= 7:
		onboarding_completed = true
	if active_definition.reward_coins > 0:
		EconomyManager.add_coins(active_definition.reward_coins)
	if active_definition.reward_tickets > 0:
		EconomyManager.add_tickets(active_definition.reward_tickets)
	_sync_save_data()
	SaveManager.save_game()
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	EventBus.mission_completed.emit(completed_level, active_definition.reward_coins, active_definition.reward_tickets)
	GameManager.end_run("mission_complete")


func _emit_progress() -> void:
	if not active_definition:
		return
	EventBus.mission_progress_changed.emit(get_progress_text(), objective_progress, active_definition.target_count)


func _emit_instruction() -> void:
	if tutorial_hidden or not active_definition:
		return
	var title := "MISSION %d" % active_definition.level
	var message := active_definition.opening_instruction
	var target_tier := active_definition.target_tier - 1
	if not active_definition.required_powerup.is_empty() and not required_power_used:
		title = PowerLoadoutManager.get_display_name(active_definition.required_powerup).to_upper()
		message = active_definition.power_instruction
		target_tier = active_definition.starting_tiers[0] if not active_definition.starting_tiers.is_empty() else -1
	elif objective_progress > 0:
		message = "Great! Keep matching until the objective is complete."
	EventBus.mission_instruction_changed.emit(title, message, target_tier)


func _highlight_scenario_target() -> void:
	if tutorial_hidden or _seeded_fruits.is_empty() or bool(SaveManager.get_setting("reduced_motion", false)):
		return
	var fruit := _seeded_fruits[0]
	if not is_instance_valid(fruit):
		return
	var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	var original := sprite.modulate
	var tween := sprite.create_tween().set_loops(3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate", Color(1.35, 1.25, 0.68, 1.0), 0.34)
	tween.tween_property(sprite, "modulate", original, 0.34)


func _is_active_run() -> bool:
	return GameManager.current_mode == Enums.GameMode.MISSIONS and active_definition != null and GameManager.current_state == Enums.GameState.PLAYING


func _sync_save_data() -> void:
	GameManager.mission_data = {
		"highest_unlocked": highest_unlocked,
		"completed_levels": completed_levels.duplicate(),
		"onboarding_started": onboarding_started,
		"onboarding_completed": onboarding_completed,
	}
