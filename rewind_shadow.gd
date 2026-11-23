class_name RewindShadow
extends Node2D

signal expired(shadow: RewindShadow)

@onready var sprite: Sprite2D = $Shadow
@onready var timer: Timer = $Timer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.play("fade_in")
	
func capture_frame(source: AnimatedSprite2D) -> void:
	var frame_texture := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if frame_texture is AtlasTexture:
		# Give the shader UVs for this frame and keep its edge sampling inside the frame.
		var frame_image := frame_texture.get_image()
		if frame_image != null and not frame_image.is_empty():
			frame_texture = ImageTexture.create_from_image(frame_image)
	sprite.texture = frame_texture
	sprite.global_transform = source.global_transform
	sprite.centered = source.centered
	sprite.offset = source.offset
	sprite.flip_h = source.flip_h
	sprite.flip_v = source.flip_v
	sprite.texture_filter = source.texture_filter
	sprite.modulate = source.modulate
	sprite.self_modulate = source.self_modulate


func consume() -> void:
	timer.stop()
	queue_free()


func _on_timer_timeout() -> void:
	expired.emit(self)
	consume()
