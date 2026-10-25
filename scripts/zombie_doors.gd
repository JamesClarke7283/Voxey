class_name ZombieDoors
extends RefCounted
const BREAK_TIME = 12.0

static func moving_away(pos: Vector3, door: Vector3, velocity: Vector3) -> bool:
	var direction: Vector3 = (door-pos)*Vector3(1,0,1)
	if direction.length() < 0.05: return false
	# The reference passes 100 radians to cos, despite its constant's name.
	return velocity.length() > 1 and direction.normalized().dot(velocity.normalized()) < -cos(100.0)

static func valid(pos: Vector3, door: Vector3, velocity: Vector3, closed: bool) -> bool:
	return Vector2(pos.x-door.x,pos.z-door.z).length() < 1.25 and absf(pos.y-(door.y-0.5)) < 1.5 and closed and not moving_away(pos,door,velocity)

static func initial() -> Dictionary: return {"time":0.0,"stage":0,"punch":0.0}

static func tick(state: Dictionary, delta: float, protected: bool, roll: int = 20) -> Dictionary:
	state.time += delta
	if state.time >= BREAK_TIME and not protected: return {"break":true,"sound":false}
	var progress: int = floori(state.time/BREAK_TIME*10)
	var sound: bool = progress != int(state.stage); state.stage = progress
	if roll == 1 and state.punch <= 0: state.punch = 0.45
	return {"break":false,"sound":sound}

static func breaking(mob: Creature) -> bool: return not mob.zombie_door.is_empty()

static func find(mob: Creature) -> Vector3i:
	if mob.direction.length() < 0.1: return Vector3i.MAX
	var hit: Dictionary = mob.game.world.raycast(mob.position+Vector3.UP*minf(0.5,mob.height*0.5),mob.direction.normalized(),mob.width+0.85)
	if hit.is_empty(): return Vector3i.MAX
	var pos: Vector3i = hit.pos; var id: int = mob.game.world.node_at(pos)
	if Doors.legacy(id): Doors.migrate_at(mob.game.world,pos); id = mob.game.world.node_at(pos)
	if not Doors.wooden(id) or Doors.opened(id): return Vector3i.MAX
	return pos+Vector3i.DOWN if Doors.upper(id) else pos

static func step(mob: Creature, delta: float, pursuing: bool) -> void:
	if not ZombieTraits.handles(mob.kind): return
	if mob.zombie_door.is_empty():
		if not mob.zombie_traits.get("break_doors",false) or mob.game.difficulty != 2 or MobJockeys.vehicle(mob) != null: return
		var found: Vector3i = find(mob)
		if found == Vector3i.MAX: return
		mob.zombie_door = initial(); mob.zombie_door.pos = found
	var state: Dictionary = mob.zombie_door
	state.punch = maxf(0,float(state.punch)-delta)
	var pos: Vector3i = state.pos; var id: int = mob.game.world.node_at(pos)
	if not valid(mob.position,Vector3(pos)+Vector3.ONE*0.5,mob.velocity,Doors.wooden(id) and not Doors.opened(id)):
		mob.zombie_door = {}; return
	if not pursuing: mob.direction = ((Vector3(pos)+Vector3.ONE*0.5-mob.position)*Vector3(1,0,1)).normalized()
	var result: Dictionary = tick(state,delta,false,ZombieTraits.rng_for(mob.game.world).integer(1,20))
	if result["break"]:
		Doors.break_node(mob.game,pos,id,0,true,false); mob.zombie_door = {}
	elif result.sound:
		mob.game.sound_at("break",Vector3(pos)+Vector3.ONE*0.5,0.6)
		mob.game.puff(Vector3(pos)+Vector3.ONE*0.5,Nodes.color(id),4,0.25)

static func pose(mob: Creature) -> void:
	if breaking(mob) and float(mob.zombie_door.punch) > 0 and not mob.arms.is_empty():
		mob.arms[0].rotation.x = 1.35+0.7*sin((0.45-float(mob.zombie_door.punch))/0.45*PI)
