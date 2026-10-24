@tool
extends Marker2D
## Optional patrol stop settings. Plain Marker2D nodes also work.
@export_range(-1.0, 30.0) var pause_seconds: float = -1.0
@export var face_marker_direction: bool = false
@export var spin_at_stop: bool = false
