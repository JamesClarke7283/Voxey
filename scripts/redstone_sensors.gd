class_name RedstoneSensors
extends RefCounted

# Mineclonia daylight detector and target rules; source attribution and the
# natural-light adapter are documented in docs/redstone-sensors-source.md.
const DAYLIGHT = 1240
const INVERTED = 1241
const TARGET = 1242
const TARGET_ON = 1243
const HEIGHT = 0.375
const PULSE_SECONDS = 1.0
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]
# Natural light and sky columns are kept per 16x16 column. A node change can
# only reach light within 13 nodes horizontally, so it drops the cached light
# of its own and the eight surrounding columns, and its own sky columns.
static var light_cache: Dictionary = {}
static var light_sky: int = -1
static var light_block_columns: Dictionary = {}
static var sky_column_cache: Dictionary = {}
static var synced_world: int = 0
static var synced_dimension: String = ""
static var synced_revision: int = -1

static func is_detector(id: int) -> bool: return id in [DAYLIGHT,INVERTED]
static func is_target(id: int) -> bool: return id in [TARGET,TARGET_ON]
static func is_device(id: int) -> bool: return is_detector(id) or is_target(id)
static func same_family(a: int, b: int) -> bool: return is_detector(a) and is_detector(b) or is_target(a) and is_target(b)
static func item(id: int) -> int: return DAYLIGHT if is_detector(id) else TARGET
static func boxes(id: int) -> Array: return [AABB(Vector3.ZERO,Vector3(1,HEIGHT if is_detector(id) else 1.0,1))]
static func signal_strength(natural: float, inverted: bool = false) -> int:
	var level: int = clampi(floori((natural-2.0)*15.0/12.0+0.5),0,15)
	return 15-level if inverted else level

static func recipes(inv: Inventory) -> void:
	var slab: int = BuildingShapes.slab_for(Nodes.PLANKS)
	inv._recipe("Daylight detector",DAYLIGHT,1,[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ,slab,slab,slab],3,"table")
	inv._recipe("Target",TARGET,1,[0,Nodes.REDSTONE_WIRE,0,Nodes.REDSTONE_WIRE,Nodes.HAY_BALE,Nodes.REDSTONE_WIRE,0,Nodes.REDSTONE_WIRE,0],3,"table")

static func special_recipe(grid: Array) -> Dictionary:
	if grid.size() != 9: return {}
	var pattern: Array = []
	for slot in grid: pattern.append(int(slot.get("id",0)))
	for index in 3:
		if pattern[index] != Nodes.GLASS or pattern[index+3] != Nodes.QUARTZ: return {}
		var slab: int = pattern[index+6]
		if not BuildingShapes.half_slab(slab) or not WoodTypes.is_planks(BuildingShapes.material(slab)): return {}
	var ingredients: Dictionary = {}
	for id in pattern: ingredients[id] = int(ingredients.get(id,0))+1
	return {"name":"Daylight detector","id":DAYLIGHT,"count":1,"pattern":pattern,"width":3,"ingredients":ingredients,"station":"table","dynamic":true}

static func normalize(state: Dictionary) -> void:
	state.out = clampi(int(state.get("out",0)),0,15)
	state.sensor_light = clampi(int(state.get("sensor_light",0)),0,14)
	state.sensor_clock = maxf(0,float(state.get("sensor_clock",0)))
	state.target_remaining = maxf(0,float(state.get("target_remaining",0)))

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	var state: Dictionary = world.circuits.state(p)
	normalize(state)
	if is_detector(id): sample(world,p,id,state)
	elif id == TARGET: state.out = 0; state.target_remaining = 0.0

static func sample(world: VoxelWorld, p: Vector3i, id: int, state: Dictionary) -> void:
	var natural: int = natural_light(world,p)
	var previous: int = int(state.get("sensor_light",-1))
	state.sensor_light = natural
	state.out = signal_strength(natural,id == INVERTED)
	state.sensor_clock = 0.0
	if signal_strength(previous) != signal_strength(natural): world.circuits.notify_observers(p)

static func tick(world: VoxelWorld, p: Vector3i, id: int, state: Dictionary, delta: float) -> void:
	normalize(state)
	if is_detector(id):
		state.sensor_clock += delta
		if state.sensor_clock >= 1.0-0.00001: sample(world,p,id,state)
	elif id == TARGET_ON:
		state.target_remaining = maxf(0,state.target_remaining-delta)
		if state.target_remaining <= 0.00001:
			state.out = 0; state.target_remaining = 0.0
			world.set_node(p,TARGET)

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_detector(int(target.get("id",0))): return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	if game.target_mob() != null: return false
	return toggle(game.world,target.pos)

static func toggle(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_detector(id): return false
	if not world.set_node(p,INVERTED if id == DAYLIGHT else DAYLIGHT): return false
	world.get_parent().sound("place")
	return true

# Source chooses the dominant face, then radial distance from its center.
# Its 0.08 margin yields a small full-strength bullseye on every face.
static func hit_strength(p: Vector3i, impact: Vector3) -> int:
	var rel: Vector3 = impact-(Vector3(p)+Vector3.ONE*0.5)
	var a: Vector3 = rel.abs()
	var face: Vector2
	if a.x > a.y and a.x > a.z: face = Vector2(rel.z,rel.y)
	elif a.y > a.x and a.y > a.z: face = Vector2(rel.x,rel.z)
	else: face = Vector2(rel.x,rel.y)
	return floori(clampf(30.0*(0.5-face.length()+0.08),1,15))

static func hit(world: VoxelWorld, p: Vector3i, impact: Vector3 = Vector3.INF, shooter: Node3D = null) -> bool:
	# Source's powered target has no arrow callback; an active pulse is neither
	# overwritten nor extended by another impact.
	if world.node_at(p) != TARGET: return false
	var strength: int = 15 if is_inf(impact.x) else hit_strength(p,impact)
	if not world.set_node(p,TARGET_ON): return false
	var state: Dictionary = world.circuits.state(p)
	state.out = strength; state.target_remaining = PULSE_SECONDS
	world.circuits.refresh(p)
	var game: Node3D = world.get_parent()
	if shooter == game.player and strength == 15:
		var distance: float = Vector2(shooter.position.x-p.x-0.5,shooter.position.z-p.z-0.5).length()
		if floori(distance) >= 30: game.achievements.award("bullseye")
	return true

# Called only on a projectile's block collision, never its entity collision.
# The short ray locates the actual face even when the projectile body touched
# a block slightly before its center entered it.
static func projectile_hit(world: VoxelWorld, origin: Vector3, motion: Vector3, precise: bool = true, shooter: Node3D = null) -> bool:
	if motion.length_squared() < 0.000001: return false
	var collision: Dictionary = world.raycast(origin,motion.normalized(),motion.length()+0.15)
	if collision.is_empty() or not is_target(int(collision.id)): return false
	return hit(world,collision.pos,collision.point if precise else Vector3.INF,shooter)

# Voxey has no stored natural-light channel. Reconstruct a bounded skylight
# field: vertical transparent columns admit daylight, while indirect paths
# lose one level per block. Emitters such as torches never enter this field.
static func natural_light(world: VoxelWorld, p: Vector3i) -> int:
	if world.dimension != "overworld" or p.y >= world.generator.max_y() or not world.loaded_at(Vector3(p)): return 0
	var game: Node3D = world.get_parent()
	var sky: int = clampi(roundi(2.0+12.0*clampf((game.daylight-0.05)/0.95,0,1)),2,14)
	_sync_geometry(world)
	if sky != light_sky: light_sky = sky; light_cache.clear()
	var column := Vector2i(p.x >> 4,p.z >> 4)
	var known: Variant = light_cache.get(column)
	if known == null: known = {}; light_cache[column] = known
	if known.has(p): return int(known[p])
	var result: int = _natural_light(world,p,sky)
	known[p] = result
	return result

# Columns are re-sorted lazily, only when a light query reaches them.
static func _sync_geometry(world: VoxelWorld) -> void:
	var revision: int = world.sky_revision
	if revision == synced_revision and world.get_instance_id() == synced_world and world.dimension == synced_dimension: return
	var changes: Array[Vector2i] = world.sky_log
	var from: int = synced_revision-world.sky_log_start
	if world.get_instance_id() != synced_world or world.dimension != synced_dimension or from < 0 or revision < synced_revision or revision != world.sky_log_start+changes.size():
		light_block_columns.clear(); sky_column_cache.clear(); light_cache.clear()
		if revision != world.sky_log_start+changes.size(): changes.clear(); world.sky_log_start = revision
	else:
		var seen: Dictionary = {}
		for i in range(from,changes.size()):
			var column: Vector2i = changes[i]
			if seen.has(column): continue
			seen[column] = true
			light_block_columns.erase(column); sky_column_cache.erase(column)
			for dz in range(-1,2):
				for dx in range(-1,2): light_cache.erase(column+Vector2i(dx,dz))
	synced_world = world.get_instance_id(); synced_dimension = world.dimension; synced_revision = revision

static func _natural_light(world: VoxelWorld, p: Vector3i, sky: int) -> int:
	var initial: Dictionary = _sky_column(world,Vector2i(p.x,p.z))
	var direct: int = maxi(0,sky-_filter_count(initial,p.y)) if int(initial.opaque) <= p.y else 0
	if direct >= sky-1: return direct # Any indirect path costs at least one level.
	# Before flooding a large covered volume, prove whether any column within
	# light range could possibly be reached. Height above the opaque roof,
	# horizontal distance and remaining leaf/water filters are a lower bound;
	# obstacles can only make the actual path longer.
	var possible: bool = false
	for x in range(1-sky,sky):
		for z in range(1-sky,sky):
			var horizontal: int = absi(x)+absi(z)
			if horizontal >= sky: continue
			var column: Vector2i = Vector2i(p.x+x,p.z+z)
			if not world.loaded_at(Vector3(column.x,p.y,column.y)): continue
			var info: Dictionary = _sky_column(world,column)
			var up: int = maxi(0,int(info.opaque)+1-p.y)
			if horizontal+up+_filter_count(info,p.y+up) < sky:
				possible = true; break
		if possible: break
	if not possible: return direct
	var queue: Array = [p]
	var distances: Dictionary = {p:0}
	var best: int = direct
	var index: int = 0
	while index < queue.size():
		var q: Vector3i = queue[index]; index += 1
		var distance: int = distances[q]
		if sky-distance <= best: break
		var data: Dictionary = _sky_column(world,Vector2i(q.x,q.z))
		if int(data.opaque) <= q.y:
			best = maxi(best,sky-distance-_filter_count(data,q.y))
		if sky-distance-1 <= best: continue
		for side in SIDES:
			var neighbor: Vector3i = q+side
			if distances.has(neighbor) or not world.loaded_at(Vector3(neighbor)) or light_filter(world.node_at(neighbor)) < 0: continue
			distances[neighbor] = distance+1; queue.append(neighbor)
	return clampi(best,0,14)

static func _filter_count(column: Dictionary, y: int) -> int:
	var count: int = 0
	for filter_y in column.filters:
		if filter_y > y: count += 1
	return count

static func _sky_column(world: VoxelWorld, column: Vector2i) -> Dictionary:
	var chunk := Vector2i(column.x >> 4,column.y >> 4)
	var cached: Variant = sky_column_cache.get(chunk)
	if cached == null: cached = {}; sky_column_cache[chunk] = cached
	if cached.has(column): return cached[column]
	var result: Dictionary = {"opaque":world.generator.min_y()-1,"filters":[]}
	var offset: int = posmod(column.x,16)+posmod(column.y,16)*16
	# Empty altitude gaps are implicit air, even with a building at Y30,900.
	# Inspect only allocated mapblocks, from the top until the first opaque cell.
	if not light_block_columns.has(chunk):
		var sorted: Array = world.column_blocks.get(chunk,[]).duplicate()
		sorted.sort_custom(func(a: Vector3i,b: Vector3i): return a.y > b.y)
		light_block_columns[chunk] = sorted
	for block in light_block_columns[chunk]:
		if not world.blocks.has(block): continue
		var data: PackedInt32Array = world.blocks[block].data
		for y in range(15,-1,-1):
			var id: int = data[offset+y*256]
			if id == Nodes.AIR: continue
			var cost: int = light_filter(id)
			if cost < 0:
				result.opaque = block.y*16+y
				cached[column] = result
				return result
			if cost > 0: result.filters.append(block.y*16+y)
	cached[column] = result
	return result

# Light propagation asks this for every cell it visits. It depends only on the
# id, so the main thread keeps each answer (see NodeInfo for the thread rules).
static var filter_memo: Dictionary = {}

static func light_filter(id: int) -> int:
	if not NodeInfo.cached(): return uncached_light_filter(id)
	var known: Variant = filter_memo.get(id)
	if known != null: return known
	var value: int = uncached_light_filter(id)
	filter_memo[id] = value
	return value

static func uncached_light_filter(id: int) -> int:
	if id == Amethyst.TINTED_GLASS: return -1
	if id == Nodes.AIR: return 0
	if WoodTypes.is_leaves(id) or Fluids.water(id): return 1
	if id in [Nodes.AIR,Nodes.GLASS,Nodes.ICE] or is_detector(id): return 0
	return 0 if Nodes.transparent(id) else -1

static func build(id: int, state: Dictionary = {}, _level: int = 0) -> Node3D:
	var root := Node3D.new()
	if is_detector(id):
		RedstoneArt.box(root,Vector3(0,0.125,0),Vector3(1,0.25,1),Color("8d6b44"))
		RedstoneArt.box(root,Vector3(0,0.31,0),Vector3(1,0.13,1),Color("c6ae79"))
		for x in 3:
			for z in 3: RedstoneArt.box(root,Vector3((x-1)*0.31,0.368,(z-1)*0.31),Vector3(0.26,0.014,0.26),Color("657e9e") if id == INVERTED else Color("e4d4a5"))
		RedstoneArt.box(root,Vector3(0,0.17,-0.503),Vector3(0.16,0.07,0.01),Color("de5544") if int(state.get("out",0)) > 0 else Color("66332d"))
	else:
		RedstoneArt.box(root,Vector3(0,0.5,0),Vector3.ONE,Color("d3bf86"))
		for side in SIDES:
			var face := Node3D.new(); root.add_child(face)
			face.position = Vector3(0,0.5,0)+Vector3(side)*0.501
			if side.y != 0: face.rotation.x = -PI/2.0*side.y
			elif side.x != 0: face.rotation.y = PI/2.0*side.x
			elif side.z < 0: face.rotation.y = PI
			for ring in 5:
				var size: float = 0.9-ring*0.17
				RedstoneArt.box(face,Vector3(0,0,ring*0.001),Vector3(size,size,0.005),Color("bb5148") if ring%2 == 0 else Color("f1e4ba"))
	return root

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if is_detector(id):
		BlockMesher._art_box(out,p+Vector3(0.5,HEIGHT*0.5,0.5),Vector3(1,HEIGHT,1),Nodes.tile(Nodes.PLANKS,0),Nodes.tile(id,2))
	else: BlockMesher._art_box(out,p+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(id,0),Nodes.tile(id,2))

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_detector(id):
		if x%5 == 0 or y%5 == 0: return Color("97784c")
		return Color("6c83a4") if id == INVERTED else Color("e4d5a5")
	var ring: int = maxi(absi(x*2-15),absi(y*2-15))
	if ring >= 15: return noise
	return Color("be5149") if ring in [1,3,9,11] else Color("f0e3ba")

static func draw(img: Image, id: int) -> void:
	if is_detector(id):
		ItemArt._polygon(img,[[1,6],[8,2],[15,6],[15,10],[8,14],[1,10]],Color("977249"))
		ItemArt._polygon(img,[[1,6],[8,2],[15,6],[8,10]],Color("68839e") if id == INVERTED else Color("e0cea0"))
		for offset in [-2,2]: ItemArt._line(img,Vector2(4+offset,5+offset*0.5),Vector2(11+offset,8+offset*0.5),Color("856849"))
	else:
		img.fill_rect(Rect2i(1,1,14,14),Color("d7c593"))
		for ring in 5:
			var edge: int = 2+ring
			img.fill_rect(Rect2i(edge,edge,16-edge*2,16-edge*2),Color("ba4b43") if ring%2 == 0 else Color("f0dfb4"))
