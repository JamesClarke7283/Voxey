class_name PrimedTnt
extends Node3D

var game: Node3D
var fuse: float = 3.0
var velocity := Vector3.ZERO
var instance: MeshInstance3D
var flash_material: StandardMaterial3D

func _ready() -> void:
	instance = MeshInstance3D.new()
	instance.mesh = game.node_mesh(Nodes.TNT)
	instance.material_override = game.node_material
	add_child(instance)
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1,1,1,0.8)
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	game.sound_at("creeper",position+Vector3.ONE*0.5,1.3)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	fuse -= delta
	instance.material_override = flash_material if int(fuse*8)%2 == 0 else game.node_material
	if fuse <= 0:
		game.explode(position+Vector3.ONE*0.5,3.2,self)
		queue_free()
		return
	velocity.y = maxf(-20,velocity.y-22*delta)
	var next: Vector3 = position+velocity*delta
	var below := Vector3i(floori(position.x+0.5),floori(next.y-0.001),floori(position.z+0.5))
	if Nodes.solid(game.world.node_at(below)): velocity.y = 0
	else: position = next
