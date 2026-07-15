extends Node

@export var fruits: Array[FruitData] = []


func _ready() -> void:
	if fruits.is_empty():
		_auto_load_fruits()
	for f in fruits:
		if f.merge_sfx == null:
			continue
		f.merge_sfx.resource_local_to_scene = true


func _auto_load_fruits() -> void:
	var dir := DirAccess.open("res://data/fruits/")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load("res://data/fruits/" + file_name) as FruitData
			if res:
				fruits.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	fruits.sort_custom(func(a: FruitData, b: FruitData): return a.tier < b.tier)


func get_fruit(tier: int) -> FruitData:
	for f in fruits:
		if f.tier == tier:
			return f
	return null


func get_next_fruit(current_tier: Enums.FruitTier) -> FruitData:
	var fd: FruitData = get_fruit(current_tier)
	if not fd or fd.next_tier < 0:
		return null
	return get_fruit(fd.next_tier)


func get_tier_count() -> int:
	return fruits.size()


func get_max_tier() -> Enums.FruitTier:
	if fruits.is_empty():
		return Enums.FruitTier.CHERRY
	return fruits[-1].tier
