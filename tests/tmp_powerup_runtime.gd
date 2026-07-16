extends Node


func _enter_tree() -> void:
	GameManager.current_state = Enums.GameState.PLAYING
	EconomyManager.powerup_counts = {
		"powerup_level_up": 1,
		"powerup_shake_box": 1,
		"powerup_remove_smallest": 1,
	}


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var main := $Main

	var level_target := FruitDatabase.create_fruit(Enums.FruitTier.CHERRY)
	add_child(level_target)
	level_target.freeze = true
	level_target.global_position = Vector2(0, -420)
	await get_tree().physics_frame
	main.call("_on_powerup_requested", &"powerup_level_up")
	main.call("_try_level_up_at", level_target.global_position)
	await get_tree().create_timer(0.65).timeout
	if EconomyManager.get_powerup_count(&"powerup_level_up") != 0:
		push_error("Level Up did not consume one charge")
	var found_promoted := false
	for node in get_tree().get_nodes_in_group("fruits"):
		print("LEVEL_GROUP ", node.name, " tier=", node.data.tier, " merging=", node.is_merging)
		if node is Fruit and node.data.tier == Enums.FruitTier.BERRIES:
			found_promoted = true
	if not found_promoted:
		push_error("Level Up did not spawn the next-tier fruit scene")
	for node in get_tree().get_nodes_in_group("fruits"):
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().physics_frame

	var smallest := FruitDatabase.create_fruit(Enums.FruitTier.CHERRY)
	add_child(smallest)
	smallest.freeze = true
	smallest.global_position = Vector2(-120, -300)
	main.call("_on_powerup_requested", &"powerup_remove_smallest")
	await get_tree().create_timer(0.55).timeout
	if EconomyManager.get_powerup_count(&"powerup_remove_smallest") != 0:
		push_error("Remove Smallest did not consume one charge")
	print("REMOVE_INSTANCE valid=", is_instance_valid(smallest), " queued=", smallest.is_queued_for_deletion() if is_instance_valid(smallest) else true)
	if is_instance_valid(smallest):
		push_error("Remove Smallest did not remove the lowest-tier fruit")
	for node in get_tree().get_nodes_in_group("fruits"):
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().physics_frame

	var shake_target := FruitDatabase.create_fruit(Enums.FruitTier.STRAWBERRY)
	add_child(shake_target)
	shake_target.freeze = false
	shake_target.global_position = Vector2(100, -320)
	shake_target.linear_velocity = Vector2.ZERO
	await get_tree().physics_frame
	main.call("_on_powerup_requested", &"powerup_shake_box")
	await get_tree().create_timer(0.12).timeout
	if EconomyManager.get_powerup_count(&"powerup_shake_box") != 0:
		push_error("Shake Box did not consume one charge")
	if shake_target.linear_velocity.length() < 1.0:
		push_error("Shake Box did not mix the fruit bodies")

	print("POWERUP_RUNTIME_OK")
	get_tree().quit()
