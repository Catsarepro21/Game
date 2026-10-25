extends Node2D

const SETTINGS = preload("res://Scripts/settings.gd")
enum Lesson { MOVE, AIM, SCOUT, BREACH, SHOOT, FINAL, COMPLETE }
var lesson: int = Lesson.MOVE
var _aim_time: float = 0.0
var _breach_killed: bool = false
var _target_killed: bool = false
var _patrol_killed: bool = false
var _objective: Vector2 = Vector2(600, 540)
var _leaving: bool = false
@onready var player = $Player
@onready var _guide: Node2D = $Instructions/Guide
@onready var _heading: Label = $Instructions/Panel/Content/Heading
@onready var _prompt: Label = $Instructions/Panel/Content/Prompt

func _ready() -> void:
	$BreachDoor.set_process_unhandled_input(false)
	$BreachGuard.died.connect(func(): _breach_killed = true)
	$PracticeGuard.died.connect(func(): _target_killed = true)
	$PatrolGuard.died.connect(func(): _patrol_killed = true)
	_guide.draw.connect(_draw_guide)
	$Instructions/Completion/Content/Play.pressed.connect(func(): _leave("res://level_1.tscn"))
	$Instructions/Completion/Content/Title.pressed.connect(func(): _leave("res://title_screen.tscn"))
	_refresh_prompt()

func binding(action: String) -> String:
	var result := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
		elif event is InputEventMouseButton:
			result.append("Left click" if event.button_index == MOUSE_BUTTON_LEFT else "Mouse %d" % event.button_index)
	return " / ".join(result) if not result.is_empty() else "Unbound"

func _physics_process(delta: float) -> void:
	_guide.queue_redraw()
	if player.current_health <= 0:
		_heading.text = "TRY AGAIN"
		_prompt.text = "%s restarts the tutorial. Escape returns to the title." % binding("restart")
		return
	match lesson:
		Lesson.MOVE:
			if player.global_position.distance_to(_objective) < 70:
				_advance(Lesson.AIM)
		Lesson.AIM:
			var angle: float = (_objective - player.global_position).angle()
			if absf(angle_difference(player.global_rotation, angle)) < 0.18:
				_aim_time += delta
			else:
				_aim_time = 0.0
			if _aim_time >= 0.5:
				_advance(Lesson.SCOUT)
		Lesson.SCOUT:
			if is_instance_valid(player._peek_light):
				var spot: Vector2 = player._peek_light.global_position
				if spot.x > 1620 and spot.distance_to($BreachGuard.global_position) < player.peek_radius:
					_advance(Lesson.BREACH)
		Lesson.BREACH:
			if _breach_killed:
				_advance(Lesson.SHOOT)
		Lesson.SHOOT:
			if _target_killed:
				_advance(Lesson.FINAL)
		Lesson.FINAL:
			var patrol := get_node_or_null("PatrolGuard")
			if is_instance_valid(patrol):
				patrol.attack_enabled = player.position.x > 2780
			_objective = Vector2(3800, 540) if _patrol_killed else Vector2(2975, 540)
			if _patrol_killed and player.position.distance_to(Vector2(3800, 540)) < 80:
				_advance(Lesson.COMPLETE)
	_refresh_prompt()

func _advance(next: int) -> void:
	lesson = next
	match lesson:
		Lesson.AIM:
			_objective = Vector2(760, 320)
		Lesson.SCOUT:
			$MoveGate.queue_free()
			_objective = Vector2(1450, 540)
		Lesson.BREACH:
			$BreachDoor.set_process_unhandled_input(true)
			_objective = Vector2(1550, 540)
		Lesson.SHOOT:
			$BreachGate.queue_free()
			_objective = Vector2(2220, 540)
		Lesson.FINAL:
			$RangeGate.queue_free()
			_objective = Vector2(2975, 540)
		Lesson.COMPLETE:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
			player._peek_preview.hide()
			$Instructions/Completion.show()
			$Instructions/Completion/Content/Play.grab_focus()
	_guide.queue_redraw()
	_refresh_prompt()

func _refresh_prompt() -> void:
	if player.current_health <= 0:
		return
	var instructions: Array[String] = [
		"Use %s / %s / %s / %s to reach the green marker." % [binding("move_up"), binding("move_left"), binding("move_down"), binding("move_right")],
		"Move the mouse to point your flashlight at the green marker. Hold your aim briefly.",
		"Approach the door. Equip the spyglass [%s], then %s beyond the door to reveal the guard." % [binding("equip_spyglass"), binding("fire")],
		"Approach the door and press [%s]. Its swing will take out the guard on the other side." % binding("interact"),
		"Only %d bullets for this entire attempt. Equip the gun [%s], aim carefully, and %s. Every guard takes one hit to kill" % [player.max_ammo, binding("equip_gun"), binding("fire")],
		"%d bullet(s) left. Remember, you have a limited number of bullets, so use a door to conserve ammo, or aim carefully. Reach the exit." % player.current_ammo,
		"Training complete. You are ready for the first level."
	]
	var titles: Array[String] = ["MOVING", "AIMING", "SCOUTING", "PROGRESS", "LIMITATIOSN", "TRY IT", "TRAINING COMPLETE"]
	_heading.text = titles[lesson]
	_prompt.text = instructions[lesson]
	if lesson == Lesson.SHOOT and player.current_ammo == 0 and not _target_killed:
		_prompt.text = "No bullets left. Press [%s] to restart the whole attempt, then make your shots count." % binding("restart")
	elif lesson == Lesson.FINAL and not _patrol_killed and player.current_ammo == 0:
		_prompt.text = "No bullets left. Scout and time a door hit on the patrol. If the breach misses, [%s] restarts the whole attempt." % binding("restart")
	elif lesson == Lesson.FINAL and _patrol_killed:
		_prompt.text = "Patrol cleared. Follow the green marker to the exit."
	$Instructions/Help.text = "Escape: title  |  Swap: %s  |  Restart attempt: %s" % [binding("swap_item"), binding("restart")]

func _draw_guide() -> void:
	if lesson == Lesson.COMPLETE or player.current_health <= 0:
		return
	var screen := get_viewport().get_canvas_transform() * _objective
	_guide.draw_arc(screen, 26.0, 0, TAU, 48, Color(0.35, 1, 0.45, 0.95), 3.0, true)
	_guide.draw_circle(screen, 4.0, Color(0.35, 1, 0.45))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not event.is_echo() and lesson != Lesson.COMPLETE:
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave("res://title_screen.tscn")

func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
