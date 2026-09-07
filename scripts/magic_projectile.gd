class_name MagicProjectile
extends Node3D

var game: Node3D
var kind: String = "pearl"
var velocity := Vector3.ZERO
var target := Vector3.ZERO
var from_player: bool = false
var source: Node
var life: float = 0.0
var impacted: bool = false

func _ready() -> void:
	var color: Color = Color("4bbda8") if kind == "pearl" else (Color("9ddb69") if kind == "eye" else (Color("c276e5") if kind == "breath" else Color("ffb447")))
	var size: float = 0.23 if kind in ["pearl","eye"] else (0.55 if kind == "ghast" else 0.3)
	var core := RedstoneArt.box(self,Vector3.ZERO,Vector3.ONE*size,color,1.4)
	core.rotation = Vector3(0.5,0.5,0.3)
	if kind == "eye": RedstoneArt.box(self,Vector3(0,0,-0.13),Vector3(0.065,0.13,0.02),Color("153f37"))

func deflect(direction: Vector3) -> void:
	if kind != "ghast": return
	velocity = direction.normalized()*22
	from_player = true
	source = game.player
	game.sound_at("arrow",position)

func _physics_process(delta: float) -> void:
	if not game.playing() or impacted: return
	life += delta
	if life > 20: queue_free(); return
	if kind == "eye":
		position = position.move_toward(target,delta*9)
		rotation.y += delta*2
		if fmod(life,0.12) < delta: game.puff(position,Color("a890d7"),1,0.3)
		if life > 2.5:
			if from_player: game.spawn_drop(position,Nodes.ENDER_EYE).pickup_delay = 0.5
			queue_free()
		return
	if kind == "shulker":
		var desired: Vector3 = (game.player.position+Vector3.UP-position).normalized()*6
		velocity = velocity.move_toward(desired,delta*8)
	if kind == "pearl": velocity.y -= 16*delta
	var motion: Vector3 = velocity*delta
	var steps: int = maxi(1,ceili(motion.length()/0.08))
	for i in steps:
		var next: Vector3 = position+motion/steps
		if not game.world.loaded_at(next): return # Pause at streaming boundaries.
		if kind == "pearl" and game.world.node_at(Vector3i(next.floor())) == Nodes.END_GATEWAY:
			game.adventure.enter_gateway(); queue_free(); return
		if game.world.intersects(next,0.06,0.12) or game.world.node_at(Vector3i(next.floor())) in [Nodes.WATER,Nodes.LAVA]:
			impact(next)
			return
		position = next
		if kind == "pearl": continue
		if from_player:
			for mob in game.creatures.get_children():
				if mob.is_queued_for_deletion(): continue
				if position.distance_to(mob.center()) < maxf(0.6,mob.width+0.2):
					mob.hit(20 if kind == "ghast" else 6,position-velocity)
					impact(position); return
		elif position.distance_to(game.player.position+Vector3.UP*0.9) < 0.7:
			if kind == "shulker": game.player.levitation = 8
			game.player.hurt(6 if kind == "ghast" else 4,false,position-velocity)
			impact(position); return
	if fmod(life,0.12) < delta: game.puff(position,Color("aa72d2") if kind in ["breath","pearl"] else Color("f6aa42"),1,0.3)

func impact(at: Vector3) -> void:
	if impacted: return
	impacted = true
	if kind == "pearl":
		var destination: Vector3 = safe_destination(at)
		if not is_inf(destination.x):
			game.puff(game.player.position+Vector3.UP,Color("a875d8"),16)
			game.teleport(destination)
			game.player.hurt(5,true)
			game.puff(destination+Vector3.UP,Color("a875d8"),16)
		else: game.toast("The pearl found no safe landing space.")
	elif kind == "ghast": game.explode(at,1.8,source if is_instance_valid(source) else null)
	elif kind == "breath": game.adventure.add_breath(at)
	else: game.puff(at,Color("f6b84b"),10)
	queue_free()

func safe_destination(at: Vector3) -> Vector3:
	var closest := Vector3.INF
	var best: float = INF
	var origin := Vector3i(at.floor())
	for dy in range(-2,4):
		for dx in range(-2,3):
			for dz in range(-2,3):
				var cell := origin+Vector3i(dx,dy,dz)
				var q := Vector3(cell)+Vector3(0.5,0.01,0.5)
				if not game.world.loaded_at(q) or game.world.intersects(q): continue
				if game.world.node_at(cell) in [Nodes.WATER,Nodes.LAVA]: continue
				if not Nodes.solid(game.world.node_at(cell+Vector3i.DOWN)): continue
				var d: float = q.distance_squared_to(at)
				if d < best: best = d; closest = q
	return closest
