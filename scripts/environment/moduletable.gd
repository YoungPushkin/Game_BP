extends "res://scripts/environment/interactive/interactive_area.gd"

class_name ModuleTable

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var module_icon: Sprite2D = $Marker2D/PlacedModule

@export var animation_start_delay: float = 1.0
@export var activates_group: StringName = &"moduletable_active"

var has_module: bool = false

func _ready() -> void:
	super._ready()
	if module_icon != null:
		module_icon.visible = false
	_reset_anim()

func can_interact() -> bool:
	if has_module:
		return false
	return super.can_interact()

func _handle_interaction() -> void:
	var inventory_node := PlayerRefs.get_inv(player)
	if inventory_node == null:
		return

	var ok: bool = inventory_node.remove_one_module()
	if not ok:
		return

	_put_module()

func _put_module() -> void:
	has_module = true
	add_to_group(_get_group_name())
	if module_icon != null:
		module_icon.visible = true
	_start_anim()

func _start_anim() -> void:
	if animation_start_delay > 0.0:
		await get_tree().create_timer(animation_start_delay).timeout
	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("moduletable"):
		anim.frame = 0
		anim.play("moduletable")

func _get_group_name() -> String:
	if has_meta("activates_group"):
		return str(get_meta("activates_group"))
	var group_name := str(activates_group)
	if group_name.is_empty():
		return "moduletable_active"
	return group_name

func _reset_anim() -> void:
	if anim == null:
		return
	if anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation("moduletable"):
		return
	anim.sprite_frames.set_animation_loop("moduletable", false)
	anim.animation = "moduletable"
	anim.frame = 0
	anim.stop()
