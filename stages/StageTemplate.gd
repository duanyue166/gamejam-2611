class_name StageTemplate
extends Node2D


signal stage_exit_entered(player: DebugPlayer, target_stage_path: String)

@onready var spawn_point: Marker2D = $SpawnPoint


func spawn(player: Node2D, spawn_id: StringName = &"default") -> void:
	var marker := get_spawn_point(spawn_id)

	if player.get_parent():
		player.reparent($Actors)

	else:
		$Actors.add_child(player)

	player.global_position = marker.global_position


func get_spawn_point(id: StringName) -> Marker2D:
	if id == &"default":
		return spawn_point
	return null
