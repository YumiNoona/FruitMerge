class_name SettingsMenu
extends Control

signal closed

@onready var _panel: Control = %PanelRoot
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _vibration_toggle: Button = %VibrationToggle
@onready var _language: OptionButton = %LanguageOption
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(close)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	_vibration_toggle.toggled.connect(_on_vibration_toggled)
	_language.item_selected.connect(_on_language_selected)
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


func _sync_controls() -> void:
	_music_slider.set_value_no_signal(AudioManager.music_vol)
	_sfx_slider.set_value_no_signal(AudioManager.sfx_vol)
	_vibration_toggle.set_pressed_no_signal(bool(SaveManager.get_setting("vibration_enabled", true)))
	_update_volume_copy(_music_value_label, AudioManager.music_vol)
	_update_volume_copy(_sfx_value_label, AudioManager.sfx_vol)
	_update_toggle_copy(_vibration_toggle)
	var locale_names := {"en": "English", "hi": "Hindi", "es": "Spanish"}
	_select_option(_language, locale_names.get(str(SaveManager.get_setting("locale", "en")), "English"))


func _select_option(option: OptionButton, saved_text: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == saved_text:
			option.select(index)
			return
	option.select(0)


func _on_music_volume_changed(value: float) -> void:
	AudioManager.music_vol = value
	SaveManager.set_setting("music_volume", value)
	_update_volume_copy(_music_value_label, value)


func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.sfx_vol = value
	SaveManager.set_setting("sfx_volume", value)
	_update_volume_copy(_sfx_value_label, value)


func _on_vibration_toggled(enabled: bool) -> void:
	SaveManager.set_setting("vibration_enabled", enabled)
	_update_toggle_copy(_vibration_toggle)


func _update_toggle_copy(toggle: Button) -> void:
	toggle.text = "ON" if toggle.button_pressed else "OFF"
	toggle.modulate = Color.WHITE if toggle.button_pressed else Color(0.82, 0.76, 0.68, 0.9)


func _update_volume_copy(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(clampf(value, 0.0, 1.0) * 100.0)


func _on_language_selected(index: int) -> void:
	var locales := ["en", "hi", "es"]
	var locale: String = locales[clampi(index, 0, locales.size() - 1)]
	TranslationServer.set_locale(locale)
	SaveManager.set_setting("locale", locale)
	_show_status("Language applied. Some new content may still use English.")


func _show_status(message: String) -> void:
	_status_label.text = message
