class_name NetworkAvatar
extends Node3D

var destination := Vector3.ZERO
var target_yaw: float = 0.0
var appearance: Dictionary = {}
var body: Node3D
var initial: bool = true
var motion := NetworkMotion.new()
var shields: Dictionary = {}
var shield_nodes: Dictionary = {}

func set_shields(equipment: Dictionary) -> void:
	if shields == equipment: return
	for hand in ["main","offhand"]:
		var item: Dictionary = equipment.get(hand,{})
		if shields.get(hand,{}) != item:
			if is_instance_valid(shield_nodes.get(hand)): shield_nodes[hand].queue_free()
			shield_nodes.erase(hand)
			if Shields.is_shield(int(item.get("id",0))):
				var model: MeshInstance3D = Shields.model(item); model.scale = Vector3.ONE*0.75
				add_child(model); shield_nodes[hand] = model
		if is_instance_valid(shield_nodes.get(hand)):
			var side: float = 1.0 if hand == "main" else -1.0
			var raised: bool = bool(equipment.get("raised",false))
			shield_nodes[hand].position = Vector3(side*(0.24 if raised else 0.43),1.1 if raised else 0.85,-0.4 if raised else -0.08)
			shield_nodes[hand].rotation = Vector3(0,PI,-side*0.08)
	shields = equipment.duplicate(true)

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
