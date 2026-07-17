extends "res://Scripts/States/base_state.gd"

var _score: int = 0


func enter() -> void:
	_score = GameManager.score
	SaveManager.save_run_result(_score)
	EventBus.game_over.emit(_score)
