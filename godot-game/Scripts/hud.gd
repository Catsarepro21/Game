extends CanvasLayer

@onready var gun_sprite: Sprite2D = $ItemSwap/Gun
@onready var spyglass_sprite: Sprite2D = $ItemSwap/SpyglassThingy_png
@onready var hearts_anim: AnimatedSprite2D = $MarginContainer/HBoxContainer/Hearts/AnimatedSprite2D
@onready var ammo_label: Label = $MarginContainer/HBoxContainer/AmmoCount
var _player: CharacterBody2D
var _last_health: int = -1

func _ready() -> void:
	set_active_slot(1)
	get_tree().node_added.connect(_on_node_added)
	_bind_player.call_deferred()

func _on_node_added(_node: Node) -> void:
	if not is_instance_valid(_player):
		_bind_player.call_deferred()

func _bind_player() -> void:
	if is_instance_valid(_player):
		return
	var candidate := get_tree().get_first_node_in_group("player")
	if candidate == null or not candidate.is_node_ready():
		return
	_player = candidate
	_player.connect("slot_changed", set_active_slot)
	_player.connect("ammo_updated", update_ammo)
	_player.connect("health_updated", update_health)
	_player.tree_exiting.connect(_on_player_exiting)
	_last_health = -1
	set_active_slot(_player.get("active_slot"))
	update_ammo(_player.get("current_ammo"), _player.get("max_ammo"))
	update_health(_player.get("current_health"), _player.get("max_health"))

func _on_player_exiting() -> void:
	_player = null

func set_active_slot(slot: int) -> void:
	gun_sprite.modulate.a = 1.0 if slot == 1 else 0.35
	spyglass_sprite.modulate.a = 1.0 if slot == 2 else 0.35

func update_ammo(current: int, maximum: int) -> void:
	ammo_label.text = "%d / %d" % [clampi(current, 0, maximum), maximum]
	ammo_label.modulate = Color(1, 0.4, 0.35) if current == 0 else Color.WHITE

func update_health(current: int, maximum: int) -> void:
	var health := clampi(current, 0, mini(maximum, 3))
	if health == _last_health:
		return
	var animations: Array[StringName] = [&"LoseHeart3", &"LoseHeart2", &"LoseHeart1", &"NoAnimation"]
	hearts_anim.play(animations[health])
	# Initial binding and healing show the correct state immediately.
	if _last_health == -1 or health > _last_health:
		hearts_anim.pause()
		hearts_anim.frame = hearts_anim.sprite_frames.get_frame_count(animations[health]) - 1
	_last_health = health
