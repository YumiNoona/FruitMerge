extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# All autoloads have initialized by now (Bootstrap is last).
	# Explicitly load save data into GameManager/EconomyManager.
	SaveManager.load_game()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
