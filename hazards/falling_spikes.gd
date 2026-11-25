extends Area2D

const WORLD_COLLISION_MASK := 1 << 0

@export_range(1.0, 2000.0, 1.0, "or_greater", "suffix:px/s") var fall_speed: float = 480.0

var _fall_query := PhysicsShapeQueryParameters2D.new()
var _has_landed := false


func _ready() -> void:
	_fall_query.collision_mask = WORLD_COLLISION_MASK
	set_physics_process(false)


func fall(_body) -> void:
	if not _has_landed:
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	var motion := Vector2.DOWN * fall_speed * delta
	var space_state := get_world_2d().direct_space_state
	var safe_fraction := 1.0
	_fall_query.motion = motion

	# Sweep the same convex shapes that the hazard area uses for damage.
	for owner_id in get_shape_owners():
		if is_shape_owner_disabled(owner_id):
			continue
		_fall_query.transform = global_transform * shape_owner_get_transform(owner_id)
		for shape_index in shape_owner_get_shape_count(owner_id):
			_fall_query.shape = shape_owner_get_shape(owner_id, shape_index)
			safe_fraction = minf(safe_fraction, space_state.cast_motion(_fall_query)[0])

	global_position += motion * safe_fraction
	if safe_fraction < 1.0:
		_has_landed = true
		set_physics_process(false)
		get_tree().create_timer(0.5, false, true).timeout.connect(queue_free)
