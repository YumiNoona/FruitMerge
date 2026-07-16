extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The project main scene handles navigation; Bootstrap only restores state.
	SaveManager.load_game()
