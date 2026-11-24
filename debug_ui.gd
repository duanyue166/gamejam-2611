extends CanvasLayer

@export var enabled: bool
@export var player: Node
@export var toggle_key: Key = KEY_F1

@onready var panel: PanelContainer = $Panel
@onready var rows: VBoxContainer = %Rows
@onready var title: Label = %Title
@onready var reset_button: Button = %ResetButton
@onready var save_button: Button = %SaveButton
@onready var status: Label = %Status

var _data: Resource
var _defaults := {}
var _refreshers: Array[Callable] = []

func _ready() -> void:
	if not enabled:
		queue_free()
	if player == null:
		player = _find_player()
	_data = player.get("movement_data") if player else null
	if _data == null:
		title.text = "No player with movement_data"
		reset_button.hide()
		save_button.hide()
		return
	reset_button.focus_mode = Control.FOCUS_NONE
	save_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset)
	save_button.pressed.connect(_save)
	_build_rows()

func _unhandled_input(event: InputEvent) -> void:
	# clicking the game world drops focus from a text field so A/D/Space stop typing into it
	if event is InputEventMouseButton and event.pressed:
		var focused := get_viewport().gui_get_focus_owner()
		if focused:
			focused.release_focus()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

func _find_player() -> Node:
	for node in get_parent().get_children():
		if "movement_data" in node:
			return node
	return null

func _build_rows() -> void:
	for p in _data.get_property_list():
		if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR):
			continue
		var prop: StringName = p.name
		_defaults[prop] = _data.get(prop)
		match p.type:
			TYPE_BOOL:
				_add_bool_row(prop)
			TYPE_FLOAT, TYPE_INT:
				_add_number_row(prop, p.type == TYPE_INT)

func _make_row(prop: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = String(prop)
	label.custom_minimum_size.x = 150
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	rows.add_child(row)
	return row

func _add_bool_row(prop: StringName) -> void:
	var row := _make_row(prop)
	var box := CheckBox.new()
	box.focus_mode = Control.FOCUS_NONE
	box.button_pressed = _data.get(prop)
	box.toggled.connect(func(on: bool): _data.set(prop, on))
	row.add_child(box)
	_refreshers.append(func(): box.set_pressed_no_signal(_data.get(prop)))

func _add_number_row(prop: StringName, is_int: bool) -> void:
	var row := _make_row(prop)
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 110
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.step = 1.0 if is_int else 0.05
	spin.min_value = -10000
	spin.max_value = 10000
	spin.set_value_no_signal(_data.get(prop))
	spin.value_changed.connect(func(v: float): _data.set(prop, int(v) if is_int else v))
	spin.get_line_edit().text_submitted.connect(func(_t: String): spin.get_line_edit().release_focus())
	row.add_child(spin)
	_refreshers.append(func(): spin.set_value_no_signal(_data.get(prop)))

func _reset() -> void:
	for prop in _defaults:
		_data.set(prop, _defaults[prop])
	for refresh in _refreshers:
		refresh.call()
	status.text = "Reverted to last saved values"

func _save() -> void:
	var path := _data.resource_path
	if path.is_empty() or path.contains("::"):
		status.text = "Resource is not a standalone file, cannot save"
		return
	if not OS.has_feature("editor"):
		status.text = "Saving only works when run from the editor"
		return
	var err := ResourceSaver.save(_data, path)
	if err != OK:
		status.text = "Save failed: %s" % error_string(err)
		return
	for prop in _defaults:
		_defaults[prop] = _data.get(prop)
	status.text = "Saved to %s" % path
