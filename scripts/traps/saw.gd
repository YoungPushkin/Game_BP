extends Area2D

class_name SawTrap

const PLAYER_COLLISION_LAYER := 1 << 1

@export var damage: int = 1
@export var hit_cooldown: float = 0.4
@export var move_speed: float = 80.0
@export var run_anim: String = "run"
@export var stop_anim: String = "stop"
@export var frame_step_pixels: float = 8.0

@export var use_patrol_limits: bool = false
@export var auto_detect_limits: bool = true
@export var detect_distance: float = 1200.0
@export var patrol_left_offset: float = -180.0
@export var patrol_right_offset: float = 180.0

@export var wall_collision_mask: int = 1
@export var wall_margin: float = 0.0
@export var ray_length: float = 30.0
@export var edge_wait_time: float = 0.12

var dir: int = 1
var last_hit: Dictionary = {}
var patrol_left_x: float = 0.0
var patrol_right_x: float = 0.0
var local_x_min: float = 0.0
var local_x_max: float = 0.0
var is_waiting_at_edge: bool = false
var wait_left: float = 0.0
var frame_accum: float = 0.0
var move_frame_index: int = 0
var last_move_dir: int = 1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_shape: CollisionShape2D = $CollisionShape2D

const STOP_FRAME: int = 0
const RUN_FRAMES_RIGHT: Array[int] = [0, 1, 2, 3]
const RUN_FRAMES_LEFT: Array[int] = [3, 2, 1, 0]

func _ready() -> void:
	add_to_group("trap")
	collision_mask |= PLAYER_COLLISION_LAYER
	body_entered.connect(_on_body_entered)
	_compute_local_x_extents()
	_setup_limits()
	_init_manual_animation()

func _physics_process(delta: float) -> void:
	if is_waiting_at_edge:
		wait_left -= delta
		_set_edge_frame()
		if wait_left <= 0.0:
			is_waiting_at_edge = false
			dir *= -1
		return

	if move_speed <= 0.0:
		_set_edge_frame()
		return

	var step: float = dir * move_speed * delta
	var next_x: float = global_position.x + step

	if _hit_patrol_limit(next_x):
		_start_edge_wait()
		return

	var wall_hit_x: float = _front_wall_hit_x()
	if wall_hit_x != INF:
		global_position.x = _wall_stop_x(next_x, wall_hit_x)
		_start_edge_wait()
		return

	global_position.x = next_x
	_advance_move_frames(absf(step))

func _setup_limits() -> void:
	patrol_left_x = global_position.x + minf(patrol_left_offset, patrol_right_offset)
	patrol_right_x = global_position.x + maxf(patrol_left_offset, patrol_right_offset)

	if auto_detect_limits:
		var cast_origin: Vector2 = _cast_origin()
		var left_hit: float = _cast_wall_x(cast_origin, cast_origin + Vector2(-detect_distance, 0.0))
		var right_hit: float = _cast_wall_x(cast_origin, cast_origin + Vector2(detect_distance, 0.0))

		if left_hit != INF:
			patrol_left_x = _root_x_for_left_wall(left_hit + wall_margin)
		if right_hit != INF:
			patrol_right_x = _root_x_for_right_wall(right_hit - wall_margin)

	if patrol_left_x > patrol_right_x:
		var mid: float = (patrol_left_x + patrol_right_x) * 0.5
		patrol_left_x = mid - 8.0
		patrol_right_x = mid + 8.0

func _hit_patrol_limit(next_x: float) -> bool:
	if not use_patrol_limits:
		return false
	if dir > 0 and next_x >= patrol_right_x:
		global_position.x = patrol_right_x
		return true
	if dir < 0 and next_x <= patrol_left_x:
		global_position.x = patrol_left_x
		return true
	return false

func _front_wall_hit_x() -> float:
	var from_pos: Vector2 = _cast_origin()
	var to_pos := from_pos + Vector2(ray_length * dir, 0.0)
	return _cast_wall_x(from_pos, to_pos)

func _cast_origin() -> Vector2:
	if hit_shape != null:
		return hit_shape.global_position
	return global_position

func _cast_wall_x(from_pos: Vector2, to_pos: Vector2) -> float:
	var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = wall_collision_mask
	var excluded: Array = [self]
	query.exclude = excluded

	for _i in 16:
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return INF

		var collider: Object = hit.get("collider")
		if _is_wall_collider(collider):
			return (hit.get("position", from_pos) as Vector2).x

		excluded.append(collider)
		query.exclude = excluded

	return INF

func _is_wall_collider(collider: Object) -> bool:
	return collider is StaticBody2D or collider is TileMapLayer or collider is TileMap

func _compute_local_x_extents() -> void:
	local_x_min = 0.0
	local_x_max = 0.0
	if hit_shape == null or hit_shape.shape == null:
		return

	var center_x: float = hit_shape.position.x
	if hit_shape.shape is CircleShape2D:
		var r: float = (hit_shape.shape as CircleShape2D).radius
		local_x_min = center_x - r
		local_x_max = center_x + r
	elif hit_shape.shape is RectangleShape2D:
		var half_w: float = (hit_shape.shape as RectangleShape2D).size.x * 0.5
		local_x_min = center_x - half_w
		local_x_max = center_x + half_w

func _root_x_for_left_wall(wall_x: float) -> float:
	return wall_x - local_x_min

func _root_x_for_right_wall(wall_x: float) -> float:
	return wall_x - local_x_max

func _wall_stop_x(next_x: float, wall_hit_x: float) -> float:
	if dir > 0:
		return minf(next_x, _root_x_for_right_wall(wall_hit_x - wall_margin))
	return maxf(next_x, _root_x_for_left_wall(wall_hit_x + wall_margin))

func _start_edge_wait() -> void:
	_set_edge_frame()
	if edge_wait_time <= 0.0:
		dir *= -1
		return
	is_waiting_at_edge = true
	wait_left = edge_wait_time

func _on_body_entered(body: Node) -> void:
	if not _can_damage(body):
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	var prev: float = last_hit.get(body, -999.0)
	if now - prev >= hit_cooldown:
		last_hit[body] = now
		_apply_damage(body)

func _init_manual_animation() -> void:
	if anim.sprite_frames == null:
		push_warning("Saw: SpriteFrames not assigned")
		return
	if not anim.sprite_frames.has_animation(run_anim):
		push_warning("Saw: run animation not found: %s" % [run_anim])
		return
	if not anim.sprite_frames.has_animation(stop_anim):
		push_warning("Saw: stop animation not found: %s" % [stop_anim])
		return
	anim.animation = stop_anim
	anim.stop()
	_set_edge_frame()

func _set_edge_frame() -> void:
	frame_accum = 0.0
	move_frame_index = 0
	last_move_dir = dir
	_set_stop_animation()

func _advance_move_frames(distance: float) -> void:
	if frame_step_pixels <= 0.0 or distance <= 0.0:
		return
	if dir != last_move_dir:
		last_move_dir = dir
		frame_accum = 0.0
		move_frame_index = 0

	_set_run_animation()
	frame_accum += distance

	var seq: Array[int] = RUN_FRAMES_RIGHT if dir > 0 else RUN_FRAMES_LEFT
	while frame_accum >= frame_step_pixels:
		frame_accum -= frame_step_pixels
		_set_run_frame(seq[move_frame_index])
		move_frame_index = (move_frame_index + 1) % seq.size()

func _set_stop_animation() -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(stop_anim):
		return
	anim.animation = stop_anim
	anim.stop()
	var count: int = anim.sprite_frames.get_frame_count(stop_anim)
	if count <= 0:
		return
	anim.frame = clampi(STOP_FRAME, 0, count - 1)

func _set_run_animation() -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(run_anim):
		return
	if anim.animation != run_anim:
		anim.animation = run_anim
	anim.stop()

func _set_run_frame(frame_idx: int) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(run_anim):
		return
	if anim.animation != run_anim:
		anim.animation = run_anim
	anim.stop()
	var count: int = anim.sprite_frames.get_frame_count(run_anim)
	if count <= 0:
		return
	anim.frame = clampi(frame_idx, 0, count - 1)

func _can_damage(body: Node) -> bool:
	return body is Player or body is RobotEnemy or body is SkyEnemy or body is WolfEnemy

func _apply_damage(body: Node) -> void:
	if body is Player:
		(body as Player).take_damage(damage)
	elif body is RobotEnemy:
		(body as RobotEnemy).take_damage(damage)
	elif body is SkyEnemy:
		(body as SkyEnemy).take_damage(damage)
	elif body is WolfEnemy:
		(body as WolfEnemy).take_damage(damage)
