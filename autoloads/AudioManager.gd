extends Node

const MUSIC_TRACK_SOURCES: Array[AudioStream] = [
	preload("res://Audio/Music/Main Menu.wav"),
	preload("res://Audio/Music/Gameplay.wav"),
	preload("res://Audio/Music/Shop.wav"),
	preload("res://Audio/Music/Achievements.wav"),
]
const SFX_POOL_SIZE := 8
const SPATIAL_SFX_POOL_SIZE := 12
const PROCEDURAL_SFX_RATE := 44100

@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"
@export_category("Music playlist")
@export_range(0.1, 5.0, 0.05) var music_fade_in_duration: float = 1.25
@export_range(0.25, 8.0, 0.05) var music_crossfade_duration: float = 2.0
@export_range(-60.0, -12.0, 1.0) var music_silent_db: float = -36.0

var music_vol: float = 0.8:
	set(v):
		music_vol = clampf(v, 0.0, 1.0)
		_apply_music_vol()

var sfx_vol: float = 0.8:
	set(v):
		sfx_vol = clampf(v, 0.0, 1.0)
		_apply_sfx_vol()

var _music_players: Array[AudioStreamPlayer] = []
var _music_tracks: Array[AudioStream] = []
var _shuffled_track_indices: Array[int] = []
var _music_tween: Tween
var _active_music_player_index: int = 0
var _last_track_index: int = -1
var _playlist_started: bool = false
var _music_transitioning: bool = false
var _sfx_pool: Array[AudioStreamPlayer] = []
var _spatial_sfx_pool: Array[AudioStreamPlayer2D] = []
var _pool_index: int = 0
var _spatial_pool_index: int = 0
var _merge_sfx_cache: Dictionary = {}
var _impact_sfx_cache: Dictionary = {}
var _last_impact_sfx_msec := -1000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_prepare_music_tracks()
	_create_music_players()
	_create_sfx_pool()
	_create_spatial_sfx_pool()


func _process(_delta: float) -> void:
	if not _playlist_started or _music_transitioning or _music_players.is_empty():
		return
	var active_player := _music_players[_active_music_player_index]
	if not active_player.playing:
		_music_transitioning = true
		_start_next_after_finished.call_deferred()
		return
	var track_length := active_player.stream.get_length() if active_player.stream else 0.0
	if track_length <= music_crossfade_duration:
		return
	var remaining := track_length - active_player.get_playback_position()
	if remaining <= music_crossfade_duration:
		_crossfade_to_next()


func _exit_tree() -> void:
	_playlist_started = false
	_music_transitioning = false
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
	_music_tracks.clear()
	_shuffled_track_indices.clear()
	for player in _sfx_pool:
		player.stop()
		player.stream = null
	for player in _spatial_sfx_pool:
		player.stop()
		player.stream = null
	_merge_sfx_cache.clear()
	_impact_sfx_cache.clear()

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

func _prepare_music_tracks() -> void:
	_music_tracks.clear()
	for source in MUSIC_TRACK_SOURCES:
		var track := source.duplicate(true) as AudioStream
		if track is AudioStreamWAV:
			(track as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_music_tracks.append(track)


func _create_music_players() -> void:
	for player_index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (player_index + 1)
		player.bus = music_bus
		player.volume_db = music_silent_db
		player.finished.connect(_on_music_player_finished.bind(player))
		add_child(player)
		_music_players.append(player)

func _create_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		add_child(p)
		_sfx_pool.append(p)


func _create_spatial_sfx_pool() -> void:
	for _index in SPATIAL_SFX_POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = sfx_bus
		add_child(player)
		_spatial_sfx_pool.append(player)

func start_music_playlist() -> void:
	if _playlist_started:
		return
	if _music_tracks.is_empty() or _music_players.is_empty():
		push_warning("Music playlist has no playable tracks")
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.stream = null
		player.volume_db = music_silent_db
	_playlist_started = true
	_music_transitioning = true
	_active_music_player_index = 0
	var first_player := _music_players[_active_music_player_index]
	first_player.stream = _take_next_music_track()
	first_player.play()
	_music_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(first_player, "volume_db", 0.0, music_fade_in_duration)
	_music_tween.finished.connect(func(): _music_transitioning = false)


func stop_music(fade_duration: float = 0.6) -> void:
	_playlist_started = false
	_music_transitioning = true
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for player in _music_players:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", music_silent_db, maxf(fade_duration, 0.01))
	_music_tween.finished.connect(func():
		for player in _music_players:
			player.stop()
			player.stream = null
		_music_transitioning = false
	)


func _crossfade_to_next() -> void:
	if _music_transitioning:
		return
	_music_transitioning = true
	var outgoing_player := _music_players[_active_music_player_index]
	var incoming_index := 1 - _active_music_player_index
	var incoming_player := _music_players[incoming_index]
	incoming_player.stop()
	incoming_player.stream = _take_next_music_track()
	incoming_player.volume_db = music_silent_db
	incoming_player.play()
	_active_music_player_index = incoming_index
	_music_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(outgoing_player, "volume_db", music_silent_db, music_crossfade_duration)
	_music_tween.tween_property(incoming_player, "volume_db", 0.0, music_crossfade_duration)
	_music_tween.finished.connect(func():
		outgoing_player.stop()
		outgoing_player.stream = null
		_music_transitioning = false
	)


func _on_music_player_finished(player: AudioStreamPlayer) -> void:
	if not _playlist_started or _music_transitioning:
		return
	if player != _music_players[_active_music_player_index]:
		return
	_music_transitioning = true
	_start_next_after_finished.call_deferred()


func _start_next_after_finished() -> void:
	if not _playlist_started:
		_music_transitioning = false
		return
	var incoming_index := 1 - _active_music_player_index
	var incoming_player := _music_players[incoming_index]
	incoming_player.stop()
	incoming_player.stream = _take_next_music_track()
	incoming_player.volume_db = music_silent_db
	incoming_player.play()
	_active_music_player_index = incoming_index
	_music_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_property(incoming_player, "volume_db", 0.0, music_fade_in_duration)
	_music_tween.finished.connect(func(): _music_transitioning = false)


func _take_next_music_track() -> AudioStream:
	if _shuffled_track_indices.is_empty():
		_refill_shuffled_track_indices()
	var next_index: int = _shuffled_track_indices.pop_front()
	_last_track_index = next_index
	return _music_tracks[next_index]


func _refill_shuffled_track_indices() -> void:
	_shuffled_track_indices.clear()
	for track_index in _music_tracks.size():
		_shuffled_track_indices.append(track_index)
	_shuffled_track_indices.shuffle()
	if _shuffled_track_indices.size() > 1 and _shuffled_track_indices[0] == _last_track_index:
		var swap_index := randi_range(1, _shuffled_track_indices.size() - 1)
		var repeated_index := _shuffled_track_indices[0]
		_shuffled_track_indices[0] = _shuffled_track_indices[swap_index]
		_shuffled_track_indices[swap_index] = repeated_index


func get_music_track_count() -> int:
	return _music_tracks.size()


func are_music_tracks_one_shot() -> bool:
	for track in _music_tracks:
		if track is AudioStreamWAV and (track as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
			return false
	return true

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
	var player := _spatial_sfx_pool[_spatial_pool_index]
	_spatial_pool_index = wrapi(_spatial_pool_index + 1, 0, _spatial_sfx_pool.size())
	player.stream = stream
	player.global_position = position
	player.play()


func play_merge_sfx(tier: int, custom_stream: AudioStream, position: Vector2) -> void:
	var stream := custom_stream
	if not stream:
		if not _merge_sfx_cache.has(tier):
			_merge_sfx_cache[tier] = _build_merge_pop(tier)
		stream = _merge_sfx_cache[tier] as AudioStream
	play_sfx_at(stream, position)


func play_fruit_impact(relative_speed: float, tier: int, position: Vector2) -> void:
	if relative_speed < Fruit.DEFAULT_IMPACT_MIN_SPEED:
		return
	var now := Time.get_ticks_msec()
	if now - _last_impact_sfx_msec < 45:
		return
	_last_impact_sfx_msec = now
	var bucket := clampi(floori((relative_speed - Fruit.DEFAULT_IMPACT_MIN_SPEED) / 145.0), 0, 2)
	var pitch_group := clampi(floori(float(tier) / 4.0), 0, 3)
	var cache_key := "%d:%d" % [bucket, pitch_group]
	if not _impact_sfx_cache.has(cache_key):
		_impact_sfx_cache[cache_key] = _build_impact_plop(bucket, pitch_group * 4)
	play_sfx_at(_impact_sfx_cache[cache_key] as AudioStream, position)


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


func _build_impact_plop(bucket: int, tier: int) -> AudioStreamWAV:
	var duration := 0.075 + float(bucket) * 0.012
	var sample_count := int(PROCEDURAL_SFX_RATE * duration)
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var base_frequency := clampf(175.0 - float(tier) * 3.5 - float(bucket) * 16.0, 92.0, 180.0)
	var amplitude := 0.10 + float(bucket) * 0.035
	for sample_index in sample_count:
		var time := float(sample_index) / float(PROCEDURAL_SFX_RATE)
		var progress := time / duration
		var envelope := pow(1.0 - progress, 2.8)
		var pitch := base_frequency * lerpf(1.08, 0.72, progress)
		var body := sin(TAU * pitch * time)
		var soft_click := sin(TAU * pitch * 2.7 * time) * exp(-time * 48.0) * 0.20
		var value := clampf((body + soft_click) * envelope * amplitude, -1.0, 1.0)
		pcm.encode_s16(sample_index * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = PROCEDURAL_SFX_RATE
	wav.stereo = false
	wav.data = pcm
	return wav
