extends Control

const HOME_SCENE := "res://ui/home/home.tscn"
const MINIMUM_DISPLAY_TIME := 1.35
const LOADING_TIPS := [
	"Two matching fruits walk into a box. One bigger fruit walks out.",
	"Gravity is free. Floor space is definitely not.",
	"Cherries are tiny, but their ambitions are watermelon-sized.",
	"If the pile starts wobbling, pretend it is dancing.",
	"A sideways pineapple is just taking a very spiky nap.",
	"Merge responsibly. Watermelons need personal space.",
	"The danger line is not decorative. The fruit wish it were.",
	"When in doubt, blame gravity. It cannot defend itself.",
	"Combos are just fruit having dramatic family reunions.",
	"No fruit were squished permanently during this loading screen.",
]

@onready var _loading_bar: ProgressBar = %LoadingBar
@onready var _loading_label: Label = %LoadingLabel
@onready var _mascot: TextureRect = %Mascot
@onready var _tip_label: Label = %Tip

var _elapsed := 0.0
var _load_started := false
var _transitioning := false

func _ready() -> void:
	_tip_label.text = "Tip: %s" % LOADING_TIPS.pick_random()
	_play_intro()
	var error := ResourceLoader.load_threaded_request(HOME_SCENE)
	_load_started = error == OK
	if not _load_started:
		_loading_label.text = "Opening your cozy kitchen..."
	set_process(true)


func _process(delta: float) -> void:
	if _transitioning:
		return
	_elapsed += delta
	if not _load_started:
		_loading_bar.value = minf(92.0, _loading_bar.value + delta * 45.0)
		if _elapsed >= MINIMUM_DISPLAY_TIME:
			_finish_with_path()
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(HOME_SCENE, progress)
	var actual := 0.0
	if not progress.is_empty():
		actual = float(progress[0]) * 100.0
	var display_target := minf(actual, 92.0) if status != ResourceLoader.THREAD_LOAD_LOADED else 100.0
	_loading_bar.value = move_toward(_loading_bar.value, display_target, delta * 85.0)

	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_load_started = false
		_loading_label.text = "Opening your cozy kitchen..."
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MINIMUM_DISPLAY_TIME and _loading_bar.value >= 99.0:
		_finish_with_resource()


func _play_intro() -> void:
	_mascot.pivot_offset = _mascot.size * 0.5
	_mascot.scale = Vector2(0.82, 0.82)
	_mascot.modulate.a = 0.0
	var intro := create_tween().set_parallel(true)
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_mascot, "scale", Vector2.ONE, 0.55)
	intro.tween_property(_mascot, "modulate:a", 1.0, 0.3)
	await intro.finished
	var bob := create_tween().set_loops()
	bob.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_mascot, "position:y", _mascot.position.y - 8.0, 1.4)
	bob.tween_property(_mascot, "position:y", _mascot.position.y, 1.4)


func _finish_with_resource() -> void:
	_transitioning = true
	_loading_label.text = "Ready!"
	var packed := ResourceLoader.load_threaded_get(HOME_SCENE) as PackedScene
	await _fade_out()
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(HOME_SCENE)


func _finish_with_path() -> void:
	_transitioning = true
	_loading_bar.value = 100.0
	_loading_label.text = "Ready!"
	await _fade_out()
	get_tree().change_scene_to_file(HOME_SCENE)


func _fade_out() -> void:
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	await fade.finished
