extends Node
## Only player-owned light can reveal the world. Enemy lighting remains real,
## but the final world image is masked by a second, player-only light pass.
const SOURCE_GROUP: StringName = &"player_visibility_lights"
var _mask: SubViewport
var _surface: Polygon2D
var _overlay: ColorRect
var _lights: Dictionary = {}
var _occluders: Dictionary = {}

func _ready() -> void:
	_mask = SubViewport.new()
	_mask.name = "PlayerLightMask"
	_mask.world_2d = World2D.new()
	_mask.disable_3d = true
	_mask.gui_disable_input = true
	_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_mask)
	var darkness := CanvasModulate.new()
	darkness.color = Color.BLACK
	_mask.add_child(darkness)
	_surface = Polygon2D.new()
	_surface.color = Color.WHITE
	_mask.add_child(_surface)
	var layer := CanvasLayer.new()
	layer.name = "VisibilityOverlay"
	layer.layer = 1
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://Scripts/player_visibility.gdshader")
	shader_material.set_shader_parameter("player_visibility", _mask.get_texture())
	_overlay.material = shader_material
	layer.add_child(_overlay)
	_scan_occluders(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_sync)
	_sync()

func _scan_occluders(node: Node) -> void:
	if node == self:
		return
	if node is LightOccluder2D:
		_add_occluder(node)
	for child in node.get_children():
		_scan_occluders(child)

func _on_node_added(node: Node) -> void:
	if node is LightOccluder2D and not is_ancestor_of(node):
		_add_occluder(node)

func _add_occluder(source: LightOccluder2D) -> void:
	if _occluders.has(source.get_instance_id()):
		return
	var copy := LightOccluder2D.new()
	copy.occluder = source.occluder
	_mask.add_child(copy)
	_occluders[source.get_instance_id()] = {"source": source, "copy": copy}

func _sync() -> void:
	var view := get_viewport()
	var dimensions := Vector2i(view.get_visible_rect().size)
	if dimensions.x < 2 or dimensions.y < 2:
		return
	if _mask.size != dimensions:
		_mask.size = dimensions
	_overlay.size = Vector2(dimensions)
	_mask.canvas_transform = view.canvas_transform
	_mask.global_canvas_transform = view.global_canvas_transform
	var inverse := (view.global_canvas_transform * view.canvas_transform).affine_inverse()
	_surface.polygon = PackedVector2Array([inverse * Vector2.ZERO,
		inverse * Vector2(dimensions.x, 0), inverse * Vector2(dimensions),
		inverse * Vector2(0, dimensions.y)])
	for source in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if source is PointLight2D and not _lights.has(source.get_instance_id()):
			var copy := PointLight2D.new()
			copy.texture = source.texture
			_mask.add_child(copy)
			_lights[source.get_instance_id()] = {"source": source, "copy": copy}
	for id in _lights.keys():
		var pair: Dictionary = _lights[id]
		if not is_instance_valid(pair.source) or not pair.source.is_in_group(SOURCE_GROUP):
			pair.copy.queue_free()
			_lights.erase(id)
			continue
		var source: PointLight2D = pair.source
		var copy: PointLight2D = pair.copy
		copy.enabled = source.enabled and source.is_visible_in_tree()
		copy.global_transform = source.global_transform
		copy.texture = source.texture
		copy.texture_scale = source.texture_scale
		copy.offset = source.offset
		copy.color = Color.WHITE
		copy.energy = source.energy
		copy.shadow_enabled = source.shadow_enabled
		copy.shadow_filter = source.shadow_filter
		copy.shadow_filter_smooth = source.shadow_filter_smooth
		copy.shadow_item_cull_mask = source.shadow_item_cull_mask
	for id in _occluders.keys():
		var pair: Dictionary = _occluders[id]
		if not is_instance_valid(pair.source):
			pair.copy.queue_free()
			_occluders.erase(id)
			continue
		var source: LightOccluder2D = pair.source
		var copy: LightOccluder2D = pair.copy
		copy.visible = source.is_visible_in_tree()
		copy.global_transform = source.global_transform
		copy.occluder = source.occluder
		copy.occluder_light_mask = source.occluder_light_mask

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
