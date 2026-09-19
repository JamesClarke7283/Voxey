class_name ThrownItem
extends Node3D

var game: Node3D
var item_id: int = Nodes.EGG
var thrower: Node3D
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
var age: float = 0.0
var impacted: bool = false
var rng := RandomNumberGenerator.new()
var chicks: Array = []

func _ready() -> void:
	rng.randomize()
	var model := MeshInstance3D.new()
	model.mesh = ItemArt.mesh(item_id); model.material_override = ItemArt.material(item_id)
	model.scale = Vector3.ONE*(0.45 if item_id == Nodes.EGG else 0.5)
	add_child(model)

func overlaps(target: Node3D, point: Vector3) -> bool:
	var width: float = target.width if target is Creature else 0.29
	var height: float = target.height if target is Creature else 1.8
	return AABB(target.position-Vector3(width+0.035,0.035,width+0.035),Vector3((width+0.035)*2,height+0.07,(width+0.035)*2)).has_point(point)

func _physics_process(delta: float) -> void:
	if not game.playing() or impacted or delta <= 0: return
	age += delta
	if age > 30: queue_free(); return
	var motion: Vector3 = velocity*delta+acceleration*delta*delta*0.5
	velocity += acceleration*delta
	var steps: int = maxi(1,ceili(motion.length()/0.06))
	var step: Vector3 = motion/steps
	for i in steps:
		var next: Vector3 = position+step
		if not game.world.loaded_at(next): queue_free(); return
		# Sweep the tiny body before creatures so a wall shields entities behind it.
		if game.world.intersects(next-Vector3.UP*0.035,0.035,0.07):
			RedstoneSensors.projectile_hit(game.world,position,step,false)
			impact(null,true); return
		position = next
		for mob in game.creatures.get_children():
			if mob.is_queued_for_deletion() or mob.health <= 0 or mob == thrower and age <= 0.5: continue
			if overlaps(mob,position): impact(mob); return
		if (game.player != thrower or age > 0.5) and overlaps(game.player,position): impact(game.player); return
	rotation.z += delta*5

func impact(target: Node3D = null, block: bool = false) -> void:
	if impacted: return
	impacted = true
	if target != null:
		if target is Creature and is_instance_valid(thrower): Golems.attacked(target,thrower)
		Throwables.strike(target,item_id,velocity)
	elif block and item_id == Nodes.EGG: chicks = Throwables.hatch(game,position,Throwables.hatch_count(rng))
	elif item_id == VillageContent.XP_BOTTLE:
		# `HUD/mcl_experience/bottle.lua`: a broken bottle grants `random(3, 11)`
		# experience. The player path already does this; a thrown one must too.
		game.experience += randi_range(3,11)
		game.puff(position,Color("9ad964"),15)
	game.puff(position,Nodes.color(item_id),20 if item_id == Nodes.SNOWBALL else 12,2)
	game.sound_at("thud",position,1.5 if item_id == Nodes.SNOWBALL else 1.9)
	queue_free()
