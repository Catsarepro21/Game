@tool
extends CanvasModulate

const EDITOR_PREVIEW = preload("res://Scripts/editor_preview.gd")
@export var preview_in_editor: bool = false:
	set(value):
		preview_in_editor = value
		if is_node_ready():
			_update_preview()

func _ready() -> void:
	_update_preview()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_update_preview()

func _update_preview() -> void:
	visible = preview_in_editor and EDITOR_PREVIEW.is_active_scene(self) if Engine.is_editor_hint() else true
