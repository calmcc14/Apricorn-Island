class_name MapNodeData
extends Resource

@export var id := ""
@export var display_name := ""
@export_enum("start", "battle", "boss", "chest", "camp", "mystery", "finish") var kind := "battle"
@export var map_position := Vector2.ZERO
@export var linked_node_ids: Array[String] = []
@export var prerequisite_node_ids: Array[String] = []
@export var encounter_id := ""

