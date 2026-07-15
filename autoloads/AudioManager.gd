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
const SFX_POOL_SIZE := 8

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
	var p := AudioStreamPlayer2D.new()
	p.bus = sfx_bus
	p.stream = stream
	p.global_position = position
	p.finished.connect(p.queue_free)
	get_tree().root.add_child(p)
	p.play()
