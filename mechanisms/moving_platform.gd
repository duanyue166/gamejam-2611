class_name MovingPlatform
extends AnimatableBody2D

@export var anchor_a: Marker2D
@export var anchor_b: Marker2D
@export_range(1.0, 1000.0, 1.0, "or_greater", "suffix:px/s") var move_speed: float = 160.0

var _target_anchor: Marker2D


func _ready() -> void:
	set_physics_process(false)
	if is_instance_valid(anchor_a):
		global_position = anchor_a.global_position


func move_on() -> void:
	_move_to(anchor_b)


func move_back() -> void:
	_move_to(anchor_a)


func _move_to(anchor: Marker2D) -> void:
	if not is_instance_valid(anchor):
		return
	_target_anchor = anchor
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target_anchor):
		set_physics_process(false)
		return

	var target_position := _target_anchor.global_position
	var next_position := global_position.move_toward(target_position, move_speed * delta)
	global_position = next_position
	if next_position == target_position:
		set_physics_process(false)
