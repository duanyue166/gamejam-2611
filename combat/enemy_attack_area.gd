class_name EnemyAttackArea
extends Area2D

@export var damage: int = 1

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

var _hit_enemies: Dictionary[int, bool] = {}
var _sweep_query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	_sweep_query.shape = _collision_shape.shape
	_sweep_query.collision_mask = collision_mask
	_sweep_query.collide_with_bodies = false
	_sweep_query.collide_with_areas = true


func hit_along_motion(motion: Vector2) -> void:
	_sweep_query.transform = _collision_shape.global_transform.translated(-motion)
	_sweep_query.motion = motion
	for hit in get_world_2d().direct_space_state.intersect_shape(_sweep_query):
		hit_enemy(hit.collider)


func hit_enemy(area: Area2D) -> void:
	var enemy := area as Enemy
	if enemy == null or enemy.is_queued_for_deletion():
		return
	var enemy_id := enemy.get_instance_id()
	if _hit_enemies.has(enemy_id):
		return
	_hit_enemies[enemy_id] = true
	enemy.take_damage(damage)


func reset_hits() -> void:
	_hit_enemies.clear()
