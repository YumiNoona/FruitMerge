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
	var migrated_v7: Dictionary = SaveManager.call("_migrate_data", {
		"version": 7,
		"mission_data": {"date": "2026-07-18", "claimed": [0]},
		"settings": {},
	})
	if migrated_v7.get("daily_mission_data", {}) != {"date": "2026-07-18", "claimed": [0]}:
		failures.append("Save v8 migration must preserve legacy daily mission data")
	var campaign_data: Dictionary = migrated_v7.get("mission_data", {})
	if not bool(campaign_data.get("onboarding_completed", false)) or int(campaign_data.get("highest_unlocked", 0)) != 7:
		failures.append("Existing profiles must migrate with onboarding complete and all modes unlocked")
	if migrated_v7.get("settings", {}).get("power_loadout", []).size() != 3:
		failures.append("Save v8 migration must create a valid three-power loadout")
	if Enums.GameMode.keys() != ["CLASSIC", "MISSIONS", "TIME_ATTACK"]:
		failures.append("Only Classic, Missions, and Time Attack may be exposed")
	if MissionManager.definitions.size() != 7:
		failures.append("The onboarding campaign must contain seven mission resources")
	else:
		var taught: Array[StringName] = []
		var unique_taught: Dictionary = {}
		for level in range(1, 8):
			var mission := MissionManager.get_definition(level)
			if not mission or mission.level != level or not mission.is_valid_definition():
				failures.append("Mission %d must be a valid sequential definition" % level)
			elif level > 1:
				taught.append(mission.required_powerup)
				unique_taught[mission.required_powerup] = true
		if taught.size() != 6 or unique_taught.size() != 6:
			failures.append("Missions 2-7 must teach six distinct power-ups")
	if PowerLoadoutManager.ALL_POWERUPS.size() != 6 or PowerLoadoutManager.selected_loadout.size() != 3:
		failures.append("Power loadouts must select three of the six available types")
	if GameManager.TIME_ATTACK_CONFIG.duration_seconds != 120.0:
		failures.append("Time Attack must retain its two-minute resource setting")
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
	if ShopItemDisplayRulesScript.should_show_description(&"pet"):
		failures.append("Pet cards must keep descriptions hidden")
	if not ShopItemDisplayRulesScript.should_show_description(&"powerup"):
		failures.append("Non-pet shop cards must retain useful descriptions")
	if FloatingButtonAnimatorScript.DEFAULT_FLOAT_HEIGHT < 6.0 \
		or FloatingButtonAnimatorScript.DEFAULT_FLOAT_HEIGHT > 12.0 \
		or FloatingButtonAnimatorScript.DEFAULT_TRAVEL_DURATION < 0.8:
		failures.append("The dock Play button float must remain gentle and readable")
	RewardPresentationManager.clear_pending_wallet_rewards()
	if RewardPresentationManager.queue_wallet_reward(&"gems", 2) \
		or RewardPresentationManager.queue_wallet_reward(&"coins", 0):
		failures.append("Wallet reward presentation must reject invalid rewards")
	RewardPresentationManager.queue_wallet_reward(&"tickets", 2)
	var pending_rewards := RewardPresentationManager.take_pending_wallet_rewards()
	if pending_rewards.size() != 1 \
		or StringName(pending_rewards[0].get("currency", &"")) != &"tickets" \
		or int(pending_rewards[0].get("amount", 0)) != 2:
		failures.append("Wallet reward presentation must survive a scene transition queue")
	if not RewardPresentationManager.take_pending_wallet_rewards().is_empty():
		failures.append("Wallet reward presentation queue must be consumed exactly once")
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
	if Fruit.calculate_impact_strength(80.0, 85.0, 430.0) != 0.0:
		failures.append("Low-speed pile settling must not trigger extra impact motion")
	var strong_impact := Fruit.calculate_impact_strength(430.0, 85.0, 430.0)
	if strong_impact < 0.99 or strong_impact > 1.0:
		failures.append("A full-speed fruit collision must reach the complete spring response")
	var fruit_material := load("res://Data/Resources/fruit_physics.tres") as PhysicsMaterial
	if not fruit_material or fruit_material.bounce < 0.16 or fruit_material.bounce > 0.25 \
		or fruit_material.friction < 0.28 or fruit_material.friction > 0.40:
		failures.append("Fruit material must retain its soft, mobile-friendly rebound tuning")
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
