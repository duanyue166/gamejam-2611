class_name GameplayUI
extends CanvasLayer

const HEART_SIZE := Vector2(48, 48)

@export var full_heart_texture: Texture2D
@export var empty_heart_texture: Texture2D

@onready var _hearts: HFlowContainer = $Hearts


func set_health(current_health: int, max_health: int) -> void:
	var heart_count := maxi(max_health, 0)
	while _hearts.get_child_count() < heart_count:
		var heart := TextureRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts.add_child(heart)

	while _hearts.get_child_count() > heart_count:
		var heart := _hearts.get_child(-1)
		_hearts.remove_child(heart)
		heart.queue_free()

	for index in heart_count:
		var heart := _hearts.get_child(index) as TextureRect
		heart.texture = full_heart_texture if index < current_health else empty_heart_texture
