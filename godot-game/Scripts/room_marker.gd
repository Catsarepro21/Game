@tool
extends Node2D

@export var heading: String = "ROOM":
	set(value):
		heading = value
		if is_node_ready():
			$Label.text = heading

func _ready() -> void:
	$Label.text = heading
