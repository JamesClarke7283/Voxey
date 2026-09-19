class_name RedstoneCircuit
extends RefCounted

# `mcl_hoppers/init.lua`: `GAMETICK_TIME = 0.05`, so the idle interval is 0.050s,
# a real transfer buys 0.400s, and an emptied destination hopper gets 0.350s.
const HOPPER_INTERVAL = 0.05
const HOPPER_COOLDOWN = 0.4
const HOPPER_EMPTY_COOLDOWN = 0.35

# Source `mcl_inv_nodes_movable`, whose default is true.
const INV_NODES_MOVABLE = true
# Source `mcl_redstone_sticky_pistons_one_tick_detach`, whose default is true: a
# sticky piston powered for a single tick does not pull its block back.
const ONE_TICK_DETACH = true

const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
const HORIZONTAL = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const FURNACES = [Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE]
const CONTAINERS = [VillageContent.RECOVERY_CHEST,VillageContent.BREWING_STAND,TrappedChests.ID,Nodes.CHEST,Nodes.FURNACE,Nodes.DISPENSER,Nodes.DROPPER,Nodes.HOPPER,VillageContent.BARREL,VillageContent.SMOKER,VillageContent.BLAST_FURNACE]
var world: VoxelWorld
var tracked: Dictionary = {}
var power: Dictionary = {}
var strong: Dictionary = {}
var visuals: Dictionary = {}
var accumulator: float = 0.0
# Monotonic redstone-tick counter, used to time a one-tick sticky detach.
var ticks: int = 0
# `mcl_dispensers` chooses its stack at random. The generator lives here so a test
# can seed it and pin which slot a given activation dispenses from.
var dispenser_rng := RandomNumberGenerator.new()
# Source `burnout_tab`: a torch that is switched off eight times within thirty
# seconds stays off. This is the reference's fast-clock limiter, and without it a
# redstone torch in a tight loop never stops toggling.
const BURNOUT_LIMIT = 8
const BURNOUT_WINDOW = 30.0
var moving: bool = false

func _init(owner_world: VoxelWorld) -> void:
	world = owner_world

static func circuit_node(id: int) -> bool:
	return Rails.is_rail(id) or id in Nodes.CIRCUIT_NODES or id == NoteBlocks.ID or RedstoneInputs.is_device(id) or RedstoneSensors.is_device(id) or Barriers.is_gate(id) or Trapdoors.is_trapdoor(id) or Doors.is_door(id) or Copper.is_bulb(id) or Copper.is_rod(id)

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
	if circuit_node(id):
		tracked[p] = id
		if RedstoneSensors.is_device(id): RedstoneSensors.registered(world,p,id)
		if RedstoneInputs.is_device(id): RedstoneInputs.registered(world,p,id)
		if id == NoteBlocks.ID: NoteBlocks.state(world,p)
	else: tracked.erase(p)
	refresh(p)

func changed(p: Vector3i, old_id: int, id: int) -> void:
	var preserve: bool = (Farmland.is_soil(old_id) and Farmland.is_soil(id)) or RedstoneInputs.same_family(old_id,id) or Doors.same_family(old_id,id) or Copper.same_family(old_id,id) or Rails.same_family(old_id,id) or (old_id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN] and id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]) or Trapdoors.same_family(old_id,id) or RedstoneSensors.same_family(old_id,id) or (Barriers.is_gate(old_id) and Barriers.is_gate(id) and Barriers.item(old_id) == Barriers.item(id))
	if old_id != id and not preserve:
		world.block_states.erase(VoxelWorld.station_key(p))
	register(p,id)
	notify_observers(p)
	# Removing a piston removes its head; removing a head retracts the base.
	if old_id in [Nodes.PISTON,Nodes.STICKY_PISTON] and not moving:
		piston_extended_at.erase(VoxelWorld.station_key(p))
		for d in SIDES:
			if world.node_at(p+d) == Nodes.PISTON_HEAD and direction(p+d) == d:
				world.set_node(p+d,Nodes.AIR)
				# `piston_remove_pusher` plays the retract sound when a head goes.
				var game: Node = world.get_parent()
				if game != null and game.has_method("sound_at"):
					game.sound_at("piston_retract",Vector3(p+d)+Vector3.ONE*0.5)
	if old_id == Nodes.PISTON_HEAD and not moving:
		for d in SIDES:
			if world.node_at(p-d) in [Nodes.PISTON,Nodes.STICKY_PISTON] and direction(p-d) == d:
				state(p-d)["extended"] = false
				# `piston_remove_base`: destroying the pusher destroys the base too
				# and drops the **off** piston as an item.
				var base: Vector3i = p-d
				var kind: int = world.node_at(base)
				if world.set_node(base,Nodes.AIR):
					var game: Node = world.get_parent()
					if game != null and game.has_method("spawn_drop") and game.gamemode != "creative":
						game.spawn_drop(Vector3(base)+Vector3.ONE*0.5,kind,1)
					if game != null and game.has_method("sound_at"):
						game.sound_at("piston_retract",Vector3(base)+Vector3.ONE*0.5)

func notify_observers(p: Vector3i) -> void:
	for d in SIDES:
		var q: Vector3i = p+d
		if world.node_at(q) == Nodes.OBSERVER and q-direction(q) == p: state(q)["pulse"] = 0.2

func unload(c: Vector2i) -> void:
	for p in tracked.keys():
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == c:
			tracked.erase(p)
			power.erase(p)
			if visuals.has(p): visuals[p].queue_free(); visuals.erase(p)
	for p in strong.keys():
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == c: strong.erase(p)

func support_changed(p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	RedstoneInputs.support_changed(world,p)
	var current: int = world.node_at(p)
	if not BuildingShapes.is_shape(current) and Nodes.solid(current): return
	for side in SIDES:
		var q: Vector3i = p+side
		var id: int = world.node_at(q)
		if RedstoneInputs.is_device(id) or id not in Nodes.SMALL_CIRCUITS or id == Nodes.IRON_DOOR_OPEN: continue
		var saved: Array = state(q).get("support",[0,-1,0])
		var support := Vector3i(saved[0],saved[1],saved[2])
		if q+support != p or BuildingShapes.supports(world,p,-support): continue
		world.set_node(q,Nodes.AIR)
		world.get_parent().spawn_drop(Vector3(q)+Vector3.ONE*0.5,id,1)

func refresh(p: Vector3i) -> void:
	if visuals.has(p): visuals[p].queue_free(); visuals.erase(p)
	if not tracked.has(p) or not world.loaded_at(Vector3(p)): return
	if int(tracked[p]) == NoteBlocks.ID or Barriers.is_gate(int(tracked[p])) or Trapdoors.is_trapdoor(int(tracked[p])) or Doors.is_door(int(tracked[p])) or Rails.is_rail(int(tracked[p])): return # These blocks use their world mesh.
	var root: Node3D = RedstoneInputs.build(int(tracked[p]),state(p)) if RedstoneInputs.is_device(int(tracked[p])) else RedstoneArt.build(int(tracked[p]),state(p),int(power.get(p,0)))
	root.position = Vector3(p)+Vector3(0.5,0,0.5)
	var d := Vector3(direction(p))
	if RedstoneInputs.is_device(int(tracked[p])): pass # Attachment is encoded in the mesh.
	elif d.y == 0: root.rotation.y = atan2(-d.x,-d.z)
	elif tracked[p] in [Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.PISTON_HEAD,Nodes.OBSERVER,Nodes.DISPENSER,Nodes.DROPPER]:
		root.position += Vector3.UP*0.5
		root.rotation.x = PI/2.0*d.y
		for child in root.get_children(): child.position.y -= 0.5
	world.add_child(root)
	visuals[p] = root

func interact(p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if RedstoneInputs.is_button(id): return RedstoneInputs.use(world.get_parent(),{"pos":p,"id":id})
	if RedstoneSensors.is_detector(id): return RedstoneSensors.toggle(world,p)
	if id not in [Nodes.LEVER,Nodes.REPEATER,Nodes.COMPARATOR,Nodes.DISPENSER,Nodes.DROPPER,Nodes.HOPPER]: return false
	var s: Dictionary = state(p)
	match id:
		Nodes.LEVER: s["on"] = not s.get("on",false)
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
		# One redstone tick, which `ONE_TICK_DETACH` measures in.
		ticks += 1
		step(0.1)
		steps += 1

func output(p: Vector3i, toward: Vector3i) -> int:
	if not tracked.has(p):
		# A trapped chest is not a tracked circuit node, but it powers its
		# neighbours while open, so a wire beside it must read that level.
		if TrappedChests.is_trapped(world.node_at(p)): return TrappedChests.output(world,p)
		return int(strong.get(p,0))
	var id: int = tracked[p]
	# A powered rod emits a strong 15 in every direction; a bulb only reports
	# its lit state to a comparator and does not power neighbours.
	if Copper.is_rod(id): return clampi(int(state(p).get("out",0)),0,15)
	if Copper.is_bulb(id): return 0
	if id == NoteBlocks.ID: return int(strong.get(p,0))
	if RedstoneInputs.is_device(id): return RedstoneInputs.weak_power(id,state(p),toward)
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

func step(dt: float = 0.1) -> void:
	if tracked.is_empty(): return
	var previous: Dictionary = power.duplicate()
	var plate_entities: Variant = RedstoneInputs.entity_index(world) if tracked.values().any(RedstoneInputs.is_plate) else null
	# Sources and delayed outputs are evaluated against the previous tick.
	for p in tracked.keys():
		if not world.loaded_at(Vector3(p)): continue
		var id: int = world.node_at(p)
		var s: Dictionary = state(p)
		var before: Array = appearance(s)
		if RedstoneSensors.is_device(id): RedstoneSensors.tick(world,p,id,s,dt)
		if RedstoneInputs.is_device(id): RedstoneInputs.tick(world,p,id,s,dt,plate_entities)
		if Copper.is_rod(id): Copper.tick_rod(world,p,s,dt)
		if Rails.is_rail(id): Rails.tick(world,p,id,s,dt)
		match id:
			Nodes.REDSTONE_BLOCK: s["out"] = 15
			Nodes.LEVER: s["out"] = 15 if s.get("on",false) else 0
			Nodes.REDSTONE_TORCH:
				var support: Array = s.get("support",[0,-1,0])
				var q: Vector3i = p+Vector3i(support[0],support[1],support[2])
				# Ignore the torch itself when testing its attached block.
				var wanted: int = 15 if input_power(q,p-q) == 0 else 0
				# Source `burnout_tab`: the count rises by one on each on-to-off edge,
				# and `mcl_redstone.after(30, ...)` removes one count thirty seconds
				# later. At eight counts the torch refuses to relight, which is the
				# reference's fast-clock limiter. The queue of pending decrements is
				# held as a list of remaining seconds.
				var pending: Array = s.get("burnout",[])
				var index: int = pending.size()-1
				while index >= 0:
					var remaining: float = float(pending[index])-dt
					if remaining <= 0: pending.remove_at(index)
					else: pending[index] = remaining
					index -= 1
				if wanted == 0 and int(s.get("out",15)) != 0: pending.append(BURNOUT_WINDOW)
				if wanted != 0 and pending.size() >= BURNOUT_LIMIT: wanted = 0
				s["burnout"] = pending
				s["out"] = wanted
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
				if id == Nodes.COMPARATOR and (world.node_at(p-d) in CONTAINERS or PortableStorage.is_shulker(world.node_at(p-d)) or world.node_at(p-d) in [Jukeboxes.ID,VillageContent.COMPOSTER,VillageContent.CAULDRON] or FoodFeatures.is_cake(world.node_at(p-d)) or Beehives.is_hive(world.node_at(p-d)) or Copper.is_bulb(world.node_at(p-d))): rear = container_signal(p-d)
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
		if RedstoneInputs.is_device(id):
			for d in SIDES:
				var q: Vector3i = p+d
				if Nodes.solid(world.node_at(q)) and (not tracked.has(q) or world.node_at(q) == NoteBlocks.ID): strong[q] = maxi(int(strong.get(q,0)),RedstoneInputs.strong_power(id,state(p),d))
			continue
		if id == NoteBlocks.ID: continue # Conduct incoming strong power without becoming a source.
		if RedstoneSensors.is_device(id) or Barriers.is_gate(id) or Trapdoors.is_trapdoor(id) or Doors.is_door(id): continue # Source devices emit weak power only.
		if id in [Nodes.REDSTONE_WIRE,Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.PISTON_HEAD,Nodes.REDSTONE_LAMP,Nodes.HOPPER,Nodes.DROPPER,Nodes.DISPENSER,Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]: continue
		for d in SIDES:
			var q: Vector3i = p+d
			if Nodes.solid(world.node_at(q)) and (not tracked.has(q) or world.node_at(q) == NoteBlocks.ID): strong[q] = maxi(int(strong.get(q,0)),output(p,d))
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
		if Copper.is_bulb(id): Copper.bulb(world,p,id,s,level)
		elif id in [Nodes.PISTON,Nodes.STICKY_PISTON]: piston(p,on)
		elif id == NoteBlocks.ID: NoteBlocks.power(world,p,on,was_on)
		elif id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]:
			var new_id: int = Nodes.IRON_DOOR_OPEN if on else Nodes.IRON_DOOR
			if id != new_id: world.set_node(p,new_id)
		elif Barriers.is_gate(id) and was_on != on: Barriers.set_open(world,p,on)
		elif Doors.is_door(id): Doors.power(world,p)
		elif Trapdoors.is_trapdoor(id):
			if int(s.get("trapdoor_power",0)) != level: Trapdoors.set_open(world,p,on)
			s["trapdoor_power"] = level
		elif id in [Nodes.DISPENSER,Nodes.DROPPER] and on and not was_on: dispense(p,id == Nodes.DISPENSER)
		elif id == Nodes.HOPPER and not on:
			# `mcl_hoppers`: HOPPER_COOLDOWN_TIME 0.400s when a transfer happened and
			# HOPPER_INTERVAL_TIME 0.050s when it did not, so an idle hopper keeps
			# looking ten times faster than a busy one.
			s["transfer"] = float(s.get("transfer",0))+dt
			if s.transfer >= float(s.get("transfer_delay",HOPPER_INTERVAL)):
				s["transfer"] = 0
				s["transfer_delay"] = HOPPER_COOLDOWN if hopper(p) else HOPPER_INTERVAL
		if was_on != on: refresh(p)
	# Adjacent powered wiring lights TNT; perform mutations after traversals.
	var ignite: Array = []
	for p in tracked:
		for d in SIDES:
			if world.node_at(p+d) == Nodes.TNT and output(p,d) > 0 and p+d not in ignite: ignite.append(p+d)
	for p in ignite: world.get_parent().ignite_tnt(p)

func container_signal(p: Vector3i) -> int:
	# A trapped chest reports full strength to its neighbours while it is open,
	# which is the block's whole purpose. Its signal is not its fullness, so it is
	# read before the fullness path below.
	if TrappedChests.is_trapped(world.node_at(p)): return TrappedChests.output(world,p)
	# `measure_chiseled_bookshelf`: a shelf reports the last slot that changed, not its
	# fullness, which is why it is read here beside the trapped chest.
	if world.node_at(p) == Bookshelves.ID: return Bookshelves.comparator_output(world,p)
	if Copper.is_bulb(world.node_at(p)): return Copper.signal_strength(world.node_at(p))
	if Beehives.is_hive(world.node_at(p)): return Beehives.signal_strength(world,p)
	if world.node_at(p) == Jukeboxes.ID: return Jukeboxes.signal_strength(world,p)
	if FoodFeatures.is_cake(world.node_at(p)): return FoodFeatures.slices(world.node_at(p))*2
	if world.node_at(p) == VillageContent.CAULDRON: return Cauldrons.level(world.get_station(p,"cauldron"))
	if world.node_at(p) == VillageContent.COMPOSTER: return Composters.level(world.get_station(p,"composter"))
	var slots: Array = container(p)
	if slots.is_empty(): return 0
	var fullness: float = 0
	for slot in slots:
		if slot.id != 0: fullness += float(slot.count)/Nodes.max_stack(slot.id)
	return 0 if fullness == 0 else 1+floori(fullness/slots.size()*14)

func container(p: Vector3i) -> Array:
	if world.node_at(p) not in CONTAINERS and not PortableStorage.is_shulker(world.node_at(p)): return []
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

func hopper(p: Vector3i) -> bool:
	var slots: Array = container(p)
	var d := direction(p)
	if d == Vector3i.UP: d = Vector3i.DOWN
	var destination: Array = container(p+d)
	if world.node_at(p+d) in FURNACES and d == Vector3i.DOWN and destination[2].count > 0: destination = []
	elif world.node_at(p+d) in FURNACES: destination = [destination[0 if d == Vector3i.DOWN else 1]]
	for slot in slots:
		if PortableStorage.is_shulker(world.node_at(p+d)) and not PortableStorage.accepts(PortableStorage.station(world,p+d),slot): continue
		if world.node_at(p+d) == VillageContent.COMPOSTER:
			if d == Vector3i.DOWN and Composters.add(world.get_station(p+d,"composter"),slot.id): consume_one(slot); return true
			continue
		if world.node_at(p+d) in FURNACES:
			if d == Vector3i.DOWN and Nodes.smelt_result(slot.id) == 0: continue
			if d != Vector3i.DOWN and Nodes.fuel_time(slot.id) <= 0: continue
		if world.node_at(p+d) == VillageContent.BREWING_STAND:
			var eligible: Array = []
			for i in destination.size():
				if (d == Vector3i.DOWN and i != 0) or (d != Vector3i.DOWN and i == 0): continue
				if Brewing.accepts(i,slot.id): eligible.append(destination[i])
			if slot.id != 0 and insert_one(eligible,slot): consume_one(slot); return true
		elif slot.id != 0 and insert_one(destination,slot): consume_one(slot); return true
	if world.node_at(p+Vector3i.UP) == Bookshelves.ID:
		# The source registers `_on_hopper_out` on the shelf, so a hopper above feeds
		# one book per transfer into the first free slot.
		for shelf_slot in slots:
			if shelf_slot.id != 0 and Bookshelves.hopper_in(world,p+Vector3i.UP,shelf_slot): consume_one(shelf_slot); return true
	if world.node_at(p+Vector3i.UP) == VillageContent.COMPOSTER:
		var compost: Dictionary = world.get_station(p+Vector3i.UP,"composter")
		if Composters.level(compost) == 8 and insert_one(slots,{"id":Nodes.BONE_MEAL,"count":1,"wear":0}):
			Composters.harvest(compost); return true
	var above: Array = container(p+Vector3i.UP)
	if world.node_at(p+Vector3i.UP) in FURNACES: above = [above[2]]
	if world.node_at(p+Vector3i.UP) == VillageContent.BREWING_STAND: above = above.slice(2,5)
	for slot in above:
		if slot.id != 0 and insert_one(slots,slot): consume_one(slot); return true
	# `mcl_hoppers`: a hopper also exchanges with a chest or hopper minecart one
	# block above (pull) or one block below (push) within 1.5 blocks horizontally.
	if cart_transfer(p): return true
	# `mcl_hoppers.hopper_collect` only runs when the node above is not a full
	# solid, and its window is a radius-2 sphere with the item between 0.3 and 1.5
	# above the hopper.
	if full_solid(p+Vector3i.UP): return false
	# `mcl_hoppers.hopper_collect`: the window is `0.5 + radius` in x and z, the item
	# must be at least 0.3 above the hopper, and the upper bound is measured to the
	# drop's box **bottom** (`posob.y + cbox[2]`), not its centre. An item resting on
	# the block above a hopper therefore still qualifies.
	const DROP_RADIUS = 0.25
	for drop in world.get_parent().drops.get_children():
		if drop.is_queued_for_deletion(): continue
		var at: Vector3 = drop.position
		if absf(at.x-(p.x+0.5)) > 0.5+DROP_RADIUS or absf(at.z-(p.z+0.5)) > 0.5+DROP_RADIUS: continue
		if at.y-p.y < 0.3 or at.y-DROP_RADIUS-p.y >= 1.5: continue
		if insert_one(slots,{"id":drop.item_id,"count":1,"wear":drop.wear,"data":drop.data}):
			drop.amount -= 1
			if drop.amount <= 0: drop.queue_free()
			return true
	return false

# Source `hopper_and_mc` with its `DIST_FROM_MC = 1.5`: a cart at the hopper's own
# y + 1 is pulled from, and one at y - 1 is pushed into.
func cart_transfer(p: Vector3i) -> bool:
	var game: Node = world.get_parent()
	if game == null or game.rails == null: return false
	var slots: Array = container(p)
	if slots.is_empty(): return false
	for cart in game.rails.active.values():
		if cart == null or not is_instance_valid(cart) or cart.is_queued_for_deletion(): continue
		if cart.kind != Rails.CHEST_CART and cart.kind != Rails.HOPPER_CART: continue
		if absf(cart.position.x-(p.x+0.5)) > 1.5 or absf(cart.position.z-(p.z+0.5)) > 1.5: continue
		var cargo: Array = game.rails.cargo(cart)
		if floori(cart.position.y) == p.y+1:
			for slot in cargo:
				if slot.id != 0 and insert_one(slots,slot): consume_one(slot); return true
		elif floori(cart.position.y) == p.y-1:
			for slot in slots:
				if slot.id != 0 and insert_one(cargo,slot): consume_one(slot); return true
	return false

# Source `is_full_solid`: a node whose first collision box is at least half a block
# tall counts as solid, which is what stops items being sucked through a thin
# decorative block sitting on the hopper.
func full_solid(p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id == Nodes.AIR or Fluids.liquid(id): return false
	if not Nodes.solid(id): return false
	var boxes: Array = world.collision_boxes(p)
	return boxes.is_empty() or boxes[0].size.y >= 0.5

func dispense(p: Vector3i, projectile: bool) -> void:
	var slots: Array = container(p)
	var game: Node = world.get_parent()
	var d := direction(p)
	var origin := Vector3(p)+Vector3.ONE*0.5+Vector3(d)*0.75
	# `mcl_dispensers`: the source collects every non-empty stack and picks one **at
	# random**, rather than always taking the first. Ordering the non-empty indexes
	# and choosing one of them is the same distribution.
	var choices: Array = []
	for i in slots.size():
		if slots[i].id != 0: choices.append(i)
	if choices.is_empty(): return
	for pick in [choices[dispenser_rng.randi_range(0,choices.size()-1)]]:
		var slot: Dictionary = slots[pick]
		if projectile and Golems.dispense(self,p,p+d,d,slot): return
		if projectile and Beehives.dispense(self,p,p+d,d,slot): return
		if not projectile and (world.node_at(p+d) in CONTAINERS or PortableStorage.is_shulker(world.node_at(p+d))):
			if PortableStorage.is_shulker(world.node_at(p+d)) and not PortableStorage.accepts(PortableStorage.station(world,p+d),slot): return
			var destination: Array = container(p+d)
			if world.node_at(p+d) in FURNACES:
				var eligible: Array = []
				var index: int = 0 if d == Vector3i.DOWN else 1
				if FurnaceRules.accepts(destination,index,slot.id): eligible.append(destination[index])
				destination = eligible
			if insert_one(destination,slot): consume_one(slot)
			return
		# The source's per-item `_on_dispense` actions: bone meal, buckets, flint and
		# steel, fire charges, potions and XP bottles.
		if Dispensers.handles(slot.id):
			var outcome: Dictionary = Dispensers.dispense(game,p,d,slot)
			if bool(outcome.get("applied",false)):
				if int(outcome.get("replacement",0)) != 0 and int(outcome.replacement) != slot.id: slot.id = int(outcome.replacement)
				if bool(outcome.get("consume",true)): consume_one(slot)
				return
		if projectile and Throwables.supports(slot.id):
			if Nodes.solid(world.node_at(p+d)): return
			Throwables.launch(game,slot.id,Vector3(p)+Vector3.ONE*0.5+Vector3(d)*0.51,Vector3(d))
		elif projectile and Boats.is_boat(slot.id):
			game.boats.dispense(slot,p,d)
		elif projectile and slot.id == Nodes.ARROW_ITEM:
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
	if VillageContent.shape(id) == "banner" or Beehives.immovable(id) or id in [Jukeboxes.ID,Dungeons.SPAWNER] or Campfires.is_campfire(id) or RedstoneSensors.is_detector(id): return false
	if not world.loaded_at(Vector3(p)) or p.y <= world.generator.min_y() or p.y >= world.generator.max_y()-1: return false
	# `mcl_pistons/api.lua`: `inv_nodes_movable` defaults to **true**, so a chest, a
	# furnace, a dispenser or a hopper is pushed like any other block. It is a
	# setting in the source, and Voxey's default follows the source's default.
	if id in CONTAINERS and not INV_NODES_MOVABLE: return false
	if id in [Nodes.BEDROCK,Nodes.OBSIDIAN,Nodes.END_FRAME,Nodes.END_FRAME_EYE,Nodes.END_PORTAL,Nodes.END_GATEWAY,Nodes.NETHER_PORTAL,Nodes.BLAZE_SPAWNER,Nodes.PISTON_HEAD,Nodes.BED_FOOT,Nodes.BED_HEAD] or id in [VillageContent.COMPOSTER,VillageContent.CAULDRON] or PortableStorage.is_storage(id): return false
	return not (id in [Nodes.PISTON,Nodes.STICKY_PISTON] and state(p).get("extended",false))

func _move(from: Vector3i, to: Vector3i) -> void:
	var id: int = world.node_at(from)
	if Signs.is_sign(id): Signs.station(world,from)
	var station: Dictionary = world.stations.get(VoxelWorld.station_key(from),{}).duplicate(true)
	var hive: Dictionary = Beehives.move_state(world,from)
	var metadata: Dictionary = world.block_states.get(VoxelWorld.station_key(from),{}).duplicate(true)
	world.stations.erase(VoxelWorld.station_key(from)); world.stations.erase(VoxelWorld.station_key(to))
	world.set_node(to,id)
	world.set_node(from,Nodes.AIR)
	if not station.is_empty(): world.stations[VoxelWorld.station_key(to)] = station
	Beehives.restore_moved(world,to,hive)
	if not metadata.is_empty(): world.block_states[VoxelWorld.station_key(to)] = metadata; refresh(to)

# `activation_time_tab`: the tick each sticky piston last extended on.
var piston_extended_at: Dictionary = {}

# True when this piston extended within the last redstone tick, which is the
# source's `ONE_TICK_DETACH` condition.
func was_one_tick_pulse(p: Vector3i) -> bool:
	var key: String = VoxelWorld.station_key(p)
	if not piston_extended_at.has(key): return false
	return ticks-piston_extended_at[key] <= 1

func piston(p: Vector3i, extend: bool) -> bool:
	var s: Dictionary = state(p)
	if bool(s.get("extended",false)) == extend: return true
	var d := direction(p)
	if extend:
		if not PistonPush.push(self,p+d,d,p,p+d): return false
		# `mcl_pistons/nodes.lua` `piston_on`: farmland directly under the pusher is
		# trampled to dirt by the extending head.
		# `mcl_pistons/nodes.lua`: the trampled cell is below `np`, the head's own
		# position, not below the base.
		var below: Vector3i = p+d+Vector3i.DOWN
		if Farmland.is_soil(world.node_at(below)): world.set_node(below,Nodes.DIRT)
	else:
		moving = true
		if world.node_at(p+d) == Nodes.PISTON_HEAD: world.set_node(p+d,Nodes.AIR)
		var id: int = world.node_at(p+d*2)
		# A one-tick pulse leaves the block behind: the source stores the tick it
		# extended on and detaches rather than pulling when the reversal comes
		# within one redstone tick.
		var detach: bool = ONE_TICK_DETACH and world.node_at(p) == Nodes.STICKY_PISTON and was_one_tick_pulse(p)
		if world.node_at(p) == Nodes.STICKY_PISTON and not detach and not PistonPush.replaceable(id) and not PistonPush.unsticky(id): PistonPush.push(self,p+d*2,-d,p)
		PistonPush.finish(self)
	s["extended"] = extend
	if extend: piston_extended_at[VoxelWorld.station_key(p)] = ticks
	# `piston_extend` / `piston_retract` at gain 0.3 over 31 blocks.
	var game: Node = world.get_parent()
	if game != null and game.has_method("sound_at"):
		game.sound_at("piston_extend" if extend else "piston_retract",Vector3(p)+Vector3.ONE*0.5)
	refresh(p)
	return true

static func appearance(s: Dictionary) -> Array:
	return [s.get("out",0),s.get("input_pressed",false),s.get("powered",false),s.get("delay",1),s.get("subtract",false),s.get("locked",false),s.get("extended",false)]
