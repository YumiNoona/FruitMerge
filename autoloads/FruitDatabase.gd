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

const FRUIT_SCENE_PATHS: PackedStringArray = [
	"res://entities/fruit/variants/cherry.tscn",
	"res://entities/fruit/variants/berries.tscn",
	"res://entities/fruit/variants/strawberry.tscn",
	"res://entities/fruit/variants/grape.tscn",
	"res://entities/fruit/variants/kiwi.tscn",
	"res://entities/fruit/variants/lemon.tscn",
	"res://entities/fruit/variants/orange.tscn",
	"res://entities/fruit/variants/apple.tscn",
	"res://entities/fruit/variants/peach.tscn",
	"res://entities/fruit/variants/mango.tscn",
	"res://entities/fruit/variants/coconut.tscn",
	"res://entities/fruit/variants/pineapple.tscn",
	"res://entities/fruit/variants/dragonfruit.tscn",
	"res://entities/fruit/variants/watermelon.tscn",
]

@export var fruits: Array[FruitData] = []
var _fruit_scenes: Array[PackedScene] = []
var _fruit_collision_radii: Array[float] = []


func _ready() -> void:
	if fruits.is_empty():
		_load_fruit_chain()
	fruits.sort_custom(func(a: FruitData, b: FruitData): return a.tier < b.tier)
	_load_fruit_scenes()


func _load_fruit_chain() -> void:
	for path in FRUIT_PATHS:
		var fruit := load(path) as FruitData
		if fruit and fruit.sprite:
			fruits.append(fruit)


func _load_fruit_scenes() -> void:
	_fruit_scenes.clear()
	_fruit_collision_radii.clear()
	for tier in FRUIT_SCENE_PATHS.size():
		var scene := load(FRUIT_SCENE_PATHS[tier]) as PackedScene
		_fruit_scenes.append(scene)
		var fruit_data := get_fruit(tier)
		var collision_radius := fruit_data.radius if fruit_data else 28.0
		if scene:
			var fruit := scene.instantiate() as Fruit
			if fruit:
				var collision := fruit.get_node_or_null("CollisionShape2D") as CollisionShape2D
				if collision and collision.shape is CircleShape2D:
					collision_radius = (collision.shape as CircleShape2D).radius
				fruit.free()
		_fruit_collision_radii.append(collision_radius)


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


func get_fruit_scene(tier: int) -> PackedScene:
	if tier < 0 or tier >= _fruit_scenes.size():
		return null
	return _fruit_scenes[tier]


func get_collision_radius(tier: int) -> float:
	if tier < 0 or tier >= _fruit_collision_radii.size():
		var fruit := get_fruit(tier)
		return fruit.radius if fruit else 28.0
	return _fruit_collision_radii[tier]


func create_fruit(tier: int) -> Fruit:
	var scene := get_fruit_scene(tier)
	if not scene:
		return null
	var fruit := scene.instantiate() as Fruit
	if fruit and not fruit.data:
		fruit.data = get_fruit(tier)
	return fruit


func get_tier_count() -> int:
	return fruits.size()


func get_max_tier() -> Enums.FruitTier:
	if fruits.is_empty():
		return Enums.FruitTier.CHERRY
	return fruits[-1].tier
