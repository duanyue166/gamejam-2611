extends Node

enum Activity { MAIN_MENU, PLAYING, PAUSED, DEAD, CHANGING_STAGE, PLAYING_DIALOGUE }

@export var main_scene: PackedScene
@export var initial_spawn: StringName = StageTemplate.DEFAULT_SPAWN

@onready var player: DebugPlayer = $Player
@onready var _stage_container: Node2D = $StageContainer
@onready var _gameplay_ui: GameplayUI = $GameplayUI
@onready var _dialogue_ui: DialogueUI = $DialogueUI
@onready var _stage_transition: AnimationPlayer = $StageTransition/AnimationPlayer
@onready var _menu_ui: MenuUI = $MenuUI

var _stage: StageTemplate
var _stage_scene: PackedScene
var _arrival_spawn_id: StringName
var _activity := Activity.MAIN_MENU


func _ready() -> void:
	player.health_changed.connect(_gameplay_ui.set_health)
	player.died.connect(_on_player_died)
	_menu_ui.start_requested.connect(_start_game)
	_menu_ui.pause_toggled.connect(_toggle_pause)
	_menu_ui.restart_requested.connect(_restart_stage)
	_menu_ui.main_menu_requested.connect(_return_to_main_menu)
	_show_main_menu()


func _show_main_menu() -> void:
	get_tree().paused = true
	_gameplay_ui.hide()
	_menu_ui.show_main_menu()


func _start_game() -> void:
	if _activity != Activity.MAIN_MENU:
		return
	var stage := _instantiate_stage(main_scene, initial_spawn)
	if stage == null:
		return
	_activity = Activity.CHANGING_STAGE
	await _fade_out()
	_mount_stage(stage, main_scene, initial_spawn, true)
	_gameplay_ui.show()
	_menu_ui.hide_menu()
	await _fade_in()
	_resume_game()


func _toggle_pause() -> void:
	match _activity:
		Activity.PLAYING:
			_activity = Activity.PAUSED
			get_tree().paused = true
			_menu_ui.show_pause_menu()
		Activity.PAUSED:
			_menu_ui.hide_menu()
			_resume_game()


func _resume_game() -> void:
	_activity = Activity.PLAYING
	get_tree().paused = false


func _restart_stage() -> void:
	if _activity != Activity.PAUSED and _activity != Activity.DEAD:
		return
	var spawn_id := StageTemplate.DEFAULT_SPAWN
	if _stage.get_spawn_point(spawn_id) == null:
		spawn_id = _arrival_spawn_id
	var scene := _stage_scene
	var stage := _instantiate_stage(scene, spawn_id)
	if stage == null:
		return
	_unmount_stage()
	_mount_stage(stage, scene, spawn_id, true)
	_menu_ui.hide_menu()
	_resume_game()


func _return_to_main_menu() -> void:
	if _activity != Activity.PAUSED:
		return
	_activity = Activity.CHANGING_STAGE
	await _fade_out()
	player.reset_for_spawn()
	_unmount_stage()
	_show_main_menu()
	await _fade_in()
	_activity = Activity.MAIN_MENU


func _fade_out() -> void:
	_menu_ui.set_input_enabled(false)
	_stage_transition.play(&"fade_out")
	await _stage_transition.animation_finished


func _fade_in() -> void:
	_stage_transition.play(&"fade_in")
	await _stage_transition.animation_finished
	_menu_ui.set_input_enabled(true)


func _on_player_died() -> void:
	_activity = Activity.DEAD
	# Fatal damage can be emitted by a physics callback.
	_show_death_menu.call_deferred()


func _show_death_menu() -> void:
	get_tree().paused = true
	_menu_ui.show_death_menu()


func _mount_stage(stage: StageTemplate, scene: PackedScene, spawn_id: StringName, restore_health: bool) -> void:
	_stage = stage
	_stage_scene = scene
	_arrival_spawn_id = spawn_id
	_stage_container.add_child(_stage)
	player.stage_actors = _stage.get_actor_container()
	var spawn_position := _stage.get_spawn_point(spawn_id).global_position
	if restore_health:
		player.respawn(spawn_position)
	else:
		player.global_position = spawn_position
		player.reset_for_spawn()
	for gate in _stage.get_gates():
		gate.suppress_arrival_overlap(player)
		gate.stage_change_requested.connect(_on_stage_change_requested)
	for trigger in _stage.get_dialogue_triggers():
		trigger.dialogue_requested.connect(_on_dialogue_requested.bind(trigger))
	_stage.on_enter(player)


func _unmount_stage() -> void:
	_stage.on_exit(player)
	player.stage_actors = null
	_stage_container.remove_child(_stage)
	_stage.queue_free()
	_stage = null
	_stage_scene = null


func _on_stage_change_requested(body: DebugPlayer, stage_path: String, spawn_id: StringName) -> void:
	if _activity != Activity.PLAYING or body != player or player.health <= 0:
		return
	_activity = Activity.CHANGING_STAGE
	# Area2D emits during the physics flush. Pause and change the tree afterward.
	_change_stage.call_deferred(stage_path, spawn_id)


func _change_stage(stage_path: String, spawn_id: StringName) -> void:
	if _activity != Activity.CHANGING_STAGE:
		return
	var target_stage := ResourceLoader.load(stage_path, "PackedScene") as PackedScene
	if target_stage == null:
		push_error("Could not load stage exit target: %s" % stage_path)
		_activity = Activity.PLAYING
		return

	var next_stage := _instantiate_stage(target_stage, spawn_id)
	if next_stage == null:
		_activity = Activity.PLAYING
		return

	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	await _fade_out()

	_unmount_stage()
	_mount_stage(next_stage, target_stage, spawn_id, false)

	await _fade_in()
	tree.paused = was_paused
	_activity = Activity.PLAYING


func _on_dialogue_requested(body: DebugPlayer, dialogue: DialogueData, trigger: DialogueTrigger) -> void:
	if _activity != Activity.PLAYING or body != player or player.health <= 0:
		return
	_activity = Activity.PLAYING_DIALOGUE
	_play_dialogue.call_deferred(dialogue, trigger)


func _play_dialogue(dialogue: DialogueData, trigger: DialogueTrigger) -> void:
	if _activity != Activity.PLAYING_DIALOGUE:
		return
	if not is_instance_valid(trigger) or not _stage.is_ancestor_of(trigger):
		_activity = Activity.PLAYING
		return
	if not _dialogue_ui.play_dialogue(dialogue):
		_activity = Activity.PLAYING
		return
	trigger.mark_started()
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	await _dialogue_ui.dialogue_finished
	tree.paused = was_paused
	_activity = Activity.PLAYING


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
