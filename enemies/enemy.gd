class_name Enemy
extends Area2D

@export_range(1, 99, 1, "or_greater") var max_health: int = 1

@onready var health: int = max_health


func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return
	health = maxi(health - amount, 0)
	if health == 0:
		queue_free()
