extends Control

@export var icon: Texture2D
@export var amount: int = 0:
	set(v):
		amount = v
		if _label:
			_label.text = str(v)

var _label: Label
var _icon_rect: TextureRect


func _ready() -> void:
	_label = %Label
	_icon_rect = %IconRect
	if _label:
		_label.text = str(amount)
	if _icon_rect and icon:
		_icon_rect.texture = icon
