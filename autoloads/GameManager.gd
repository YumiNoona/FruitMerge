extends Node

const COMBO_WINDOW := 0.9
const MAX_COMBO_MULTIPLIER := 4.0
const TIME_ATTACK_CONFIG: GameModeDefinition = preload("res://Data/Modes/time_attack.tres")
const TIME_ATTACK_RESOLVE_DELAY := 0.35

var current_state: Enums.GameState = Enums.GameState.MENU
var current_mode: Enums.GameMode = Enums.GameMode.CLASSIC
var score := 0
var high_score := 0
var time_attack_high_score := 0
var run_highest_tier := 0
var lifetime_highest_tier := 0
var discovered_tiers: Array[int] = [Enums.FruitTier.CHERRY]
var is_new_high_score := false
var next_fruit_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var second_next_fruit_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var show_second_next_preview := false
var active_combo := 0
var combo_timer := 0.0
var combo_window_bonus := 0.0
var run_time_remaining := 0.0
var run_end_reason := ""
var run_input_locked := false
var is_powerup_targeting := false
var run_reward_claimed := false
var statistics: Dictionary = {}
var mission_data: Dictionary = {}
var daily_mission_data: Dictionary = {}
var achievement_data: Dictionary = {}
var _run_rng := RandomNumberGenerator.new()
var _time_attack_finishing := false
var _last_timer_second := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	statistics = default_statistics()


func _process(delta: float) -> void:
	if current_state != Enums.GameState.PLAYING:
		return
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			active_combo = 0
	if current_mode == Enums.GameMode.TIME_ATTACK and not _time_attack_finishing:
		run_time_remaining = maxf(0.0, run_time_remaining - delta)
		var whole_seconds := ceili(run_time_remaining)
		if whole_seconds != _last_timer_second:
			_last_timer_second = whole_seconds
			EventBus.run_timer_changed.emit(whole_seconds)
		if run_time_remaining <= 0.0:
			_finish_time_attack.call_deferred()


func change_state(new_state: Enums.GameState) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	match new_state:
		Enums.GameState.PLAYING:
			get_tree().paused = false
		Enums.GameState.PAUSED:
			get_tree().paused = true
		Enums.GameState.GAME_OVER:
			get_tree().paused = false
			run_input_locked = true
			SaveManager.save_run_result(score)
			EventBus.game_over.emit(score)
		Enums.GameState.MENU, Enums.GameState.SHOP:
			get_tree().paused = false
	EventBus.state_changed.emit(new_state)


func start_new_run(mode := -1) -> void:
	if mode >= 0:
		current_mode = mode as Enums.GameMode
	score = 0
	is_new_high_score = false
	run_highest_tier = 0
	active_combo = 0
	combo_timer = 0.0
	is_powerup_targeting = false
	run_reward_claimed = false
	run_end_reason = ""
	run_input_locked = false
	_time_attack_finishing = false
	next_fruit_tier = Enums.FruitTier.CHERRY
	second_next_fruit_tier = Enums.FruitTier.CHERRY
	show_second_next_preview = false
	combo_window_bonus = 0.0
	run_time_remaining = TIME_ATTACK_CONFIG.duration_seconds if current_mode == Enums.GameMode.TIME_ATTACK else 0.0
	_last_timer_second = ceili(run_time_remaining)
	_seed_run_rng()
	EventBus.score_changed.emit(score)
	EventBus.high_score_changed.emit(get_current_high_score())
	if current_mode == Enums.GameMode.TIME_ATTACK:
		EventBus.run_timer_changed.emit(_last_timer_second)
	change_state(Enums.GameState.PLAYING)
	SceneRouter.go_game()


func end_run(reason: String) -> void:
	if current_state != Enums.GameState.PLAYING:
		return
	run_end_reason = reason
	run_input_locked = true
	change_state(Enums.GameState.GAME_OVER)


func can_accept_gameplay_input() -> bool:
	return current_state == Enums.GameState.PLAYING and not run_input_locked


func _finish_time_attack() -> void:
	if _time_attack_finishing or current_state != Enums.GameState.PLAYING:
		return
	_time_attack_finishing = true
	run_input_locked = true
	run_end_reason = "time_up"
	await get_tree().create_timer(TIME_ATTACK_RESOLVE_DELAY).timeout
	if current_state == Enums.GameState.PLAYING:
		change_state(Enums.GameState.GAME_OVER)


func _seed_run_rng() -> void:
	_run_rng.randomize()


func get_random_spawn_index(count: int) -> int:
	return _run_rng.randi_range(0, maxi(0, count - 1))


func add_score(points: int) -> int:
	if combo_timer > 0.0:
		active_combo += 1
	else:
		active_combo = 1
	combo_timer = COMBO_WINDOW + maxf(0.0, combo_window_bonus)
	var multiplier := minf(1.0 + float(active_combo - 1) * 0.25, MAX_COMBO_MULTIPLIER)
	var awarded_points := maxi(0, int(points * multiplier))
	score += awarded_points
	statistics["largest_combo"] = maxi(int(statistics.get("largest_combo", 0)), active_combo)
	if current_mode == Enums.GameMode.CLASSIC and score > high_score:
		high_score = score
		is_new_high_score = true
		EventBus.high_score_changed.emit(high_score)
	elif current_mode == Enums.GameMode.TIME_ATTACK and score > time_attack_high_score:
		time_attack_high_score = score
		is_new_high_score = true
		EventBus.high_score_changed.emit(time_attack_high_score)
	EventBus.score_changed.emit(score)
	return awarded_points


func get_current_high_score() -> int:
	return time_attack_high_score if current_mode == Enums.GameMode.TIME_ATTACK else high_score


func record_drop(tier: int) -> void:
	statistics["fruits_dropped"] = int(statistics.get("fruits_dropped", 0)) + 1
	statistics["daily_fruits_dropped"] = int(statistics.get("daily_fruits_dropped", 0)) + 1
	register_fruit_discovered(tier)
	EventBus.statistics_changed.emit()


func record_merge(created_tier: int) -> void:
	statistics["total_merges"] = int(statistics.get("total_merges", 0)) + 1
	statistics["daily_merges"] = int(statistics.get("daily_merges", 0)) + 1
	if created_tier == Enums.FruitTier.WATERMELON:
		statistics["watermelons_created"] = int(statistics.get("watermelons_created", 0)) + 1
	register_fruit_discovered(created_tier)
	EventBus.statistics_changed.emit()


func record_powerup_used() -> void:
	statistics["powerups_used"] = int(statistics.get("powerups_used", 0)) + 1
	statistics["daily_powerups_used"] = int(statistics.get("daily_powerups_used", 0)) + 1
	EventBus.statistics_changed.emit()


func register_fruit_discovered(tier: int) -> void:
	var valid_tier := clampi(tier, 0, Enums.FruitTier.WATERMELON)
	run_highest_tier = maxi(run_highest_tier, valid_tier)
	lifetime_highest_tier = maxi(lifetime_highest_tier, valid_tier)
	if valid_tier not in discovered_tiers:
		discovered_tiers.append(valid_tier)
		discovered_tiers.sort()
		EventBus.fruit_discovered.emit(valid_tier)
		SaveManager.request_save()


func get_mode_name(mode: Enums.GameMode = current_mode) -> String:
	match mode:
		Enums.GameMode.CLASSIC: return "Classic"
		Enums.GameMode.MISSIONS: return "Missions"
		Enums.GameMode.TIME_ATTACK: return "Time Attack"
	return "Classic"


func default_statistics() -> Dictionary:
	return {
		"fruits_dropped": 0,
		"total_merges": 0,
		"largest_combo": 0,
		"watermelons_created": 0,
		"powerups_used": 0,
		"runs_completed": 0,
		"daily_fruits_dropped": 0,
		"daily_merges": 0,
		"daily_powerups_used": 0,
	}


func sanitize_statistics(value) -> Dictionary:
	var clean := default_statistics()
	if value is Dictionary:
		for key in clean:
			clean[key] = maxi(0, int(value.get(key, 0)))
	return clean
