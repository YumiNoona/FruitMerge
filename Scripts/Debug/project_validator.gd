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
	return issues


static func _validate_ui_contracts() -> PackedStringArray:
	var issues: PackedStringArray = []
	var settings_scene := load("res://Scenes/UI/Settings/settings_menu.tscn") as PackedScene
	if settings_scene:
		var settings := settings_scene.instantiate()
		if not settings.get_node_or_null("PanelRoot/Content/MusicRow/MusicSlider"):
			issues.append("Settings is missing the music volume slider")
		if not settings.get_node_or_null("PanelRoot/Content/SfxRow/SfxSlider"):
			issues.append("Settings is missing the SFX volume slider")
		if settings.find_child("ThemeOption", true, false) or settings.find_child("FeedbackOption", true, false):
			issues.append("Removed Theme/Game Feel options returned to Settings")
		settings.free()
	var card_scene := load("res://Scenes/UI/Components/shop_item_button.tscn") as PackedScene
	if card_scene:
		var card := card_scene.instantiate() as Control
		if card and (card.custom_minimum_size.y < 290.0 or not card.clip_contents):
			issues.append("Shop cards must contain and clip their portrait layout")
		if card:
			card.free()
	return issues
