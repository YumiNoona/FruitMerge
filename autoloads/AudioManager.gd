extends Node

@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"

var music_vol: float = 0.8:
	set(v):
		music_vol = clampf(v, 0.0, 1.0)
		_apply_music_vol()

var sfx_vol: float = 0.8:
	set(v):
		sfx_vol = clampf(v, 0.0, 1.0)
		_apply_sfx_vol()

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _merge_sfx_cache: Dictionary = {}
const SFX_POOL_SIZE := 8
const PROCEDURAL_SFX_RATE := 44100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_create_music_player()
	_create_sfx_pool()

func _setup_buses() -> void:
	var music_idx := AudioServer.get_bus_index(music_bus)
	if music_idx >= 0:
		_apply_music_vol()

	var sfx_idx := AudioServer.get_bus_index(sfx_bus)
	if sfx_idx >= 0:
		_apply_sfx_vol()

func _apply_music_vol() -> void:
	var idx := AudioServer.get_bus_index(music_bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_vol))

func _apply_sfx_vol() -> void:
	var idx := AudioServer.get_bus_index(sfx_bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_vol))

func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = music_bus
	add_child(_music_player)

func _create_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_pool.append(p)

func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	var p := _sfx_pool[_pool_index]
	_pool_index = wrapi(_pool_index + 1, 0, SFX_POOL_SIZE)
	p.stream = stream
	p.play()

func play_sfx_at(stream: AudioStream, position: Vector2) -> void:
	if not stream:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = sfx_bus
	p.stream = stream
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.ready.connect(p.play, CONNECT_ONE_SHOT)
	get_tree().root.add_child.call_deferred(p)


func play_merge_sfx(tier: int, custom_stream: AudioStream, position: Vector2) -> void:
	var stream := custom_stream
	if not stream:
		if not _merge_sfx_cache.has(tier):
			_merge_sfx_cache[tier] = _build_merge_pop(tier)
		stream = _merge_sfx_cache[tier] as AudioStream
	play_sfx_at(stream, position)


func _build_merge_pop(tier: int) -> AudioStreamWAV:
	var duration := 0.18 + minf(float(tier), 8.0) * 0.006
	var sample_count := int(PROCEDURAL_SFX_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var base_frequency := 360.0 + minf(float(tier), 12.0) * 28.0
	for sample_index in sample_count:
		var time := float(sample_index) / float(PROCEDURAL_SFX_RATE)
		var progress := time / duration
		var envelope := pow(1.0 - progress, 2.2)
		var pitch_sweep := base_frequency * (1.0 + 0.32 * progress)
		var pop := sin(TAU * pitch_sweep * time)
		var sparkle := sin(TAU * pitch_sweep * 2.01 * time) * 0.32
		var transient := sin(TAU * 95.0 * time) * exp(-time * 35.0) * 0.45
		var value := clampf((pop + sparkle) * envelope * 0.5 + transient, -1.0, 1.0)
		pcm.encode_s16(sample_index * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = PROCEDURAL_SFX_RATE
	wav.stereo = false
	wav.data = pcm
	return wav
