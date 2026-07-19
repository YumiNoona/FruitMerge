@tool
class_name ContainerRig
extends Node2D

const BASE_ART_SCALE := 0.603
const BASE_ART_BOTTOM_Y := -214.5
const BASE_BOX_POSITION := Vector2(0.0, -230.0)
const BASE_INNER_WIDTH := 498.0
const BASE_INNER_HEIGHT := 820.0
const BASE_WALL_THICKNESS := 22.0
const BASE_DANGER_DEPTH := 700.0
const BASE_SPAWNER_MARGIN := 30.0
const BASE_PET_EDGE_GAP := 33.0

@export_category("Container sizing")
@export_range(0.85, 1.20, 0.01) var container_width_multiplier := 1.0:
	set(value):
		container_width_multiplier = clampf(value, 0.85, 1.20)
		if is_inside_tree():
			_apply_container_layout.call_deferred()
@export_range(0.85, 1.15, 0.01) var container_height_multiplier := 1.0:
	set(value):
		container_height_multiplier = clampf(value, 0.85, 1.15)
		if is_inside_tree():
			_apply_container_layout.call_deferred()


func _ready() -> void:
	set_notify_local_transform(true)
	_apply_container_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_inside_tree():
		_sync_sibling_anchors.call_deferred()


func _apply_container_layout() -> void:
	if not is_inside_tree():
		return
	var inner_width := BASE_INNER_WIDTH * container_width_multiplier
	var inner_height := BASE_INNER_HEIGHT * container_height_multiplier
	var wall_thickness := BASE_WALL_THICKNESS * minf(container_width_multiplier, container_height_multiplier)
	var danger_depth := BASE_DANGER_DEPTH * container_height_multiplier
	var box_container := get_node_or_null("BoxContainer") as Node2D
	var box := get_node_or_null("BoxContainer/Box") as Box
	var container_art := get_node_or_null("ContainerArt") as Sprite2D

	if box_container:
		box_container.position = BASE_BOX_POSITION
	if box:
		box.configure_dimensions(inner_width, inner_height, wall_thickness, danger_depth)
	if container_art and container_art.texture:
		var art_scale := Vector2(
			BASE_ART_SCALE * container_width_multiplier,
			BASE_ART_SCALE * container_height_multiplier
		)
		container_art.scale = art_scale
		container_art.position = Vector2(
			0.0,
			BASE_ART_BOTTOM_Y - float(container_art.texture.get_height()) * art_scale.y * 0.5
		)

	_sync_sibling_anchors()


func _sync_sibling_anchors() -> void:
	if not is_inside_tree():
		return
	var inner_width := BASE_INNER_WIDTH * container_width_multiplier
	var inner_height := BASE_INNER_HEIGHT * container_height_multiplier
	var world_origin := get_parent()
	if not world_origin:
		return
	var spawner_container := world_origin.get_node_or_null("SpawnerContainer") as Node2D
	if spawner_container:
		spawner_container.position.y = position.y + BASE_BOX_POSITION.y - inner_height - BASE_SPAWNER_MARGIN
		var live_spawner := spawner_container.get_node_or_null("Spawner") as Spawner
		if live_spawner:
			live_spawner.set_playfield_half_width(inner_width * 0.5)
	var pet_container := world_origin.get_node_or_null("PetContainer") as Node2D
	if pet_container:
		pet_container.position.x = position.x + inner_width * 0.5 + BASE_PET_EDGE_GAP


func get_playfield_half_width() -> float:
	return BASE_INNER_WIDTH * container_width_multiplier * 0.5


func get_playfield_height() -> float:
	return BASE_INNER_HEIGHT * container_height_multiplier
