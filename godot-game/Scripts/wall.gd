@tool
extends StaticBody2D

@export var wall_size: Vector2 = Vector2(128, 32):
	set(value):
		wall_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_queue_update()
@export var wall_color: Color = Color(0.28, 0.31, 0.33, 1):
	set(value):
		wall_color = value
		_queue_update()
var _update_pending: bool = false

func _ready() -> void:
	_apply_geometry()

func _queue_update() -> void:
	if not is_node_ready() or _update_pending:
		return
	_update_pending = true
	_apply_geometry.call_deferred()

func _apply_geometry() -> void:
	_update_pending = false
	var half := wall_size * 0.5
	($Collision.shape as RectangleShape2D).size = wall_size
	$Surface.position = -half
	$Surface.size = wall_size
	$Surface.color = wall_color
	$Shadow.occluder.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)])
