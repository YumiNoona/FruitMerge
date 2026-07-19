extends Node

const DEBUG_POWERUP_COUNT := 1
const DEBUG_COIN_COUNT := 10_000
const DEBUG_TICKET_COUNT := 100
const ProjectValidatorScript = preload("res://Scripts/Debug/project_validator.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The project main scene handles navigation; Bootstrap only restores state.
	SaveManager.load_game()
	if OS.is_debug_build():
		EconomyManager.set_debug_powerups(DEBUG_POWERUP_COUNT)
		EconomyManager.set_debug_wallet(DEBUG_COIN_COUNT, DEBUG_TICKET_COUNT)
	AudioManager.music_vol = SaveManager.get_setting("music_volume", 0.8)
	AudioManager.sfx_vol = SaveManager.get_setting("sfx_volume", 0.8)
	if DisplayServer.get_name() != "headless":
		AudioManager.start_music_playlist()
	TranslationServer.set_locale(str(SaveManager.get_setting("locale", "en")))
	DisplayServer.screen_set_keep_on(true)
	if OS.is_debug_build():
		call_deferred("_validate_project")


func _validate_project() -> void:
	ProjectValidatorScript.validate_all()


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
			else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
