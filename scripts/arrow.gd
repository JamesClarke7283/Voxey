class_name Arrow
extends Node3D

var game: Node3D
var velocity := Vector3.ZERO
var life: float = 0.0
var stuck: bool = false
var from_player: bool = false

func _ready() -> void:
	var shaft := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05,0.05,0.55)
	shaft.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("8a6a45")
	shaft.material_override = mat
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.08,0.08,0.12)
	tip.mesh = tip_mesh
	tip.position = Vector3(0,0,-0.3)
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color("c9ccc4")
	tip.material_override = tip_mat
	add_child(tip)
	_orient()

func _orient() -> void:
	if velocity.length() > 0.01: look_at(position+velocity,Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	life += delta
	if life > 8 or (stuck and life > 2.5): queue_free(); return
	if stuck: return
	velocity.y -= 12*delta
	var next: Vector3 = position+velocity*delta
	if game.world.intersects(next,0.03,0.06):
		stuck = true
		life = 1.0
		game.sound_at("thud",position,1.4)
		return
	position = next
	_orient()
	if from_player:
		# Player arrows hit creatures.
		for mob in game.creatures.get_children():
			if position.distance_to(mob.center()) < maxf(0.75,mob.width+0.4):
				mob.hit(6.0,position-velocity)
				queue_free()
				return
	elif position.distance_to(game.player.position+Vector3.UP*0.9) < 0.8:
		game.player.hurt(3,false,position-velocity)
		queue_free()
