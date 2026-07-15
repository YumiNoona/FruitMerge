class_name MergeService
extends RefCounted

static func try_merge(fruit_a: Fruit, fruit_b: Fruit) -> bool:
	if fruit_a.is_merging or fruit_b.is_merging:
		return false
	if not fruit_a.data or not fruit_b.data:
		return false
	if fruit_a.data.tier != fruit_b.data.tier:
		return false
	if fruit_a.data.next_tier < 0:
		return false

	var next_data: FruitData = FruitDatabase.get_next_fruit(fruit_a.data.tier)
	if not next_data:
		return false

	fruit_a.is_merging = true
	fruit_b.is_merging = true

	fruit_a.set_emotion(Enums.FruitEmotion.EXCITED)
	fruit_b.set_emotion(Enums.FruitEmotion.EXCITED)

	await fruit_a.get_tree().create_timer(0.1).timeout

	var midpoint: Vector2 = (fruit_a.global_position + fruit_b.global_position) / 2.0
	var score_gained: int = fruit_a.data.score_value
	var tier: int = fruit_a.data.tier as int

	EventBus.fruit_merged.emit(tier, midpoint, score_gained)

	if is_instance_valid(fruit_a):
		fruit_a.queue_free()
	if is_instance_valid(fruit_b):
		fruit_b.queue_free()

	Spawner.spawn_at(next_data, midpoint)
	return true
