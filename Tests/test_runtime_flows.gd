extends RefCounted


static func run(tree: SceneTree) -> PackedStringArray:
	var failures: PackedStringArray = []
	var setup_scene := load("res://Scenes/UI/RunSetup/run_setup.tscn") as PackedScene
	if not setup_scene:
		return PackedStringArray(["Run Setup scene must load"])
	var setup := setup_scene.instantiate() as RunSetupPanel
	tree.root.add_child(setup)
	await tree.process_frame
	setup.call("_show_loadout")
	await tree.process_frame
	var selected: Array = setup.get("_selected_powerups")
	var start_button := setup.get("_start_button") as Button
	if selected.size() != 3 or not start_button or start_button.disabled:
		failures.append("Run Setup must open a valid three-power selection ready to play")
	selected.remove_at(0)
	setup.call("_refresh_loadout_state")
	if not start_button.disabled:
		failures.append("Run Setup must disable Play until exactly three power types are selected")
	setup.call("_show_mission_intro", 2)
	await tree.process_frame
	var found_inventory_copy := false
	for node in setup.find_children("*", "Label", true, false):
		if (node as Label).text.contains("Inventory will not be consumed"):
			found_inventory_copy = true
			break
	if not found_inventory_copy:
		failures.append("Mission briefing must explain that tutorial power does not consume inventory")
	setup.queue_free()
	await tree.process_frame

	var impact_root := Node2D.new()
	tree.root.add_child(impact_root)
	var falling := FruitDatabase.create_fruit(Enums.FruitTier.CHERRY)
	var receiver := FruitDatabase.create_fruit(Enums.FruitTier.BERRIES)
	impact_root.add_child(falling)
	impact_root.add_child(receiver)
	falling.global_position = Vector2(320, 260)
	receiver.global_position = Vector2(320, 380)
	falling.sleeping = false
	receiver.sleeping = false
	falling.linear_velocity = Vector2(0, 520)
	receiver.linear_velocity = Vector2.ZERO
	for _frame in 40:
		await tree.physics_frame
		if int(receiver.get("_last_impact_msec")) > -1000:
			break
	if int(receiver.get("_last_impact_msec")) <= -1000:
		failures.append("A dropped fruit must trigger the receiving fruit's spring impact response")
	impact_root.free()
	await tree.create_timer(0.2).timeout
	return failures
