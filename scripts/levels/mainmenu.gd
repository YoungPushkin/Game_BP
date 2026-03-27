extends CanvasLayer

class_name MainMenu

const LEVEL_1_SCENE := "res://scenes/levels/Level1.tscn"
const LEVEL_2_SCENE := "res://scenes/levels/level_2.tscn"
const LEVEL_3_SCENE := "res://scenes/levels/level_3.tscn"

var is_pause := false

@onready var fon: Sprite2D = $fon
@onready var fundament: Sprite2D = $fundament
@onready var main1: Node2D = $fundament/main1
@onready var main2: Node2D = $fundament/main2

@onready var start_button: TextureButton = $fundament/main1/start/start
@onready var levels_button: TextureButton = $fundament/main1/levels/levels
@onready var exit_button: TextureButton = $fundament/main1/exit/exit

@onready var godot_button: TextureButton = $fundament/main2/godot/TextureButton
@onready var ldtk_button: TextureButton = $fundament/main2/ldtk/TextureButton
@onready var tiled_button: TextureButton = $fundament/main2/tiled/TextureButton
@onready var back_button: TextureButton = $fundament/main2/back/TextureButton

func _ready() -> void:
	fon.visible = true
	fundament.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	_show_main()

	start_button.pressed.connect(_start)
	levels_button.pressed.connect(_show_levels)
	exit_button.pressed.connect(_exit)

	godot_button.pressed.connect(_start)
	ldtk_button.pressed.connect(_open_2)
	tiled_button.pressed.connect(_open_3)
	back_button.pressed.connect(_show_main)

func show_as_pause_menu() -> void:
	is_pause = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	fon.visible = false
	fundament.self_modulate = Color(1.0, 1.0, 1.0, 0.7)
	_show_main()

func _show_main() -> void:
	main1.visible = true
	main2.visible = false

func _show_levels() -> void:
	main1.visible = false
	main2.visible = true

func _start() -> void:
	_go(LEVEL_1_SCENE)

func _open_2() -> void:
	_go(LEVEL_2_SCENE)

func _open_3() -> void:
	_go(LEVEL_3_SCENE)

func _exit() -> void:
	if is_pause:
		get_tree().paused = false
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_pause:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		queue_free()

func _go(scene_path: String) -> void:
	if is_pause:
		get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
