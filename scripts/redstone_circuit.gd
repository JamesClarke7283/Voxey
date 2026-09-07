class_name RedstoneCircuit
extends RefCounted

const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
const HORIZONTAL = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const FURNACES = [Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CAMPFIRE]
const CONTAINERS = [VillageContent.RECOVERY_CHEST,VillageContent.BREWING_STAND,Nodes.CHEST,Nodes.FURNACE,Nodes.DISPENSER,Nodes.DROPPER,Nodes.HOPPER,VillageContent.BARREL,VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CAMPFIRE]
var world: VoxelWorld
var tracked: Dictionary = {}
var power: Dictionary = {}
var strong: Dictionary = {}
var visuals: Dictionary = {}
var accumulator: float = 0.0
var moving: bool = false

func _init(owner_world: VoxelWorld) -> void:
	world = owner_world

func state(p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {"dir":[0,0,-1],"out":0,"delay":1}
	return world.block_states[key]

func direction(p: Vector3i) -> Vector3i:
	var d: Array = state(p).get("dir",[0,0,-1])
	return Vector3i(int(d[0]),int(d[1]),int(d[2]))

func configure(p: Vector3i, d: Vector3i, support: Vector3i = Vector3i.DOWN) -> void:
	state(p)["dir"] = [d.x,d.y,d.z]
	state(p)["support"] = [support.x,support.y,support.z]
	refresh(p)

func register(p: Vector3i, id: int) -> void:
	if id in Nodes.CIRCUIT_NODES: tracked[p] = id
	else: tracked.erase(p)
	refresh(p)

func changed(p: Vector3i, old_id: int, id: int) -> void:
	if old_id != id and not (old_id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN] and id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]):
		world.block_states.erase(VoxelWorld.station_key(p))
	register(p,id)
	for d in SIDES:
		var q: Vector3i = p+d
		if world.node_at(q) == Nodes.OBSERVER and q-direction(q) == p: state(q)["pulse"] = 0.2
	# Removing a piston removes its head; removing a head retracts the base.
	if old_id in [Nodes.PISTON,Nodes.STICKY_PISTON] and not moving:
		for d in SIDES:
			if world.node_at(p+d) == Nodes.PISTON_HEAD and direction(p+d) == d: world.set_node(p+d,Nodes.AIR)
	if old_id == Nodes.PISTON_HEAD and not moving:
		for d in SIDES:
			if world.node_at(p-d) in [Nodes.PISTON,Nodes.STICKY_PISTON] and direction(p-d) == d: state(p-d)["extended"] = false

func unload(c: Vector2i) -> void:
	for p in tracked.keys():
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == c:
			tracked.erase(p)
			if visuals.has(p): visuals[p].queue_free(); visuals.erase(p)

func refresh(p: Vector3i) -> void:
	if visuals.has(p): visuals[p].queue_free(); visuals.erase(p)
	if not tracked.has(p) or not world.loaded_at(Vector3(p)): return
	var root: Node3D = RedstoneArt.build(int(tracked[p]),state(p),int(power.get(p,0)))
	root.position = Vector3(p)+Vector3(0.5,0,0.5)
	var d := Vector3(direction(p))
	if d.y == 0: root.rotation.y = atan2(-d.x,-d.z)
	elif tracked[p] in [Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.PISTON_HEAD,Nodes.OBSERVER,Nodes.DISPENSER,Nodes.DROPPER]:
		root.position += Vector3.UP*0.5
		root.rotation.x = PI/2.0*d.y
		for child in root.get_children(): child.position.y -= 0.5
	world.add_child(root)
	visuals[p] = root

func interact(p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id not in [Nodes.LEVER,Nodes.BUTTON,Nodes.REPEATER,Nodes.COMPARATOR,Nodes.DISPENSER,Nodes.DROPPER,Nodes.HOPPER]: return false
	var s: Dictionary = state(p)
	match id:
		Nodes.LEVER: s["on"] = not s.get("on",false)
		Nodes.BUTTON: s["remaining"] = 1.0
		Nodes.REPEATER:
			s["delay"] = int(s.get("delay",1))%4+1
			world.get_parent().toast("Repeater: %d redstone ticks" % s.delay)
		Nodes.COMPARATOR:
			s["subtract"] = not s.get("subtract",false)
			world.get_parent().toast("Comparator: "+("subtract" if s.subtract else "compare"))
		Nodes.DISPENSER,Nodes.DROPPER,Nodes.HOPPER:
			world.get_station(p,"chest")["label"] = Nodes.title(id).to_upper()+" STORAGE"
			world.get_parent().open_inventory("chest",p)
		_: return false
	refresh(p)
	return true

func update(delta: float) -> void:
	accumulator += delta
	# Fixed 10 Hz simulation; cap catch-up after a stalled frame.
	var steps: int = 0
	while accumulator >= 0.1 and steps < 5:
		accumulator -= 0.1
		step(0.1)
		steps += 1

func output(p: Vector3i, toward: Vector3i) -> int:
	if not tracked.has(p): return int(strong.get(p,0))
	var id: int = tracked[p]
	if id == Nodes.REDSTONE_WIRE: return int(power.get(p,0))
	if id in [Nodes.REPEATER,Nodes.COMPARATOR,Nodes.OBSERVER] and toward != direction(p): return 0
	if id == Nodes.REDSTONE_TORCH:
		var a: Array = state(p).get("support",[0,-1,0])
		if toward == Vector3i(a[0],a[1],a[2]): return 0
	return int(state(p).get("out",0))

func input_power(p: Vector3i, excluded: Vector3i = Vector3i.ZERO) -> int:
	var level: int = 0
	for d in SIDES:
		if d != excluded: level = maxi(level,output(p+d,-d))
	return level

func _wire_neighbors(p: Vector3i) -> Array:
	var result: Array = []
	for d in HORIZONTAL:
		var q: Vector3i = p+d
		if world.node_at(q) == Nodes.REDSTONE_WIRE: result.append(q)
		elif Nodes.solid(world.node_at(q)) and not Nodes.solid(world.node_at(p+Vector3i.UP)) and world.node_at(q+Vector3i.UP) == Nodes.REDSTONE_WIRE: result.append(q+Vector3i.UP)
		elif not Nodes.solid(world.node_at(q)) and world.node_at(q+Vector3i.DOWN) == Nodes.REDSTONE_WIRE: result.append(q+Vector3i.DOWN)
	return result

func _occupied(p: Vector3i) -> bool:
	var game: Node = world.get_parent()
	if game.player.position.distance_to(Vector3(p)+Vector3(0.5,0.1,0.5)) < 0.85: return true
	for root in [game.creatures,game.drops]:
		for entity in root.get_children():
			if not entity.is_queued_for_deletion() and entity.position.distance_to(Vector3(p)+Vector3(0.5,0.2,0.5)) < 0.9: return true
	return false

func step(dt: float = 0.1) -> void:
	if tracked.is_empty(): return
	var previous: Dictionary = power.duplicate()
	# Sources and delayed outputs are evaluated against the previous tick.
	for p in tracked.keys():
		var id: int = world.node_at(p)
		var s: Dictionary = state(p)
		var before: Array = appearance(s)
		match id:
			Nodes.REDSTONE_BLOCK: s["out"] = 15
			Nodes.LEVER: s["out"] = 15 if s.get("on",false) else 0
			Nodes.BUTTON:
				s["out"] = 15 if float(s.get("remaining",0)) > 0 else 0
				s["remaining"] = maxf(0,float(s.get("remaining",0))-dt)
			Nodes.PRESSURE_PLATE: s["out"] = 15 if _occupied(p) else 0
			Nodes.REDSTONE_TORCH:
				var support: Array = s.get("support",[0,-1,0])
				var q: Vector3i = p+Vector3i(support[0],support[1],support[2])
				# Ignore the torch itself when testing its attached block.
				s["out"] = 15 if input_power(q,p-q) == 0 else 0
			Nodes.REPEATER,Nodes.COMPARATOR:
				var d := direction(p)
				var rear: int = output(p-d,d)
				var side_level: int = 0
				var locked: bool = false
				for side in HORIZONTAL:
					if side == d or side == -d: continue
					side_level = maxi(side_level,output(p+side,-side))
					if world.node_at(p+side) in [Nodes.REPEATER,Nodes.COMPARATOR] and output(p+side,-side) > 0: locked = true
				if id == Nodes.REPEATER and locked: s["locked"] = true; continue
				s["locked"] = false
				if id == Nodes.COMPARATOR and world.node_at(p-d) in CONTAINERS: rear = container_signal(p-d)
				var wanted: int = 15 if rear > 0 else 0
				if id == Nodes.COMPARATOR: wanted = maxi(0,rear-side_level) if s.get("subtract",false) else (rear if rear >= side_level else 0)
				if id == Nodes.REPEATER:
					# Queue both edges and stretch short pulses to the selected delay.
					if not s.has("edges"): s["edges"] = []
					if wanted != int(s.get("last_input",0)):
						var delay: float = float(s.get("delay",1))*0.1
						var wait_time: float = delay if s.edges.is_empty() else maxf(delay,float(s.edges.back().remaining)+delay)
						s.edges.append({"remaining":wait_time,"value":wanted})
						s["last_input"] = wanted
					for edge in s.edges: edge.remaining -= dt
					if not s.edges.is_empty() and float(s.edges[0].remaining) < 0.00001: s["out"] = int(s.edges.pop_front().value)
				else: s["out"] = wanted
			Nodes.OBSERVER:
				s["out"] = 15 if float(s.get("pulse",0)) > 0 else 0
				s["pulse"] = maxf(0,float(s.get("pulse",0))-dt)
		if before != appearance(s): refresh(p)
	strong.clear()
	# Directional components and controls can strongly power one solid block.
	for p in tracked:
		var id: int = tracked[p]
		if id in [Nodes.REDSTONE_WIRE,Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.PISTON_HEAD,Nodes.REDSTONE_LAMP,Nodes.HOPPER,Nodes.DROPPER,Nodes.DISPENSER,Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]: continue
		for d in SIDES:
			var q: Vector3i = p+d
			if Nodes.solid(world.node_at(q)) and not tracked.has(q): strong[q] = maxi(int(strong.get(q,0)),output(p,d))
	power.clear()
	var queue: Array = []
	for p in tracked:
		if tracked[p] != Nodes.REDSTONE_WIRE: continue
		var level: int = 0
		for d in SIDES:
			if world.node_at(p+d) != Nodes.REDSTONE_WIRE: level = maxi(level,output(p+d,-d))
		power[p] = level
		if level > 0: queue.append(p)
	var index: int = 0
	while index < queue.size():
		var p: Vector3i = queue[index]; index += 1
		for q in _wire_neighbors(p):
			var value: int = int(power[p])-1
			if value > int(power.get(q,0)): power[q] = value; queue.append(q)
	for p in tracked.keys():
		var id: int = world.node_at(p)
		var s: Dictionary = state(p)
		var level: int = int(power.get(p,0)) if id == Nodes.REDSTONE_WIRE else input_power(p)
		var on: bool = level > 0
		if id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]:
			var other: Vector3i = p+(Vector3i.DOWN if s.get("upper",false) else Vector3i.UP)
			if world.node_at(other) in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]: on = on or input_power(other) > 0
		if id == Nodes.REDSTONE_WIRE:
			if previous.get(p,0) != level: refresh(p)
			continue
		var was_on: bool = s.get("powered",false)
		s["powered"] = on
		if id in [Nodes.PISTON,Nodes.STICKY_PISTON]: piston(p,on)
		elif id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]:
			var new_id: int = Nodes.IRON_DOOR_OPEN if on else Nodes.IRON_DOOR
			if id != new_id: world.set_node(p,new_id)
		elif id in [Nodes.DISPENSER,Nodes.DROPPER] and on and not was_on: dispense(p,id == Nodes.DISPENSER)
		elif id == Nodes.HOPPER and not on:
			s["transfer"] = float(s.get("transfer",0))+dt
			if s.transfer >= 0.4: s.transfer = 0; hopper(p)
		if was_on != on: refresh(p)
	# Adjacent powered wiring lights TNT; perform mutations after traversals.
	var ignite: Array = []
	for p in tracked:
		for d in SIDES:
			if world.node_at(p+d) == Nodes.TNT and output(p,d) > 0 and p+d not in ignite: ignite.append(p+d)
	for p in ignite: world.get_parent().ignite_tnt(p)

func container_signal(p: Vector3i) -> int:
	var slots: Array = container(p)
	if slots.is_empty(): return 0
	var fullness: float = 0
	for slot in slots:
		if slot.id != 0: fullness += float(slot.count)/Nodes.max_stack(slot.id)
	return 0 if fullness == 0 else 1+floori(fullness/slots.size()*14)

func container(p: Vector3i) -> Array:
	if world.node_at(p) not in CONTAINERS: return []
	var station: Dictionary = world.get_station(p,"brewing" if world.node_at(p) == VillageContent.BREWING_STAND else ("furnace" if world.node_at(p) in FURNACES else "chest"))
	if world.node_at(p) in FURNACES: station.device = world.node_at(p)
	return station.slots

static func insert_one(slots: Array, item: Dictionary) -> bool:
	for pass_index in 2:
		for slot in slots:
			if (pass_index == 0 and slot.id == item.id and slot.wear == item.wear and slot.get("data",{}) == item.get("data",{}) and slot.count < Nodes.max_stack(item.id)) or (pass_index == 1 and slot.id == 0):
				slot.id = item.id; slot.wear = item.wear; slot.count += 1
				Inventory.copy_data(slot,item)
				return true
	return false

static func consume_one(slot: Dictionary) -> void:
	slot.count -= 1
	if slot.count <= 0: slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")

func hopper(p: Vector3i) -> void:
	var slots: Array = container(p)
	var d := direction(p)
	if d == Vector3i.UP: d = Vector3i.DOWN
	var destination: Array = container(p+d)
	if world.node_at(p+d) in FURNACES: destination = [destination[0 if d == Vector3i.DOWN else 1]]
	for slot in slots:
		if world.node_at(p+d) in FURNACES:
			if d == Vector3i.DOWN and Nodes.smelt_result(slot.id) == 0: continue
			if d != Vector3i.DOWN and Nodes.fuel_time(slot.id) <= 0: continue
		if world.node_at(p+d) == VillageContent.BREWING_STAND:
			var eligible: Array = []
			for i in destination.size():
				if (d == Vector3i.DOWN and i != 0) or (d != Vector3i.DOWN and i == 0): continue
				if Brewing.accepts(i,slot.id): eligible.append(destination[i])
			if slot.id != 0 and insert_one(eligible,slot): consume_one(slot); break
		elif slot.id != 0 and insert_one(destination,slot): consume_one(slot); break
	var above: Array = container(p+Vector3i.UP)
	if world.node_at(p+Vector3i.UP) in FURNACES: above = [above[2]]
	if world.node_at(p+Vector3i.UP) == VillageContent.BREWING_STAND: above = above.slice(2,5)
	for slot in above:
		if slot.id != 0 and insert_one(slots,slot): consume_one(slot); return
	for drop in world.get_parent().drops.get_children():
		if drop.is_queued_for_deletion() or drop.position.distance_to(Vector3(p)+Vector3(0.5,1,0.5)) > 1.1: continue
		if insert_one(slots,{"id":drop.item_id,"count":1,"wear":drop.wear,"data":drop.data}):
			drop.amount -= 1
			if drop.amount <= 0: drop.queue_free()
			return

func dispense(p: Vector3i, projectile: bool) -> void:
	var slots: Array = container(p)
	var game: Node = world.get_parent()
	var d := direction(p)
	var origin := Vector3(p)+Vector3.ONE*0.5+Vector3(d)*0.75
	for slot in slots:
		if slot.id == 0: continue
		if not projectile and world.node_at(p+d) in CONTAINERS:
			if insert_one(container(p+d),slot): consume_one(slot)
			return
		if projectile and slot.id == Nodes.ARROW_ITEM:
			var shot: Arrow = game.spawn_arrow(origin,Vector3(d)*24)
			shot.from_player = true; shot.hits_player = true
		elif projectile and slot.id == Nodes.TNT:
			if world.node_at(p+d) != Nodes.AIR: return
			world.set_node(p+d,Nodes.TNT); game.ignite_tnt(p+d)
		else:
			var drop: ItemDrop = game.spawn_drop(origin,slot.id,1,slot.wear,slot.get("data",{}))
			drop.velocity = Vector3(d)*4+Vector3.UP*1.5
		consume_one(slot)
		return

func movable(p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not world.loaded_at(Vector3(p)) or p.y <= world.generator.min_y() or p.y >= world.generator.max_y()-1: return false
	if id in [Nodes.BEDROCK,Nodes.OBSIDIAN,Nodes.END_FRAME,Nodes.END_FRAME_EYE,Nodes.END_PORTAL,Nodes.END_GATEWAY,Nodes.NETHER_PORTAL,Nodes.BLAZE_SPAWNER,Nodes.PISTON_HEAD,Nodes.BED_FOOT,Nodes.BED_HEAD] or id in CONTAINERS: return false
	return not (id in [Nodes.PISTON,Nodes.STICKY_PISTON] and state(p).get("extended",false))

func _move(from: Vector3i, to: Vector3i) -> void:
	var id: int = world.node_at(from)
	var metadata: Dictionary = world.block_states.get(VoxelWorld.station_key(from),{}).duplicate(true)
	world.set_node(to,id)
	world.set_node(from,Nodes.AIR)
	if not metadata.is_empty(): world.block_states[VoxelWorld.station_key(to)] = metadata; refresh(to)

func piston(p: Vector3i, extend: bool) -> bool:
	var s: Dictionary = state(p)
	if bool(s.get("extended",false)) == extend: return true
	var d := direction(p)
	if extend:
		var line: Array = []
		var q: Vector3i = p+d
		while world.node_at(q) != Nodes.AIR:
			if line.size() >= 12 or not movable(q): return false
			line.append(q); q += d
		if not movable(q): return false
		# Move intersecting entities only if they have space at the far side.
		var shifts: Array = []
		var game: Node = world.get_parent()
		for entity in [game.player]+game.creatures.get_children():
			for cell in line+[p+d]:
				var box := AABB(Vector3(cell),Vector3.ONE)
				var body := AABB(entity.position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6))
				if box.intersects(body):
					var destination: Vector3 = entity.position+Vector3(d)
					if world.intersects(destination) and not AABB(Vector3(q),Vector3.ONE).has_point(destination): return false
					if entity not in shifts: shifts.append(entity)
		moving = true
		line.reverse()
		for cell in line: _move(cell,cell+d)
		world.set_node(p+d,Nodes.PISTON_HEAD)
		configure(p+d,d)
		for entity in shifts: entity.position += Vector3(d)
		moving = false
	else:
		moving = true
		if world.node_at(p+d) == Nodes.PISTON_HEAD: world.set_node(p+d,Nodes.AIR)
		if world.node_at(p) == Nodes.STICKY_PISTON and world.node_at(p+d) == Nodes.AIR and world.node_at(p+d*2) != Nodes.AIR and movable(p+d*2): _move(p+d*2,p+d)
		moving = false
	s["extended"] = extend
	refresh(p)
	return true

static func appearance(s: Dictionary) -> Array:
	return [s.get("out",0),s.get("powered",false),s.get("delay",1),s.get("subtract",false),s.get("locked",false),s.get("extended",false)]
