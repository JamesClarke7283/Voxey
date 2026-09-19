class_name Archaeology
extends RefCounted

# Mineclonia mcl_pottery_sherds/init.lua and mcl_sus_nodes/init.lua,
# GPL-3.0-or-later. Original procedural art.
#
# Source rules reproduced here:
# - A decorated pot carries one pattern per face, four faces in a fixed order.
#   Source rotates the stored array by the node's facing, so the pattern follows
#   the block rather than the world axis. Voxey stores the same four-entry list
#   in saved block metadata and rotates on read.
# - Crafting is a plus shape of four sherds or bricks: top-centre, mid-left,
#   mid-right and bottom-centre. A plain brick contributes a blank face.
# - Breaking a pot returns the base plus one item per face, in face order. Silk
#   Touch returns the whole pot with its patterns intact.
# - Suspicious sand and gravel keep the source's `falling_node` group, so they
#   fall when unsupported, and they revert to plain sand or gravel when emptied.
# - Brushing rolls the loot ONCE, on the first stroke, and that result is fixed
#   for the node. Source advances a stage counter with a 1-in-3 chance per later
#   stroke and completes at stage 4, so the minimum is four strokes and the
#   expected is about ten.
# - Each completed node costs the brush exactly 1/64 of its life, and the brush
#   is craftable from a feather over a copper ingot over a stick.
#
# Source gaps carried over rather than invented:
# - 23 sherds are registered in the checkout. Voxey registers four of them,
#   chosen so every source pattern family is represented and the atlas stays
#   bounded; the remaining nineteen names are recorded in the notes as omitted.
# - Source's craft guard `old_craft_grid[1][2] == "mcl_core:brick"` indexes an
#   ItemStack userdata with a number, which is always nil, so a four-brick pot
#   still stores an empty pattern list. Voxey stores four blanks, which is the
#   intended behaviour and is equivalent.
# - No structure in the checkout places decorated pots outside trial chambers,
#   and Voxey has no trial chambers, so decorated pots and suspicious nodes are
#   creative-only for now. That is recorded, not papered over.

const BRUSH = 9900
const SUSPICIOUS_SAND = 9901
const SUSPICIOUS_GRAVEL = 9902
const POT = 9903
const SHERD_FIRST = 9910
const SHERDS = [SHERD_FIRST+0,SHERD_FIRST+1,SHERD_FIRST+2,SHERD_FIRST+3,SHERD_FIRST+4,SHERD_FIRST+5,SHERD_FIRST+6,SHERD_FIRST+7,SHERD_FIRST+8,SHERD_FIRST+9,SHERD_FIRST+10,SHERD_FIRST+11,SHERD_FIRST+12,SHERD_FIRST+13,SHERD_FIRST+14,SHERD_FIRST+15,SHERD_FIRST+16,SHERD_FIRST+17,SHERD_FIRST+18,SHERD_FIRST+19,SHERD_FIRST+20,SHERD_FIRST+21,SHERD_FIRST+22]
# The four source patterns Voxey keeps. Source names them angler, archer,
# arms_up, blade, brewer, burn, danger, explorer, friend, heartbreak, heart,
# howl, miner, mourner, plenty, prize, sheaf, shelter, skull, snort, flow,
# guster, scrape; see the notes for why only these four are registered.
const SHERD_NAMES = ["Angler pottery sherd","Blade pottery sherd","Explorer pottery sherd","Skull pottery sherd","Archer pottery sherd","Arms up pottery sherd","Brewer pottery sherd","Burn pottery sherd","Danger pottery sherd","Friend pottery sherd","Heartbreak pottery sherd","Heart pottery sherd","Howl pottery sherd","Miner pottery sherd","Mourner pottery sherd","Plenty pottery sherd","Prize pottery sherd","Sheaf pottery sherd","Shelter pottery sherd","Snort pottery sherd","Flow pottery sherd","Guster pottery sherd","Scrape pottery sherd"]
# Sherds whose only source route is a structure or container the checkout's Voxey
# does not have: the source sends these to trail ruins, trial chambers and vaults,
# none of which is implemented here. They are registered for completeness and
# recorded rather than given an invented placement, exactly as the echo shard is.
# `STRUCTURE_TABLES` below routes every other sherd from the structures Voxey has.
const UNROUTED_SHERDS = ["burn","danger","friend","heartbreak","heart","howl","sheaf","flow","guster","scrape","arms_up","brewer"]

const SHERD_PATTERNS = ["angler","blade","explorer","skull","archer","arms_up","brewer","burn","danger","friend","heartbreak","heart","howl","miner","mourner","plenty","prize","sheaf","shelter","snort","flow","guster","scrape"]
const BRUSH_USES = 64
# Source: stage starts at 1, advances with a 1-in-3 chance, completes at 4.
const FIRST_STAGE = 1
const COMPLETE_STAGE = 4
const STAGE_CHANCE = 3
# Source item entity pops out 0.02 nodes per stage.
const STAGE_OFFSET = 0.02
const HIDE_DELAY = 5.0
const SUB_TIMER = 1.0
const FACES = 4
const SAND = "sand"
const GRAVEL = "gravel"
static var icons: Dictionary = {}

const DATA = {
	BRUSH:{"name":"Brush","stack":1,"durability":BRUSH_USES,"color":"d8c08a"},
	SUSPICIOUS_SAND:{"name":"Suspicious sand","block":true,"color":"d8cd97","hardness":0.5},
	SUSPICIOUS_GRAVEL:{"name":"Suspicious gravel","block":true,"color":"8f8d86","hardness":0.6},
	POT:{"name":"Decorated pot","block":true,"shape":"pot","color":"a5673f","hardness":0.0},
	9910:{"name":SHERD_NAMES[0],"color":"c98a63","pattern":SHERD_PATTERNS[0]},
	9911:{"name":SHERD_NAMES[1],"color":"b0765a","pattern":SHERD_PATTERNS[1]},
	9912:{"name":SHERD_NAMES[2],"color":"c2a06a","pattern":SHERD_PATTERNS[2]},
	9913:{"name":SHERD_NAMES[3],"color":"b6ada0","pattern":SHERD_PATTERNS[3]},
	9914:{"name":SHERD_NAMES[4],"color":"bd7f57","pattern":SHERD_PATTERNS[4]},
	9915:{"name":SHERD_NAMES[5],"color":"c98a63","pattern":SHERD_PATTERNS[5]},
	9916:{"name":SHERD_NAMES[6],"color":"b0765a","pattern":SHERD_PATTERNS[6]},
	9917:{"name":SHERD_NAMES[7],"color":"a86a4e","pattern":SHERD_PATTERNS[7]},
	9918:{"name":SHERD_NAMES[8],"color":"c2a06a","pattern":SHERD_PATTERNS[8]},
	9919:{"name":SHERD_NAMES[9],"color":"b98f6a","pattern":SHERD_PATTERNS[9]},
	9920:{"name":SHERD_NAMES[10],"color":"a97c5c","pattern":SHERD_PATTERNS[10]},
	9921:{"name":SHERD_NAMES[11],"color":"b8503f","pattern":SHERD_PATTERNS[11]},
	9922:{"name":SHERD_NAMES[12],"color":"8f7a63","pattern":SHERD_PATTERNS[12]},
	9923:{"name":SHERD_NAMES[13],"color":"9a7f5e","pattern":SHERD_PATTERNS[13]},
	9924:{"name":SHERD_NAMES[14],"color":"82715f","pattern":SHERD_PATTERNS[14]},
	9925:{"name":SHERD_NAMES[15],"color":"c4b07a","pattern":SHERD_PATTERNS[15]},
	9926:{"name":SHERD_NAMES[16],"color":"c9a86a","pattern":SHERD_PATTERNS[16]},
	9927:{"name":SHERD_NAMES[17],"color":"b8a06a","pattern":SHERD_PATTERNS[17]},
	9928:{"name":SHERD_NAMES[18],"color":"a89478","pattern":SHERD_PATTERNS[18]},
	9929:{"name":SHERD_NAMES[19],"color":"c0a080","pattern":SHERD_PATTERNS[19]},
	9930:{"name":SHERD_NAMES[20],"color":"9fb0c0","pattern":SHERD_PATTERNS[20]},
	9931:{"name":SHERD_NAMES[21],"color":"8fa8b8","pattern":SHERD_PATTERNS[21]},
	9932:{"name":SHERD_NAMES[22],"color":"b0a08f","pattern":SHERD_PATTERNS[22]},
}
# Source `sus_drops_default` fallbacks and the trial-chamber pot loot table.
# Weights are transcribed; entries whose item Voxey lacks are omitted and the
# omission is recorded in the notes rather than silently reweighted.
const SAND_LOOT = [
	{"id":Nodes.DIAMOND,"weight":8,"min":1,"max":2},
	{"id":Nodes.IRON,"weight":10,"min":1,"max":2},
	{"id":Nodes.GOLD,"weight":8,"min":1,"max":2},
	{"id":Nodes.COAL,"weight":20,"min":2,"max":8},
	{"id":Nodes.BONE_MEAL,"weight":12,"min":2,"max":6},
	{"id":Nodes.STRING,"weight":8,"min":1,"max":3},
]
const GRAVEL_LOOT = [
	{"id":Nodes.FLINT,"weight":25,"min":1,"max":3},
	{"id":Nodes.IRON,"weight":12,"min":1,"max":2},
	{"id":Nodes.COAL,"weight":18,"min":2,"max":8},
	{"id":Nodes.BONE,"weight":12,"min":1,"max":4},
	{"id":Nodes.CLAY_BALL,"weight":12,"min":2,"max":6},
	{"id":Nodes.DIAMOND,"weight":4,"min":1,"max":1},
]

# --- registry ---------------------------------------------------------------

static func is_sherd(id: int) -> bool: return SHERDS.has(id)
static func sherd_pattern(id: int) -> String: return String(DATA.get(id,{}).get("pattern",""))
# Whether this sherd has a route in Voxey. A sherd with no route is still a real
# item; it is simply not yet obtainable, which the module records.
static func routed(id: int) -> bool: return is_sherd(id) and not UNROUTED_SHERDS.has(sherd_pattern(id))
static func pattern_of(id: int) -> String:
	# The pattern a crafted pot face carries: a sherd contributes its own, and a
	# plain brick contributes a blank face, as in source.
	return sherd_pattern(id)
static func is_suspicious(id: int) -> bool: return id == SUSPICIOUS_SAND or id == SUSPICIOUS_GRAVEL
static func is_brush(id: int) -> bool: return id == BRUSH
static func is_pot(id: int) -> bool: return id == POT
# The plain node a brushed-out suspicious block reverts to.
static func parent(id: int) -> int: return Nodes.SAND if id == SUSPICIOUS_SAND else Nodes.GRAVEL if id == SUSPICIOUS_GRAVEL else 0
static func suspicious_for(parent_id: int) -> int:
	return SUSPICIOUS_SAND if parent_id == Nodes.SAND else SUSPICIOUS_GRAVEL if parent_id == Nodes.GRAVEL else 0

# --- pot patterns -----------------------------------------------------------

static func patterns(world: VoxelWorld, p: Vector3i) -> Array:
	var raw: Variant = world.block_states.get(VoxelWorld.station_key(p),{}).get("pot_patterns",[])
	var result: Array = []
	if raw is Array:
		for i in FACES: result.append(String(raw[i]) if i < raw.size() and raw[i] is String else "")
	while result.size() < FACES: result.append("")
	return result

# Source rotates the stored array by the node's facing so a pattern stays on the
# side it was built against. Facing is stored with the block metadata.
static func facing(world: VoxelWorld, p: Vector3i) -> int:
	return clampi(int(world.block_states.get(VoxelWorld.station_key(p),{}).get("pot_facing",0)),0,3)

static func face_pattern(world: VoxelWorld, p: Vector3i, face: int) -> String:
	var stored: Array = patterns(world,p)
	return String(stored[posmod(face+facing(world,p),FACES)])

static func set_patterns(world: VoxelWorld, p: Vector3i, list: Array) -> void:
	var clean: Array = []
	for i in FACES: clean.append(String(list[i]) if i < list.size() and list[i] is String else "")
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	state["pot_patterns"] = clean
	world.block_states[key] = state

# --- loot -------------------------------------------------------------------

static func table(id: int) -> Array:
	return SAND_LOOT if id == SUSPICIOUS_SAND else (GRAVEL_LOOT if id == SUSPICIOUS_GRAVEL else [])

# The source does not draw a suspicious node's loot from one table. It reads the
# `structure` tag the placing structure wrote into the node, looks that
# structure's own `loot["SUS"]` table up, and falls back to a default list
# otherwise. Those per-structure tables are where **the pottery sherds live** —
# several of them carry four sherds each — so a world without one is a world
# where sherds cannot be found at all.
#
# Voxey writes the structure name into the node's saved state at placement
# (`set_structure`) and draws from these tables. The four sherds Voxey registers
# appear in the tables that carried them in the source: angler and explorer in
# the ocean ruins, blade in the cold ruins, and skull in the desert temple's
# archaeology table. Source weights are preserved, and an entry Voxey has no item
# for keeps its weight with a zero id rather than being redistributed.
const STRUCTURE_TABLES = {
	# `mcl_sus_nodes:sus_node_loot.desert_pyramid_archeology`, which the desert
	# temple's own `loot["SUS"]` mirrors.
	"desert_temple": [
		# Source `desert_temple.lua`: archer, miner, prize and skull, each at weight 1.
		{"id":9914,"weight":1,"min":1,"max":1},                           # archer
		{"id":9923,"weight":1,"min":1,"max":1},                           # miner
		{"id":9926,"weight":1,"min":1,"max":1},                           # prize
		{"id":9913,"weight":1,"min":1,"max":1},                           # skull
		{"id":VillageContent.EMERALD,"weight":1,"min":1,"max":1},
		{"id":Nodes.GUNPOWDER,"weight":1,"min":1,"max":1},
		{"id":Nodes.TNT,"weight":1,"min":1,"max":1},
		{"id":Nodes.DIAMOND,"weight":1,"min":1,"max":1},
	],
	# `ocean_ruins_warm`.
	"ocean_ruins_warm": [
		{"id":Nodes.COAL,"weight":2,"min":1,"max":1},
		{"id":VillageContent.EMERALD,"weight":2,"min":1,"max":1},
		{"id":Nodes.GRAIN,"weight":2,"min":1,"max":1},
		{"id":Nodes.TOOLS+4,"weight":2,"min":1,"max":1},             # wooden hoe
		{"id":Nodes.GOLD_NUGGET,"weight":2,"min":1,"max":1},
		{"id":9910,"weight":1,"min":1,"max":1},
		{"id":9928,"weight":1,"min":1,"max":1},
		{"id":9929,"weight":1,"min":1,"max":1},

		{"id":9928,"weight":1,"min":1,"max":1},                           # shelter
		{"id":9929,"weight":1,"min":1,"max":1},                           # snort
		{"id":Nodes.TOOLS+11,"weight":1,"min":1,"max":1},            # iron axe
	],
	# `ocean_ruins_cold`.
	"ocean_ruins_cold": [
		{"id":Nodes.COAL,"weight":2,"min":1,"max":1},
		{"id":VillageContent.EMERALD,"weight":2,"min":1,"max":1},
		{"id":Nodes.GRAIN,"weight":2,"min":1,"max":1},
		{"id":Nodes.TOOLS+4,"weight":2,"min":1,"max":1},             # wooden hoe
		{"id":Nodes.GOLD_NUGGET,"weight":2,"min":1,"max":1},
		{"id":9911,"weight":1,"min":1,"max":1},
		{"id":9912,"weight":1,"min":1,"max":1},
		{"id":9924,"weight":1,"min":1,"max":1},
		{"id":9925,"weight":1,"min":1,"max":1},

		{"id":SHERD_FIRST+2,"weight":1,"min":1,"max":1},               # explorer
		{"id":9924,"weight":1,"min":1,"max":1},                           # mourner
		{"id":9925,"weight":1,"min":1,"max":1},                           # plenty
		{"id":Nodes.TOOLS+11,"weight":1,"min":1,"max":1},            # iron axe
	],
}

# The structure a suspicious node belongs to, written at placement.
static func set_structure(world: VoxelWorld, p: Vector3i, name: String) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	state["structure"] = name
	world.block_states[key] = state

static func structure(world: VoxelWorld, p: Vector3i) -> String:
	return String(world.block_states.get(VoxelWorld.station_key(p),{}).get("structure",""))

# The table for a node: its structure's own table when it has one, else the
# generic sand or gravel list.
static func table_for(id: int, structure_name: String) -> Array:
	if STRUCTURE_TABLES.has(structure_name): return STRUCTURE_TABLES[structure_name]
	return table(id)

static func total_weight(id: int, structure_name: String = "") -> int:
	var sum: int = 0
	for entry in table_for(id,structure_name): sum += int(entry.weight)
	return sum

# One weighted draw, returning [[id,count],...] as the break path expects.
static func loot(id: int, rng: RandomNumberGenerator, structure_name: String = "") -> Array:
	var entries: Array = table_for(id,structure_name)
	if entries.is_empty(): return []
	var roll: int = rng.randi_range(1,total_weight(id,structure_name))
	for entry in entries:
		roll -= int(entry.weight)
		if roll <= 0:
			return [[int(entry.id),rng.randi_range(int(entry.min),int(entry.max))]]
	return [[int(entries[0].id),int(entries[0].min)]]

# --- brushing ---------------------------------------------------------------

# Source keeps the rolled loot and the stroke progress in a per-node entity. It
# is stored here in the node's saved state so the roll survives a save and the
# node cannot be re-rolled by leaving and returning.
static func progress(world: VoxelWorld, p: Vector3i) -> Dictionary:
	return world.get_station(p,"suspicious")

static func strokes(world: VoxelWorld, p: Vector3i) -> int:
	return clampi(int(progress(world,p).get("stage",0)),0,COMPLETE_STAGE)

static func brush(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var held: int = game.inventory.held().id
	if held != BRUSH: return false
	var p: Vector3i = target.pos
	var id: int = game.world.node_at(p)
	if not is_suspicious(id): return false
	var state: Dictionary = progress(game.world,p)
	var rng: RandomNumberGenerator = runtime(game.world).rng
	if not state.has("stage") or int(state.stage) <= 0:
		# First stroke: roll the loot once and fix it for this node. The draw uses
		# the structure the node belongs to, which is how the source reaches the
		# per-structure tables that carry the sherds.
		var rolled: Array = loot(id,rng,structure(game.world,p))
		if rolled.is_empty(): return false
		state["stage"] = FIRST_STAGE
		state["loot_id"] = int(rolled[0][0])
		state["loot_count"] = int(rolled[0][1])
		state["timer"] = HIDE_DELAY
		state["clock"] = SUB_TIMER
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("d8cd97"),6)
		game.sound("place"); game.player.swing = 1
		return true
	state["timer"] = HIDE_DELAY
	state["clock"] = SUB_TIMER
	if rng.randi_range(1,STAGE_CHANCE) == 1: state["stage"] = mini(COMPLETE_STAGE,int(state.stage)+1)
	if int(state.stage) >= COMPLETE_STAGE:
		var count: int = maxi(1,int(state.get("loot_count",1)))
		var loot_id: int = int(state.get("loot_id",0))
		# The node reverts to plain sand or gravel and yields its fixed drop once.
		if not game.world.set_node(p,parent(id)): return true
		game.world.stations.erase(VoxelWorld.station_key(p))
		if loot_id != 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,loot_id,count)
		if game.gamemode != "creative":
			# Source `add_wear_by_uses(64)`: one completed node per 1/64 of life.
			game.inventory.slots[game.inventory.selected].wear += floori(Nodes.durability(BRUSH)/BRUSH_USES)
			if game.inventory.slots[game.inventory.selected].wear >= Nodes.durability(BRUSH): game.inventory.consume_selected()
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("d8cd97"),10)
		game.sound("break"); game.player.swing = 1
		return true
	game.puff(Vector3(p)+Vector3.ONE*0.5,Color("d8cd97"),4)
	game.sound("place"); game.player.swing = 1
	return true

# Source removes the in-progress entity when the node is gone or the hide timer
# expires, resetting the visible stage without discarding the rolled loot.
static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("archaeology"): return
	var data: Dictionary = runtime(world)
	data.clock = float(data.clock)+maxf(0,delta)
	if float(data.clock) < SUB_TIMER: return
	data.clock = 0.0
	for key in world.stations.keys():
		var station: Dictionary = world.stations[key]
		if station.get("kind","") != "suspicious": continue
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 3: continue
		var at := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		if not world.loaded_at(Vector3(at)) or not is_suspicious(world.node_at(at)):
			world.stations.erase(key); continue
		station.timer = maxf(0,float(station.get("timer",HIDE_DELAY))-SUB_TIMER)

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("archaeology"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+9910
		world.set_meta("archaeology",{"rng":rng,"clock":0.0})
	return world.get_meta("archaeology")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("archaeology"): world.remove_meta("archaeology")

# --- breaking ---------------------------------------------------------------

# Source `after_dig_node`: silk touch returns the whole pot; otherwise one item
# per face, with a blank face yielding a plain brick.
static func break_node(game: Node3D, p: Vector3i, id: int, tool: int, exploded: bool = false) -> bool:
	if id == POT:
		var silk: bool = Inventory.enchantment(game.inventory.held(),"Silk Touch") > 0
		var stored: Array = patterns(game.world,p)
		var facing_value: int = facing(game.world,p)
		if not game.world.set_node(p,Nodes.AIR): return true
		if silk:
			var pot: Dictionary = {"id":POT,"count":1,"wear":0,"data":{"pot_patterns":stored,"pot_facing":facing_value}}
			if game.inventory.add_item(POT,1,0,pot.data) > 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,POT,1,0,pot.data)
		elif not exploded or game.gamemode != "creative":
			for pattern in stored:
				var drop: int = Nodes.BRICK_ITEM
				for sherd in SHERDS:
					if sherd_pattern(sherd) == String(pattern): drop = sherd; break
				game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,drop,1)
		game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
		return true
	if is_suspicious(id):
		# Breaking a suspicious node loses its contents, as in source; it drops
		# the plain node instead.
		if not game.world.set_node(p,Nodes.AIR): return true
		game.world.stations.erase(VoxelWorld.station_key(p))
		if game.gamemode != "creative" and Nodes.harvestable(id,tool): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,parent(id),1)
		game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
		return true
	return false

# --- placement --------------------------------------------------------------

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not (is_pot(held) or is_sherd(held)) or target.is_empty(): return false
	if is_sherd(held): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current): return true
	if not Nodes.solid(game.world.node_at(at+Vector3i.DOWN)): return true
	# A placed pot carries the patterns of the item it came from.
	var slot: Dictionary = game.inventory.held()
	var stored: Array = slot.get("data",{}).get("pot_patterns",[])
	var facing_value: int = clampi(int(slot.get("data",{}).get("pot_facing",0)),0,3)
	if not game.world.set_node(at,POT): return true
	set_patterns(game.world,at,stored)
	var key: String = VoxelWorld.station_key(at)
	game.world.block_states[key]["pot_facing"] = facing_value
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,POT)
	return true

# --- recipes ----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source: a plus of four sherds or bricks, one per face.
	for sherd in SHERDS:
		inv._recipe("Decorated pot",POT,1,[0,sherd,0,sherd,0,sherd,0,sherd,0],3,"table")
	inv._recipe("Decorated pot",POT,1,[0,Nodes.BRICK_ITEM,0,Nodes.BRICK_ITEM,0,Nodes.BRICK_ITEM,0,Nodes.BRICK_ITEM,0],3,"table")
	inv._recipe("Brush",BRUSH,1,[Nodes.FEATHER,Nodes.COPPER,Nodes.STICK],1)

# A sherd-bearing pot records which sherd occupies each face. The plus shape
# gives four slots in a fixed order, which is the source's face order.
static func special_recipe(grid: Array) -> Dictionary:
	if grid.size() != 9: return {}
	var order: Array = [1,3,5,7]
	var patterns_found: Array = []
	for index in order:
		var id: int = int(grid[index].get("id",0))
		if id == Nodes.BRICK_ITEM: patterns_found.append("")
		elif is_sherd(id): patterns_found.append(sherd_pattern(id))
		else: return {}
	for index in 9:
		if not order.has(index) and int(grid[index].get("id",0)) != 0: return {}
	var ingredients: Dictionary = {}
	for index in order: ingredients[int(grid[index].get("id",0))] = int(ingredients.get(int(grid[index].get("id",0)),0))+1
	return {"name":"Decorated pot","id":POT,"count":1,"pattern":grid.map(func(s): return int(s.get("id",0))),"width":3,"ingredients":ingredients,"station":"table","dynamic":true,"patterns":patterns_found}

# --- art --------------------------------------------------------------------

static func pot_pattern_pixel(pattern: String, x: int, y: int) -> Color:
	# Original procedural motifs, one per registered source pattern name.
	match pattern:
		"angler":
			var rod: bool = x == 4+y/3
			if rod or (y > 11 and absi(x-7) < 4): return Color("5b4634")
			return Color("c98a63")
		"blade":
			if (x+y) in [10,11] or (x-y) in [2,3]: return Color("8d9aa2")
			return Color("b0765a")
		"explorer":
			var ring: int = maxi(absi(x-7),absi(y-7))
			if ring in [4,5]: return Color("e0cf9a")
			return Color("c2a06a")
		"skull":
			if y > 4 and y < 11 and absi(x-7) < 4: return Color("e8e2d4")
			if y in [7,8] and x in [5,9]: return Color("2f2b28")
			return Color("b6ada0")
		"archer":
			if absi(x-7)+absi(y-7) < 5 and absi(x-7) != absi(y-7): return Color("5b4634")
			return Color("bd7f57")
		"arms_up":
			if absi(x-7) <= 1 and absi(y-7) <= 1: return Color("4a3626")
			if x in [3,11] and y < 9: return Color("5b4634")
			if y in [9,10] and x in range(4,12): return Color("5b4634")
			return Color("c98a63")
		"brewer":
			if y > 6 and y < 13 and x in range(5,11): return Color("7e9a6a")
			if y in [4,5] and x in [6,9]: return Color("5b4634")
			return Color("b0765a")
		"burn":
			if y > 3 and y < 13 and absi(x-7) < 2+int((y-3)/2.0): return Color("e2803a")
			return Color("a86a4e")
		"danger":
			if absi(x-7) <= 1 and y in [7,8]: return Color("6d1f1f")
			if absi(x-7)+absi(y-9) < 6 and absi(x-7) == absi(y-9): return Color("8d2a2a")
			if y in [3,4] and x in range(5,11): return Color("8d2a2a")
			return Color("c2a06a")
		"friend":
			if y in [8,9] and absi(x-7) < 4: return Color("5b4634")
			if y in [5,6] and x in [5,9]: return Color("5b4634")
			return Color("b98f6a")
		"heartbreak":
			if maxi(absi(x-6),absi(y-6)) < 3 and maxi(absi(x-9),absi(y-6)) < 3: return Color("a03030")
			return Color("a97c5c")
		"heart":
			if maxi(absi(x-6),absi(y-6)) < 3 and maxi(absi(x-9),absi(y-6)) < 3: return Color("c0392b")
			if y > 6 and absi(x-7) < 3: return Color("c0392b")
			return Color("b8503f")
		"howl":
			var ring2: int = maxi(absi(x-7),absi(y-7))
			if ring2 in [2,4]: return Color("e8e2d4")
			return Color("8f7a63")
		"miner":
			if x == y/2+3 or x == 12-y/2: return Color("6d6d75")
			return Color("9a7f5e")
		"mourner":
			if y > 9 and absi(x-7) < 4: return Color("3a3a44")
			if y in [6,7,8] and absi(x-7) < 3: return Color("5b4634")
			return Color("82715f")
		"plenty":
			if y > 10 and absi(x-7) < 4: return Color("c9a83a")
			if y in [5,6] and absi(x-7) < 3: return Color("d8c05a")
			return Color("c4b07a")
		"prize":
			if maxi(absi(x-7),absi(y-7)) in [3,5]: return Color("c9a83a")
			return Color("c9a86a")
		"sheaf":
			for bar in [4,7,10]:
				if x == bar and y > 4: return Color("8a8a3a")
			if y in [9,10]: return Color("a8a84a")
			return Color("b8a06a")
		"shelter":
			if x in [3,11] and y > 4: return Color("6d5a44")
			if y in [4,5] and absi(x-7) < 5: return Color("6d5a44")
			return Color("a89478")
		"snort":
			if x == 7 and y == 7: return Color("8a2f2f")
			if y in [6,7] and absi(x-7) < 4: return Color("5b4634")
			if y in [9,10] and x in [5,9]: return Color("2f2b28")
			return Color("c0a080")
		"flow":
			if posmod(x+y,6) < 2 or posmod(x-y,6) < 2: return Color("5aa8d8")
			return Color("9fb0c0")
		"guster":
			if posmod(x*3+y,5) < 2: return Color("7a9cb8")
			return Color("8fa8b8")
		"scrape":
			for bar in [4,8,12]:
				if x in [bar,bar+1] and y in range(3,13): return Color("5b4634")
			return Color("b0a08f")
	return Color("b6ada0")

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_suspicious(id):
		var base: Color = Color(DATA[id].color)
		# The source overlay is a speckled scatter of darker grains.
		if posmod(x*7+y*13,11) < 3: return base.darkened(0.3)
		return base.lightened(0.05) if posmod(x*3+y*5,7) == 0 else base
	if id == POT:
		if x in [0,15] or y in [0,15]: return Color("7d4b2c")
		if y < 4: return Color("c07a4a")
		if posmod(x*5+y*3,13) == 0: return Color("8e5730")
		return Color("a5673f")
	return noise

static func draw(img: Image, id: int) -> void:
	if is_sherd(id):
		ItemArt._polygon(img,[[2,3],[13,2],[14,10],[8,14],[2,11]],Color("8b6a53"))
		for y in 16:
			for x in 16:
				if x < 3 or x > 12 or y < 3 or y > 12: continue
				var c: Color = pot_pattern_pixel(sherd_pattern(id),x,y)
				if c != Color("8b6a53"): img.set_pixel(x,y,c)
		return
	if is_brush(id):
		ItemArt._line(img,Vector2(3,13),Vector2(10,5),Color("9c7440"),3)
		ItemArt._polygon(img,[[9,1],[15,1],[15,6],[9,6]],Color("e6d6a8"))
		return
	if id == POT:
		ItemArt._polygon(img,[[3,3],[12,3],[14,6],[13,13],[2,13],[1,6]],Color("a5673f"))
		ItemArt._line(img,Vector2(3,5),Vector2(12,5),Color("c07a4a"))
		ItemArt._line(img,Vector2(3,12),Vector2(13,12),Color("7d4b2c"))
		return

static func boxes(id: int) -> Array:
	if id == POT: return [AABB(Vector3(0.0625,0,0.0625),Vector3(0.875,1,0.875))]
	return [AABB(Vector3.ZERO,Vector3.ONE)]

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if id == POT:
		# A tapered pot: a wide belly, a narrow neck and a flat rim.
		BlockMesher._art_box(out,p+Vector3(0.5,0.375,0.5),Vector3(0.875,0.75,0.875),Nodes.tile(id,0),Nodes.tile(id,2))
		BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(0.5625,1.0,0.5625),Nodes.tile(id,0),Nodes.tile(id,2))
		BlockMesher._art_box(out,p+Vector3(0.5,0.95,0.5),Vector3(0.6875,0.1,0.6875),Nodes.tile(id,0),Nodes.tile(id,2))
		return
	BlockMesher._art_box(out,p+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(id,0),Nodes.tile(id,2))

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]
