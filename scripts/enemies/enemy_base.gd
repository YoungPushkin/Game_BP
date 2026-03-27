extends CharacterBody2D

class_name EnemyBase

var player: Player = null

@onready var hitbox: CollisionShape2D = $CollisionShape2D

func _find_nearest_player(origin: Vector2) -> Player:
	var nearest: Player = null
	var best_distance_sq: float = INF

	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Player):
			continue
		var target := node as Player
		var distance_sq := origin.distance_squared_to(_player_pos(target))
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			nearest = target

	return nearest

func _player_pos(target: Player) -> Vector2:
	if target == null:
		return global_position
	return target.get_enemy_target_position()

func _player_half_width(target: Player, fallback: float = 8.0) -> float:
	if target == null:
		return fallback
	var width := target.get_enemy_target_half_width()
	if is_finite(width) and width > 0.0:
		return width
	return fallback

func _body_pos() -> Vector2:
	if hitbox != null:
		return hitbox.global_position
	return global_position

func _half_width(fallback: float = 12.0) -> float:
	if hitbox == null or hitbox.shape == null:
		return fallback
	if hitbox.shape is RectangleShape2D:
		var rect := hitbox.shape as RectangleShape2D
		return rect.size.x * 0.5
	if hitbox.shape is CircleShape2D:
		var circle := hitbox.shape as CircleShape2D
		return circle.radius
	return fallback

func _half_height(fallback: float = 16.0) -> float:
	if hitbox == null or hitbox.shape == null:
		return fallback
	if hitbox.shape is RectangleShape2D:
		var rect := hitbox.shape as RectangleShape2D
		return rect.size.y * 0.5
	if hitbox.shape is CircleShape2D:
		var circle := hitbox.shape as CircleShape2D
		return circle.radius
	return fallback
