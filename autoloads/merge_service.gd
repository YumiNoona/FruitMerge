class_name MergeService
extends RefCounted

const FruitFactoryScript = preload("res://Scripts/Entities/Fruit/fruit_factory.gd")
const MERGE_CONVERGE_DURATION: float = 0.075

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
	var midpoint: Vector2 = (fruit_a.global_position + fruit_b.global_position) / 2.0
	var merged_velocity := (fruit_a.linear_velocity + fruit_b.linear_velocity) * 0.22 + Vector2(0, -45)
	fruit_a.linear_velocity *= 0.2
	fruit_b.linear_velocity *= 0.2
	fruit_a.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).tween_property(fruit_a, "global_position", midpoint, MERGE_CONVERGE_DURATION)
	fruit_b.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).tween_property(fruit_b, "global_position", midpoint, MERGE_CONVERGE_DURATION)

	fruit_a.set_emotion(Enums.FruitEmotion.EXCITED)
	fruit_b.set_emotion(Enums.FruitEmotion.EXCITED)

	var tree := fruit_a.get_tree()
	await tree.create_timer(MERGE_CONVERGE_DURATION).timeout

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

	var score_gained: int = GameManager.add_score(fruit_a.data.score_value)
	var tier: int = fruit_a.data.tier as int

	GameManager.record_merge(next_data.tier)
	EventBus.fruit_merged.emit(tier, midpoint, score_gained)
	AudioManager.play_merge_sfx(tier, next_data.merge_sfx, midpoint)

	fruit_a.start_merge_exit()
	fruit_b.start_merge_exit()

	var merged_fruit: Fruit = FruitFactoryScript.create(next_data, midpoint, fruit_a.get_parent())
	if merged_fruit:
		merged_fruit.linear_velocity = merged_velocity
	return true


static func _release_merge_lock(fruit) -> void:
	if is_instance_valid(fruit):
		fruit.is_merging = false
