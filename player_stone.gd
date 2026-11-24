class_name PlayerStone
extends CharacterBody2D

@onready var _platform: AnimatableBody2D = $Platform
@onready var _platform_timer: Timer = $PlatformTimer
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _impact: AnimatedSprite2D = $VFX

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
		_impact.position.y = 2.0 * $CollisionShape.position.y - _impact.position.y
		_impact.flip_v = true


func move_as_stone(gravity: Vector2, delta: float) -> void:
	_gravity = gravity
	velocity += gravity * delta
	move_and_slide()
	if is_on_floor() and not _was_on_floor:
		_impact.show()
		_impact.play(&"pound")
		_impact.set_frame_and_progress(0, 0.0)
	_was_on_floor = is_on_floor()


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
