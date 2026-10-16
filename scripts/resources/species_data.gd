class_name SpeciesData
extends Resource

@export var id := ""
@export var display_name := ""
@export_enum("normal", "fire", "water", "grass", "electric", "rock") var element := "normal"
@export var max_hp := 50
@export var attack := 10
@export var defense := 10
@export var move_ids: Array[String] = []
@export var body_color := Color.WHITE
@export var accent_color := Color.GRAY

