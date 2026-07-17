class_name PauseMenu
extends Control

signal closed

@onready var _panel: Control = %PanelRoot
@onready var _settings_menu = %SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%CloseButton.pressed.connect(close)
	%ContinueButton.pressed.connect(close)
	%RestartButton.pressed.connect(_restart_game)
	%HomeButton.pressed.connect(_go_home)
	%SettingsButton.pressed.connect(_open_settings)
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


func _restart_game() -> void:
	visible = false
	GameManager.start_new_run()


func _go_home() -> void:
	visible = false
	GameManager.change_state(Enums.GameState.MENU)
	get_tree().change_scene_to_file("res://Scenes/UI/Home/home.tscn")


func _open_settings() -> void:
	_settings_menu.open()

