class_name SnowCover
extends RefCounted

# mcl_core/nodes_base.lua top_snow=1..8; source coordinates are centered,
# while Voxey voxel collision and mesh coordinates start at the lower corner.
const BASE = 5260
const MELT_INTERVAL = 16.0
const MELT_CHANCE = 8
static var icons: Dictionary = {}

static func is_snow(id: int) -> bool: return id >= BASE and id < BASE+8
static func layers(id: int) -> int: return id-BASE+1 if is_snow(id) else 0
static func height(id: int) -> float: return layers(id)/8.0
static func title(id: int) -> String: return "Top snow" if id == BASE else "Top snow (%d layers)"%layers(id)

static func replaceable(id: int) -> bool: return id == Nodes.AIR or is_snow(id)

static func placement(world: VoxelWorld, target: Dictionary) -> Dictionary:
	# Use only in placement branches: interacting with snow must not activate
	# the chest/workstation beneath it. Its replacement cell has different
	# support from the originally pointed snow node.
	var normal: Vector3i = target.normal
	var at: Vector3i = target.pos if is_snow(int(target.id)) else target.pos+normal
	var support: Vector3i = at-normal
	return {"pos":at,"normal":normal,"support":support,"support_id":world.node_at(support)}

static func boxes(id: int, collision: bool = true) -> Array:
	if not is_snow(id) or collision and id == BASE: return []
	return [AABB(Vector3.ZERO,Vector3(1,height(id),1))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	if not is_snow(id): return
	var h: float = height(id)
	BlockMesher._art_box(out,at+Vector3(0.5,h*0.5,0.5),Vector3(1,h,1),Nodes.tile(Nodes.SNOW_BLOCK,0),Nodes.tile(Nodes.SNOW_BLOCK,0))

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	if not world.loaded_at(Vector3(below)) or not Nodes.solid(world.node_at(below)): return false
	for box in world.collision_boxes(below):
		if box.position.is_equal_approx(Vector3.ZERO) and box.size.is_equal_approx(Vector3.ONE): return true
	return false

static func harvest(id: int, slot: Dictionary) -> Array:
	if not is_snow(id) or Nodes.tool_kind(int(slot.get("id",0))) != 2: return []
	return [[BASE,layers(id)]] if Inventory.enchantment(slot,"Silk Touch") > 0 else [[Nodes.SNOWBALL,layers(id)+1]]

static func drop(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_snow(id) or world.node_at(p) != id: return
	if world.set_node(p,Nodes.AIR):
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_drop"): game.spawn_drop(Vector3(p)+Vector3(0.5,height(id)*0.5,0.5),Nodes.SNOWBALL,layers(id)+1)

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: Dictionary = game.inventory.held()
	if not is_snow(int(held.id)) or target.is_empty(): return false
	if held.id != BASE or held.count <= 0: return true
	var at: Vector3i = target.pos if is_snow(int(target.id)) or Nodes.plant(int(target.id)) or Fire.is_fire(int(target.id)) else target.pos+target.normal
	var previous: int = game.world.node_at(at)
	var id: int = BASE
	if is_snow(previous):
		if layers(previous) < 8: id = previous+1
		else:
			at += Vector3i.UP
			if game.world.node_at(at) != Nodes.AIR: return true
	elif previous != Nodes.AIR and not Nodes.plant(previous) and not Fire.is_fire(previous): return true
	if not supported(game.world,at): return true
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(id):
		if body.intersects(AABB(Vector3(at)+box.position,box.size)): return true
	if game.world.set_node(at,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1
		game.api.emit_node_placed(at,id)
	return true

static func recipes(inv: Inventory) -> void:
	inv._recipe("Top snow",BASE,6,[Nodes.SNOW_BLOCK,Nodes.SNOW_BLOCK,Nodes.SNOW_BLOCK],3,"table")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("snow_cover"): world.remove_meta("snow_cover")

static func state(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("snow_cover"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value^5281780
		world.set_meta("snow_cover",{"cells":{},"columns":{},"clock":0.0,"scans":[],"rng":rng})
	return world.get_meta("snow_cover")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	var data: Dictionary = state(world)
	if id != BASE and not data.cells.has(p): return
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	# The installed source melting ABM lists only the one-layer snow node.
	if id == BASE and world.loaded_at(Vector3(p)):
		data.cells[p] = true
		if not data.columns.has(column): data.columns[column] = {}
		data.columns[column][p] = true
	else:
		data.cells.erase(p)
		if data.columns.has(column):
			data.columns[column].erase(p)
			if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i) -> void:
	registered(world,p,world.node_at(p))
	if PistonPush.defer_support(world,p): return
	for at in [p,p+Vector3i.UP]:
		var id: int = world.node_at(at)
		if is_snow(id) and world.loaded_at(Vector3(at)) and not supported(world,at): drop(world,at,id)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var data: Dictionary = state(world)
	for p in data.columns.get(column,{}): data.cells.erase(p)
	data.columns.erase(column)

static func melt(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != BASE or Pasture.block_light(world,p,12) < 12: return false
	return world.set_node(p,Nodes.AIR)

static func update(world: VoxelWorld, delta: float) -> void:
	var data: Dictionary = state(world)
	data.clock += maxf(0,delta)
	if data.clock >= MELT_INTERVAL:
		data.clock = 0.0
		data.scans.append({"cells":data.cells.keys(),"cursor":0})
	var started: int = Time.get_ticks_usec()
	var attempts: int = 0
	var rng: RandomNumberGenerator = data.rng
	for i in 128:
		if data.scans.is_empty() or attempts >= 4 or i > 0 and Time.get_ticks_usec()-started >= 1500: break
		var scan: Dictionary = data.scans[0]
		if scan.cursor >= scan.cells.size(): data.scans.pop_front(); continue
		var p: Vector3i = scan.cells[scan.cursor]; scan.cursor += 1
		if world.node_at(p) != BASE or not world.loaded_at(Vector3(p)): continue
		if rng.randi_range(1,MELT_CHANCE) == 1:
			attempts += 1; melt(world,p)
