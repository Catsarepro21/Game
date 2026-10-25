extends PointLight2D
const SETTINGS = preload("res://Scripts/settings.gd")
var lifetime: float = 6.0
var remaining: float = 6.0
var radius: float = 125.0

func _ready() -> void:
	add_to_group("player_visibility_lights")
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.7), Color(1,1,1,0)])
	var radial := GradientTexture2D.new()
	radial.gradient = gradient
	radial.width = 256
	radial.height = 256
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(1.0, 0.5)
	texture = radial
	texture_scale = radius * 2.0 / 256.0
	color = Color(0.55, 0.9, 1.0)
	energy = 2.0 * SETTINGS.brightness_scale()
	shadow_enabled = true
	shadow_filter = Light2D.SHADOW_FILTER_PCF5
	remaining = lifetime

func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	energy = 2.0 * SETTINGS.brightness_scale() * minf(1.0, remaining / 0.6)
	if remaining <= 0.0:
		queue_free()
