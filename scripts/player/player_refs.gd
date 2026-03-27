extends RefCounted

class_name PlayerRefs

static func get_player_from_inv(inventory_node: InventoryPanel) -> Player:
	if inventory_node == null:
		return null
	var inventory_layer := inventory_node.get_parent()
	if inventory_layer == null:
		return null
	return inventory_layer.get_parent() as Player

static func get_inv(player: Player) -> InventoryPanel:
	if player == null:
		return null
	return player.get_node_or_null("InventoryLayer/inventory") as InventoryPanel

static func get_gun(player: Player) -> PlayerGun:
	if player == null:
		return null
	return player.get_node_or_null("hands/guns") as PlayerGun
