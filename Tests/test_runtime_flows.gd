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
	var fruit_container := gameplay.find_child("FruitContainer", true, false)
	if gameplay_spawner and fruit_container:
		var fruit_count_before := fruit_container.get_child_count()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = Vector2(360, 300)
		press.pressed = true
		tree.root.push_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = press.position
		release.pressed = false
		tree.root.push_input(release)
		await tree.physics_frame
		await tree.process_frame
		if fruit_container.get_child_count() <= fruit_count_before:
			failures.append("An empty-space left click must pass through the HUD and drop a fruit")
	var gameplay_hud := gameplay.find_child("HUD", true, false) as Control
	var refill_panel := gameplay.find_child("PowerupRefillPanel", true, false) as Control
	if not gameplay_hud or not refill_panel or PowerLoadoutManager.active_loadout.is_empty():
		failures.append("Gameplay HUD must include the in-game power-up refill panel")
	else:
		var refill_id := PowerLoadoutManager.active_loadout[0]
		var refill_item := PowerLoadoutManager.get_item_data(refill_id)
		var previous_power_count := EconomyManager.get_powerup_count(refill_id)
		var previous_tickets := EconomyManager.tickets
		EconomyManager.powerup_counts[refill_id] = 0
		EconomyManager.tickets = refill_item.refill_ticket_cost
		EventBus.powerup_count_changed.emit(refill_id, 0)
		EventBus.tickets_changed.emit(EconomyManager.tickets)
		gameplay_hud.call("_request_powerup", refill_id)
		if not refill_panel.visible or GameManager.current_state != Enums.GameState.PAUSED:
			failures.append("Tapping an empty selected power must pause and open its refill choices")
		else:
			refill_panel.call("_on_ticket_pressed")
			await tree.process_frame
			if refill_panel.visible or GameManager.current_state != Enums.GameState.PLAYING \
					or EconomyManager.get_powerup_count(refill_id) != 1 \
					or EconomyManager.tickets != 0:
				failures.append("Ticket refill must grant one power, charge its configured price, and resume play")
		EconomyManager.powerup_counts[refill_id] = previous_power_count
		EconomyManager.tickets = previous_tickets
		EventBus.powerup_count_changed.emit(refill_id, previous_power_count)
		EventBus.tickets_changed.emit(previous_tickets)
		SaveManager.save_game()
	var game_over_panel := gameplay.find_child("GameOverPanel", true, false) as Control
	var final_snapshot := gameplay.find_child("FinalSnapshot", true, false) as TextureRect
	if not game_over_panel or not final_snapshot:
		failures.append("Game Over must retain its dynamic final-pile snapshot target")
	else:
		game_over_panel.call("_on_game_over", 321)
		await tree.process_frame
		var result_score := game_over_panel.find_child("NewHighLabel", true, false) as Label
		if not game_over_panel.visible or not result_score or not result_score.text.contains("321"):
			failures.append("Headless Game Over must reveal its fallback result without waiting for a render frame")
	gameplay.free()
	await tree.process_frame
	SaveManager.set_setting("equipped_pet", previous_pet, false)
	GameManager.current_mode = previous_mode
	GameManager.current_state = previous_state
	GameManager.show_second_next_preview = false
	GameManager.combo_window_bonus = 0.0

	var shop_scene := load(SceneRouter.SHOP_SCENE) as PackedScene
	var shop := shop_scene.instantiate() if shop_scene else null
	if not shop:
		failures.append("Rebuilt Store scene must instantiate")
	else:
		tree.root.add_child(shop)
		await tree.process_frame
		await tree.process_frame
		var shop_list := shop.find_child("ShopList", true, false) as GridContainer
		if not shop_list or shop_list.get_child_count() != ProjectValidator.REQUIRED_PETS.size():
			failures.append("Rebuilt Store must complete _ready and populate its default pet catalog")
		shop.call("_filter_category", &"powerup")
		if not shop_list or shop_list.get_child_count() != ProjectValidator.REQUIRED_POWERUPS.size():
			failures.append("Rebuilt Store bottom tabs must repopulate the selected catalog")
		shop.free()
		await tree.process_frame
	GameManager.current_state = previous_state
	tree.paused = false

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
