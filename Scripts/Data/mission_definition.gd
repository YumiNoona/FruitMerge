class_name MissionDefinition
extends Resource

@export_range(1, 7, 1) var level := 1
@export var title := "First Harvest"
@export_multiline var description := "Learn to merge matching fruit."
@export var target_tier: Enums.FruitTier = Enums.FruitTier.BERRIES
@export_range(1, 20, 1) var target_count := 1
@export var required_powerup: StringName = &""
@export_range(0, 5, 1) var temporary_charges := 0
@export var spawn_sequence: Array[int] = []
@export var starting_tiers: Array[int] = []
@export var starting_positions: Array[Vector2] = []
@export_multiline var opening_instruction := "Drop a matching fruit onto its twin."
@export_multiline var power_instruction := "Use the highlighted power-up."
@export_range(0, 1000, 1) var reward_coins := 0
@export_range(0, 10, 1) var reward_tickets := 0


func is_valid_definition() -> bool:
	return (
		level >= 1
		and level <= 7
		and target_count > 0
		and starting_tiers.size() == starting_positions.size()
		and (required_powerup.is_empty() or temporary_charges > 0)
	)
