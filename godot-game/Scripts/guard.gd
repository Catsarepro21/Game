extends CharacterBody2D

signal health_updated(current: int, maximum: int)
signal died

@export_range(1, 10) var max_health: int = 2
var current_health: int = 2

signal attack_started(target: Node2D)
signal attack_fired(target: Node2D)

enum GuardType {Stationary, Stationary_Sweeping, Patrol_Points, Spin_360}
enum PatrolRoute { Loop, Ping_Pong }

@export_category("Behavior")
@export var behavior: GuardType = GuardType.Stationary
@export_range(0.0, 500.0) var move_speed: float = 90.0
## Radians per second.
@export_range(0.1, 20.0) var turn_speed: float = 4.0

@export_group("Sweep Settings")
@export_range(0.0, 10.0) var sweep_speed: float = 1.5
## Degrees to either side of the starting direction.
@export_range(0.0, 180.0) var sweep_angle_deg: float = 45.0

@export_group("Spin Settings")
@export_range(1.0, 360.0) var spin_speed_deg: float = 90.0
@export var spin_clockwise: bool = true

@export_group("Patrol Settings")
## Drag markers here in order. Positions are captured at startup so child markers work too.
@export var patrol_points: Array[Marker2D] = []
@export var patrol_route: PatrolRoute = PatrolRoute.Loop
@export_range(0.0, 30.0) var wait_time: float = 1.5
@export_range(1.0, 32.0) var arrival_distance: float = 4.0

@export_group("Attack")
@export var attack_enabled: bool = true
@export_range(1.0, 2000.0) var attack_range: float = 200.0
@export_range(1.0, 360.0) var vision_angle_deg: float = 45.0
@export_range(1, 10) var attack_damage: int = 1
@export_range(0.1, 10.0) var attack_cooldown: float = 1.5
@export_range(0.1, 5.0) var attack_windup: float = 0.5
## Include the player and walls/doors in this mask.
@export_flags_2d_physics var sight_collision_mask: int = 1

var _home_angle: float
var _sweep_time: float = 0.0
var _stops: Array[Dictionary] = []
var _point_index: int = 0
var _route_direction: int = 1
var _at_stop: bool = false
var _facing_done: bool = false
var _wait_remaining: float = 0.0
var _spin_remaining: float = 0.0
var _cooldown: float = 0.0
var _windup_remaining: float = 0.0
var _target: Node2D
var _tracer_remaining: float = 0.0
var _shot_end: Vector2

func _ready() -> void:
	current_health = max_health
	_home_angle = global_rotation
	for point in patrol_points:
		if not is_instance_valid(point):
			continue
		var stop: Dictionary = {"position": point.global_position, "angle": point.global_rotation,
			"pause": wait_time, "face": false, "spin": false}
		if point.get_script() == preload("res://Scripts/guard_waypoint.gd"):
			stop.pause = point.pause_seconds if point.pause_seconds >= 0.0 else wait_time
			stop.face = point.face_marker_direction
			stop.spin = point.spin_at_stop
		_stops.append(stop)

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_tracer_remaining = maxf(0.0, _tracer_remaining - delta)
	velocity = Vector2.ZERO
	if _windup_remaining > 0.0:
		_update_attack(delta)
	else:
		_update_movement(delta)
		if attack_enabled and _cooldown <= 0.0:
			for candidate in get_tree().get_nodes_in_group("player"):
				if candidate is Node2D and _can_attack(candidate):
					_target = candidate
					_windup_remaining = attack_windup
					velocity = Vector2.ZERO
					attack_started.emit(_target)
					break
	move_and_slide()
	queue_redraw()

func _update_movement(delta: float) -> void:
	match behavior:
		GuardType.Stationary:
			pass
		GuardType.Stationary_Sweeping:
			_sweep_time += delta
			global_rotation = _home_angle + sin(_sweep_time * sweep_speed) * deg_to_rad(sweep_angle_deg)
		GuardType.Spin_360:
			global_rotation += _spin_step(delta)
		GuardType.Patrol_Points:
			_update_patrol(delta)

func _spin_step(delta: float) -> float:
	return deg_to_rad(spin_speed_deg) * delta * (1.0 if spin_clockwise else -1.0)

func _update_patrol(delta: float) -> void:
	if _stops.is_empty():
		return
	var stop: Dictionary = _stops[_point_index]
	if not _at_stop:
		var offset: Vector2 = stop.position - global_position
		if offset.length() > arrival_distance:
			global_rotation = rotate_toward(global_rotation, offset.angle(), turn_speed * delta)
			velocity = offset.normalized() * minf(move_speed, offset.length() / delta)
			return
		_at_stop = true
		_facing_done = false
		_wait_remaining = stop.pause
		_spin_remaining = TAU if stop.spin else 0.0
	if stop.face and not _facing_done:
		global_rotation = rotate_toward(global_rotation, stop.angle, turn_speed * delta)
		if absf(angle_difference(global_rotation, stop.angle)) > 0.01:
			return
		_facing_done = true
	if _spin_remaining > 0.0:
		var step: float = minf(absf(_spin_step(delta)), _spin_remaining)
		global_rotation += step * (1.0 if spin_clockwise else -1.0)
		_spin_remaining -= step
		return
	_wait_remaining -= delta
	if _wait_remaining > 0.0:
		return
	if _stops.size() > 1:
		if patrol_route == PatrolRoute.Ping_Pong:
			if _point_index == _stops.size() - 1:
				_route_direction = -1
			elif _point_index == 0:
				_route_direction = 1
			_point_index += _route_direction
		else:
			_point_index = (_point_index + 1) % _stops.size()
	_at_stop = false

func _can_attack(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
		return false
	if "current_health" in candidate and candidate.current_health <= 0:
		return false
	var offset := candidate.global_position - global_position
	if offset.length() > attack_range:
		return false
	if absf(angle_difference(global_rotation, offset.angle())) > deg_to_rad(vision_angle_deg * 0.5):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, candidate.global_position,
		sight_collision_mask, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == candidate

func _update_attack(delta: float) -> void:
	if not attack_enabled or not _can_attack(_target):
		_windup_remaining = 0.0
		_target = null
		return
	global_rotation = rotate_toward(global_rotation,
		(_target.global_position - global_position).angle(), turn_speed * delta)
	_windup_remaining = maxf(0.0, _windup_remaining - delta)
	if _windup_remaining <= 0.0:
		_shot_end = _target.global_position
		_tracer_remaining = 0.12
		_target.take_damage(attack_damage)
		_cooldown = attack_cooldown
		attack_fired.emit(_target)
		_target = null

func _draw() -> void:
	if _windup_remaining > 0.0 and is_instance_valid(_target):
		draw_line(Vector2(30, 0), to_local(_target.global_position), Color(1, 0.15, 0.1, 0.7), 2.0)
	elif _tracer_remaining > 0.0:
		draw_line(Vector2(30, 0), to_local(_shot_end), Color(1, 0.8, 0.2), 4.0)

func take_damage(amount: int = 1) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = maxi(0, current_health - amount)
	health_updated.emit(current_health, max_health)
	if current_health == 0:
		_windup_remaining = 0.0
		velocity = Vector2.ZERO
		died.emit()
		queue_free()
	else:
		$Sprite2D.modulate = Color(1.0, 0.35, 0.35)
		create_tween().tween_property($Sprite2D, "modulate", Color.WHITE, 0.2)
