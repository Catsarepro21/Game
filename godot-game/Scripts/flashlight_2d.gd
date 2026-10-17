extends Polygon2D

@export var cone_angle_deg: float = 65.0
@export var cone_distance: float = 450.0
@export var arc_segments: int = 32

func _ready() -> void:
	var pts: PackedVector2Array = [Vector2.ZERO]
	var half_angle :=  deg_to_rad(cone_angle_deg /2.0)
	
	for i in range(arc_segments + 1):
		var t:= float(i) / float(arc_segments)
		var angle := lerpf(-half_angle, half_angle, t)
		pts.append(Vector2(cos(angle), sin(angle)) * cone_distance)
		
		polygon = pts
