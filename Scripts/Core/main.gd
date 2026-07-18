extends Node2D

@export var spawner_scene: PackedScene
@export var pet_scene: PackedScene
@export var merge_burst_scene: PackedScene

@onready var _box_container: Node2D = %BoxContainer
@onready var _box: Box = %Box
@onready var _spawner_container: Node2D = %SpawnerContainer
@onready var _pet_container: Node2D = %PetContainer
@onready var _fruit_container: Node2D = %FruitContainer
@onready var _game_over_panel: Control = %GameOverPanel
@onready var _container_art: Sprite2D = %ContainerArt
@onready var _background: Sprite2D = %Background
@onready var _hud: Control = %HUD
@onready var _juice: GameplayJuice = %GameplayJuice
@onready var _powerups: PowerupController = %PowerupController

var _spawner: Spawner


func _ready() -> void:
	_setup_world()
	_juice.configure(merge_burst_scene, _hud)
	_powerups.configure(_box, _box_container, _container_art, _fruit_container, _juice)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.fruit_merged.connect(_juice.on_fruit_merged)
	_game_over_panel.visible = false
	_apply_equipped_cosmetics()


func _setup_world() -> void:
	if spawner_scene:
		_spawner = spawner_scene.instantiate()
		_spawner_container.add_child(_spawner)
		_spawner.configure(_fruit_container)
	if pet_scene and not EconomyManager.get_equipped_item(&"pet").is_empty():
		_pet_container.add_child(pet_scene.instantiate())


func _apply_equipped_cosmetics() -> void:
	var skin := EconomyManager.get_equipped_item(&"skin")
	match skin:
		&"skin_pastel": _container_art.modulate = Color(1.0, 0.94, 0.66, 1.0)
		&"skin_pineapple": _container_art.modulate = Color(1.0, 0.79, 0.3, 1.0)
		_: _container_art.modulate = Color.WHITE
	_background.visible = EconomyManager.get_equipped_item(&"background") == &"background_garden"


func _on_state_changed(state: Enums.GameState) -> void:
	_game_over_panel.visible = state == Enums.GameState.GAME_OVER


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		SaveManager.save_game()
