@tool
extends PointLight2D

@export_range(1.0, 175.0) var cone_angle_deg: float = 65.0:
	set(value):
		cone_angle_deg = value
		_queue_texture_update()
@export_range(1.0, 2000.0) var cone_distance: float = 450.0:
	set(value):
		cone_distance = value
		_queue_texture_update()

var _update_pending: bool = false

func _ready() -> void:
	_rebuild_texture()

func _queue_texture_update() -> void:
	if not is_inside_tree() or _update_pending:
		return
	_update_pending = true
	_rebuild_texture.call_deferred()

func _rebuild_texture() -> void:
	_update_pending = false
	const SIZE: int = 512
	var light_image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	light_image.fill(Color(0, 0, 0, 0))
	var half_angle := deg_to_rad(cone_angle_deg * 0.5)
	var edge_width := deg_to_rad(0.7)
	for y in range(SIZE):
		for x in range(SIZE >> 1, SIZE):
			var direction := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2.ONE * SIZE * 0.5) / (SIZE * 0.5)
			var radius := direction.length()
			var angle := absf(direction.angle())
			if radius > 1.0 or angle > half_angle:
				continue
			var edge := 1.0 - smoothstep(maxf(0.0, half_angle - edge_width), half_angle, angle)
			var falloff := (1.0 - 0.35 * radius) * (1.0 - smoothstep(0.8, 1.0, radius))
			light_image.set_pixel(x, y, Color(1, 1, 1, edge * falloff))
	# Reuse the texture on Inspector updates rather than replacing its GPU resource.
	if texture is ImageTexture:
		(texture as ImageTexture).update(light_image)
	else:
		texture = ImageTexture.create_from_image(light_image)
	texture_scale = cone_distance * 2.0 / SIZE
	offset = Vector2.ZERO
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
