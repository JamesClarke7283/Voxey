class_name PrimedTnt
extends Node3D

# `mcl_tnt.BOOMTIMER = 4`, and `mcl_explosions.explode(pos, 4, ...)`.
const FUSE := 4.0
const BLAST_RADIUS := 4.0
var game: Node3D
var fuse: float = FUSE
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

# `TNT:on_activate`: the primed block launches up by two nodes with a small random
# horizontal kick (a 0.02-radius circle) and then falls under gravity. Reproduced as
# a one-time velocity on the spawn, so the entity arcs the same way.
func launch(rng: RandomNumberGenerator = null) -> void:
	var source: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	if rng == null: source.randomize()
	var phi: float = source.randf() * TAU
	velocity = Vector3(cos(phi) * 0.02, 2.0, sin(phi) * 0.02)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	fuse -= delta
	instance.material_override = flash_material if int(fuse*8)%2 == 0 else game.node_material
	if fuse <= 0:
		game.explode(position+Vector3.ONE*0.5,BLAST_RADIUS,self)
		queue_free()
		return
	velocity.y = maxf(-20,velocity.y-22*delta)
	var next: Vector3 = position+velocity*delta
	var below := Vector3i(floori(position.x+0.5),floori(next.y-0.001),floori(position.z+0.5))
	if Nodes.solid(game.world.node_at(below)): velocity.y = 0
	else: position = next
