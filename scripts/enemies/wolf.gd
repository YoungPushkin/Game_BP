extends "res://scripts/enemies/enemy_base.gd"

class_name WolfEnemy

const PLAYER_DETECT_MASK := (1 << 0) | (1 << 1)

enum State { SCAN, CHASE, BLOCKED_WAIT, SEARCH, ATTACK, HURT, DEAD }

@export var max_health: int = 6
var gravity: float = 900.0
@export var run_speed: float = 180.0
var hurt_duration: float = 0.2
var scan_turn_interval: float = 1.2
var stop_on_damage_hit: bool = false
var hurt_reaction_cooldown: float = 0.2

var detect_radius: float = 360.0
var lose_radius: float = 520.0
var vision_angle_deg: float = 100.0
var vision_height_tolerance: float = 120.0
var lose_target_if_airborne: bool = true
var wall_collision_mask: int = 1
var target_refresh_interval: float = 0.2

var chase_stop_distance: float = 14.0
var blocked_wait_time: float = 0.55
var avoid_fall: bool = true
var wall_check_distance: float = 26.0
var cliff_check_distance: float = 36.0
var cliff_check_depth: float = 72.0
var trap_check_distance: float = 42.0
var trap_check_radius: float = 14.0
var trap_collision_mask: int = 8

var attack_damage: int = 1
@export var attack_range: float = 12.0
@export var attack_vertical_tolerance: float = 44.0
@export var attack_cooldown: float = 0.35
@export var attack_hit_frame: int = 1
var end_attack_on_hit_frame: bool = true
@export var attack_anim_fps: float = 10.0
var use_damage_area_as_attack_radius: bool = true

var enable_back_push: bool = true
var back_push_range: float = 8.0
var back_push_force_x: float = 220.0
var back_push_separation_x: float = 2.0
var back_push_cooldown: float = 0.25

var search_duration: float = 2.2
var search_turn_interval: float = 0.55
var search_anchor_slack: float = 4.0

var death_fallback_time: float = 0.7

var mode: State = State.SCAN
var hp: int = 0
var dir_x: int = -1

var target_cd: float = 0.0
var turn_cd: float = 0.0
var wait_cd: float = 0.0
var search_cd: float = 0.0
var search_turn_cd: float = 0.0
var search_x: float = 0.0
var hurt_cd: float = 0.0
var death_cd: float = 0.0
var attack_cd: float = 0.0
var attack_hit_done: bool = false
var hurt_react_cd: float = 0.0
var push_cd: float = 0.0

@onready var look_root: Node2D = $FacingRoot
@onready var sprite: AnimatedSprite2D = $FacingRoot/AnimatedSprite2D
@onready var hit_area: Area2D = get_node_or_null("FacingRoot/damage") as Area2D
@onready var hit_area_shape: CollisionShape2D = get_node_or_null("FacingRoot/damage/CollisionShape2D") as CollisionShape2D
var look_root_pos: Vector2 = Vector2.ZERO
var sprite_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	hp = max_health
	add_to_group("enemy")
	if look_root != null:
		look_root_pos = look_root.position
	if sprite != null:
		sprite_start_pos = sprite.position
	if hit_area != null:
		hit_area.monitoring = true
		hit_area.monitorable = true
		hit_area.collision_mask = PLAYER_DETECT_MASK
	_setup_anims()
	_connect_anims()
	mode = State.SCAN
	velocity.x = 0.0
	turn_cd = scan_turn_interval
	_play_if_exists("idle")
	_flip_enemy()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_player()

	if mode != State.DEAD:
		_add_gravity(delta)

	match mode:
		State.SCAN:
			_scan()
		State.CHASE:
			_chase()
		State.BLOCKED_WAIT:
			_wait_block()
		State.SEARCH:
			_search()
		State.ATTACK:
			_attack()
		State.HURT:
			_hurt()
		State.DEAD:
			_dead()

	move_and_slide()

func take_damage(amount: int = 1) -> void:
	if mode == State.DEAD:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		mode = State.DEAD
		velocity = Vector2.ZERO
		_play_if_exists("death")
		death_cd = _anim_time("death", death_fallback_time)
		if hit_area != null:
			hit_area.monitoring = false
		return
	if stop_on_damage_hit and hurt_react_cd <= 0.0:
		hurt_react_cd = hurt_reaction_cooldown
		mode = State.HURT
		velocity.x = 0.0
		hurt_cd = hurt_duration
		_play_if_exists("hurt")

func _update_timers(delta: float) -> void:
	target_cd = maxf(target_cd - delta, 0.0)
	turn_cd = maxf(turn_cd - delta, 0.0)
	wait_cd = maxf(wait_cd - delta, 0.0)
	search_cd = maxf(search_cd - delta, 0.0)
	search_turn_cd = maxf(search_turn_cd - delta, 0.0)
	hurt_cd = maxf(hurt_cd - delta, 0.0)
	death_cd = maxf(death_cd - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	hurt_react_cd = maxf(hurt_react_cd - delta, 0.0)
	push_cd = maxf(push_cd - delta, 0.0)

func _update_player() -> void:
	if target_cd > 0.0 and is_instance_valid(player):
		return
	player = _find_nearest_player(_eye_pos())
	target_cd = target_refresh_interval

func _scan() -> void:
	velocity.x = 0.0
	_play_if_exists("idle")

	if _see_player(detect_radius, true):
		mode = State.CHASE
		_play_if_exists("run")
		return

	if turn_cd <= 0.0:
		dir_x *= -1
		turn_cd = scan_turn_interval
		_flip_enemy()

func _chase() -> void:
	if not _see_player(lose_radius, false):
		_enter_search()
		return

	_push_back_player()

	var to_target: Vector2 = _player_pos(player) - _body_pos()
	if absf(to_target.x) > 0.01:
		dir_x = 1 if to_target.x > 0.0 else -1
		_flip_enemy()

	if _can_attack():
		mode = State.ATTACK
		velocity.x = 0.0
		attack_hit_done = false
		if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")
		else:
			_end_attack()
		return

	if _stop_near_player():
		velocity.x = 0.0
		_play_if_exists("idle")
		return

	if _wall_or_trap(dir_x):
		mode = State.BLOCKED_WAIT
		velocity.x = 0.0
		wait_cd = blocked_wait_time
		_play_if_exists("idle")
		_flip_enemy()
		return

	velocity.x = float(dir_x) * run_speed
	_play_if_exists("run")

func _wait_block() -> void:
	velocity.x = 0.0
	_play_if_exists("idle")

	if not _see_player(lose_radius, false):
		_enter_search()
		return

	_push_back_player()

	var to_target: Vector2 = _player_pos(player) - _body_pos()
	if absf(to_target.x) > 0.01:
		dir_x = 1 if to_target.x > 0.0 else -1
		_flip_enemy()

	if wait_cd <= 0.0:
		if _can_attack():
			mode = State.ATTACK
			velocity.x = 0.0
			attack_hit_done = false
			if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("attack"):
				sprite.play("attack")
			else:
				_end_attack()
			return
		if _stop_near_player():
			return
		if not _wall_or_trap(dir_x):
			mode = State.CHASE
			_play_if_exists("run")
			return
		wait_cd = blocked_wait_time

func _attack() -> void:
	velocity.x = 0.0
	_play_if_exists("attack")
	if attack_hit_done:
		return
	if sprite == null or sprite.animation != "attack":
		return
	if sprite.frame < attack_hit_frame:
		return
	attack_hit_done = true
	_try_hit_player()
	if end_attack_on_hit_frame:
		_end_attack()

func _search() -> void:
	velocity.x = 0.0
	_play_if_exists("idle")

	if _see_player(detect_radius, true):
		mode = State.CHASE
		_play_if_exists("run")
		return

	var body_pos: Vector2 = _body_pos()
	if absf(body_pos.x - search_x) > search_anchor_slack:
		global_position.x += search_x - body_pos.x

	if search_turn_cd <= 0.0:
		dir_x *= -1
		search_turn_cd = search_turn_interval
		_flip_enemy()

	if search_cd <= 0.0:
		mode = State.SCAN
		velocity.x = 0.0
		turn_cd = scan_turn_interval
		_play_if_exists("idle")
		_flip_enemy()

func _hurt() -> void:
	velocity.x = 0.0
	_play_if_exists("hurt")
	if hurt_cd <= 0.0:
		if _see_player(lose_radius, false):
			mode = State.CHASE
			_play_if_exists("run")
		else:
			_enter_search()

func _dead() -> void:
	velocity = Vector2.ZERO
	_play_if_exists("death")
	if death_cd <= 0.0:
		queue_free()

func _see_player(radius: float, need_face: bool) -> bool:
	if not is_instance_valid(player):
		return false
	if lose_target_if_airborne and player is CharacterBody2D:
		var target_body: CharacterBody2D = player as CharacterBody2D
		if not target_body.is_on_floor():
			return false

	var from_pos: Vector2 = _eye_pos()
	var target_pos: Vector2 = _player_pos(player)
	var to_target: Vector2 = target_pos - from_pos

	if to_target.length() > radius:
		return false
	if absf(to_target.y) > vision_height_tolerance:
		return false

	if need_face and to_target.length() > 0.001:
		var forward: Vector2 = Vector2(float(dir_x), 0.0)
		var dot_val: float = clampf(forward.dot(to_target.normalized()), -1.0, 1.0)
		var angle: float = rad_to_deg(acos(dot_val))
		if angle > vision_angle_deg * 0.5:
			return false

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, target_pos)
	query.collision_mask = wall_collision_mask
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	if collider == player:
		return true
	if collider is Node and (collider as Node).is_in_group("player"):
		return true
	return false

func _stop_near_player() -> bool:
	if not is_instance_valid(player):
		return false
	if use_damage_area_as_attack_radius:
		return _player_in_hit_area()
	var dx: float = absf(_player_pos(player).x - _body_pos().x)
	var gap: float = maxf(0.0, dx - (_half_width(16.0) + _player_half_width(player)))
	var effective_attack_range: float = attack_range if not use_damage_area_as_attack_radius else _hit_area_range()
	var effective_stop_gap: float = minf(chase_stop_distance, effective_attack_range)
	return gap <= effective_stop_gap

func _player_in_attack_range() -> bool:
	if not is_instance_valid(player):
		return false
	if use_damage_area_as_attack_radius:
		return _player_in_hit_area()
	var self_pos: Vector2 = _body_pos()
	var target_pos: Vector2 = _player_pos(player)
	if absf(target_pos.y - self_pos.y) > attack_vertical_tolerance:
		return false
	var dx: float = absf(target_pos.x - self_pos.x)
	var edge_gap: float = maxf(0.0, dx - (_half_width(16.0) + _player_half_width(player)))
	var attack_reach: float = attack_range if not use_damage_area_as_attack_radius else _hit_area_range()
	return edge_gap <= attack_reach

func _can_attack() -> bool:
	if attack_cd > 0.0:
		return false
	if use_damage_area_as_attack_radius:
		return _player_in_hit_area()
	return _player_in_attack_range() or _player_in_hit_area()

func _hit_area_range() -> float:
	if hit_area == null or hitbox == null:
		return attack_range
	if hit_area_shape == null or hit_area_shape.shape == null:
		return attack_range

	var shape_half_x: float = 0.0
	if hit_area_shape.shape is CircleShape2D:
		shape_half_x = (hit_area_shape.shape as CircleShape2D).radius
	elif hit_area_shape.shape is RectangleShape2D:
		shape_half_x = (hit_area_shape.shape as RectangleShape2D).size.x * 0.5
	else:
		return attack_range

	var center_dx: float = absf(hit_area_shape.global_position.x - _body_pos().x)
	var reach_from_center: float = center_dx + shape_half_x
	return maxf(0.0, reach_from_center - _half_width(16.0))

func _wall_or_trap(sign_dir: int) -> bool:
	if sign_dir == 0:
		return true
	if _wall_ahead(sign_dir):
		return true
	if avoid_fall and _cliff_ahead(sign_dir):
		return true
	if _trap_ahead(sign_dir):
		return true
	return false

func _wall_ahead(sign_dir: int) -> bool:
	var from_pos: Vector2 = _body_pos()
	var to_pos: Vector2 = from_pos + Vector2(float(sign_dir) * wall_check_distance, 0.0)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = wall_collision_mask
	var excluded: Array[RID] = [get_rid()]
	query.exclude = excluded

	for _i in 8:
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit.get("collider")
		if collider is Node:
			var node: Node = collider as Node
			if node.is_in_group("player") or node.is_in_group("enemy"):
				var co: CollisionObject2D = collider as CollisionObject2D
				if co != null:
					excluded.append(co.get_rid())
					query.exclude = excluded
					continue
		return true

	return false

func _cliff_ahead(sign_dir: int) -> bool:
	var from_pos: Vector2 = _body_pos() + Vector2(float(sign_dir) * cliff_check_distance, 0.0)
	var to_pos: Vector2 = from_pos + Vector2(0.0, cliff_check_depth)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = wall_collision_mask
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _trap_ahead(sign_dir: int) -> bool:
	var center: Vector2 = _body_pos() + Vector2(float(sign_dir) * trap_check_distance, 0.0)
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = trap_check_radius

	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, center)
	params.collision_mask = trap_collision_mask
	params.exclude = [get_rid()]

	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(params, 16)
	for h in hits:
		var collider: Object = h.get("collider")
		if collider is Node and (collider as Node).is_in_group("player"):
			continue
		return true
	return false

func _setup_anims() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation("attack"):
		sprite.sprite_frames.set_animation_speed("attack", maxf(1.0, attack_anim_fps))
		sprite.sprite_frames.set_animation_loop("attack", false)
	if sprite.sprite_frames.has_animation("death"):
		sprite.sprite_frames.set_animation_loop("death", false)

func _connect_anims() -> void:
	if sprite == null:
		return
	if not sprite.frame_changed.is_connected(_on_anim_frame_changed):
		sprite.frame_changed.connect(_on_anim_frame_changed)
	if not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)

func _on_anim_frame_changed() -> void:
	if mode != State.ATTACK:
		return
	if attack_hit_done:
		return
	if sprite == null or sprite.animation != "attack":
		return
	if sprite.frame < attack_hit_frame:
		return
	attack_hit_done = true
	_try_hit_player()
	if end_attack_on_hit_frame:
		_end_attack()

func _on_anim_finished() -> void:
	if mode != State.ATTACK:
		return
	_end_attack()

func _end_attack() -> void:
	attack_cd = attack_cooldown
	if _see_player(lose_radius, false):
		mode = State.CHASE
		_play_if_exists("run")
	else:
		_enter_search()

func _try_hit_player() -> void:
	if hit_area != null:
		var bodies: Array[Node2D] = hit_area.get_overlapping_bodies()
		for b in bodies:
			if b is Player:
				(b as Player).take_damage(attack_damage, global_position, true)
				return

	if not _player_in_attack_range():
		return
	if player != null:
		player.take_damage(attack_damage, global_position, true)

func _enter_search() -> void:
	mode = State.SEARCH
	velocity.x = 0.0
	search_x = _body_pos().x
	search_cd = search_duration
	search_turn_cd = search_turn_interval
	_play_if_exists("idle")
	_flip_enemy()

func _player_in_hit_area() -> bool:
	if hit_area == null:
		return false
	var bodies: Array[Node2D] = hit_area.get_overlapping_bodies()
	for b in bodies:
		if b == null:
			continue
		if not b.is_in_group("player"):
			continue
		return true
	return false

func _push_back_player() -> void:
	if not enable_back_push:
		return
	if push_cd > 0.0:
		return
	if not is_instance_valid(player):
		return
	if not (player is CharacterBody2D):
		return

	var self_pos: Vector2 = _body_pos()
	var target_pos: Vector2 = _player_pos(player)
	if absf(target_pos.y - self_pos.y) > attack_vertical_tolerance:
		return

	var dx: float = target_pos.x - self_pos.x
	var abs_dx: float = absf(dx)
	var edge_gap: float = maxf(0.0, abs_dx - (_half_width(16.0) + _player_half_width(player)))
	if edge_gap > back_push_range:
		return

	var is_behind: bool = (dir_x > 0 and dx < 0.0) or (dir_x < 0 and dx > 0.0)
	if not is_behind:
		return

	var target_body: CharacterBody2D = player as CharacterBody2D
	var push_dir: float = signf(dx)
	if push_dir == 0.0:
		push_dir = -float(dir_x)

	target_body.velocity.x = push_dir * back_push_force_x
	target_body.global_position.x += push_dir * back_push_separation_x
	push_cd = back_push_cooldown

func _play_if_exists(anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _anim_time(anim_name: String, fallback: float) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return fallback
	if not sprite.sprite_frames.has_animation(anim_name):
		return fallback
	var fps: float = sprite.sprite_frames.get_animation_speed(anim_name)
	var frames: int = sprite.sprite_frames.get_frame_count(anim_name)
	if fps <= 0.0 or frames <= 0:
		return fallback
	return maxf(float(frames) / fps, fallback)

func _flip_enemy() -> void:
	if look_root != null:
		look_root.scale.x = float(dir_x)
		if dir_x < 0:
			look_root.position = look_root_pos + Vector2(sprite_start_pos.x * 2.0, 0.0)
		else:
			look_root.position = look_root_pos

func _add_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta

func _eye_pos() -> Vector2:
	return _body_pos() + Vector2(0.0, -18.0)
