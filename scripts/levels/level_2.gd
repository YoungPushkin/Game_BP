extends "res://scripts/levels/level_navigation.gd"

const LEVEL_3_SCENE_PATH := "res://scenes/levels/level_3.tscn"

func _ready() -> void:
	call_deferred("_setup_door", self, "door_right", "door_right", LEVEL_3_SCENE_PATH)
