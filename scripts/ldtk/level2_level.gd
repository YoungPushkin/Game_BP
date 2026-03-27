@tool
extends Node

const LADDER_AREA_SCENE := preload("res://scenes/environment/ladder_area.tscn")
const WORLD_COLLISION_NAME := "generated_world_collision"
const WORLD_COLLISION_LAYER := 1 << 0
const WORLD_LAYER_NAME := "Kollizia"
const LADDER_LAYER_NAME := "KolliziaLadder"
const LADDER_CELL_WIDTH := 20.0

func post_import(level: Node2D) -> Node2D:
	var door_nodes: Dictionary = {}
	var terminal_nodes: Array[Terminal] = []

	for child in level.get_children():
		_assign_level_owner(child, level)
		_disable_tile_layer_collision(child)
		_collect_level_nodes(child, door_nodes, terminal_nodes)

	_rebuild_world_collision(level)
	_rebuild_ladder_areas(level)

	for terminal in terminal_nodes:
		if not terminal.has_meta("target_door_id"):
			continue

		var door_name := str(terminal.get_meta("target_door_id"))
		if door_name.is_empty():
			continue
		if not door_nodes.has(door_name):
			continue

		terminal.door_path = level.get_path_to(door_nodes[door_name])

	return level

func _rebuild_world_collision(level: Node2D) -> void:
	_free_node(level.get_node_or_null(WORLD_COLLISION_NAME))

	var layer_data := _find_raw_layer(level, WORLD_LAYER_NAME)
	if layer_data.is_empty():
		return

	var world_body := StaticBody2D.new()
	world_body.name = WORLD_COLLISION_NAME
	world_body.collision_layer = WORLD_COLLISION_LAYER
	world_body.collision_mask = 0
	level.add_child(world_body)
	world_body.owner = level
	_add_world_collision_shapes(world_body, layer_data)

func _add_world_collision_shapes(world_body: StaticBody2D, layer_data: Dictionary) -> void:
	var columns := int(layer_data.get("__cWid", 0))
	var rows := int(layer_data.get("__cHei", 0))
	var grid_size := int(layer_data.get("__gridSize", 0))
	var values: Array = layer_data.get("intGridCsv", [])
	if columns <= 0 or rows <= 0 or grid_size <= 0 or values.is_empty():
		return

	var shape_index := 1
	for y in range(rows):
		var run_start := -1
		for x in range(columns + 1):
			var is_solid := false
			if x < columns:
				var index := y * columns + x
				if index < values.size():
					is_solid = int(values[index]) != 0

			if is_solid and run_start == -1:
				run_start = x
			elif not is_solid and run_start != -1:
				_create_world_shape(world_body, run_start, y, x - run_start, grid_size, shape_index)
				shape_index += 1
				run_start = -1

func _create_world_shape(world_body: StaticBody2D, start_x: int, cell_y: int, run_length: int, grid_size: int, shape_index: int) -> void:
	if run_length <= 0:
		return

	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(run_length * grid_size), float(grid_size))

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D%d" % shape_index
	collision.shape = shape
	collision.position = Vector2(
		float(start_x * grid_size) + float(run_length * grid_size) * 0.5,
		float(cell_y * grid_size) + float(grid_size) * 0.5
	)
	world_body.add_child(collision)
	collision.owner = world_body.owner

func _rebuild_ladder_areas(level: Node2D) -> void:
	_free_node(level.get_node_or_null("ladder_area"))

	var layer_data := _find_raw_layer(level, LADDER_LAYER_NAME)
	if layer_data.is_empty():
		return

	var ladder_area := LADDER_AREA_SCENE.instantiate()
	if ladder_area == null:
		return
	ladder_area.name = "ladder_area"
	level.add_child(ladder_area)
	ladder_area.owner = level
	for child in ladder_area.get_children():
		child.free()

	_add_ladder_collision_shapes(ladder_area, layer_data)

func _add_ladder_collision_shapes(ladder_area: Area2D, layer_data: Dictionary) -> void:
	var columns := int(layer_data.get("__cWid", 0))
	var rows := int(layer_data.get("__cHei", 0))
	var grid_size := int(layer_data.get("__gridSize", 0))
	var values: Array = layer_data.get("intGridCsv", [])
	if columns <= 0 or rows <= 0 or grid_size <= 0 or values.is_empty():
		return

	var run_index := 1
	for x in range(columns):
		var start_y := -1
		for y in range(rows + 1):
			var is_ladder := false
			if y < rows:
				var index := y * columns + x
				if index < values.size():
					is_ladder = int(values[index]) != 0

			if is_ladder and start_y == -1:
				start_y = y
			elif not is_ladder and start_y != -1:
				_create_ladder_shape(ladder_area, x, start_y, y - start_y, grid_size, run_index)
				run_index += 1
				start_y = -1

func _create_ladder_shape(ladder_area: Area2D, cell_x: int, start_y: int, run_length: int, grid_size: int, run_index: int) -> void:
	if run_length <= 0:
		return

	var shape := RectangleShape2D.new()
	shape.size = Vector2(LADDER_CELL_WIDTH, float(run_length * grid_size))

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D%d" % run_index
	collision.shape = shape
	collision.position = Vector2(
		float(cell_x * grid_size) + float(grid_size) * 0.5,
		float(start_y * grid_size) + float(run_length * grid_size) * 0.5
	)
	ladder_area.add_child(collision)
	collision.owner = ladder_area.owner

func _assign_level_owner(node: Node, level: Node) -> void:
	if node.has_meta("LDtk_from_entity_layer"):
		node.owner = level
		return

	for child in node.get_children():
		_assign_level_owner(child, level)

func _disable_tile_layer_collision(node: Node) -> void:
	if node is TileMapLayer:
		(node as TileMapLayer).collision_enabled = false

	for child in node.get_children():
		_disable_tile_layer_collision(child)

func _collect_level_nodes(node: Node, door_nodes: Dictionary, terminal_nodes: Array[Terminal]) -> void:
	if node is Door:
		door_nodes[node.name] = node
	elif node is Terminal:
		terminal_nodes.append(node as Terminal)

	for child in node.get_children():
		_collect_level_nodes(child, door_nodes, terminal_nodes)

func _find_raw_layer(level: Node2D, layer_name: String) -> Dictionary:
	var level_data: Dictionary = level.get_meta("LDtk_raw_data", {})
	if level_data.is_empty():
		return {}

	var layer_instances: Array = level_data.get("layerInstances", [])
	for layer_data in layer_instances:
		if str(layer_data.get("__identifier", "")) == layer_name:
			return layer_data
	return {}

func _free_node(node: Node) -> void:
	if node != null:
		node.free()
