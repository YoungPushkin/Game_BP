extends Node2D

class_name PlayerGun

const DEFAULT_GUN_TEXTURE = preload("res://assets/player/2 Guns/7_1.png")
const DEFAULT_BULLET_TEXTURE = preload("res://assets/player/5 Bullets/7_1.png")

@onready var muzzle: Marker2D = $muzzle
@onready var gun_sprite: Sprite2D = $Sprite2D

var bullet_tex: Texture2D = DEFAULT_BULLET_TEXTURE
var shot_cd: float = 0.0
var player_node: Player = null

func _ready() -> void:
	player_node = get_parent().get_parent() as Player
	if gun_sprite != null and gun_sprite.texture == null:
		gun_sprite.texture = DEFAULT_GUN_TEXTURE
	if bullet_tex == null:
		bullet_tex = DEFAULT_BULLET_TEXTURE

func _process(delta: float) -> void:
	shot_cd = maxf(shot_cd - delta, 0.0)

	if player_node != null and not player_node.can_shoot():
		return

	if Input.is_action_just_pressed("fire"):
		if shot_cd > 0.0:
			return
		var bullet_scene := _bullet_scene()
		if bullet_scene == null:
			return
		var bullet_instance = bullet_scene.instantiate()
		if bullet_instance == null:
			return
		get_tree().current_scene.add_child(bullet_instance)
		bullet_instance.global_position = muzzle.global_position
		bullet_instance.global_rotation = muzzle.global_rotation
		_set_bullet_tex(bullet_instance)
		shot_cd = _shot_interval()

func equip_weapon(new_gun_texture: Texture2D, new_bullet_texture: Texture2D) -> void:
	if new_gun_texture != null and gun_sprite != null:
		gun_sprite.texture = new_gun_texture
	if new_bullet_texture != null:
		bullet_tex = new_bullet_texture

func _set_bullet_tex(bullet_instance: Node) -> void:
	if bullet_instance == null or bullet_tex == null:
		return
	var sprite := bullet_instance.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = bullet_tex

func _shot_interval() -> float:
	if player_node == null:
		return 0.14
	return player_node.shoot_cooldown

func _bullet_scene() -> PackedScene:
	if player_node == null:
		return null
	return player_node.bullet_scene
