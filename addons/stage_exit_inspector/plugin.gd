@tool
extends EditorPlugin

var _inspector := StageExitInspector.new()


func _enter_tree() -> void:
	add_inspector_plugin(_inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)


class StageExitInspector extends EditorInspectorPlugin:
	func _can_handle(object: Object) -> bool:
		return object is StageExit

	func _parse_property(object: Object, _type: Variant.Type, property: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
		match property:
			"target_stage_path":
				add_property_editor(property, TargetStageEditor.new(), false, "Target Stage")
				return true
			"target_spawn":
				var editor := TargetSpawnEditor.new()
				object.target_stage_changed.connect(editor.refresh_options)
				add_property_editor(property, editor)
				return true
		return false


class TargetStageEditor extends EditorProperty:
	var _picker := EditorResourcePicker.new()

	func _init() -> void:
		_picker.base_type = "PackedScene"
		_picker.resource_changed.connect(_on_resource_changed)
		add_child(_picker)
		add_focusable(_picker)

	func _update_property() -> void:
		var gate := get_edited_object() as StageExit
		if _picker.edited_resource != null and _picker.edited_resource.resource_path == gate.target_stage_path:
			return
		_picker.edited_resource = null
		if not gate.target_stage_path.is_empty() and ResourceLoader.exists(gate.target_stage_path, "PackedScene"):
			_picker.edited_resource = ResourceLoader.load(gate.target_stage_path, "PackedScene")

	func _set_read_only(read_only: bool) -> void:
		_picker.editable = not read_only

	func _on_resource_changed(resource: Resource) -> void:
		if resource == null:
			emit_changed(get_edited_property(), "")
			return
		var path := resource.resource_path
		# A built-in scene has no independent file to load at runtime.
		if not path.begins_with("res://") or "::" in path:
			_update_property()
			return
		emit_changed(get_edited_property(), path)


class TargetSpawnEditor extends EditorProperty:
	var _options := OptionButton.new()
	var _spawn_ids: Array[StringName] = []
	var _status := ""
	var _read_only := false

	func _init() -> void:
		_options.fit_to_longest_item = false
		_options.item_selected.connect(_on_spawn_selected)
		_options.get_popup().about_to_popup.connect(refresh_options)
		add_child(_options)
		add_focusable(_options)

	func _update_property() -> void:
		if _options.item_count == 0:
			refresh_options()
		else:
			_show_options()

	func _set_read_only(read_only: bool) -> void:
		_read_only = read_only
		_options.disabled = read_only or _spawn_ids.is_empty()

	func refresh_options() -> void:
		var gate := get_edited_object() as StageExit
		if gate == null:
			return
		_spawn_ids.clear()
		_status = "Choose a target stage"
		if not gate.target_stage_path.is_empty():
			_status = "Target scene not found"
			if ResourceLoader.exists(gate.target_stage_path, "PackedScene"):
				_status = "Target must inherit StageTemplate"
				var scene := ResourceLoader.load(gate.target_stage_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
				if scene != null and scene.can_instantiate():
					var instance := scene.instantiate()
					if instance is StageTemplate:
						_spawn_ids = StageTemplate.collect_spawn_points(instance).keys()
						_status = "No spawn points"
					instance.free()
		_show_options()

	func _show_options() -> void:
		var gate := get_edited_object() as StageExit
		_options.clear()
		_options.disabled = _read_only or _spawn_ids.is_empty()
		for spawn_id in _spawn_ids:
			_options.add_item(String(spawn_id))

		var index := _spawn_ids.find(gate.target_spawn)
		if index == -1:
			var label := _status if _spawn_ids.is_empty() else "Missing: %s" % gate.target_spawn
			index = _options.item_count
			_options.add_item(label)
			_options.set_item_disabled(index, true)
		_options.select(index)

	func _on_spawn_selected(index: int) -> void:
		emit_changed(get_edited_property(), _spawn_ids[index])
