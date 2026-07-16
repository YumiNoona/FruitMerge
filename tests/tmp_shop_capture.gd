extends Node


func _enter_tree() -> void:
	EconomyManager.coins = 12850


func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("res://tests/shop_capture.png")
	get_tree().quit()
