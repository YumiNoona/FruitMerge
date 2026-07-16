class_name MergeService
extends RefCounted

static func try_merge(fruit_a: Fruit, fruit_b: Fruit) -> bool:
	if not is_instance_valid(fruit_a) or not is_instance_valid(fruit_b):
		return false
	if not fruit_a.is_inside_tree() or not fruit_b.is_inside_tree():
		return false
	if GameManager.current_state != Enums.GameState.PLAYING:
		return false
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

	var tree := fruit_a.get_tree()
	await tree.create_timer(0.18).timeout

	if not is_instance_valid(fruit_a) or not is_instance_valid(fruit_b):
		_release_merge_lock(fruit_a)
		_release_merge_lock(fruit_b)
		return false
	if not fruit_a.is_inside_tree() or not fruit_b.is_inside_tree():
		_release_merge_lock(fruit_a)
		_release_merge_lock(fruit_b)
		return false
	if GameManager.current_state != Enums.GameState.PLAYING:
		_release_merge_lock(fruit_a)
		_release_merge_lock(fruit_b)
		return false

	var midpoint: Vector2 = (fruit_a.global_position + fruit_b.global_position) / 2.0
	var score_gained: int = GameManager.add_score(fruit_a.data.score_value)
	var tier: int = fruit_a.data.tier as int
	var merged_velocity := (fruit_a.linear_velocity + fruit_b.linear_velocity) * 0.22 + Vector2(0, -45)

	GameManager.highest_tier_reached = max(GameManager.highest_tier_reached, next_data.tier)
	EventBus.fruit_merged.emit(tier, midpoint, score_gained)
	AudioManager.play_merge_sfx(tier, next_data.merge_sfx, midpoint)

	fruit_a.start_merge_exit()
	fruit_b.start_merge_exit()

	var merged_fruit := Spawner.spawn_at(next_data, midpoint)
	if merged_fruit:
		merged_fruit.linear_velocity = merged_velocity
	return true


static func _release_merge_lock(fruit) -> void:
	if is_instance_valid(fruit):
		fruit.is_merging = false
