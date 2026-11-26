class_name DialogueUI
extends CanvasLayer

signal dialogue_finished

const ADVANCE_ACTION := &"dialogue_advance"

@onready var _portrait: TextureRect = %Portrait
@onready var _speaker: Label = %Speaker
@onready var _body: RichTextLabel = %Body

var _lines: Array[DialogueLine] = []
var _line_index := 0


func _ready() -> void:
	hide()


func play_dialogue(dialogue: DialogueData) -> bool:
	if not _lines.is_empty() or dialogue == null:
		return false
	for line in dialogue.lines:
		if line != null:
			_lines.append(line)
	if _lines.is_empty():
		return false
	_line_index = 0
	show()
	_show_line(_lines[_line_index])
	return true


func _input(event: InputEvent) -> void:
	if _lines.is_empty() or not event.is_action_pressed(ADVANCE_ACTION):
		return
	get_viewport().set_input_as_handled()
	_line_index += 1
	if _line_index < _lines.size():
		_show_line(_lines[_line_index])
	else:
		_lines.clear()
		_portrait.texture = null
		hide()
		dialogue_finished.emit()


func _show_line(line: DialogueLine) -> void:
	var speaker := line.speaker
	_speaker.text = speaker.display_name if speaker != null else ""
	_speaker.visible = not _speaker.text.is_empty()
	_portrait.texture = speaker.get_portrait(line.portrait_id) if speaker != null else null
	_portrait.visible = _portrait.texture != null
	_body.text = line.text
	_body.scroll_to_line(0)
