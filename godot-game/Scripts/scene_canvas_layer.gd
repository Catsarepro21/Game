@tool
extends CanvasLayer

const EDITOR_PREVIEW = preload("res://Scripts/editor_preview.gd")

func _ready() -> void:
	_update_preview()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	_update_preview()

func _update_preview() -> void:
	visible = EDITOR_PREVIEW.is_active_scene(self) if Engine.is_editor_hint() else true
