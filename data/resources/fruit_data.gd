class_name FruitData
extends Resource

@export var tier: Enums.FruitTier
@export var display_name: String
@export var sprite: Texture2D
@export var radius: float = 28.0
@export var score_value: int = 1
@export var next_tier: int = -1
@export var merge_sfx: AudioStream
@export var mass: float = 1.0
@export var color: Color = Color.WHITE
