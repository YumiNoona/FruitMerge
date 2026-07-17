class_name DailyReward
extends Control

const HOME_SCENE := "res://Scenes/UI/Home/home.tscn"
const MAIN_MENU_MUSIC: AudioStream = preload("res://Audio/Music/Main Menu.wav")
const COIN_ICON: Texture2D = preload("res://Assets/Menu/Coin.png")
const DAILY_COIN_REWARDS: PackedInt32Array = [25, 35, 45, 60, 75, 100, 250]

@onready var _grid: GridContainer = %RewardsGrid
@onready var _day_seven_slot: Control = %DaySevenSlot
@onready var _claim_button: Button = %ClaimButton
@onready var _status_label: Label = %StatusLabel
@onready var _panel_root: Control = %PanelRoot

var _day_index := 0
var _claimed_today := false


func _ready() -> void:
	AudioManager.play_music(MAIN_MENU_MUSIC)
	_day_index = _get_current_day_index()
	_claimed_today = str(SaveManager.get_setting("daily_reward_last_claim", "")) == _today_string()
	_claim_button.pressed.connect(_on_claim_pressed)
	%CloseButton.pressed.connect(_go_home)
	_populate_rewards()
	_update_claim_button()
	_play_intro.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_home()


func _get_current_day_index() -> int:
	var stored_day := int(SaveManager.get_setting("daily_reward_day_index", 0))
	var last_claim := str(SaveManager.get_setting("daily_reward_last_claim", ""))
	if not last_claim.is_empty() and last_claim != _today_string():
		stored_day = posmod(stored_day + 1, DAILY_COIN_REWARDS.size())
	return stored_day


func _today_string() -> String:
	return Time.get_date_string_from_system()


func _populate_rewards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for index in 6:
		_grid.add_child(_create_day_card(index))
	for child in _day_seven_slot.get_children():
		child.queue_free()
	var day_seven_card := _create_day_seven_card()
	_day_seven_slot.add_child(day_seven_card)
	# The slot is intentionally laid out in the scene. Make the generated card
	# inherit those exact bounds instead of keeping a fixed reward-card size.
	day_seven_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _create_day_card(index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(174, 106)
	card.add_theme_stylebox_override("panel", _card_style(_get_card_color(index), _get_card_border(index)))

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	card.add_child(content)

	var day_label := Label.new()
	day_label.text = "TODAY" if _is_current_day(index) else "DAY %d" % (index + 1)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 17)
	day_label.add_theme_color_override("font_color", Color(1, 0.98, 0.89, 1) if _is_current_day(index) else Color(0.47, 0.27, 0.13, 1))
	content.add_child(day_label)

	if _is_completed(index):
		var check := Label.new()
		check.text = "✓"
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 43)
		check.add_theme_color_override("font_color", Color(0.48, 0.75, 0.28, 1))
		content.add_child(check)
	else:
		var reward_row := HBoxContainer.new()
		reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_row.add_theme_constant_override("separation", 4)
		content.add_child(reward_row)

		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(35, 35)
		coin.texture = COIN_ICON
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reward_row.add_child(coin)

		var amount := Label.new()
		amount.text = "%d" % DAILY_COIN_REWARDS[index]
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", 23)
		amount.add_theme_color_override("font_color", Color(1, 0.96, 0.78, 1) if _is_current_day(index) else Color(0.48, 0.27, 0.13, 1))
		reward_row.add_child(amount)
	return card


func _create_day_seven_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _card_style(Color(1.0, 0.77, 0.16, 1), Color(1, 0.96, 0.66, 1), 22))

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	card.add_child(content)

	var title := Label.new()
	title.text = "DAY 7  •  MEGA HARVEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.45, 0.23, 0.08, 1))
	content.add_child(title)

	if _is_completed(6):
		var check := Label.new()
		check.text = "✓  COLLECTED"
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 28)
		check.add_theme_color_override("font_color", Color(0.38, 0.61, 0.18, 1))
		content.add_child(check)
	else:
		var reward_row := HBoxContainer.new()
		reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_row.add_theme_constant_override("separation", 7)
		content.add_child(reward_row)

		var coin := TextureRect.new()
		coin.custom_minimum_size = Vector2(42, 42)
		coin.texture = COIN_ICON
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reward_row.add_child(coin)

		var amount := Label.new()
		amount.text = "%d coins" % DAILY_COIN_REWARDS[6]
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", 26)
		amount.add_theme_color_override("font_color", Color(0.45, 0.23, 0.08, 1))
		reward_row.add_child(amount)
	return card


func _get_card_color(index: int) -> Color:
	if _is_completed(index):
		return Color(0.56, 0.47, 0.34, 1)
	if _is_current_day(index):
		return Color(0.16, 0.69, 0.9, 1)
	return Color(1.0, 0.88, 0.62, 1)


func _get_card_border(index: int) -> Color:
	if _is_current_day(index):
		return Color(0.75, 0.96, 1.0, 1)
	if _is_completed(index):
		return Color(0.72, 0.63, 0.47, 1)
	return Color(1.0, 0.95, 0.8, 1)


func _card_style(background: Color, border: Color, radius := 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.31, 0.16, 0.06, 0.26)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	return style


func _is_current_day(index: int) -> bool:
	return index == _day_index and not _claimed_today


func _is_completed(index: int) -> bool:
	if _claimed_today:
		return index <= _day_index
	return index < _day_index


func _update_claim_button() -> void:
	if _claimed_today:
		_claim_button.text = "CONTINUE"
		_status_label.text = "Today’s fruit treat is safely in your basket!"
	else:
		_claim_button.text = "CLAIM %d COINS" % DAILY_COIN_REWARDS[_day_index]
		_status_label.text = "Come back tomorrow for the next sweet surprise."


func _on_claim_pressed() -> void:
	if _claimed_today:
		_go_home()
		return
	EconomyManager.add_coins(DAILY_COIN_REWARDS[_day_index])
	SaveManager.set_setting("daily_reward_day_index", _day_index)
	SaveManager.set_setting("daily_reward_last_claim", _today_string())
	_claimed_today = true
	_populate_rewards()
	_update_claim_button()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_claim_button, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(_claim_button, "scale", Vector2.ONE, 0.22)


func _go_home() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


func _play_intro() -> void:
	_panel_root.pivot_offset = _panel_root.size * 0.5
	_panel_root.scale = Vector2(0.86, 0.86)
	_panel_root.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_root, "scale", Vector2.ONE, 0.38)
	tween.tween_property(_panel_root, "modulate:a", 1.0, 0.22)
