extends AnimatableBody2D

@export var open_angle_deg: float = 90.0
@export var open_duration: float = 0.12

var is_open: bool = false
var player_in_range: bool = false

@onready var interaction_zone: Area2D = $InteractionZone

func _ready() -> void:
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_open and event.is_action_pressed("interact"):
		breach_door()

func breach_door() -> void:
	is_open = true
	var tween :=create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", open_angle_deg, open_duration)

func _on_body_entered(body: Node2D) -> void:
	print(body.name)
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
