class_name CocoaCrops
extends RefCounted

# Mineclonia ITEMS/mcl_cocoas/init.lua. IDs are literal so VillageContent can
# consume DATA without introducing a class-reference cycle.
const STAGE_1 = 687
const STAGE_2 = 698
const STAGE_3 = 688
const BEANS = 816
const JUNGLE_LOG = 6096
const STAGES = [STAGE_1, STAGE_2, STAGE_3]
const BLOCKS = STAGES
const INTERVAL = 50.0
const CHANCE = 20
const ACTION_BUDGET = 8
const FACING_KEY = "cocoa_facedir"
# Source facedir 0..3 points toward +Z, +X, -Z and -X respectively. For cocoa
# that vector points from the pod cell into its supporting log.
const SUPPORTS = [Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.LEFT]
const SIDES = [Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.LEFT]
const DATA = {
	687:{"name":"Premature Cocoa Pod","color":"719047","block":true,"shape":"cocoa","hidden":true,"tool":-1,"hardness":0.2,"blast_resistance":3.0},
	698:{"name":"Medium Cocoa Pod","color":"8a7a42","block":true,"shape":"cocoa","hidden":true,"tool":-1,"hardness":0.2,"blast_resistance":3.0},
	688:{"name":"Mature Cocoa Pod","color":"9f643c","block":true,"shape":"cocoa","hidden":true,"tool":-1,"hardness":0.2,"blast_resistance":3.0},
	816:{"name":"Cocoa beans","color":"825136","stack":64,"compostability":65},
}
# Node-local minima/maxima after translating Mineclonia's -0.5..0.5 coordinates
# to Voxey's 0..1 cell. Selection and collision use the identical source box.
const BOXES = [
	[-0.125,-0.0625,0.1875,0.125,0.25,0.4375],
	[-0.1875,-0.1875,0.0625,0.1875,0.25,0.4375],
	[-0.25,-0.3125,-0.0625,0.25,0.25,0.4375],
]

static func is_cocoa(id: int) -> bool: return id in STAGES
static func stage(id: int) -> int: return STAGES.find(id)+1 if is_cocoa(id) else 0
static func mature(id: int) -> bool: return id == STAGE_3
static func next_stage(id: int) -> int: return STAGES[stage(id)] if stage(id) in [1,2] else 0
static func unsticky(id: int) -> bool: return is_cocoa(id)

static func normal_jungle_log(id: int) -> bool:
	# Axis variants retain mcl_trees:tree_jungle; bark wood and stripped logs do not.
	return WoodTypes.canonical(id) == JUNGLE_LOG

static func facedir_for(support: Vector3i) -> int:
	return SUPPORTS.find(support)

static func support_direction(value: int) -> Vector3i:
	return SUPPORTS[clampi(value,0,3)]

static func column_of(p: Vector3i) -> Vector2i:
	return Vector2i(floori(p.x/16.0),floori(p.z/16.0))

static func facing_snapshot(world: VoxelWorld, column: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	# Pods currently have no natural generator, so every placed/saved pod is an
	# edit. Snapshot only those cells and their local block-state directions.
	for p in world.edits_near(column):
		if not is_cocoa(int(world.edits[p])): continue
		var block: Vector3i = VoxelWorld.block_coord(p)
		if not result.has(block): result[block] = {}
		result[block][VoxelWorld.local_index(p)] = facedir(world,p)
	return result
static func metadata(world: VoxelWorld, p: Vector3i, create: bool = false) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	var raw: Variant = world.block_states.get(key,{})
	var state: Dictionary = raw if raw is Dictionary else {}
	if create and (not raw is Dictionary or not world.block_states.has(key)): world.block_states[key] = state
	return state

static func facedir(world: VoxelWorld, p: Vector3i) -> int:
	var raw: Variant = metadata(world,p).get(FACING_KEY,0)
	return clampi(int(raw),0,3) if raw is int or raw is float else 0

static func set_facedir(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = metadata(world,p,true)
	state[FACING_KEY] = clampi(value,0,3)
	world.block_states[key] = state
	if world.loaded_at(Vector3(p)): world._mark_dirty(p)

# Rotate a facedir-zero box around the block centre. The +90 degree steps map
# +Z to +X, matching Luanti facedir rather than screen-clockwise conventions.
static func rotate_box(box: AABB, turns: int) -> AABB:
	for turn in posmod(turns,4):
		box = AABB(Vector3(box.position.z,box.position.y,1.0-box.end.x),Vector3(box.size.z,box.size.y,box.size.x))
	return box

static func boxes(id: int, facing: int = 0) -> Array:
	if not is_cocoa(id): return []
	var b: Array = BOXES[stage(id)-1]
	var minimum := Vector3(float(b[0]),float(b[1]),float(b[2]))+Vector3.ONE*0.5
	var maximum := Vector3(float(b[3]),float(b[4]),float(b[5]))+Vector3.ONE*0.5
	return [rotate_box(AABB(minimum,maximum-minimum),facing)]

static func world_boxes(world: VoxelWorld, p: Vector3i, _selection: bool = false) -> Array:
	return boxes(world.node_at(p),facedir(world,p))

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var support: Vector3i = p+support_direction(facedir(world,p))
	if not world.loaded_at(Vector3(support)): return false
	var id: int = world.node_at(support)
	# attached_node_facedir checks group:solid, not cocoa's placement rule. A
	# regular full collision cube qualifies; cocoa's own shaped collision does not.
	if not Nodes.solid(id): return false
	var geometry: Array = world.collision_boxes(support)
	return geometry.size() == 1 and geometry[0].position.is_equal_approx(Vector3.ZERO) and geometry[0].size.is_equal_approx(Vector3.ONE)

static func harvest(id: int) -> Array:
	if not is_cocoa(id): return []
	# In particular, source stage two drops ONE bean, not two.
	return [[BEANS,3 if id == STAGE_3 else 1]]

static func spawn_drops(world: VoxelWorld, p: Vector3i, id: int, lava: bool = false) -> void:
	if lava: return
	var game: Node = world.get_parent()
	if game == null or not game.has_method("spawn_drop"): return
	for entry in harvest(id): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])

static func environmental_break(world: VoxelWorld, p: Vector3i, lava: bool = false) -> bool:
	var id: int = world.node_at(p)
	if not is_cocoa(id) or not world.set_node(p,Nodes.AIR): return false
	spawn_drops(world,p,id,lava)
	return true

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	return environmental_break(world,p)

static func refresh(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	if not is_cocoa(world.node_at(p)) or not world.loaded_at(Vector3(p)): return
	var support: Vector3i = p+support_direction(facedir(world,p))
	# Never break against an unloaded support column. column_loaded revisits both
	# sides of a boundary once the real neighbor is available.
	if world.loaded_at(Vector3(support)) and not supported(world,p): environmental_break(world,p)

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("cocoa_crops"):
		var rng := RandomNumberGenerator.new()
		rng.seed = world.seed_value+687698
		world.set_meta("cocoa_crops",{"cells":{},"columns":{},"clock":0.0,"jobs":[],"pending":{},"serial":0,"rng":rng})
	return world.get_meta("cocoa_crops")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("cocoa_crops"): world.remove_meta("cocoa_crops")

static func register_job(world: VoxelWorld, p: Vector3i, kind: String) -> void:
	var state: Dictionary = runtime(world)
	if state.pending.has(p): return
	state.serial += 1
	state.pending[p] = state.serial
	state.jobs.append({"pos":p,"kind":kind,"serial":state.serial})

static func queue_growth(world: VoxelWorld, p: Vector3i) -> void:
	register_job(world,p,"grow")

static func queue_roll(world: VoxelWorld, p: Vector3i) -> void:
	register_job(world,p,"roll")

static func registered(world: VoxelWorld, p: Vector3i, on_load: bool = false) -> void:
	var id: int = world.node_at(p)
	if not is_cocoa(id) or not world.loaded_at(Vector3(p)): return
	world.growth.erase(p)
	var state: Dictionary = runtime(world)
	var first_load: bool = not state.cells.has(p)
	state.cells[p] = id
	var column: Vector2i = column_of(p)
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true
	# Loading starts an ABM-style chance roll, not free offline growth.
	if on_load and first_load and not mature(id): queue_roll(world,p)

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("cocoa_crops"): return
	var state: Dictionary = runtime(world)
	state.cells.erase(p)
	state.pending.erase(p)
	var column: Vector2i = column_of(p)
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("cocoa_crops"): return
	var state: Dictionary = runtime(world)
	for p in state.columns.get(column,{}).keys(): forget(world,p)
	state.jobs = state.jobs.filter(func(job): return column_of(job.pos) != column)

static func position_before(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x: return a.x < b.x
	if a.z != b.z: return a.z < b.z
	return a.y < b.y

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("cocoa_crops"): return
	var state: Dictionary = runtime(world)
	var cells: Array = state.cells.keys()
	cells.sort_custom(position_before)
	for p in cells:
		if not is_cocoa(world.node_at(p)):
			forget(world,p)
			continue
		var support: Vector3i = p+support_direction(facedir(world,p))
		if column_of(p) == column or column_of(support) == column: refresh(world,p)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if is_cocoa(old_id) and not is_cocoa(id):
		forget(world,p)
		var key: String = VoxelWorld.station_key(p)
		var state: Dictionary = metadata(world,p)
		state.erase(FACING_KEY)
		if state.is_empty(): world.block_states.erase(key)
		else: world.block_states[key] = state
	if is_cocoa(id): registered(world,p)
	# Growth replaces one non-solid pod with another. Its facedir is restored by
	# grow immediately after set_node, so checking the transient default is wrong.
	if is_cocoa(old_id) and is_cocoa(id): return
	# Initial placement also writes facedir immediately after set_node. Direct
	# edits/load reconciliation are checked by column_loaded instead.
	if not is_cocoa(old_id) and is_cocoa(id): return
	refresh(world,p)
	for side in SIDES: refresh(world,p+side)

# Source return values are intentionally unusual: cocoa_1 -> cocoa_2 performs
# the replacement but falls through to false; cocoa_2 -> cocoa_3 returns true.
static func grow(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id not in [STAGE_1,STAGE_2]: return false
	var facing: int = facedir(world,p)
	if not world.set_node(p,next_stage(id)): return false
	set_facedir(world,p,facing)
	return id == STAGE_2

static func bone_meal(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var before: int = world.node_at(p)
	if before not in [STAGE_1,STAGE_2]: return {"consume":false,"grew":false}
	var callback: bool = grow(world,p)
	# mcl_bone_meal consumes only callback results ~= false. Thus stage one
	# visibly grows without consumption/particles; stage two consumes once.
	return {"consume":callback,"grew":world.node_at(p) != before}

static func place(world: VoxelWorld, support: Vector3i, normal: Vector3i) -> bool:
	if normal.y != 0 or normal.length_squared() != 1: return false
	var at: Vector3i = support+normal
	if not world.loaded_at(Vector3(support)) or not world.loaded_at(Vector3(at)): return false
	if not normal_jungle_log(world.node_at(support)) or world.node_at(at) != Nodes.AIR: return false
	var facing: int = facedir_for(-normal)
	if facing < 0 or not world.set_node(at,STAGE_1): return false
	set_facedir(world,at,facing)
	refresh(world,at)
	return is_cocoa(world.node_at(at))

static func use(game: Node3D, target: Dictionary) -> bool:
	var held: int = int(game.inventory.held().id)
	if held != BEANS and not (held == Nodes.BONE_MEAL and not target.is_empty() and is_cocoa(int(target.id))): return false
	if held == BEANS:
		if target.is_empty(): return true
		var at: Vector3i = target.pos+target.normal
		if place(game.world,target.pos,target.normal):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place")
			game.player.swing = 1
			game.api.emit_node_placed(at,STAGE_1)
		return true
	var p: Vector3i = target.pos
	var result: Dictionary = bone_meal(game.world,p)
	if result.consume:
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
		game.puff(Vector3(p+Vector3i.UP)+Vector3.ONE*0.5,Color("b8e07a"),8)
		game.sound("place")
		game.player.swing = 1
	return true

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("cocoa_crops"): return
	var state: Dictionary = runtime(world)
	var rng: RandomNumberGenerator = state.rng
	if is_finite(delta) and delta > 0:
		state.clock += delta
		while state.clock >= INTERVAL:
			state.clock -= INTERVAL
			var cells: Array = state.cells.keys()
			cells.sort_custom(position_before)
			for p in cells:
				if not world.loaded_at(Vector3(p)):
					continue
				var id: int = world.node_at(p)
				if not is_cocoa(id) or mature(id):
					forget(world,p)
					continue
				state.cells[p] = id
				if rng.randi_range(1,CHANCE) == 1: queue_growth(world,p)
	# Coordinate ordering makes rolls independent of dictionary/load insertion
	# order. Serials still reject work queued for an older occupant of a cell.
	state.jobs.sort_custom(func(a: Dictionary,b: Dictionary):
		if a.pos != b.pos: return position_before(a.pos,b.pos)
		return int(a.serial) < int(b.serial))
	for index in mini(ACTION_BUDGET,state.jobs.size()):
		var job: Dictionary = state.jobs.pop_front()
		if state.pending.get(job.pos,-1) != job.serial: continue
		state.pending.erase(job.pos)
		if not state.cells.has(job.pos) or not world.loaded_at(Vector3(job.pos)): continue
		if job.kind == "roll" and rng.randi_range(1,CHANCE) != 1: continue
		grow(world,job.pos)

static func mesh(out: Array, at: Vector3, id: int, facing: int = 0) -> void:
	if not is_cocoa(id): return
	var body: AABB = boxes(id,facing)[0]
	var tile: int = Nodes.tile(id,0)
	BlockMesher._art_box(out,at+body.get_center(),body.size,tile,tile)
	# Original procedural stem/art; the body occupies the exact source box.
	var stem := rotate_box(AABB(Vector3(0.46875,0.60,0.9375),Vector3(0.0625,0.10,0.0625)),facing)
	BlockMesher._art_box(out,at+stem.get_center(),stem.size,tile,tile)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_cocoa(id): return noise
	var base := Color(DATA[id].color)
	if (x*3+y*5)%11 < 2: return base.darkened(0.20)
	return base.lightened(0.08) if (x+y)%5 == 0 else base

static func draw(img: Image, id: int) -> void:
	if id != BEANS: return
	for center in [Vector2(5,5),Vector2(10,7),Vector2(6,11)]:
		ItemArt._polygon(img,[center+Vector2(-2,-2),center+Vector2(1,-3),center+Vector2(3,-1),center+Vector2(2,2),center+Vector2(-1,3),center+Vector2(-3,1)],Color("825136"))
		ItemArt._line(img,center+Vector2(-1,-1),center+Vector2(1,1),Color("b17b53"),1)
