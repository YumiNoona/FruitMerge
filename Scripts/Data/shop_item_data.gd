class_name ShopItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var cost: int
@export var currency: StringName = &"coins"
@export var category: StringName
@export var description: String

@export_category("In-game refill")
@export_range(1, 99, 1, "suffix: tickets") var refill_ticket_cost := 1

@export_category("Power-up Juice")
@export_range(0.05, 3.0, 0.01, "suffix:s") var effect_duration := 0.3
@export_range(0.0, 2.0, 0.01) var camera_shake_strength := 0.35
@export_range(0.1, 3.0, 0.01, "suffix:x") var camera_shake_duration := 0.7
@export_range(0.0, 40.0, 0.1, "suffix:px") var container_motion_strength := 12.0
@export_range(0.1, 3.0, 0.01, "suffix:s") var container_motion_duration := 0.8
@export_range(0.0, 500.0, 1.0) var fruit_impulse_strength := 180.0
@export_range(0.0, 16.0, 0.1) var fruit_spin_strength := 4.5
@export_range(0.0, 1.0, 0.01) var fruit_followup_impulse_ratio := 0.4
@export_range(0.5, 4.0, 0.01, "suffix:x") var target_marker_scale := 2.55
@export_range(0.05, 2.0, 0.01, "suffix:s") var target_marker_hold_time := 0.52
@export_range(0.05, 1.0, 0.01, "suffix:s") var target_lock_time := 0.17
@export_range(1.0, 1.5, 0.01, "suffix:x") var grab_held_scale := 1.13
@export_range(20.0, 500.0, 1.0) var grab_release_speed := 180.0
@export_range(1.0, 16.0, 0.1) var grab_ring_speed := 5.5
@export_range(40.0, 320.0, 1.0, "suffix:px") var blast_radius := 150.0


func is_valid_definition() -> bool:
	return not id.is_empty() \
		and not display_name.is_empty() \
		and cost >= 0 \
		and currency in [&"coins", &"tickets"] \
		and category in [&"skin", &"pet", &"powerup", &"background"] \
		and (category != &"powerup" or refill_ticket_cost > 0)
