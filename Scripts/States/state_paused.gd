extends "res://Scripts/States/base_state.gd"


func enter() -> void:
	get_tree().paused = true


func exit() -> void:
	get_tree().paused = false
