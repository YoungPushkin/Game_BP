extends "res://scripts/enemies/enemy_base.gd"

class_name SkyEnemy

enum State {
	IDLE,
	ATTACK_DASH,
	RETREAT,
	HURT,
	DEAD
}

enum DodgeAxis {
	VERTICAL = 0,
	HORIZONTAL = 1
}

var max_health: int = 3
var contact_damage: int = 1

var detect_radius: float = 220.0
var lose_radius: float = 320.0
var detect_vertical_tolerance: float = 220.0
var refresh_target_interval: float = 0.15
var use_line_of_sight: bool = true
var vision_block_mask: int = 1

var attack_speed: float = 220.0
var attack_max_duration: float = 1.0
var attack_contact_extra_range: float = 4.0
var attack_vertical_tolerance: float = 22.0
var attack_cooldown: float = 0.35
var retreat_speed: float = 150.0
var retreat_duration: float = 0.3
var die_on_player_hit: bool = true
var die_on_any_dash_collision: bool = true
var attack_block_mask: int = 1
var attack_path_side_probe: float = 8.0
var attack_path_end_padding: float = 6.0

var enable_bullet_dodge: bool = true
var dodge_axis: int = DodgeAxis.VERTICAL
var dodge_check_radius: float = 180.0
var dodge_speed: float = 170.0
var dodge_duration: float = 0.18
var dodge_cooldown: float = 0.35
var bullet_group: StringName = &"player_bullet"

var idle_anim: StringName = &"idle"
var attack_anim: StringName = &"attack"
var hurt_anim: StringName = &"hurt"
var death_anim: StringName = &"death"
var move_anim: StringName = &"fly"
var flip_by_velocity_x: bool = true

var hurt_duration: float = 0.16
var queue_free_after_death: bool = true

var mode: State = State.IDLE
var hp: int = 1
var target_cd: float = 0.0
var attack_cd: float = 0.0
var hurt_cd: float = 0.0
var attack_time: float = 0.0
var back_time: float = 0.0
var dodge_time: float = 0.0
var dodge_cd: float = 0.0
var dodge_vec: Vector2 = Vector2.ZERO
var attack_dir: Vector2 = Vector2.RIGHT
var back_dir: Vector2 = Vector2.LEFT
var hit_done: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	hp = max_health
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(death_anim):
		sprite.sprite_frames.set_animation_loop(death_anim, false)
	mode = State.IDLE
	velocity = Vector2.ZERO
	_update_sprite()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_player()

	if mode == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		if queue_free_after_death and sprite != null and sprite.animation == death_anim and not sprite.is_playing():
			queue_free()
		return

	if mode == State.HURT:
		velocity = Vector2.ZERO
		move_and_slide()
		if hurt_cd <= 0.0:
			if _can_attack():
				mode = State.ATTACK_DASH
				attack_time = attack_max_duration
				hit_done = false
				if is_instance_valid(player):
					var hurt_to_target: Vector2 = _player_pos(player) - _body_pos()
					if hurt_to_target.length_squared() > 0.001:
						attack_dir = hurt_to_target.normalized()
						back_dir = -attack_dir
				_update_sprite()
			else:
				mode = State.IDLE
				velocity = Vector2.ZERO
				_update_sprite()
		_update_sprite()
		return

	if enable_bullet_dodge and (mode == State.IDLE or mode == State.RETREAT):
		_try_dodge()

	match mode:
		State.IDLE:
			velocity = Vector2.ZERO
			if _can_attack():
				mode = State.ATTACK_DASH
				attack_time = attack_max_duration
				hit_done = false
				if is_instance_valid(player):
					var idle_to_target: Vector2 = _player_pos(player) - _body_pos()
					if idle_to_target.length_squared() > 0.001:
						attack_dir = idle_to_target.normalized()
						back_dir = -attack_dir
				_update_sprite()
		State.ATTACK_DASH:
			_attack_dash()
		State.RETREAT:
			_back_off()

	if dodge_time > 0.0:
		velocity += dodge_vec

	move_and_slide()
	if mode == State.ATTACK_DASH:
		_check_dash_hit()
	_update_sprite()

func take_damage(amount: int = 1, _from_position: Vector2 = Vector2.ZERO, _has_from_position: bool = false) -> void:
	if mode == State.DEAD:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		mode = State.DEAD
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO
		_update_sprite()
	else:
		mode = State.HURT
		hurt_cd = hurt_duration
		velocity = Vector2.ZERO
		_update_sprite()

func _update_timers(delta: float) -> void:
	target_cd = maxf(target_cd - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	hurt_cd = maxf(hurt_cd - delta, 0.0)
	attack_time = maxf(attack_time - delta, 0.0)
	back_time = maxf(back_time - delta, 0.0)
	dodge_time = maxf(dodge_time - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	if dodge_time <= 0.0:
		dodge_vec = Vector2.ZERO

func _update_player() -> void:
	if target_cd > 0.0 and is_instance_valid(player):
		return
	target_cd = refresh_target_interval
	player = _get_player()

func _get_player() -> Player:
	return _find_nearest_player(_body_pos())

func _can_attack() -> bool:
	if attack_cd > 0.0:
		return false
	if not is_instance_valid(player):
		return false
	if not _see_player(player, detect_radius):
		return false
	return _dash_ok(player)

func _see_player(target: Player, radius: float) -> bool:
	var from: Vector2 = _body_pos()
	var to: Vector2 = _player_pos(target)
	var delta: Vector2 = to - from
	if delta.length() > radius:
		return false
	if absf(delta.y) > detect_vertical_tolerance:
		return false

	if not use_line_of_sight:
		return true

	var ray := PhysicsRayQueryParameters2D.create(from, to)
	ray.collision_mask = vision_block_mask
	ray.exclude = [self, target]
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty()

func _attack_dash() -> void:
	if not is_instance_valid(player):
		mode = State.RETREAT
		back_time = retreat_duration
		attack_cd = attack_cooldown
		_update_sprite()
		return

	var to_target: Vector2 = _player_pos(player) - _body_pos()
	if to_target.length_squared() > 0.001:
		attack_dir = to_target.normalized()
		back_dir = -attack_dir

	velocity = attack_dir * attack_speed

	if not hit_done and _touch_player(player):
		if player != null:
			player.take_damage(contact_damage, _body_pos(), true)
		hit_done = true
		if die_on_player_hit:
			mode = State.DEAD
			collision_layer = 0
			collision_mask = 0
			velocity = Vector2.ZERO
			_update_sprite()
		else:
			mode = State.RETREAT
			back_time = retreat_duration
			attack_cd = attack_cooldown
			_update_sprite()
		return

	if attack_time <= 0.0:
		mode = State.IDLE
		velocity = Vector2.ZERO
		_update_sprite()

func _back_off() -> void:
	velocity = back_dir * retreat_speed
	if back_time <= 0.0:
		if is_instance_valid(player) and _see_player(player, lose_radius) and attack_cd <= 0.0:
			mode = State.ATTACK_DASH
			attack_time = attack_max_duration
			hit_done = false
			if is_instance_valid(player):
				var back_to_target: Vector2 = _player_pos(player) - _body_pos()
				if back_to_target.length_squared() > 0.001:
					attack_dir = back_to_target.normalized()
					back_dir = -attack_dir
			_update_sprite()
		else:
			mode = State.IDLE
			velocity = Vector2.ZERO
			_update_sprite()

func _touch_player(target: Player) -> bool:
	var self_pos: Vector2 = _body_pos()
	var target_pos: Vector2 = _player_pos(target)
	var dx: float = absf(target_pos.x - self_pos.x)
	var dy: float = absf(target_pos.y - self_pos.y)
	if dy > attack_vertical_tolerance:
		return false
	var touch_range: float = _half_width(10.0) + _player_half_width(target) + attack_contact_extra_range
	return dx <= touch_range

func _try_dodge() -> void:
	if dodge_cd > 0.0:
		return
	var bullet: Node2D = _get_bullet()
	if bullet == null:
		return

	var bdir: Vector2 = bullet.transform.x.normalized()
	var side: Vector2 = Vector2(-bdir.y, bdir.x)
	var rel: Vector2 = _body_pos() - bullet.global_position
	if rel.dot(side) < 0.0:
		side = -side

	var dodge_dir: Vector2 = Vector2.ZERO
	if dodge_axis == DodgeAxis.VERTICAL:
		dodge_dir = Vector2(0.0, signf(side.y))
		if dodge_dir.y == 0.0:
			dodge_dir.y = 1.0
	else:
		dodge_dir = Vector2(signf(side.x), 0.0)
		if dodge_dir.x == 0.0:
			dodge_dir.x = 1.0

	dodge_vec = dodge_dir * dodge_speed
	dodge_time = dodge_duration
	dodge_cd = dodge_cooldown

func _get_bullet() -> Node2D:
	var bullets: Array[Node] = get_tree().get_nodes_in_group(bullet_group)
	var nearest: Node2D = null
	var best_d2: float = INF
	var self_pos: Vector2 = _body_pos()

	for n in bullets:
		if not (n is Node2D):
			continue
		var b := n as Node2D
		var rel: Vector2 = self_pos - b.global_position
		var d2: float = rel.length_squared()
		if d2 > dodge_check_radius * dodge_check_radius:
			continue

		var bdir: Vector2 = b.transform.x.normalized()
		if rel.dot(bdir) <= 0.0:
			continue

		var perp: float = absf(rel.cross(bdir))
		if perp > 24.0:
			continue

		if d2 < best_d2:
			best_d2 = d2
			nearest = b

	return nearest

func _dash_ok(target: Player) -> bool:
	if not is_instance_valid(target):
		return false

	var from: Vector2 = _body_pos()
	var to: Vector2 = _player_pos(target)
	var dir: Vector2 = to - from
	var distance_to_target: float = dir.length()
	if distance_to_target <= 0.001:
		return true
	dir /= distance_to_target
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var start_offsets: Array[Vector2] = [Vector2.ZERO, perp * attack_path_side_probe, -perp * attack_path_side_probe]
	var cast_len: float = maxf(0.0, distance_to_target - attack_path_end_padding)

	for off in start_offsets:
		var ray := PhysicsRayQueryParameters2D.create(from + off, from + off + dir * cast_len)
		ray.collision_mask = attack_block_mask
		ray.exclude = [self, target]
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			return false

	return true

func _check_dash_hit() -> void:
	if mode != State.ATTACK_DASH:
		return
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue
		var collider: Object = col.get_collider()
		if collider == null:
			continue
		if collider == self:
			continue

		if collider is Node and (collider as Node).is_in_group("player"):
			if not hit_done and is_instance_valid(player):
				player.take_damage(contact_damage, _body_pos(), true)
				hit_done = true
			if die_on_player_hit:
				mode = State.DEAD
				collision_layer = 0
				collision_mask = 0
				velocity = Vector2.ZERO
				_update_sprite()
			else:
				mode = State.RETREAT
				back_time = retreat_duration
				attack_cd = attack_cooldown
				_update_sprite()
			return

		if die_on_any_dash_collision:
			mode = State.DEAD
			collision_layer = 0
			collision_mask = 0
			velocity = Vector2.ZERO
			_update_sprite()
			return

func _update_sprite() -> void:
	if sprite == null:
		return
	match mode:
		State.IDLE:
			_play(idle_anim)
		State.ATTACK_DASH:
			_play(attack_anim)
		State.RETREAT:
			if _has_anim(move_anim):
				_play(move_anim)
			else:
				_play(idle_anim)
		State.HURT:
			_play(hurt_anim)
		State.DEAD:
			_play(death_anim)

	if flip_by_velocity_x and absf(velocity.x) > 0.01:
		sprite.flip_h = velocity.x < 0.0

func _has_anim(anim_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)

func _play(anim_name: StringName) -> void:
	if not _has_anim(anim_name):
		return
	if sprite.animation != anim_name:
		sprite.play(anim_name)
