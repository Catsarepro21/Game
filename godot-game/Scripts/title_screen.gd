extends Node2D

@onready var Settings_Button: Button = $Settings

func _ready() -> void:
	Settings_Button.pressed.connect(_on_settings_button_pressed)
	
func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")
