class_name PetAbilityData
extends Resource

enum Activation { CHARGED_TAP, PASSIVE, AUTOMATIC }
enum Effect {
	MATCH_POUNCE,
	SAFETY_BARK,
	GENTLE_LANDING,
	SAFE_LANE,
	COZY_HUG,
	FUTURE_SIGHT,
	COIN_CACHE,
	ENCORE,
	LUCKY_HOP,
}

@export var pet_id: StringName
@export var ability_name: String
@export_multiline var shop_summary: String
@export var activation: Activation = Activation.PASSIVE
@export var effect: Effect = Effect.MATCH_POUNCE
@export_range(0, 20, 1) var charge_required := 0
@export_range(0, 10, 1) var max_uses_per_run := 0
@export_range(0, 20, 1) var interval := 0
@export_range(0.0, 10.0, 0.05) var effect_duration := 0.0
@export_range(0.0, 200.0, 0.05) var effect_value := 0.0
@export var accent_color := Color(0.54, 0.86, 0.30, 1.0)


func is_valid_definition() -> bool:
	if pet_id.is_empty() or ability_name.is_empty() or shop_summary.is_empty():
		return false
	if activation == Activation.CHARGED_TAP and charge_required <= 0:
		return false
	if effect in [Effect.GENTLE_LANDING, Effect.COIN_CACHE] and interval <= 0:
		return false
	return true
