class_name GameModeDefinition
extends Resource

@export var mode: Enums.GameMode = Enums.GameMode.CLASSIC
@export var display_name := "Classic"
@export_multiline var description := "Merge freely and chase your best score."
@export_range(0.0, 600.0, 1.0, "suffix:s") var duration_seconds := 0.0


func is_valid_definition() -> bool:
	return not display_name.is_empty() and duration_seconds >= 0.0
