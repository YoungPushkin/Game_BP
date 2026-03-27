extends CharacterBody2D

class_name Player

@export var walk_speed: float = 140.0
@export var run_speed: float = 230.0
@export var jump_velocity: float = -350.0
@export var ladder_speed: float = 120.0
@export var max_health: int = 4
@export var shoot_cooldown: float = 0.14
@export var hurt_anim_time: float = 0.25
@export var death_anim_time: float = 0.6
@export var knockback_force_x: float = 220.0
@export var knockback_force_y: float = -170.0
@export var knockback_duration: float = 0.12
@export var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
@export var abyss_fallback_y: float = 1200.0
@export var abyss_margin: float = 160.0
@export var auto_flip_visual_compensation: bool = true

@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hands_node: PlayerHands = $hands
@onready var body_hitbox: CollisionShape2D = $CollisionShape2D
@onready var heart_1: CanvasItem = $InventoryLayer/heart_ui/heart_1
@onready var heart_2: CanvasItem = $InventoryLayer/heart_ui/heart_2
@onready var heart_3: CanvasItem = $InventoryLayer/heart_ui/heart_3
@onready var heart_4: CanvasItem = $InventoryLayer/heart_ui/heart_4

var spawn_pos: Vector2
var jumps_used: int = 0
var was_jump_down: bool = false
var fall_y: float = INF
var health: int = 0
var hurt_time_left: float = 0.0
var death_time_left: float = 0.0
var knockback_time_left: float = 0.0
var wait_hit: bool = false
var is_dead: bool = false
var can_use_ladder: bool = false
var is_climbing: bool = false
var body_start: Vector2 = Vector2.ZERO
var hitbox_start: Vector2 = Vector2.ZERO
var sprite_offset: Vector2 = Vector2.ZERO
var hitbox_offset: Vector2 = Vector2.ZERO
var frame_cache: Dictionary = {}
var hearts_ui: Array[CanvasItem] = []

func _ready() -> void:
	add_to_group("player")
	spawn_pos = global_position
	hearts_ui = [heart_1, heart_2, heart_3, heart_4]
	health = max_health
	_store_visual_setup()
	_prepare_idle_frame()
	_update_hearts()
	_update_anim()
	_update_hands()
	_update_sprite_offset()
	_fix_hitbox_pos()

func _physics_process(delta: float) -> void:
	_fix_sprite_pos()
	if _check_fall():
		return

	hurt_time_left = maxf(hurt_time_left - delta, 0.0)
	knockback_time_left = maxf(knockback_time_left - delta, 0.0)
	death_time_left = maxf(death_time_left - delta, 0.0)

	if wait_hit:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		if get_slide_collision_count() > 0:
			_start_death()
		_update_anim()
		_update_hands()
		_fix_hitbox_pos()
		return

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_anim()
		_update_hands()
		if death_time_left <= 0.0:
			_respawn_player()
		return

	_move_player(delta)
	_update_look()
	_update_anim()
	_update_sprite_offset()
	_update_hands()
	_fix_hitbox_pos()

func _process(_delta: float) -> void:
	_fix_sprite_pos()
	_update_sprite_offset()
	_fix_hitbox_pos()

func _move_player(delta: float) -> void:
	var wants_climb: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S)
	is_climbing = can_use_ladder and wants_climb
	if is_climbing:
		velocity.x = 0.0
		if Input.is_key_pressed(KEY_W):
			velocity.y = -ladder_speed
		elif Input.is_key_pressed(KEY_S):
			velocity.y = ladder_speed
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor():
		jumps_used = 0

	if knockback_time_left > 0.0:
		move_and_slide()
		return

	var jump_down: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_action_pressed("ui_accept")
	var jump_just_pressed: bool = jump_down and not was_jump_down
	was_jump_down = jump_down

	if jump_just_pressed and jumps_used < 2:
		velocity.y = jump_velocity
		jumps_used += 1

	var input_x := Input.get_axis("ui_left", "ui_right")
	if input_x == 0.0:
		if Input.is_key_pressed(KEY_A):
			input_x = -1.0
		elif Input.is_key_pressed(KEY_D):
			input_x = 1.0

	var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	velocity.x = input_x * speed
	move_and_slide()

func _update_look() -> void:
	if hands_node == null:
		return
	if is_climbing:
		return
	var mouse := get_global_mouse_position()
	var x: float = global_position.x
	if body_sprite != null:
		x = body_sprite.global_position.x
	var facing_left := mouse.x < x
	body_sprite.flip_h = facing_left
	hands_node.set_facing_left(facing_left)


func _update_anim() -> void:
	if body_sprite == null:
		return
	if is_dead:
		_play_anim("death")
		return
	if wait_hit:
		_play_anim("Hurt")
		return
	if hurt_time_left > 0.0:
		_play_anim("Hurt")
		return
	if is_climbing:
		_play_anim("climb")
		return
	if not is_on_floor():
		if jumps_used >= 2:
			_play_anim("doublejump")
		else:
			_play_anim("jump")
		return
	if absf(velocity.x) < 1.0:
		_play_anim("idle")
		return
	_play_anim("run" if absf(velocity.x) > (walk_speed + 5.0) else "walk")

func _update_hands() -> void:
	if hands_node == null:
		return
	var in_double_jump: bool = (not is_on_floor()) and jumps_used >= 2
	var hide_hands: bool = in_double_jump or is_climbing or is_dead
	hands_node.visible = not hide_hands

func _check_fall() -> bool:
	var limit_y: float = fall_y
	if not is_finite(limit_y):
		limit_y = abyss_fallback_y
	if global_position.y <= limit_y:
		return false
	_respawn_player()
	return true

func _play_anim(anim_name: String) -> void:
	if body_sprite.sprite_frames != null and body_sprite.sprite_frames.has_animation(anim_name):
		if body_sprite.animation != anim_name:
			body_sprite.play(anim_name)

func take_damage(amount: int = 1, from_position: Vector2 = Vector2.ZERO, has_from_position: bool = false) -> void:
	var facing_left := body_sprite != null and body_sprite.flip_h
	if is_dead or wait_hit:
		return

	var knockback_dir: float = 1.0 if facing_left else -1.0
	if has_from_position:
		knockback_dir = signf(global_position.x - from_position.x)
		if knockback_dir == 0.0:
			knockback_dir = 1.0 if facing_left else -1.0

	health = max(0, health - amount)
	_update_hearts()
	hurt_time_left = hurt_anim_time

	if health == 0:
		wait_hit = true
		knockback_time_left = 0.0
	else:
		knockback_time_left = knockback_duration

	velocity = Vector2(knockback_dir * knockback_force_x, knockback_force_y)

func _start_death() -> void:
	wait_hit = false
	is_dead = true
	death_time_left = death_anim_time
	hurt_time_left = 0.0
	velocity = Vector2.ZERO

func set_checkpoint(new_spawn_position: Vector2) -> void:
	spawn_pos = new_spawn_position

func set_fall_limit(limit_y: float) -> void:
	fall_y = limit_y

func set_can_use_ladder(value: bool) -> void:
	can_use_ladder = value
	if not can_use_ladder:
		is_climbing = false

func can_shoot() -> bool:
	return not is_climbing and not is_dead and not wait_hit

func _respawn_player() -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	health = max_health
	is_dead = false
	hurt_time_left = 0.0
	death_time_left = 0.0
	knockback_time_left = 0.0
	wait_hit = false
	can_use_ladder = false
	is_climbing = false
	_update_hearts()
	jumps_used = 0
	was_jump_down = false
	if hands_node != null:
		hands_node.visible = true

func get_enemy_target_position() -> Vector2:
	if body_hitbox != null:
		return body_hitbox.global_position
	if body_sprite != null:
		return body_sprite.global_position + hitbox_offset
	return global_position

func get_enemy_target_half_width() -> float:
	if body_hitbox == null or body_hitbox.shape == null:
		return 8.0
	if body_hitbox.shape is RectangleShape2D:
		var rect := body_hitbox.shape as RectangleShape2D
		return rect.size.x * 0.5
	if body_hitbox.shape is CircleShape2D:
		var circle := body_hitbox.shape as CircleShape2D
		return circle.radius
	return 8.0

func _update_hearts() -> void:
	var hearts_count: int = clampi(health, 0, hearts_ui.size())
	for i in hearts_ui.size():
		if hearts_ui[i] != null:
			hearts_ui[i].visible = i < hearts_count

func _fix_sprite_pos() -> void:
	if body_sprite == null:
		return
	body_sprite.position = body_start

func _fix_hitbox_pos() -> void:
	if body_hitbox == null:
		return
	body_hitbox.position = hitbox_start

func _update_sprite_offset() -> void:
	if body_sprite == null:
		return
	if not auto_flip_visual_compensation:
		body_sprite.offset = sprite_offset
		return
	var next_offset: Vector2 = sprite_offset
	if body_sprite.flip_h:
		next_offset.x += _calc_frame_shift() * 2.0
	body_sprite.offset = next_offset

func _store_visual_setup() -> void:
	if body_sprite != null:
		body_sprite.centered = true
		body_start = body_sprite.position
		sprite_offset = body_sprite.offset
	if body_hitbox != null:
		hitbox_start = body_hitbox.position
	if body_sprite != null and body_hitbox != null:
		hitbox_offset = body_hitbox.position - body_sprite.position

func _prepare_idle_frame() -> void:
	if body_sprite == null:
		return
	if body_sprite.sprite_frames == null:
		return
	if not body_sprite.sprite_frames.has_animation("idle"):
		return
	body_sprite.play("idle")
	body_sprite.frame = 0
	body_sprite.stop()

func _calc_frame_shift() -> float:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return 0.0
	var key := "%s:%d" % [String(body_sprite.animation), body_sprite.frame]
	if frame_cache.has(key):
		return float(frame_cache[key])

	var texture: Texture2D = body_sprite.sprite_frames.get_frame_texture(body_sprite.animation, body_sprite.frame)
	if texture == null:
		frame_cache[key] = 0.0
		return 0.0

	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		frame_cache[key] = 0.0
		return 0.0

	var min_x := image.get_width()
	var max_x := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.05:
				continue
			if x < min_x:
				min_x = x
			if x > max_x:
				max_x = x

	if max_x < 0:
		frame_cache[key] = 0.0
		return 0.0

	var pic_mid := (float(min_x) + float(max_x)) * 0.5
	var frame_mid := (float(image.get_width()) - 1.0) * 0.5
	var shift := pic_mid - frame_mid
	frame_cache[key] = shift
	return shift
