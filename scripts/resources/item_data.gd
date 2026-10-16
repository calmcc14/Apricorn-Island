class_name ItemData
extends Resource

@export var id := ""
@export var display_name := ""
@export var description := ""
@export_enum("heal", "ball", "treasure") var kind := "heal"
@export var amount := 0
@export_range(0.0, 1.0, 0.01) var capture_bonus := 0.0

