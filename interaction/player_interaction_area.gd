extends Area2D

const INTERACT_ACTION := &"interact"
const PROMPT_HEAD_OFFSET := 64.0

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D
@onready var _prompt: Label = $InteractionPrompt

var _target: Interactable


func set_interaction_enabled(enabled: bool) -> void:
	set_process_unhandled_input(enabled)
	set_physics_process(enabled)
	if not enabled:
		_target = null
		_prompt.hide()


func _physics_process(_delta: float) -> void:
	_target = _find_nearest_interactable()
	if _target == null:
		_prompt.hide()
		return

	var key_text := _get_interact_binding_text()
	if key_text.is_empty():
		_prompt.hide()
		return

	var prompt_text := "%s : %s" % [key_text, _target.get_interaction_text()]
	if _prompt.text != prompt_text:
		_prompt.text = prompt_text
		_prompt.reset_size()

	var prompt_y := -PROMPT_HEAD_OFFSET - _prompt.size.y
	if _player.up_direction == Vector2.DOWN:
		prompt_y = PROMPT_HEAD_OFFSET
	_prompt.position = Vector2(-_prompt.size.x / 2.0, prompt_y)
	_prompt.show()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(INTERACT_ACTION) or not is_instance_valid(_target):
		return

	if _target.is_queued_for_deletion() or not _target.is_interactable() or not overlaps_area(_target):
		return

	get_viewport().set_input_as_handled()
	_target.interact(_player)


func _find_nearest_interactable() -> Interactable:
	var nearest: Interactable
	var nearest_distance := INF
	for area in get_overlapping_areas():
		var candidate := area as Interactable
		if candidate == null or candidate.is_queued_for_deletion() or not candidate.is_interactable():
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _get_interact_binding_text() -> String:
	var bindings := InputMap.action_get_events(INTERACT_ACTION)
	if bindings.is_empty():
		return ""

	var binding := bindings[0]
	if binding is InputEventKey and binding.physical_keycode != KEY_NONE:
		if OS.has_feature("pc") and DisplayServer.get_name() != "headless":
			var key_label := DisplayServer.keyboard_get_label_from_physical(binding.physical_keycode)
			if key_label != KEY_NONE:
				return OS.get_keycode_string(key_label | binding.get_modifiers_mask())
		return binding.as_text_physical_keycode()

	return binding.as_text()
