extends Node

const COMBO_WINDOW := 0.9
const MAX_COMBO_MULTIPLIER := 4.0
const TIME_ATTACK_DURATION := 120.0

var current_state: Enums.GameState = Enums.GameState.MENU
var current_mode: Enums.GameMode = Enums.GameMode.CLASSIC
var score := 0
var high_score := 0
var run_highest_tier := 0
var lifetime_highest_tier := 0
var discovered_tiers: Array[int] = [Enums.FruitTier.CHERRY]
var is_new_high_score := false
var next_fruit_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var active_combo := 0
var combo_timer := 0.0
var run_time_remaining := 0.0
var is_powerup_targeting := false
var run_reward_claimed := false
var statistics: Dictionary = {}
var mission_data: Dictionary = {}
var achievement_data: Dictionary = {}
var _run_rng := RandomNumberGenerator.new()


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
	if current_mode == Enums.GameMode.TIME_ATTACK:
		run_time_remaining = maxf(0.0, run_time_remaining - delta)
		if run_time_remaining <= 0.0:
			change_state(Enums.GameState.GAME_OVER)


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
	next_fruit_tier = Enums.FruitTier.CHERRY
	run_time_remaining = TIME_ATTACK_DURATION if mode == Enums.GameMode.TIME_ATTACK else 0.0
	_seed_run_rng()
	EventBus.score_changed.emit(score)
	change_state(Enums.GameState.PLAYING)
	SceneRouter.go_game()


func _seed_run_rng() -> void:
	if current_mode == Enums.GameMode.DAILY_CHALLENGE:
		_run_rng.seed = hash(Time.get_date_string_from_system())
	else:
		_run_rng.randomize()


func get_random_spawn_index(count: int) -> int:
	return _run_rng.randi_range(0, maxi(0, count - 1))


func add_score(points: int) -> int:
	if combo_timer > 0.0:
		active_combo += 1
	else:
		active_combo = 1
	combo_timer = COMBO_WINDOW
	var multiplier := minf(1.0 + float(active_combo - 1) * 0.25, MAX_COMBO_MULTIPLIER)
	var awarded_points := maxi(0, int(points * multiplier))
	score += awarded_points
	statistics["largest_combo"] = maxi(int(statistics.get("largest_combo", 0)), active_combo)
	if score > high_score:
		high_score = score
		is_new_high_score = true
		EventBus.high_score_changed.emit(high_score)
	EventBus.score_changed.emit(score)
	return awarded_points


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


func is_relaxed_mode() -> bool:
	return current_mode == Enums.GameMode.RELAXED


func get_mode_name(mode: Enums.GameMode = current_mode) -> String:
	return Enums.GameMode.keys()[mode].capitalize()


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
