class_name InteractButton
extends Interactable

signal activated

var _is_pressed := false

@onready var _handle: Polygon2D = $Handle


func interact(_player: Node2D) -> void:
	if not is_interactable():
		return

	_is_pressed = true
	create_tween().tween_property(_handle, ^"rotation_degrees", 55.0, 0.15)
	activated.emit()


func is_interactable() -> bool:
	return super.is_interactable() and not _is_pressed
