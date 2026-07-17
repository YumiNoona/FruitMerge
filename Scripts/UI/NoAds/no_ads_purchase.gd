class_name NoAdsPurchase
extends Control

@onready var _panel_root: Control = %PanelRoot
@onready var _purchase_button: Button = %PurchaseButton
@onready var _status_label: Label = %StatusLabel
@onready var _close_button: TextureButton = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_close_button.pressed.connect(close)
	AdManager.ad_message.connect(_show_status)
	AdManager.no_ads_changed.connect(_on_no_ads_changed)
	_refresh()


func open() -> void:
	_refresh()
	visible = true
	_panel_root.pivot_offset = _panel_root.size * 0.5
	_panel_root.scale = Vector2(0.86, 0.86)
	_panel_root.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel_root, "scale", Vector2.ONE, 0.28)
	tween.tween_property(_panel_root, "modulate:a", 1.0, 0.18)


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_purchase_pressed() -> void:
	AdManager.request_no_ads_purchase()


func _on_no_ads_changed(_owned: bool) -> void:
	_refresh()


func _refresh() -> void:
	var owned := AdManager.has_no_ads()
	_purchase_button.disabled = owned
	_purchase_button.text = "AD-FREE UNLOCKED" if owned else "CONTINUE WITH GOOGLE PLAY"
	_status_label.text = "Your orchard is peacefully ad-free." if owned else "One payment removes forced ads forever. Price is shown by Google Play."


func _show_status(message: String) -> void:
	_status_label.text = message
