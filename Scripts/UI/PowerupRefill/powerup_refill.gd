class_name PowerupRefillPanel
extends Control

signal closed
signal refilled(item_id: StringName, source: StringName)

const CurrencyFormatterScript = preload("res://Scripts/UI/Components/currency_formatter.gd")

@onready var _panel: PanelContainer = %PanelRoot
@onready var _title: Label = %Title
@onready var _power_icon: TextureRect = %PowerIcon
@onready var _power_name: Label = %PowerName
@onready var _ticket_balance: Label = %TicketBalance
@onready var _watch_ad_button: Button = %WatchAdButton
@onready var _ticket_button: Button = %TicketButton
@onready var _status: Label = %Status
@onready var _close_button: TextureButton = %CloseButton

var _item: ShopItemData
var _intro_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_ad_button.pressed.connect(_on_watch_ad_pressed)
	_ticket_button.pressed.connect(_on_ticket_pressed)
	_close_button.pressed.connect(close)
	EventBus.tickets_changed.connect(_on_tickets_changed)
	AdManager.ad_message.connect(_on_ad_message)
	AdManager.rewarded_ad_availability_changed.connect(_on_ad_availability_changed)
	AdManager.rewarded_powerup_completed.connect(_on_rewarded_powerup_completed)
	EventBus.state_changed.connect(_on_state_changed)
	visible = false


func open(item_id: StringName) -> void:
	if GameManager.current_state != Enums.GameState.PLAYING:
		return
	_item = PowerLoadoutManager.get_item_data(item_id)
	if not _item:
		return
	_title.text = "REFILL POWER"
	_power_icon.texture = _item.icon
	_power_name.text = _item.display_name.to_upper()
	_status.text = "Get one now and keep your run going."
	visible = true
	_refresh_actions()
	GameManager.change_state(Enums.GameState.PAUSED)
	_play_intro.call_deferred()


func close() -> void:
	if not visible or AdManager.is_rewarded_ad_busy():
		return
	visible = false
	_item = null
	if GameManager.current_state == Enums.GameState.PAUSED:
		GameManager.change_state(Enums.GameState.PLAYING)
	closed.emit()


func _play_intro() -> void:
	if not visible:
		return
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.84, 0.84)
	_panel.modulate.a = 0.0
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(_panel, "modulate:a", 1.0, 0.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _refresh_actions(message := "") -> void:
	if not _item:
		return
	var ticket_cost := _item.refill_ticket_cost
	_ticket_balance.text = "YOUR TICKETS  %s" % CurrencyFormatterScript.format_amount(EconomyManager.tickets)
	_ticket_button.text = "USE %d TICKET%s   +1" % [ticket_cost, "" if ticket_cost == 1 else "S"]
	_ticket_button.disabled = EconomyManager.tickets < ticket_cost or AdManager.is_rewarded_ad_busy()
	var ad_busy := AdManager.is_rewarded_ad_busy()
	_watch_ad_button.text = "WATCHING…" if ad_busy else "WATCH AD   +1"
	_watch_ad_button.disabled = ad_busy or not AdManager.is_rewarded_ad_available()
	_close_button.disabled = ad_busy
	if not message.is_empty():
		_status.text = message
	elif not AdManager.is_rewarded_ad_available() and not ad_busy:
		_status.text = AdManager.get_rewarded_ad_message()


func _on_watch_ad_pressed() -> void:
	if not _item or not AdManager.is_rewarded_ad_available():
		return
	HapticManager.pulse(HapticManager.Feedback.TAP)
	_status.text = "Preparing your reward…"
	AdManager.request_rewarded_powerup(_item.id, 1)
	_refresh_actions("Keep this screen open until the reward is confirmed.")


func _on_ticket_pressed() -> void:
	if not _item:
		return
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if not EconomyManager.try_purchase_powerup_refill(_item):
		_refresh_actions("You need %d tickets for this refill." % _item.refill_ticket_cost)
		_pulse_ticket_button()
		return
	var refilled_id := _item.id
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	refilled.emit(refilled_id, &"tickets")
	close()


func _on_rewarded_powerup_completed(item_id: StringName, _amount: int) -> void:
	if not visible or not _item or item_id != _item.id:
		return
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	refilled.emit(item_id, &"ad")
	close()


func _on_tickets_changed(_amount: int) -> void:
	if visible:
		_refresh_actions()


func _on_ad_availability_changed(_available: bool, message: String) -> void:
	if visible:
		_refresh_actions(message)


func _on_ad_message(message: String) -> void:
	if visible:
		_status.text = message


func _on_state_changed(state: Enums.GameState) -> void:
	if visible and state not in [Enums.GameState.PLAYING, Enums.GameState.PAUSED]:
		visible = false
		_item = null


func _pulse_ticket_button() -> void:
	var pulse := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(_ticket_button, "scale", Vector2(1.05, 1.05), 0.09)
	pulse.tween_property(_ticket_button, "scale", Vector2.ONE, 0.16)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not AdManager.is_rewarded_ad_busy():
		get_viewport().set_input_as_handled()
		close()
