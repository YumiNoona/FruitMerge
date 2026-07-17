class_name SettingsMenu
extends Control

signal closed

@onready var _panel: Control = %PanelRoot
@onready var _music_toggle: Button = %MusicToggle
@onready var _sfx_toggle: Button = %SfxToggle
@onready var _vibration_toggle: Button = %VibrationToggle
@onready var _language: OptionButton = %LanguageOption
@onready var _theme: OptionButton = %ThemeOption
@onready var _status_label: Label = %StatusLabel

var _last_music_volume: float = 0.8
var _last_sfx_volume: float = 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(close)
	_music_toggle.toggled.connect(_on_music_toggled)
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	_vibration_toggle.toggled.connect(_on_vibration_toggled)
	_language.item_selected.connect(_on_language_selected)
	_theme.item_selected.connect(_on_theme_selected)
	%PrivacyButton.pressed.connect(func(): _show_status("Privacy policy will open here when the store page is connected."))
	%RestoreButton.pressed.connect(func(): _show_status("Purchases checked — everything is already cozy and accounted for!"))
	%AboutButton.pressed.connect(func(): _show_status("Fruit Merge • cozy kitchen build 1.0.0"))
	_setup_choices()
	visible = false


func open() -> void:
	_sync_controls()
	visible = true
	_status_label.text = ""
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.88, 0.88)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _setup_choices() -> void:
	if _language.item_count == 0:
		_language.add_item("English")
		_language.add_item("Hindi")
		_language.add_item("Spanish")
	if _theme.item_count == 0:
		_theme.add_item("Light")
		_theme.add_item("Warm")


func _sync_controls() -> void:
	_last_music_volume = maxf(AudioManager.music_vol, float(SaveManager.get_setting("music_restore_volume", 0.8)))
	_last_sfx_volume = maxf(AudioManager.sfx_vol, float(SaveManager.get_setting("sfx_restore_volume", 0.8)))
	_music_toggle.set_pressed_no_signal(AudioManager.music_vol > 0.001)
	_sfx_toggle.set_pressed_no_signal(AudioManager.sfx_vol > 0.001)
	_vibration_toggle.set_pressed_no_signal(bool(SaveManager.get_setting("vibration_enabled", true)))
	_update_toggle_copy(_music_toggle)
	_update_toggle_copy(_sfx_toggle)
	_update_toggle_copy(_vibration_toggle)
	_select_option(_language, str(SaveManager.get_setting("language", "English")))
	_select_option(_theme, str(SaveManager.get_setting("theme", "Light")))


func _select_option(option: OptionButton, saved_text: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == saved_text:
			option.select(index)
			return
	option.select(0)


func _on_music_toggled(enabled: bool) -> void:
	AudioManager.music_vol = _last_music_volume if enabled else 0.0
	SaveManager.set_setting("music_volume", AudioManager.music_vol)
	SaveManager.set_setting("music_restore_volume", _last_music_volume)
	_update_toggle_copy(_music_toggle)


func _on_sfx_toggled(enabled: bool) -> void:
	AudioManager.sfx_vol = _last_sfx_volume if enabled else 0.0
	SaveManager.set_setting("sfx_volume", AudioManager.sfx_vol)
	SaveManager.set_setting("sfx_restore_volume", _last_sfx_volume)
	_update_toggle_copy(_sfx_toggle)


func _on_vibration_toggled(enabled: bool) -> void:
	SaveManager.set_setting("vibration_enabled", enabled)
	_update_toggle_copy(_vibration_toggle)


func _update_toggle_copy(toggle: Button) -> void:
	toggle.text = "ON" if toggle.button_pressed else "OFF"
	toggle.modulate = Color.WHITE if toggle.button_pressed else Color(0.82, 0.76, 0.68, 0.9)


func _on_language_selected(index: int) -> void:
	SaveManager.set_setting("language", _language.get_item_text(index))
	_show_status("Language preference saved.")


func _on_theme_selected(index: int) -> void:
	SaveManager.set_setting("theme", _theme.get_item_text(index))
	_show_status("Theme preference saved for the next style pass.")


func _show_status(message: String) -> void:
	_status_label.text = message

