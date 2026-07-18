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
]
const RETIRED_UI_FONTS := ["Spenbeb Game.otf", "Atop.ttf", "Cloudy.otf"]


static func validate_all() -> PackedStringArray:
	var issues: PackedStringArray = []
	issues.append_array(_validate_fruits())
	issues.append_array(_validate_shop())
	issues.append_array(_validate_scenes())
	issues.append_array(_validate_ui_contracts())
	for issue in issues:
		push_error("PROJECT VALIDATION: %s" % issue)
	if issues.is_empty():
		print("Project validation passed: fruit chain, catalog, UI contracts, and core scenes are consistent.")
	return issues


static func _validate_fruits() -> PackedStringArray:
	var issues: PackedStringArray = []
	if FruitDatabase.get_tier_count() != Enums.FruitTier.size():
		issues.append("Fruit database count does not match FruitTier enum")
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
		instance.free()
	return issues


static func _validate_shop() -> PackedStringArray:
	var catalog: Resource = load("res://Data/ShopCatalog.tres")
	if not catalog:
		return PackedStringArray(["Shop catalog could not be loaded"])
	var issues: PackedStringArray = catalog.call("validate")
	var ids: Dictionary = {}
	for item in catalog.get("items"):
		if item: ids[item.id] = true
	for required in REQUIRED_POWERUPS:
		if not ids.has(required):
			issues.append("Missing required power-up item: %s" % required)
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
		var rig := gameplay.get_node_or_null("WorldOrigin/ContainerRig")
		if not world_origin:
			issues.append("Gameplay scene is missing its editor-aligned WorldOrigin")
		elif world_origin.position != Vector2(360, 1280):
			issues.append("WorldOrigin must align the 720x1280 gameplay world with the editor canvas")
		if not rig:
			issues.append("Gameplay scene is missing its movable ContainerRig")
		elif not rig.get_node_or_null("ContainerArt") or not rig.get_node_or_null("BoxContainer/Box"):
			issues.append("ContainerRig must own both the visible container and physical Box instance")
		gameplay.free()
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
	var daily_reward_source := FileAccess.get_file_as_string("res://Scripts/UI/DailyReward/daily_reward.gd")
	if daily_reward_source.contains("check.text") or daily_reward_source.contains("COLLECTED"):
		issues.append("Daily Reward claimed cards must use their subdued style instead of checkmark labels")
	var home_source := FileAccess.get_file_as_string("res://Scripts/UI/Home/home.gd")
	if home_source.contains("amount_label"):
		issues.append("Home wallet flyover must animate only the currency texture")
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
		if card and (card.custom_minimum_size.y < 320.0 or not card.clip_contents):
			issues.append("Shop cards must contain and clip their portrait layout")
		if card and card.find_child("OwnedBadge", true, false):
			issues.append("Removed Shop OwnedBadge returned; owned state belongs in the action label")
		if card and not card.find_child("CountLabel", true, false):
			issues.append("Shop cards must retain the stacked power-up count label")
		var description := card.find_child("DescriptionLabel", true, false) as Label if card else null
		if description and (description.get_theme_font_size("font_size") < 16 or description.get_theme_constant("outline_size") < 2):
			issues.append("Shop descriptions must retain their readable size and warm outline")
		if card:
			card.free()
	var shop_scene := load(SceneRouter.SHOP_SCENE) as PackedScene
	if shop_scene:
		var shop := shop_scene.instantiate()
		for node_name in ["HomeButton", "AchievementsButton", "PlayButton", "ShopButton", "SettingsButton"]:
			if not shop.find_child(node_name, true, false):
				issues.append("Shop dock is missing %s required by shop.gd" % node_name)
		var shop_scroll := shop.find_child("ShopScroll", true, false) as ScrollContainer
		if not shop_scroll or shop_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
			issues.append("Shop must remain touch-scrollable without a visible scrollbar")
		shop.free()
	var home_scene := load(SceneRouter.HOME_SCENE) as PackedScene
	if home_scene:
		var home := home_scene.instantiate()
		if not home.find_child("RewardsButton", true, false):
			issues.append("Home is missing RewardsButton required for Daily Reward access")
		home.free()
	return issues
