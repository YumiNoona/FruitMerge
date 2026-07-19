extends Node

const FRUIT_PATHS: PackedStringArray = [
	"res://Data/Fruits/cherry.tres",
	"res://Data/Fruits/berries.tres",
	"res://Data/Fruits/strawberry.tres",
	"res://Data/Fruits/grape.tres",
	"res://Data/Fruits/kiwi.tres",
	"res://Data/Fruits/lemon.tres",
	"res://Data/Fruits/orange.tres",
	"res://Data/Fruits/apple.tres",
	"res://Data/Fruits/peach.tres",
	"res://Data/Fruits/coconut.tres",
	"res://Data/Fruits/pineapple.tres",
	"res://Data/Fruits/dragonfruit.tres",
	"res://Data/Fruits/watermelon.tres",
]

const FRUIT_SCENE_PATHS: PackedStringArray = [
	"res://Scenes/Fruits/Variants/cherry.tscn",
	"res://Scenes/Fruits/Variants/berries.tscn",
	"res://Scenes/Fruits/Variants/strawberry.tscn",
	"res://Scenes/Fruits/Variants/grape.tscn",
	"res://Scenes/Fruits/Variants/kiwi.tscn",
	"res://Scenes/Fruits/Variants/lemon.tscn",
	"res://Scenes/Fruits/Variants/orange.tscn",
	"res://Scenes/Fruits/Variants/apple.tscn",
	"res://Scenes/Fruits/Variants/peach.tscn",
	"res://Scenes/Fruits/Variants/coconut.tscn",
	"res://Scenes/Fruits/Variants/pineapple.tscn",
	"res://Scenes/Fruits/Variants/dragonfruit.tscn",
	"res://Scenes/Fruits/Variants/watermelon.tscn",
]

@export var fruits: Array[FruitData] = []
var _fruit_scenes: Array[PackedScene] = []
var _fruit_collision_radii: Array[float] = []
var _fruit_collision_tops: Array[float] = []
var _fruit_collision_bottoms: Array[float] = []
var _fruit_visual_textures: Array[Texture2D] = []
var _fruit_visual_scales: Array[Vector2] = []


func _ready() -> void:
	if fruits.is_empty():
		_load_fruit_chain()
	fruits.sort_custom(func(a: FruitData, b: FruitData): return a.tier < b.tier)
	_load_fruit_scenes()


func _load_fruit_chain() -> void:
	for path in FRUIT_PATHS:
		var fruit := load(path) as FruitData
		if fruit:
			fruits.append(fruit)


func _load_fruit_scenes() -> void:
	_fruit_scenes.clear()
	_fruit_collision_radii.clear()
	_fruit_collision_tops.clear()
	_fruit_collision_bottoms.clear()
	_fruit_visual_textures.clear()
	_fruit_visual_scales.clear()
	for tier in FRUIT_SCENE_PATHS.size():
		var scene := load(FRUIT_SCENE_PATHS[tier]) as PackedScene
		_fruit_scenes.append(scene)
		var fruit_data := get_fruit(tier)
		var collision_half_width := fruit_data.radius if fruit_data else 28.0
		var collision_top := collision_half_width
		var collision_bottom := collision_half_width
		var visual_texture: Texture2D = fruit_data.sprite if fruit_data else null
		var visual_scale := Vector2.ONE
		if scene:
			var fruit := scene.instantiate() as Fruit
			if fruit:
				var collision := fruit.get_node_or_null("CollisionShape2D") as CollisionShape2D
				if collision and collision.shape:
					var half_size := _get_shape_half_size(collision.shape, collision_half_width)
					collision_half_width = half_size.x + absf(collision.position.x)
					collision_top = maxf(1.0, half_size.y - collision.position.y)
					collision_bottom = maxf(1.0, half_size.y + collision.position.y)
				var sprite := fruit.get_node_or_null("Sprite2D") as Sprite2D
				if sprite:
					visual_texture = sprite.texture
					visual_scale = sprite.scale
				fruit.free()
		_fruit_collision_radii.append(collision_half_width)
		_fruit_collision_tops.append(collision_top)
		_fruit_collision_bottoms.append(collision_bottom)
		_fruit_visual_textures.append(visual_texture)
		_fruit_visual_scales.append(visual_scale)


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


func get_collision_bottom_extent(tier: int) -> float:
	if tier < 0 or tier >= _fruit_collision_bottoms.size():
		var fruit := get_fruit(tier)
		return fruit.radius if fruit else 28.0
	return _fruit_collision_bottoms[tier]


func get_collision_top_extent(tier: int) -> float:
	if tier < 0 or tier >= _fruit_collision_tops.size():
		var fruit := get_fruit(tier)
		return fruit.radius if fruit else 28.0
	return _fruit_collision_tops[tier]


func _get_shape_half_size(shape: Shape2D, fallback_radius: float) -> Vector2:
	if shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		return Vector2(radius, radius)
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return Vector2(capsule.radius, capsule.height * 0.5)
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size * 0.5
	return Vector2.ONE * fallback_radius


func get_visual_texture(tier: int) -> Texture2D:
	if tier < 0 or tier >= _fruit_visual_textures.size():
		return null
	return _fruit_visual_textures[tier]


func get_visual_scale(tier: int) -> Vector2:
	if tier < 0 or tier >= _fruit_visual_scales.size():
		return Vector2.ONE
	return _fruit_visual_scales[tier]


func get_guide_color(tier: int) -> Color:
	var fruit := get_fruit(tier)
	return fruit.guide_color if fruit else Color(1.0, 0.72, 0.2, 1.0)


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
