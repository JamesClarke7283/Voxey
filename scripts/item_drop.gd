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
# As with mobs, bunched engine ticks after a slow frame merge into one step per
# rendered frame (at most 1/30 s apart); at 60 FPS every tick steps.
var step_frame: int = -1
var step_delta: float = 0.0

func _ready() -> void:
	velocity = Vector3(randf_range(-1.2,1.2),2.8,randf_range(-1.2,1.2))
	mesh_instance = MeshInstance3D.new()
	if Nodes.placeable(item_id):
		# Dropped nodes are miniature copies of the real node, atlas textures included.
		mesh_instance.mesh = game.node_mesh(item_id)
		mesh_instance.material_override = game.world.water_material if item_id in [Amethyst.TINTED_GLASS,Beehives.HONEY_BLOCK] else game.node_material
		mesh_instance.scale = Vector3.ONE*0.25
		mesh_instance.position = Vector3(-0.125,0,-0.125)
	else:
		mesh_instance.mesh = ItemArt.mesh(item_id)
		mesh_instance.material_override = ItemArt.material(item_id)
		mesh_instance.scale = Vector3.ONE*0.36
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	if Engine.is_in_physics_frame():
		step_delta += delta
		if Engine.get_process_frames() == step_frame and step_delta < 1.0/30.0: return
		step_frame = Engine.get_process_frames()
		delta = step_delta
		step_delta = 0.0
	age += delta
	pickup_delay = maxf(0,pickup_delay-delta)
	if age >= (600.0 if item_id == Nodes.ARROW_ITEM else 300.0): queue_free(); return
	if age > 2 and (Fluids.contains(game.world,position,Nodes.LAVA) or Fire.is_fire(game.world.node_at(Vector3i(position.floor())))) and not VillageContent.DATA.get(item_id,{}).get("fire_immune",false):
		queue_free(); return
	# `mcl_item_entity`: a cactus in the item's cell destroys it, a resting item
	# merges with an identical neighbour within 0.8, liquid floats or carries it,
	# and a solid cell ejects it. `step` queues the item for deletion on a cactus.
	if ItemPhysics.step(self,delta): return
	rotation.y += delta
	mesh_instance.position.y = sin(age*3)*0.04
	var destination: Vector3 = game.player.position+Vector3.UP*0.8
	var distance: float = position.distance_to(destination)
	# The magnet runs when the item fits either hand: the source's pickup fills the
	# offhand first, so a full backpack must not block a pickup that the offhand
	# can take — which is `core.item_pickup`'s whole point.
	var room: int = game.inventory.capacity(item_id,wear,data)+ItemPhysics.offhand_room(game,self)
	if age > 0.6 and pickup_delay <= 0 and distance < 2.4 and room >= amount:
		position = position.move_toward(destination,delta*8)
		if distance < 0.65:
			# Source `core.item_pickup`: the **offhand** is filled first, and only
			# the remainder goes to the main inventory. That is why a torch picked
			# up while a shield is held lands in the second hand.
			var remaining: int = ItemPhysics.fill_offhand(game,self)
			if remaining > 0: remaining = game.inventory.add_item(item_id,remaining,wear,data)
			if remaining < amount: game.sound("pickup"); game.progress("gather")
			amount = remaining
			if amount == 0: queue_free()
		return
	# The source merges only a resting item, so the scan runs when the item is on a
	# floor rather than mid-flight, and a merge consumes the rest of this step. An
	# item floating on water is equally at rest and never merges while carried by a
	# flow, which is `apply_physics`'s `is_floating` branch.
	var floating: bool = ItemPhysics.floats(game.world,position,velocity)
	if floating or grounded_on_floor():
		if ItemPhysics.try_merge(self): return
	if floating: return
	if not Fluids.water(game.world.node_at(Vector3i(position.floor()))):
		velocity.y = maxf(-15,velocity.y-delta*15)
	var steps: int = maxi(1,ceili(velocity.length()*delta/0.1))
	for step in steps:
		var next: Vector3 = position+velocity*delta/steps
		if not game.world.intersects(next,0.1,0.2): position = next
		else: velocity = Vector3.ZERO; break

# The source's `is_on_floor`: a walkable, non-slippery node directly below with no
# vertical velocity. A merged stack is moved off the floor, so this only gates the
# scan rather than preventing it.
func grounded_on_floor() -> bool:
	if absf(velocity.y) > 0.001: return false
	var below := Vector3i((position-Vector3.UP*0.5).floor())
	return Nodes.solid(game.world.node_at(below))
