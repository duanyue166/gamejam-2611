class_name DebugPlayer
extends CharacterBody2D

signal health_changed(current_health: int, maximum_health: int)
signal died

enum AnimationState { IDLE, WALK, RUN, JUMP, FALL, FALL_LOOP, ATTACK, ATTACK_END, HURT }

const ANIMATIONS: Dictionary[AnimationState, StringName] = {
	AnimationState.IDLE: &"idle",
	AnimationState.WALK: &"walk",
	AnimationState.RUN: &"run",
	AnimationState.JUMP: &"jump",
	AnimationState.FALL: &"fall",
	AnimationState.FALL_LOOP: &"fall_loop",
	AnimationState.ATTACK: &"attack",
	AnimationState.ATTACK_END: &"attack_end",
	AnimationState.HURT: &"hurt",
}
const WALK_MIN_SPEED := 5.0
const RUN_SPEED_RATIO := 0.7
const RUN_EXIT_RATIO := 0.75
const COYOTE_TIME := 0.1
const INVULNERABILITY_DURATION := 1.0
const STONE_EXIT_INVULNERABILITY_DURATION := 1.0
const BLINK_INTERVAL := 0.1
const KNOCKBACK_DURATION := 0.2
const HURT_BOUNCE_SPEED := 320.0
const REWIND_SHADOW_SCENE: PackedScene = preload("res://rewind_shadow.tscn")
const PLAYER_STONE_SCENE: PackedScene = preload("res://player_stone.tscn")

@export var movement_data : PlayerMovementData
@export var rewind_effect_layer: Node2D
@export_range(1, 99, 1, "or_greater") var max_health: int = 5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: int = max_health
@onready var _hazard_detector: Area2D = $HazardDetector

var could_air_jump := false
var could_air_dash := true
var coyote_time_left := 0.0
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_direction := 1.0
var gravity_sign := 1.0
var gravity_flip_cooldown_left := 0.0
var jumped_this_frame := false
var _animation_state := AnimationState.IDLE
var _rewind_shadow: RewindShadow
var _stone: PlayerStone
var _invulnerability_left := 0.0
var _knockback_time_left := 0.0
var _knockback_velocity := 0.0

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	_change_animation_state(AnimationState.IDLE, true)

func _physics_process(delta: float) -> void:
	_update_invulnerability(delta)
	if health > 0 and Input.is_action_just_pressed(&"ability_2"):
		if is_petrified():
			_leave_stone(false)
			return
		_petrify()

	if is_petrified():
		if Input.is_action_just_pressed(&"ability_1") and _has_rewind_anchor():
			_use_rewind()
		else:
			_stone.move_as_stone(get_gravity() * Vector2(1.0, gravity_sign) * movement_data.gravity_scale, delta)
			global_position = _stone.global_position
		return

	_check_hazards()
	gravity_flip_cooldown_left = maxf(gravity_flip_cooldown_left - delta, 0.0)
	update_dash_timers(delta)
	if health == 0 or _animation_state == AnimationState.HURT or _knockback_time_left > 0.0:
		_move_while_hurt(delta)
		return

	if Input.is_action_just_pressed(&"ability_1") and _use_rewind():
		return

	var input_axis := Input.get_axis("move_left", "move_right")
	coyote_time_left = maxf(coyote_time_left - delta, 0.0)
	var flipped := handle_gravity_flip()
	handle_dash(input_axis)
	if dash_time_left > 0.0:
		velocity = Vector2(dash_direction * movement_data.dash_speed, 0.0)
	else:
		apply_gravity(delta)
		var wall_jumped = handle_wall_jump()
		if not wall_jumped:
			handle_jump()
		# planted feet while attacking on the ground: no input acceleration, friction slows to a stop
		var move_axis := 0.0 if (is_attacking() and is_on_floor()) else input_axis
		apply_acceleration(move_axis, delta)
		apply_friction(move_axis, delta)
		apply_air_resistance(move_axis, delta)
	var attack_requested := can_start_attack()
	var was_on_floor := is_on_floor()
	move_and_slide()
	if dash_time_left > 0.0 and is_on_wall():
		end_dash()
	var just_left_ledge := not flipped and was_on_floor and (not is_on_floor()) and velocity.y * gravity_sign >= 0
	# potential bug: failure on moving-up platform
	if just_left_ledge:
		coyote_time_left = COYOTE_TIME
	update_animation(input_axis, attack_requested)

func is_petrified() -> bool:
	return is_instance_valid(_stone)


func _petrify() -> void:
	_stone = PLAYER_STONE_SCENE.instantiate() as PlayerStone
	get_parent().add_child(_stone)
	_stone.global_position = global_position
	_stone.reset_physics_interpolation()
	_stone.begin(up_direction, velocity, is_on_floor())
	velocity = Vector2.ZERO
	dash_time_left = 0.0
	coyote_time_left = 0.0
	jumped_this_frame = false
	_knockback_time_left = 0.0
	$CollisionShape2D.disabled = true
	$InteractionArea.set_interaction_enabled(false)
	sprite.hide()


func _leave_stone(keep_platform: bool) -> void:
	var stone := _stone
	_stone = null
	velocity = stone.velocity
	if keep_platform:
		stone.leave_as_platform()
	else:
		stone.fade_out()
	$CollisionShape2D.disabled = false
	$InteractionArea.set_interaction_enabled(true)
	_invulnerability_left = maxf(_invulnerability_left, STONE_EXIT_INVULNERABILITY_DURATION)
	sprite.show()
	_change_animation_state(AnimationState.IDLE, true)


func _has_rewind_anchor() -> bool:
	return is_instance_valid(_rewind_shadow) and not _rewind_shadow.is_queued_for_deletion()


func _use_rewind() -> bool:
	if _has_rewind_anchor():
		var anchor := _rewind_shadow
		_rewind_shadow = null
		if is_petrified():
			_leave_stone(true)
		global_position = anchor.global_position
		reset_physics_interpolation()
		velocity = Vector2.ZERO
		dash_time_left = 0.0
		coyote_time_left = 0.0
		anchor.consume()
		return true

	if is_instance_valid(rewind_effect_layer):
		var shadow := REWIND_SHADOW_SCENE.instantiate() as RewindShadow
		rewind_effect_layer.add_child(shadow)
		shadow.global_position = global_position
		shadow.capture_frame(sprite)
		shadow.expired.connect(_on_rewind_shadow_expired)
		_rewind_shadow = shadow
	return false

func _on_rewind_shadow_expired(shadow: RewindShadow) -> void:
	if _rewind_shadow == shadow:
		_rewind_shadow = null

func set_gravity_inverted(inverted: bool) -> void:
	gravity_sign = -1.0 if inverted else 1.0
	up_direction = Vector2.DOWN if inverted else Vector2.UP
	sprite.flip_v = inverted

func handle_gravity_flip() -> bool:
	if not movement_data.enable_gravity_flip:
		return false
	if gravity_flip_cooldown_left > 0.0:
		return false
	if not Input.is_action_just_pressed("flip_gravity"):
		return false
	set_gravity_inverted(gravity_sign > 0.0)
	gravity_flip_cooldown_left = movement_data.gravity_flip_cooldown
	coyote_time_left = 0.0
	# keep momentum already heading toward the new gravity, otherwise snap to a small push
	var toward_new := velocity.y * gravity_sign
	velocity.y = gravity_sign * maxf(toward_new, movement_data.gravity_flip_speed)
	return true

func update_dash_timers(delta: float) -> void:
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	if dash_time_left > 0.0:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			end_dash()

func end_dash() -> void:
	dash_time_left = 0.0
	velocity.x = clampf(velocity.x, -movement_data.speed, movement_data.speed)

func handle_dash(input_axis: float) -> void:
	if is_on_floor():
		could_air_dash = true
	if not movement_data.enable_dash:
		return
	if dash_time_left > 0.0 or dash_cooldown_left > 0.0:
		return
	if not Input.is_action_just_pressed("dash"):
		return
	if not is_on_floor():
		if not could_air_dash:
			return
		could_air_dash = false
	if input_axis != 0:
		dash_direction = signf(input_axis)
	else:
		dash_direction = -1.0 if sprite.flip_h else 1.0
	dash_time_left = movement_data.dash_duration
	dash_cooldown_left = movement_data.dash_duration + movement_data.dash_cooldown

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * Vector2(1.0, gravity_sign) * delta * movement_data.gravity_scale

func jump_impulse(strength := 1.0) -> void:
	velocity.y = movement_data.jump_velocity * strength * gravity_sign
	coyote_time_left = 0.0
	jumped_this_frame = true

func handle_wall_jump() -> bool:
	if not movement_data.enable_wall_jump:
		return false
	if not is_on_wall():
		return false
	could_air_jump = true
	if is_on_floor():
		return false
	if not Input.is_action_just_pressed("jump"):
		return false
	var wall_normal = get_wall_normal()
	if wall_normal == Vector2.LEFT:
		velocity.x = movement_data.speed * wall_normal.x
		jump_impulse()
		print_debug('wall jump left')
		return true
	if wall_normal == Vector2.RIGHT:
		velocity.x = movement_data.speed * wall_normal.x
		jump_impulse()
		print_debug('wall jump right')
		return true
	print_debug('bug')
	return false
		
func handle_jump():
	if is_on_floor():
		could_air_jump = true
		if Input.is_action_just_pressed("jump"):
			jump_impulse()
			return
	else:
		if Input.is_action_just_pressed("jump"):
			if coyote_time_left > 0.0:
				jump_impulse()
				print_debug('coyote jump')
				return
			if movement_data.enable_air_jump and could_air_jump:
				jump_impulse(0.8)
				print_debug('air jump')
				could_air_jump = false
				return
		if Input.is_action_just_released("jump"):
			if velocity.y * gravity_sign < movement_data.jump_velocity / 2:
				velocity.y = movement_data.jump_velocity / 2 * gravity_sign
				return

func apply_acceleration(input_axis, delta):
	if input_axis:
		if is_on_floor():
			velocity.x = move_toward(velocity.x , movement_data.speed * input_axis, movement_data.acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x , movement_data.speed * input_axis, movement_data.air_acceleration * delta)
		
func apply_friction(input_axis, delta):
	if input_axis == 0 and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, movement_data.friction * delta)

func apply_air_resistance(input_axis, delta):
	if input_axis == 0 and not is_on_floor():
		velocity.x = move_toward(velocity.x, 0, movement_data.air_resistance * delta)

func update_animation(input_axis: float, attack_requested: bool) -> void:
	var restart_jump := jumped_this_frame
	jumped_this_frame = false
	var on_floor := is_on_floor()
	var dashing := dash_time_left > 0.0
	var attacking := is_attacking()
	var recovering := _animation_state == AnimationState.ATTACK_END
	if not restart_jump and not dashing:
		if attacking:
			return
		if recovering and on_floor and not attack_requested and input_axis == 0.0:
			return
	if dashing:
		sprite.flip_h = dash_direction < 0.0
	elif input_axis != 0.0:
		sprite.flip_h = input_axis < 0.0

	if attack_requested:
		_change_animation_state(AnimationState.ATTACK)
	elif on_floor and not restart_jump:
		_change_animation_state(pick_ground_anim_state())
	elif restart_jump:
		_change_animation_state(AnimationState.JUMP, true)
	elif not dashing or attacking or recovering:
		# An air dash keeps its current pose unless it has to leave Attack.
		_change_animation_state(pick_air_anim_state())

func _change_animation_state(next_state: AnimationState, restart := false) -> void:
	if _animation_state == next_state and not restart:
		return
	_animation_state = next_state
	sprite.play(ANIMATIONS[next_state])
	if restart:
		sprite.set_frame_and_progress(0, 0.0)

func _on_animation_finished() -> void:
	match _animation_state:
		AnimationState.FALL:
			_change_animation_state(AnimationState.FALL_LOOP)
		AnimationState.ATTACK:
			if is_on_floor():
				_change_animation_state(AnimationState.ATTACK_END)
			else:
				_change_animation_state(pick_air_anim_state())
		AnimationState.ATTACK_END:
			_change_animation_state(AnimationState.IDLE)
		AnimationState.HURT:
			if health > 0:
				_change_animation_state(pick_ground_anim_state() if is_on_floor() else pick_air_anim_state())

func is_attacking() -> bool:
	return _animation_state == AnimationState.ATTACK

func can_start_attack() -> bool:
	return (
		Input.is_action_just_pressed("attack")
		and dash_time_left <= 0.0
		and not is_attacking()
	)

func pick_ground_anim_state() -> AnimationState:
	var speed_x := absf(velocity.x)
	if speed_x < WALK_MIN_SPEED:
		return AnimationState.IDLE
	var run_speed: float = movement_data.speed * RUN_SPEED_RATIO
	if _animation_state == AnimationState.RUN:
		run_speed *= RUN_EXIT_RATIO
	return AnimationState.RUN if speed_x >= run_speed else AnimationState.WALK


func pick_air_anim_state() -> AnimationState:
	if velocity.y * gravity_sign < 0.0:
		return AnimationState.JUMP
	if _animation_state == AnimationState.FALL_LOOP:
		return AnimationState.FALL_LOOP
	return AnimationState.FALL


func take_damage(amount: int, source_position: Vector2) -> void:
	if amount <= 0 or health <= 0 or _invulnerability_left > 0.0 or is_petrified():
		return

	health = maxi(health - amount, 0)
	_invulnerability_left = INVULNERABILITY_DURATION
	sprite.show()
	dash_time_left = 0.0
	coyote_time_left = 0.0
	jumped_this_frame = false

	var direction := signf(global_position.x - source_position.x)
	if direction == 0.0:
		direction = 1.0 if sprite.flip_h else -1.0
	var distance := maxf(movement_data.knockback_distance, 0.0)
	_knockback_velocity = direction * distance / KNOCKBACK_DURATION
	_knockback_time_left = KNOCKBACK_DURATION if distance > 0.0 else 0.0
	velocity = up_direction * HURT_BOUNCE_SPEED if distance > 0.0 else Vector2.ZERO
	_change_animation_state(AnimationState.HURT, true)

	var is_fatal := health == 0
	if is_fatal:
		$InteractionArea.set_interaction_enabled(false)
	health_changed.emit(health, max_health)
	if is_fatal:
		died.emit()


func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	reset_for_spawn()
	health = max_health
	health_changed.emit(health, max_health)


func reset_for_spawn() -> void:
	if is_petrified():
		_leave_stone(false)
	reset_physics_interpolation()
	$Camera2D.reset_smoothing()
	$Camera2D.force_update_scroll()
	velocity = Vector2.ZERO
	set_gravity_inverted(false)
	could_air_jump = false
	could_air_dash = true
	coyote_time_left = 0.0
	dash_time_left = 0.0
	dash_cooldown_left = 0.0
	gravity_flip_cooldown_left = 0.0
	jumped_this_frame = false
	_invulnerability_left = 0.0
	_knockback_time_left = 0.0
	_knockback_velocity = 0.0
	if _has_rewind_anchor():
		_rewind_shadow.consume()
	_rewind_shadow = null

	sprite.show()
	_change_animation_state(AnimationState.IDLE, true)
	$InteractionArea.set_interaction_enabled(true)


func _check_hazards() -> void:
	if health <= 0 or _invulnerability_left > 0.0:
		return
	for hazard in _hazard_detector.get_overlapping_areas():
		if not hazard.is_queued_for_deletion():
			take_damage(1, hazard.global_position)
			return


func _update_invulnerability(delta: float) -> void:
	if _invulnerability_left <= 0.0:
		return
	_invulnerability_left = maxf(_invulnerability_left - delta, 0.0)
	var elapsed := INVULNERABILITY_DURATION - _invulnerability_left
	if not is_petrified():
		sprite.visible = _invulnerability_left == 0.0 or int(elapsed / BLINK_INTERVAL) % 2 == 0


func _move_while_hurt(delta: float) -> void:
	var knockback_step := minf(_knockback_time_left, delta)
	_knockback_time_left -= knockback_step
	# Limit the last physics step to the remaining knockback distance.
	velocity.x = _knockback_velocity * (knockback_step / delta)
	apply_gravity(delta)
	move_and_slide()
