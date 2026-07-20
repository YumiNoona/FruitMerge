class_name ProjectValidator
extends RefCounted

const REQUIRED_POWERUPS := [
	&"powerup_level_up",
	&"powerup_shake_box",
	&"powerup_remove_smallest",
	&"powerup_grab_em",
	&"powerup_hammer",
	&"powerup_bomb",
]
const REQUIRED_PETS := [
	&"pet_strawberry_cat",
	&"pet_watermelon_pup",
	&"pet_peach_bunny",
	&"pet_pineapple_meow",
	&"pet_melon_bear",
	&"pet_banana_fox",
	&"pet_berry_hamster",
	&"pet_cherry_bird",
	&"pet_lemon_frog",
]
const UI_SCENE_PATHS := [
	"res://Scenes/UI/Shop/shop.tscn",
	"res://Scenes/UI/Settings/settings_menu.tscn",
	"res://Scenes/UI/MainMenu/main_menu.tscn",
	"res://Scenes/UI/DailyReward/daily_reward.tscn",
	"res://Scenes/UI/Home/home.tscn",
	"res://Scenes/UI/NoAds/no_ads_purchase.tscn",
	"res://Scenes/UI/HUD/hud.tscn",
	"res://Scenes/UI/Pause/pause_menu.tscn",
	"res://Scenes/UI/Components/shop_item_button.tscn",
	"res://Scenes/UI/Components/score_pop.tscn",
	"res://Scenes/UI/Components/currency_pill.tscn",
	"res://Scenes/UI/GameOver/game_over.tscn",
	"res://Scenes/UI/RunSetup/run_setup.tscn",
	"res://Scenes/UI/PowerupRefill/powerup_refill.tscn",
]
const RETIRED_UI_FONTS := ["Spenbeb Game.otf", "Atop.ttf", "Cloudy.otf"]


static func validate_all() -> PackedStringArray:
	var issues: PackedStringArray = []
	issues.append_array(_validate_display_profile())
	issues.append_array(_validate_fruits())
	issues.append_array(_validate_shop())
	issues.append_array(_validate_modes_and_missions())
	issues.append_array(_validate_scenes())
	issues.append_array(_validate_ui_contracts())
	for issue in issues:
		push_error("PROJECT VALIDATION: %s" % issue)
	if issues.is_empty():
		print("Project validation passed: fruit chain, pet abilities, catalog, UI contracts, and core scenes are consistent.")
	return issues


static func _validate_modes_and_missions() -> PackedStringArray:
	var issues: PackedStringArray = []
	if Enums.GameMode.keys() != ["CLASSIC", "MISSIONS", "TIME_ATTACK"]:
		issues.append("GameMode must expose exactly Classic, Missions, and Time Attack")
	var mode_paths := [
		"res://Data/Modes/classic.tres",
		"res://Data/Modes/missions.tres",
		"res://Data/Modes/time_attack.tres",
	]
	var seen_modes: Dictionary = {}
	for path in mode_paths:
		var mode := load(path) as GameModeDefinition
		if not mode or not mode.is_valid_definition():
			issues.append("Invalid mode definition: %s" % path)
			continue
		seen_modes[mode.mode] = true
	if seen_modes.size() != 3:
		issues.append("The mode catalog must define each of the three modes once")
	var taught_powerups: Array[StringName] = []
	if MissionManager.definitions.size() != 7:
		issues.append("Mission campaign must contain exactly seven levels")
	for expected_level in range(1, 8):
		var mission := MissionManager.get_definition(expected_level)
		if not mission or not mission.is_valid_definition():
			issues.append("Mission %d is missing or invalid" % expected_level)
			continue
		if expected_level == 1 and not mission.required_powerup.is_empty():
			issues.append("Mission 1 must teach merging without a power-up")
		if expected_level > 1:
			if mission.required_powerup.is_empty() or mission.temporary_charges != 1:
				issues.append("Mission %d must pin one free tutorial power charge" % expected_level)
			elif mission.required_powerup not in taught_powerups:
				taught_powerups.append(mission.required_powerup)
	if taught_powerups.size() != PowerLoadoutManager.ALL_POWERUPS.size():
		issues.append("Missions 2-7 must teach all six power-up types exactly once")
	if GameManager.TIME_ATTACK_CONFIG.duration_seconds <= 0.0:
		issues.append("Time Attack must use a positive resource-configured duration")
	return issues


static func _validate_display_profile() -> PackedStringArray:
	var issues: PackedStringArray = []
	var logical_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	)
	var preview_size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0))
	)
	if logical_size != Vector2i(720, 1600):
		issues.append("Logical UI viewport must remain 720x1600")
	if preview_size != Vector2i(432, 960):
		issues.append("Desktop mobile preview must remain 432x960 (9:20)")
	if str(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "expand":
		issues.append("Mobile layout requires canvas stretch aspect expand")
	if bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)):
		issues.append("The branded game intro must not show Godot's default boot splash")
	var export_source := FileAccess.get_file_as_string("res://export_presets.cfg")
	if not export_source.contains("splash_screen/disable_godot_boot_splash=true"):
		issues.append("Android export must disable the Godot boot splash")
	return issues


static func _validate_fruits() -> PackedStringArray:
	var issues: PackedStringArray = []
	var fruit_material := load("res://Data/Resources/fruit_physics.tres") as PhysicsMaterial
	if not fruit_material or fruit_material.bounce < 0.16 or fruit_material.bounce > 0.25:
		issues.append("Fruit physics material must keep a soft 0.16-0.25 rebound")
	elif fruit_material.friction < 0.28 or fruit_material.friction > 0.40:
		issues.append("Fruit physics material friction must allow gentle rolling without sliding")
	if FruitDatabase.get_tier_count() != Enums.FruitTier.size():
		issues.append("Fruit database count does not match FruitTier enum")
	if Enums.FruitTier.size() != 13:
		issues.append("The Mango-free fruit chain must contain exactly 13 tiers")
	if FruitDatabase.get_next_fruit(Enums.FruitTier.PEACH) != FruitDatabase.get_fruit(Enums.FruitTier.COCONUT):
		issues.append("Peach must merge directly into Coconut")
	for tier in Enums.FruitTier.size():
		var data := FruitDatabase.get_fruit(tier)
		var scene := FruitDatabase.get_fruit_scene(tier)
		if not data:
			issues.append("Missing FruitData for tier %d" % tier)
			continue
		if not scene:
			issues.append("Missing fruit scene for tier %d" % tier)
			continue
		if data.tier != tier:
			issues.append("Fruit tier/order mismatch for %s" % data.display_name)
		if data.guide_color == Color.WHITE or data.guide_color.a < 0.95:
			issues.append("%s needs an opaque, non-white guide color" % data.display_name)
		if tier < Enums.FruitTier.WATERMELON and data.next_tier != tier + 1:
			issues.append("Broken next tier for %s" % data.display_name)
		if tier == Enums.FruitTier.WATERMELON and data.next_tier != -1:
			issues.append("Final fruit must not have a next tier")
		var instance := scene.instantiate() as Fruit
		if not instance:
			issues.append("Tier %d scene root is not Fruit" % tier)
			continue
		if not instance.get_node_or_null("Sprite2D") or not instance.get_node_or_null("CollisionShape2D"):
			issues.append("%s scene is missing its scene-owned visual/collision" % data.display_name)
		if instance.impact_min_speed >= instance.impact_full_speed \
			or instance.impact_visual_strength <= 0.0 \
			or instance.impact_side_velocity <= 0.0:
			issues.append("%s has invalid impact-feel tuning" % data.display_name)
		instance.free()
	return issues


static func _validate_shop() -> PackedStringArray:
	var catalog: Resource = load("res://Data/ShopCatalog.tres")
	if not catalog:
		return PackedStringArray(["Shop catalog could not be loaded"])
	var issues: PackedStringArray = catalog.call("validate")
	var ids: Dictionary = {}
	for item in catalog.get("items"):
		if item:
			ids[item.id] = true
			if item.category == &"powerup" and item.refill_ticket_cost <= 0:
				issues.append("Power-up needs a positive in-game ticket refill price: %s" % item.id)
	for required in REQUIRED_POWERUPS:
		if not ids.has(required):
			issues.append("Missing required power-up item: %s" % required)
	for required in REQUIRED_PETS:
		if not ids.has(required):
			issues.append("Missing required pet item: %s" % required)
	var abilities := PetAbilityCatalog.get_all()
	if abilities.size() != REQUIRED_PETS.size():
		issues.append("Every shop pet must have one PetAbilityData resource")
	var seen_effects: Dictionary = {}
	for ability in abilities:
		if not ability.is_valid_definition():
			issues.append("Invalid pet ability definition for %s" % ability.pet_id)
		elif ability.pet_id not in REQUIRED_PETS:
			issues.append("Pet ability references an unknown shop pet: %s" % ability.pet_id)
		if seen_effects.has(ability.effect):
			issues.append("Pet abilities must keep distinct effects: %s" % ability.ability_name)
		seen_effects[ability.effect] = true
	return issues


static func _validate_scenes() -> PackedStringArray:
	var issues: PackedStringArray = []
	for path in [SceneRouter.HOME_SCENE, SceneRouter.GAME_SCENE, SceneRouter.SHOP_SCENE, SceneRouter.DAILY_REWARD_SCENE]:
		if not ResourceLoader.exists(path):
			issues.append("Missing core scene: %s" % path)
	var gameplay_scene := load(SceneRouter.GAME_SCENE) as PackedScene
	if gameplay_scene:
		var gameplay := gameplay_scene.instantiate()
		var world_origin := gameplay.get_node_or_null("WorldOrigin") as Node2D
		var camera := gameplay.get_node_or_null("WorldOrigin/Camera2D") as Camera2D
		var rig := gameplay.get_node_or_null("WorldOrigin/ContainerRig")
		if not world_origin:
			issues.append("Gameplay scene is missing its editor-aligned WorldOrigin")
		elif world_origin.position != Vector2(360, 1440):
			issues.append("WorldOrigin must align the 720x1600 gameplay world with the editor canvas")
		elif not camera or world_origin.position + camera.position != Vector2(360, 800):
			issues.append("Gameplay camera must center the 720x1600 editor canvas at (360, 800)")
		if not rig:
			issues.append("Gameplay scene is missing its movable ContainerRig")
		elif not rig.get_node_or_null("ContainerArt") or not rig.get_node_or_null("BoxContainer/Box"):
			issues.append("ContainerRig must own both the visible container and physical Box instance")
		elif not rig is ContainerRig:
			issues.append("ContainerRig must use the synchronized container sizing script")
		elif not is_equal_approx((rig as ContainerRig).scale.x, 1.0) \
				or not is_equal_approx((rig as ContainerRig).scale.y, 1.0):
			issues.append("ContainerRig Node2D scale must remain (1, 1); use its size multiplier")
		elif (rig as ContainerRig).container_width_multiplier < 0.85 \
				or (rig as ContainerRig).container_width_multiplier > 1.20 \
				or (rig as ContainerRig).container_height_multiplier < 0.85 \
				or (rig as ContainerRig).container_height_multiplier > 1.15:
			issues.append("ContainerRig width/height multipliers are outside their supported mobile range")
		if not gameplay.get_node_or_null("PetAbilityController"):
			issues.append("Gameplay scene is missing its modular PetAbilityController")
		gameplay.free()
	var pet_scene := load("res://Scenes/Entities/Pet/pet.tscn") as PackedScene
	if pet_scene:
		var pet := pet_scene.instantiate()
		if not pet.get_node_or_null("TouchArea/CollisionShape2D") or not pet.get_node_or_null("AbilityLabel"):
			issues.append("Pet scene must retain its mobile touch target and ability callout")
		pet.free()
	return issues


static func _validate_ui_contracts() -> PackedStringArray:
	var issues: PackedStringArray = []
	for scene_path in UI_SCENE_PATHS:
		var source := FileAccess.get_file_as_string(scene_path)
		for retired_font in RETIRED_UI_FONTS:
			if source.contains(retired_font):
				issues.append("%s still uses retired UI font %s" % [scene_path, retired_font])
	var theme_source := FileAccess.get_file_as_string("res://Data/Themes/cozy_theme.tres")
	if not theme_source.contains("NERILLKID Trial.ttf") or not theme_source.contains("TooltipPanel/styles/panel"):
		issues.append("Cozy theme must use NERILLKID and the styled tooltip panel")
	var hud_scene_source := FileAccess.get_file_as_string("res://Scenes/UI/HUD/hud.tscn")
	var hud_script_source := FileAccess.get_file_as_string("res://Scripts/UI/HUD/hud.gd")
	var hud_scene := load("res://Scenes/UI/HUD/hud.tscn") as PackedScene
	if hud_scene:
		var hud := hud_scene.instantiate() as Control
		var top_row := hud.get_node_or_null("TopRow") as Control if hud else null
		if not hud or hud.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				or not top_row or top_row.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			issues.append("HUD and its full-screen TopRow must ignore empty-space pointer input")
		if hud:
			hud.free()
	if hud_scene_source.contains("ModeLabel") or hud_script_source.contains("ModeLabel"):
		issues.append("Removed HUD ModeLabel returned; Time Attack belongs in ScoreCaption")
	if hud_scene_source.contains("PowerupTray") or hud_script_source.contains("PowerupTray"):
		issues.append("Removed PowerupTray returned; PowerupColumn is the runtime loadout root")
	if not hud_scene_source.contains("SecondNextFruitIcon"):
		issues.append("HUD is missing Banana Fox's optional second-fruit preview")
	var refill_scene := load("res://Scenes/UI/PowerupRefill/powerup_refill.tscn") as PackedScene
	if refill_scene:
		var refill := refill_scene.instantiate() as Control
		for node_name in ["PowerIcon", "WatchAdButton", "TicketButton", "TicketBalance", "Status", "CloseButton"]:
			if not refill.find_child(node_name, true, false):
				issues.append("In-game power refill is missing %s" % node_name)
		if refill.process_mode != Node.PROCESS_MODE_ALWAYS:
			issues.append("In-game power refill must process while gameplay is paused")
		refill.free()
	var ad_source := FileAccess.get_file_as_string("res://Autoloads/AdManager.gd")
	if not ad_source.contains("request_rewarded_powerup") \
			or not ad_source.contains("complete_rewarded_powerup") \
			or not ad_source.contains("rewarded_powerup_completed"):
		issues.append("AdManager must expose verified direct power-up rewards")
	var daily_reward_source := FileAccess.get_file_as_string("res://Scripts/UI/DailyReward/daily_reward.gd")
	if daily_reward_source.contains("check.text") or daily_reward_source.contains("COLLECTED"):
		issues.append("Daily Reward claimed cards must use their subdued style instead of checkmark labels")
	var home_source := FileAccess.get_file_as_string("res://Scripts/UI/Home/home.gd")
	if home_source.contains("amount_label"):
		issues.append("Home wallet flyover must animate only the currency texture")
	for wallet_script in [
		"res://Scripts/UI/Home/home.gd",
		"res://Scripts/UI/HUD/hud.gd",
		"res://Scripts/UI/Shop/shop.gd",
		"res://Scripts/UI/Components/currency_pill.gd",
	]:
		if not FileAccess.get_file_as_string(wallet_script).contains("CurrencyFormatterScript.format_amount"):
			issues.append("Wallet display must use compact K/M formatting: %s" % wallet_script)
	var settings_scene := load("res://Scenes/UI/Settings/settings_menu.tscn") as PackedScene
	if settings_scene:
		var settings := settings_scene.instantiate()
		if not settings.get_node_or_null("PanelRoot/Content/MusicRow/MusicSlider"):
			issues.append("Settings is missing the music volume slider")
		if not settings.get_node_or_null("PanelRoot/Content/SfxRow/SfxSlider"):
			issues.append("Settings is missing the SFX volume slider")
		if settings.find_child("ThemeOption", true, false) or settings.find_child("FeedbackOption", true, false):
			issues.append("Removed Theme/Game Feel options returned to Settings")
		if settings.find_child("LanguageOption", true, false) or settings.find_child("LanguageRow", true, false):
			issues.append("Removed Language selector returned to Settings")
		settings.free()
	var card_scene := load("res://Scenes/UI/Components/shop_item_button.tscn") as PackedScene
	if card_scene:
		var card := card_scene.instantiate() as Control
		if card and (card.custom_minimum_size.x < 220.0 or card.custom_minimum_size.y < 330.0 or not card.clip_contents):
			issues.append("Shop cards must contain and clip their portrait layout")
		if card and card.find_child("OwnedBadge", true, false):
			issues.append("Removed Shop OwnedBadge returned; owned state belongs in the action label")
		if card and not card.find_child("CountLabel", true, false):
			issues.append("Shop cards must retain the stacked power-up count label")
		var description := card.find_child("DescriptionLabel", true, false) as Label if card else null
		if description and (description.get_theme_font_size("font_size") < 16 or description.get_theme_constant("outline_size") < 2):
			issues.append("Shop descriptions must retain their readable size and warm outline")
		if card and card.mouse_filter != Control.MOUSE_FILTER_PASS:
			issues.append("Shop cards must pass drag gestures to the catalog ScrollContainer")
		if card:
			card.free()
	var shop_scene := load(SceneRouter.SHOP_SCENE) as PackedScene
	if shop_scene:
		var shop := shop_scene.instantiate()
		for node_name in [
			"FrameArt", "ShopTitle", "CatalogMargin", "ShopScroll", "ShopList",
			"TabPets", "TabPowerups", "TabSkins", "TabThemes", "CloseButton",
			"NoAdsButton", "ShopCoinsLabel", "ShopTicketsLabel",
		]:
			if not shop.find_child(node_name, true, false):
				issues.append("Store is missing %s required by its rebuilt layout" % node_name)
		var shop_scroll := shop.find_child("ShopScroll", true, false) as ScrollContainer
		if not shop_scroll or shop_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
			issues.append("Shop must remain touch-scrollable without a visible scrollbar")
		elif shop_scroll.scroll_deadzone != 8:
			issues.append("Shop touch scrolling must retain its 8 px drag deadzone")
		var shop_list := shop.find_child("ShopList", true, false) as GridContainer
		if not shop_list or shop_list.mouse_filter != Control.MOUSE_FILTER_PASS:
			issues.append("Shop grid must pass card drag gestures to its ScrollContainer")
		elif shop_list.columns != 2:
			issues.append("Store catalog must use the mobile-friendly two-column grid")
		var category_row := shop.get_node_or_null("HBoxContainer") as HBoxContainer
		if not category_row or not is_equal_approx(category_row.anchor_top, 1.0) \
				or not is_equal_approx(category_row.anchor_bottom, 1.0):
			issues.append("Store category row must stay bottom-anchored")
		var catalog_margin := shop.get_node_or_null("CatalogMargin") as MarginContainer
		if not catalog_margin or not catalog_margin.clip_contents:
			issues.append("Store catalog margin must clip scrolling cards to the frame")
		shop.free()
	var shop_source := FileAccess.get_file_as_string(SceneRouter.SHOP_SCENE)
	for asset_path in [
		"res://Assets/UI/BackGround.png", "res://Assets/UI/StoreFrame.png",
		"res://Assets/UI/Pets.png",
		"res://Assets/UI/Power-Ups.png", "res://Assets/UI/Skins.png",
		"res://Assets/Menu/Themes.png", "res://Assets/Menu/Close.png",
		"res://Assets/Menu/NoAds.png", "res://Assets/Menu/Coin.png",
		"res://Assets/UI/Ticket.png",
	]:
		if not shop_source.contains(asset_path):
			issues.append("Store presentation is missing surviving UI art: %s" % asset_path)
	var game_over_scene := load("res://Scenes/UI/GameOver/game_over.tscn") as PackedScene
	if game_over_scene:
		var game_over := game_over_scene.instantiate()
		for node_name in [
			"SnapshotFrame", "FinalSnapshot", "SnapshotFlash", "MenuButton",
			"RestartButton", "SettingsButton", "SettingsMenu",
		]:
			if not game_over.find_child(node_name, true, false):
				issues.append("Game Over final-frame layout is missing %s" % node_name)
		for button_name in ["MenuButton", "RestartButton", "SettingsButton"]:
			var icon_button := game_over.find_child(button_name, true, false) as TextureButton
			if icon_button and not icon_button.texture_normal:
				issues.append("Game Over %s must use the new icon artwork" % button_name)
		game_over.free()
	var game_over_source := FileAccess.get_file_as_string("res://Scripts/UI/GameOver/game_over.gd")
	if not game_over_source.contains("RenderingServer.frame_post_draw") \
			or not game_over_source.contains("get_viewport().get_texture()") \
			or not game_over_source.contains("ImageTexture.create_from_image"):
		issues.append("Game Over must capture the unobstructed final gameplay frame dynamically")
	if FileAccess.get_file_as_string("res://Scripts/Core/main.gd").contains("visible = state == Enums.GameState.GAME_OVER"):
		issues.append("Main must not reveal Game Over before its final-frame capture completes")
	var home_scene := load(SceneRouter.HOME_SCENE) as PackedScene
	if home_scene:
		var home := home_scene.instantiate()
		for node_name in ["RewardsButton", "ThemesButton", "MissionButton"]:
			if not home.find_child(node_name, true, false):
				issues.append("Home is missing %s required by its shortcut hub" % node_name)
		for node_name in ["Dock", "HomeButton", "AchievementsButton", "PlayButton", "ModeButton", "ShopButton", "SettingsButton"]:
			var bottom_control := home.find_child(node_name, true, false) as Control
			if not bottom_control or not is_equal_approx(bottom_control.anchor_top, 1.0) or not is_equal_approx(bottom_control.anchor_bottom, 1.0):
				issues.append("Home %s must stay bottom-anchored on tall phones" % node_name)
		var mascot := home.find_child("Mascot", true, false) as Control
		if not mascot or not is_equal_approx(mascot.anchor_top, 0.5) or not is_equal_approx(mascot.anchor_bottom, 0.5):
			issues.append("Home mascot must remain vertically centered on tall phones")
		home.free()
	var main_menu_scene := load("res://Scenes/UI/MainMenu/main_menu.tscn") as PackedScene
	if main_menu_scene:
		var main_menu := main_menu_scene.instantiate()
		for node_name in ["TipPanel", "Footer"]:
			var bottom_control := main_menu.find_child(node_name, true, false) as Control
			if not bottom_control or not is_equal_approx(bottom_control.anchor_top, 1.0) or not is_equal_approx(bottom_control.anchor_bottom, 1.0):
				issues.append("Main menu %s must stay bottom-anchored on tall phones" % node_name)
		main_menu.free()
	return issues
