extends StaticBody2D

class_name Door

@export var checkpoint_offset: Vector2 = Vector2(48, 0)
@export_file("*.tscn") var next_scene_path: String = ""
@export var fade_duration: float = 0.45

const PLAYER_DETECT_MASK := (1 << 0) | (1 << 1)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var passage_area: Area2D = $PassageArea

enum DoorState { CLOSED, OPENING, OPEN, CLOSING }

var state: DoorState = DoorState.CLOSED
var side: float = 0.0
var started: bool = false

func _ready() -> void:
	_setup_animation()
	body_collision.disabled = false
	passage_area.collision_mask = PLAYER_DETECT_MASK
	passage_area.monitoring = true
	passage_area.monitorable = true
	passage_area.body_entered.connect(_on_passage_body_entered)
	passage_area.body_exited.connect(_on_passage_body_exited)

func open_from_terminal() -> void:
	if state != DoorState.CLOSED:
		return

	state = DoorState.OPENING
	body_collision.set_deferred("disabled", false)
	_play_door(false)

func _close_door(player: Node, exit_side: float) -> void:
	if state != DoorState.OPEN:
		return

	state = DoorState.CLOSING
	body_collision.set_deferred("disabled", false)
	_play_door(true)

	if player is Player:
		(player as Player).set_checkpoint(global_position + Vector2(checkpoint_offset.x * exit_side, checkpoint_offset.y))

	if started or next_scene_path.is_empty():
		return

	started = true
	_go_next_scene(player)

func _setup_animation() -> void:
	if anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation("door"):
		return
	anim.sprite_frames.set_animation_loop("door", false)
	anim.animation_finished.connect(_on_animation_finished)
	anim.animation = "door"
	anim.frame = 0

func _play_door(backwards: bool) -> void:
	if anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation("door"):
		return
	if backwards:
		anim.play_backwards("door")
	else:
		anim.play("door")

func _on_passage_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	var enter: float = signf(body.global_position.x - global_position.x)
	side = enter if enter != 0.0 else 1.0

func _on_passage_body_exited(body: Node) -> void:
	if state != DoorState.OPEN or not body.is_in_group("player"):
		return

	var out_side: float = signf(body.global_position.x - global_position.x)
	if out_side == 0.0:
		out_side = side

	if out_side != side:
		_close_door(body, out_side)

func _on_animation_finished() -> void:
	if state == DoorState.OPENING and anim.animation == "door":
		state = DoorState.OPEN
		body_collision.set_deferred("disabled", true)
		anim.frame = anim.sprite_frames.get_frame_count("door") - 1
	elif state == DoorState.CLOSING and anim.animation == "door":
		state = DoorState.CLOSED
		body_collision.set_deferred("disabled", false)
		anim.frame = 0

func _go_next_scene(player: Node) -> void:
	if player is CanvasItem:
		(player as CanvasItem).visible = false
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	var root := get_tree().current_scene
	if root == null:
		get_tree().change_scene_to_file(next_scene_path)
		return

	var layer := CanvasLayer.new()
	layer.name = "scene_transition_fade"
	layer.layer = 100

	var rect := ColorRect.new()
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	root.add_child(layer)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 1.0, fade_duration)
	tween.finished.connect(func() -> void:
		get_tree().change_scene_to_file(next_scene_path)
	)
