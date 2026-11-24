extends Node

@export var main_scene: PackedScene

@onready var player: DebugPlayer = $Player
@onready var _gameplay_ui: GameplayUI = $GameplayUI

var _stage: StageTemplate


func _ready() -> void:
	_stage = main_scene.instantiate() as StageTemplate
	add_child(_stage)
	_stage.spawn(player)
	player.health_changed.connect(_gameplay_ui.set_health)
	_gameplay_ui.set_health(player.health, player.max_health)
	player.died.connect(_respawn_player, CONNECT_DEFERRED)


func _respawn_player() -> void:
	player.respawn(_stage.get_spawn_point(&"default").global_position)
