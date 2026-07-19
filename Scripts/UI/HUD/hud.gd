extends Control

const UI_FONT: FontFile = preload("res://Assets/Fonts/NERILLKID Trial.ttf")

@onready var _score_label: Label = %ScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _tickets_label: Label = %TicketsLabel
@onready var _next_fruit_icon: TextureRect = %NextFruitIcon
@onready var _danger_overlay: ColorRect = %DangerOverlay
@onready var _danger_warning: Label = %DangerWarning
@onready var _combo_banner: Control = %ComboBanner
@onready var _combo_multiplier: Label = %ComboMultiplier
@onready var _combo_callout: Label = %ComboCallout
@onready var _score_pop_container: Control = %ScorePopContainer
@onready var _pause_button: TextureButton = %PauseButton
@onready var _pause_menu = $PauseMenu
@onready var _level_up_button: TextureButton = %LevelUpButton
@onready var _shake_button: TextureButton = %ShakeButton
@onready var _remove_button: TextureButton = %RemoveButton
@onready var _grab_button: TextureButton = %GrabButton
@onready var _hammer_button: TextureButton = %HammerButton
@onready var _bomb_button: TextureButton = %BombButton
@onready var _level_up_count: Label = %LevelUpCount
@onready var _shake_count: Label = %ShakeCount
@onready var _remove_count: Label = %RemoveCount
@onready var _grab_count: Label = %GrabCount
@onready var _hammer_count: Label = %HammerCount
@onready var _bomb_count: Label = %BombCount
@onready var _powerup_hint: Label = %PowerupHint
@onready var _tier_reward_banner: Control = %TierRewardBanner
@onready var _tier_reward_label: Label = %TierRewardLabel
@onready var _mode_label: Label = %ModeLabel
@onready var _top_panel: Control = $TopPanel
@onready var _powerup_tray: Control = $PowerupTray
@onready var _next_panel: Control = $NextPanel

var _danger_tween: Tween
var _combo_tween: Tween
var _combo_base_position: Vector2
var _tier_reward_tween: Tween
var _requested_targeting_powerup: StringName = &""
var _power_buttons: Dictionary = {}
var _power_counts: Dictionary = {}
var _power_slots: Dictionary = {}
var _mission_panel: PanelContainer
var _mission_objective: Label
var _mission_progress: ProgressBar
var _tutorial_card: PanelContainer
var _tutorial_title: Label
var _tutorial_text: Label
var _tutorial_icon: TextureRect
var _last_urgent_second := -1

const TICKET_REWARD_TIERS: PackedInt32Array = [
	Enums.FruitTier.PINEAPPLE,
	Enums.FruitTier.DRAGONFRUIT,
	Enums.FruitTier.WATERMELON,
]


func _ready() -> void:
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.high_score_changed.connect(_on_high_score_changed)
	EventBus.coins_changed.connect(_on_coins_changed)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	EventBus.fruit_dropped.connect(_on_fruit_dropped)
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.danger_line_exited.connect(_on_danger_exited)
	_pause_button.pressed.connect(_on_pause_pressed)
	_level_up_button.pressed.connect(func(): _request_powerup(&"powerup_level_up"))
	_shake_button.pressed.connect(func(): _request_powerup(&"powerup_shake_box"))
	_remove_button.pressed.connect(func(): _request_powerup(&"powerup_remove_smallest"))
	_grab_button.pressed.connect(func(): _request_powerup(&"powerup_grab_em"))
	_hammer_button.pressed.connect(func(): _request_powerup(&"powerup_hammer"))
	_bomb_button.pressed.connect(func(): _request_powerup(&"powerup_bomb"))
	EventBus.powerup_count_changed.connect(_on_powerup_count_changed)
	EventBus.powerup_targeting_changed.connect(_on_powerup_targeting_changed)
	EventBus.power_loadout_changed.connect(func(_loadout): _update_powerup_buttons())
	EventBus.run_timer_changed.connect(_on_run_timer_changed)
	_power_buttons = {
		&"powerup_level_up": _level_up_button,
		&"powerup_shake_box": _shake_button,
		&"powerup_remove_smallest": _remove_button,
		&"powerup_grab_em": _grab_button,
		&"powerup_hammer": _hammer_button,
		&"powerup_bomb": _bomb_button,
	}
	_power_counts = {
		&"powerup_level_up": _level_up_count,
		&"powerup_shake_box": _shake_count,
		&"powerup_remove_smallest": _remove_count,
		&"powerup_grab_em": _grab_count,
		&"powerup_hammer": _hammer_count,
		&"powerup_bomb": _bomb_count,
	}
	for item_id in _power_buttons:
		_power_slots[item_id] = (_power_buttons[item_id] as Control).get_parent()
	_danger_overlay.modulate.a = 0.0
	_combo_base_position = _combo_banner.position
	_update_score(GameManager.score)
	_update_high_score(GameManager.get_current_high_score())
	_update_coins(EconomyManager.coins)
	_update_tickets(EconomyManager.tickets)
	_update_next_fruit()
	_update_powerup_buttons()
	_update_mode_label()
	if GameManager.current_mode == Enums.GameMode.MISSIONS:
		_build_mission_ui()
	MobileSafeArea.apply_top_inset(_top_panel, _top_panel.position.y)
	MobileSafeArea.apply_top_inset(_powerup_tray, _powerup_tray.position.y)
	MobileSafeArea.apply_top_inset(_next_panel, _next_panel.position.y)


func _process(_delta: float) -> void:
	if GameManager.current_mode == Enums.GameMode.TIME_ATTACK:
		var whole_seconds := floori(GameManager.run_time_remaining)
		var minutes := floori(float(whole_seconds) / 60.0)
		_mode_label.text = "TIME ATTACK  %02d:%02d" % [minutes, whole_seconds % 60]


func _on_score_changed(new_score: int) -> void:
	_update_score(new_score)


func _on_high_score_changed(new_high: int) -> void:
	_update_high_score(new_high)


func _on_coins_changed(new_amount: int) -> void:
	_update_coins(new_amount)


func _on_tickets_changed(new_amount: int) -> void:
	_update_tickets(new_amount)


func _on_fruit_dropped(_tier: int) -> void:
	_update_next_fruit.call_deferred()


func _on_fruit_merged(_tier: int, pos: Vector2, score_gained: int) -> void:
	if GameManager.active_combo > 1:
		_show_combo(GameManager.active_combo)
		_spawn_score_pop(pos, score_gained)


func _show_combo(combo: int) -> void:
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_multiplier.text = "x%d" % combo
	_combo_callout.text = _get_combo_callout(combo)
	_combo_banner.visible = true
	_combo_banner.pivot_offset = _combo_banner.size * 0.5
	_combo_banner.position = _combo_base_position
	_combo_banner.scale = Vector2(0.52, 0.52)
	_combo_banner.rotation = deg_to_rad(randf_range(-6.0, 6.0))
	_combo_banner.modulate.a = 1.0
	_combo_tween = create_tween().set_parallel(true)
	_combo_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(_combo_banner, "scale", Vector2.ONE, 0.24)
	_combo_tween.tween_property(_combo_banner, "rotation", 0.0, 0.22)
	_combo_tween.tween_property(_combo_banner, "position:y", _combo_base_position.y - 26.0, 0.9).set_delay(0.18)
	_combo_tween.tween_property(_combo_banner, "modulate:a", 0.0, 0.38).set_delay(0.78)
	_combo_tween.chain().tween_callback(func(): _combo_banner.visible = false)


func _get_combo_callout(combo: int) -> String:
	if combo >= 5:
		return "MEGA MERGE!"
	if combo == 4:
		return "FRUIT FRENZY!"
	if combo == 3:
		return "SWEET STREAK!"
	return "JUICY COMBO!"


func _on_danger_entered() -> void:
	HapticManager.pulse(HapticManager.Feedback.DANGER)
	if _danger_tween and _danger_tween.is_valid():
		_danger_tween.kill()
	_danger_warning.visible = true
	_danger_warning.modulate.a = 1.0
	_danger_tween = create_tween().set_loops()
	_danger_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.8, 0.45)
	_danger_tween.parallel().tween_property(_danger_warning, "modulate:a", 0.55, 0.45)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.28, 0.45)
	_danger_tween.parallel().tween_property(_danger_warning, "modulate:a", 1.0, 0.45)


func _on_danger_exited() -> void:
	if _danger_tween and _danger_tween.is_valid():
		_danger_tween.kill()
	_danger_tween = create_tween().set_parallel(true)
	_danger_tween.tween_property(_danger_overlay, "modulate:a", 0.0, 0.35)
	_danger_tween.tween_property(_danger_warning, "modulate:a", 0.0, 0.25)
	_danger_tween.chain().tween_callback(func(): _danger_warning.visible = false)


func _on_pause_pressed() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_pause_menu.open()


func _request_powerup(item_id: StringName) -> void:
	if PowerLoadoutManager.get_available_count(item_id) <= 0:
		return
	_requested_targeting_powerup = item_id
	EventBus.powerup_requested.emit(item_id)


func _on_powerup_count_changed(_item_id: StringName, _count: int) -> void:
	_update_powerup_buttons()


func _update_powerup_buttons() -> void:
	var loadout := PowerLoadoutManager.active_loadout
	_powerup_tray.visible = not loadout.is_empty()
	for item_id in _power_buttons:
		var slot := _power_slots[item_id] as Control
		slot.visible = item_id in loadout
		_update_powerup_button(_power_buttons[item_id], _power_counts[item_id], item_id)


func _update_powerup_button(button: TextureButton, count_label: Label, item_id: StringName) -> void:
	var count := PowerLoadoutManager.get_available_count(item_id)
	count_label.text = "x%d" % count
	button.disabled = count <= 0
	button.modulate = Color.WHITE if count > 0 else Color(0.62, 0.62, 0.62, 0.52)


func _on_powerup_targeting_changed(active: bool, message: String) -> void:
	if not active:
		_requested_targeting_powerup = &""
	_powerup_hint.visible = active
	_powerup_hint.text = message
	for item_id in _power_buttons:
		var button := _power_buttons[item_id] as TextureButton
		var selected: bool = active and _requested_targeting_powerup == item_id
		button.modulate = Color(1.12, 1.12, 0.78, 1.0) if selected else (Color.WHITE if PowerLoadoutManager.get_available_count(item_id) > 0 else Color(0.62, 0.62, 0.62, 0.52))


func _update_mode_label() -> void:
	_mode_label.text = GameManager.get_mode_name().to_upper()


func _on_run_timer_changed(seconds: int) -> void:
	if GameManager.current_mode != Enums.GameMode.TIME_ATTACK:
		return
	var minutes := floori(float(seconds) / 60.0)
	_mode_label.text = "TIME ATTACK  %02d:%02d" % [minutes, seconds % 60]
	if seconds <= 10 and seconds > 0 and seconds != _last_urgent_second:
		_last_urgent_second = seconds
		_mode_label.pivot_offset = _mode_label.size * 0.5
		_mode_label.modulate = Color(1.0, 0.28, 0.18)
		var urgency := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		urgency.tween_property(_mode_label, "scale", Vector2(1.18, 1.18), 0.08)
		urgency.tween_property(_mode_label, "scale", Vector2.ONE, 0.18)
		if seconds in [10, 5, 3, 2, 1]:
			HapticManager.pulse(HapticManager.Feedback.DANGER)
	elif seconds > 10:
		_mode_label.modulate = Color.WHITE


func _build_mission_ui() -> void:
	EventBus.mission_progress_changed.connect(_on_mission_progress_changed)
	EventBus.mission_instruction_changed.connect(_on_mission_instruction_changed)

	_mission_panel = PanelContainer.new()
	_mission_panel.position = Vector2(95, 250)
	_mission_panel.size = Vector2(530, 112)
	_mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_panel.add_theme_stylebox_override("panel", _mission_style(Color(1.0, 0.88, 0.57, 0.96)))
	add_child(_mission_panel)
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 4)
	_mission_panel.add_child(mission_box)
	_mission_objective = _mission_label("MISSION OBJECTIVE", 20)
	mission_box.add_child(_mission_objective)
	_mission_progress = ProgressBar.new()
	_mission_progress.custom_minimum_size.y = 22
	_mission_progress.show_percentage = false
	_mission_progress.add_theme_stylebox_override("background", _mission_style(Color(1.0, 0.96, 0.80, 1.0), 10))
	_mission_progress.add_theme_stylebox_override("fill", _mission_style(Color(0.45, 0.78, 0.25, 1.0), 10))
	mission_box.add_child(_mission_progress)

	_tutorial_card = PanelContainer.new()
	_tutorial_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_card.position = Vector2(-290, -380)
	_tutorial_card.size = Vector2(580, 190)
	_tutorial_card.add_theme_stylebox_override("panel", _mission_style(Color(1.0, 0.78, 0.39, 0.98)))
	add_child(_tutorial_card)
	var guide_row := HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 12)
	_tutorial_card.add_child(guide_row)
	_tutorial_icon = TextureRect.new()
	_tutorial_icon.custom_minimum_size = Vector2(94, 94)
	_tutorial_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tutorial_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	guide_row.add_child(_tutorial_icon)
	var guide_copy := VBoxContainer.new()
	guide_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_row.add_child(guide_copy)
	_tutorial_title = _mission_label("HOW TO MERGE", 23)
	guide_copy.add_child(_tutorial_title)
	_tutorial_text = _mission_label("", 18)
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_copy.add_child(_tutorial_text)
	var hide_button := Button.new()
	hide_button.text = "HIDE HINT"
	hide_button.custom_minimum_size = Vector2(130, 52)
	hide_button.add_theme_font_override("font", UI_FONT)
	hide_button.add_theme_font_size_override("font_size", 16)
	hide_button.pressed.connect(MissionManager.hide_tutorial_hint)
	guide_copy.add_child(hide_button)

	var definition := MissionManager.active_definition
	if definition:
		_on_mission_progress_changed(MissionManager.get_progress_text(), MissionManager.objective_progress, definition.target_count)


func _on_mission_progress_changed(label: String, current: int, target: int) -> void:
	if not _mission_objective:
		return
	_mission_objective.text = "LEVEL %d  -  %s\n%s  (%d/%d)" % [MissionManager.active_definition.level, MissionManager.active_definition.title, label, current, target]
	_mission_progress.max_value = target
	_mission_progress.value = current


func _on_mission_instruction_changed(title: String, message: String, target_tier: int) -> void:
	if not _tutorial_card:
		return
	_tutorial_card.visible = not message.is_empty()
	if message.is_empty():
		return
	_tutorial_title.text = title
	_tutorial_text.text = message
	_tutorial_icon.texture = FruitDatabase.get_visual_texture(target_tier) if target_tier >= 0 else null
	_tutorial_card.pivot_offset = _tutorial_card.size * 0.5
	_tutorial_card.scale = Vector2(0.92, 0.92)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(_tutorial_card, "scale", Vector2.ONE, 0.22)


func _mission_label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.39, 0.19, 0.07))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _mission_style(color: Color, radius := 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.52, 0.22, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _update_score(value: int) -> void:
	_score_label.text = "%d" % value
	_score_label.self_modulate = Color(1.0, 0.65, 0.18) if GameManager.is_new_high_score else Color.WHITE


func _update_high_score(value: int) -> void:
	_high_score_label.text = "Best  %d" % value


func _update_coins(value: int) -> void:
	_coins_label.text = "%d" % value


func _update_tickets(value: int) -> void:
	_tickets_label.text = "%d" % value


func _update_next_fruit() -> void:
	var texture := FruitDatabase.get_visual_texture(GameManager.next_fruit_tier)
	if texture:
		_next_fruit_icon.texture = texture


func show_tier_ticket_reward(created_tier: int, ticket_amount: int) -> void:
	if created_tier not in TICKET_REWARD_TIERS:
		return
	_tier_reward_label.text = "+%d TICKET%s!" % [ticket_amount, "" if ticket_amount == 1 else "S"]
	_tier_reward_banner.visible = true
	_tier_reward_banner.pivot_offset = _tier_reward_banner.size * 0.5
	_tier_reward_banner.scale = Vector2(0.55, 0.55)
	_tier_reward_banner.modulate.a = 0.0
	if _tier_reward_tween and _tier_reward_tween.is_valid():
		_tier_reward_tween.kill()
	_tier_reward_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tier_reward_tween.tween_property(_tier_reward_banner, "scale", Vector2.ONE, 0.22)
	_tier_reward_tween.tween_property(_tier_reward_banner, "modulate:a", 1.0, 0.14)
	_tier_reward_tween.tween_property(_tier_reward_banner, "position:y", 920.0, 0.85).set_delay(0.16)
	_tier_reward_tween.tween_property(_tier_reward_banner, "modulate:a", 0.0, 0.28).set_delay(0.72)
	_tier_reward_tween.chain().tween_callback(func():
		_tier_reward_banner.visible = false
		_tier_reward_banner.position.y = 948.0
	)


func _spawn_score_pop(world_pos: Vector2, score: int) -> void:
	var pop_scene := preload("res://Scenes/UI/Components/score_pop.tscn")
	if not pop_scene:
		return
	var pop: Control = pop_scene.instantiate()
	pop.text = "+%d" % score
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
	pop.position = screen_pos
	_score_pop_container.add_child(pop)
