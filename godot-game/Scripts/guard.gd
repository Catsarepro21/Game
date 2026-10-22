extends CharacterBody2D

enum GuardType {Stationary, Stationary_Sweeping, Patrol_Points, Spin_360}

@export_category("Behavior")
@export var behavior: GuardType = GuardType.Stationary
@export var move_speed: float = 90.0
@export var turn_speed: float = 4.00

@export_group("Sweep_Settings")
@export var sweep_speed: float = 1.5
@export var sweep_angle_deg: float = 45.0

# Yo drag marker 2d nodes into the thing where you want it to patrol.
@export_group("Patrol_Settings")
@export var patrol_points: Array[Marker2D] = []
@export var wait_time:float = 1.5
