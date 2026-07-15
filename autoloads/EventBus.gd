extends Node

signal fruit_merged(tier: int, world_pos: Vector2, score_gained: int)
signal fruit_dropped(tier: int)
signal score_changed(new_score: int)
signal high_score_changed(new_high_score: int)
signal coins_changed(new_amount: int)
signal game_over(final_score: int)
signal danger_line_entered
signal danger_line_exited
signal shop_item_purchased(item_id: StringName)
signal state_changed(new_state: Enums.GameState)
signal game_restarted
