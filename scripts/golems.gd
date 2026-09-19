class_name Golems
extends RefCounted

# Pattern order, literal-air requirements and creator semantics follow the
# installed mobs_mc summoners. Voxey positions are lower voxel corners.
const SNOW_DIRECTIONS = [Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]

static func iron_patterns() -> Array:
	var patterns: Array = []
	for arm in [Vector3i.RIGHT,Vector3i.BACK]:
		for stem in [Vector3i.DOWN,Vector3i.UP]:
			patterns.append({"blocks":[stem-arm,stem+arm,stem,stem*2],"air":[-arm,arm,stem*2-arm,stem*2+arm],"feet":Vector3i.ZERO if stem == Vector3i.UP else stem*2})
	for stem in [Vector3i.FORWARD,Vector3i.BACK,Vector3i.LEFT,Vector3i.RIGHT]:
		var arm: Vector3i = Vector3i.RIGHT if stem.z != 0 else Vector3i.BACK
		patterns.append({"blocks":[stem-arm,stem,stem+arm,stem*2],"air":[-arm,arm,stem*2-arm,stem*2+arm],"feet":stem*2})
	return patterns

static func head(id: int) -> bool:
	return FruitCrops.is_pumpkin_head(id) and id != Nodes.PUMPKIN

static func construction(world: VoxelWorld, p: Vector3i) -> Dictionary:
	if not head(world.node_at(p)) or not world.loaded_at(Vector3(p)): return {}
	for pattern in iron_patterns():
		var cells: Array = [p]; var valid: bool = true
		for offset in pattern.blocks:
			var at: Vector3i = p+offset
			if not world.loaded_at(Vector3(at)) or world.node_at(at) != Nodes.IRON_BLOCK: valid = false; break
			cells.append(at)
		if not valid: continue
		for offset in pattern.air:
			var at: Vector3i = p+offset
			if not world.loaded_at(Vector3(at)) or world.node_at(at) != Nodes.AIR: valid = false; break
		if valid: return {"kind":"iron_golem","cells":cells,"position":Vector3(p+pattern.feet)+Vector3(0.5,0,0.5)}
	for d in SNOW_DIRECTIONS:
		if not world.loaded_at(Vector3(p+d)) or not world.loaded_at(Vector3(p+d*2)): continue
		if world.node_at(p+d) == Nodes.SNOW_BLOCK and world.node_at(p+d*2) == Nodes.SNOW_BLOCK:
			var feet: Vector3i = p if d == Vector3i.UP else p+d*2
			return {"kind":"snow_golem","cells":[p,p+d,p+d*2],"position":Vector3(feet)+Vector3(0.5,0,0.5)}
	return {}

static func body_clear(world: VoxelWorld, pos: Vector3, width: float, height: float, removed: Array) -> bool:
	var body := AABB(pos-Vector3(width,0,width),Vector3(width*2,height,width*2))
	var lo := Vector3i(body.position.floor()); var hi := Vector3i((body.end-Vector3.ONE*0.0001).floor())
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for z in range(lo.z,hi.z+1):
				var p := Vector3i(x,y,z)
				if not world.loaded_at(Vector3(p)): return false
				if p in removed: continue
				for box in world.collision_boxes(p):
					if body.intersects(AABB(Vector3(p)+box.position,box.size)): return false
	return true

static func placed(game: Node3D, p: Vector3i, creator: String = "") -> Creature:
	var plan: Dictionary = construction(game.world,p)
	if plan.is_empty(): return null
	var info: Dictionary = Creature.KINDS[plan.kind]
	if not body_clear(game.world,plan.position,info.width,info.height,plan.cells): return null
	# Spawn first: if allocation fails the player's complete structure survives.
	var mob: Creature = spawn(game,plan.kind,plan.position,creator)
	if mob == null: return null
	for at in plan.cells: game.world.set_node(at,Nodes.AIR)
	game.puff(mob.center(),Color("e1e4dd"),35,1.4)
	return mob

static func state(game: Node3D) -> Dictionary:
	if not game.world.adventure_state.has("golems"):
		game.world.adventure_state.golems = {"next":0,"snow":{}}
	return game.world.adventure_state.golems

static func spawn(game: Node3D, kind: String, p: Vector3, creator: String = "") -> Creature:
	if kind == "iron_golem":
		var mob := VillageMob.new(); mob.game = game; mob.kind = kind; mob.position = p
		game.creatures.add_child(mob); game.villages.manual(mob)
		var person: Dictionary = game.villages.record(mob.person_key)
		person.creator = creator; mob.creator = creator; mob.store_record()
		return mob
	if kind != "snow_golem": return null
	var data: Dictionary = state(game); data.next = int(data.next)+1
	var key: String = "snow:%d"%int(data.next)
	var mob := SnowGolem.new(); mob.game = game; mob.kind = kind; mob.position = p; mob.golem_key = key; mob.creator = creator
	game.creatures.add_child(mob); mob.store_record()
	return mob

static func resolve(game: Node3D, key: String) -> SnowGolem:
	if key.is_empty(): return null
	for mob in game.creatures.get_children():
		if mob is SnowGolem and not mob.is_queued_for_deletion() and mob.golem_key == key: return mob
	var record: Dictionary = state(game).snow.get(key,{})
	if record.is_empty() or float(record.get("health",0)) <= 0: return null
	var mob := SnowGolem.new(); mob.game = game; mob.kind = "snow_golem"; mob.golem_key = key; mob.position = VillageLife.vec(record.position)
	game.creatures.add_child(mob); mob.bind(record)
	return mob

static func snapshot(game: Node3D) -> void:
	for mob in game.creatures.get_children():
		if mob is SnowGolem and not mob.is_queued_for_deletion(): mob.store_record()

static func restore(game: Node3D) -> void:
	update(game,1.0)

static func update(game: Node3D, delta: float) -> void:
	var clock: float = float(game.world.get_meta("golem_clock",0.0))-delta
	game.world.set_meta("golem_clock",clock if clock > 0 else 0.5)
	if clock > 0: return
	var live: Dictionary = {}
	for mob in game.creatures.get_children():
		if not mob is SnowGolem or mob.is_queued_for_deletion(): continue
		mob.store_record(); live[mob.golem_key] = mob
		if not game.world.loaded_at(mob.position) or mob.position.distance_to(game.player.position) > 95:
			if Boats.is_passenger(mob): continue
			game.leads.hibernate(mob); mob.queue_free()
	for key in state(game).snow:
		if live.has(key): continue
		var record: Dictionary = state(game).snow[key]
		if float(record.get("health",0)) <= 0 or not record.get("position") is Array or record.position.size() != 3: continue
		var p: Vector3 = VillageLife.vec(record.position)
		if not game.world.loaded_at(p) or p.distance_to(game.player.position) >= 70: continue
		var mob := SnowGolem.new(); mob.game = game; mob.kind = "snow_golem"; mob.golem_key = str(key); mob.position = p
		game.creatures.add_child(mob); mob.bind(record)

static func use(game: Node3D, mob: Creature) -> bool:
	if mob == null or mob.health <= 0 or mob.is_queued_for_deletion(): return false
	var held: Dictionary = game.inventory.held()
	if mob.kind == "iron_golem" and held.id == Nodes.IRON:
		if mob.health >= 100: return true
		mob.health = minf(100,mob.health+25)
		if game.gamemode != "creative": game.inventory.consume_selected()
		if mob is VillageMob: mob.store_record(); mob.cracks()
		game.puff(mob.center(),Color("7cbd72"),10); game.sound("equip")
		return true
	if mob is SnowGolem and held.id == Nodes.SHEARS:
		if mob.shear() and game.gamemode != "creative": game.inventory.damage_tool()
		return true
	return false

static func dispense(circuit: RedstoneCircuit, _p: Vector3i, target: Vector3i, d: Vector3i, slot: Dictionary) -> bool:
	var game: Node3D = circuit.world.get_parent()
	if slot.id == Nodes.SHEARS:
		for mob in game.creatures.get_children():
			if mob is SnowGolem and not mob.is_queued_for_deletion() and mob.position.distance_to(Vector3(target)+Vector3.ONE*0.5) <= 1.0 and mob.shear(false):
				slot.wear += 1
				if slot.wear >= Nodes.durability(slot.id): slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
				return true
	if FruitCrops.is_pumpkin_head(slot.id) and FruitCrops.canonical(slot.id) == FruitCrops.CARVED:
		var previous: int = circuit.world.node_at(target)
		if previous == Nodes.AIR or Nodes.plant(previous) or Fire.is_fire(previous):
			var facing: int = [Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT].find(d)
			circuit.world.set_node(target,FruitCrops.head_id(false,maxi(0,facing))); RedstoneCircuit.consume_one(slot)
		return true
	return false

static func attacked(mob: Creature, attacker: Node3D) -> void:
	if mob is VillageMob and mob.kind == "iron_golem" and is_instance_valid(attacker) and attacker != mob:
		mob.retaliate(attacker)

static func visible(game: Node3D, from: Vector3, to: Vector3) -> bool:
	var direction: Vector3 = to-from
	if direction.length() < 0.01: return true
	var hit: Dictionary = game.world.raycast(from,direction.normalized(),direction.length())
	return hit.is_empty() or float(hit.distance) >= direction.length()-0.2

static func hot(game: Node3D, p: Vector3) -> bool:
	# Voxey's reduced biome map has one hot Overworld biome. Source temperature
	# values are 2.0 for desert and Nether, <=1.0 for represented temperate biomes.
	return game.dimension == "nether" or game.world.generator.biome(floori(p.x),floori(p.z)) == "Sunwash desert"

static func wet(game: Node3D, p: Vector3) -> bool:
	if Fluids.water(game.world.node_at(Vector3i(p.floor()))): return true
	if game.dimension != "overworld" or game.survival.weather() == "clear": return false
	var biome: String = game.world.generator.biome(floori(p.x),floori(p.z))
	if biome in ["Sunwash desert","Frostpine highlands"]: return false
	return game.world.open_sky(Vector3i((p+Vector3.UP*1.7).floor()))
