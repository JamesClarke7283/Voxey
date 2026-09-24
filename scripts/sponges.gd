class_name Sponges
extends RefCounted

# Mineclonia mcl_sponges/init.lua, GPL-3.0-or-later. Original procedural art.
#
# Source rules reproduced here:
# - Absorption scans the inclusive 7x7x7 cube centred on the sponge and removes
#   every water node in it.
# - Source counts river water separately from normal water and becomes the
#   river-waterlogged variant only when river water strictly outnumbers normal
#   water, so a tie favours normal water. Voxey has one water fluid, so
#   `river_water` is always false and the river variant is registered for save
#   compatibility only; the source could never produce it here either without
#   the mclx_core river nodes, which this checkout's Voxey does not represent.
# - A dry sponge placed where water is present, or beside water within one node,
#   absorbs immediately and is placed as its wet variant.
# - A wet sponge placed in the Nether dries into a plain sponge at once.
# - One active sweep visits every tracked dry sponge once per second and
#   converts it when water has become adjacent.
# - The wet variants smelt into a plain sponge, and an empty bucket in the
#   furnace's fuel slot is replaced by a water bucket.
#
# Source gap carried over: the checkout registers no crafting recipe that
# produces a dry sponge and no acquisition path except an elder guardian drop or
# an ocean monument room, neither of which Voxey has. Sponges are therefore
# obtainable only in creative or through a mod for now, and this is recorded as
# a remaining difference rather than papered over with an invented recipe.

const SPONGE = 9400
const WET = 9401
const WET_RIVER = 9402
const DATA = {
	SPONGE:{"name":"Sponge","block":true,"color":"d6d16a","hardness":0.6},
	WET:{"name":"Waterlogged sponge","block":true,"color":"a8b455","hardness":0.6},
	WET_RIVER:{"name":"Riverwaterlogged sponge","block":true,"color":"a8b455","hardness":0.6,"hidden":true},
}
const BLOCKS = [SPONGE,WET,WET_RIVER]
# The source absorption volume is pos-3..pos+3 inclusive on every axis.
const RADIUS = 3
# Source ABM: nodenames {sponge}, neighbors {group:water}, interval 1, chance 1.
const INTERVAL = 1.0
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]

static func is_sponge(id: int) -> bool: return BLOCKS.has(id)
static func is_wet(id: int) -> bool: return id == WET or id == WET_RIVER

# Source distinguishes river water by a per-node group. No Voxey water node
# carries that group, so this is honest and testable rather than assumed.
static func river_water(_id: int) -> bool: return false

# Source `absorb(pos)`: remove every water node in the 7x7x7 cube, then choose
# the wet variant by which kind dominated. The strict comparison is reproduced,
# so a tie yields the ordinary waterlogged sponge.
static func absorb(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var river: int = 0
	var normal: int = 0
	var removed: Array = []
	for x in range(-RADIUS,RADIUS+1):
		for y in range(-RADIUS,RADIUS+1):
			for z in range(-RADIUS,RADIUS+1):
				var at := p+Vector3i(x,y,z)
				var id: int = world.node_at(at)
				if not Fluids.water(id): continue
				if river_water(id): river += 1
				else: normal += 1
				removed.append(at)
	if removed.is_empty(): return {"changed":false,"result":SPONGE,"count":0}
	for at in removed: world.set_node(at,Nodes.AIR)
	return {"changed":true,"result":WET_RIVER if river > normal else WET,"count":removed.size()}

# --- registration -----------------------------------------------------------

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("sponges"):
		world.set_meta("sponges",{"cells":{},"columns":{},"clock":0.0})
	return world.get_meta("sponges")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("sponges"): world.remove_meta("sponges")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if id != SPONGE or not world.loaded_at(Vector3(p)): return
	var data: Dictionary = runtime(world)
	data.cells[p] = true
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("sponges"): return
	var data: Dictionary = runtime(world); data.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.columns.has(column):
		data.columns[column].erase(p)
		if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i, _old_id: int, id: int) -> void:
	forget(world,p)
	registered(world,p,id)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("sponges"): return
	for p in runtime(world).columns.get(column,{}).keys(): forget(world,p)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("sponges"): return
	for p in world.column_edits(column):
		if world.edits[p] == SPONGE and world.loaded_at(Vector3(p)): registered(world,p,SPONGE)

# Source ABM: one second, every dry sponge, water as a neighbour.
static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("sponges"): return
	var data: Dictionary = runtime(world)
	data.clock = float(data.clock)+maxf(0,delta)
	if float(data.clock) < INTERVAL: return
	data.clock = 0.0
	for p in data.cells.keys():
		if world.node_at(p) != SPONGE: continue
		tick(world,p)

static func tick(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != SPONGE or not adjacent_water(world,p): return false
	var result: Dictionary = absorb(world,p)
	if not result.changed: return false
	world.set_node(p,result.result)
	registered(world,p,world.node_at(p))
	return true

static func adjacent_water(world: VoxelWorld, p: Vector3i) -> bool:
	for side in SIDES:
		if Fluids.water(world.node_at(p+side)): return true
	return false

# --- interaction ------------------------------------------------------------

# Source `on_place`: absorbs first when the target cell or a neighbour within one
# node is water, then places the wet variant and consumes one item.
static func place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if held != SPONGE or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos if SnowCover.is_snow(int(target.id)) else target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.is_snow(current) and not Nodes.plant(current) and not Fluids.liquid(current): return true
	if not SnowCover.replaceable(current) and not Fluids.liquid(current): return true
	var water_nearby: bool = Fluids.water(game.world.node_at(at))
	if not water_nearby:
		for dx in range(-1,2):
			for dy in range(-1,2):
				for dz in range(-1,2):
					if dx == 0 and dy == 0 and dz == 0: continue
					if Fluids.water(game.world.node_at(at+Vector3i(dx,dy,dz))): water_nearby = true
	var placed: int = SPONGE
	if water_nearby:
		var result: Dictionary = absorb(game.world,at)
		if result.changed: placed = result.result
	return _put(game,at,placed)

# Source `place_wet_sponge`: the Nether dries the sponge as it is placed, with no
# bucket produced and no water dropped.
static func place_wet(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_wet(held) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos if SnowCover.is_snow(int(target.id)) else target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if not SnowCover.replaceable(current) and not Fluids.liquid(current) and current != Nodes.AIR: return true
	var placed: int = SPONGE if game.world.dimension == "nether" else held
	if not _put(game,at,placed): return true
	if placed == SPONGE:
		game.puff(Vector3(at)+Vector3.ONE*0.5,Color("e8f4f7"),10)
		game.toast("The water evaporates in the Nether.")
	return true

static func _put(game: Node3D, at: Vector3i, id: int) -> bool:
	if not game.world.set_node(at,id): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,id)
	return true

# Breaking any variant returns a plain sponge, as in source.
static func break_node(game: Node3D, p: Vector3i, id: int, tool: int, exploded: bool = false) -> bool:
	if not is_wet(id) and id != SPONGE: return false
	if not game.world.set_node(p,Nodes.AIR): return true
	if exploded or game.gamemode != "creative" and Nodes.harvestable(id,tool): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,SPONGE,1)
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

# --- furnace ----------------------------------------------------------------

# Source `_mcl_cooking_output` is the plain sponge, and its
# `_mcl_cooking_replacements` swaps an empty bucket in the fuel slot for a water
# bucket. Voxey's furnace owns its own slots, so the replacement is exposed here
# for the parent to apply rather than duplicating the furnace here.
static func cooking_replacement(id: int) -> int:
	return Nodes.WATER_BUCKET if is_wet(id) else 0

# --- art --------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = Color(DATA[id].color)
	if is_wet(id):
		# A soaked sponge reads darker and bluer, with the pores still visible.
		base = base.darkened(0.22).lerp(Color("4f7f96"),0.35)
	for ox in [-2,0,2]:
		for oy in [-2,0,2]:
			if posmod(ox*7+oy*11+x*3+y*5,7) == 0: continue
			if absi(x-8-ox) <= 1 and absi(y-8-oy) <= 1: return base.darkened(0.38)
	return base.lightened(0.06) if posmod(x*5+y*3,11) == 0 else base

static func draw(img: Image, id: int) -> void:
	var base: Color = Color(DATA[id].color)
	if is_wet(id): base = base.darkened(0.22).lerp(Color("4f7f96"),0.35)
	ItemArt._polygon(img,[[2,3],[13,2],[14,12],[3,14]],base)
	ItemArt._line(img,Vector2(3,4),Vector2(13,3),base.lightened(0.28))
	for offset in [Vector2i(4,5),Vector2i(9,4),Vector2i(5,10),Vector2i(10,9)]:
		img.fill_rect(Rect2i(offset,Vector2i(2,2)),base.darkened(0.4))

static func mesh(out: Array, p: Vector3, id: int) -> void:
	BlockMesher._art_box(out,p+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(id,0),Nodes.tile(id,2))

static func icon_faces(id: int) -> Array:
	var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
	return Barriers.project_icon(out)
