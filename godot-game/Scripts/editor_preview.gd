@tool
extends RefCounted

static func belongs_to_scene(node: Node, scene: Node) -> bool:
	return is_instance_valid(scene) and (node == scene or scene.is_ancestor_of(node))

static func is_active_scene(node: Node) -> bool:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return false
	var editor := Engine.get_singleton("EditorInterface")
	return belongs_to_scene(node, editor.get_edited_scene_root())
