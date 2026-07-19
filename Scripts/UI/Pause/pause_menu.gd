class_name PauseMenu
extends Control

signal closed

@onready var _panel: Control = %PanelRoot
@onready var _settings_menu: SettingsMenu = %SettingsMenu
@onready var _continue_button: TextureButton = $ActionRow/ContinueButton
@onready var _restart_button: TextureButton = $ActionRow/RestartButton
@onready var _menu_button: TextureButton = %MenuButton
@onready var _music_button: TextureButton = %MusicButton
@onready var _sfx_button: TextureButton = %SfxButton
@onready var _vibrate_button: TextureButton = %VibrateButton

var _music_restore_volume := 0.8
var _sfx_restore_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(close)
	_continue_button.pressed.connect(close)
	_restart_button.pressed.connect(_restart_game)
	_menu_button.pressed.connect(_go_home)
	_music_button.pressed.connect(_toggle_music)
	_sfx_button.pressed.connect(_toggle_sfx)
	_vibrate_button.pressed.connect(_toggle_vibration)
	if AudioManager.music_vol > 0.01:
		_music_restore_volume = AudioManager.music_vol
	if AudioManager.sfx_vol > 0.01:
		_sfx_restore_volume = AudioManager.sfx_vol
	_refresh_quick_controls()
	visible = false


func open() -> void:
	if GameManager.current_state != Enums.GameState.PLAYING:
		return
	visible = true
	GameManager.change_state(Enums.GameState.PAUSED)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.84, 0.84)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28)


func close() -> void:
	if not visible:
		return
	if _settings_menu.visible:
		_settings_menu.close()
	visible = false
	if GameManager.current_state == Enums.GameState.PAUSED:
		GameManager.change_state(Enums.GameState.PLAYING)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _settings_menu.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _toggle_music() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if AudioManager.music_vol > 0.01:
		_music_restore_volume = AudioManager.music_vol
		AudioManager.music_vol = 0.0
	else:
		AudioManager.music_vol = maxf(_music_restore_volume, 0.05)
	SaveManager.set_setting("music_volume", AudioManager.music_vol)
	_refresh_quick_controls()


func _toggle_sfx() -> void:
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if AudioManager.sfx_vol > 0.01:
		_sfx_restore_volume = AudioManager.sfx_vol
		AudioManager.sfx_vol = 0.0
	else:
		AudioManager.sfx_vol = maxf(_sfx_restore_volume, 0.05)
	SaveManager.set_setting("sfx_volume", AudioManager.sfx_vol)
	_refresh_quick_controls()


func _toggle_vibration() -> void:
	var enabled := not bool(SaveManager.get_setting("vibration_enabled", true))
	SaveManager.set_setting("vibration_enabled", enabled)
	if enabled:
		HapticManager.pulse(HapticManager.Feedback.TAP)
	_refresh_quick_controls()


func _refresh_quick_controls() -> void:
	_update_quick_control(_music_button, "Music", AudioManager.music_vol > 0.01)
	_update_quick_control(_sfx_button, "Sound effects", AudioManager.sfx_vol > 0.01)
	_update_quick_control(_vibrate_button, "Vibration", bool(SaveManager.get_setting("vibration_enabled", true)))


func _update_quick_control(button: TextureButton, label: String, enabled: bool) -> void:
	button.modulate = Color.WHITE if enabled else Color(0.48, 0.58, 0.66, 0.68)
	button.tooltip_text = "%s: %s" % [label, "ON" if enabled else "OFF"]


func _restart_game() -> void:
	visible = false
	if GameManager.current_mode == Enums.GameMode.MISSIONS:
		MissionManager.restart_active_mission()
	else:
		PowerLoadoutManager.prepare_standard_run()
		GameManager.start_new_run()


func _go_home() -> void:
	visible = false
	GameManager.change_state(Enums.GameState.MENU)
	SceneRouter.go_home()
