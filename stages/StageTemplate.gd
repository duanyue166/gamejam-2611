class_name StageTemplate
extends Node2D


const DEFAULT_SPAWN := &"default"


# Also used by the Inspector on off-tree stages with non-tool scripts.
static func collect_spawn_points(stage: Node) -> Dictionary[StringName, Marker2D]:
	var points: Dictionary[StringName, Marker2D] = {}
	var default_marker := stage.get_node_or_null(^"SpawnPoint") as Marker2D
	if default_marker != null:
		points[DEFAULT_SPAWN] = default_marker

	var container := stage.get_node_or_null(^"SpawnPoints")
	if container != null:
		for child in container.get_children():
			if child is Marker2D and not points.has(child.name):
				points[child.name] = child
	return points


func get_spawn_point(id: StringName) -> Marker2D:
	return collect_spawn_points(self).get(id)


func get_gates() -> Array[StageExit]:
	var gates: Array[StageExit] = []
	for area in find_children("*", "Area2D", true, false):
		if area is StageExit:
			gates.append(area)
	return gates


func get_actor_container() -> Node2D:
	return $Actors


func on_enter(_player: DebugPlayer) -> void:
	pass


func on_exit(_player: DebugPlayer) -> void:
	pass
