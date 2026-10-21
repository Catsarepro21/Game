extends CharacterBody2D

signal slot_changed(slot: int)
signal ammo_updated(current: int, maximum: int)
signal health_updated(current: int, maximum: int)
signal shot_fired(origin: Vector2, direction: Vector2)
signal died

enum Slot { GUN = 1, SPYGLASS = 2 }

const SPEED: float = 250.0
@export_range(1, 3) var max_health: int = 3
@export_range(1, 99) var max_ammo: int = 3
var current_health: int = 3
var current_ammo: int = 3
var active_slot: int = Slot.GUN

func _enter_tree() -> void:
	add_to_group("player")

func _ready() -> void:
	current_health = max_health
	current_ammo = max_ammo

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("swap_item"):
		set_active_slot(Slot.SPYGLASS if active_slot == Slot.GUN else Slot.GUN)
	elif event.is_action_pressed("equip_gun"):
		set_active_slot(Slot.GUN)
	elif event.is_action_pressed("equip_spyglass"):
		set_active_slot(Slot.SPYGLASS)
	elif event.is_action_pressed("reload"):
		reload()
	elif event.is_action_pressed("fire"):
		fire()
	else:
		return
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	if current_health <= 0:
		velocity = Vector2.ZERO
		return
	look_at(get_global_mouse_position())
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vector * SPEED
	move_and_slide()

func set_active_slot(slot: int) -> void:
	if current_health <= 0 or slot not in [Slot.GUN, Slot.SPYGLASS] or slot == active_slot:
		return
	active_slot = slot
	slot_changed.emit(active_slot)

func fire() -> bool:
	if current_health <= 0 or active_slot != Slot.GUN or current_ammo <= 0:
		return false
	current_ammo -= 1
	ammo_updated.emit(current_ammo, max_ammo)
	shot_fired.emit(global_position, Vector2.RIGHT.rotated(global_rotation))
	return true

func reload() -> void:
	if current_health <= 0 or active_slot != Slot.GUN or current_ammo == max_ammo:
		return
	current_ammo = max_ammo
	ammo_updated.emit(current_ammo, max_ammo)

func take_damage(amount: int = 1) -> void:
	if amount <= 0 or current_health <= 0:
		return
	current_health = maxi(0, current_health - amount)
	health_updated.emit(current_health, max_health)
	if current_health == 0:
		died.emit()

func heal(amount: int = 1) -> void:
	if amount <= 0 or current_health <= 0 or current_health == max_health:
		return
	current_health = mini(max_health, current_health + amount)
	health_updated.emit(current_health, max_health)
