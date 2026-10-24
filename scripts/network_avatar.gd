class_name NetworkAvatar
extends Node3D

var destination := Vector3.ZERO
var target_yaw: float = 0.0
var appearance: Dictionary = {}
var body: Node3D
var initial: bool = true
var motion := NetworkMotion.new()

func set_appearance(value: Dictionary) -> void:
	var clean: Dictionary = CharacterSkin.clean(value)
	if clean == appearance: return
	appearance = clean
	if is_instance_valid(body): body.queue_free()
	body = CharacterSkin.model(clean)
	add_child(body)

func move_to(at: Vector3, yaw: float) -> void:
	destination = at; target_yaw = yaw
	motion.update(at,yaw)
	position = motion.current; rotation.y = motion.current_yaw; initial = false

func _process(dt: float) -> void:
	motion.advance(dt)
	position = motion.current
	rotation.y = motion.current_yaw
