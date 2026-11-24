class_name Interactable
extends Area2D

@export var interaction_text: String = "交互"
@export var can_interact: bool = true


func interact(_player: Node2D) -> void:
	pass


func get_interaction_text() -> String:
	return interaction_text


func is_interactable() -> bool:
	return can_interact
