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

	var previous_pet := EconomyManager.get_equipped_item(&"pet")
	var previous_mode := GameManager.current_mode
	var previous_state := GameManager.current_state
	SaveManager.set_setting("equipped_pet", &"pet_banana_fox", false)
	GameManager.current_mode = Enums.GameMode.CLASSIC
	GameManager.current_state = Enums.GameState.PLAYING
	var gameplay_scene := load("res://Scenes/Core/main.tscn") as PackedScene
	var gameplay := gameplay_scene.instantiate()
	tree.root.add_child(gameplay)
	await tree.process_frame
	await tree.process_frame
	var pet := gameplay.find_child("Pet", true, false) as Pet
	var pet_controller := gameplay.find_child("PetAbilityController", true, false) as PetAbilityController
	var second_preview := gameplay.find_child("SecondNextFruitIcon", true, false) as TextureRect
	var container_rig := gameplay.find_child("ContainerRig", true, false) as ContainerRig
	var gameplay_box := gameplay.find_child("Box", true, false) as Box
	var gameplay_spawner := gameplay.find_child("Spawner", true, false) as Spawner
	var container_art := gameplay.find_child("ContainerArt", true, false) as Sprite2D
	if not pet or not pet_controller or not pet_controller.ability:
		failures.append("An equipped shop pet must spawn with its modular ability controller")
	elif pet_controller.ability.pet_id != &"pet_banana_fox":
		failures.append("PetAbilityController must load the equipped pet's matching resource")
	if not GameManager.show_second_next_preview or not second_preview or not second_preview.visible:
		failures.append("Banana Fox Future Sight must reveal the second upcoming-fruit icon")
	var pet_touch_shape := pet.get_node_or_null("TouchArea/CollisionShape2D") as CollisionShape2D if pet else null
	if not pet_touch_shape or not pet_touch_shape.shape is CircleShape2D \
		or (pet_touch_shape.shape as CircleShape2D).radius < 60.0:
		failures.append("The in-world pet must retain a generous mobile touch target")
	if not container_rig or not gameplay_box or not gameplay_spawner or not container_art:
		failures.append("Gameplay must instantiate the synchronized container layout")
	elif not is_equal_approx(gameplay_box.container_half_width, 278.88) \
			or not is_equal_approx(gameplay_spawner.max_x_spread, 267.88) \
			or not is_equal_approx(container_art.scale.x, 0.67536) \
			or not is_equal_approx(container_art.scale.y, 0.603):
		failures.append("Container width must resize art, collisions, and drop bounds together")
	gameplay.free()
	await tree.process_frame
	SaveManager.set_setting("equipped_pet", previous_pet, false)
	GameManager.current_mode = previous_mode
	GameManager.current_state = previous_state
	GameManager.show_second_next_preview = false
	GameManager.combo_window_bonus = 0.0

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
