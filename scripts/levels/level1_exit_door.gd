extends "res://scripts/environment/door.gd"

@export_file("*.tscn") var default_next_scene_path: String = "res://scenes/levels/level_2.tscn"

func _ready() -> void:
	if next_scene_path.is_empty():
		next_scene_path = default_next_scene_path
	super._ready()
