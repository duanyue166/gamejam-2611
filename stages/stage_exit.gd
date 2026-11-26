@tool
class_name StageExit
extends Area2D

signal stage_change_requested(player: DebugPlayer, stage_path: String, spawn_id: StringName)
signal target_stage_changed

## Destination scene inheriting StageTemplate, loaded on entry to allow return exits.
## Leave empty to disable this exit.
@export_file("*.tscn", "*.scn") var target_stage_path: String:
	set(value):
		if target_stage_path != value:
			target_stage_path = value
			target_stage_changed.emit()

@export var target_spawn: StringName = &"default"

var _arrival_player: DebugPlayer


func _ready() -> void:
	set_physics_process(false)


func suppress_arrival_overlap(player: DebugPlayer) -> void:
	if monitoring and not target_stage_path.is_empty() and _intersects_player(player):
		_arrival_player = player
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_arrival_player) or not _intersects_player(_arrival_player):
		_arrival_player = null
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	var player := body as DebugPlayer
	if player != null and player != _arrival_player and not target_stage_path.is_empty():
		stage_change_requested.emit(player, target_stage_path, target_spawn)


func _intersects_player(player: DebugPlayer) -> bool:
	# Area2D's overlap list is still stale when Main places the player.
	for gate_owner in get_shape_owners():
		if is_shape_owner_disabled(gate_owner):
			continue
		var gate_transform := global_transform * shape_owner_get_transform(gate_owner)
		for player_owner in player.get_shape_owners():
			if player.is_shape_owner_disabled(player_owner):
				continue
			var player_transform := player.global_transform * player.shape_owner_get_transform(player_owner)
			for gate_index in shape_owner_get_shape_count(gate_owner):
				var gate_shape := shape_owner_get_shape(gate_owner, gate_index)
				for player_index in player.shape_owner_get_shape_count(player_owner):
					var player_shape := player.shape_owner_get_shape(player_owner, player_index)
					if gate_shape.collide(gate_transform, player_shape, player_transform):
						return true
	return false
