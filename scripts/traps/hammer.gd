extends Area2D

class_name HammerTrap

@export var anim_name: StringName = &"hammer"
@export var damage: int = 9999
@export var hit_cooldown: float = 0.4
@export var active_frame_from: int = 0
@export var active_frame_to: int = 7
@export var cycle_speed: float = 1.0
@export_range(0.0, 1.0, 0.01) var start_phase: float = 0.0
@export var frame_y_offsets: PackedFloat32Array = PackedFloat32Array([0.0, 4.0, 10.0, 18.0, 28.0, 22.0, 12.0, 4.0])
@export var frame_y_scales: PackedFloat32Array = PackedFloat32Array([1.0, 1.1, 1.25, 1.45, 1.7, 1.45, 1.2, 1.05])

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

var last_hit_time: Dictionary = {}
var bodies_in_range: Array[Node] = []
var base_hitbox_position: Vector2

func _ready() -> void:
	add_to_group("trap")
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		push_warning("Hammer: animation not found: %s" % [anim_name])
		return

	monitoring = true
	monitorable = true
	collision_mask = -1
	hitbox.disabled = false
	base_hitbox_position = hitbox.position
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	anim.play(anim_name)
	anim.speed_scale = cycle_speed
	_apply_start_phase()

func _physics_process(_delta: float) -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		return

	var frame: int = anim.frame
	_apply_hitbox_motion(frame)
	var is_active: bool = frame >= active_frame_from and frame <= active_frame_to

	if not is_active:
		return

	var now: float = Time.get_ticks_msec() / 1000.0
	for body in get_overlapping_bodies():
		if body == null:
			continue
		if not is_instance_valid(body):
			continue
		if not _can_damage(body):
			continue

		var prev: float = last_hit_time.get(body, -999.0)
		if now - prev >= hit_cooldown:
			last_hit_time[body] = now
			_apply_damage(body)

func _on_body_entered(body: Node) -> void:
	if not bodies_in_range.has(body):
		bodies_in_range.append(body)
	if body != null and _can_damage(body):
		_apply_damage(body)

func _on_body_exited(body: Node) -> void:
	bodies_in_range.erase(body)

func _apply_start_phase() -> void:
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(anim_name):
		return
	var count: int = anim.sprite_frames.get_frame_count(anim_name)
	if count <= 0:
		return
	var phase: float = wrapf(start_phase, 0.0, 1.0)
	var frame_index: int = int(floor(phase * float(count)))
	if frame_index >= count:
		frame_index = count - 1
	anim.frame = frame_index

func _apply_hitbox_motion(frame: int) -> void:
	var index: int = frame
	if frame_y_offsets.size() > 0:
		if index >= frame_y_offsets.size():
			index = frame_y_offsets.size() - 1
		hitbox.position = base_hitbox_position + Vector2(0.0, frame_y_offsets[index])
	else:
		hitbox.position = base_hitbox_position

	var scale_index: int = frame
	if frame_y_scales.size() > 0:
		if scale_index >= frame_y_scales.size():
			scale_index = frame_y_scales.size() - 1
		hitbox.scale = Vector2(1.0, frame_y_scales[scale_index])
	else:
		hitbox.scale = Vector2.ONE

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
