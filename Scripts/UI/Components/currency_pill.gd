extends Control

const CurrencyFormatterScript = preload("res://Scripts/UI/Components/currency_formatter.gd")

@export var icon: Texture2D
@export var amount: int = 0:
	set(v):
		amount = v
		if _label:
			_refresh_amount()

var _label: Label
var _icon_rect: TextureRect


func _ready() -> void:
	_label = %Label
	_icon_rect = %IconRect
	if _label:
		_refresh_amount()
	if _icon_rect and icon:
		_icon_rect.texture = icon


func _refresh_amount() -> void:
	_label.text = CurrencyFormatterScript.format_amount(amount)
	_label.tooltip_text = "%d" % amount
