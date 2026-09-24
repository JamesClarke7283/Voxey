class_name WoodTypes
extends RefCounted

# Canonical oak IDs remain compatible with old saves. Other species occupy
# permanent 32-ID groups; axis variants drop their canonical vertical item.
const FIRST = 6000
const NAMES = ["Oak","Spruce","Birch","Jungle","Acacia","Dark oak"]
const KEYS = ["oak","spruce","birch","jungle","acacia","dark_oak"]
const PLANKS = [Nodes.PLANKS,6035,6067,6099,6131,6163]
const LOGS = [Nodes.LOG,6032,6064,6096,6128,6160]
const LEAVES = [Nodes.LEAVES,6033,6065,6097,6129,6161]
const SAPLINGS = [Nodes.SAPLING,6034,6066,6098,6130,6162]
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
const BARK_COLORS = ["745335","62503b","d7d4bc","785840","82796c","46372b"]
const WOOD_COLORS = ["b7955e","896744","dbcf9c","b88661","ba6f4c","594336"]
const LEAF_COLORS = ["639144","426d4b","79a44d","3d9650","748444","42633b"]
const TEXTURES = [6000,6001,6002,6003,6004,6016,6017,6032,6033,6034,6035,6036,6048,6049,6064,6065,6066,6067,6068,6080,6081,6096,6097,6098,6099,6100,6112,6113,6128,6129,6130,6131,6132,6144,6145,6160,6161,6162,6163,6164,6176,6177]
const DATA = {
	6004:{"name":"Oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6004},
	6005:{"name":"Oak bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6005},
	6006:{"name":"Oak stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6006},
	6008:{"name":"Oak log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6,"hidden":true},
	6009:{"name":"Oak log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6,"hidden":true},
	6010:{"name":"Oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6004,"hidden":true},
	6011:{"name":"Oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6004,"hidden":true},
	6032:{"name":"Spruce log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6032},
	6033:{"name":"Spruce leaves","block":true,"family":"wood_leaves","hardness":0.2,"tool":4,"blast_resistance":0.2,"drop":6033,"transparent":true},
	6034:{"name":"Spruce sapling","block":true,"family":"wood_sapling","hardness":0,"tool":1,"blast_resistance":3,"drop":6034,"shape":"plant","transparent":true},
	6035:{"name":"Spruce planks","block":true,"family":"wood_planks","hardness":2,"tool":1,"blast_resistance":3,"drop":6035},
	6036:{"name":"Spruce stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6036},
	6037:{"name":"Spruce bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6037},
	6038:{"name":"Spruce stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6038},
	6040:{"name":"Spruce log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6032,"hidden":true},
	6041:{"name":"Spruce log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6032,"hidden":true},
	6042:{"name":"Spruce stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6036,"hidden":true},
	6043:{"name":"Spruce stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6036,"hidden":true},
	6064:{"name":"Birch log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6064},
	6065:{"name":"Birch leaves","block":true,"family":"wood_leaves","hardness":0.2,"tool":4,"blast_resistance":0.2,"drop":6065,"transparent":true},
	6066:{"name":"Birch sapling","block":true,"family":"wood_sapling","hardness":0,"tool":1,"blast_resistance":3,"drop":6066,"shape":"plant","transparent":true},
	6067:{"name":"Birch planks","block":true,"family":"wood_planks","hardness":2,"tool":1,"blast_resistance":3,"drop":6067},
	6068:{"name":"Birch stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6068},
	6069:{"name":"Birch bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6069},
	6070:{"name":"Birch stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6070},
	6072:{"name":"Birch log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6064,"hidden":true},
	6073:{"name":"Birch log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6064,"hidden":true},
	6074:{"name":"Birch stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6068,"hidden":true},
	6075:{"name":"Birch stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6068,"hidden":true},
	6096:{"name":"Jungle log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6096},
	6097:{"name":"Jungle leaves","block":true,"family":"wood_leaves","hardness":0.2,"tool":4,"blast_resistance":0.2,"drop":6097,"transparent":true},
	6098:{"name":"Jungle sapling","block":true,"family":"wood_sapling","hardness":0,"tool":1,"blast_resistance":3,"drop":6098,"shape":"plant","transparent":true},
	6099:{"name":"Jungle planks","block":true,"family":"wood_planks","hardness":2,"tool":1,"blast_resistance":3,"drop":6099},
	6100:{"name":"Jungle stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6100},
	6101:{"name":"Jungle bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6101},
	6102:{"name":"Jungle stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6102},
	6104:{"name":"Jungle log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6096,"hidden":true},
	6105:{"name":"Jungle log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6096,"hidden":true},
	6106:{"name":"Jungle stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6100,"hidden":true},
	6107:{"name":"Jungle stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6100,"hidden":true},
	6128:{"name":"Acacia log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6128},
	6129:{"name":"Acacia leaves","block":true,"family":"wood_leaves","hardness":0.2,"tool":4,"blast_resistance":0.2,"drop":6129,"transparent":true},
	6130:{"name":"Acacia sapling","block":true,"family":"wood_sapling","hardness":0,"tool":1,"blast_resistance":3,"drop":6130,"shape":"plant","transparent":true},
	6131:{"name":"Acacia planks","block":true,"family":"wood_planks","hardness":2,"tool":1,"blast_resistance":3,"drop":6131},
	6132:{"name":"Acacia stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6132},
	6133:{"name":"Acacia bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6133},
	6134:{"name":"Acacia stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6134},
	6136:{"name":"Acacia log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6128,"hidden":true},
	6137:{"name":"Acacia log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6128,"hidden":true},
	6138:{"name":"Acacia stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6132,"hidden":true},
	6139:{"name":"Acacia stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6132,"hidden":true},
	6160:{"name":"Dark oak log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6160},
	6161:{"name":"Dark oak leaves","block":true,"family":"wood_leaves","hardness":0.2,"tool":4,"blast_resistance":0.2,"drop":6161,"transparent":true},
	6162:{"name":"Dark oak sapling","block":true,"family":"wood_sapling","hardness":0,"tool":1,"blast_resistance":3,"drop":6162,"shape":"plant","transparent":true},
	6163:{"name":"Dark oak planks","block":true,"family":"wood_planks","hardness":2,"tool":1,"blast_resistance":3,"drop":6163},
	6164:{"name":"Dark oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6164},
	6165:{"name":"Dark oak bark wood","block":true,"family":"wood_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6165},
	6166:{"name":"Dark oak stripped bark wood","block":true,"family":"wood_stripped_bark_wood","hardness":2,"tool":1,"blast_resistance":3,"drop":6166},
	6168:{"name":"Dark oak log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6160,"hidden":true},
	6169:{"name":"Dark oak log","block":true,"family":"wood_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6160,"hidden":true},
	6170:{"name":"Dark oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6164,"hidden":true},
	6171:{"name":"Dark oak stripped log","block":true,"family":"wood_stripped_log","hardness":2,"tool":1,"blast_resistance":3,"drop":6164,"hidden":true},
}
static var SCHEMATICS: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/trees/mineclonia_trees.json"))

static func base(kind: int) -> int: return FIRST+clampi(kind,0,5)*32
static func species(id: int) -> int:
	if id in [Nodes.LOG,Nodes.LEAVES,Nodes.SAPLING,Nodes.PLANKS]: return 0
	return (id-FIRST)/32 if id >= FIRST and id < FIRST+192 else -1
static func part(id: int) -> int:
	if id in [Nodes.LOG,Nodes.LEAVES,Nodes.SAPLING,Nodes.PLANKS]: return [Nodes.LOG,Nodes.LEAVES,Nodes.SAPLING,Nodes.PLANKS].find(id)
	return posmod(id-FIRST,32) if species(id) >= 0 else -1
static func is_wood(id: int) -> bool: return id in [Nodes.LOG,Nodes.LEAVES,Nodes.SAPLING,Nodes.PLANKS] or DATA.has(id)
static func is_log(id: int) -> bool: return is_wood(id) and part(id) in [0,4,5,6,8,9,10,11]
static func is_leaves(id: int) -> bool: return LushCaveExtra.is_azalea_leaves(id) or is_wood(id) and part(id) == 1
static func is_sapling(id: int) -> bool: return is_wood(id) and part(id) == 2
static func is_planks(id: int) -> bool: return is_wood(id) and part(id) == 3
static func log_id(kind: int) -> int: return LOGS[clampi(kind,0,5)]
static func leaves_id(kind: int) -> int: return LEAVES[clampi(kind,0,5)]
static func sapling_id(kind: int) -> int: return SAPLINGS[clampi(kind,0,5)]
static func planks_id(kind: int) -> int: return PLANKS[clampi(kind,0,5)]
static func stripped(id: int) -> bool: return part(id) in [4,6,10,11]
static func axis(id: int) -> int: return 0 if part(id) in [8,10] else (2 if part(id) in [9,11] else 1)
static func canonical(id: int) -> int:
	if part(id) in [8,9]: return log_id(species(id))
	if part(id) in [10,11]: return base(species(id))+4
	return id
static func oriented(id: int, normal: Vector3i) -> int:
	if not is_log(id) or part(id) in [5,6]: return id
	if normal.x != 0: return base(species(id))+(10 if stripped(id) else 8)
	if normal.z != 0: return base(species(id))+(11 if stripped(id) else 9)
	return base(species(id))+4 if stripped(id) else log_id(species(id))
static func items() -> Array:
	var result: Array = []
	for id in DATA:
		if not DATA[id].get("hidden",false): result.append(id)
	return result
static func blocks() -> Array: return DATA.keys()
static func fuel_time(id: int) -> float: return 5 if is_sapling(id) else (15 if is_log(id) or is_planks(id) else 0)
static func texture_id(id: int, face: int) -> int:
	var kind: int = species(id); var offset: int = part(id)
	if is_log(id):
		if offset in [5,6]: return base(kind)+(4 if stripped(id) else 0)
		var end: bool = face/2 == axis(id)
		return base(kind)+(17 if stripped(id) else 16) if end else base(kind)+(4 if stripped(id) else 0)
	return base(kind)+offset
static func color(id: int) -> Color:
	var kind: int = maxi(0,species(id)); var offset: int = part(id)
	if offset == 1 or offset == 2: return Color(LEAF_COLORS[kind])
	return Color(WOOD_COLORS[kind]) if offset in [3,4,6,10,11,16,17] else Color(BARK_COLORS[kind])

static func pixel(key: int, x: int, y: int, noise: Color) -> Color:
	var kind: int = maxi(0,species(key)); var offset: int = part(key); var tint: Color = color(key)
	if offset in [16,17]:
		var ring: int = maxi(absi(x-7),absi(y-7))
		if ring in [2,5] or x == 0 or y == 0 or x == 15 or y == 15: return tint.darkened(0.24)
		return noise.lightened(0.08)
	if offset == 3:
		if y%4 == 0 or (x+(y/4)*7)%16 == 0: return tint.darkened(0.3)
		if y%4 == 1: return noise.lightened(0.06)
		return noise
	if offset == 1:
		if (x*7+y*11+x*y)%19 in [0,1,3]: return Color(0,0,0,0)
		return noise.darkened(0.22) if (x/3+y/3)%2 == 0 else noise.lightened(0.05)
	if offset == 2:
		if x in [7,8] and y >= 7: return Color(BARK_COLORS[kind])
		var canopy: bool = (x-7)*(x-7)+(y-6)*(y-6) < (25 if kind != 1 else 18)
		if kind == 1: canopy = y in range(2,11) and absi(x-7) <= (y/3)
		return noise if canopy else Color(0,0,0,0)
	if offset == 4:
		if (x*3+y/5)%13 < 2: return noise.darkened(0.14)
		return noise
	if kind == 2:
		if (x+y/3*5)%13 < 4 and y%4 == 1: return Color("4b4940")
		return noise
	if x%5 == 0 or (x+y/7)%7 == 0: return tint.darkened(0.32)
	return noise

static func recipes(inv: Inventory) -> void:
	for kind in 6:
		var group: int = base(kind)
		for id in [log_id(kind),group+4,group+5,group+6]:
			if id != Nodes.LOG: inv._recipe(NAMES[kind]+" planks",planks_id(kind),4,[id],1)
		for pair in [[log_id(kind),group+5],[group+4,group+6]]:
			inv._recipe(DATA[pair[1]].name,pair[1],3,[pair[0],pair[0],pair[0],pair[0]],2)

static func harvest(id: int, slot: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if not is_leaves(id): return []
	# Azalea leaves are not one of the six wood species, so they have no sapling in
	# the species table; the lush-cave module owns their drops.
	if LushCaveExtra.is_azalea_leaves(id): return LushCaveExtra.leaf_drops(id,slot,rng)
	if slot.get("id",0) == Nodes.SHEARS or (int(slot.get("id",0)) != 0 and Inventory.enchantment(slot,"Silk Touch") > 0): return [[id,1]]
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var fortune: int = clampi(Inventory.enchantment(slot,"Fortune"),0,4) if int(slot.get("id",0)) != 0 else 0
	var sticks: int = [50,45,30,35,10][fortune]
	# Source drop.max_items=1: these independent attempts are ordered, not a
	# weighted table or simultaneous guaranteed sapling/apple/stick rewards.
	if rng.randi_range(1,sticks) == 1: return [[Nodes.STICK,1]]
	if rng.randi_range(1,sticks) == 1: return [[Nodes.STICK,2]]
	var kind: int = species(id)
	var saplings: int = ([40,36,32,24,10] if kind == 3 else [20,16,12,10,10])[fortune]
	if rng.randi_range(1,saplings) == 1: return [[sapling_id(kind),1]]
	if kind in [0,5] and rng.randi_range(1,[200,180,160,120,40][fortune]) == 1: return [[Nodes.APPLE,1]]
	return []

static func soil(id: int) -> bool:
	return Farmland.is_soil(id) or id in [Nodes.DIRT,Nodes.GRASS,Nodes.SNOW,VillageContent.SWAMP_GRASS]

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var id: int = int(target.id); var held: int = game.inventory.held().id
	if Nodes.tool_kind(held) == 1 and is_log(id) and not stripped(id):
		var next: int = base(species(id))+(6 if part(id) == 5 else 4)
		if part(id) in [8,9]: next = base(species(id))+part(id)+2
		if game.world.set_node(target.pos,next):
			if game.gamemode != "creative": game.inventory.damage_tool()
			game.sound("dig")
		return true
	if held == Nodes.BONE_MEAL and is_sapling(id):
		if randf() < 0.45: grow(game.world,target.pos)
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.puff(Vector3(target.pos)+Vector3.ONE*0.5,Color("7cb84a"),8)
		return true
	return false

static func sapling_tick(world: VoxelWorld, p: Vector3i, roll: int = -1) -> void:
	if not is_sapling(world.node_at(p)): world.growth.erase(p); return
	if float(world.growth.get(p,0)) < 35: return
	world.growth[p] = 0.0
	if (randi_range(0,4) if roll < 0 else roll) != 0: return
	var id: int = world.node_at(p)
	var daylight_at_noon: bool = world.open_sky(p-Vector3i.UP)
	if not soil(world.node_at(p+Vector3i.DOWN)) or (Pasture.light(world,p,8) <= 7 and not daylight_at_noon):
		if world.set_node(p,Nodes.AIR): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,id)
		return
	grow(world,p)

static func square(world: VoxelWorld, p: Vector3i, id: int) -> Array:
	for dx in [-1,0]:
		for dz in [-1,0]:
			var corner: Vector3i = p+Vector3i(dx,0,dz)
			var points: Array = [corner,corner+Vector3i.RIGHT,corner+Vector3i.BACK,corner+Vector3i(1,0,1)]
			var valid: bool = true
			for point in points:
				if world.node_at(point) != id: valid = false; break
			if valid: return points
	return []

static func schematics(kind: int, giant: bool = false) -> Array:
	match kind:
		0: return ["oak_classic","oak_large_1","oak_large_2","oak_large_3","oak_large_4"]
		1: return ["spruce_huge_1","spruce_huge_2","spruce_huge_3","spruce_huge_4","spruce_huge_up_1","spruce_huge_up_2","spruce_huge_up_3"] if giant else ["spruce_1","spruce_2","spruce_3","spruce_4","spruce_5","spruce_lollipop","spruce_matchstick","spruce_tall"]
		2: return ["birch"]
		3: return ["jungle_tree_huge_1","jungle_tree_huge_2","jungle_tree_huge_3","jungle_tree_huge_4"] if giant else ["jungle_tree","jungle_tree_2","jungle_tree_3","jungle_tree_4"]
		4: return ["acacia_1","acacia_2","acacia_3","acacia_4","acacia_5","acacia_6","acacia_7","acacia_weirdo"]
		5: return ["dark_oak"]
	return []

static func rotate(p: Vector3i, turn: int, giant: bool) -> Vector3i:
	for i in turn: p = Vector3i((1 if giant else 0)-p.z,p.y,p.x)
	return p

# All source schematics are immutable sparse JSON, safe for worker generation.
static func tree_plan(kind: int, seed_value: int, giant: bool = false, variant: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var choices: Array = schematics(kind,giant)
	var selected: int = variant
	if selected < 0: selected = (0 if rng.randf() < 0.9 else rng.randi_range(1,4)) if kind == 0 else rng.randi_range(0,choices.size()-1)
	var name: String = choices[posmod(selected,choices.size())]
	var schematic: Dictionary = SCHEMATICS[name]
	var turn: int = rng.randi_range(0,3)
	var layers: Array = []; var height: int = 0
	for chance in schematic.layers:
		var include: bool = int(chance) == 127 or rng.randi_range(1,127) <= int(chance)
		layers.append(height if include else -1)
		if include: height += 1
	var blocks_value: Dictionary = {}
	for entry in schematic.nodes:
		if layers[int(entry[1])] < 0: continue
		var probability: int = int(entry[4])&127
		if probability < 127 and rng.randi_range(1,127) > probability: continue
		var source_name: String = schematic.names[int(entry[3])]
		var id: int = Nodes.AIR
		if source_name.begins_with("mcl_trees:tree_"):
			id = log_id(kind)
			var source_axis: int = int(entry[5])/4
			if source_axis in [1,2,3,4]:
				var normal: Vector3i = Vector3i.BACK if source_axis in [1,2] else Vector3i.RIGHT
				if turn%2 != 0: normal = Vector3i.RIGHT if normal == Vector3i.BACK else Vector3i.BACK
				id = oriented(id,normal)
		elif source_name.begins_with("mcl_trees:leaves_"): id = leaves_id(kind)
		elif source_name == "mcl_core:vine": id = Nodes.VINE
		elif source_name.begins_with("mcl_cocoas:cocoa_"): id = VillageContent.RIPE_COCOA_POD if source_name.ends_with("3") else VillageContent.COCOA_POD
		if id == Nodes.AIR: continue
		var pos := Vector3i(int(entry[0])-(int(schematic.size[0])-1)/2,int(layers[int(entry[1])]),int(entry[2])-(int(schematic.size[2])-1)/2)
		blocks_value[rotate(pos,turn,giant or kind == 5)] = id
	return {"blocks":blocks_value,"height":height,"clearance":int(schematic.size[1]),"schematic":name,"giant":giant or kind == 5}

static func grow(world: VoxelWorld, p: Vector3i, seed_value: int = -1) -> bool:
	var id: int = world.node_at(p)
	if not is_sapling(id) or not soil(world.node_at(p+Vector3i.DOWN)): return false
	var kind: int = species(id)
	var seedlings: Array = square(world,p,id) if kind in [1,3,5] else []
	if kind == 5 and seedlings.is_empty(): return false
	var origin: Vector3i = seedlings[0] if not seedlings.is_empty() else p
	if seedlings.is_empty(): seedlings = [p]
	for point in seedlings:
		if not soil(world.node_at(point+Vector3i.DOWN)): return false
	var plan: Dictionary = tree_plan(kind,randi() if seed_value < 0 else seed_value,seedlings.size() == 4)
	# Source giant trees require a six-by-six clear volume. Single trees check
	# the entire center column, even where a probabilistic layer is omitted.
	var width: Array = range(-2,4) if seedlings.size() == 4 else [0]
	for x in width:
		for z in width:
			for y in range(0,int(plan.clearance)):
				if not replaceable(world,origin+Vector3i(x,y,z),seedlings): return false
	# Validate the whole generated shape before consuming any sapling. In
	# particular, forced source trunk nodes may not replace player buildings.
	for offset in plan.blocks:
		var pos: Vector3i = origin+offset
		if not replaceable(world,pos,seedlings): return false
	for point in seedlings: world.set_node(point,Nodes.AIR)
	for offset in plan.blocks: world.set_node(origin+offset,int(plan.blocks[offset]))
	Beehives.after_tree_grow(world,origin,kind,seed_value)
	return true

static func replaceable(world: VoxelWorld, p: Vector3i, seedlings: Array) -> bool:
	if not world.loaded_at(Vector3(p)) or p.y >= world.generator.max_y(): return false
	var id: int = world.node_at(p)
	return seedlings.has(p) or id == Nodes.AIR or SnowCover.is_snow(id) or (is_leaves(id) and not persistent(world,p)) or (not is_sapling(id) and Nodes.plant(id))

static func persistent(world: VoxelWorld, p: Vector3i) -> bool:
	return bool(world.block_states.get(VoxelWorld.station_key(p),{}).get("wood_persistent",false))

# Old saves never distinguished harvested/placed leaves from naturally grown
# leaf edits. Preserve those edits once; new trees keep normal decay semantics.
static func restore_legacy(world: VoxelWorld) -> void:
	if int(world.adventure_state.get("wood_schema",0)) >= 1: return
	for p in world.edits:
		if int(world.edits[p]) != Nodes.LEAVES: continue
		var key: String = VoxelWorld.station_key(p)
		if not world.block_states.has(key): world.block_states[key] = {}
		world.block_states[key]["wood_persistent"] = true
	world.adventure_state["wood_schema"] = 1

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("wood_runtime"):
		world.set_meta("wood_runtime",{"leaves":{},"columns":{},"pending":[],"queued":{},"orphans":{},"retry":{},"decay":{},"head":0,"clock":0.0,"next_decay":5.0})
	return world.get_meta("wood_runtime")

static func enqueue(world: VoxelWorld, p: Vector3i) -> void:
	var data: Dictionary = runtime(world)
	if not data.leaves.has(p) or data.queued.has(p): return
	data.queued[p] = true; data.pending.append(p)

# `check` false registers the leaf without a support search. A column load uses
# that for generated leaves with no edit within reach: an untouched tree is
# whole, and only a change within six nodes can cut a leaf off from its log.
static func scan(world: VoxelWorld, p: Vector3i, id: int, check: bool = true) -> void:
	if not is_leaves(id): return
	var data: Dictionary = runtime(world)
	if data.leaves.has(p): return
	data.leaves[p] = true
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true
	if check and not persistent(world,p): enqueue(world,p)

static func around(world: VoxelWorld, p: Vector3i) -> void:
	var data: Dictionary = runtime(world)
	for dx in range(-6,7):
		for dy in range(-6+absi(dx),7-absi(dx)):
			var reach: int = 6-absi(dx)-absi(dy)
			for dz in range(-reach,reach+1):
				var q: Vector3i = p+Vector3i(dx,dy,dz)
				if data.leaves.has(q): enqueue(world,q)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, new_id: int) -> void:
	if old_id == new_id: return
	if not is_leaves(old_id) and not is_leaves(new_id) and is_log(old_id) == is_log(new_id): return
	var data: Dictionary = runtime(world)
	if is_leaves(old_id):
		data.leaves.erase(p); data.orphans.erase(p); data.retry.erase(p); data.decay.erase(p); data.queued.erase(p)
		var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
		if data.columns.has(column): data.columns[column].erase(p)
		var key: String = VoxelWorld.station_key(p)
		if world.block_states.has(key):
			world.block_states[key].erase("wood_persistent"); world.block_states[key].erase("wood_orphan")
			if world.block_states[key].is_empty(): world.block_states.erase(key)
	scan(world,p,new_id)
	if is_log(old_id) != is_log(new_id) or is_leaves(old_id): around(world,p)

static func mark_placed(world: VoxelWorld, p: Vector3i) -> void:
	if not is_leaves(world.node_at(p)): return
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	world.block_states[key]["wood_persistent"] = true
	world.block_states[key].erase("wood_orphan")
	var data: Dictionary = runtime(world); data.orphans.erase(p); data.retry.erase(p); data.decay.erase(p)
	around(world,p)

# Connected leaf paths may reach any log species within six edges. Placed
# leaves carry source distance zero and never decay. Unknown columns postpone
# the decision so streaming boundaries cannot destroy a supported canopy.
static func support(world: VoxelWorld, p: Vector3i) -> int:
	if persistent(world,p): return 1
	var queue: Array = [p]; var distances: Dictionary = {p:0}; var head: int = 0; var unknown: bool = false
	while head < queue.size():
		var q: Vector3i = queue[head]; head += 1
		var distance: int = int(distances[q])+1
		if distance > 6: continue
		for side in SIDES:
			var neighbor: Vector3i = q+side
			if distances.has(neighbor): continue
			if not world.loaded_at(Vector3(neighbor)): unknown = true; continue
			var id: int = world.node_at(neighbor)
			if is_log(id): return 1
			if is_leaves(id):
				if persistent(world,neighbor): return 1
				distances[neighbor] = distance; queue.append(neighbor)
	return -1 if unknown else 0

static func check_leaf(world: VoxelWorld, p: Vector3i, decay: bool = false) -> void:
	var data: Dictionary = runtime(world)
	if not world.loaded_at(Vector3(p)) or not is_leaves(world.node_at(p)): return
	var supported: int = support(world,p)
	var key: String = VoxelWorld.station_key(p)
	if supported == 1:
		data.orphans.erase(p); data.retry.erase(p)
		if world.block_states.has(key):
			world.block_states[key].erase("wood_orphan")
			if world.block_states[key].is_empty(): world.block_states.erase(key)
	elif supported == -1: data.retry[p] = true
	else:
		data.retry.erase(p); data.orphans[p] = true
		if not world.block_states.has(key): world.block_states[key] = {}
		world.block_states[key]["wood_orphan"] = true
		if decay:
			var id: int = world.node_at(p)
			if world.set_node(p,Nodes.AIR):
				for drop in harvest(id,{}): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,drop[0],drop[1])

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("wood_runtime"): return
	var data: Dictionary = runtime(world)
	data.clock += delta
	if float(data.clock) >= float(data.next_decay):
		data.next_decay = float(data.clock)+5.0
		for p in data.orphans:
			if randi_range(1,10) == 1: data.decay[p] = true; enqueue(world,p)
		for p in data.retry: enqueue(world,p)
	var started: int = Time.get_ticks_usec(); var checked: int = 0
	while int(data.head) < data.pending.size() and checked < 16:
		var p: Vector3i = data.pending[int(data.head)]; data.head += 1; checked += 1
		if not data.queued.has(p): continue
		data.queued.erase(p)
		var decay: bool = data.decay.has(p); data.decay.erase(p)
		check_leaf(world,p,decay)
		if Time.get_ticks_usec()-started >= 1500: break
	if int(data.head) >= data.pending.size() or int(data.head) > 1024:
		data.pending = data.pending.slice(int(data.head)); data.head = 0

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("wood_runtime"): return
	var data: Dictionary = runtime(world)
	for p in data.columns.get(column,{}):
		for collection in [data.leaves,data.queued,data.orphans,data.retry,data.decay]: collection.erase(p)
	data.columns.erase(column)

static func natural_species(generator: TerrainGenerator, x: int, z: int) -> int:
	if generator.dimension != "overworld": return -1
	var region: String = generator.biome(x,z)
	if region == "Sunwash desert" or generator.terrain_height(x,z) <= TerrainGenerator.SEA+2: return -1
	if region == "Frostpine highlands": return 1
	var climate_value: float = generator.climate.get_noise_2d(x,z)
	if region in ["Swamp","Willow shores"]: return 3 if climate_value > 0.05 else 0
	if climate_value > 0.12: return 4
	var patch: int = generator.hash_at(floori(x/64.0),237,floori(z/64.0))%100
	if patch < 18: return 5
	if patch < 43: return 2
	return 0

static func natural_tree(generator: TerrainGenerator, x: int, z: int) -> Dictionary:
	if generator.hash_at(x,77,z)%105 != 0: return {}
	var kind: int = natural_species(generator,x,z)
	if kind < 0: return {}
	var h: int = generator.terrain_height(x,z)
	var giant: bool = kind == 5 or kind in [1,3] and generator.hash_at(x,92,z)%5 == 0
	if giant:
		for side in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
			if generator.terrain_height(x+side.x,z+side.y) != h:
				if kind == 5: return {}
				giant = false; break
	var plan: Dictionary = tree_plan(kind,generator.hash_at(x,79,z),giant)
	# The legacy surface generator has a fixed64-high buffer. Pick a compact
	# spruce if a large source layout would cross it; never clip a treetop.
	if h+1+int(plan.height) > generator.terrain_ceiling():
		if kind == 1: plan = tree_plan(kind,generator.hash_at(x,79,z),false,5)
		elif kind == 3: plan = tree_plan(kind,generator.hash_at(x,79,z),false)
		else: return {}
	if h+1+int(plan.height) > generator.terrain_ceiling(): return {}
	plan["origin"] = Vector3i(x,h+1,z); plan["species"] = kind
	Beehives.decorate_tree(generator,plan)
	return plan
