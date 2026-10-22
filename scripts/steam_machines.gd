class_name SteamMachines
extends RefCounted

# Steam is a finite resource drawn from boilers through redstone-driven bellows.
# Network reachability is rebuilt at each fixed tick: breaking a pipe immediately
# isolates its consumers, and branches cannot multiply a boiler's stored steam.
const GENERATOR = 12000
const BELLOWS = 12001
const PIPE = 12002
const FURNACE = 12003
const GRINDER = 12004
const ENGINE = 12005
const FRAME = 12006
const IRON_POWDER = 12010
const GOLD_POWDER = 12011
const COPPER_POWDER = 12012
const COAL_POWDER = 12013
const DIAMOND_POWDER = 12014
const LAPIS_POWDER = 12015
const REDSTONE_POWDER = 12016
const QUARTZ_POWDER = 12017
const EMERALD_POWDER = 12018
const BLOCKS = [GENERATOR,BELLOWS,PIPE,FURNACE,GRINDER,ENGINE,FRAME]
const CONTAINERS = [GENERATOR,FURNACE,GRINDER]
const CONSUMERS = [FURNACE,GRINDER,ENGINE]
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
const CAPACITY = 240.0
const COAL_SECONDS = 40.0
const STEAM_RATE = 12.0
const WORK_SECONDS = 4.0
const FRAME_LIMIT = 256
const PIPE_LIMIT = 1024
const MOVE_SECONDS = 0.8
const DATA = {
	12000:{"name":"Coal-fired steam generator","block":true,"shape":"steam","color":"67594e","hardness":3.5,"tool":0},
	12001:{"name":"Steam bellows","block":true,"shape":"steam","color":"996742","hardness":2.5,"tool":0},
	12002:{"name":"Iron steam pipe","block":true,"shape":"steam","color":"a3adb0","hardness":2.0,"tool":0},
	12003:{"name":"Steam furnace","block":true,"shape":"steam","color":"676e72","hardness":3.5,"tool":0},
	12004:{"name":"Steam ore grinder","block":true,"shape":"steam","color":"897861","hardness":3.5,"tool":0},
	12005:{"name":"Steam frame engine","block":true,"shape":"steam","color":"a9864c","hardness":3.5,"tool":0},
	12006:{"name":"Machine frame","block":true,"shape":"steam","color":"977450","hardness":2.5,"tool":0},
	12010:{"name":"Iron ore powder","color":"dba36f","smelt":Nodes.IRON},
	12011:{"name":"Gold ore powder","color":"e3be56","smelt":Nodes.GOLD},
	12012:{"name":"Copper ore powder","color":"dc885e","smelt":Nodes.COPPER},
	12013:{"name":"Coal ore powder","color":"484b54","smelt":Nodes.COAL},
	12014:{"name":"Diamond ore powder","color":"6cdbd4","smelt":Nodes.DIAMOND},
	12015:{"name":"Lapis ore powder","color":"456ed2","smelt":Nodes.LAPIS},
	12016:{"name":"Redstone ore powder","color":"ca4340","smelt":Nodes.REDSTONE_WIRE},
	12017:{"name":"Quartz ore powder","color":"eee5db","smelt":Nodes.QUARTZ},
	12018:{"name":"Emerald ore powder","color":"4ac37d","smelt":VillageContent.EMERALD},
}
# [powder, count]. Raw metal items work too, so normal mining needs no Silk Touch.
const GRINDS = {
	Nodes.IRON_ORE:[IRON_POWDER,4], RawOres.RAW_IRON:[IRON_POWDER,4],
	Nodes.GOLD_ORE:[GOLD_POWDER,4], RawOres.RAW_GOLD:[GOLD_POWDER,4],
	Nodes.COPPER_ORE:[COPPER_POWDER,8], RawOres.RAW_COPPER:[COPPER_POWDER,4],
	Nodes.COAL_ORE:[COAL_POWDER,4], Nodes.DIAMOND_ORE:[DIAMOND_POWDER,4],
	Nodes.LAPIS_ORE:[LAPIS_POWDER,16], Nodes.REDSTONE_ORE:[REDSTONE_POWDER,16],
	Nodes.NETHER_QUARTZ_ORE:[QUARTZ_POWDER,4], VillageContent.EMERALD_ORE:[EMERALD_POWDER,4],
}

static func is_device(id: int) -> bool: return id in BLOCKS and id != FRAME
static func grind(id: int) -> Array:
	if id == VillageContent.DEEP_EMERALD_ORE: id = VillageContent.EMERALD_ORE
	if RedstoneOre.is_lit(id): id = Nodes.REDSTONE_ORE
	return GRINDS.get(Nodes.DEEP_ORES.get(id,Nodes.REDSTONE_ORE if id == Nodes.DEEP_REDSTONE_ORE else id),[])

static func recipes(inv: Inventory) -> void:
	var iron: int = Nodes.IRON; var p: int = Nodes.PLANKS; var r: int = Nodes.REDSTONE_WIRE
	inv._recipe("Coal-fired steam generator",GENERATOR,1,[iron,iron,iron,iron,Nodes.FURNACE,iron,iron,Nodes.BUCKET,iron],3,"table")
	inv._recipe("Steam bellows",BELLOWS,1,[p,Nodes.LEATHER,p,iron,r,iron,p,Nodes.LEATHER,p],3,"table")
	inv._recipe("Iron steam pipes",PIPE,8,[iron,iron,iron,0,0,0,iron,iron,iron],3,"table")
	inv._recipe("Steam furnace",FURNACE,1,[iron,PIPE,iron,iron,Nodes.FURNACE,iron,0,r,0],3,"table")
	inv._recipe("Steam ore grinder",GRINDER,1,[iron,Nodes.FLINT,iron,PIPE,Nodes.PISTON,PIPE,iron,r,iron],3,"table")
	inv._recipe("Machine frames",FRAME,8,[Nodes.STICK,iron,Nodes.STICK,iron,0,iron,Nodes.STICK,iron,Nodes.STICK],3,"table")
	inv._recipe("Steam frame engine",ENGINE,1,[iron,PIPE,iron,Nodes.PISTON,r,Nodes.PISTON,iron,FRAME,iron],3,"table")

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var id: int = world.node_at(p)
	if id not in CONTAINERS: return {}
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = VoxelWorld._new_station("steam",1 if id == GENERATOR else 3)
	var s: Dictionary = world.stations[key]
	s["kind"] = "steam"; s["device"] = id
	return s

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if id in CONTAINERS: station(world,p)

static func accepts(s: Dictionary, index: int, id: int) -> bool:
	if id == 0: return true
	var device: int = s.get("device",0)
	if device == GENERATOR: return index == 0 and id in [Nodes.COAL,Nodes.CHARCOAL,Nodes.COAL_BLOCK]
	if index != 0: return false
	return not grind(id).is_empty() if device == GRINDER else Nodes.smelt_result(id) != 0

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var id: int = game.world.node_at(target.pos)
	if id not in BLOCKS: return false
	# Sneak permits attaching pipes/frames to an existing machine.
	if Input.is_physical_key_pressed(KEY_CTRL): return false
	if id in CONTAINERS:
		station(game.world,target.pos)
		game.open_inventory("steam",target.pos)
	elif id in [BELLOWS,ENGINE] and Screwdriver.is_screwdriver(game.inventory.held().id):
		var d: Vector3i = game.world.circuits.direction(target.pos)
		var order: Array = [Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN]
		d = order[(order.find(d)+1)%order.size()]
		game.world.circuits.configure(target.pos,d)
		game.toast("%s facing %s"%[Nodes.title(id),{Vector3i.RIGHT:"east",Vector3i.LEFT:"west",Vector3i.FORWARD:"north",Vector3i.BACK:"south",Vector3i.UP:"up",Vector3i.DOWN:"down"}[d]])
	else:
		var s: Dictionary = game.world.circuits.state(target.pos)
		game.toast("%s · %s"%[Nodes.title(id),str(s.get("status","Connect steam; power bellows and engines with redstone."))])
	return true

static func draw_steam(world: VoxelWorld, sources: Array, amount: float) -> bool:
	var total: float = 0
	for p in sources: total += float(station(world,p).get("steam",0))
	if total+0.00001 < amount: return false
	for p in sources:
		var s: Dictionary = station(world,p)
		var take: float = minf(float(s.get("steam",0)),amount)
		s["steam"] = maxf(0,float(s.get("steam",0))-take); amount -= take
		if amount <= 0.00001: break
	return true

static func step(world: VoxelWorld, dt: float) -> void:
	var positions: Array = world.circuits.tracked.keys()
	# Generators keep their buffer and burning coal in world.stations (saved).
	for p in positions:
		if world.node_at(p) == PIPE: world.circuits.state(p)["status"] = "No powered steam connection"
		if world.node_at(p) != GENERATOR: continue
		var s: Dictionary = station(world,p)
		var fuel: Dictionary = s.slots[0]
		var steam: float = clampf(float(s.get("steam",0)),0,CAPACITY)
		var burn: float = maxf(0,float(s.get("burn",0)))
		if burn <= 0 and steam < CAPACITY and accepts(s,0,fuel.id) and fuel.id != 0 and fuel.count > 0:
			burn = COAL_SECONDS*(9 if fuel.id == Nodes.COAL_BLOCK else 1)
			RedstoneCircuit.consume_one(fuel)
		var burning: float = minf(dt,burn)
		s["steam"] = minf(CAPACITY,steam+STEAM_RATE*burning)
		s["burn"] = maxf(0,burn-dt)
		s["status"] = "Steam %.0f / %.0f · coal %.0fs"%[s.steam,CAPACITY,s.burn]
	# Build consumers -> unique boilers through a powered, directional bellows.
	var supplies: Dictionary = {}
	for p in positions:
		if world.node_at(p) != BELLOWS: continue
		var s: Dictionary = world.circuits.state(p)
		s["status"] = "Needs redstone power"
		if world.circuits.input_power(p) == 0: continue
		var d: Vector3i = world.circuits.direction(p)
		var boiler: Vector3i = p-d
		if world.node_at(boiler) != GENERATOR:
			s.status = "Place a generator behind the bellows"; continue
		var queue: Array = [p+d]; var seen: Dictionary = {p+d:true}; var cursor: int = 0
		while cursor < queue.size() and cursor < PIPE_LIMIT:
			var at: Vector3i = queue[cursor]; cursor += 1
			var id: int = world.node_at(at)
			if id in CONSUMERS:
				if not supplies.has(at): supplies[at] = []
				if boiler not in supplies[at]: supplies[at].append(boiler)
			elif id == PIPE:
				world.circuits.state(at)["status"] = "Connected to steam generator"
				for side in SIDES:
					var next: Vector3i = at+side
					if not seen.has(next) and (world.node_at(next) == PIPE or world.node_at(next) in CONSUMERS):
						seen[next] = true; queue.append(next)
		s.status = "Pumping steam" if float(station(world,boiler).get("steam",0)) > 0 else "Generator needs coal"
	for p in positions:
		var id: int = world.node_at(p)
		if id not in CONSUMERS: continue
		var sources: Array = supplies.get(p,[])
		if id == ENGINE:
			var s: Dictionary = world.circuits.state(p)
			s["status"] = "Needs redstone power" if world.circuits.input_power(p) == 0 else "Needs steam"
			if sources.is_empty() or world.circuits.input_power(p) == 0: s["move_time"] = 0.0; continue
			s["move_time"] = minf(MOVE_SECONDS,float(s.get("move_time",0))+dt)
			if s.move_time+0.00001 >= MOVE_SECONDS:
				s.move_time = 0.0
				move_vehicle(world,p,sources)
			continue
		process_machine(world,p,sources,dt)

static func process_machine(world: VoxelWorld, p: Vector3i, sources: Array, dt: float) -> void:
	var s: Dictionary = station(world,p)
	var input: Dictionary = s.slots[0]; var output: Dictionary = s.slots[2]
	var recipe: Array = grind(input.id) if s.device == GRINDER else [Nodes.smelt_result(input.id),1]
	if recipe.is_empty() or int(recipe[0]) == 0 or input.count <= 0:
		s.progress = 0.0; s["input_id"] = 0; s["status"] = "Add raw ore or ore blocks" if s.device == GRINDER else "Add ore powder, ore or food"; return
	if s.get("input_id",input.id) != input.id: s.progress = 0.0
	s["input_id"] = input.id
	if (output.id != 0 and output.id != recipe[0]) or output.count+recipe[1] > Nodes.max_stack(recipe[0]):
		s["status"] = "Output full"; return
	if sources.is_empty() or not draw_steam(world,sources,dt*(2.0 if s.device == GRINDER else 1.0)):
		s["status"] = "Needs steam through powered bellows"; return
	s.progress += dt
	s["status"] = "%s %d%%"%["Grinding" if s.device == GRINDER else "Smelting",mini(100,int(s.progress/WORK_SECONDS*100))]
	if s.progress+0.00001 < WORK_SECONDS: return
	s.progress = maxf(0,s.progress-WORK_SECONDS)
	RedstoneCircuit.consume_one(input)
	output.id = recipe[0]; output.count += recipe[1]; output.wear = 0
	if s.device == FURNACE: s["xp"] = int(s.get("xp",0))+FurnaceRules.XP_PER_SMELT

static func plan_vehicle(world: VoxelWorld, engine: Vector3i, movement: Vector3i) -> Dictionary:
	var queue: Array = [engine]; var connected: Dictionary = {engine:true}; var cursor: int = 0
	while cursor < queue.size():
		var at: Vector3i = queue[cursor]; cursor += 1
		for side in SIDES:
			var next: Vector3i = at+side; var id: int = world.node_at(next)
			if connected.has(next) or id == Nodes.AIR: continue
			# Only frames spread the attachment, and an engine attaches to frames.
			if at == engine and id != FRAME: continue
			connected[next] = true
			if connected.size() > FRAME_LIMIT: return {}
			if id == FRAME: queue.append(next)
	if connected.size() == 1: return {}
	var nodes: Array = []
	for at in connected:
		var dest: Vector3i = at+movement
		if not world.circuits.movable(at) or not world.circuits.movable(dest): return {}
		if not connected.has(dest) and world.node_at(dest) != Nodes.AIR: return {}
		nodes.append({"from":at,"to":dest,"id":world.node_at(at)})
	return {"nodes":nodes,"dig":[]}

static func move_vehicle(world: VoxelWorld, p: Vector3i, sources: Array) -> bool:
	var s: Dictionary = world.circuits.state(p)
	var d: Vector3i = world.circuits.direction(p)
	var planned: Dictionary = plan_vehicle(world,p,d)
	if planned.is_empty(): s["status"] = "Blocked, no frames, or over 256 blocks"; return false
	var shifts: Dictionary = PistonPush.actor_shifts(world,planned,d,null)
	if shifts.is_empty(): s["status"] = "Passenger path blocked"; return false
	if not draw_steam(world,sources,4.0+planned.nodes.size()*0.1): s["status"] = "Needs more steam"; return false
	s["status"] = "Moving %d blocks"%planned.nodes.size()
	split_moving_chests(world,planned)
	return PistonPush.apply_plan(world.circuits,planned,d,shifts)

# Double chests store their 54 slots under a pair key, rather than either cell.
# Split that state into its original halves before translation. Normal chest
# access joins moved neighbors again and also handles a half left behind.
static func split_moving_chests(world: VoxelWorld, planned: Dictionary) -> void:
	var handled: Dictionary = {}
	for entry in planned.nodes:
		if entry.id != Nodes.CHEST: continue
		var at: Vector3i = entry.from
		var other: Vector3i = world.chest_partner(at)
		if other == at: continue
		var key: String = world.pair_key(at,other)
		if handled.has(key) or not world.stations.has(key): continue
		handled[key] = true
		var pair: Dictionary = world.stations[key]
		var primary: Vector3i = world.chest_primary(at,other)
		for cell in [at,other]:
			var offset: int = 0 if cell == primary else 27
			var half: Dictionary = pair.duplicate()
			half.slots = pair.slots.slice(offset,offset+27)
			world.stations[world.station_key(cell)] = half
		world.stations.erase(key)

static func boxes(id: int) -> Array:
	if id == PIPE: return [AABB(Vector3(0,0.38,0.38),Vector3(1,0.24,0.24)),AABB(Vector3(0.38,0,0.38),Vector3(0.24,1,0.24)),AABB(Vector3(0.38,0.38,0),Vector3(0.24,0.24,1))]
	if id != FRAME: return [AABB(Vector3.ZERO,Vector3.ONE)]
	var result: Array = []
	for a in [0.0,0.86]:
		for b in [0.0,0.86]:
			result.append(AABB(Vector3(0,a,b),Vector3(1,0.14,0.14)))
			result.append(AABB(Vector3(a,0,b),Vector3(0.14,1,0.14)))
			result.append(AABB(Vector3(a,b,0),Vector3(0.14,0.14,1)))
	return result

static func mesh(out: Array, p: Vector3, id: int) -> void:
	for box in boxes(id): BlockMesher._art_box(out,p+box.get_center(),box.size,Nodes.tile(id,0),Nodes.tile(id,2))

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if id == FRAME: return base.darkened(0.3) if x%4 == 0 else base
	if id == PIPE: return base.lightened(0.2) if x in [3,4,11,12] else base.darkened(0.15 if y%8 == 0 else 0)
	if x in [0,15] or y in [0,15]: return base.darkened(0.4)
	if x in [2,13] and y in [2,13]: return Color("d1b57c")
	if y in range(4,11) and x in range(4,12):
		if id == GENERATOR or id == FURNACE: return Color("e7a052") if y > 7 and x%3 != 0 else Color("302b2b")
		if id == GRINDER: return Color("beb9a2") if (x+y)%3 == 0 else Color("343b40")
		if id == BELLOWS: return Color("452d25") if y%2 == 0 else Color("af8055")
		if id == ENGINE: return Color("d9bd77") if x == 8 or y == 7 else Color("374b53")
	return noise.lerp(base,0.75)

static func draw_powder(img: Image, id: int) -> void:
	var base := Color(DATA[id].color)
	ItemArt._polygon(img,[[2,12],[5,8],[8,6],[11,8],[14,12],[12,14],[4,14]],base)
	for point in [Vector2i(4,6),Vector2i(10,3),Vector2i(12,6),Vector2i(7,10)]: img.set_pixelv(point,base.lightened(0.3))

static func direction_marker(id: int, state: Dictionary) -> Node3D:
	var root := Node3D.new()
	if id not in [BELLOWS,ENGINE]: return root
	var brass := Color("d8b76d")
	# Inlet at +Z, marked outlet at -Z; RedstoneCircuit rotates the assembly.
	RedstoneArt.box(root,Vector3(0,0.5,0.51),Vector3(0.34,0.34,0.04),Color("272f35"))
	RedstoneArt.box(root,Vector3(0,0.5,-0.51),Vector3(0.4,0.4,0.04),brass)
	RedstoneArt.box(root,Vector3(0,0.5,-0.54),Vector3(0.23,0.23,0.03),Color("33414a"))
	RedstoneArt.box(root,Vector3(0,1.012,0),Vector3(0.07,0.025,0.5),brass)
	for side in [-1,1]:
		var arrow: MeshInstance3D = RedstoneArt.box(root,Vector3(side*0.09,1.012,-0.2),Vector3(0.06,0.025,0.26),brass)
		arrow.rotation.y = side*0.8
	var active: bool = state.get("powered",false)
	RedstoneArt.box(root,Vector3(0.34,0.8,-0.512),Vector3(0.09,0.09,0.035),Color("e56443") if active else Color("543d33"),0.5 if active else 0)
	return root

static func draw_fitting(img: Image, id: int) -> void:
	if id == PIPE:
		ItemArt._line(img,Vector2(2,10),Vector2(13,5),Color("586871"),5)
		ItemArt._line(img,Vector2(2,8),Vector2(13,3),Color("b9c9cf"),3)
		ItemArt._line(img,Vector2(6,6),Vector2(9,13),Color("83949e"),4)
		for start in [Vector2(2,7),Vector2(11,3)]:
			ItemArt._line(img,start,start+Vector2(2,4),Color("d1d8d7"),2)
		return
	var wood := Color("b48c58")
	# Wireframe cube, with the rear edges first and open faces.
	for edge in [[Vector2(1,5),Vector2(8,2)],[Vector2(8,2),Vector2(14,5)],[Vector2(8,2),Vector2(8,10)],[Vector2(1,5),Vector2(8,8)],[Vector2(8,8),Vector2(14,5)],[Vector2(1,5),Vector2(1,12)],[Vector2(14,5),Vector2(14,12)],[Vector2(8,8),Vector2(8,15)],[Vector2(1,12),Vector2(8,15)],[Vector2(8,15),Vector2(14,12)]]:
		ItemArt._line(img,edge[0],edge[1],wood,2)
	for corner in [Vector2i(1,5),Vector2i(14,5),Vector2i(8,8),Vector2i(8,14)]: img.set_pixelv(corner,Color("e5d39d"))
