extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The project main scene handles navigation; Bootstrap only restores state.
	SaveManager.load_game()
	AudioManager.music_vol = SaveManager.get_setting("music_volume", 0.8)
	AudioManager.sfx_vol = SaveManager.get_setting("sfx_volume", 0.8)
