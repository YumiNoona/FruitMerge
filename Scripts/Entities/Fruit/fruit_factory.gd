class_name FruitFactory
extends RefCounted

const CHAIN_MERGE_LOCK_TIME: float = 0.035

static func create(data: FruitData, world_position: Vector2, parent: Node) -> Fruit:
	if not data or not is_instance_valid(parent):
		return null
	var fruit := FruitDatabase.create_fruit(data.tier)
	if not fruit:
		return null
	fruit.data = data
	fruit.spawn_merge_lock_time = CHAIN_MERGE_LOCK_TIME
	fruit.position = world_position
	fruit.sleeping = false
	fruit.linear_velocity = Vector2(0, -70)
	fruit.angular_velocity = random_drop_spin()
	parent.add_child.call_deferred(fruit)
	return fruit


static func random_drop_spin() -> float:
	var spin := randf_range(-0.9, 0.9)
	if absf(spin) < 0.28:
		spin = 0.28 if randf() > 0.5 else -0.28
	return spin
