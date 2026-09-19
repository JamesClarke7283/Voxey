class_name Concrete
extends RefCounted

# Mineclonia ITEMS/mcl_colorblocks/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; all art is original procedural code.
#
# The source registers four colour families in one loop over `mcl_dyes.colors`:
# uncoloured `hardened_clay`, then per colour `hardened_clay_<c>`,
# `concrete_powder_<c>`, `concrete_<c>` and `glazed_terracotta_<c>`. Voxey already
# had the terracotta and glazed terracotta halves (ids 603-618 and 619-634); this
# module closes the missing **concrete** half. Its DATA entries sit beside the
# terracotta ones in `VillageContent.DATA`, which is where this project keeps
# colour families, and the behaviour lives here.
#
# Source rules reproduced here:
# - Concrete powder is a `falling_node` with the `float` group, so an unsupported
#   column comes down like sand, which `Nodes.falls` reports for these ids.
# - Water contact hardens powder into concrete of the *same* colour, through two
#   paths in the source: `on_construct` (placing powder into water, or water into
#   powder) and an ABM with `interval = 1, chance = 1` over
#   `group:concrete_powder` with `neighbors = {"group:water"}`.
# - The ABM has a second half that matters: if the cell *below* the powder is
#   water, the concrete is written into that water cell and the powder cell is
#   cleared, then falling is re-checked for any powder stacked above. That is what
#   makes powder dropped into water sink and harden rather than float.
# - Recipe: `concrete_powder_<c> 8` shapeless from four sand, four gravel and one
#   dye. Concrete is not craftable directly; it only comes from hardening.

# Concrete powder, then concrete, in Voxey's colour order (the order of
# `VillageContent.DYE_WHITE`..`DYE_BROWN`).
const POWDER_FIRST = 11040
const BLOCK_FIRST = 11056
const COUNT = 16
const COLORS = ["white","grey","silver","black","yellow","orange","red","magenta","purple","blue","cyan","lime","green","pink","light_blue","brown"]

static func is_powder(id: int) -> bool: return id >= POWDER_FIRST and id < POWDER_FIRST+COUNT
static func is_concrete(id: int) -> bool: return id >= BLOCK_FIRST and id < BLOCK_FIRST+COUNT
static func is_concrete_family(id: int) -> bool: return is_powder(id) or is_concrete(id)
static func index(id: int) -> int:
	if is_powder(id): return id-POWDER_FIRST
	return id-BLOCK_FIRST if is_concrete(id) else -1
# The concrete a powder hardens into, or 0 when the block is not powder.
static func hardened(id: int) -> int: return BLOCK_FIRST+index(id) if is_powder(id) else 0

# Source `register_craft`: `concrete_powder_<c> 8` shapeless from sand, gravel,
# sand / gravel, dye, gravel / sand, gravel, sand. Concrete itself has no recipe:
# it is what powder becomes in water.
static func recipes(inv: Inventory) -> void:
	for i in COUNT:
		inv._shapeless(
			"%s concrete powder"%COLORS[i].replace("_"," ").capitalize(),
			POWDER_FIRST+i, 8,
			[Nodes.SAND,Nodes.GRAVEL,Nodes.SAND,Nodes.GRAVEL,VillageContent.DYE_WHITE+i,Nodes.GRAVEL,Nodes.SAND,Nodes.GRAVEL,Nodes.SAND])

# --- water hardening ---------------------------------------------------------

# A one-block search for any water, which is `core.find_node_near(pos, 1,
# {"group:water"})` in the source's `on_construct`.
static func nearby_water(world: VoxelWorld, p: Vector3i) -> bool:
	for d in [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP,Vector3i.DOWN]:
		if Fluids.water(world.node_at(p+d)): return true
	return false

# The ABM body. Hardens in place, unless the cell below is water, in which case the
# concrete is written into that water cell and this cell is cleared, then falling
# is re-checked so powder stacked above drops into the space.
static func harden(world: VoxelWorld, p: Vector3i) -> bool:
	var target: int = hardened(world.node_at(p))
	if target == 0: return false
	var below: Vector3i = p+Vector3i.DOWN
	if Fluids.water(world.node_at(below)):
		if not world.set_node(below,target): return false
		world.set_node(p,Nodes.AIR)
		# `core.check_for_falling(pos)`: the powder resting on this cell now has
		# nothing under it, so the column comes down.
		var game: Node = world.get_parent()
		if game != null and game.has_method("settle"): game.settle(below+Vector3i.UP)
		return true
	return world.set_node(p,target)

# The sweep over tracked powder cells, run from the world's active simulation.
# The source's ABM is `interval = 1, chance = 1`, so every tracked cell is tested
# each second with no roll.
static func update(world: VoxelWorld, delta: float) -> void:
	var tracked: Dictionary = _tracked(world)
	if tracked.is_empty(): return
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < 1.0:
		tracked["clock"] = clock
		world.set_meta("concrete",tracked)
		return
	tracked["clock"] = 0.0
	# `harden` calls `set_node`, whose tail calls `changed` -> `placed_powder`, which
	# erases keys from this very dictionary. Godot ends a Dictionary loop as soon as a
	# key is erased, so iterating `tracked` directly hardened exactly one cell per
	# sweep. Iterate a snapshot of the keys instead.
	var done: Array = []
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		if not world.loaded_at(Vector3(p)): continue
		if not is_powder(world.node_at(p)) or not nearby_water(world,p): done.append(p); continue
		if harden(world,p): done.append(p)
	for p in done: tracked.erase(p)
	world.set_meta("concrete",tracked)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("concrete"): world.set_meta("concrete",{})
	return world.get_meta("concrete")

# Powder cells are tracked so the sweep has a bounded working set, exactly as the
# other stateful modules do.
static func placed_powder(world: VoxelWorld, p: Vector3i, id: int) -> void:
	var tracked: Dictionary = _tracked(world)
	if is_powder(id): tracked[p] = true
	else: tracked.erase(p)
	world.set_meta("concrete",tracked)

# Called from `VoxelWorld.set_node` for every change. A cell stops being tracked
# once it is no longer powder, and a freshly placed powder cell in or beside water
# hardens immediately, which is the source's `on_construct`.
static func changed(world: VoxelWorld, p: Vector3i, _old_id: int, id: int) -> void:
	placed_powder(world,p,id)
	if is_powder(id) and nearby_water(world,p): harden(world,p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _tracked(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	world.set_meta("concrete",tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("concrete"): world.set_meta("concrete",{})

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if is_powder(id):
		# Powder is granular: dense speckle plus a slightly darker lower half, which
		# reads as a loose pile rather than a solid block.
		var grain: float = float((x*7+y*13+x*y*3)%5)*0.018
		var c: Color = base.darkened(grain)
		if y > 9: c = c.darkened(0.05)
		if (x*11+y*5)%17 < 2: c = c.lightened(0.10)
		return noise.lerp(c,0.62)
	# Concrete is smooth and clean, with only a faint mottle so a wall does not
	# read as a flat colour.
	if (x*5+y*3)%23 == 0: return noise.lerp(base,0.82).lightened(0.04)
	return noise.lerp(base,0.86)
