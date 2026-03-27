extends "res://scripts/enemies/enemy_base.gd"

class_name RobotEnemy

enum State {
	PATROL,
	ATTACK,
	DEAD
}

var walk_speed: float = 70.0
var gravity_scale: float = 1.0

var floor_mask: int = 1
var trap_mask: int = 8
var edge_check_forward: float = 30.0
var edge_check_down: float = 70.0
var wall_check_forward: float = 24.0
var turn_cooldown: float = 0.12
var near_probe_forward: float = 3.0
var mid_probe_ratio: float = 0.5
var max_step_down: float = 6.0
var floor_flat_tolerance: float = 8.0

@export var detect_diameter: float = 520.0
@export var lose_radius: float = 340.0
var vision_block_mask: int = 1
var refresh_target_interval: float = 0.2
var lose_sight_delay: float = 0.2

@export var max_health: int = 3
var queue_free_on_death_end: bool = true

var walk_anim: StringName = &"walk"
var attack_anim: StringName = &"attack"
var death_anim: StringName = &"death"
var flip_visual_by_dir: bool = true

var start_direction: int = 1

var mode: State = State.PATROL
var dir_x: int = 1
var hp: int = 1
var target_cd: float = 0.0
var turn_cd: float = 0.0
var lose_cd: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	hp = max_health
	dir_x = 1 if start_direction >= 0 else -1
	target_cd = 0.0
	lose_cd = lose_sight_delay
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(death_anim):
		sprite.sprite_frames.set_animation_loop(death_anim, false)
	_play(walk_anim)

func take_damage(amount: int = 1, _from_position: Vector2 = Vector2.ZERO, _has_from_position: bool = false) -> void:
	if mode == State.DEAD:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		_go_dead()

func _physics_process(delta: float) -> void:
	if mode == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		if queue_free_on_death_end and sprite != null and sprite.animation == death_anim and not sprite.is_playing():
			queue_free()
		return

	_update_timers(delta)
	_update_player()

	var can_see: bool = _see_player()
	var in_lose_zone: bool = _player_still_close()
	if mode == State.PATROL and can_see:
		mode = State.ATTACK
		lose_cd = lose_sight_delay
		velocity.x = 0.0
		_play(attack_anim)
	elif mode == State.ATTACK:
		if can_see and in_lose_zone:
			lose_cd = lose_sight_delay
		else:
			lose_cd = maxf(lose_cd - delta, 0.0)
			if lose_cd <= 0.0:
				mode = State.PATROL
				lose_cd = lose_sight_delay
				_play(walk_anim)

	_add_gravity(delta)

	if mode == State.PATROL:
		_patrol()
	else:
		_attack()

	move_and_slide()
	_update_sprite()

func _update_timers(delta: float) -> void:
	target_cd = maxf(target_cd - delta, 0.0)
	turn_cd = maxf(turn_cd - delta, 0.0)

func _update_player() -> void:
	if target_cd > 0.0 and is_instance_valid(player):
		return
	target_cd = refresh_target_interval
	player = _get_player()

func _get_player() -> Player:
	return _find_nearest_player(_body_pos())

func _see_player() -> bool:
	if not is_instance_valid(player):
		return false

	var from: Vector2 = _body_pos()
	var to: Vector2 = _player_pos(player)
	var dx: float = absf(to.x - from.x)
	if dx > maxf(0.0, detect_diameter * 0.5):
		return false

	var ray := PhysicsRayQueryParameters2D.create(from, to)
	ray.collision_mask = vision_block_mask
	ray.exclude = [self, player]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty()

func _player_still_close() -> bool:
	if not is_instance_valid(player):
		return false
	var from: Vector2 = _body_pos()
	var to: Vector2 = _player_pos(player)
	var dx: float = absf(to.x - from.x)
	return dx <= lose_radius

func _patrol() -> void:
	if dir_x == 0:
		dir_x = 1

	if turn_cd <= 0.0 and (_wall_ahead(dir_x) or not _floor_ahead(dir_x)):
		dir_x *= -1
		turn_cd = turn_cooldown

	velocity.x = float(dir_x) * walk_speed
	_play(walk_anim)

func _attack() -> void:
	velocity.x = 0.0
	if is_instance_valid(player):
		var dx: float = _player_pos(player).x - _body_pos().x
		if absf(dx) > 0.001:
			dir_x = 1 if dx > 0.0 else -1
	_play(attack_anim)

func _add_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	velocity += get_gravity() * gravity_scale * delta

func _floor_ahead(sign_dir: int) -> bool:
	var half_w: float = _half_width(12.0)
	var base: Vector2 = _body_pos()
	base.y += _half_height(16.0) - 1.0

	var near_fwd: float = maxf(0.0, near_probe_forward)
	var mid_fwd: float = maxf(near_fwd, edge_check_forward * clampf(mid_probe_ratio, 0.0, 1.0))
	var far_fwd: float = maxf(mid_fwd, edge_check_forward)

	var near_y: float = _floor_y(base, sign_dir, half_w + near_fwd)
	var mid_y: float = _floor_y(base, sign_dir, half_w + mid_fwd)
	var far_y: float = _floor_y(base, sign_dir, half_w + far_fwd)

	if not is_finite(near_y) or not is_finite(mid_y) or not is_finite(far_y):
		return false

	var min_y: float = minf(near_y, minf(mid_y, far_y))
	var max_y: float = maxf(near_y, maxf(mid_y, far_y))
	if (max_y - min_y) > floor_flat_tolerance:
		return false

	return true

func _wall_ahead(sign_dir: int) -> bool:
	var half_w: float = _half_width(12.0)
	var from: Vector2 = _body_pos()
	from.x += float(sign_dir) * (half_w - 2.0)
	var to: Vector2 = from + Vector2(float(sign_dir) * wall_check_forward, 0.0)
	var ray := PhysicsRayQueryParameters2D.create(from, to)
	ray.collision_mask = floor_mask
	ray.exclude = [self]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty()

func _floor_y(base: Vector2, sign_dir: int, forward_offset: float) -> float:
	var from: Vector2 = base + Vector2(float(sign_dir) * forward_offset, 0.0)
	var to: Vector2 = from + Vector2(0.0, edge_check_down)
	var ray := PhysicsRayQueryParameters2D.create(from, to)
	ray.collision_mask = floor_mask | trap_mask
	ray.exclude = [self]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return INF
	if not _safe_floor(hit):
		return INF
	var pos_v: Variant = hit.get("position")
	if not (pos_v is Vector2):
		return INF
	var y: float = (pos_v as Vector2).y
	if (y - base.y) > max_step_down:
		return INF
	return y

func _safe_floor(hit: Dictionary) -> bool:
	var collider_v: Variant = hit.get("collider")
	if not (collider_v is Object):
		return false
	var collider_obj: Object = collider_v as Object
	if collider_obj is Node:
		var node := collider_obj as Node
		if node.is_in_group("trap"):
			return false
		if node.get_parent() != null and node.get_parent().is_in_group("trap"):
			return false

	var body_v: Variant = hit.get("collider")
	if body_v is CollisionObject2D:
		var body := body_v as CollisionObject2D
		if (body.collision_layer & trap_mask) != 0:
			return false
	return true

func _update_sprite() -> void:
	if sprite == null:
		return
	if flip_visual_by_dir:
		sprite.flip_h = dir_x < 0

func _go_dead() -> void:
	mode = State.DEAD
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_play(death_anim)

func _play(anim_name: String) -> void:
	if sprite == null:
		return
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func is_attack_active() -> bool:
	return mode == State.ATTACK

func is_dead() -> bool:
	return mode == State.DEAD
