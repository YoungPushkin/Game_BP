extends Camera2D

const MAX_CONFIG_ATTEMPTS := 20
const STABLE_FRAMES_NEEDED := 2
const BG_NAMES := {"backround": true, "fon": true}

@export var abyss_margin: float = 160.0

var tries: int = 0
var stable_frames: int = 0
var last_bounds_key: String = ""

func _ready() -> void:
	enabled = true
	make_current()
	limit_enabled = true
	set_process(true)

func _process(_delta: float) -> void:
	if tries >= MAX_CONFIG_ATTEMPTS:
		set_process(false)
		return

	var bounds = _get_level_rect(get_tree().current_scene)
	if bounds == null:
		tries += 1
		return

	var bounds_key := "%d:%d:%d:%d" % [
		int(round(bounds.position.x)),
		int(round(bounds.position.y)),
		int(round(bounds.size.x)),
		int(round(bounds.size.y))
	]
	if bounds_key == last_bounds_key:
		stable_frames += 1
	else:
		last_bounds_key = bounds_key
		stable_frames = 0

	_set_limits(bounds)
	tries += 1
	if stable_frames >= STABLE_FRAMES_NEEDED:
		set_process(false)

func _set_limits(bounds: Rect2) -> void:
	var left := int(floor(bounds.position.x))
	var top := int(floor(bounds.position.y))
	var right := int(ceil(bounds.end.x))
	var bottom := int(ceil(bounds.end.y))

	if right < left:
		var center_x := int(round((bounds.position.x + bounds.end.x) * 0.5))
		left = center_x
		right = center_x
	if bottom < top:
		var center_y := int(round((bounds.position.y + bounds.end.y) * 0.5))
		top = center_y
		bottom = center_y

	limit_left = left
	limit_top = top
	limit_right = right
	limit_bottom = bottom
	enabled = true
	make_current()
	_set_fall_limit(float(bounds.end.y) + abyss_margin)

func _set_fall_limit(limit_y: float) -> void:
	var player := get_parent() as Player
	if player != null:
		player.set_fall_limit(limit_y)

func _get_level_rect(root: Node):
	if root == null:
		return null

	var collision_bounds = _get_collision_rect(root)
	var tile_bounds = _get_tilemap_rect(root)
	var sprite_bounds = _get_bg_rect(root)

	if collision_bounds != null:
		if tile_bounds != null:
			return collision_bounds.merge(tile_bounds)
		return collision_bounds
	if tile_bounds != null:
		return tile_bounds
	return sprite_bounds

func _get_tilemap_rect(root: Node):
	var bounds: Rect2
	var has_bounds := false
	var nodes: Array = [root]

	while not nodes.is_empty():
		var node = nodes.pop_back()
		if node is TileMapLayer:
			var used_cells = node.get_used_cells()
			if not used_cells.is_empty():
				var tile_size := Vector2(32.0, 32.0)
				if node.tile_set != null:
					tile_size = Vector2(node.tile_set.tile_size)
				var half_tile := tile_size * 0.5

				for cell in used_cells:
					var cell_pos: Vector2 = node.map_to_local(cell)
					var world_pos: Vector2 = _world_point(node, cell_pos)
					var cell_rect := Rect2(world_pos - half_tile, tile_size)
					if not has_bounds:
						bounds = cell_rect
						has_bounds = true
					else:
						bounds = bounds.merge(cell_rect)

		for child in node.get_children():
			nodes.append(child)

	if not has_bounds:
		return null
	return bounds

func _get_collision_rect(root: Node):
	var world_collision: Node2D = _find_world_collision(root)
	if world_collision == null:
		return null

	var bounds: Rect2
	var has_bounds := false

	for child in world_collision.get_children():
		if child is not CollisionShape2D:
			continue
		var shape_node := child as CollisionShape2D
		if shape_node.shape == null:
			continue
		var rect = _shape_rect(shape_node)
		if rect == null:
			continue
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)

	if not has_bounds:
		return null
	return bounds

func _find_world_collision(root: Node) -> Node2D:
	if root == null:
		return null

	if str(root.name) == "generated_world_collision" and root is Node2D:
		return root as Node2D

	for child in root.get_children():
		var found: Node2D = _find_world_collision(child)
		if found != null:
			return found

	return null

func _shape_rect(shape_node: CollisionShape2D):
	if shape_node == null or shape_node.shape == null:
		return null
	if shape_node.shape is RectangleShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		var size := rect_shape.size
		var global_pos := shape_node.global_position
		return Rect2(global_pos - size * 0.5, size)
	return null

func _get_bg_rect(root: Node):
	var bounds: Rect2
	var has_bounds := false
	var nodes: Array = [root]

	while not nodes.is_empty():
		var node = nodes.pop_back()
		if node is Sprite2D and node.texture != null and BG_NAMES.has(str(node.name).to_lower()):
			var local_rect: Rect2 = node.get_rect()
			var p1: Vector2 = _world_point(node, local_rect.position)
			var p2: Vector2 = _world_point(node, local_rect.position + Vector2(local_rect.size.x, 0.0))
			var p3: Vector2 = _world_point(node, local_rect.position + Vector2(0.0, local_rect.size.y))
			var p4: Vector2 = _world_point(node, local_rect.position + local_rect.size)
			var points := PackedVector2Array([p1, p2, p3, p4])
			var point_rect := Rect2(points[0], Vector2.ZERO)
			for i in range(1, points.size()):
				point_rect = point_rect.expand(points[i])
			if not has_bounds:
				bounds = point_rect
				has_bounds = true
			else:
				bounds = bounds.merge(point_rect)
		for child in node.get_children():
			nodes.append(child)

	if not has_bounds:
		return null
	return bounds

func _world_point(node: Node, local_point: Vector2) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_transform * local_point
	return local_point
