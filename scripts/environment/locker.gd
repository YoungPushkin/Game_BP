extends "res://scripts/environment/interactive/interactive_area.gd"

const NEW_GUN_TEXTURE = preload("res://assets/player/2 Guns/10_1.png")
const NEW_BULLET_TEXTURE = preload("res://assets/player/5 Bullets/10.png")

var is_used: bool = false

func _ready() -> void:
	super._ready()

func can_interact() -> bool:
	if is_used:
		return false
	return super.can_interact()

func _handle_interaction() -> void:
	var inventory_node := _get_inv()
	if inventory_node != null:
		inventory_node.add_weapon_skin(NEW_GUN_TEXTURE, NEW_BULLET_TEXTURE)
	else:
		var gun_node := _get_gun()
		if gun_node != null:
			gun_node.equip_weapon(NEW_GUN_TEXTURE, NEW_BULLET_TEXTURE)
	is_used = true

func _interaction_keys_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_F)

func _get_gun() -> PlayerGun:
	return PlayerRefs.get_gun(player)

func _get_inv() -> InventoryPanel:
	return PlayerRefs.get_inv(player)
