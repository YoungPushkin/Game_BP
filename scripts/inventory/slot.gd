extends Panel

class_name InventorySlot

@onready var icon: Sprite2D = $background/CenterContainer/item


func set_item_texture(texture: Texture2D) -> void:
	if icon == null:
		return
	icon.texture = texture
	icon.visible = texture != null
