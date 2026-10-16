class_name MoveData
extends Resource

@export var id := ""
@export var display_name := ""
@export_enum("normal", "fire", "water", "grass", "electric", "rock") var element := "normal"
@export_enum("damage", "heal", "buff", "debuff") var kind := "damage"
@export var power := 10
@export_range(0.0, 1.0, 0.01) var accuracy := 1.0

