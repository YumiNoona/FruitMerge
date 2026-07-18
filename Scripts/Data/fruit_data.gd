class_name FruitData
extends Resource

@export var tier: Enums.FruitTier
@export var display_name: String
@export_category("Scene-authoritative fallback/preview")
## Variant scenes own their sprite, scale, collision shape, and collision offset.
## These fields are only fallbacks for previews and generic test scenes.
@export var sprite: Texture2D
@export var sprite_visual_width: float = 0.0
@export var radius: float = 28.0
@export var score_value: int = 1
@export var next_tier: int = -1
@export var merge_sfx: AudioStream
@export var mass: float = 1.0
@export var color: Color = Color.WHITE
@export var guide_color: Color = Color.WHITE
