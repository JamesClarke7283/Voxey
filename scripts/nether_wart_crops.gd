class_name NetherWartCrops
extends RefCounted

# Mineclonia ITEMS/mcl_nether/nether_wart.lua and the registered drop resolver in
# assets/data/harvesting.json. IDs are numeric here so VillageContent can consume
# this module without a class-reference cycle.
const STAGES = [563,564,565,566]
const ITEM = 774
const SOIL = [Nodes.SOUL_SAND]
const INTERVAL = 35.0
const CHANCE = 11
const DATA = {
	563:{"name":"Premature Nether Wart (Stage 1)","color":"71362f","block":true,"shape":"crop","crop":"nether_wart","stage":0,"hidden":true,"tool":-1,"hardness":0.0,"source_node":"mcl_nether:nether_wart_0"},
	564:{"name":"Premature Nether Wart (Stage 2)","color":"8e3b38","block":true,"shape":"crop","crop":"nether_wart","stage":1,"hidden":true,"tool":-1,"hardness":0.0,"source_node":"mcl_nether:nether_wart_1"},
	565:{"name":"Premature Nether Wart (Stage 3)","color":"8e3b38","block":true,"shape":"crop","crop":"nether_wart","stage":2,"hidden":true,"tool":-1,"hardness":0.0,"source_node":"mcl_nether:nether_wart_2"},
	566:{"name":"Mature Nether Wart","color":"a84643","block":true,"shape":"crop","crop":"nether_wart","stage":3,"hidden":true,"tool":-1,"hardness":0.0,"source_node":"mcl_nether:nether_wart"},
	774:{"name":"Nether Wart","color":"a43c41","stack":64,"compostability":30,"source_node":"mcl_nether:nether_wart_item"},
}

static func is_wart(id: int) -> bool: return id >= STAGES[0] and id <= STAGES[-1]
static func stage(id: int) -> int: return STAGES.find(id)
static func mature(id: int) -> bool: return id == STAGES[-1]
static func seed_item(id: int) -> int: return ITEM if is_wart(id) else 0
static func first(id: int) -> int: return STAGES[0] if id == ITEM else 0
static func soil(id: int) -> bool: return id == Nodes.SOUL_SAND

# The source's on_place accepts any buildable_to cell above the soil. Voxey's
# shared replacement predicate is its corresponding air/snow/plant/liquid/fire set.
static func buildable_to(id: int) -> bool: return Doors.replaceable(id)

static func can_place(world: VoxelWorld, at: Vector3i) -> bool:
	var below: Vector3i = at+Vector3i.DOWN
	return world.loaded_at(Vector3(at)) and world.loaded_at(Vector3(below)) and soil(world.node_at(below)) and buildable_to(world.node_at(at))

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var world: VoxelWorld = game.world
	var held: int = int(game.inventory.held().id)
	# nether_wart.lua has no _on_bone_meal callback. Consume the interaction, not
	# the item, and never route this plant through generic crop bone-meal growth.
	if held == Nodes.BONE_MEAL and is_wart(world.node_at(target.get("pos",Vector3i.ZERO))): return true
	if held != ITEM: return false
	var at: Vector3i = SnowCover.placement(world,target).pos
	if not can_place(world,at):
		game.toast("Plant this on soul sand.")
		return true
	if world.set_node(at,STAGES[0]):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.player.eating.clear(); game.sound("place"); game.player.swing = 1
		game.api.emit_node_placed(at,STAGES[0])
	return true

static func bone_meal(_world: VoxelWorld, _p: Vector3i) -> Dictionary:
	return {"consume":false,"grew":false}

# Use the exported source definition rather than a second interpretation of its
# ordered drop table and Fortune replacement. The shared resolver also excludes
# enchanted books and leaves Silk Touch without a wart-node override.
static func harvest(id: int, slot: Dictionary = {}, random: EnchantRolls = null) -> Array:
	if not is_wart(id): return []
	var held: Dictionary = slot.duplicate()
	if not held.has("id"): held["id"] = 0
	var result: Dictionary = Harvesting.harvest(id,held,random)
	return result.get("drops",[]) if result.get("handled",false) else []

static func environmental_break(world: VoxelWorld, p: Vector3i, lava: bool = false) -> bool:
	var id: int = world.node_at(p)
	if not is_wart(id): return false
	var drops: Array = [] if lava else harvest(id)
	if not world.set_node(p,Nodes.AIR): return false
	for entry in drops: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	return true

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	return environmental_break(world,p)

# Every stage has both dig_by_piston=1 and unsticky=1 in the source.
static func unsticky(id: int) -> bool: return is_wart(id)

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	return world.loaded_at(Vector3(below)) and soil(world.node_at(below))

# One source ABM step advances exactly one node. There is deliberately no light,
# dimension, biome, day-time, moisture, or bone-meal condition here.
static func grow(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	var current: int = stage(id)
	if current < 0 or current >= STAGES.size()-1 or not supported(world,p): return false
	return world.set_node(p,STAGES[current+1])

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("nether_wart_crops"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+563566
		world.set_meta("nether_wart_crops",{"cells":{},"columns":{},"clock":0.0,"rng":rng})
	return world.get_meta("nether_wart_crops")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("nether_wart_crops"): world.remove_meta("nether_wart_crops")

static func registered(world: VoxelWorld, p: Vector3i, _on_load: bool = false) -> void:
	var id: int = world.node_at(p)
	if not is_wart(id) or not world.loaded_at(Vector3(p)): return
	# Old saves used the simplified 30-second `world.growth` ladder. The source
	# ABM has no per-node elapsed timer to restore, so discard that legacy entry.
	world.growth.erase(p)
	var state: Dictionary = runtime(world); state.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("nether_wart_crops"): return
	var state: Dictionary = runtime(world); state.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("nether_wart_crops"): return
	var state: Dictionary = runtime(world)
	for p in state.columns.get(column,{}).keys(): forget(world,p)

static func refresh(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	if is_wart(world.node_at(p)) and world.loaded_at(Vector3(p+Vector3i.DOWN)) and not supported(world,p): environmental_break(world,p)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("nether_wart_crops"): return
	# Snapshot keys because an unsupported loaded edit can remove its own entry.
	for p in runtime(world).columns.get(column,{}).keys(): refresh(world,p)

static func changed(world: VoxelWorld, p: Vector3i, old: int, id: int) -> void:
	if is_wart(old) or is_wart(id): world.growth.erase(p)
	if is_wart(old) and not is_wart(id): forget(world,p)
	if is_wart(id): registered(world,p)
	refresh(world,p); refresh(world,p+Vector3i.UP)

# Loaded-column ABM scheduling: a 35-second interval and an independent 1/11
# roll for each immature plant. Unloaded columns do not accrue catch-up work.
static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("nether_wart_crops"): return
	var state: Dictionary = runtime(world)
	state.clock = float(state.clock)+maxf(0.0,delta)
	if state.clock < INTERVAL: return
	state.clock = fmod(state.clock,INTERVAL)
	var rng: RandomNumberGenerator = state.rng
	for p in state.cells.keys():
		var id: int = world.node_at(p)
		if not is_wart(id): forget(world,p); continue
		state.cells[p] = id
		if not mature(id) and world.loaded_at(Vector3(p)) and rng.randi_range(1,CHANCE) == 1: grow(world,p)

# Source fixed selection boxes, converted from centered coordinates to Voxey's
# lower-corner AABBs: 6/16, 0.65 and 0.95 high. They are selection-only; the
# existing crop shape supplies walkable=false / empty collision boxes.
static func boxes(id: int) -> Array:
	if not is_wart(id): return []
	var height: float = [0.375,0.65,0.65,0.95][stage(id)]
	return [AABB(Vector3.ZERO,Vector3(1.0,height,1.0))]

# Original crossed-plant geometry using each saved stage's atlas tile. Stages 2
# and 3 intentionally have the same pixels, as in the source.
static func mesh(out: Array, at: Vector3, id: int) -> void:
	if not is_wart(id): return
	var h: float = boxes(id)[0].size.y
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for flip in 2:
		var vertices: Array = [at+Vector3(0.08,0,0.08),at+Vector3(0.92,0,0.92),at+Vector3(0.92,h,0.92),at+Vector3(0.08,h,0.08)] if flip == 0 else [at+Vector3(0.08,0,0.92),at+Vector3(0.92,0,0.08),at+Vector3(0.92,h,0.08),at+Vector3(0.08,h,0.92)]
		var tile: int = Nodes.tile(id,0)
		BlockMesher._quad(out,vertices,uv,Vector3.UP,tile,Color.WHITE,false)
		BlockMesher._quad(out,vertices,uv,Vector3.UP,tile,Color.WHITE,true)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_wart(id): return noise
	var visual_stage: int = [0,1,1,2][stage(id)]
	var top: int = [11,7,7,2][visual_stage]
	if y < top: return Color.TRANSPARENT
	var centers: Array = [[8],[5,11],[5,11],[3,8,13]][visual_stage]
	var stem: bool = false
	for center in centers:
		if absi(x-int(center)) <= (0 if visual_stage == 0 else 1): stem = true
	if not stem and visual_stage > 0 and y >= top+2 and (x+y)%3 != 0: stem = true
	if not stem: return Color.TRANSPARENT
	if y <= top+2 and visual_stage > 0: return Color("c25a50") if (x+y)%2 == 0 else Color("963b3b")
	return Color("7f302f") if (x*3+y)%5 < 2 else Color("ad4641")

# Original 16x16 inventory sprite for item 774.
static func draw(img: Image, id: int) -> void:
	if id != ITEM: return
	ItemArt._line(img,Vector2(4,14),Vector2(6,7),Color("71302f"),2)
	ItemArt._line(img,Vector2(11,14),Vector2(10,6),Color("71302f"),2)
	ItemArt._polygon(img,[[2,8],[3,4],[6,2],[9,5],[8,9],[5,11]],Color("a94342"))
	ItemArt._polygon(img,[[8,7],[10,3],[13,4],[15,8],[12,11],[9,10]],Color("bd5049"))
	ItemArt._line(img,Vector2(4,5),Vector2(6,4),Color("db7462"),1)
	ItemArt._line(img,Vector2(11,5),Vector2(13,7),Color("df7864"),1)
