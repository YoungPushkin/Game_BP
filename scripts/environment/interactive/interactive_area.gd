extends Area2D

const PLAYER_DETECT_MASK := (1 << 0) | (1 << 1)

var player_here: bool = false
var player: Node = null
var use_down: bool = false

func _ready() -> void:
	add_to_group("bullet_ignore")
	collision_mask = PLAYER_DETECT_MASK
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if not can_interact():
		return
	if not _use_pressed():
		return
	_handle_interaction()

func can_interact() -> bool:
	return player_here and player != null

func _handle_interaction() -> void:
	pass

func _interaction_keys_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_E)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	player_here = true
	player = body
	use_down = _interaction_keys_pressed()
	_on_player_entered(body)

func _on_body_exited(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body == player:
		player = null
	player_here = false
	use_down = false
	_on_player_exited(body)

func _on_player_entered(_body: Node) -> void:
	pass

func _on_player_exited(_body: Node) -> void:
	pass

func _use_pressed() -> bool:
	var interact_pressed := _interaction_keys_pressed()
	var interact_just_pressed := interact_pressed and not use_down
	use_down = interact_pressed
	return interact_just_pressed
