class_name LushCaves
extends RefCounted

# Mineclonia ITEMS/mcl_lush_caves/{nodes,crafting}.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference; art is original procedural
# code.
#
# Lush caves are the source's *lit* cave biome, and the light comes from one thing
# in particular:
#
#   * **Cave vines** hang from a ceiling and are climbable. Their lit form carries
#     **glow berries** and emits light 14, which is what makes a lush cave visible
#     without a torch.
#   * **Bone meal** turns an unlit vine's tip lit, which is how berries are grown
#     rather than only found.
#   * **Right-clicking a lit vine** picks a glow berry and reverts the vine to its
#     unlit form, so a berry is harvested without breaking the vine.
#   * A glow berry is **food** worth two points, and can be planted back onto a
#     vine's underside.
#
# The rest of the set — moss, moss carpet, hanging roots and rooted dirt — is
# decorative ground cover that completes the biome's look.

# The vine's two forms, and the berry they carry.
const CAVE_VINES = 1177
const CAVE_VINES_LIT = 1178
const GLOW_BERRY = 1179
# The three ground-cover blocks of the biome.
const MOSS = 1204
const MOSS_CARPET = 1205
const HANGING_ROOTS = 1206
const BLOCKS = [CAVE_VINES,CAVE_VINES_LIT,MOSS,MOSS_CARPET,HANGING_ROOTS]

# Source `light_source = 14` on the lit vine.
const LIT_LIGHT = 14
# Source `groups = {food = 2, eatable = 2}` on the berry.
const BERRY_FOOD = 2
# Source `compostability = 50`.
const BERRY_COMPOST = 50
# The berry is worth this much saturation in the source.
const BERRY_SATURATION = 1.2

# Whether a node can be climbed. The source gives a cave vine `climbable = true`, so
# a player can hold forward against a hanging strand and go up it, exactly as with a
# ladder. A lit or unlit vine climbs alike.
static func climbable(world: VoxelWorld, cell: Vector3i) -> bool:
	return is_vine(world.node_at(cell))

static func is_vine(id: int) -> bool: return id == CAVE_VINES or id == CAVE_VINES_LIT
static func is_lit_vine(id: int) -> bool: return id == CAVE_VINES_LIT
static func is_glow_berry(id: int) -> bool: return id == GLOW_BERRY

# A constant with literal keys, so the content table can reference it without a
# const cycle.
const BLOCK_DATA = {
	1177: {"name":"Cave vines","block":true,"shape":"vine","color":"5d8b3c","hardness":0.0,"tool":2,"plant":true,"climbable":true},
	1178: {"name":"Lit cave vines","block":true,"shape":"vine","color":"7fae4a","hardness":0.0,"tool":2,"plant":true,"climbable":true,"light":LIT_LIGHT,"emits":LIT_LIGHT},
	1204: {"name":"Moss block","block":true,"color":"5a7a3c","hardness":0.5,"tool":2},
	1205: {"name":"Moss carpet","block":true,"shape":"carpet","color":"5a7a3c","hardness":0.1,"tool":2},
	1206: {"name":"Hanging roots","block":true,"shape":"plant","color":"6b5636","hardness":0.0,"tool":2,"plant":true},
}

# --- the vine's light --------------------------------------------------------

# A vine's light, which is what makes a lush cave visible.
static func light_level(id: int) -> int:
	return LIT_LIGHT if is_lit_vine(id) else 0

# --- growing berries ---------------------------------------------------------

# Turn a vine's *tip* lit, which is the source's bone-meal behaviour: it lights the
# tip rather than the whole vine, so berries grow where they can be reached.
static func ripen(world: VoxelWorld, p: Vector3i) -> bool:
	var tip: Vector3i = vine_tip(world,p)
	if world.node_at(tip) != CAVE_VINES: return false
	return world.set_node(tip,CAVE_VINES_LIT)

# The lowest vine cell of the tower a vine belongs to, which is where berries grow.
static func vine_tip(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var tip: Vector3i = p
	while is_vine(world.node_at(tip+Vector3i.DOWN)): tip += Vector3i.DOWN
	return tip

# The topmost vine cell, which is the one attached to the ceiling.
static func vine_top(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var top: Vector3i = p
	while is_vine(world.node_at(top+Vector3i.UP)): top += Vector3i.UP
	return top

# --- harvesting --------------------------------------------------------------

# Pick a berry from a lit vine, which reverts it to the unlit form. The source does
# this on right-click, so the vine survives and can fruit again.
static func harvest(world: VoxelWorld, p: Vector3i) -> bool:
	if not is_lit_vine(world.node_at(p)): return false
	return world.set_node(p,CAVE_VINES)

# --- vines need a ceiling ----------------------------------------------------

# Whether a vine may hang at `p`: the source's `vinelike_node` needs something solid
# above it, or another vine. `Vector3i.UP` is positive Y, so the cell above is `p+UP`.
static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var above: int = world.node_at(p+Vector3i.UP)
	return is_vine(above) or Nodes.solid(above)

# --- ground cover ------------------------------------------------------------

# The ground cover the source's biome uses: moss grows on stone or dirt, and rooted
# dirt is dirt turned by a hanging root.
static func cover_soil(id: int) -> bool:
	return id in [Nodes.DIRT,Nodes.STONE,Nodes.COBBLE,Nodes.GRASS]

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source `mcl_lush_caves/crafting.lua`: a moss block beside a cobble makes mossy
	# cobble, and a moss block beside a stone brick makes mossy stone bricks. Both
	# are the recipes Voxey previously could not offer because moss did not exist.
	inv._shapeless("Mossy cobblestone",Nodes.MOSSY_COBBLE,1,[Nodes.COBBLE,MOSS])
	inv._shapeless("Mossy stone bricks",1161,1,[Nodes.BRICKS,MOSS])
	# Source `mcl_lush_caves/nodes.lua:109`: two moss make three moss carpet, which
	# was the one missing recipe in this family.
	inv._recipe("Moss carpet",1205,3,[MOSS,MOSS],2)

# --- art ---------------------------------------------------------------------

# A vine is a hanging strand with berries on the lit form, and moss is a rough
# green ground cover.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_vine(id):
		# Two strands with a gap between, so a vine reads as thin rather than solid.
		if x in [5,6] or x in [9,10]:
			var stem: Color = Color("5d8b3c") if id == CAVE_VINES else Color("7fae4a")
			# A lit vine carries round berries along its length.
			if id == CAVE_VINES_LIT and y%5 == 2: return Color("e8b34a")
			return stem.darkened(0.1*float((x+y)%3))
		return Color(0,0,0,0)
	if id == MOSS: return Color("5a7a3c").darkened(0.09*float((x*3+y*5)%3))
	if id == MOSS_CARPET: return Color("5a7a3c").darkened(0.06*float((x+y)%3)) if y > 3 else Color(0,0,0,0)
	if id == HANGING_ROOTS:
		return Color("6b5636").darkened(0.1*float((x*5+y)%3)) if x in [3,7,11] else Color(0,0,0,0)
	if is_glow_berry(id):
		# A berry with its own glow, which is what the item represents.
		return Color("e8b34a") if (x-7)*(x-7)+(y-9)*(y-9) < 14 else Color(0,0,0,0)
	return Color(0,0,0,0)
