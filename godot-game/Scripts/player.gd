extends CharacterBody2D


const SPEED: float = 250.0
const JUMP_VELOCITY = -400.0


func _physics_process(delta: float) -> void:
	look_at(get_global_mouse_position())
	
	var input_vector :=Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	
	move_and_slide()
