class_name FallingNode
extends Node3D

# Luanti-style falling node: sand and gravel leave the map as an entity while
# unsupported, then settle back into the first free node above solid ground.
#
# The source carries more than the drop-and-settle part, and Voxey was missing
# all of it (`mcl_falling_nodes/init.lua`):
#
#   * An entity it passes through or lands on **takes damage** scaled by the
#     distance fallen, a helmet reduces it, and a dropped item in range is
#     destroyed (`deal_falling_damage`, :9-57).
#   * A node with `crush_after_fall` — every anvil — **replaces** whatever it
#     lands on instead of dropping as an item (:188).
#   * An anvil also damages **itself** when it falls (`damage_anvil_by_falling`,
#     `mcl_anvils/init.lua`:376-383).
var game: Node3D
var node_id: int = Nodes.SAND
var velocity := Vector3.ZERO
var age: float = 0.0
# The rounded start height, which is what the damage formula measures from.
var start_y: float = 0.0
# The damage bookkeeping: one landing must not hit the same actor twice.
var hit: Array = []

func _ready() -> void:
	start_y = position.y
	var instance := MeshInstance3D.new()
	instance.mesh = game.node_mesh(node_id)
	instance.material_override = game.node_material
	add_child(instance)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	age += delta
	velocity.y = maxf(-20,velocity.y-22*delta)
	var next: Vector3 = position+velocity*delta
	# `damage = (way - 1) * 2`: an actor the node passes through is hurt as it goes,
	# which is what makes a falling anvil lethal from height.
	FallingDamage.land(game,position,node_id,start_y)
	var below := Vector3i(floori(position.x+0.5),floori(next.y-0.001),floori(position.z+0.5))
	if Nodes.solid(game.world.node_at(below)) or next.y < 1 or age > 20:
		land(below+Vector3i.UP)
		queue_free()
		return
	position = next

func land(cell: Vector3i) -> void:
	FallingDamage.land(game,Vector3(cell)+Vector3.ONE*0.5,node_id,start_y)
	var current: int = game.world.node_at(cell)
	if Nodes.solid(current) or not game.world.loaded_at(Vector3(cell)):
		game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,node_id)
		return
	# `crush_after_fall`: an anvil replaces the cell whatever it holds, and damages
	# itself in the process.
	var crushing: bool = FallingDamage.crushes(node_id)
	if current != Nodes.AIR and not Fluids.liquid(current) and not crushing:
		if current == Nodes.TORCH: game.remove_torch(cell)
		game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,Nodes.drop(current))
	if game.world.set_node(cell,node_id):
		game.sound_at("thud",Vector3(cell)+Vector3.ONE*0.5)
		if crushing: FallingDamage.anvil_self_damage(game,cell,node_id,start_y-float(cell.y)+1.0)
	else: game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,node_id)
