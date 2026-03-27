extends "res://scripts/environment/interactive/interactive_area.gd"

var used: bool = false

func _ready() -> void:
	super._ready()

func can_interact() -> bool:
	if used:
		return false
	return super.can_interact()

func _handle_interaction() -> void:
	if used or player == null:
		return

	var inventory_node := PlayerRefs.get_inv(player)
	if inventory_node == null:
		return

	var was_added: bool = inventory_node.add_module(_current_icon())
	if not was_added:
		return

	used = true
	queue_free()

func _current_icon() -> Texture2D:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return null
	if sprite.sprite_frames == null:
		return null
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return null
	return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
