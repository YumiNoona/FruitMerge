class_name PetAbilityController
extends Node

var pet: Pet
var box: Box
var spawner: Spawner
var fruit_container: Node
var juice: GameplayJuice
var ability: PetAbilityData

var _charge := 0
var _uses := 0
var _drop_count := 0
var _combo_rewarded := false
var _match_nudge_armed := false
var _gameplay_enabled := false


func configure(
		game_pet: Pet,
		game_box: Box,
		game_spawner: Spawner,
		fruits: Node,
		feedback: GameplayJuice
) -> void:
	pet = game_pet
	box = game_box
	spawner = game_spawner
	fruit_container = fruits
	juice = feedback
	var equipped_pet := EconomyManager.get_equipped_item(&"pet")
	ability = PetAbilityCatalog.get_ability(equipped_pet)
	_gameplay_enabled = ability != null and GameManager.current_mode != Enums.GameMode.MISSIONS
	if not is_instance_valid(pet):
		return
	pet.configure_ability(ability, _gameplay_enabled)
	pet.ability_pressed.connect(_on_pet_pressed)
	if not _gameplay_enabled:
		return
	EventBus.fruit_merged.connect(_on_fruit_merged)
	EventBus.fruit_spawned.connect(_on_fruit_spawned)
	EventBus.danger_line_entered.connect(_on_danger_entered)
	EventBus.state_changed.connect(_on_state_changed)
	_apply_passive_setup()
	_sync_charge()


func _apply_passive_setup() -> void:
	match ability.effect:
		PetAbilityData.Effect.FUTURE_SIGHT:
			if is_instance_valid(spawner):
				spawner.set_second_preview_enabled(true)
			pet.show_ability_status(ability.ability_name, 1.8)
		PetAbilityData.Effect.ENCORE:
			GameManager.combo_window_bonus = ability.effect_value
			pet.show_ability_status(ability.ability_name, 1.8)


func _on_fruit_merged(_tier: int, _world_position: Vector2, _score: int) -> void:
	if not _gameplay_enabled:
		return
	if ability.activation == PetAbilityData.Activation.CHARGED_TAP and _uses_available():
		var previous_charge := _charge
		_charge = mini(ability.charge_required, _charge + 1)
		_sync_charge()
		if previous_charge < ability.charge_required and _charge == ability.charge_required:
			pet.play_ready_animation()
	if ability.effect == PetAbilityData.Effect.COIN_CACHE:
		_update_coin_cache()


func _update_coin_cache() -> void:
	if GameManager.active_combo <= 1:
		_combo_rewarded = false
		return
	if GameManager.active_combo < ability.interval or _combo_rewarded or not _uses_available():
		return
	_combo_rewarded = true
	_uses += 1
	EconomyManager.add_coins(1)
	SaveManager.request_save()
	_activate_feedback("+1 COIN")


func _on_fruit_spawned(fruit: Fruit) -> void:
	if not _gameplay_enabled or not is_instance_valid(fruit):
		return
	if ability.effect == PetAbilityData.Effect.GENTLE_LANDING:
		_drop_count += 1
		if _drop_count % ability.interval == 0:
			fruit.apply_gentle_landing(ability.effect_duration, ability.effect_value)
			_activate_feedback(ability.ability_name)
	elif ability.effect == PetAbilityData.Effect.MATCH_POUNCE and _match_nudge_armed:
		_match_nudge_armed = false
		_apply_match_nudge(fruit)


func _apply_match_nudge(fruit: Fruit) -> void:
	await get_tree().create_timer(maxf(ability.effect_duration, 0.25)).timeout
	if not is_instance_valid(fruit) or fruit.is_merging or not fruit.is_inside_tree():
		return
	var target := _nearest_matching_fruit(fruit.data.tier, fruit)
	if not is_instance_valid(target):
		pet.show_ability_status("NO MATCH", 1.1)
		return
	var direction := (target.global_position - fruit.global_position).normalized()
	if direction == Vector2.ZERO:
		return
	fruit.sleeping = false
	fruit.apply_central_impulse(Vector2(direction.x, clampf(direction.y, -0.05, 0.18)) * ability.effect_value * fruit.mass)
	fruit.angular_velocity += direction.x * 1.4
	_activate_feedback(ability.ability_name)


func _on_danger_entered() -> void:
	if not _gameplay_enabled or not _uses_available():
		return
	match ability.effect:
		PetAbilityData.Effect.SAFETY_BARK:
			_uses += 1
			if is_instance_valid(box):
				box.grant_danger_grace(ability.effect_duration)
			_activate_feedback(ability.ability_name)
		PetAbilityData.Effect.SAFE_LANE:
			_uses += 1
			if is_instance_valid(spawner):
				spawner.show_safe_lane_hint(ability.effect_duration)
			_activate_feedback(ability.ability_name)


func _on_pet_pressed() -> void:
	if not _gameplay_enabled or not ability:
		return
	if not GameManager.can_accept_gameplay_input() or GameManager.is_powerup_targeting:
		return
	HapticManager.pulse(HapticManager.Feedback.TAP)
	if ability.activation != PetAbilityData.Activation.CHARGED_TAP:
		pet.show_ability_status("ALL DONE" if not _uses_available() else ability.ability_name, 1.25)
		return
	if not _uses_available():
		pet.show_ability_status("ALL DONE", 1.1)
		return
	if _charge < ability.charge_required:
		pet.show_ability_status("%d / %d MERGES" % [_charge, ability.charge_required], 1.1)
		return
	match ability.effect:
		PetAbilityData.Effect.MATCH_POUNCE:
			if not is_instance_valid(spawner) or not _has_matching_fruit(spawner.get_current_tier()):
				pet.show_ability_status("NO MATCH YET", 1.1)
				return
			_match_nudge_armed = true
			_consume_charged_use("NEXT DROP")
		PetAbilityData.Effect.COZY_HUG:
			_apply_cozy_hug()
			_consume_charged_use(ability.ability_name)
		PetAbilityData.Effect.LUCKY_HOP:
			if is_instance_valid(spawner) and spawner.reroll_next_fruit():
				_consume_charged_use(ability.ability_name)


func _apply_cozy_hug() -> void:
	for fruit in _active_fruits():
		fruit.apply_temporary_calm(ability.effect_duration, ability.effect_value)


func _consume_charged_use(callout: String) -> void:
	_charge = 0
	_uses += 1
	_sync_charge()
	_activate_feedback(callout)


func _activate_feedback(callout: String) -> void:
	if is_instance_valid(pet):
		pet.play_ability(callout)
		AudioManager.play_pet_ability_sfx(pet.global_position)
		if is_instance_valid(juice):
			juice.spawn_particles(pet.global_position, Enums.FruitTier.LEMON, ability.accent_color)
	HapticManager.pulse(HapticManager.Feedback.POWERUP)
	EventBus.pet_ability_activated.emit(ability.pet_id, ability.ability_name)


func _sync_charge() -> void:
	if not is_instance_valid(pet) or not ability:
		return
	var ability_ready := ability.activation == PetAbilityData.Activation.CHARGED_TAP \
		and _charge >= ability.charge_required and _uses_available()
	var ratio := float(_charge) / float(maxi(ability.charge_required, 1))
	pet.set_ability_charge(ratio, ability_ready, _uses_available())
	EventBus.pet_ability_charge_changed.emit(ability.pet_id, _charge, ability.charge_required)


func _uses_available() -> bool:
	return ability != null and (ability.max_uses_per_run <= 0 or _uses < ability.max_uses_per_run)


func _has_matching_fruit(tier: int) -> bool:
	return is_instance_valid(_nearest_matching_fruit(tier))


func _nearest_matching_fruit(tier: int, ignored: Fruit = null) -> Fruit:
	var nearest: Fruit
	var nearest_distance := INF
	var origin := ignored.global_position if is_instance_valid(ignored) else (spawner.global_position if is_instance_valid(spawner) else Vector2.ZERO)
	for fruit in _active_fruits():
		if fruit == ignored or not fruit.data or fruit.data.tier != tier:
			continue
		var distance := origin.distance_squared_to(fruit.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = fruit
	return nearest


func _active_fruits() -> Array[Fruit]:
	var fruits: Array[Fruit] = []
	var candidates := fruit_container.get_children() if is_instance_valid(fruit_container) else get_tree().get_nodes_in_group("fruits")
	for node in candidates:
		if node is Fruit and is_instance_valid(node) and node.is_inside_tree() and not node.is_merging:
			fruits.append(node as Fruit)
	return fruits


func _on_state_changed(state: Enums.GameState) -> void:
	if state != Enums.GameState.PLAYING:
		_match_nudge_armed = false
