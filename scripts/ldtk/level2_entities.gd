@tool
extends Node

const ENTITY_SCENE_PATHS = {
	"Player": "res://scenes/player/player.tscn",
	"Closet": "res://scenes/environment/locker.tscn",
	"Modules": "res://scenes/environment/module_pickup.tscn",
	"Saw": "res://scenes/traps/saw.tscn",
	"Premodules": "res://scenes/environment/moduletable.tscn",
	"Door": "res://scenes/environment/door.tscn",
	"Hammer": "res://scenes/traps/hammer.tscn",
	"Terminal": "res://scenes/environment/terminal.tscn",
	"Robot": "res://scenes/enemies/robot.tscn",
	"Sky": "res://scenes/enemies/sky.tscn",
	"Woolf": "res://scenes/enemies/wolf.tscn",
}

const ENTITY_FIELDS = {
	"Player": ["max_health", "run_speed", "walk_speed", "jump_velocity", "ladder_speed"],
	"Robot": ["detect_diameter", "lose_radius"],
	"Sky": ["max_health", "contact_damage", "detect_radius", "lose_radius"],
	"Woolf": ["max_health", "run_speed", "attack_range", "attack_vertical_tolerance", "attack_cooldown", "attack_hit_frame", "attack_anim_fps"],
	"Terminal": ["required_active_moduletables"],
	"Door": ["door_id"],
	"Modules": ["module_type", "inventory_add_count", "feeds_group"],
	"Premodules": ["animation_start_delay", "consumes_inventory_module", "activates_group", "feeds_terminal_group"],
	"Hammer": ["damage", "hit_cooldown", "start_phase", "cycle_speed", "anim_name", "active_frame_from", "active_frame_to", "frame_y_offsets", "frame_y_scales"],
	"Saw": ["damage", "hit_cooldown", "move_speed", "detect_distance", "ray_length", "edge_wait_time", "patrol_left_offset", "patrol_right_offset", "use_patrol_limits", "auto_detect_limits", "frame_step_pixels", "run_anim", "stop_anim", "wall_collision_mask", "wall_margin"],
}

const LEVEL_3_SCENE_PATH = "res://scenes/levels/level_3.tscn"

func post_import(entity_layer):
	var entity_list = entity_layer.get_meta("LDtk_entity_instances", [])
	var name_counts = {}

	for entity_data in entity_list:
		var identifier = str(entity_data.get("identifier", ""))
		var instance = _make_instance(identifier)
		if instance == null:
			continue

		var fields = entity_data.get("fields", {})
		instance.name = _entity_name(identifier, fields, name_counts)
		instance.position = _entity_position(entity_data)
		instance.set_meta("LDtk_entity_data", entity_data)
		instance.set_meta("LDtk_from_entity_layer", true)
		instance.set_meta("LDtk_layer_name", str(entity_layer.name))
		_apply_special_setup(instance, identifier, fields)
		_apply_fields(instance, identifier, fields)
		entity_layer.add_child(instance)
		instance.owner = entity_layer

	return entity_layer

func _make_instance(identifier):
	if not ENTITY_SCENE_PATHS.has(identifier):
		return null

	var path = str(ENTITY_SCENE_PATHS[identifier])
	var scene = load(path)
	if scene == null:
		push_warning("Failed to load entity scene: " + path)
		return null

	return scene.instantiate()

func _entity_name(identifier, fields, name_counts):
	if identifier == "Door" and fields.has("door_id"):
		return str(fields["door_id"])

	if identifier == "Terminal" and fields.has("terminal_id"):
		return str(fields["terminal_id"])

	var count = int(name_counts.get(identifier, 0)) + 1
	name_counts[identifier] = count
	if count == 1:
		return identifier

	return "%s%d" % [identifier, count]

func _entity_position(entity_data):
	var width = float(entity_data.get("width", 0.0))
	var height = float(entity_data.get("height", 0.0))
	var size = Vector2(width, height)
	var pivot_data = entity_data.get("pivot", [0.0, 0.0])
	var pos_data = entity_data.get("px", [0.0, 0.0])
	var pivot = Vector2(float(pivot_data[0]), float(pivot_data[1]))
	var pos = Vector2(float(pos_data[0]), float(pos_data[1]))
	return pos + size * 0.5 - size * pivot

func _apply_special_setup(instance, identifier, fields):
	if identifier != "Door":
		return
	if not fields.has("door_id"):
		return
	if str(fields["door_id"]) != "door_right":
		return

	instance.set("next_scene_path", LEVEL_3_SCENE_PATH)
	instance.set("fade_duration", 0.45)

func _apply_fields(instance, identifier, fields):
	var entity_id = fields.get("terminal_id", fields.get("door_id", null))
	if entity_id != null:
		instance.set_meta("entity_id", entity_id)

	if fields.has("target_door_id"):
		var target_door_id = fields["target_door_id"]
		instance.set_meta("target_door_id", target_door_id)
		instance.set_meta("target_id", target_door_id)

	if fields.has("max_hp") and (identifier == "Robot" or identifier == "Woolf"):
		instance.set("max_health", fields["max_hp"])

	var names = ENTITY_FIELDS.get(identifier, [])
	for field_name in names:
		if fields.has(field_name):
			instance.set(field_name, fields[field_name])
