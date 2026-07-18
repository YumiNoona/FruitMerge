extends RefCounted

const ShopItemDisplayRulesScript = preload("res://Scripts/UI/Components/shop_item_display_rules.gd")
const FloatingButtonAnimatorScript = preload("res://Scripts/UI/Components/floating_button_animator.gd")


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
	if ShopItemDisplayRulesScript.should_show_inventory_count(1):
		failures.append("The shop must hide redundant x1 power-up inventory badges")
	if not ShopItemDisplayRulesScript.should_show_inventory_count(2):
		failures.append("The shop must show power-up inventory badges for stacked quantities")
	if FloatingButtonAnimatorScript.DEFAULT_FLOAT_HEIGHT < 6.0 \
		or FloatingButtonAnimatorScript.DEFAULT_FLOAT_HEIGHT > 12.0 \
		or FloatingButtonAnimatorScript.DEFAULT_TRAVEL_DURATION < 0.8:
		failures.append("The dock Play button float must remain gentle and readable")
	var shake_data: Resource = load("res://Data/ShopItems/powerup_shake_box.tres")
	if not shake_data:
		failures.append("Shake Box tuning data must load")
	elif float(shake_data.get("container_motion_strength")) < 25.0 \
		or float(shake_data.get("fruit_impulse_strength")) < 250.0 \
		or float(shake_data.get("fruit_followup_impulse_ratio")) <= 0.0:
		failures.append("Shake Box must retain strong container motion and its follow-up fruit impulse")
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
