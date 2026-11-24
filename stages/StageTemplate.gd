class_name StageTemplate
extends Node2D


@onready var spawn_point: Node2D = $SpawnPoint

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn(player: Node2D, spawn_id: StringName = &"default") -> void:
	var spawn_point := get_spawn_point(spawn_id)

	if player.get_parent():
		player.reparent($Actors)

	else:
		$Actors.add_child(player)

	player.global_position = spawn_point.global_position


func get_spawn_point(id: StringName) -> Marker2D:
	if id == &"default":
		return spawn_point
	return null
