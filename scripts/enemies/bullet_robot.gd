extends Node2D

class_name RobotProjectile

const PROJECTILE_SCENE := preload("res://scenes/enemies/bullet_robot.tscn")
const PLAYER_GROUP: StringName = &"player"
const ENEMY_GROUP: StringName = &"enemy"

@export var fire_interval: float = 0.6
@export var max_active_projectiles: int = 2
@export var muzzle_offset: Vector2 = Vector2.ZERO

@export var projectile_speed: float = 160.0
@export var turn_speed: float = 7.0
@export var damage: int = 1
@export var life_time: float = 3.0
@export_flags_2d_physics var hit_mask: int = 15

@onready var sprite: Sprite2D = $Sprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var is_spawner: bool = false
var robot: RobotEnemy = null
var spawn_cd: float = 0.0
var bullet_count: int = 0

var life: float = 0.0
var speed_vec: Vector2 = Vector2.ZERO
var player: Player = null

func _ready() -> void:
	is_spawner = _is_spawner_mode()
	if is_spawner:
		robot = get_parent() as RobotEnemy
		_setup_spawner()
	else:
		_setup_projectile()

func _physics_process(delta: float) -> void:
	if is_spawner:
		_spawner(delta)
	else:
		_bullet(delta)

func _spawner(delta: float) -> void:
	if not is_instance_valid(robot):
		return
	if robot.is_dead():
		return
	if not robot.is_attack_active():
		return

	spawn_cd = maxf(spawn_cd - delta, 0.0)
	if spawn_cd > 0.0:
		return
	if bullet_count >= max_active_projectiles:
		return

	var bullet_node := _spawn_projectile()
	if bullet_node == null:
		return

	bullet_node.setup_projectile(robot, damage, projectile_speed, turn_speed, life_time, hit_mask)
	bullet_node.tree_exited.connect(_on_bullet_exit)

	bullet_count += 1
	spawn_cd = fire_interval

func _bullet(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	if not is_instance_valid(player):
		player = _get_player()

	var desired_dir: Vector2 = transform.x.normalized()
	if is_instance_valid(player):
		var to_target: Vector2 = (_player_pos(player) - global_position)
		if to_target.length_squared() > 0.001:
			desired_dir = to_target.normalized()

	var current_dir: Vector2 = speed_vec.normalized()
	if current_dir.length_squared() < 0.001:
		current_dir = desired_dir
	var blend: float = clampf(turn_speed * delta, 0.0, 1.0)
	var new_dir: Vector2 = current_dir.lerp(desired_dir, blend).normalized()
	speed_vec = new_dir * projectile_speed
	rotation = speed_vec.angle()

	var from: Vector2 = global_position
	var to: Vector2 = from + speed_vec * delta
	var hit: Dictionary = _ray_hit(from, to)
	if hit.is_empty():
		global_position = to
		return

	var collider_v: Variant = hit.get("collider")
	if collider_v is Player:
		(collider_v as Player).take_damage(damage, global_position, true)
	queue_free()

func setup_projectile(owner_robot: RobotEnemy, new_damage: int, speed: float, turn: float, new_life: float, mask: int) -> void:
	is_spawner = false
	robot = owner_robot
	damage = new_damage
	projectile_speed = speed
	turn_speed = turn
	life_time = new_life
	hit_mask = mask
	life = life_time
	player = _get_player()
	if shape != null:
		shape.disabled = false

func _setup_spawner() -> void:
	spawn_cd = 0.0
	if sprite != null:
		sprite.visible = false
	if shape != null:
		shape.disabled = true

func _setup_projectile() -> void:
	if sprite != null:
		sprite.visible = true
	life = life_time
	player = _get_player()

func _spawn_projectile() -> RobotProjectile:
	var bullet_node := PROJECTILE_SCENE.instantiate() as RobotProjectile
	if bullet_node == null:
		return null

	var parent_for_spawn: Node = get_tree().current_scene
	if parent_for_spawn == null:
		parent_for_spawn = get_tree().root

	parent_for_spawn.add_child(bullet_node)
	bullet_node.global_position = global_position + muzzle_offset
	return bullet_node

func _ray_hit(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = hit_mask
	query.exclude = [self]
	if is_instance_valid(robot):
		query.exclude.append(robot)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return hit

	var collider_v: Variant = hit.get("collider")
	if collider_v is Node:
		var collider := collider_v as Node
		if collider == robot:
			return {}
		if collider.is_in_group(ENEMY_GROUP):
			return {}
	return hit

func _is_spawner_mode() -> bool:
	return get_parent() is RobotEnemy

func _get_player() -> Player:
	var players: Array[Node] = get_tree().get_nodes_in_group(PLAYER_GROUP)
	var nearest: Player = null
	var best_d2: float = INF
	for n in players:
		if not (n is Player):
			continue
		var p := n as Player
		var d2: float = global_position.distance_squared_to(_player_pos(p))
		if d2 < best_d2:
			best_d2 = d2
			nearest = p
	return nearest

func _player_pos(node: Player) -> Vector2:
	if node == null:
		return global_position
	return node.get_enemy_target_position()

func _on_bullet_exit() -> void:
	bullet_count = max(0, bullet_count - 1)
