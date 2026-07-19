class_name PetAbilityCatalog
extends RefCounted

const ABILITY_PATHS := {
	&"pet_strawberry_cat": "res://Data/PetAbilities/strawberry_cat.tres",
	&"pet_watermelon_pup": "res://Data/PetAbilities/watermelon_pup.tres",
	&"pet_peach_bunny": "res://Data/PetAbilities/peach_bunny.tres",
	&"pet_pineapple_meow": "res://Data/PetAbilities/pineapple_meow.tres",
	&"pet_melon_bear": "res://Data/PetAbilities/melon_bear.tres",
	&"pet_banana_fox": "res://Data/PetAbilities/banana_fox.tres",
	&"pet_berry_hamster": "res://Data/PetAbilities/berry_hamster.tres",
	&"pet_cherry_bird": "res://Data/PetAbilities/cherry_bird.tres",
	&"pet_lemon_frog": "res://Data/PetAbilities/lemon_frog.tres",
}


static func get_ability(pet_id: StringName) -> PetAbilityData:
	var path := str(ABILITY_PATHS.get(pet_id, ""))
	return load(path) as PetAbilityData if not path.is_empty() else null


static func get_all() -> Array[PetAbilityData]:
	var abilities: Array[PetAbilityData] = []
	for pet_id in ABILITY_PATHS:
		var ability := get_ability(pet_id)
		if ability:
			abilities.append(ability)
	return abilities


static func get_shop_summary(pet_id: StringName) -> String:
	var ability := get_ability(pet_id)
	return ability.shop_summary if ability else ""
