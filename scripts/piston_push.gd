class_name PistonPush
extends RefCounted

# Mineclonia mods/ITEMS/REDSTONE/mcl_pistons/api.lua: breadth-first adhesive
# frontier, at most twelve moved nodes; destroyed nodes do not consume capacity.
const LIMIT = 12
const SIDES = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]

static func torch(id: int) -> bool:
	return Torches.is_torch(id) or id in [Nodes.SOUL_TORCH,Nodes.REDSTONE_TORCH]

static func diggable(id: int) -> bool:
	return CropFarming.is_crop(id) or torch(id) or id == VillageContent.ITEM_FRAME or RedstoneInputs.is_device(id) or SnowCover.is_snow(id) or Doors.is_door(id) or FoodFeatures.is_cake(id) or Amethyst.is_crystal(id) or id == Amethyst.BUDDING or id in [Nodes.PUMPKIN,Nodes.MELON] or FruitCrops.is_pumpkin_head(id)

static func unsticky(id: int) -> bool:
	if CropFarming.is_crop(id): return CropFarming.unsticky(id)
	return diggable(id)

static func replaceable(id: int) -> bool:
	return id == Nodes.AIR or Fluids.liquid(id) or Fire.is_fire(id)

static func plan(circuit: RedstoneCircuit, start: Vector3i, movement: Vector3i, base: Vector3i) -> Dictionary:
	var world: VoxelWorld = circuit.world
	var frontiers: Array = [start]; var seen: Dictionary = {start:true}
	var nodes: Array = []; var digs: Array = []; var cursor: int = 0
	while cursor < frontiers.size():
		var p: Vector3i = frontiers[cursor]; cursor += 1
		if p == base or not circuit.movable(p): return {}
		var id: int = world.node_at(p)
		if diggable(id): digs.append({"from":p,"to":p+movement,"id":id}); continue
		if replaceable(id): continue
		nodes.append({"from":p,"to":p+movement,"id":id})
		if nodes.size() > LIMIT: return {}
		var connected: Array = []
		if Beehives.sticky(id):
			for side in SIDES:
				var at: Vector3i = p+side; var neighbor: int = world.node_at(at)
				# A blocked forward node fails the whole push below. An immovable
				# side attachment is ignored, exactly as in the source frontier.
				if at != base and circuit.movable(at) and not unsticky(neighbor) and Beehives.sticks(id,neighbor): connected.append(at)
		connected.append(p+movement)
		for at in connected:
			if seen.has(at): continue
			seen[at] = true; frontiers.append(at)
	return {"nodes":nodes,"dig":digs}

static func defer_support(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.circuits.moving: return false
	var pending: Dictionary = world.get_meta("piston_support",{})
	pending[p] = true; world.set_meta("piston_support",pending)
	return true

static func finish(circuit: RedstoneCircuit) -> void:
	var world: VoxelWorld = circuit.world
	circuit.moving = false
	Signs.finish_piston(world)
	Farmland.finish_piston(world)
	Amethyst.finish_piston(world)
	var pending: Dictionary = world.get_meta("piston_support",{})
	if world.has_meta("piston_support"): world.remove_meta("piston_support")
	for p in pending:
		SnowCover.changed(world,p); FoodFeatures.changed(world,p)
		Torches.support_changed(world,p); circuit.support_changed(p)
		CropFarming.refresh(world,p); CropFarming.refresh(world,p+Vector3i.UP)
		FruitCrops.refresh(world,p); FruitCrops.refresh(world,p+Vector3i.UP)
		for side in FruitCrops.CONNECT_ORDER: FruitCrops.refresh(world,p+side)

static func destroy(world: VoxelWorld, entry: Dictionary) -> void:
	var p: Vector3i = entry.from; var id: int = int(entry.id)
	if world.node_at(p) != id: return # Paired doors may already remove a second queued half.
	if CropFarming.piston_break(world,p) or FruitCrops.piston_break(world,p) or Amethyst.piston_break(world,p): return
	if torch(id):
		if world.set_node(p,Nodes.AIR): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.TORCH if Torches.is_torch(id) else id,1)
	elif id == VillageContent.ITEM_FRAME:
		var saved: Dictionary = world.stations.get(VoxelWorld.station_key(p),{}).duplicate(true)
		if world.set_node(p,Nodes.AIR):
			world.stations.erase(VoxelWorld.station_key(p))
			world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,id,1)
			for stack in saved.get("slots",[]):
				if int(stack.get("id",0)) != 0 and int(stack.get("count",0)) > 0: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,stack.id,stack.count,stack.get("wear",0),stack.get("data",{}))
			world.get_parent().survival.refresh_displays()
	elif RedstoneInputs.is_device(id): RedstoneInputs.break_attached(world,p)
	elif SnowCover.is_snow(id): SnowCover.drop(world,p,id)
	elif Doors.is_door(id): Doors.break_node(world.get_parent(),p,id,0,true)
	else: world.set_node(p,Nodes.AIR) # Cake intentionally has no drop.

static func future_intersects(world: VoxelWorld, body: AABB, future: Dictionary) -> bool:
	var lo := Vector3i(body.position.floor()); var hi := Vector3i(body.end.floor())
	for y in range(lo.y-1,hi.y+1):
		for z in range(lo.z,hi.z+1):
			for x in range(lo.x,hi.x+1):
				var p := Vector3i(x,y,z)
				var boxes: Array = future[p] if future.has(p) else world.collision_boxes(p)
				for box in boxes:
					if body.intersects(AABB(Vector3(p)+box.position,box.size)): return true
	return false

static func actors(world: VoxelWorld) -> Array:
	var game: Node = world.get_parent(); var result: Array = []
	var riding: bool = game.boats != null and is_instance_valid(game.boats.riding)
	var mounted: bool = game.survival != null and is_instance_valid(game.survival.mount)
	if is_instance_valid(game.player) and not riding and not mounted: result.append({"actor":game.player,"width":0.29,"height":1.8})
	for actor in game.creatures.get_children():
		if actor is Creature and not actor.is_queued_for_deletion() and not Boats.is_passenger(actor): result.append({"actor":actor,"width":actor.width,"height":actor.height})
	if game.boats != null:
		for boat in game.boats.active.values():
			if is_instance_valid(boat) and not boat.is_queued_for_deletion() and not boat.removed: result.append({"actor":boat,"width":0.5,"height":0.55})
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): result.append({"actor":drop,"width":0.12,"height":0.24,"offset":Vector3(0,-0.12,0)})
	for entity in game.entities.get_children():
		if entity.is_queued_for_deletion(): continue
		if entity is PrimedTnt or entity is FallingNode: result.append({"actor":entity,"width":0.49,"height":0.98,"offset":Vector3(0.5,0.01,0.5)})
		elif entity is Arrow or entity is TridentProjectile or entity is PotionProjectile or entity is ThrownItem or entity is MagicProjectile: result.append({"actor":entity,"width":0.10,"height":0.20,"offset":Vector3(0,-0.10,0)})
	return result

static func future_boxes(world: VoxelWorld, p: Vector3i, ids: Dictionary) -> Array:
	var id: int = int(ids.get(p,world.node_at(p)))
	if Barriers.is_barrier(id):
		var neighbors: Array = []
		for side in Barriers.SIDES+[Vector3i.UP]: neighbors.append(int(ids.get(p+side,world.node_at(p+side))))
		return Barriers.boxes(id,Barriers.mask(id,neighbors),true)
	if BuildingShapes.is_shape(id):
		var neighbors: Array = []
		for side in BuildingShapes.DIRECTIONS: neighbors.append(int(ids.get(p+side,world.node_at(p+side))))
		return BuildingShapes.boxes(BuildingShapes.mask(id,neighbors))
	if Farmland.is_soil(id): return Farmland.boxes(id)
	if Amethyst.is_crystal(id): return Amethyst.boxes(id)
	if SnowCover.is_snow(id): return SnowCover.boxes(id)
	if FoodFeatures.is_cake(id): return FoodFeatures.boxes(id)
	if Doors.is_door(id): return Doors.boxes(id)
	if Trapdoors.is_trapdoor(id): return Trapdoors.boxes(id)
	if id == VillageContent.CAULDRON: return Cauldrons.boxes()
	if RedstoneSensors.is_detector(id): return RedstoneSensors.boxes(id)
	if Campfires.is_campfire(id): return Campfires.boxes(id)
	return [AABB(Vector3.ZERO,Vector3.ONE)] if Nodes.solid(id) else []

static func future_geometry(world: VoxelWorld, planned: Dictionary, head: Variant) -> Dictionary:
	var ids: Dictionary = {}; var future: Dictionary = {}; var changed: Dictionary = {}; var swept_ignore: Dictionary = {}
	for entry in planned.nodes+planned.dig:
		ids[entry.from] = Nodes.AIR; swept_ignore[entry.from] = []
		if Doors.is_door(entry.id) and Doors.matching_pair(world,entry.from,entry.id): ids[Doors.other(entry.from,entry.id)] = Nodes.AIR
	for entry in planned.nodes:
		ids[entry.to] = entry.id; swept_ignore[entry.to] = []
	if head != null: ids[head] = Nodes.PISTON_HEAD; swept_ignore[head] = []
	for p in ids:
		changed[p] = true
		# Connections also change on stationary neighboring fences/walls/stairs.
		for side in SIDES: changed[p+side] = true
	for p in changed:
		var id: int = int(ids.get(p,world.node_at(p)))
		if ids.has(p) or Barriers.is_barrier(id) or BuildingShapes.is_shape(id): future[p] = future_boxes(world,p,ids)
	for entry in planned.nodes:
		entry.boxes = world.collision_boxes(entry.from)
		entry.future_boxes = future[entry.to]
	return {"future":future,"swept_ignore":swept_ignore}

static func body_affected(world: VoxelWorld, body: AABB, planned: Dictionary, future: Dictionary, head: Variant) -> bool:
	if head != null and body.intersects(AABB(Vector3(head),Vector3.ONE)): return true
	for entry in planned.dig:
		if body.intersects(AABB(Vector3(entry.from),Vector3.ONE)): return true
	for p in future:
		for box in future[p]:
			if not body.intersects(AABB(Vector3(p)+box.position,box.size)): continue
			# A newly connecting stationary arm matters just as much as a moved
			# node. Existing unrelated overlaps do not create new push candidates.
			var existed: bool = false
			for old_box in world.collision_boxes(p):
				if body.intersects(AABB(Vector3(p)+old_box.position,old_box.size)): existed = true; break
			if not existed: return true
	return false

static func passengers(world: VoxelWorld, actor: Node3D) -> Array:
	var game: Node = world.get_parent(); var result: Array = []
	if actor is BoatEntity:
		if game.boats.riding == actor: result.append({"actor":game.player,"offset":actor.basis*Vector3(0,0.15,-0.1),"width":0.29,"height":1.8})
		if is_instance_valid(actor.passenger) and not actor.passenger.is_queued_for_deletion(): result.append({"actor":actor.passenger,"offset":actor.basis*Vector3(0,0.15,0.45 if game.boats.riding == actor else -0.1),"width":actor.passenger.width,"height":actor.passenger.height})
	elif game.survival != null and actor == game.survival.mount: result.append({"actor":game.player,"offset":Vector3.UP*1.1,"width":0.29,"height":1.8})
	return result

static func actor_shifts(world: VoxelWorld, planned: Dictionary, movement: Vector3i, head: Variant) -> Dictionary:
	var geometry: Dictionary = future_geometry(world,planned,head)
	var future: Dictionary = geometry.future; var swept_ignore: Dictionary = geometry.swept_ignore; var moved: Array = []
	for data in actors(world):
		var actor: Node3D = data.actor; var offset: Vector3 = data.get("offset",Vector3.ZERO)
		var body: AABB = Trapdoors.actor_box(actor.position+offset,data.width,data.height)
		var riders: Array = passengers(world,actor)
		var affected: bool = body_affected(world,body,planned,future,head); var launch: bool = false
		for rider in riders:
			if body_affected(world,Trapdoors.actor_box(rider.actor.position,rider.width,rider.height),planned,future,head): affected = true
		for entry in planned.nodes:
			for box in entry.future_boxes:
				if body.intersects(AABB(Vector3(entry.to)+box.position,box.size)):
					affected = true
					if entry.id == VillageContent.SLIME_BLOCK: launch = true
			for box in entry.boxes:
				var original := AABB(Vector3(entry.from)+box.position,box.size)
				if movement != Vector3i.UP and absf(actor.position.y+offset.y-original.end.y) < 0.08 and body.position.x < original.end.x and body.end.x > original.position.x and body.position.z < original.end.z and body.end.z > original.position.z: affected = true
		if not affected: continue
		var destination: Vector3 = actor.position+Vector3(movement)
		var destination_body: AABB = Trapdoors.actor_box(destination+offset,data.width,data.height)
		var blocked: bool = not world.loaded_at(destination) or future_intersects(world,destination_body,future) or future_intersects(world,body.merge(destination_body),swept_ignore)
		for rider in riders:
			var start_body: AABB = Trapdoors.actor_box(rider.actor.position,rider.width,rider.height)
			var end_body: AABB = Trapdoors.actor_box(destination+rider.offset,rider.width,rider.height)
			if not world.loaded_at(destination+rider.offset) or future_intersects(world,end_body,future) or future_intersects(world,start_body.merge(end_body),swept_ignore): blocked = true
		if blocked:
			if actor is VoxeyPlayer or actor is Creature or actor is BoatEntity: return {}
			continue # Loose entities do not jam an otherwise valid push.
		moved.append({"actor":actor,"position":destination,"launch":launch})
	return {"shifts":moved}

# Source object movement runs after on_dig has created item entities. Transport
# those new drops too; when forward transport is blocked, a bounded face escape
# supplies the item collision recovery normally provided by the voxel engine.
static func recover_drops(world: VoxelWorld, old_drops: Dictionary, movement: Vector3i) -> void:
	for drop in world.get_parent().drops.get_children():
		if drop.is_queued_for_deletion() or old_drops.has(drop.get_instance_id()): continue
		var destination: Vector3 = drop.position+Vector3(movement)
		if world.loaded_at(destination) and not world.intersects(destination,0.1,0.2): drop.position = destination; continue
		if not world.intersects(drop.position,0.1,0.2): continue
		var at := Vector3i(drop.position.floor()); var body: AABB = Trapdoors.actor_box(drop.position,0.1,0.2)
		var candidates: Array = []
		for axis in 3:
			for amount in [float(at[axis])-body.end[axis]-0.002,float(at[axis]+1)-body.position[axis]+0.002]:
				var motion := Vector3.ZERO; motion[axis] = amount; candidates.append(motion)
		candidates.sort_custom(func(a,b): return a.length_squared() < b.length_squared())
		for motion in candidates:
			destination = drop.position+motion
			if not world.loaded_at(destination) or world.intersects(destination,0.1,0.2): continue
			if not Trapdoors.clear_correction(world,at,body.merge(Trapdoors.actor_box(destination,0.1,0.2))): continue
			drop.position = destination; break

static func push(circuit: RedstoneCircuit, start: Vector3i, movement: Vector3i, base: Vector3i, head: Variant = null) -> bool:
	var world: VoxelWorld = circuit.world
	var planned: Dictionary = plan(circuit,start,movement,base)
	if planned.is_empty(): return false
	var shifts: Dictionary = actor_shifts(world,planned,movement,head)
	if shifts.is_empty(): return false
	for entry in planned.nodes:
		entry.state = world.block_states.get(VoxelWorld.station_key(entry.from),{}).duplicate(true)
		if Signs.is_sign(entry.id): Signs.station(world,entry.from)
		entry.station = world.stations.get(VoxelWorld.station_key(entry.from),{}).duplicate(true)
		entry.hive = Beehives.move_state(world,entry.from)
	var old_drops: Dictionary = {}
	for drop in world.get_parent().drops.get_children(): old_drops[drop.get_instance_id()] = true
	circuit.moving = true
	for entry in planned.dig: destroy(world,entry)
	# Equal translation permits farthest-first writes; all state was captured
	# before hooks run, so intersecting adhesive branches cannot overwrite it.
	planned.nodes.sort_custom(func(a,b): return Vector3(a.from).dot(Vector3(movement)) > Vector3(b.from).dot(Vector3(movement)))
	for entry in planned.nodes:
		world.stations.erase(VoxelWorld.station_key(entry.from))
		world.stations.erase(VoxelWorld.station_key(entry.to))
		world.set_node(entry.to,entry.id); world.set_node(entry.from,Nodes.AIR)
		if not entry.state.is_empty(): world.block_states[VoxelWorld.station_key(entry.to)] = entry.state
		if not entry.station.is_empty(): world.stations[VoxelWorld.station_key(entry.to)] = entry.station
		Beehives.restore_moved(world,entry.to,entry.hive)
		circuit.refresh(entry.to)
	if head != null:
		world.set_node(head,Nodes.PISTON_HEAD); circuit.configure(head,movement)
	var game: Node = world.get_parent()
	for shift in shifts.shifts:
		var actor: Node3D = shift.actor; actor.position = shift.position
		if actor is BoatEntity: actor.seat_occupants(); actor.store_record()
		elif game.survival != null and actor == game.survival.mount: game.player.position = actor.position+Vector3.UP*1.1
		if shift.launch and not actor is BoatEntity:
			var strength := Vector3(10,13,10) if actor is VoxeyPlayer else (Vector3(20,20,20) if actor is Creature else (Vector3(9,11,9) if actor is ItemDrop else (Vector3(43,72,43) if actor is FallingNode else Vector3(6,9,6))))
			actor.velocity += Vector3(movement)*strength
	finish(circuit)
	recover_drops(world,old_drops,movement)
	return true
