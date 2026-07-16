extends Node

const FRUIT_PATHS: PackedStringArray = [
	"res://data/fruits/cherry.tres",
	"res://data/fruits/berries.tres",
	"res://data/fruits/strawberry.tres",
	"res://data/fruits/grape.tres",
	"res://data/fruits/kiwi.tres",
	"res://data/fruits/lemon.tres",
	"res://data/fruits/orange.tres",
	"res://data/fruits/apple.tres",
	"res://data/fruits/peach.tres",
	"res://data/fruits/mango.tres",
	"res://data/fruits/coconut.tres",
	"res://data/fruits/pineapple.tres",
	"res://data/fruits/dragonfruit.tres",
	"res://data/fruits/watermelon.tres",
]

@export var fruits: Array[FruitData] = []


func _ready() -> void:
	if fruits.is_empty():
		_load_fruit_chain()
	fruits.sort_custom(func(a: FruitData, b: FruitData): return a.tier < b.tier)


func _load_fruit_chain() -> void:
	for path in FRUIT_PATHS:
		var fruit := load(path) as FruitData
		if fruit and fruit.sprite:
			fruits.append(fruit)


func get_fruit(tier: int) -> FruitData:
	for fruit in fruits:
		if fruit.tier == tier:
			return fruit
	return null


func get_next_fruit(current_tier: Enums.FruitTier) -> FruitData:
	var fruit := get_fruit(current_tier)
	if not fruit or fruit.next_tier < 0:
		return null
	return get_fruit(fruit.next_tier)


func get_tier_count() -> int:
	return fruits.size()


func get_max_tier() -> Enums.FruitTier:
	if fruits.is_empty():
		return Enums.FruitTier.CHERRY
	return fruits[-1].tier
