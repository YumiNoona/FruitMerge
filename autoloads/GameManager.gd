extends Node

var current_state: Enums.GameState = Enums.GameState.MENU
var score: int = 0
var high_score: int = 0
var highest_tier_reached: int = 0
var is_new_high_score: bool = false
var next_fruit_tier: Enums.FruitTier = Enums.FruitTier.CHERRY
var active_combo: int = 0
var combo_timer: float = 0.0
var is_powerup_targeting: bool = false
const COMBO_WINDOW: float = 0.85
const COMBO_MULTIPLIER: float = 1.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			active_combo = 0

func change_state(new_state: Enums.GameState) -> void:
	if new_state == current_state:
		return
	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)
	EventBus.state_changed.emit(new_state)

func _enter_state(state: Enums.GameState) -> void:
	match state:
		Enums.GameState.PLAYING:
			get_tree().paused = false
		Enums.GameState.PAUSED:
			get_tree().paused = true
		Enums.GameState.GAME_OVER:
			get_tree().paused = false
			_save_high_score()
			EventBus.game_over.emit(score)
		Enums.GameState.MENU:
			get_tree().paused = false

func _exit_state(_state: Enums.GameState) -> void:
	pass

func start_new_run() -> void:
	score = 0
	is_new_high_score = false
	highest_tier_reached = 0
	active_combo = 0
	combo_timer = 0.0
	is_powerup_targeting = false
	next_fruit_tier = Enums.FruitTier.CHERRY
	EventBus.score_changed.emit(score)
	change_state(Enums.GameState.PLAYING)
	get_tree().change_scene_to_file("res://main.tscn")

func add_score(points: int) -> int:
	var mult := 1.0
	if combo_timer > 0.0:
		active_combo += 1
	else:
		active_combo = 1
	if active_combo > 1:
		mult = pow(COMBO_MULTIPLIER, active_combo - 1)
	combo_timer = COMBO_WINDOW
	var awarded_points := int(points * mult)
	score += awarded_points
	if score > high_score:
		high_score = score
		is_new_high_score = true
		EventBus.high_score_changed.emit(high_score)
	EventBus.score_changed.emit(score)
	return awarded_points

func get_fruit_data_for_tier(tier: Enums.FruitTier) -> FruitData:
	var db := FruitDatabase
	if db:
		return db.get_fruit(tier)
	return null

func _save_high_score() -> void:
	SaveManager.save_run_result(score)
