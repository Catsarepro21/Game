extends AnimatableBody2D

@export var open_angle_deg: float = 90.0
@export var open_duration: float = 0.12

var is_open: bool = false
var player_in_range: bool = false
var _swing_tween: Tween
var _previous_swing_rotation: float = 0.0
var _swinging: bool = false

@onready var interaction_zone: Area2D = $InteractionZone

func _ready() -> void:
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_open and event.is_action_pressed("interact"):
		breach_door()
		get_viewport().set_input_as_handled()

func breach_door() -> void:
	if is_open:
		return
	is_open = true
	_previous_swing_rotation = rotation
	_swinging = true
	_swing_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(self, "rotation_degrees", rotation_degrees + open_angle_deg, maxf(open_duration, 0.01))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false


func _physics_process(_delta: float) -> void:
	if not _swinging:
		return
	var shape_node: CollisionShape2D = $CollisionShape2D
	var delta_angle := rotation - _previous_swing_rotation
	var steps := maxi(1, int(ceil(absf(delta_angle) / deg_to_rad(3.0))))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 2.0
	for step in range(steps + 1):
		var angle := lerpf(_previous_swing_rotation, rotation, float(step) / steps)
		var pose := Transform2D(angle, scale, skew, position)
		var parent_transform := (get_parent() as Node2D).global_transform if get_parent() is Node2D else Transform2D.IDENTITY
		query.transform = parent_transform * pose * shape_node.transform
		for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
			var body: Node = hit.collider
			if body.is_in_group("guards") and body.has_method("take_damage"):
				body.take_damage(body.current_health)
	_previous_swing_rotation = rotation
	if not _swing_tween.is_running():
		_swinging = false
