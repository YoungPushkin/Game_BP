extends "res://scripts/environment/interactive/interactive_area.gd"

class_name Terminal

@export var door_path: NodePath = NodePath("../door")
@export var required_active_moduletables: int = 0
@export var activation_source_group: StringName = &"moduletable_active"

func can_interact() -> bool:
	return player_here

func _handle_interaction() -> void:
	if not _can_open():
		return

	var door := _find_door()
	if door != null:
		door.open_from_terminal()

func _can_open() -> bool:
	var need := _required_moduletables()
	if need <= 0:
		return true

	var active = get_tree().get_nodes_in_group(_activation_group())
	if active.size() >= need:
		return true

	var root: Node = get_tree().current_scene
	if root == null:
		return false

	return _count_installed_moduletables(root) >= need

func _find_door() -> Door:
	var door := _door_from_path(self, door_path)
	if door != null:
		return door

	var root := get_tree().current_scene
	door = _door_from_path(root, door_path)
	if door != null:
		return door

	if has_meta("target_door_id"):
		var id := str(get_meta("target_door_id"))
		if not id.is_empty():
			return _find_door_by_id(root, id)

	return null

func _required_moduletables() -> int:
	if has_meta("required_active_moduletables"):
		return int(get_meta("required_active_moduletables"))
	return required_active_moduletables

func _activation_group() -> String:
	if has_meta("activation_source_group"):
		return str(get_meta("activation_source_group"))
	var group := str(activation_source_group)
	if group.is_empty():
		return "moduletable_active"
	return group

func _door_from_path(root: Node, path: NodePath) -> Door:
	if root == null:
		return null
	return root.get_node_or_null(path) as Door

func _same_id(node: Node, target_id: String) -> bool:
	if node.name == target_id:
		return true
	if node.has_meta("entity_id") and str(node.get_meta("entity_id")) == target_id:
		return true
	if node.has_meta("door_id") and str(node.get_meta("door_id")) == target_id:
		return true
	return false

func _count_installed_moduletables(node: Node) -> int:
	if node == null:
		return 0

	var count := 0
	var table := node as ModuleTable
	if table != null and table.has_module:
		count = 1

	for child in node.get_children():
		count += _count_installed_moduletables(child)

	return count

func _find_door_by_id(node: Node, target_id: String) -> Door:
	if node == null:
		return null
	if node is Door and _same_id(node, target_id):
		return node as Door
	for child in node.get_children():
		var found := _find_door_by_id(child, target_id)
		if found != null:
			return found
	return null
