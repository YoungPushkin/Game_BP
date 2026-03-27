extends Node2D

class_name PlayerHands

@export var left_hand_position: Vector2 = Vector2(-8.0, 0.0)
@export var right_hand_position: Vector2 = Vector2(4.0, 0.0)
var left: bool = false

func _process(_delta: float) -> void:
	position = left_hand_position if left else right_hand_position
	look_at(get_global_mouse_position())

	rotation_degrees = wrapf(rotation_degrees, 0.0, 360.0)
	if rotation_degrees > 90.0 and rotation_degrees < 270.0:
		scale.y = -1.0
	else:
		scale.y = 1.0

func set_facing_left(value: bool) -> void:
	left = value
