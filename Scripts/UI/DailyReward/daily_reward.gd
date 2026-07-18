class_name DailyReward
extends Control

const HOME_SCENE := "res://Scenes/UI/Home/home.tscn"
const COIN_ICON: Texture2D = preload("res://Assets/Menu/Coin.png")
const TICKET_ICON: Texture2D = preload("res://Assets/UI/Ticket.png")

# Generated reward cards live inside clipped layout slots. These small insets
# keep rounded corners and their soft shadow away from the slot boundary.
const CARD_INSET_LEFT := 2
const CARD_INSET_TOP := 1
const CARD_INSET_RIGHT := 2
const CARD_INSET_BOTTOM := 3

# Coins buy collectible friends; tickets are the special currency for power-ups.
# Keeping the rewards small and predictable makes the seven-day loop easy to read.
const DAILY_REWARDS := [
	{"currency": &"coins", "amount": 25},
	{"currency": &"coins", "amount": 35},
	{"currency": &"tickets", "amount": 1},
	{"currency": &"coins", "amount": 60},
	{"currency": &"tickets", "amount": 2},
	{"currency": &"coins", "amount": 100},
	{"currency": &"tickets", "amount": 3},
]

@onready var _grid: GridContainer = %RewardsGrid
@onready var _day_seven_slot: Control = %DaySevenSlot
@onready var _claim_button: Button = %ClaimButton
@onready var _status_label: Label = %StatusLabel
@onready var _panel_root: Control = %PanelRoot

var _day_index := 0
var _claimed_today := false


func _ready() -> void:
	_day_index = _get_current_day_index()
	_claimed_today = str(SaveManager.get_setting("daily_reward_last_claim", "")) == _today_string()
	_claim_button.pressed.connect(_on_claim_pressed)
	%CloseButton.pressed.connect(_go_home)
	# GridContainer receives its final size on the first layout pass. Populate after
	# that pass so generated cards can never be wider or taller than the area set
	# in the scene.
	await get_tree().process_frame
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
		stored_day = posmod(stored_day + 1, DAILY_REWARDS.size())
	return stored_day


func _today_string() -> String:
	return Time.get_date_string_from_system()


func _populate_rewards() -> void:
	for child in _grid.get_children():
		child.free()

	var columns := maxi(_grid.columns, 1)
	var horizontal_gap := float(_grid.get_theme_constant("h_separation"))
	var vertical_gap := float(_grid.get_theme_constant("v_separation"))
	var card_width := maxf(1.0, (_grid.size.x - horizontal_gap * float(columns - 1)) / float(columns))
	var card_height := maxf(1.0, (_grid.size.y - vertical_gap) / 2.0)
	var card_size := Vector2(floorf(card_width), floorf(card_height))
	for index in 6:
		_grid.add_child(_create_day_card(index, card_size))
	for child in _day_seven_slot.get_children():
		child.free()
	var day_seven_card := _create_day_seven_card()
	_day_seven_slot.add_child(day_seven_card)
	# The slot is intentionally laid out in the scene. Make the generated card
	# inherit those exact bounds instead of keeping a fixed reward-card size.
	day_seven_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _create_card_slot(card_size := Vector2.ZERO) -> MarginContainer:
	var slot := MarginContainer.new()
	if card_size != Vector2.ZERO:
		slot.custom_minimum_size = card_size
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_constant_override("margin_left", CARD_INSET_LEFT)
	slot.add_theme_constant_override("margin_top", CARD_INSET_TOP)
	slot.add_theme_constant_override("margin_right", CARD_INSET_RIGHT)
	slot.add_theme_constant_override("margin_bottom", CARD_INSET_BOTTOM)
	return slot


func _create_day_card(index: int, card_size: Vector2) -> MarginContainer:
	var slot := _create_card_slot(card_size)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style(_get_card_color(index), _get_card_border(index)))
	slot.add_child(card)

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

	content.add_child(_create_reward_row(index, 35.0, 23))
	return slot


func _create_day_seven_card() -> MarginContainer:
	var slot := _create_card_slot()
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _card_style(Color(1.0, 0.77, 0.16, 1), Color(1, 0.96, 0.66, 1), 22))
	slot.add_child(card)

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

	content.add_child(_create_reward_row(6, 42.0, 26, true))
	return slot


func _create_reward_row(index: int, icon_size: float, font_size: int, include_currency_name := false) -> HBoxContainer:
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 7 if include_currency_name else 4)

	var reward_icon := TextureRect.new()
	reward_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	reward_icon.texture = _reward_icon(index)
	reward_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reward_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reward_row.add_child(reward_icon)

	var amount := Label.new()
	if include_currency_name:
		amount.text = "x%d %s" % [_reward_amount(index), _reward_name(index)]
	else:
		amount.text = "x%d" % _reward_amount(index) if _reward_currency(index) == &"tickets" else "%d" % _reward_amount(index)
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", font_size)
	amount.add_theme_color_override("font_color", Color(1, 0.96, 0.78, 1) if _is_current_day(index) else Color(0.48, 0.27, 0.13, 1))
	reward_row.add_child(amount)
	return reward_row


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
	style.shadow_color = Color(0.31, 0.16, 0.06, 0.12)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.25
	return style


func _is_current_day(index: int) -> bool:
	return index == _day_index and not _claimed_today


func _is_completed(index: int) -> bool:
	if _claimed_today:
		return index <= _day_index
	return index < _day_index


func _reward_currency(index: int) -> StringName:
	return StringName(DAILY_REWARDS[index].get("currency", &"coins"))


func _reward_amount(index: int) -> int:
	return int(DAILY_REWARDS[index].get("amount", 0))


func _reward_icon(index: int) -> Texture2D:
	return TICKET_ICON if _reward_currency(index) == &"tickets" else COIN_ICON


func _reward_name(index: int) -> String:
	return "TICKETS" if _reward_currency(index) == &"tickets" else "COINS"


func _grant_reward(index: int) -> void:
	if _reward_currency(index) == &"tickets":
		EconomyManager.add_tickets(_reward_amount(index))
	else:
		EconomyManager.add_coins(_reward_amount(index))


func _update_claim_button() -> void:
	if _claimed_today:
		_claim_button.text = "CONTINUE"
		_status_label.text = "Today’s fruit treat is safely in your basket!"
	else:
		_claim_button.text = "CLAIM %d %s" % [_reward_amount(_day_index), _reward_name(_day_index)]
		_status_label.text = "Come back tomorrow for the next sweet surprise."


func _on_claim_pressed() -> void:
	if _claimed_today:
		_go_home()
		return
	_claim_button.disabled = true
	RewardPresentationManager.queue_wallet_reward(_reward_currency(_day_index), _reward_amount(_day_index))
	_grant_reward(_day_index)
	SaveManager.set_settings({"daily_reward_day_index": _day_index, "daily_reward_last_claim": _today_string()})
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	_claimed_today = true
	_populate_rewards()
	_update_claim_button()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_claim_button, "scale", Vector2(1.08, 1.08), 0.12)
	tween.tween_property(_claim_button, "scale", Vector2.ONE, 0.22)
	await tween.finished
	await get_tree().create_timer(0.22).timeout
	_go_home()


func _go_home() -> void:
	SceneRouter.go_home()


func _play_intro() -> void:
	_panel_root.pivot_offset = _panel_root.size * 0.5
	_panel_root.scale = Vector2(0.86, 0.86)
	_panel_root.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_root, "scale", Vector2.ONE, 0.38)
	tween.tween_property(_panel_root, "modulate:a", 1.0, 0.22)
