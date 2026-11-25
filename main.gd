extends Node

@export var main_scene: PackedScene

@onready var player: DebugPlayer = $Player
@onready var _gameplay_ui: GameplayUI = $GameplayUI
@onready var _stage_transition: AnimationPlayer = $StageTransition/AnimationPlayer

var _stage: StageTemplate
var _is_transitioning := false


func _ready() -> void:
	_mount_stage(main_scene.instantiate() as StageTemplate)
	player.health_changed.connect(_gameplay_ui.set_health)
	_gameplay_ui.set_health(player.health, player.max_health)
	player.died.connect(_respawn_player, CONNECT_DEFERRED)


func _mount_stage(stage: StageTemplate) -> void:
	_stage = stage
	_stage.stage_exit_entered.connect(_on_stage_exit_entered)
	add_child(_stage)
	_stage.spawn(player)
	player.reset_for_spawn()


func _on_stage_exit_entered(body: DebugPlayer, target_stage_path: String) -> void:
	if _is_transitioning or body != player or player.health <= 0:
		return
	_is_transitioning = true
	# Area2D emits during the physics flush. Pause and change the tree afterward.
	_change_stage.call_deferred(target_stage_path)


func _change_stage(target_stage_path: String) -> void:
	var target_stage := ResourceLoader.load(target_stage_path, "PackedScene") as PackedScene
	if target_stage == null:
		push_error("Could not load stage exit target: %s" % target_stage_path)
		_is_transitioning = false
		return

	var instance := target_stage.instantiate()
	var next_stage := instance as StageTemplate
	if next_stage == null:
		if instance != null:
			instance.free()
		push_error("Stage exit target must inherit StageTemplate: %s" % target_stage_path)
		_is_transitioning = false
		return

	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_stage_transition.play(&"fade_out")
	await _stage_transition.animation_finished

	var previous_stage := _stage
	_mount_stage(next_stage)
	remove_child(previous_stage)
	previous_stage.queue_free()

	_stage_transition.play(&"fade_in")
	await _stage_transition.animation_finished
	tree.paused = was_paused
	_is_transitioning = false


func _respawn_player() -> void:
	player.respawn(_stage.get_spawn_point(&"default").global_position)
