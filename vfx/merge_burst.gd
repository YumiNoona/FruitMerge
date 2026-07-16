extends Node2D

@export var duration: float = 0.52
@export var sprite_frames: SpriteFrames

var _elapsed: float = 0.0
var _tier: int = 0
var _burst_color := Color(1.0, 0.78, 0.22, 1.0)

@onready var _animated_sprite: AnimatedSprite2D = %AnimatedSprite2D


func configure(tier: int) -> void:
	_tier = tier
	var hue := fmod(0.09 + float(tier) * 0.045, 1.0)
	_burst_color = Color.from_hsv(hue, 0.62, 1.0, 1.0)


func _ready() -> void:
	z_index = 50
	if sprite_frames and sprite_frames.get_animation_names().size() > 0:
		_animated_sprite.sprite_frames = sprite_frames
		_animated_sprite.visible = true
		_animated_sprite.play(sprite_frames.get_animation_names()[0])
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= duration:
		queue_free()


func _draw() -> void:
	if sprite_frames and sprite_frames.get_animation_names().size() > 0:
		return
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var alpha := 1.0 - progress
	var ring_color := _burst_color
	ring_color.a = alpha * 0.9
	draw_arc(Vector2.ZERO, lerpf(12.0, 72.0, progress), 0.0, TAU, 40, ring_color, lerpf(9.0, 2.0, progress), true)
	var inner_color := Color(1.0, 1.0, 0.82, alpha * 0.72)
	draw_arc(Vector2.ZERO, lerpf(5.0, 48.0, progress), 0.0, TAU, 32, inner_color, lerpf(6.0, 1.0, progress), true)
	for spark_index in 10:
		var angle := TAU * float(spark_index) / 10.0 + float(_tier) * 0.17
		var spark_position := Vector2.RIGHT.rotated(angle) * lerpf(15.0, 88.0, progress)
		var spark_color := _burst_color.lightened(0.22)
		spark_color.a = alpha
		draw_circle(spark_position, lerpf(6.0, 1.0, progress), spark_color)
