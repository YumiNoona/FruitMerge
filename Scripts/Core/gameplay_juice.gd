class_name GameplayJuice
extends Node2D

const PARTICLE_POOL_SIZE := 8
const HIGH_TIER_TICKET_REWARDS := {
	Enums.FruitTier.PINEAPPLE: 1,
	Enums.FruitTier.DRAGONFRUIT: 2,
	Enums.FruitTier.WATERMELON: 3,
}

var merge_burst_scene: PackedScene
var hud: Control
var _particle_pool: Array[GPUParticles2D] = []
var _pool_index := 0
var _camera_shake_tween: Tween
var _camera_shake_camera: Camera2D
var _camera_shake_origin := Vector2.ZERO


func configure(burst_scene: PackedScene, hud_control: Control) -> void:
	merge_burst_scene = burst_scene
	hud = hud_control
	if _particle_pool.is_empty():
		_setup_particle_pool()


func on_fruit_merged(tier: int, world_position: Vector2, _score: int) -> void:
	spawn_burst(tier, world_position)
	spawn_particles(world_position, tier)
	HapticManager.merge_for_tier(tier)
	if tier >= Enums.FruitTier.ORANGE:
		apply_screen_shake(tier)
	award_high_tier_ticket(tier + 1)


func powerup_feedback(tier: int, world_position: Vector2, shake := 0.45) -> void:
	spawn_burst(tier, world_position)
	spawn_particles(world_position, tier, Color(0.45, 0.9, 1.0, 1.0))
	apply_screen_shake(tier, shake, 0.85)
	HapticManager.pulse(HapticManager.Feedback.POWERUP)


func spawn_burst(tier: int, world_position: Vector2) -> void:
	if not merge_burst_scene:
		return
	var burst := merge_burst_scene.instantiate() as Node2D
	if not burst:
		return
	burst.global_position = world_position
	if burst.has_method("configure"):
		burst.configure(tier)
	add_child(burst)


func spawn_particles(world_position: Vector2, tier := 0, tint := Color.WHITE) -> void:
	if _particle_pool.is_empty():
		return
	var particles := _particle_pool[_pool_index]
	_pool_index = wrapi(_pool_index + 1, 0, _particle_pool.size())
	particles.global_position = world_position
	particles.modulate = tint if tint != Color.WHITE else Color.from_hsv(fmod(0.08 + float(tier) * 0.04, 1.0), 0.4, 1.0)
	particles.visible = true
	particles.emitting = true
	particles.restart()


func award_high_tier_ticket(created_tier: int) -> void:
	if not HIGH_TIER_TICKET_REWARDS.has(created_tier):
		return
	var ticket_amount: int = HIGH_TIER_TICKET_REWARDS[created_tier]
	EconomyManager.add_tickets(ticket_amount)
	SaveManager.request_save()
	HapticManager.pulse(HapticManager.Feedback.REWARD)
	if hud and hud.has_method("show_tier_ticket_reward"):
		hud.show_tier_ticket_reward(created_tier, ticket_amount)


func apply_screen_shake(tier: int, intensity := 1.0, duration_scale := 1.0) -> void:
	if bool(SaveManager.get_setting("reduced_motion", false)):
		return
	intensity *= clampf(float(SaveManager.get_setting("screen_shake_strength", 1.0)), 0.0, 1.5)
	if intensity <= 0.01:
		return
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	if _camera_shake_tween and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()
	if is_instance_valid(_camera_shake_camera):
		_camera_shake_camera.position = _camera_shake_origin
	_camera_shake_camera = camera
	_camera_shake_origin = camera.position
	var ratio := clampf(float(tier - Enums.FruitTier.ORANGE) / 7.0, 0.0, 1.0)
	var strength := lerpf(2.0, 7.0, ratio) * intensity
	var shake_count := maxi(4, roundi(8.0 * duration_scale))
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_shake_tween = tween
	for index in shake_count:
		var falloff := 1.0 - float(index) / float(shake_count + 2)
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * falloff
		tween.tween_property(camera, "position", _camera_shake_origin + offset, 0.038 * duration_scale)
	tween.tween_property(camera, "position", _camera_shake_origin, 0.08 * duration_scale)
	tween.finished.connect(func():
		if is_instance_valid(camera):
			camera.position = _camera_shake_origin
	)


func _setup_particle_pool() -> void:
	for _index in PARTICLE_POOL_SIZE:
		var particles := GPUParticles2D.new()
		particles.one_shot = true
		particles.amount = 18
		particles.lifetime = 0.58
		particles.explosiveness = 1.0
		particles.process_material = _create_particle_material()
		particles.emitting = false
		particles.visible = false
		add_child(particles)
		_particle_pool.append(particles)


func _create_particle_material() -> ParticleProcessMaterial:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.gravity = Vector3(0, 220, 0)
	particle_material.initial_velocity_min = 95.0
	particle_material.initial_velocity_max = 210.0
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 105.0
	particle_material.scale_min = 2.0
	particle_material.scale_max = 6.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.98, 0.55, 1))
	gradient.set_color(1, Color(1, 0.45, 0.05, 0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	particle_material.color_ramp = texture
	return particle_material
