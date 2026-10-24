extends Node2D

@onready var cursor_light: PointLight2D = $"Cursor LightUp"
@onready var volume_slider: HSlider = $VBoxContainer/VolumeSlider
@onready var brightness_slider: HSlider = $"VBoxContainer/Brightness Slider"
@onready var fullscreen_check: CheckButton = $"VBoxContainer/Fullscreen Check"
@onready var keybind_list: VBoxContainer = $VBoxContainer/Keybinder


var baseenergy: float = 1.8
var time_passed: float = 0.0

var remap_actions: Dictionary = {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"fire": "Fire Weapon",
	"reload": "Reload",
	"slot_1": "Equip Gun",
	"slot_2": "Equip Spyglass"
}

var waiting_for_input: bool = false
var action_to_remap: String = ""
var active_remap_button: Button = null

func _ready() -> void:
	
	await  get_tree().process_frame
	brightness_slider.min_value = 0.5
	brightness_slider.max_value = 3.0
	brightness_slider.step = 0.05
	brightness_slider.value = baseenergy
	
	volume_slider.min_value = -30.0
	volume_slider.max_value = 0.0
	volume_slider.value = AudioServer.get_bus_volume_db(0)
	
	brightness_slider.value_changed.connect(_on_brightness_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	create_keybind_rows()

func _process(delta: float) -> void:
	time_passed += delta
	cursor_light.global_position = cursor_light.global_position.lerp(get_global_mouse_position(), 12.0 * delta)
	var flicker: float = sin(time_passed * 18.0) * 0.03 + sin(time_passed * 43.0) * 0.02
	cursor_light.energy = baseenergy + flicker

func create_keybind_rows() -> void:
	for action in remap_actions:
		if not InputMap.has_action(action):
			continue 
			
		var row := HBoxContainer.new()
		
		var label := Label.new()
		label.text = remap_actions[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 28)
		button.text = get_action_key_name(action)
		button.pressed.connect(_on_remap_button_pressed.bind(action, button))
		
		row.add_child(label)
		row.add_child(button)
		keybind_list.add_child(row)

func get_action_key_name(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return events[0].as_text().trim_suffix(" (Physical)")

func _on_remap_button_pressed(action: String, button: Button) -> void:
	if waiting_for_input:
		return
	waiting_for_input = true
	action_to_remap = action
	active_remap_button = button
	button.text = "Press key..."
	baseenergy *= 0.6

func _input(event: InputEvent) -> void:
	if not waiting_for_input:
		return
	
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		get_viewport().set_input_as_handled()
		
		# Press Escape to cancel rebinding without wiping the key
		if event is InputEventKey and event.keycode == KEY_ESCAPE:
			active_remap_button.text = get_action_key_name(action_to_remap)
		else:
			InputMap.action_erase_events(action_to_remap)
			InputMap.action_add_event(action_to_remap, event)
			active_remap_button.text = event.as_text().trim_suffix(" (Physical)")
		
		baseenergy /= 0.6
		waiting_for_input = false
		action_to_remap = ""
		active_remap_button = null

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		var screen_idx = DisplayServer.window_get_current_screen()
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_idx)
		var center_pos = screen_rect.position + (screen_rect.size / 2) - (Vector2i(1280, 720) / 2)
		DisplayServer.window_set_position(center_pos)
		
func _on_brightness_changed(value: float) -> void:
	baseenergy = value
	cursor_light.texture_scale = remap(value, 0.5, 3.0, 1.5, 3.5)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	AudioServer.set_bus_mute(0, value <= -29.5)
