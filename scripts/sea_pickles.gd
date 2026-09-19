class_name SeaPickles
extends RefCounted

# Mineclonia ITEMS/mcl_ocean/sea_pickle.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# A sea pickle is a small glowing growth that lives on **dead brain coral**. The
# source registers eight nodes: four sizes, each in a lit and an unlit form.
#
#   * Size controls light: 6, 9, 12 and the maximum 15 for sizes one to four.
#   * Placing a pickle on another grows it one size, if it is not already at
#     size four.
#   * The lit form requires a water source directly **above** it. The source's
#     ABM toggles between lit and unlit on the same 17 second interval with a
#     1-in-5 chance that coral uses.
#   * Bone meal grows it one size and spreads pickles to sixteen offsets around
#     it, each placement randomised to a size of one to three.
#   * Breaking one drops `size` pickles, which is the source's `" "..s` count.
#
# Voxey has dead brain coral already. This is the remaining half of the ocean
# content that does not need a mob or an ocean-biome generator.

const FIRST = VillageContent.PICKLE_FIRST
# Four sizes, lit then unlit: lit = base, unlit = base+4.
const SIZES = 4
const LIGHT = [6,9,12,15]
# Source `possible_position`: the sixteen offsets bone meal spreads to.
const SPREAD_OFFSETS = [
	Vector3i(2,0,0),Vector3i(-2,0,0),Vector3i(1,0,0),Vector3i(-1,0,0),
	Vector3i(0,0,1),Vector3i(0,0,-1),Vector3i(0,0,2),Vector3i(0,0,-2),
	Vector3i(1,-1,0),Vector3i(-1,-1,0),Vector3i(0,-1,1),Vector3i(0,-1,-1),
	Vector3i(1,0,1),Vector3i(1,0,-1),Vector3i(-1,0,1),Vector3i(-1,0,-1),
]
const UPDATE_INTERVAL = 17.0
const UPDATE_CHANCE = 5

static func is_pickle(id: int) -> bool: return index(id) >= 0

static func index(id: int) -> int:
	var i: int = id-FIRST
	return i if i >= 0 and i < SIZES*2 else -1

# Sizes are 1-4; the lit and unlit runs are four apart.
static func size(id: int) -> int:
	var i: int = index(id)
	return (i%SIZES)+1 if i >= 0 else 0
static func lit(id: int) -> bool: return index(id) >= 0 and index(id) < SIZES
static func for_size(size_index: int, lit_form: bool) -> int:
	return FIRST+clampi(size_index-1,0,SIZES-1)+(0 if lit_form else SIZES)
static func light_level(id: int) -> int:
	var s: int = size(id)
	return LIGHT[s-1] if s > 0 and lit(id) else 0
static func title(id: int) -> String: return "Sea pickle"

# The source's parent: sea pickles only live on dead brain coral.
static func on_parent(world: VoxelWorld, at: Vector3i) -> bool:
	return world.node_at(at-Vector3i.UP) == Corals.living_id(1,Corals.DEAD_BLOCK)

# Lit form requires water directly above, which is also what the ABM toggles on.
static func wants_lit(world: VoxelWorld, p: Vector3i) -> bool:
	return Fluids.water(world.node_at(p+Vector3i.UP))

# --- interaction -------------------------------------------------------------

# Placing on another pickle grows it one size, up to four.
static func grow(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_pickle(id): return false
	var s: int = size(id)
	if s >= SIZES: return false
	return world.set_node(p,for_size(s+1,lit(id)))

# `on_bone_meal`: one growth step, then a spread attempt to each offset. Each new
# pickle is randomised to a size of one to three, as the source does.
static func bone_meal(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator) -> void:
	grow(world,p)
	for offset in SPREAD_OFFSETS:
		var at: Vector3i = p+offset
		# The source tests the block above the offset, which is where the pickle
		# itself sits for a rooted plant.
		if world.node_at(at) != Nodes.AIR: continue
		if not on_parent(world,at): continue
		var stage: int = rng.randi_range(1,3)
		world.set_node(at,for_size(stage,wants_lit(world,at)))
		registered(world,at,world.node_at(at))

# A pickle must sit on dead brain coral, and may be stacked to grow.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if not is_pickle(held) or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var existing: int = world.node_at(at)
	# Placing onto an existing pickle grows it rather than adding a second node.
	if is_pickle(existing) or is_pickle(world.node_at(target.pos)):
		var grow_at: Vector3i = at if is_pickle(existing) else target.pos
		if grow(world,grow_at):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place"); game.player.swing = 1
			return true
		return true
	if existing != Nodes.AIR and not Nodes.plant(existing) and not Fluids.liquid(existing): return true
	if not on_parent(world,at):
		game.toast("Sea pickles must be placed on dead brain coral.")
		return true
	if not world.set_node(at,for_size(1,wants_lit(world,at))): return true
	registered(world,at,world.node_at(at))
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,world.node_at(at))
	return true

# --- simulation --------------------------------------------------------------

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("pickles"): return
	var tracked: Dictionary = world.get_meta("pickles")
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < UPDATE_INTERVAL:
		tracked["clock"] = clock
		world.set_meta("pickles",tracked)
		return
	tracked["clock"] = 0.0
	var rng: RandomNumberGenerator = Corals._rng(world)
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		var id: int = world.node_at(p)
		if not is_pickle(id): tracked.erase(p); continue
		if rng.randi_range(1,UPDATE_CHANCE) != 1: continue
		# The source toggles lit and unlit in both directions.
		var should_lit: bool = wants_lit(world,p)
		if should_lit != lit(id): world.set_node(p,for_size(size(id),should_lit))
	world.set_meta("pickles",tracked)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("pickles"): world.set_meta("pickles",{})
	return world.get_meta("pickles")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_pickle(id): return
	var tracked: Dictionary = _tracked(world)
	tracked[p] = true
	world.set_meta("pickles",tracked)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _tracked(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	world.set_meta("pickles",tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("pickles"): world.set_meta("pickles",{})

# --- art --------------------------------------------------------------------

static func color(id: int) -> Color:
	return Color("7fd06a") if lit(id) else Color("4f7a44")

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	# The parent block shows through around the pickle, as rooted plants do.
	var base: Color = Color("7a5f57")
	var s: int = size(id)
	# A taller stalk per size, brighter when lit.
	if absf(x-7.5) > 1+s : return base
	return color(id) if y > 12-3*s else base

static func draw(img: Image, id: int) -> void:
	var s: int = size(id)
	var base: Color = color(id)
	img.fill_rect(Rect2i(4,14-s*2,8,s*2+1),base.darkened(0.15))
	for i in s:
		img.fill_rect(Rect2i(6,12-i*3,4,3),base)
	img.fill_rect(Rect2i(7,13-s*2,2,1),Color("e8ffd8"))

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	# The parent block is drawn by the block beneath; the pickle is the stalk.
	BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(1,1,1),tile,tile)
	var s: float = float(size(id))
	BlockMesher._art_box(out,p+Vector3(0.5,0.5+s*0.11,0.5),Vector3(0.3,0.22*s,0.3),tile,tile)
