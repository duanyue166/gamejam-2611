class_name MenuUI
extends CanvasLayer

signal start_requested
signal pause_toggled
signal restart_requested
signal main_menu_requested

const SETTINGS_PATH := "user://settings.cfg"
const MASTER_BUS := 0

@onready var _overlay: Control = $Overlay
@onready var _background: Control = %Background
@onready var _dimmer: ColorRect = %Dimmer
@onready var _main_menu: MarginContainer = %MainMenu
@onready var _modal: CenterContainer = %Modal
@onready var _pause_menu: VBoxContainer = %PauseMenu
@onready var _death_menu: VBoxContainer = %DeathMenu
@onready var _settings_menu: VBoxContainer = %SettingsMenu
@onready var _start: Button = %Start
@onready var _settings_button: Button = %Settings
@onready var _continue: Button = %Continue
@onready var _revive: Button = %Revive
@onready var _volume: HSlider = %Volume
@onready var _volume_value: Label = %VolumeValue
@onready var _fullscreen: CheckButton = %Fullscreen

var _settings := ConfigFile.new()
var _screen: Control
var _focus_target: Control


func _ready() -> void:
	_start.pressed.connect(start_requested.emit)
	_settings_button.pressed.connect(_show_settings)
	%Quit.pressed.connect(get_tree().quit)
	_continue.pressed.connect(pause_toggled.emit)
	%Restart.pressed.connect(restart_requested.emit)
	%MainMenuButton.pressed.connect(main_menu_requested.emit)
	_revive.pressed.connect(restart_requested.emit)
	%SettingsBack.pressed.connect(_close_settings)

	_settings.load(SETTINGS_PATH)
	_volume.set_value_no_signal(float(_settings.get_value("audio", "master_volume", 100.0)))
	_apply_volume(_volume.value)
	_fullscreen.disabled = Engine.is_embedded_in_editor()
	var window_mode := get_tree().root.mode
	var is_fullscreen := window_mode == Window.MODE_FULLSCREEN or window_mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	_fullscreen.set_pressed_no_signal(bool(_settings.get_value("display", "fullscreen", is_fullscreen)))
	if _fullscreen.button_pressed != is_fullscreen:
		_apply_fullscreen(_fullscreen.button_pressed)
	_volume.value_changed.connect(_on_volume_changed)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _screen == _settings_menu:
		_close_settings()
	elif _screen == null or _screen == _pause_menu:
		pause_toggled.emit()


func show_main_menu() -> void:
	_show_screen(_main_menu, _start)


func show_pause_menu() -> void:
	_show_screen(_pause_menu, _continue)


func show_death_menu() -> void:
	_show_screen(_death_menu, _revive)


func hide_menu() -> void:
	_overlay.hide()
	_screen = null
	_focus_target = null


func set_input_enabled(enabled: bool) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS if enabled else Node.PROCESS_MODE_DISABLED
	if enabled and _focus_target != null:
		_focus_target.grab_focus()


func _show_settings() -> void:
	_show_screen(_settings_menu, _volume)


func _close_settings() -> void:
	_show_screen(_main_menu, _settings_button)


func _show_screen(screen: Control, focus: Control) -> void:
	_screen = screen
	_focus_target = focus
	var title_background := screen == _main_menu or screen == _settings_menu
	_background.visible = title_background
	_dimmer.visible = not title_background
	_main_menu.visible = screen == _main_menu
	_modal.visible = screen != _main_menu
	_settings_menu.visible = screen == _settings_menu
	_pause_menu.visible = screen == _pause_menu
	_death_menu.visible = screen == _death_menu
	_overlay.show()
	if can_process():
		focus.grab_focus()


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_settings.set_value("audio", "master_volume", value)
	_save_settings()


func _apply_volume(value: float) -> void:
	_volume_value.text = "%d%%" % roundi(value)
	AudioServer.set_bus_volume_linear(MASTER_BUS, maxf(value / 100.0, 0.01))
	AudioServer.set_bus_mute(MASTER_BUS, value == 0.0)


func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_settings.set_value("display", "fullscreen", enabled)
	_save_settings()


func _apply_fullscreen(enabled: bool) -> void:
	if not _fullscreen.disabled:
		get_tree().root.mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED


func _save_settings() -> void:
	var error := _settings.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save menu settings: %s" % error_string(error))
