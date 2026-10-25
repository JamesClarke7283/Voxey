class_name SoilVariants
extends RefCounted

# Mineclonia mcl_core/{nodes_base,nodes_trees,functions}.lua,
# mobs_mc/wandering_trader.lua. Original GDScript; GPL-3.0 source reference.
# Numeric literals in DATA keep VillageContent's registration table acyclic.
const PODZOL = 13602
const SNOWY_PODZOL = 13603
const MYCELIUM = 13604
const SNOWY_MYCELIUM = 13605

const SPREAD_INTERVAL = 30.0
const SPREAD_CHANCE = 20
const DECAY_INTERVAL = 8.0
const DECAY_CHANCE = 50
const GIANT_SPRUCE_RADIUS = 6

const DATA = {
	13602:{"name":"Podzol","color":"56402b","block":true,"hardness":0.5,"blast_resistance":0.5,"tool":2,"drop":2,"source_node":"mcl_core:podzol"},
	13603:{"name":"Podzol with Snow","color":"dde6eb","block":true,"hardness":0.5,"blast_resistance":0.5,"tool":2,"drop":2,"hidden":true,"source_node":"mcl_core:podzol_snow"},
	13604:{"name":"Mycelium","color":"6c5976","block":true,"hardness":0.6,"blast_resistance":0.6,"tool":2,"drop":2,"source_node":"mcl_core:mycelium"},
	13605:{"name":"Mycelium with Snow","color":"dde6eb","block":true,"hardness":0.6,"blast_resistance":0.6,"tool":2,"drop":2,"hidden":true,"source_node":"mcl_core:mycelium_snow"},
}

# Nodes.SNOW (13) is the existing snowy-grass save ID. Only unsnowed mycelium
# spreads: register_snowed_node removes spreading_dirt_type from snowy states.
const SNOWED = {1:13,13602:13603,13604:13605}
const SNOWLESS = {13:1,13603:13602,13605:13604}
const EMERALD = 768 # VillageContent.EMERALD, without a constant-cycle.
const PODZOL_OFFER = {"tier":1,"cost":[[EMERALD,3,3]],"give":[PODZOL,3,3],"stock":6,"xp":0,"multiplier":0.0}

static func is_variant(id: int) -> bool: return DATA.has(id)
static func is_mycelium(id: int) -> bool: return id == MYCELIUM
static func spreading(id: int) -> bool: return id == MYCELIUM
static func hidden(id: int) -> bool: return id in [Nodes.SNOW,SNOWY_PODZOL,SNOWY_MYCELIUM]
static func snowed(id: int) -> int: return int(SNOWED.get(id,0))
static func snowless(id: int) -> int: return int(SNOWLESS.get(id,0))
static func is_snow_cover(id: int) -> bool: return SnowCover.is_snow(id) or id == Nodes.SNOW_BLOCK
static func pathable(id: int) -> bool: return id in [Nodes.SNOW,PODZOL,SNOWY_PODZOL,MYCELIUM,SNOWY_MYCELIUM]
static func covered(world: VoxelWorld, p: Vector3i) -> bool:
	return Pasture.covered(world,p) or FarmingRules.group(world.node_at(p+Vector3i.UP),"dirtifier") != 0

# on_snow_construct, on_snowable_construct and after_snow_destruct together.
# VoxelWorld calls this for every authoritative edit with the previous ID. A
# snow-to-snow stack edit remains covered; removing/melting any cover clears the
# soil below, and placing clear soil below an existing cover snows it immediately.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int = -1) -> void:
	var id: int = world.node_at(p)
	var below: Vector3i = p+Vector3i.DOWN
	if is_snow_cover(id):
		var replacement: int = snowed(world.node_at(below))
		if replacement != 0: world.set_node(below,replacement)
	elif is_snow_cover(old_id):
		var replacement: int = snowless(world.node_at(below))
		if replacement != 0: world.set_node(below,replacement)
	if is_snow_cover(world.node_at(p+Vector3i.UP)):
		var replacement: int = snowed(id)
		if replacement != 0: world.set_node(p,replacement)

# Source 3x5x3 source search: one cell horizontally, one below through three
# above. Snowy mycelium and podzol are deliberately not spreading sources.
static func mycelium_sources(world: VoxelWorld, p: Vector3i) -> Array:
	var found: Array = []
	for y in range(-1,4):
		for z in range(-1,2):
			for x in range(-1,2):
				var q: Vector3i = p+Vector3i(x,y,z)
				if world.loaded_at(Vector3(q)) and world.node_at(q) == MYCELIUM: found.append(q)
	return found

static func _uproot_non_mycelium_plant(world: VoxelWorld, p: Vector3i) -> void:
	var above: Vector3i = p+Vector3i.UP
	var id: int = world.node_at(above)
	if FarmingRules.group(id,"non_mycelium_plant") == 0: return
	# core.dig_node, including the plant's ordinary drop and multi-node behavior.
	var game: Node = world.get_parent()
	if game != null and game.has_method("break_node"): game.break_node(above,id,0)

# Apply an already-selected source in Pasture's combined grass/mycelium draw.
# Rechecking the source and both light gates makes delayed queued jobs safe.
static func spread_from(world: VoxelWorld, p: Vector3i, source: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != Nodes.DIRT or covered(world,p): return false
	if not world.loaded_at(Vector3(source)) or world.node_at(source) != MYCELIUM: return false
	if Pasture.light(world,p+Vector3i.UP,4) < 4 or Pasture.light(world,source+Vector3i.UP,9) < 9: return false
	if not world.set_node(p,MYCELIUM): return false
	_uproot_non_mycelium_plant(world,p)
	return true

# Standalone mycelium-only entry point. Pasture uses mycelium_sources plus
# spread_from instead, so one random source is selected across grass and mycelium.
static func spread(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != Nodes.DIRT or covered(world,p): return false
	var nearby: Array = mycelium_sources(world,p)
	if nearby.is_empty() or Pasture.light(world,p+Vector3i.UP,4) < 4: return false
	var rng: RandomNumberGenerator = Pasture.state(world).rng
	var source: Vector3i = nearby[rng.randi_range(0,nearby.size()-1)]
	return spread_from(world,p,source)

static func decay(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != MYCELIUM or not covered(world,p): return false
	return world.set_node(p,Nodes.DIRT)

# _after_grow for a 2x2 spruce. find_nodes_in_area_under_air searches the exact
# inclusive 13^3 volume for group:dirt, sorts by Euclidean distance, then converts
# random(min(count,2),count) entries. One candidate converts once; none converts none.
static func after_giant_spruce(world: VoxelWorld, origin: Vector3i, rng: RandomNumberGenerator = null) -> int:
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var found: Array = []
	for y in range(-GIANT_SPRUCE_RADIUS,GIANT_SPRUCE_RADIUS+1):
		for z in range(-GIANT_SPRUCE_RADIUS,GIANT_SPRUCE_RADIUS+1):
			for x in range(-GIANT_SPRUCE_RADIUS,GIANT_SPRUCE_RADIUS+1):
				var q: Vector3i = origin+Vector3i(x,y,z)
				if not world.loaded_at(Vector3(q)) or world.node_at(q+Vector3i.UP) != Nodes.AIR: continue
				if FarmingRules.group(world.node_at(q),"dirt") > 0: found.append(q)
	found.sort_custom(func(a: Vector3i,b: Vector3i) -> bool: return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	var count: int = rng.randi_range(mini(found.size(),2),found.size())
	var converted: int = 0
	for i in count:
		if world.set_node(found[i],PODZOL): converted += 1
	return converted

# _on_shovel_place is copied to snowy definitions too. There is intentionally no
# hoe or water-bottle branch: these nodes lack cultivatable/converts_to_mud.
static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not pathable(int(target.id)): return false
	if Nodes.tool_kind(int(game.inventory.held().id)) != 2: return false
	var p: Vector3i = target.pos
	if target.get("normal",Vector3i.UP).y < 0: return true
	if not game.world.loaded_at(Vector3(p+Vector3i.UP)) or game.world.node_at(p+Vector3i.UP) != Nodes.AIR: return true
	if game.world.set_node(p,VillageContent.PATH):
		if game.gamemode != "creative": ToolCapabilities.action_wear(game.inventory)
		game.sound("dig"); game.player.swing = 1
	return true
