extends Node2D

const SAVE_PATH = "user://preferences.cfg"
const ACTIONS = {
	"move_up": "Move up", "move_down": "Move down",
	"move_left": "Move left", "move_right": "Move right",
	"interact": "Open door", "fire": "Use item", "restart": "Restart attempt",
	"swap_item": "Swap item", "equip_gun": "Equip gun", "equip_spyglass": "Equip spyglass"
}
static var preferences := ConfigFile.new()
static var loaded: bool = false
var waiting_for_input: bool = false
var action_to_remap: String = ""
var active_remap_button: Button
var remap_buttons: Dictionary = {}
var _light_time: float = 0.0

static func load_preferences() -> void:
	if loaded:
		return
	loaded = true
	preferences.load(SAVE_PATH)
	AudioServer.set_bus_volume_db(0, clampf(float(preferences.get_value("audio", "volume", 0.0)), -30.0, 0.0))
	AudioServer.set_bus_mute(0, AudioServer.get_bus_volume_db(0) <= -29.5)
	for action in ACTIONS:
		var saved: Variant = preferences.get_value("keys", action, {})
		if not saved is Dictionary or saved.is_empty() or not InputMap.has_action(action):
			continue
		var event: InputEvent
		if saved.get("kind") == "mouse":
			event = InputEventMouseButton.new()
			event.button_index = int(saved.get("code", MOUSE_BUTTON_LEFT))
		else:
			event = InputEventKey.new()
			event.physical_keycode = int(saved.get("code", 0))
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
	if preferences.has_section_key("display", "fullscreen"):
		apply_fullscreen(bool(preferences.get_value("display", "fullscreen")))

static func brightness_scale() -> float:
	return clampf(float(preferences.get_value("display", "brightness", 1.8)), 0.5, 3.0) / 1.8

static func apply_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	if not enabled:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		var screen := DisplayServer.window_get_current_screen()
		var rect := DisplayServer.screen_get_usable_rect(screen)
		var dimensions := Vector2i(mini(1280, rect.size.x), mini(720, rect.size.y))
		DisplayServer.window_set_size(dimensions)
		DisplayServer.window_set_position(rect.position + (rect.size - dimensions) / 2)

func _ready() -> void:
	load_preferences()
	$VBoxContainer/VolumeSlider.min_value = -30.0
	$VBoxContainer/VolumeSlider.max_value = 0.0
	$VBoxContainer/VolumeSlider.step = 1.0
	$"VBoxContainer/Brightness Slider".min_value = 0.5
	$"VBoxContainer/Brightness Slider".max_value = 3.0
	$"VBoxContainer/Brightness Slider".step = 0.05
	$VBoxContainer/VolumeSlider.set_value_no_signal(AudioServer.get_bus_volume_db(0))
	$"VBoxContainer/Brightness Slider".set_value_no_signal(float(preferences.get_value("display", "brightness", 1.8)))
	$"VBoxContainer/Fullscreen Check".set_pressed_no_signal(DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN])
	$VBoxContainer/VolumeSlider.value_changed.connect(_volume_changed)
	$"VBoxContainer/Brightness Slider".value_changed.connect(_brightness_changed)
	$"VBoxContainer/Fullscreen Check".toggled.connect(_fullscreen_changed)
	$Back.pressed.connect(_back)
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = ACTIONS[action]
		label.add_theme_font_override("font", preload("res://Assets/Excalifont-Regular.woff2"))
		label.add_theme_font_size_override("font_size", 20)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.custom_minimum_size = Vector2(170, 28)
		button.text = get_action_key_name(action)
		button.add_theme_font_override("font", preload("res://Assets/Excalifont-Regular.woff2"))
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_begin_remap.bind(action, button))
		row.add_child(label)
		row.add_child(button)
		$VBoxContainer/Keybinder.add_child(row)
		remap_buttons[action] = button
	$"Cursor LightUp".energy = 1.8 * brightness_scale()
	$"Cursor LightUp".texture_scale = remap(1.8 * brightness_scale(), 0.5, 3.0, 1.5, 3.5)
	$Back.grab_focus()

func get_action_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	var names := PackedStringArray()
	for event in events:
		if event is InputEventKey:
			names.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode))
		elif event is InputEventMouseButton:
			names.append("Left mouse" if event.button_index == MOUSE_BUTTON_LEFT else "Mouse %d" % event.button_index)
	return " / ".join(names) if not names.is_empty() else "Unbound"

func _begin_remap(action: String, button: Button) -> void:
	if waiting_for_input:
		return
	waiting_for_input = true
	action_to_remap = action
	active_remap_button = button
	button.text = "Press a key..."
	_set_hint("Escape cancels. Choose an unused key or mouse button.")
	for other in remap_buttons.values():
		other.disabled = other != button

func _input(event: InputEvent) -> void:
	if not waiting_for_input:
		return
	if event.is_echo() or not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_finish_remap()
		return
	if event is InputEventKey and event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	var clean: InputEvent
	var data: Dictionary
	if event is InputEventKey:
		clean = InputEventKey.new()
		clean.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		data = {"kind": "key", "code": clean.physical_keycode}
	else:
		clean = InputEventMouseButton.new()
		clean.button_index = event.button_index
		data = {"kind": "mouse", "code": clean.button_index}
	for action in ACTIONS:
		if action != action_to_remap and InputMap.action_has_event(action, clean):
			_set_hint("Already used for %s. Choose another key, or Escape to cancel." % ACTIONS[action])
			return
	InputMap.action_erase_events(action_to_remap)
	InputMap.action_add_event(action_to_remap, clean)
	_save("keys", action_to_remap, data)
	_finish_remap()

func _finish_remap() -> void:
	active_remap_button.text = get_action_key_name(action_to_remap)
	waiting_for_input = false
	action_to_remap = ""
	active_remap_button = null
	for button in remap_buttons.values():
		button.disabled = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	if waiting_for_input:
		_finish_remap()
	get_tree().change_scene_to_file("res://title_screen.tscn")

func _save(section: String, key: String, value: Variant) -> void:
	preferences.set_value(section, key, value)
	var result := preferences.save(SAVE_PATH)
	_set_hint("Changes saved automatically." if result == OK else "Could not save settings (%s)." % error_string(result))

func _volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	AudioServer.set_bus_mute(0, value <= -29.5)
	_save("audio", "volume", value)

func _brightness_changed(value: float) -> void:
	_save("display", "brightness", value)
	$"Cursor LightUp".energy = 1.8 * brightness_scale()
	$"Cursor LightUp".texture_scale = remap(value, 0.5, 3.0, 1.5, 3.5)

func _fullscreen_changed(enabled: bool) -> void:
	apply_fullscreen(enabled)
	_save("display", "fullscreen", enabled)


func _process(delta: float) -> void:
	_light_time += delta
	$"Cursor LightUp".global_position = $"Cursor LightUp".global_position.lerp(get_global_mouse_position(), 1.0 - exp(-12.0 * delta))
	$"Cursor LightUp".energy = 1.8 * brightness_scale() * (0.6 if waiting_for_input else 1.0) + sin(_light_time * 18.0) * 0.03 + sin(_light_time * 43.0) * 0.02

func _set_hint(message: String) -> void:
	var hint := get_node_or_null("Hint")
	if hint is Label:
		hint.text = message
