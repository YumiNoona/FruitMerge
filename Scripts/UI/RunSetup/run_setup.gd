class_name RunSetupPanel
extends Control

signal closed

const FONT: FontFile = preload("res://Assets/Fonts/NERILLKID Trial.ttf")
const MODE_PATHS := [
	"res://Data/Modes/classic.tres",
	"res://Data/Modes/missions.tres",
	"res://Data/Modes/time_attack.tres",
]

var _title: Label
var _subtitle: Label
var _content: VBoxContainer
var _start_button: Button
var _back_button: Button
var _selected_mode: Enums.GameMode = Enums.GameMode.CLASSIC
var _selected_mission := 1
var _selected_powerups: Array[StringName] = []
var _stage := &"modes"


func _ready() -> void:
	_build_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	visible = true
	modulate.a = 0.0
	if not MissionManager.has_started_onboarding():
		_show_mission_intro(1)
	else:
		_show_modes()
	var panel := get_node("Center/Panel") as Control
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.25)


func close() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.20, 0.10, 0.05, 0.72)
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 34.0
	center.offset_bottom = -34.0
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(630, 1020)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 26 if side in ["left", "right"] else 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = _make_label("CHOOSE A MODE", 34, Color(0.43, 0.20, 0.08), true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close_button := _make_button("X", 54.0)
	close_button.custom_minimum_size.x = 58.0
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_subtitle = _make_label("Pick how you want to play.", 20, Color(0.49, 0.31, 0.18), true)
	_subtitle.custom_minimum_size.y = 66.0
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.scroll_deadzone = 8
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	scroll.add_child(_content)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	root.add_child(actions)
	_back_button = _make_button("BACK", 74.0)
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back_button.pressed.connect(_go_back)
	actions.add_child(_back_button)
	_start_button = _make_button("START", 74.0, Color(0.48, 0.78, 0.24))
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(_begin_run)
	actions.add_child(_start_button)


func _show_modes() -> void:
	_stage = &"modes"
	_clear_content()
	_title.text = "CHOOSE A MODE"
	_subtitle.text = "Three ways to play. Finish missions to unlock every mode."
	_back_button.visible = false
	_start_button.visible = false
	for path in MODE_PATHS:
		var definition := load(path) as GameModeDefinition
		if not definition:
			continue
		var unlocked := _is_mode_unlocked(definition.mode)
		var button := _make_button("", 138.0, Color(1.0, 0.73, 0.36) if unlocked else Color(0.65, 0.62, 0.55))
		button.text = "%s\n%s%s" % [definition.display_name.to_upper(), definition.description, "" if unlocked else "\nLOCKED"]
		button.disabled = not unlocked
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_choose_mode.bind(definition.mode))
		_content.add_child(button)


func _choose_mode(mode: Enums.GameMode) -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_selected_mode = mode
	if mode == Enums.GameMode.MISSIONS:
		_show_mission_map()
	else:
		_show_loadout()


func _show_mission_map() -> void:
	_stage = &"missions"
	_clear_content()
	_title.text = "MISSION GARDEN"
	_subtitle.text = "Complete each lesson to grow your skills and unlock Time Attack."
	_back_button.visible = true
	_start_button.visible = false
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for definition in MissionManager.definitions:
		var unlocked := definition.level <= MissionManager.highest_unlocked
		var complete := definition.level in MissionManager.completed_levels
		var button := _make_button("", 150.0, Color(0.45, 0.80, 0.42) if complete else Color(1.0, 0.72, 0.34))
		button.custom_minimum_size.x = 275.0
		button.text = "LEVEL %d\n%s\n%s" % [definition.level, definition.title, "COMPLETE" if complete else ("READY" if unlocked else "LOCKED")]
		button.disabled = not unlocked
		button.pressed.connect(_show_mission_intro.bind(definition.level))
		grid.add_child(button)


func _show_mission_intro(level: int) -> void:
	var definition := MissionManager.get_definition(level)
	if not definition:
		return
	_stage = &"mission_intro"
	_selected_mode = Enums.GameMode.MISSIONS
	_selected_mission = level
	_clear_content()
	_title.text = "LEVEL %d  -  %s" % [level, definition.title]
	var target_data := FruitDatabase.get_fruit(definition.target_tier)
	var target_name := target_data.display_name if target_data else "target fruit"
	_subtitle.text = definition.description
	_back_button.visible = MissionManager.has_started_onboarding()
	_start_button.visible = true
	_start_button.disabled = false
	_start_button.text = "START TUTORIAL" if level == 1 and level not in MissionManager.completed_levels else "START MISSION"

	var target_card := PanelContainer.new()
	target_card.custom_minimum_size.y = 190.0
	target_card.add_theme_stylebox_override("panel", _soft_card_style(Color(1.0, 0.90, 0.64)))
	_content.add_child(target_card)
	var reward_suffix := ""
	if definition.reward_tickets > 0:
		reward_suffix = " + %d ticket%s" % [definition.reward_tickets, "" if definition.reward_tickets == 1 else "s"]
	var objective := _make_label("OBJECTIVE\nCreate %d %s\n\nREWARD  %d coins%s" % [definition.target_count, target_name, definition.reward_coins, reward_suffix], 24, Color(0.43, 0.22, 0.10), true)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_card.add_child(objective)

	if not definition.required_powerup.is_empty():
		var power_card := PanelContainer.new()
		power_card.custom_minimum_size.y = 190.0
		power_card.add_theme_stylebox_override("panel", _soft_card_style(Color(0.79, 0.94, 0.54)))
		_content.add_child(power_card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		power_card.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(128, 128)
		icon.texture = PowerLoadoutManager.get_icon(definition.required_powerup)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var power_text := _make_label("PINNED POWER\n%s\n1 free tutorial use\nInventory will not be consumed." % PowerLoadoutManager.get_display_name(definition.required_powerup), 22, Color(0.29, 0.34, 0.12), false)
		power_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		power_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(power_text)


func _show_loadout() -> void:
	_stage = &"loadout"
	_clear_content()
	_selected_powerups = PowerLoadoutManager.selected_loadout.duplicate()
	_title.text = "PICK 3 POWERS"
	_back_button.visible = true
	_start_button.visible = true
	_start_button.text = "PLAY"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for item_id in PowerLoadoutManager.ALL_POWERUPS:
		var button := _make_button(PowerLoadoutManager.get_display_name(item_id).to_upper(), 170.0)
		button.custom_minimum_size.x = 275.0
		button.toggle_mode = true
		button.button_pressed = item_id in _selected_powerups
		button.icon = PowerLoadoutManager.get_icon(item_id)
		button.icon_max_width = 105
		button.expand_icon = true
		button.add_theme_font_size_override("font_size", 20)
		button.toggled.connect(_toggle_power.bind(item_id, button))
		grid.add_child(button)
	_refresh_loadout_state()


func _toggle_power(pressed: bool, item_id: StringName, button: Button) -> void:
	if pressed:
		if item_id not in _selected_powerups and _selected_powerups.size() < 3:
			_selected_powerups.append(item_id)
		elif item_id not in _selected_powerups:
			button.set_pressed_no_signal(false)
			HapticManager.pulse(HapticManager.Feedback.DANGER)
			return
	else:
		_selected_powerups.erase(item_id)
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_refresh_loadout_state()


func _refresh_loadout_state() -> void:
	_start_button.disabled = _selected_powerups.size() != 3
	_subtitle.text = "%s: selected %d / 3. Choose types; inventory quantities are unchanged." % [GameManager.get_mode_name(_selected_mode), _selected_powerups.size()]


func _begin_run() -> void:
	_start_button.disabled = true
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if _selected_mode == Enums.GameMode.MISSIONS:
		if not MissionManager.start_mission(_selected_mission):
			_start_button.disabled = false
		return
	if not PowerLoadoutManager.set_selected_loadout(_selected_powerups):
		_start_button.disabled = false
		return
	PowerLoadoutManager.prepare_standard_run()
	GameManager.start_new_run(_selected_mode)


func _go_back() -> void:
	match _stage:
		&"mission_intro": _show_mission_map()
		&"missions", &"loadout": _show_modes()
		_: close()


func _is_mode_unlocked(mode: Enums.GameMode) -> bool:
	match mode:
		Enums.GameMode.CLASSIC: return MissionManager.is_classic_unlocked()
		Enums.GameMode.MISSIONS: return true
		Enums.GameMode.TIME_ATTACK: return MissionManager.is_time_attack_unlocked()
	return false


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


func _make_label(text_value: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.83, 0.94))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_button(text_value: String, height: float, color := Color(1.0, 0.72, 0.34)) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.38, 0.18, 0.07))
	button.add_theme_color_override("font_disabled_color", Color(0.38, 0.32, 0.27, 0.72))
	button.add_theme_stylebox_override("normal", _button_style(color))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.88, 0.64, 0.99)
	style.border_color = Color(0.82, 0.45, 0.16)
	style.set_border_width_all(6)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0.22, 0.09, 0.03, 0.28)
	style.shadow_size = 14
	return style


func _soft_card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.52, 0.24)
	style.set_border_width_all(4)
	style.set_corner_radius_all(24)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1.0, 0.46, 0.20)
	style.set_border_width_all(4)
	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
