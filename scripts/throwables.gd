class_name Throwables
extends RefCounted

# mcl_throwing uses 22 nodes/s, horizontal acceleration -3 * look direction,
# and movement_gravity (10.4 in the installed Mineclonia minetest.conf).
const SPEED = 22.0
const GRAVITY = 10.4
const DRAG = 3.0

static func supports(id: int) -> bool: return id in [Nodes.EGG,Nodes.SNOWBALL]

static func launch(game: Node3D, id: int, origin: Vector3, direction: Vector3, thrower: Node3D = null) -> ThrownItem:
	if not supports(id) or direction.length_squared() < 0.000001: return null
	var shot := ThrownItem.new()
	var aim: Vector3 = direction.normalized()
	shot.game = game; shot.item_id = id; shot.position = origin; shot.thrower = thrower
	shot.velocity = aim*SPEED
	shot.acceleration = Vector3(-aim.x*DRAG,-GRAVITY,-aim.z*DRAG)
	game.entities.add_child(shot)
	game.sound_at("arrow",origin,1.4)
	return shot

static func use(game: Node3D) -> bool:
	var held: Dictionary = game.inventory.held()
	if not supports(held.id) or held.count <= 0: return false
	var shot: ThrownItem = launch(game,held.id,game.player.position+Vector3.UP*1.5,-game.player.camera.global_basis.z,game.player)
	if shot == null: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.player.swing = 1
	return true

static func hatch_result(first: int, bonus: int) -> int:
	if first != 1: return 0
	return 4 if bonus == 1 else 1

static func hatch_count(rng: RandomNumberGenerator) -> int:
	var first: int = rng.randi_range(1,8)
	return hatch_result(first,rng.randi_range(1,32)) if first == 1 else 0

static func chick_position(game: Node3D, preferred: Vector3) -> Vector3:
	# Source spawn_child calls prevent_phasing. Use the actual baby collision
	# dimensions to keep wall/ceiling impacts from embedding newly hatched chicks.
	for y in [0.0,-0.35,0.35,0.7,-0.7]:
		for offset in [Vector3.ZERO,Vector3(0.2,0,0),Vector3(-0.2,0,0),Vector3(0,0,0.2),Vector3(0,0,-0.2),Vector3(0.4,0,0),Vector3(-0.4,0,0),Vector3(0,0,0.4),Vector3(0,0,-0.4)]:
			var candidate: Vector3 = preferred+offset+Vector3.UP*y
			if game.world.loaded_at(candidate) and not game.world.intersects(candidate,Creature.KINDS.chicken.width*0.5,Creature.KINDS.chicken.height*0.5): return candidate
	return Vector3.INF

static func hatch(game: Node3D, at: Vector3, count: int) -> Array:
	var chicks: Array = []
	var offsets: Array = [Vector3.ZERO,Vector3(0.7,0,0),Vector3(-0.7,0,-0.7),Vector3(-0.7,0,0.7)]
	for i in mini(count,4):
		var location: Vector3 = chick_position(game,at+offsets[i])
		if is_inf(location.x): location = chick_position(game,at)
		if is_inf(location.x): continue
		var chick: Creature = game.spawn_creature("chicken",location)
		if chick == null: continue
		chick.growth_remaining = Farming.GROW_TIME
		Farming.resize(chick); Farming.remember(chick)
		game.puff(chick.center(),Color("eee2c5"),8,0.8)
		chicks.append(chick)
	return chicks

static func strike(target: Node3D, id: int, direction: Vector3) -> void:
	var away: Vector3 = (direction*Vector3(1,0,1)).normalized()
	var previous: Vector3 = target.velocity
	if target is Creature:
		if id == Nodes.SNOWBALL and target.kind == "blaze": target.hit(3,target.position-away)
		else:
			# A zero-damage punch still provokes/flees and knocks back in source;
			# avoid health-damage visuals and potion damage callbacks for this case.
			target.provoked = true
			if not target.hostile: target.scared = 5
		if target.kind == "iron_golem": return # Source full knockback resistance.
		# Source full-punch factor: (1.4 - 1.0) * 1.5 * 0.5 = 0.3.
		var horizontal: Vector3 = (previous*Vector3(1,0,1)*0.5+away*6.0)*0.546
		target.knock = horizontal
		if target.grounded: target.velocity.y = minf(8,previous.y*0.5+3)
	elif target is VoxeyPlayer:
		target.velocity.x = (target.velocity.x*0.5+away.x*6.0)*0.546
		target.velocity.z = (target.velocity.z*0.5+away.z*6.0)*0.546
		if target.grounded: target.velocity.y = minf(8,target.velocity.y*0.5+3)
