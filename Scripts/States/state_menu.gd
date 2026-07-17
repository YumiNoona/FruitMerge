extends "res://Scripts/States/base_state.gd"


func enter() -> void:
	EventBus.state_changed.connect(_on_state_changed, CONNECT_ONE_SHOT)


func _on_state_changed(state: Enums.GameState) -> void:
	if state != Enums.GameState.MENU:
		get_tree().change_scene_to_file("res://Scenes/UI/Home/home.tscn")
