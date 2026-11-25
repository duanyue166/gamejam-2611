class_name PlayerStone
extends CharacterBody2D

const DIRT_ATTACK_SCENE: PackedScene = preload("res://combat/dirt_attack_area.tscn")

@onready var _platform: AnimatableBody2D = $Platform
@onready var _platform_timer: Timer = $PlatformTimer
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _impact: AnimatedSprite2D = $VFX
@onready var _falling_attack: EnemyAttackArea = $FallingAttackArea
@onready var _collision_shape: CollisionShape2D = $CollisionShape

var _was_on_floor := false
var _gravity := Vector2.ZERO


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	move_as_stone(_gravity, delta)


func begin(player_up: Vector2, player_velocity: Vector2, grounded: bool) -> void:
	up_direction = player_up
	velocity = -up_direction * maxf(player_velocity.dot(-up_direction), 0.0)
	_was_on_floor = grounded
	if up_direction == Vector2.DOWN:
		var mirror_y := 2.0 * _collision_shape.position.y
		_impact.position.y = mirror_y - _impact.position.y
		_impact.flip_v = true
		_falling_attack.position.y = mirror_y - _falling_attack.position.y
		_falling_attack.scale.y = -1.0


func move_as_stone(gravity: Vector2, delta: float) -> void:
	_gravity = gravity
	velocity += gravity * delta
	var previous_position := global_position
	move_and_slide()
	var motion := global_position - previous_position
	var on_floor := is_on_floor()
	# Use the actual fall motion, including the last segment before hitting the floor.
	if not _was_on_floor and motion.dot(up_direction) < 0.0:
		_falling_attack.hit_along_motion(motion)
	if on_floor and not _was_on_floor:
		_falling_attack.reset_hits()
		_spawn_dirt_attack()
		_impact.show()
		_impact.play(&"pound")
		_impact.set_frame_and_progress(0, 0.0)
	_was_on_floor = on_floor


func _spawn_dirt_attack() -> void:
	var dirt_attack := DIRT_ATTACK_SCENE.instantiate() as Area2D
	get_parent().add_child(dirt_attack)
	dirt_attack.global_position = global_position
	if up_direction == Vector2.DOWN:
		dirt_attack.global_position.y += 2.0 * _collision_shape.position.y


func leave_as_platform() -> void:
	velocity = Vector2.ZERO
	# A stone left in midair still hovers until something pushes it.
	if not is_on_floor():
		_gravity = Vector2.ZERO
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	set_physics_process(true)
	_platform_timer.start()


func fade_out() -> void:
	set_physics_process(false)
	_platform.collision_layer = 0
	collision_mask = 0
	_animation_player.play(&"fade_out")


func _on_animation_finished(animation: StringName) -> void:
	if animation == &"fade_out":
		queue_free()
