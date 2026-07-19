extends Node

@warning_ignore("unused_signal")
signal fruit_merged(tier: int, world_pos: Vector2, score_gained: int)

@warning_ignore("unused_signal")
signal fruit_created(tier: int, world_pos: Vector2)

@warning_ignore("unused_signal")
signal fruit_dropped(tier: int)

@warning_ignore("unused_signal")
signal score_changed(new_score: int)

@warning_ignore("unused_signal")
signal high_score_changed(new_high_score: int)

@warning_ignore("unused_signal")
signal coins_changed(new_amount: int)

@warning_ignore("unused_signal")
signal tickets_changed(new_amount: int)

@warning_ignore("unused_signal")
signal game_over(final_score: int)

@warning_ignore("unused_signal")
signal danger_line_entered

@warning_ignore("unused_signal")
signal danger_line_exited

@warning_ignore("unused_signal")
signal shop_item_purchased(item_id: StringName)

@warning_ignore("unused_signal")
signal item_equipped(item_id: StringName)

@warning_ignore("unused_signal")
signal powerup_count_changed(item_id: StringName, count: int)

@warning_ignore("unused_signal")
signal powerup_requested(item_id: StringName)

@warning_ignore("unused_signal")
signal powerup_targeting_changed(active: bool, message: String)

@warning_ignore("unused_signal")
signal powerup_used(item_id: StringName)

@warning_ignore("unused_signal")
signal power_loadout_changed(loadout: Array[StringName])

@warning_ignore("unused_signal")
signal mission_progress_changed(label: String, current: int, target: int)

@warning_ignore("unused_signal")
signal mission_instruction_changed(title: String, message: String, target_tier: int)

@warning_ignore("unused_signal")
signal mission_completed(level: int, coins: int, tickets: int)

@warning_ignore("unused_signal")
signal run_timer_changed(seconds_remaining: int)

@warning_ignore("unused_signal")
signal state_changed(new_state: Enums.GameState)

@warning_ignore("unused_signal")
signal game_restarted

@warning_ignore("unused_signal")
signal fruit_discovered(tier: int)

@warning_ignore("unused_signal")
signal statistics_changed

@warning_ignore("unused_signal")
signal accessibility_changed

@warning_ignore("unused_signal")
signal daily_missions_changed
