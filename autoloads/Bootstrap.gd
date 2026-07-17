extends Node

const DEBUG_POWERUP_COUNT := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The project main scene handles navigation; Bootstrap only restores state.
	SaveManager.load_game()
	if OS.is_debug_build():
		EconomyManager.set_debug_powerups(DEBUG_POWERUP_COUNT)
	AudioManager.music_vol = SaveManager.get_setting("music_volume", 0.8)
	AudioManager.sfx_vol = SaveManager.get_setting("sfx_volume", 0.8)
