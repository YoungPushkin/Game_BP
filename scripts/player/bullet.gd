extends Area2D

class_name PlayerBullet

@export var speed: float = 300.0
@export var damage: int = 1
@export var life_time: float = 2.0
@export_flags_2d_physics var hit_mask: int = 13

var player_ignore: CollisionObject2D = null

func _ready() -> void:
	add_to_group("player_bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node is CollisionObject2D:
		player_ignore = player_node as CollisionObject2D

func _physics_process(delta: float) -> void:
	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return

	var from: Vector2 = global_position
	var to: Vector2 = from + transform.x * speed * delta

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var excluded: Array = [self]
	if player_ignore != null:
		excluded.append(player_ignore)

	for _i in 8:
		query.exclude = excluded
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break

		var collider: Object = hit.get("collider")
		if _ignore_hit(collider):
			excluded.append(collider)
			continue

		global_position = hit.position
		_hit(collider)
		return

	global_position = to

func _hit(collider: Object) -> void:
	if collider == null:
		queue_free()
		return
	if _ignore_hit(collider):
		return
	if collider is Node and (collider as Node).is_in_group("player"):
		return
	if collider is RobotEnemy:
		(collider as RobotEnemy).take_damage(damage)
	elif collider is SkyEnemy:
		(collider as SkyEnemy).take_damage(damage)
	elif collider is WolfEnemy:
		(collider as WolfEnemy).take_damage(damage)
	queue_free()

func _ignore_hit(collider: Object) -> bool:
	if not (collider is Node):
		return false
	var node := collider as Node
	return node.is_in_group("ladder") or node.is_in_group("bullet_ignore")

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _on_visible_on_screen_enabler_2d_screen_exited() -> void:
	queue_free()
