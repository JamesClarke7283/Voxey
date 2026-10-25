class_name SweetBerryCrops
extends RefCounted

# Mineclonia ITEMS/mcl_farming/{sweet_berry,shared_functions}.lua and
# ITEMS/mcl_bone_meal/init.lua, GPL-3.0-or-later. Original GDScript and art.
# IDs are literal so VillageContent can reference this module without a cycle.
const FIRST = 567
const STAGES = [567,568,569,570]
const BLOCKS = STAGES
const BERRY = 775
const BONE_MEAL = 119
const WET_SOIL = 8000
const HOSTS = [Nodes.GRASS,Nodes.DIRT,13600,13602,21,8000,1204] # Mycelium is not a berry host.
const INTERVAL = 68.0
const CHANCE = 3
const PERIOD = INTERVAL*CHANCE
const COMPOSTABILITY = 30
const ACTION_BUDGET = 8

static func stage(id: int) -> int: return id-FIRST if id >= FIRST and id < FIRST+4 else -1
static func is_bush(id: int) -> bool: return stage(id) >= 0
static func mature(id: int) -> bool: return id == STAGES[3]
static func base_item(id: int) -> int: return BERRY if is_bush(id) else 0
static func can_plant_on(id: int) -> bool: return id in HOSTS
static func compost_chance(id: int) -> int: return COMPOSTABILITY if id == BERRY or is_bush(id) else 0
static func source_node(id: int) -> String:
	if is_bush(id): return "mcl_farming:sweet_berry_bush_"+str(stage(id))
	return "mcl_farming:sweet_berry" if id == BERRY else ""
static func random(rng: RandomNumberGenerator, low: int, high: int) -> int:
	return rng.randi_range(low,high) if rng != null else randi_range(low,high)

# The ordinary node drop table, not the old crop fallback. Stages 0/1 drop
# nothing. At stages 2/3 the low count has rarity two and the high count is the
# fallback, so each outcome has probability one half. Tools do not alter it.
static func harvest(id: int, rng: RandomNumberGenerator = null) -> Array:
	var s: int = stage(id)
	if s < 2: return []
	return [[BERRY,s-1 if random(rng,1,2) == 1 else s]]

static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int = 0) -> bool:
	if not is_bush(id): return false
	if not game.world.set_node(p,Nodes.AIR): return true
	if game.gamemode != "creative":
		for entry in harvest(id): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	game._break_particles(p,id); game.sound("break"); game.progress("gather")
	game.api.emit_node_broken(p,id)
	return true

static func environmental_break(world: VoxelWorld, p: Vector3i, lava: bool = false) -> bool:
	var id: int = world.node_at(p)
	if not is_bush(id): return false
	var drops: Array = [] if lava else harvest(id,runtime(world).rng)
	if not world.set_node(p,Nodes.AIR): return false
	for entry in drops: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	return true

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	return environmental_break(world,p)

# --- Source shared plant growth ------------------------------------------------

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("sweet_berry_crops"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+775567
		world.set_meta("sweet_berry_crops",{"cells":{},"columns":{},"clock":0.0,"jobs":[],"pending":{},"serial":0,"rng":rng})
	return world.get_meta("sweet_berry_crops")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("sweet_berry_crops"): world.remove_meta("sweet_berry_crops")

static func queue_growth(world: VoxelWorld, p: Vector3i) -> void:
	var state: Dictionary = runtime(world)
	if state.pending.has(p): return
	state.serial += 1; state.pending[p] = state.serial
	state.jobs.append({"pos":p,"serial":state.serial})

static func registered(world: VoxelWorld, p: Vector3i, on_load: bool = false) -> void:
	var id: int = world.node_at(p)
	if not is_bush(id) or not world.loaded_at(Vector3(p)): return
	world.growth.erase(p)
	var state: Dictionary = runtime(world); var first_load: bool = not state.cells.has(p)
	state.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true
	if on_load and first_load and not mature(id): queue_growth(world,p)

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("sweet_berry_crops"): return
	var state: Dictionary = runtime(world); state.cells.erase(p); state.pending.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("sweet_berry_crops"): return
	var state: Dictionary = runtime(world)
	for p in state.columns.get(column,{}).keys(): forget(world,p)
	state.jobs = state.jobs.filter(func(job): return Vector2i(floori(job.pos.x/16.0),floori(job.pos.z/16.0)) != column)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("sweet_berry_crops"): return
	for p in runtime(world).columns.get(column,{}).keys(): refresh(world,p)

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	return world.loaded_at(Vector3(p+Vector3i.DOWN)) and Nodes.solid(world.node_at(p+Vector3i.DOWN))

static func refresh(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	if is_bush(world.node_at(p)) and world.loaded_at(Vector3(p+Vector3i.DOWN)) and not supported(world,p): environmental_break(world,p)

static func changed(world: VoxelWorld, p: Vector3i, old: int, id: int) -> void:
	if is_bush(old) and not is_bush(id): forget(world,p)
	if is_bush(old) or is_bush(id): world.growth.erase(p)
	if is_bush(id): registered(world,p)
	refresh(world,p); refresh(world,p+Vector3i.UP)

static func metadata(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.get(key) is Dictionary: world.block_states[key] = {}
	if not world.block_states[key].get("sweet_berry",null) is Dictionary: world.block_states[key].sweet_berry = {}
	return world.block_states[key].sweet_berry

static func now(world: VoxelWorld) -> float: return float(world.get_parent().day_time)*1200.0

# This deliberately calls FarmingRules.growth rather than a timer/stage shortcut.
# Fresh history advances 1+ceil(.1), i.e. two visual stages. Every non-wet support
# (including grass, dirt, coarse dirt and moss) uses the source's dry early-growth
# throttle; only literal wet farmland avoids it. Saved time/light history drives
# loaded-column catch-up exactly as it does for the other shared-farming plants.
static func grow(world: VoxelWorld, p: Vector3i, stages: int = 1, ignore_light: bool = false, low_speed: bool = false, rng: RandomNumberGenerator = null) -> bool:
	var id: int = world.node_at(p)
	if not is_bush(id) or mature(id) or not supported(world,p): return false
	var current_stage: int = stage(id)+1; var meta: Dictionary = metadata(world,p)
	var light: int = Pasture.light(world,p,14); var current: float = now(world)
	var last: float = float(meta.get("last_time",0))
	var elapsed: float = PERIOD/10.0 if last < 1 else PERIOD if last == current else current-last
	var roll: int = random(rng,0,9) if low_speed and elapsed/PERIOD < 1.01 else 0
	var next: int = FarmingRules.growth(meta,current_stage,4,PERIOD,current,light,stages,ignore_light,low_speed,roll)
	if next == current_stage: world.block_states.erase(VoxelWorld.station_key(p))
	return next > 0 and world.set_node(p,STAGES[next-1])

# The node's `_on_bone_meal` has no Lua return. If the dispatcher is reached its
# nil result therefore consumes even when mature growth returns false. Ordinary
# non-sneaking clicks on fruit-bearing bushes never reach it (see use below).
static func bone_meal(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> Dictionary:
	if not is_bush(world.node_at(p)): return {"consume":false,"grew":false}
	return {"consume":true,"grew":grow(world,p,1,true,false,rng)}

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("sweet_berry_crops"): return
	var state: Dictionary = runtime(world); var rng: RandomNumberGenerator = state.rng
	state.clock += maxf(0,delta)
	if state.clock >= INTERVAL:
		state.clock = fmod(state.clock,INTERVAL)
		for p in state.cells:
			if not mature(int(state.cells[p])) and rng.randi_range(1,CHANCE) == 1: queue_growth(world,p)
	var started: int = Time.get_ticks_usec(); var backlog: bool = state.jobs.size() > 16
	for i in mini(ACTION_BUDGET,state.jobs.size()):
		if backlog and i > 0 and Time.get_ticks_usec()-started >= 4000: break
		var job: Dictionary = state.jobs.pop_front()
		if state.pending.get(job.pos,-1) != job.serial: continue
		state.pending.erase(job.pos)
		if not state.cells.has(job.pos) or not world.loaded_at(Vector3(job.pos)): continue
		grow(world,job.pos,1,false,world.node_at(job.pos+Vector3i.DOWN) != WET_SOIL,rng)

# --- Planting, harvesting and the actual item dispatch -------------------------

# core.swap_node preserves metadata, unlike growth's core.set_node. Preserve the
# complete block-state entry while Voxey replaces the stage for the same reason.
static func harvest_right_click(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> int:
	var id: int = world.node_at(p)
	if stage(id) < 2: return 0
	var drops: Array = harvest(id,rng if rng != null else runtime(world).rng)
	var key: String = VoxelWorld.station_key(p)
	var saved: Dictionary = world.block_states.get(key,{}).duplicate(true)
	if not world.set_node(p,STAGES[1]): return 0
	if saved.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = saved
	var amount: int = int(drops[0][1])
	world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,BERRY,amount)
	return amount

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var world: VoxelWorld = game.world; var p: Vector3i = target.pos
	var id: int = world.node_at(p); var held: int = int(game.inventory.held().get("id",0))
	if is_bush(id):
		if held == BONE_MEAL:
			# sweet_berry.lua's fruit-bearing on_rightclick returns the stack when it
			# sees bone meal. mcl_bone_meal.on_place first calls that handler and
			# returns immediately: no growth, consumption, particles or berries.
			if stage(id) >= 2 and not game.player.crouching:
				game.player.eating.clear(); game.player.swing = 1
				return true
			# Stages 0/1 have no on_rightclick, so their real click reaches the
			# dispatcher. Sneaking bypasses the handler at every stage.
			var result: Dictionary = bone_meal(world,p,runtime(world).rng)
			if result.consume:
				if game.gamemode != "creative": game.inventory.consume_selected()
				game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),10)
				game.puff(Vector3(p+Vector3i.UP)+Vector3.ONE*0.5,Color("b8e07a"),10)
			game.player.swing = 1
			return true
		if stage(id) >= 2 and not game.player.crouching:
			harvest_right_click(world,p)
			game.player.eating.clear(); game.player.swing = 1
			return true
		return false
	if held != BERRY or target.get("normal",Vector3i.ZERO) != Vector3i.UP: return false
	# The source requires its exact host below, a top-face click and literal air.
	# Replaceable snow, fluids and side/bottom faces are not planting positions.
	var at: Vector3i = p+Vector3i.UP
	if not can_plant_on(id) or world.node_at(at) != Nodes.AIR: return false
	if not world.set_node(at,FIRST): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.player.eating.clear(); game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,FIRST)
	return true

# --- Geometry and original art -------------------------------------------------

static func boxes(id: int) -> Array:
	if not is_bush(id): return []
	# Source x/z +/-6/16 and top -0.30+stage*.25, translated to block-local Y.
	return [AABB(Vector3(0.125,0,0.125),Vector3(0.75,0.20+stage(id)*0.25,0.75))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	if is_bush(id): BlockMesher._plant(out,at,id)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_bush(id): return noise
	var s: int = stage(id); var start: int = [11,7,4,2][s]
	var width: float = 1.5+(15-y)*0.38
	var leaf: bool = y >= start and y <= 14 and absf(x-7.5) <= width
	var stem: bool = x in [7,8] and y >= maxi(6,start) or y >= 13 and x in range(5,11)
	if not leaf and not stem: return Color(0,0,0,0)
	var color := Color("315f2f") if stem else Color("427a38").lightened(0.08 if (x+y)%4 == 0 else 0.0)
	if s >= 2:
		var berries: Array = [Vector2i(4,8),Vector2i(11,7),Vector2i(6,11),Vector2i(10,12)]
		for i in (2 if s == 2 else 4):
			if Vector2i(x,y).distance_to(berries[i]) < 1.6: color = Color("bd3f4d").lightened(0.18 if x < berries[i].x else 0.0)
	return color

static func draw(img: Image, id: int) -> void:
	if id != BERRY: return
	for at in [Vector2i(3,7),Vector2i(8,4),Vector2i(9,10)]:
		ItemArt._polygon(img,[at+Vector2i(-2,0),at+Vector2i(0,-2),at+Vector2i(3,-1),at+Vector2i(3,2),at+Vector2i(1,4),at+Vector2i(-2,3)],Color("bd4050"))
		img.set_pixel(at.x,at.y,Color("ed8a91"))
	ItemArt._line(img,Vector2(9,3),Vector2(8,0),Color("54733b"),2)
	ItemArt._polygon(img,[[9,2],[13,0],[14,2],[11,4]],Color("6c963f"))

# --- PARENT WIRING -------------------------------------------------------------
# docs/sweet-berries-source.md lists every dispatcher and rendering hook. Keep
# SweetBerryThorns as the sole contact damage/slowdown implementation; this module
# owns only planting, growth, harvest, drops, support, compost and presentation.
