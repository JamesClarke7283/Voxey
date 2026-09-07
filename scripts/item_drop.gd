class_name ItemDrop
extends Node3D

var game: Node3D
var item_id: int
var amount: int = 1
var wear: int = 0
var data: Dictionary = {}
var age: float = 0.0
var pickup_delay: float = 0.0
var velocity := Vector3.ZERO
var mesh_instance: MeshInstance3D

func _ready() -> void:
	velocity = Vector3(randf_range(-1.2,1.2),2.8,randf_range(-1.2,1.2))
	mesh_instance = MeshInstance3D.new()
	if Nodes.placeable(item_id):
		# Dropped nodes are miniature copies of the real node, atlas textures included.
		mesh_instance.mesh = game.node_mesh(item_id)
		mesh_instance.material_override = game.node_material
		mesh_instance.scale = Vector3.ONE*0.25
		mesh_instance.position = Vector3(-0.125,0,-0.125)
	else:
		mesh_instance.mesh = ItemArt.mesh(item_id)
		mesh_instance.material_override = ItemArt.material(item_id)
		mesh_instance.scale = Vector3.ONE*0.36
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	age += delta
	pickup_delay = maxf(0,pickup_delay-delta)
	if age >= (600.0 if item_id == Nodes.ARROW_ITEM else 300.0): queue_free(); return
	if age > 2 and (Fluids.contains(game.world,position,Nodes.LAVA) or Fire.is_fire(game.world.node_at(Vector3i(position.floor())))) and not VillageContent.DATA.get(item_id,{}).get("fire_immune",false):
		queue_free(); return
	rotation.y += delta
	mesh_instance.position.y = sin(age*3)*0.04
	var destination: Vector3 = game.player.position+Vector3.UP*0.8
	var distance: float = position.distance_to(destination)
	if age > 0.6 and pickup_delay <= 0 and distance < 2.4 and game.inventory.capacity(item_id,wear,data) >= amount:
		position = position.move_toward(destination,delta*8)
		if distance < 0.65:
			var remaining: int = game.inventory.add_item(item_id,amount,wear,data)
			if remaining < amount: game.sound("pickup"); game.progress("gather")
			amount = remaining
			if amount == 0: queue_free()
	else:
		velocity.y = maxf(-15,velocity.y-delta*15)
		var steps: int = maxi(1,ceili(velocity.length()*delta/0.1))
		for step in steps:
			var next: Vector3 = position+velocity*delta/steps
			if not game.world.intersects(next,0.1,0.2): position = next
			else: velocity = Vector3.ZERO; break
