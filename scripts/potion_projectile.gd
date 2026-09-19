class_name PotionProjectile
extends Node3D

var game: Node3D
var item_id: int = 0
var velocity := Vector3.ZERO
var age: float = 0.0
var cloud: bool = false
var radius: float = 3.0
var affected: Dictionary = {}

func _ready() -> void:
	var mesh := MeshInstance3D.new(); mesh.mesh = ItemArt.mesh(item_id); mesh.material_override = ItemArt.material(item_id); mesh.scale = Vector3.ONE*0.35; add_child(mesh)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	age += delta
	if cloud:
		radius -= delta*0.05
		if age >= 30 or radius <= 0.1: queue_free(); return
		if fmod(age,0.15) < delta: game.puff(position+Vector3(randf_range(-radius,radius),0.3,randf_range(-radius,radius)),Nodes.color(item_id),2,0.3)
		if age < 0.5: return
		if PotionCatalog.ITEMS[item_id].get("potion","") == "water": Campfires.water_splash(game.world,position,radius)
		for target in game.creatures.get_children()+[game.player]:
			if target.is_queued_for_deletion(): continue
			if target.position.distance_to(position) <= radius and absf(target.position.y-position.y) < 1.5 and age >= float(affected.get(target.get_instance_id(),0)):
				PotionEffects.apply_item(target,item_id); affected[target.get_instance_id()] = age+5; radius -= 0.5
		return
	if age > 15: queue_free(); return
	velocity.y -= delta*12
	var motion: Vector3 = velocity*delta
	var steps: int = maxi(1,ceili(motion.length()/0.08))
	for i in steps:
		var next: Vector3 = position+motion/steps
		if game.world.intersects(next,0.06,0.12):
			RedstoneSensors.projectile_hit(game.world,position,motion,false)
			impact(); return
		position = next
		for mob in game.creatures.get_children():
			if not mob.is_queued_for_deletion() and position.distance_to(mob.center()) < mob.width+0.2: impact(mob); return
	rotate_z(delta*4)

func impact(direct: Node3D = null) -> void:
	if PotionCatalog.ITEMS[item_id].get("potion","") == "water": Campfires.water_splash(game.world,position)
	game.puff(position,Nodes.color(item_id),22,2)
	game.sound_at("glass",position)
	if PotionCatalog.ITEMS[item_id].form == "lingering":
		cloud = true; age = 0
		for child in get_children(): child.queue_free()
		return
	for target in game.creatures.get_children()+[game.player]:
		if target.is_queued_for_deletion(): continue
		var distance: float = target.position.distance_to(position)
		if distance < 4 or target == direct: PotionEffects.apply_item(target,item_id,1.0 if target == direct else maxf(0,1.0-distance/4.0))
	queue_free()
