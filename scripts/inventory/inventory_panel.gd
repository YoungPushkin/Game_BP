extends Panel

class_name InventoryPanel

const DEFAULT_GUN_TEXTURE = preload("res://assets/player/2 Guns/7_1.png")
const DEFAULT_BULLET_TEXTURE = preload("res://assets/player/5 Bullets/7_1.png")

@onready var slot_1: Panel = $slot
@onready var slot_2: Panel = $slot2
@onready var slot_3: Panel = $slot3
@onready var slot_4: Panel = $slot4
@onready var slot_5: Panel = $slot5

var player: Player = null
var gun: PlayerGun = null
var is_open: bool = false
var tab_down: bool = false
var one_down: bool = false
var two_down: bool = false
var modules: Array[Texture2D] = []

var slots: Array = [
	{"gun": null, "bullet": null},
	{"gun": null, "bullet": null}
]

func _ready() -> void:
	_place_bottom_center()
	_get_refs()
	_set_inventory_visible(false)
	_add_default_gun()
	_update_slots()

func _process(_delta: float) -> void:
	_handle_inventory_toggle()
	_handle_hotkeys()

func add_weapon_skin(gun_texture: Texture2D, bullet_texture: Texture2D) -> void:
	if gun_texture == null or bullet_texture == null:
		return

	var existing_index: int = _find_weapon(gun_texture, bullet_texture)
	if existing_index == 0:
		_use_slot_1()
		return
	if existing_index == 1:
		_swap_slots(0, 1)
		_use_slot_1()
		_update_slots()
		return

	if slots[0]["gun"] == null:
		slots[0] = {"gun": gun_texture, "bullet": bullet_texture}
	else:
		slots[1] = slots[0]
		slots[0] = {"gun": gun_texture, "bullet": bullet_texture}

	_use_slot_1()
	_update_slots()

func add_module(module_icon: Texture2D) -> bool:
	if module_icon == null:
		return false
	if modules.size() >= 3:
		return false
	modules.append(module_icon)
	_update_slots()
	return true

func take_first_module() -> Texture2D:
	if modules.is_empty():
		return null
	var module_icon: Texture2D = modules.pop_front()
	_update_slots()
	return module_icon

func remove_one_module() -> bool:
	if modules.is_empty():
		return false
	modules.pop_front()
	_update_slots()
	return true

func _place_bottom_center() -> void:
	anchors_preset = Control.PRESET_CENTER_BOTTOM

func _get_refs() -> void:
	player = PlayerRefs.get_player_from_inv(self)
	gun = PlayerRefs.get_gun(player)

func _add_default_gun() -> void:
	if slots[0]["gun"] != null and slots[0]["bullet"] != null:
		return
	slots[0] = {"gun": DEFAULT_GUN_TEXTURE, "bullet": DEFAULT_BULLET_TEXTURE}
	_use_slot_1()

func _set_inventory_visible(value: bool) -> void:
	is_open = value
	visible = value

func _handle_inventory_toggle() -> void:
	var tab_pressed: bool = Input.is_key_pressed(KEY_TAB)
	var tab_just_pressed: bool = tab_pressed and not tab_down
	tab_down = tab_pressed
	if tab_just_pressed:
		_set_inventory_visible(not is_open)

func _handle_hotkeys() -> void:
	var key_1_pressed: bool = Input.is_key_pressed(KEY_1)
	var key_1_just_pressed: bool = key_1_pressed and not one_down
	one_down = key_1_pressed
	if key_1_just_pressed:
		_use_slot_1()

	var key_2_pressed: bool = Input.is_key_pressed(KEY_2)
	var key_2_just_pressed: bool = key_2_pressed and not two_down
	two_down = key_2_pressed
	if key_2_just_pressed and slots[1]["gun"] != null:
		_swap_slots(0, 1)
		_use_slot_1()
		_update_slots()

func _use_slot_1() -> void:
	if gun == null or not is_instance_valid(gun):
		return
	var gun_texture: Texture2D = slots[0]["gun"]
	var bullet_texture: Texture2D = slots[0]["bullet"]
	if gun_texture == null or bullet_texture == null:
		return
	gun.equip_weapon(gun_texture, bullet_texture)

func _swap_slots(a: int, b: int) -> void:
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp

func _find_weapon(gun_texture: Texture2D, bullet_texture: Texture2D) -> int:
	for i in slots.size():
		var slot_data: Dictionary = slots[i]
		if slot_data["gun"] == gun_texture and slot_data["bullet"] == bullet_texture:
			return i
	return -1

func _update_slots() -> void:
	_set_slot_texture(slot_1, slots[0]["gun"])

	var module_index: int = 0
	var second_weapon: Texture2D = slots[1]["gun"]
	if second_weapon != null:
		_set_slot_texture(slot_2, second_weapon)
	else:
		if modules.size() > 0:
			_set_slot_texture(slot_2, modules[0])
			module_index = 1
		else:
			_set_slot_texture(slot_2, null)

	_set_slot_texture(slot_3, modules[module_index] if module_index < modules.size() else null)
	_set_slot_texture(slot_4, modules[module_index + 1] if (module_index + 1) < modules.size() else null)
	_set_slot_texture(slot_5, modules[module_index + 2] if (module_index + 2) < modules.size() else null)

func _set_slot_texture(slot_node: Panel, texture: Texture2D) -> void:
	if slot_node is InventorySlot:
		(slot_node as InventorySlot).set_item_texture(texture)
