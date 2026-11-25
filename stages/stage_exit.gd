extends Area2D

## Destination scene inheriting StageTemplate, loaded on entry to allow return exits.
## Leave empty to disable this exit.
@export_file("*.tscn", "*.scn") var target_stage_path: String


func _on_body_entered(body: Node2D) -> void:
	var player := body as DebugPlayer
	if player == null or target_stage_path.is_empty():
		return

	var ancestor := get_parent()
	while ancestor != null:
		var stage := ancestor as StageTemplate
		if stage != null:
			stage.stage_exit_entered.emit(player, target_stage_path)
			return
		ancestor = ancestor.get_parent()
