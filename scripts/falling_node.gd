class_name FallingNode
extends Node3D

# Luanti-style falling node: sand and gravel leave the map as an entity while
# unsupported, then settle back into the first free node above solid ground.
var game: Node3D
var node_id: int = Nodes.SAND
var velocity := Vector3.ZERO
var age: float = 0.0

func _ready() -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = game.node_mesh(node_id)
	instance.material_override = game.node_material
	add_child(instance)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	age += delta
	velocity.y = maxf(-20,velocity.y-22*delta)
	var next: Vector3 = position+velocity*delta
	var below := Vector3i(floori(position.x+0.5),floori(next.y-0.001),floori(position.z+0.5))
	if Nodes.solid(game.world.node_at(below)) or next.y < 1 or age > 20:
		land(below+Vector3i.UP)
		queue_free()
		return
	position = next

func land(cell: Vector3i) -> void:
	var current: int = game.world.node_at(cell)
	if Nodes.solid(current) or not game.world.loaded_at(Vector3(cell)):
		game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,node_id)
		return
	if current != Nodes.AIR and current != Nodes.WATER:
		if current == Nodes.TORCH: game.remove_torch(cell)
		game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,Nodes.drop(current))
	if game.world.set_node(cell,node_id): game.sound_at("thud",Vector3(cell)+Vector3.ONE*0.5)
	else: game.spawn_drop(Vector3(cell)+Vector3.ONE*0.5,node_id)
