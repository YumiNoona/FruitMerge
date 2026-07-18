extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var failures: PackedStringArray = []
	failures.append_array(load("res://Tests/test_game_rules.gd").run())
	failures.append_array(load("res://Tests/test_project_content.gd").run())
	for failure in failures:
		push_error("TEST FAILED: %s" % failure)
	quit(0 if failures.is_empty() else 1)
