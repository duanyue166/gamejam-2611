extends Node

@export var main_scene: PackedScene
@export var initial_spawn: StringName = StageTemplate.DEFAULT_SPAWN

@onready var player: DebugPlayer = $Player
@onready var _stage_container: Node2D = $StageContainer
@onready var _gameplay_ui: GameplayUI = $GameplayUI
@onready var _stage_transition: AnimationPlayer = $StageTransition/AnimationPlayer

var _stage: StageTemplate
var _arrival_spawn: Marker2D
var _is_transitioning := false


func _ready() -> void:
	player.health_changed.connect(_gameplay_ui.set_health)
	_gameplay_ui.set_health(player.health, player.max_health)
	player.died.connect(_respawn_player, CONNECT_DEFERRED)

	var stage := _instantiate_stage(main_scene, initial_spawn)
	if stage != null:
		_mount_stage(stage, initial_spawn)


func _mount_stage(stage: StageTemplate, spawn_id: StringName) -> void:
	_stage = stage
	_stage_container.add_child(_stage)
	player.stage_actors = _stage.get_actor_container()
	_arrival_spawn = _stage.get_spawn_point(spawn_id)
	player.global_position = _arrival_spawn.global_position
	player.reset_for_spawn()
	for gate in _stage.get_gates():
		gate.suppress_arrival_overlap(player)
		gate.stage_change_requested.connect(_on_stage_change_requested)
	_stage.on_enter(player)


func _on_stage_change_requested(body: DebugPlayer, stage_path: String, spawn_id: StringName) -> void:
	if _is_transitioning or body != player or player.health <= 0:
		return
	_is_transitioning = true
	# Area2D emits during the physics flush. Pause and change the tree afterward.
	_change_stage.call_deferred(stage_path, spawn_id)


func _change_stage(stage_path: String, spawn_id: StringName) -> void:
	var target_stage := ResourceLoader.load(stage_path, "PackedScene") as PackedScene
	if target_stage == null:
		push_error("Could not load stage exit target: %s" % stage_path)
		_is_transitioning = false
		return

	var next_stage := _instantiate_stage(target_stage, spawn_id)
	if next_stage == null:
		_is_transitioning = false
		return

	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_stage_transition.play(&"fade_out")
	await _stage_transition.animation_finished

	var previous_stage := _stage
	previous_stage.on_exit(player)
	_stage_container.remove_child(previous_stage)
	_mount_stage(next_stage, spawn_id)
	previous_stage.queue_free()

	_stage_transition.play(&"fade_in")
	await _stage_transition.animation_finished
	tree.paused = was_paused
	_is_transitioning = false


func _instantiate_stage(scene: PackedScene, spawn_id: StringName) -> StageTemplate:
	if scene == null:
		push_error("No initial stage configured.")
		return null

	var instance := scene.instantiate()
	var stage := instance as StageTemplate
	if stage == null:
		if instance != null:
			instance.free()
		push_error("Stage scene must inherit StageTemplate: %s" % scene.resource_path)
		return null
	if stage.get_spawn_point(spawn_id) == null:
		stage.free()
		push_error("Spawn point '%s' not found in %s" % [spawn_id, scene.resource_path])
		return null
	return stage


func _respawn_player() -> void:
	if _stage != null:
		var spawn := _stage.get_spawn_point(StageTemplate.DEFAULT_SPAWN)
		player.respawn((spawn if spawn != null else _arrival_spawn).global_position)
