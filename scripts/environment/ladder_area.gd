extends Area2D

const PLAYER_DETECT_MASK := (1 << 0) | (1 << 1)

func _ready() -> void:
	add_to_group("ladder")
	collision_mask = PLAYER_DETECT_MASK
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).set_can_use_ladder(true)

func _on_body_exited(body: Node) -> void:
	if body is Player:
		(body as Player).set_can_use_ladder(false)
