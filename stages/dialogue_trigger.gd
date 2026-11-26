class_name DialogueTrigger
extends Area2D

signal dialogue_requested(player: DebugPlayer, dialogue: DialogueData)

@export var dialogue: DialogueData
## By default this trigger plays once for each instance of the stage.
@export var repeatable := false

var _has_played := false


func mark_started() -> void:
	_has_played = true


func _on_body_entered(body: Node2D) -> void:
	var player := body as DebugPlayer
	if player != null and dialogue != null and (repeatable or not _has_played):
		dialogue_requested.emit(player, dialogue)
