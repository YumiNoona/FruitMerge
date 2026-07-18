extends RefCounted

const ShopItemButtonScript = preload("res://Scripts/UI/Components/shop_item_button.gd")


static func run() -> PackedStringArray:
	var failures: PackedStringArray = []
	var stats := GameManager.sanitize_statistics({"total_merges": -5, "largest_combo": 7})
	if stats.total_merges != 0:
		failures.append("Statistics must clamp negative values")
	if stats.largest_combo != 7:
		failures.append("Statistics migration lost valid values")
	var migrated_profile: Dictionary = SaveManager.call("_migrate_data", {
		"version": 6,
		"settings": {"theme": "Warm", "feedback_level": 3, "haptic_strength": 0.0, "reduced_motion": true},
	})
	var migrated_settings: Dictionary = migrated_profile.get("settings", {})
	if migrated_settings.has("theme") or migrated_settings.has("feedback_level"):
		failures.append("Save v7 must remove retired Theme and Game Feel settings")
	if float(migrated_settings.get("haptic_strength", 0.0)) != 1.0 or bool(migrated_settings.get("reduced_motion", true)):
		failures.append("Save v7 must restore standard effects after removing Game Feel")
	if FruitDatabase.get_next_fruit(Enums.FruitTier.WATERMELON) != null:
		failures.append("Watermelon must be the end of the chain")
	if EconomyManager.get_currency_balance(&"invalid") != -1:
		failures.append("Unknown currency must be rejected")
	if Bootstrap.DEBUG_POWERUP_COUNT != 1:
		failures.append("Debug builds must seed exactly one of each power-up")
	if ShopItemButtonScript.should_show_inventory_count(1):
		failures.append("The shop must hide redundant x1 power-up inventory badges")
	if not ShopItemButtonScript.should_show_inventory_count(2):
		failures.append("The shop must show power-up inventory badges for stacked quantities")
	if AudioManager.get_music_track_count() != 4:
		failures.append("Persistent music playlist must contain all four authored tracks")
	if not AudioManager.are_music_tracks_one_shot():
		failures.append("Playlist tracks must be one-shot so all four can rotate")
	if MergeService.MERGE_CONVERGE_DURATION > 0.1 or FruitFactory.CHAIN_MERGE_LOCK_TIME > 0.05:
		failures.append("Merge anticipation and chain lock must remain responsive")
	if OS.get_name() not in ["Android", "iOS"] and MobileSafeArea.get_viewport_insets(Engine.get_main_loop().root) != Vector4.ZERO:
		failures.append("Desktop debug builds must not apply mobile safe-area offsets")
	if Box.is_danger_candidate(true, false, false, -10.0, 0.0, Vector2(0.0, 280.0), false, 70.0):
		failures.append("Fast falling fruit must not trigger the danger warning")
	if Box.is_danger_candidate(false, false, false, -10.0, 0.0, Vector2.ZERO, true, 70.0):
		failures.append("Fruit that has not entered the container must not trigger danger")
	if not Box.is_danger_candidate(true, false, false, -10.0, 0.0, Vector2.ZERO, true, 70.0):
		failures.append("Settled fruit above the line must trigger danger")
	if Box.is_danger_candidate(true, true, false, -10.0, 0.0, Vector2.ZERO, true, 70.0):
		failures.append("Grabbed or frozen fruit must not trigger danger")
	if Box.is_danger_candidate(true, false, false, 10.0, 0.0, Vector2.ZERO, true, 70.0):
		failures.append("Fruit fully below the line must not trigger danger")
	return failures
