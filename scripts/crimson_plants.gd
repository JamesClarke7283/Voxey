class_name CrimsonPlants
extends RefCounted

# Mineclonia ITEMS/mcl_crimson/init.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference; all art is original procedural code.
#
# Voxey had the crimson and warped *stems* and `shroomlight`, but none of the
# biome's plants. This module adds the rest of the family:
#
# - **Crimson and warped fungus**: the two mushrooms, each with a `light_source = 1`.
#   A fungus only survives on its own nylium (`soil_fungus`), and bone meal grows a
#   huge fungus from it on the source's 40% roll.
# - **Crimson and warped roots**, **nether sprouts**: `plantlike` decorations that
#   drop only to shears, exactly as the source's `_mcl_shears_drop` says.
# - **Twisting and weeping vines**: `climbable` strands that grow **downward** from
#   the cell they are placed against, one to three blocks per bone-meal use. Twisting
#   vines grow down from a ceiling and weeping vines hang from a block.
# - **Warped wart block**: a plain decorative cube with the source's hoe preference.
#
# The two `nylium` soils already exist in Voxey as `CRIMSON_NYLIUM` and
# `WARPED_NYLIUM`, so the fungi and roots bind to them.

const CRIMSON_FUNGUS = 11511
const WARPED_FUNGUS = 11512
const CRIMSON_ROOTS = 11513
const WARPED_ROOTS = 11514
const NETHER_SPROUTS = 11515
const TWISTING_VINES = 11516
const WEEPING_VINES = 11517
const WARPED_WART_BLOCK = 11518
const COUNT = 8
const BLOCKS = [11511,11512,11513,11514,11515,11516,11517,11518]

const DATA = {
	# Source `light_source = 1` on both fungi, `groups.mushroom`.
	CRIMSON_FUNGUS:{"name":"Crimson fungus","block":true,"shape":"plant","color":"8d2a2a","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_plant","soil":"crimson","light":1,"mushroom":true,"compostability":65},
	WARPED_FUNGUS:{"name":"Warped fungus","block":true,"shape":"plant","color":"4a8d8a","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_plant","soil":"warped","light":1,"mushroom":true,"compostability":65},
	# Roots and sprouts are `_mcl_shears_drop`: nothing by hand, themselves to shears.
	CRIMSON_ROOTS:{"name":"Crimson roots","block":true,"shape":"plant","color":"a8394a","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_plant","soil":"crimson","compostability":65},
	WARPED_ROOTS:{"name":"Warped roots","block":true,"shape":"plant","color":"2f7d78","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_plant","soil":"warped","compostability":65},
	NETHER_SPROUTS:{"name":"Nether sprouts","block":true,"shape":"plant","color":"4f9a86","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_plant","compostability":50},
	# Vines are `climbable` and grow downward in one-to-three block steps.
	TWISTING_VINES:{"name":"Twisting vines","block":true,"shape":"plant","color":"1f6f8b","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_vine","vine":"twisting","climbable":true,"compostability":50},
	WEEPING_VINES:{"name":"Weeping vines","block":true,"shape":"plant","color":"7a1f2b","hardness":0.0,"tool":-1,"transparent":true,"family":"nether_vine","vine":"weeping","climbable":true,"compostability":50},
	# A plain cube with the source's hoe preference (`hoey = 7`), hardness 1.
	WARPED_WART_BLOCK:{"name":"Warped wart block","block":true,"shape":"cube","color":"1f6f66","hardness":1.0,"tool":4,"family":"nether_plant","compostability":85},
}

# The source's `soil_fungus` group: a fungus only survives on its own nylium.
static func soil(id: int) -> String:
	return str(DATA.get(id,{}).get("soil",""))

static func is_fungus(id: int) -> bool: return id == CRIMSON_FUNGUS or id == WARPED_FUNGUS
static func is_vine(id: int) -> bool:
	var family: String = DATA.get(id,{}).get("family","")
	return family == "nether_vine"

static func is_plant(id: int) -> bool:
	var family: String = DATA.get(id,{}).get("family","")
	return family == "nether_plant"

static func light_level(id: int) -> int: return int(DATA.get(id,{}).get("light",0))

# `on_place`: a fungus is refused on the wrong soil, which the source's
# `place_fungus` enforces.
static func placement_ok(world: VoxelWorld, at: Vector3i, id: int) -> bool:
	if not is_fungus(id): return true
	var below: int = world.node_at(at+Vector3i.DOWN)
	return below == (Nodes.CRIMSON_NYLIUM if soil(id) == "crimson" else Nodes.WARPED_NYLIUM)

# `grow_vines`: one to three blocks downward, each step in the empty cell below the
# last, from the source's `math.random(1, 3)`.
static func grow(world: VoxelWorld, from: Vector3i, id: int, rng: RandomNumberGenerator = null) -> int:
	if not is_vine(id): return 0
	var steps: int = rng.randi_range(1,3) if rng != null else randi_range(1,3)
	var grown: int = 0
	var at: Vector3i = from
	for i in steps:
		var next: Vector3i = at+Vector3i.DOWN
		var below: int = world.node_at(next)
		if below != Nodes.AIR and below != id: break
		if not world.set_node(next,id): break
		# A step onto an existing strand still counts, which the source allows so a
		# vine bridges a gap.
		at = next
		grown += 1
	return grown

# `_on_bone_meal` for a fungus: the source's 40% roll, and only on its own nylium.
# The grown structure is the one the source's own schematics encode — every
# `mcl_crimson/schematics/*.mts` is a stem of `tree_crimson`/`tree_warped` carrying a
# cap of the matching wart block with `shroomlight` set into it — built here as a
# generator rather than loaded from a schematic, because Voxey has no `.mts` reader.
static func bone_meal_fungus(world: VoxelWorld, at: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	var id: int = world.node_at(at)
	if not is_fungus(id) or not placement_ok(world,at,id) or at.y <= world.generator.min_y(): return false
	var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
	if roll > 40: return false
	return grow_huge(world,at,id,rng)

# The huge form's own numbers, read off the source's schematics: a stem of three to
# five blocks and a cap two blocks out from the stem.
const STEM_MIN = 3
const STEM_SPAN = 2
const CAP_RADIUS = 2
const SHROOMLIGHT_CHANCE = 4

# Grow a huge fungus where a small one stood. Returns false when there is no room,
# which the source's own `check_for_bedrock`/room test also refuses.
static func grow_huge(world: VoxelWorld, at: Vector3i, id: int, rng: RandomNumberGenerator = null) -> bool:
	var stem: int = Nodes.CRIMSON_STEM if soil(id) == "crimson" else Nodes.WARPED_STEM
	var cap: int = NetherBlocks.NETHER_WART_BLOCK if soil(id) == "crimson" else WARPED_WART_BLOCK
	var height: int = STEM_MIN+(rng.randi_range(0,STEM_SPAN) if rng != null else randi_range(0,STEM_SPAN))
	# The whole stem must fit, so a blocked column refuses the growth outright rather
	# than growing a partial fungus.
	for i in range(1,height+1):
		if not world.loaded_at(Vector3(at)+Vector3(0,i,0)): return false
		if world.node_at(at+Vector3i.UP*i) != Nodes.AIR: return false
	var top: Vector3i = at+Vector3i.UP*height
	world.set_node(at,stem)
	for i in range(1,height): world.set_node(at+Vector3i.UP*i,stem)
	# The cap: a two-out square disc of wart block with shroomlight set into it.
	for dx in range(-CAP_RADIUS,CAP_RADIUS+1):
		for dz in range(-CAP_RADIUS,CAP_RADIUS+1):
			var edge: int = absi(dx)+absi(dz)
			if edge > CAP_RADIUS+1: continue
			var cell: Vector3i = top+Vector3i(dx,0,dz)
			if not world.loaded_at(Vector3(cell)): continue
			if world.node_at(cell) != Nodes.AIR and cell != at: continue
			var lit: bool = edge <= 1 and (rng.randi_range(1,SHROOMLIGHT_CHANCE) if rng != null else randi_range(1,SHROOMLIGHT_CHANCE)) == 1
			world.set_node(cell,Nodes.SHROOMLIGHT if lit else cap)
	world.set_node(top,stem)
	return true

# The shears drop: a root, sprout or vine yields itself only to shears, which the
# source's `_mcl_shears_drop` arranges.
static func harvest(id: int, slot: Dictionary) -> Array:
	if not is_plant(id) and not is_vine(id): return []
	if is_fungus(id) or id == WARPED_WART_BLOCK: return [[id,1]]
	return [[id,1]] if int(slot.get("id",0)) == Nodes.SHEARS else []

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if id == WARPED_WART_BLOCK:
		# A dense, slightly luminous wart mass.
		if (x/2*3+y/2*5)%7 < 2: return base.darkened(0.3)
		return noise.lightened(0.07) if (x+y)%5 == 0 else noise
	if is_vine(id):
		# A thin strand down the centre with a leaf node every few pixels.
		if absi(x-7) > 1: return Color(0,0,0,0)
		if y%5 in [2,3] and absf(x-7) <= 1: return base.lightened(0.18)
		return base if y%3 != 0 else base.darkened(0.15)
	if is_fungus(id):
		# A mushroom: a stalk with a cap.
		if y < 6: return base if absi(x-7) <= 3 else Color(0,0,0,0)
		if absi(x-7) <= 1: return Color("d8d2c0").darkened(0.2)
		return Color(0,0,0,0)
	# A root or sprout is a tuft of thin fronds.
	if y > 12 and absf(x-7.5) > 1.5+float(15-y)*0.5: return Color(0,0,0,0)
	return base.darkened(0.1) if (x+y)%4 == 0 else base
