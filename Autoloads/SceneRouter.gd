extends Node

const LOADING_SCENE := "res://Scenes/UI/MainMenu/main_menu.tscn"
const HOME_SCENE := "res://Scenes/UI/Home/home.tscn"
const GAME_SCENE := "res://Scenes/Core/main.tscn"
const SHOP_SCENE := "res://Scenes/UI/Shop/shop.tscn"
const DAILY_REWARD_SCENE := "res://Scenes/UI/DailyReward/daily_reward.tscn"
const SHOP_CATEGORIES: Array[StringName] = [&"pet", &"powerup", &"skin", &"background"]

var _transitioning := false
var _shop_entry_category: StringName = &"pet"


func go_home() -> void:
	_change_to(HOME_SCENE)


func go_game() -> void:
	_change_to(GAME_SCENE)


func go_shop(category: StringName = &"pet") -> void:
	_shop_entry_category = category if category in SHOP_CATEGORIES else &"pet"
	_change_to(SHOP_SCENE)


func take_shop_entry_category() -> StringName:
	var category := _shop_entry_category
	_shop_entry_category = &"pet"
	return category


func go_daily_reward() -> void:
	_change_to(DAILY_REWARD_SCENE)


func _change_to(path: String) -> void:
	if _transitioning or not ResourceLoader.exists(path):
		return
	_transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_transitioning = false
		push_error("Could not change scene to %s: %s" % [path, error_string(error)])
	else:
		_unlock_after_frame.call_deferred()


func _unlock_after_frame() -> void:
	await get_tree().process_frame
	_transitioning = false
