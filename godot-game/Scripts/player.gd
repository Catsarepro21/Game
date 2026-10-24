extends CharacterBody2D

signal slot_changed(slot: int)
signal ammo_updated(current: int, maximum: int)
signal health_updated(current: int, maximum: int)
signal shot_fired(origin: Vector2, direction: Vector2)
signal died

enum Slot { GUN = 1, SPYGLASS = 2 }
const SPEED: float = 250.0
const PEEK_LIGHT = preload("res://Scripts/peek_light.gd")
@export_range(1, 3) var max_health: int = 3
@export_range(1, 99) var max_ammo: int = 3
@export_group("Gun")
@export_range(50.0, 2000.0) var gun_range: float = 700.0
@export_range(1, 10) var gun_damage: int = 1
@export_range(0.1, 2.0) var fire_interval: float = 0.3
@export_range(0.1, 5.0) var reload_duration: float = 1.2
@export_flags_2d_physics var gun_collision_mask: int = 1
@export_group("Peek Light")
@export_range(40.0, 600.0) var peek_range: float = 240.0
@export_range(30.0, 300.0) var peek_radius: float = 125.0
@export_range(1.0, 20.0) var peek_duration: float = 6.0
@export_range(0.1, 10.0) var peek_cooldown: float = 2.0
@export_flags_2d_physics var placement_collision_mask: int = 1

var current_health: int = 3
var current_ammo: int = 3
var active_slot: int = Slot.GUN
var reload_remaining: float = 0.0
var peek_cooldown_remaining: float = 0.0
var _fire_remaining: float = 0.0
var _hurt_remaining: float = 0.0
var _tracer_remaining: float = 0.0
var _shot_end: Vector2
var _peek_light: PointLight2D
var _held_item: Sprite2D

func _enter_tree() -> void:
	add_to_group("player")

func _ready() -> void:
	current_health = max_health
	current_ammo = max_ammo
	for child in get_children():
		if child is PointLight2D:
			child.add_to_group("player_visibility_lights")
	_held_item = Sprite2D.new()
	_held_item.position = Vector2(34, 4)
	_held_item.scale = Vector2(0.45, 0.45)
	_held_item.material = CanvasItemMaterial.new()
	_held_item.material.light_mode = CanvasItemMaterial.LIGHT_MODE_NORMAL
	add_child(_held_item)
	_update_held_item()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if current_health <= 0:
		if event.is_action_pressed("reload"):
			get_tree().reload_current_scene()
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
		use_active_item(get_global_mouse_position())
	else:
		return
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_fire_remaining = maxf(0.0, _fire_remaining - delta)
	peek_cooldown_remaining = maxf(0.0, peek_cooldown_remaining - delta)
	_hurt_remaining = maxf(0.0, _hurt_remaining - delta)
	_tracer_remaining = maxf(0.0, _tracer_remaining - delta)
	if reload_remaining > 0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0:
			current_ammo = max_ammo
			ammo_updated.emit(current_ammo, max_ammo)
	$Sprite2D.modulate = Color(1, 0.35, 0.35) if _hurt_remaining > 0 else Color.WHITE
	if current_health <= 0:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	look_at(get_global_mouse_position())
	velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * SPEED
	move_and_slide()
	if is_instance_valid(_peek_light) and global_position.distance_to(_peek_light.global_position) > peek_range + 16.0:
		_peek_light.queue_free()
	queue_redraw()

func _update_held_item() -> void:
	if not is_instance_valid(_held_item):
		return
	var atlas := AtlasTexture.new()
	if active_slot == Slot.GUN:
		atlas.atlas = preload("res://Assets/Gun.png")
		atlas.region = Rect2(32, 24, 76, 52)
	else:
		atlas.atlas = preload("res://Assets/Spyglass_Thingy.png")
		atlas.region = Rect2(8, 4, 112, 100)
	_held_item.texture = atlas

func set_active_slot(slot: int) -> void:
	if current_health <= 0 or slot not in [Slot.GUN, Slot.SPYGLASS] or slot == active_slot:
		return
	active_slot = slot
	reload_remaining = 0.0
	_update_held_item()
	slot_changed.emit(active_slot)

func use_active_item(target_position: Vector2) -> bool:
	if active_slot == Slot.SPYGLASS:
		return place_peek_light(target_position)
	return fire()

func fire() -> bool:
	if current_health <= 0 or active_slot != Slot.GUN or current_ammo <= 0 or reload_remaining > 0 or _fire_remaining > 0:
		return false
	current_ammo -= 1
	_fire_remaining = fire_interval
	var direction := Vector2.RIGHT.rotated(global_rotation)
	_shot_end = global_position + direction * gun_range
	var query := PhysicsRayQueryParameters2D.create(global_position, _shot_end, gun_collision_mask, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_shot_end = hit.position
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(gun_damage)
	_tracer_remaining = 0.1
	ammo_updated.emit(current_ammo, max_ammo)
	shot_fired.emit(global_position, direction)
	queue_redraw()
	return true

func reload() -> void:
	if current_health <= 0 or active_slot != Slot.GUN or current_ammo == max_ammo or reload_remaining > 0:
		return
	reload_remaining = reload_duration

func peek_target(target_position: Vector2) -> Vector2:
	return global_position + (target_position - global_position).limit_length(peek_range)

func can_place_peek(target_position: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = target_position
	query.collision_mask = placement_collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_point(query):
		if hit.collider is StaticBody2D or hit.collider is AnimatableBody2D:
			return false
	return true

func place_peek_light(target_position: Vector2) -> bool:
	if current_health <= 0 or active_slot != Slot.SPYGLASS or peek_cooldown_remaining > 0:
		return false
	var destination := peek_target(target_position)
	if not can_place_peek(destination):
		return false
	if is_instance_valid(_peek_light):
		_peek_light.queue_free()
	_peek_light = PEEK_LIGHT.new()
	_peek_light.radius = peek_radius
	_peek_light.lifetime = peek_duration
	get_parent().add_child(_peek_light)
	_peek_light.global_position = destination
	peek_cooldown_remaining = peek_cooldown
	return true

func take_damage(amount: int = 1) -> void:
	if amount <= 0 or current_health <= 0 or _hurt_remaining > 0:
		return
	current_health = maxi(0, current_health - amount)
	_hurt_remaining = 0.5
	health_updated.emit(current_health, max_health)
	if current_health == 0:
		reload_remaining = 0.0
		if is_instance_valid(_peek_light):
			_peek_light.queue_free()
		died.emit()

func heal(amount: int = 1) -> void:
	if amount <= 0 or current_health <= 0 or current_health == max_health:
		return
	current_health = mini(max_health, current_health + amount)
	health_updated.emit(current_health, max_health)

func _exit_tree() -> void:
	if is_instance_valid(_peek_light):
		_peek_light.queue_free()

func _draw() -> void:
	if current_health <= 0:
		return
	if _tracer_remaining > 0:
		draw_line(Vector2(34, 0), to_local(_shot_end), Color(1, 0.85, 0.4), 3.0)
	if active_slot == Slot.SPYGLASS:
		var destination := peek_target(get_global_mouse_position())
		var valid := can_place_peek(destination) and peek_cooldown_remaining <= 0
		var tint := Color(0.4, 0.9, 1.0, 0.65) if valid else Color(1, 0.35, 0.3, 0.5)
		draw_arc(Vector2.ZERO, peek_range, 0, TAU, 96, Color(0.4,0.9,1,0.15), 1.0)
		draw_line(Vector2.ZERO, to_local(destination), tint * Color(1,1,1,0.4), 1.0)
		draw_arc(to_local(destination), peek_radius, 0, TAU, 64, tint, 2.0)
		draw_circle(to_local(destination), 4.0, tint)
