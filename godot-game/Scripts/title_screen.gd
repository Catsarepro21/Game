extends Control

const SETTINGS = preload("res://Scripts/settings.gd")
var _opening: bool = false

func _ready() -> void:
	SETTINGS.load_preferences()
	$Menu/Start.pressed.connect(_start)
	$Menu/Tutorial.pressed.connect(func(): get_tree().change_scene_to_file("res://tutorial.tscn"))
	$Menu/Settings.pressed.connect(func(): get_tree().change_scene_to_file("res://settings.tscn"))
	$Menu/Quit.pressed.connect(func(): get_tree().quit())
	$Menu/Start.grab_focus()

func _start() -> void:
	if _opening:
		return
	_opening = true
	if get_tree().change_scene_to_file("res://level_1.tscn") != OK:
		_opening = false
