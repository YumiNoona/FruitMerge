extends Control

@export_category("Final frame capture")
@export_range(0.60, 1.0, 0.01) var snapshot_width_fraction := 0.86
@export_range(0.35, 0.75, 0.01) var snapshot_vertical_focus := 0.60
@export_range(360, 1080, 60) var snapshot_max_width := 720

@onready var _result_card: Control = %ResultCard
@onready var _final_snapshot: TextureRect = %FinalSnapshot
@onready var _snapshot_flash: ColorRect = %SnapshotFlash
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_earned_label: Label = %CoinsEarnedLabel
@onready var _score_label: Label = %NewHighLabel
@onready var _restart_button: TextureButton = %RestartButton
@onready var _menu_button: TextureButton = %MenuButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _title: Label = $Center/ResultCard/Title
@onready var _encouragement: Label = $Center/ResultCard/Encouragement
@onready var _settings_menu: SettingsMenu = $SettingsMenu

var _captured_texture: ImageTexture
var _intro_tween: Tween
var _snapshot_settle_tween: Tween


func _ready() -> void:
	_restart_button.pressed.connect(_on_restart)
	_menu_button.pressed.connect(_on_menu)
	_settings_button.pressed.connect(_settings_menu.open)
	EventBus.game_over.connect(_on_game_over)
	_populate(GameManager.score)


func _on_game_over(final_score: int) -> void:
	HapticManager.pulse(HapticManager.Feedback.GAME_OVER)
	visible = false
	# Wait for the run's last rendered frame while this overlay is still hidden.
	# The headless test renderer has no frame-post-draw signal or readable texture.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_capture_final_frame()
	_populate(final_score)
	visible = true
	_play_intro()


func _capture_final_frame() -> void:
	var viewport_texture := get_viewport().get_texture()
	if not viewport_texture:
		return
	var screenshot: Image = viewport_texture.get_image()
	if not screenshot or screenshot.is_empty():
		return

	# Crop around the center-lower gameplay area so the filled container is the
	# subject instead of the HUD. The crop adopts the authored snapshot aspect.
	var target_size := _final_snapshot.size
	var target_aspect := maxf(target_size.x / maxf(target_size.y, 1.0), 0.1)
	var source_width := screenshot.get_width()
	var source_height := screenshot.get_height()
	var crop_width := clampi(roundi(float(source_width) * snapshot_width_fraction), 1, source_width)
	var crop_height := maxi(1, roundi(float(crop_width) / target_aspect))
	if crop_height > source_height:
		crop_height = source_height
		crop_width = mini(source_width, maxi(1, roundi(float(crop_height) * target_aspect)))
	var crop_x := maxi(0, floori(float(source_width - crop_width) / 2.0))
	var focus_y := roundi(float(source_height) * snapshot_vertical_focus)
	var crop_y := clampi(
		focus_y - floori(float(crop_height) / 2.0),
		0,
		source_height - crop_height
	)
	screenshot = screenshot.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))

	if screenshot.get_width() > snapshot_max_width:
		var resized_height := maxi(1, roundi(
			float(screenshot.get_height()) * float(snapshot_max_width) / float(screenshot.get_width())
		))
		screenshot.resize(snapshot_max_width, resized_height, Image.INTERPOLATE_LANCZOS)
	_captured_texture = ImageTexture.create_from_image(screenshot)
	_final_snapshot.texture = _captured_texture


func _populate(score: int) -> void:
	var coins_earned := int(score * 0.1)
	_score_label.visible = true
	_score_label.text = "NEW BEST  •  SCORE %d" % score if GameManager.is_new_high_score else "SCORE  %d" % score
	_high_score_label.text = "Best  %d" % GameManager.get_current_high_score()
	_coins_earned_label.text = "+%d coins" % coins_earned
	_restart_button.tooltip_text = "Play again"
	match GameManager.current_mode:
		Enums.GameMode.MISSIONS:
			_populate_mission_result()
		Enums.GameMode.TIME_ATTACK:
			_title.text = "TIME'S UP!"
			_encouragement.text = "Your best two-minute harvest is saved"
		_:
			_title.text = "FRUIT BASKET FULL"
			_encouragement.text = "Every drop grows your garden"


func _populate_mission_result() -> void:
	var definition := MissionManager.active_definition
	var completed := GameManager.run_end_reason == "mission_complete"
	_title.text = "MISSION COMPLETE!" if completed else "MISSION FAILED"
	_score_label.text = "LEVEL %d  •  %s" % [
		definition.level if definition else 1,
		"COMPLETE" if completed else "TRY AGAIN",
	]
	_high_score_label.text = "Level %d" % definition.level if definition else "Mission"
	if completed and definition:
		_coins_earned_label.text = "+%d coins  +%d tickets" % [definition.reward_coins, definition.reward_tickets]
		_encouragement.text = "A new lesson is ready!" if definition.level < 7 else "All modes are now unlocked!"
		_restart_button.tooltip_text = "Next mission" if definition.level < 7 else "Continue"
	else:
		_coins_earned_label.text = "Tutorial power stays free"
		_encouragement.text = "Try the guided hint again"
		_restart_button.tooltip_text = "Retry mission"


func _play_intro() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	if _snapshot_settle_tween and _snapshot_settle_tween.is_valid():
		_snapshot_settle_tween.kill()

	_result_card.pivot_offset = _result_card.size * 0.5
	_result_card.scale = Vector2(0.84, 0.84)
	_result_card.modulate.a = 0.0
	_final_snapshot.pivot_offset = _final_snapshot.size * 0.5
	_final_snapshot.scale = Vector2(0.92, 0.92)
	_final_snapshot.modulate.a = 0.0
	_snapshot_flash.modulate.a = 0.72

	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(_result_card, "scale", Vector2.ONE, 0.44).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_result_card, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_final_snapshot, "scale", Vector2.ONE, 0.52).set_delay(0.10).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_final_snapshot, "modulate:a", 1.0, 0.24).set_delay(0.08)
	_intro_tween.tween_property(_snapshot_flash, "modulate:a", 0.0, 0.48).set_delay(0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _intro_tween.finished
	if not is_inside_tree() or not visible:
		return
	_snapshot_settle_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_snapshot_settle_tween.tween_property(_final_snapshot, "scale", Vector2(1.018, 1.018), 2.6)


func _on_restart() -> void:
	_restart_button.disabled = true
	if GameManager.current_mode == Enums.GameMode.MISSIONS:
		var definition := MissionManager.active_definition
		if GameManager.run_end_reason == "mission_complete" and definition and definition.level < 7:
			MissionManager.start_mission(definition.level + 1)
		elif GameManager.run_end_reason != "mission_complete":
			MissionManager.restart_active_mission()
		else:
			GameManager.change_state(Enums.GameState.MENU)
			SceneRouter.go_home()
		return
	PowerLoadoutManager.prepare_standard_run()
	GameManager.start_new_run()


func _on_menu() -> void:
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()
