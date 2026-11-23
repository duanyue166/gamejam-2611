class_name PlayerMovementData
extends Resource

@export var speed = 140.0
@export var acceleration = 1500.0
@export var friction = 1800.0
@export var jump_velocity = -270.0
@export var gravity_scale = 1.0
@export var air_resistance = 1200.0
@export var air_acceleration = 800.0
@export var enable_air_jump := true
@export var enable_wall_jump := true
@export var enable_dash := true
@export var dash_speed = 400.0
@export var dash_duration = 0.3
@export var dash_cooldown = 0.5
@export var enable_gravity_flip := true
@export var gravity_flip_cooldown = 0.25
@export var gravity_flip_speed = 150.0
