extends Node

const MAIN_MENU := preload("res://scenes/levels/mainmenu.tscn")
const PAUSE_MENU_NAME := "pause_menu"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		var scene := get_tree().current_scene
		if scene == null:
			return

		var pause_menu := scene.get_node_or_null(PAUSE_MENU_NAME)
		if pause_menu != null:
			return

		var menu := MAIN_MENU.instantiate() as MainMenu
		if menu == null:
			return

		menu.name = PAUSE_MENU_NAME
		scene.add_child(menu)
		menu.show_as_pause_menu()
		get_tree().paused = true

func _setup_door(root: Node, door_name: String, door_id: String, scene_path: String, fade_time: float = 0.45) -> void:
	if scene_path.is_empty():
		return
	var exit_door := _find_door(root, door_name, door_id)
	if exit_door == null:
		return
	exit_door.next_scene_path = scene_path
	exit_door.fade_duration = fade_time

func _find_door(root: Node, wanted_name: String, target_id: String) -> Door:
	if root == null:
		return null
	if root is Door:
		var door := root as Door
		if not wanted_name.is_empty() and door.name == wanted_name:
			return door
		if not target_id.is_empty():
			if door.has_meta("door_id") and str(door.get_meta("door_id")) == target_id:
				return door
			if door.has_meta("entity_id") and str(door.get_meta("entity_id")) == target_id:
				return door
	for child in root.get_children():
		var found := _find_door(child, wanted_name, target_id)
		if found != null:
			return found
	return null
