class_name Farmland
extends RefCounted

# Mineclonia mcl_farming/soil.lua. The visible dry node can retain moisture:
# wet soil changes to dry at 7 -> 6, then counts down before becoming dirt.
const DRY = 21
const WET = 8000
const HEIGHT = 15.0/16.0
const INTERVAL = 15.0
const CHANCE = 4
const COVER_INTERVAL = 8.0
const COVER_CHANCE = 50
const ACTION_BUDGET = 8
const BLOCKS = [WET]
const DATA = {
	8000:{"name":"Wet farmland","block":true,"shape":"farmland","color":"443323","hardness":0.6,"tool":2,"drop":2,"hidden":true},
}
static var icons: Dictionary = {}

static func is_soil(id: int) -> bool: return id == DRY or id == WET
static func dirtifies(id: int) -> bool: return is_soil(id) or id == VillageContent.PATH or FarmingRules.group(id,"dirtifies_below_solid") == 1
static func hydrated(id: int) -> bool: return id == WET
static func same_family(a: int, b: int) -> bool: return is_soil(a) and is_soil(b)
static func boxes(_id: int = DRY) -> Array: return [AABB(Vector3.ZERO,Vector3(1,HEIGHT,1))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	BlockMesher._art_box(out,at+Vector3(0.5,HEIGHT*0.5,0.5),Vector3(1,HEIGHT,1),Nodes.tile(Nodes.DIRT,0),Nodes.tile(id,2))

static func pixel(_id: int, x: int, _y: int, noise: Color) -> Color:
	return noise*(0.68 if x%4 < 2 else 1.0)

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var kind: int = Nodes.tool_kind(int(game.inventory.held().id)); var id: int = int(target.id)
	if kind == 4:
		if id not in [Nodes.GRASS,Nodes.DIRT,VillageContent.SWAMP_GRASS,VillageContent.PATH]: return false
	elif kind == 2:
		if id not in [Nodes.GRASS,Nodes.DIRT,VillageContent.SWAMP_GRASS]: return false
		if target.get("normal",Vector3i.UP).y < 0: return true
	else: return false
	var p: Vector3i = target.pos
	# Both callbacks require literal air above. Hoes accept every clicked face;
	# the source shovel callback excludes the lower face.
	if not game.world.loaded_at(Vector3(p+Vector3i.UP)) or game.world.node_at(p+Vector3i.UP) != Nodes.AIR: return true
	if game.world.set_node(p,DRY if kind == 4 else VillageContent.PATH):
		if game.gamemode != "creative": ToolCapabilities.action_wear(game.inventory)
		game.sound("dig"); game.player.swing = 1
	return true

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("farmland"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+8000
		world.set_meta("farmland",{"cells":{},"columns":{},"jobs":[],"pending":{},"rng":rng,"actions":0,"cover_clock":0.0,"cover_jobs":[],"cover_pending":{}})
	return world.get_meta("farmland")

static func state(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.get(key) is Dictionary: world.block_states[key] = {}
	var metadata: Dictionary = world.block_states[key]
	if not metadata.get("farmland") is Dictionary: metadata.farmland = {}
	var data: Dictionary = metadata.farmland
	var wet: Variant = data.get("wet",7 if hydrated(world.node_at(p)) else 0)
	var remaining: Variant = data.get("remaining",INTERVAL)
	data.wet = clampi(int(wet),0,7) if (wet is int or wet is float) and is_finite(float(wet)) else (7 if hydrated(world.node_at(p)) else 0)
	data.remaining = clampf(float(remaining),0,INTERVAL) if (remaining is int or remaining is float) and is_finite(float(remaining)) else INTERVAL
	return data

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not dirtifies(id) or not world.loaded_at(Vector3(p)): return
	var data: Dictionary = runtime(world)
	if is_soil(id): state(world,p)
	data.cells[p] = true
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("farmland"): return
	var data: Dictionary = runtime(world)
	data.cells.erase(p); data.pending.erase(p)
	data.jobs = data.jobs.filter(func(at): return at != p)
	data.cover_pending.erase(p); data.cover_jobs = data.cover_jobs.filter(func(at): return at != p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.columns.has(column):
		data.columns[column].erase(p)
		if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if not is_soil(id):
		forget(world,p)
		var key: String = VoxelWorld.station_key(p)
		if world.block_states.get(key) is Dictionary:
			world.block_states[key].erase("farmland")
			if world.block_states[key].is_empty(): world.block_states.erase(key)
		if dirtifies(id): registered(world,p,id)
		return
	registered(world,p,id)
	if not same_family(old_id,id) or old_id != WET and id == WET:
		var data: Dictionary = state(world,p)
		data.wet = 7 if hydrated(id) else 0; data.remaining = INTERVAL

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("farmland"): return
	for p in runtime(world).columns.get(column,{}).keys():
		if is_soil(world.node_at(p)): state(world,p)
		elif dirtifies(world.node_at(p)): pass
		else: forget(world,p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("farmland"): return
	for p in runtime(world).columns.get(column,{}).keys(): forget(world,p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("farmland"): world.remove_meta("farmland")

static func finish_piston(world: VoxelWorld) -> void:
	# The generic piston transaction transports block_states, including both
	# moisture and the timer. Runtime entries are maintained by changed().
	if not world.has_meta("farmland"): return
	for p in runtime(world).cells:
		if is_soil(world.node_at(p)): state(world,p)

static func solid_above(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id in [Nodes.PISTON,Nodes.STICKY_PISTON] and world.block_states.get(VoxelWorld.station_key(p),{}).get("extended",false): return false
	var groups: Dictionary = FarmingRules.groups(id)
	if not groups.is_empty(): return int(groups.solid) != 0
	# Native extensions without a source node retain their actual geometry.
	if not Nodes.solid(id) or is_soil(id) or VillageContent.is_bed(id) or id in [VillageContent.PATH,Nodes.PISTON_HEAD,Nodes.CHEST,PortableStorage.ENDER_CHEST,Nodes.BED,Nodes.ENCHANTING_TABLE,Nodes.HOPPER,Beehives.HONEY_BLOCK]: return false
	var geometry: Array = world.collision_boxes(p)
	return geometry.size() == 1 and geometry[0].position.is_equal_approx(Vector3.ZERO) and geometry[0].size.is_equal_approx(Vector3.ONE)

static func placed(world: VoxelWorld, p: Vector3i) -> void:
	var below: Vector3i = p+Vector3i.DOWN
	var id: int = world.node_at(p)
	if world.loaded_at(Vector3(below)) and dirtifies(world.node_at(below)) and (solid_above(world,p) or FarmingRules.group(id,"dirtifier") != 0): world.set_node(below,Nodes.DIRT)
	var above: Vector3i = p+Vector3i.UP
	if dirtifies(id) and world.loaded_at(Vector3(above)) and (solid_above(world,above) or FarmingRules.group(world.node_at(above),"dirtifier") != 0): world.set_node(p,Nodes.DIRT)

static func plant(id: int) -> bool:
	var groups: Dictionary = FarmingRules.groups(id)
	if not groups.is_empty(): return int(groups.plant) != 0
	return CropFarming.is_crop(id) or FruitCrops.is_stem(id) or Nodes.plant(id)

static func rain_preserves(world: VoxelWorld, p: Vector3i) -> bool:
	var game: Node = world.get_parent()
	if world.dimension != "overworld" or game == null or game.survival == null or game.survival.weather() not in ["rain","thunder"]: return false
	# mcl_weather.is_outdoor uses noon light, even at night. Transparent glass
	# intentionally counts as outdoors in that source function. Its soil ABM
	# checks global rain, not the separate biome-aware is_exposed_to_rain.
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	var offset: int = posmod(p.x,16)+posmod(p.z,16)*16
	for block in world.blocks:
		if block.x != column.x or block.z != column.y or block.y*16+15 <= p.y: continue
		var voxels: PackedInt32Array = world.blocks[block].data
		for y in range(maxi(0,p.y+1-block.y*16),16):
			if RedstoneSensors.light_filter(voxels[offset+y*256]) != 0: return false
	return true

static func water_nearby(world: VoxelWorld, p: Vector3i) -> int:
	# 1 water found, 0 fully known and dry, -1 unknown neighbors. Water wins
	# even when another part of the source's 9x2x9 volume is unloaded.
	var unknown: bool = false
	for y in 2:
		for x in range(-4,5):
			for z in range(-4,5):
				var at: Vector3i = p+Vector3i(x,y,z)
				if not world.loaded_at(Vector3(at)): unknown = true
				elif Fluids.water(world.node_at(at)): return 1
	return -1 if unknown else 0

static func advance(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or not is_soil(world.node_at(p)): return false
	var above: Vector3i = p+Vector3i.UP
	var nearby: int = water_nearby(world,p)
	var data: Dictionary = state(world,p)
	var before: int = world.node_at(p)
	var rain: bool = nearby != 1 and rain_preserves(world,p)
	var known: bool = world.loaded_at(Vector3(above))
	var plant_above: bool = int(data.wet) <= 0 and nearby == 0 and not rain and known and plant(world.node_at(above))
	var next: Dictionary = hydration_result(before,int(data.wet),nearby,rain,known,plant_above)
	if next.id != before and not world.set_node(p,int(next.id)): return false
	if not is_soil(int(next.id)): return next.id != before
	var changed: bool = next.id != before or int(next.wet) != int(data.wet)
	state(world,p).wet = int(next.wet)
	return changed

static func hydration_result(id: int, wet: int, nearby: int, rain: bool, above_known: bool, plant_above: bool) -> Dictionary:
	if nearby == 1: return {"id":WET,"wet":7 if id != WET else wet}
	if rain or nearby < 0: return {"id":id,"wet":wet}
	if wet <= 0: return {"id":Nodes.DIRT if above_known and not plant_above else id,"wet":wet}
	return {"id":DRY if wet == 7 else id,"wet":wet-1}

static func decay_above(world: VoxelWorld, p: Vector3i) -> bool:
	return world.loaded_at(Vector3(p)) and dirtifies(world.node_at(p)) and world.loaded_at(Vector3(p+Vector3i.UP)) and solid_above(world,p+Vector3i.UP) and world.set_node(p,Nodes.DIRT)

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("farmland") or delta <= 0 or not is_finite(delta): return
	var game: Node = world.get_parent()
	if game == null: return
	var hosting: bool = game.network != null and game.network.active() and not game.network.client() and game.state not in ["title","loading"]
	if not game.playing() and not hosting: return
	var data: Dictionary = runtime(world); var rng: RandomNumberGenerator = data.rng
	data.actions = 0
	data.cover_clock += delta
	var cover_due: bool = data.cover_clock >= COVER_INTERVAL
	if cover_due: data.cover_clock = fmod(data.cover_clock,COVER_INTERVAL)
	for p in data.cells.keys():
		if not world.loaded_at(Vector3(p)) or not dirtifies(world.node_at(p)): forget(world,p); continue
		if cover_due and not data.cover_pending.has(p) and solid_above(world,p+Vector3i.UP) and rng.randi_range(1,COVER_CHANCE) == 1:
			data.cover_jobs.append(p); data.cover_pending[p] = true
		if not is_soil(world.node_at(p)): continue
		if data.pending.has(p): continue
		var saved: Dictionary = state(world,p)
		saved.remaining = maxf(0,float(saved.remaining)-delta)
		if saved.remaining > 0: continue
		if rng.randi_range(1,CHANCE) == 1: data.jobs.append(p); data.pending[p] = true
		else: saved.remaining = INTERVAL
	while data.actions < ACTION_BUDGET and not data.jobs.is_empty():
		var p: Vector3i = data.jobs.pop_front(); data.pending.erase(p)
		if not data.cells.has(p): continue
		data.actions += 1; advance(world,p)
		if is_soil(world.node_at(p)): state(world,p).remaining = INTERVAL
	while data.actions < ACTION_BUDGET and not data.cover_jobs.is_empty():
		var p: Vector3i = data.cover_jobs.pop_front(); data.cover_pending.erase(p)
		if not data.cells.has(p): continue
		data.actions += 1; decay_above(world,p)
