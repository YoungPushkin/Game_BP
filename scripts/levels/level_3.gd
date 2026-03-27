extends "res://scripts/levels/level_navigation.gd"

const MAIN_MENU_SCENE_PATH := "res://scenes/levels/mainmenu.tscn"

func _ready() -> void:
	call_deferred("_setup_door", self, "door_right2", "door_right", MAIN_MENU_SCENE_PATH)
