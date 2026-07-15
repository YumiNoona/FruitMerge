extends GpuParticles2D

@export var auto_free: bool = true


func _ready() -> void:
	if one_shot:
		emitting = true
	if auto_free:
		finished.connect(queue_free)
