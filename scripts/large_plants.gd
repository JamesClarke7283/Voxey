class_name LargePlants
extends RefCounted

# Mineclonia ITEMS/mcl_flowers/register.lua (`mcl_flowers.add_large_plant`),
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference;
# the bottom halves are drawn procedurally and the four top-half bloom tiles are
# drawn in GIMP (`assets/textures/tiles/tile_<top_id>.png`).
#
# A **large plant** occupies two cells: a bottom half that carries the stem and a
# top half that carries the bloom. The two halves are separate nodes, placed
# together and removed together, and only the bottom drops the item. The source's
# own facts, reproduced here:
#
#   * `selbox_radius = 5/16` — the selection box is wider than the 2px cross of a
#     small plant, so the bloom is easy to target.
#   * Every large plant is `is_flower = true`, so it goes through the flower
#     placement rules (`soil_flower` + light) and yields **two** of its dye.
#   * Bone meal on the bottom half drops one more of the plant (`_on_bone_meal`).
#   * The sunflower is the odd one out: it is *not* `is_flower`, is drawn from four
#     tiles, and yields two yellow dye.
#
# Voxey keeps one id per half. The two ids sit beside each other so the pair is a
# range test, and `bottom(id)`/`top(id)` map between them.

const PEONY = 11418
const ROSE_BUSH = 11420
const LILAC = 11422
const SUNFLOWER = 11424
# The ids run bottom, top, bottom, top, ... so a pair is `[even, odd]`.
const BOTTOMS = [PEONY,ROSE_BUSH,LILAC,SUNFLOWER]
const BLOCKS = [PEONY,PEONY+1,ROSE_BUSH,ROSE_BUSH+1,LILAC,LILAC+1,SUNFLOWER,SUNFLOWER+1]

# The dye each large plant yields, two at a time (source `_mcl_crafting_output`).
const DYE = {PEONY:VillageContent.DYE_PINK,ROSE_BUSH:VillageContent.DYE_RED,LILAC:VillageContent.DYE_MAGENTA,SUNFLOWER:VillageContent.DYE_YELLOW}

# Source `soil_flower` for every large plant.
const SOIL = [Nodes.GRASS,Nodes.DIRT,VillageContent.SWAMP_GRASS,VillageContent.MUD,LushCaves.MOSS,Nodes.CLAY,Farmland.DRY,Farmland.WET]

const DATA = {
	PEONY:{"name":"Peony","block":true,"shape":"plant","color":"e07aa0","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:peony"},
	PEONY+1:{"name":"Peony","block":true,"shape":"plant","color":"e07aa0","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:peony"},
	ROSE_BUSH:{"name":"Rose bush","block":true,"shape":"plant","color":"b83d41","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:rose_bush"},
	ROSE_BUSH+1:{"name":"Rose bush","block":true,"shape":"plant","color":"b83d41","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:rose_bush"},
	LILAC:{"name":"Lilac","block":true,"shape":"plant","color":"b878cc","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:lilac"},
	LILAC+1:{"name":"Lilac","block":true,"shape":"plant","color":"b878cc","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:lilac"},
	SUNFLOWER:{"name":"Sunflower","block":true,"shape":"plant","color":"e8c23a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:sunflower"},
	SUNFLOWER+1:{"name":"Sunflower","block":true,"shape":"plant","color":"e8c23a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:sunflower"},
}

static func is_large(id: int) -> bool: return id in BLOCKS
static func is_bottom(id: int) -> bool: return id in BOTTOMS
static func is_top(id: int) -> bool: return is_large(id) and not is_bottom(id)
static func bottom(id: int) -> int: return id if is_bottom(id) else id-1
static func top(id: int) -> int: return id+1 if is_bottom(id) else id
static func dye_of(id: int) -> int: return int(DYE.get(bottom(id),0))
static func color(id: int) -> Color: return Color(DATA[id].color)

# Source places the pair straight up on the bottom's own soil.
static func can_place(world: VoxelWorld, at: Vector3i) -> bool:
	if not SOIL.has(world.node_at(at-Vector3i.UP)): return false
	# Flower light rule: artificial light eight, or unobstructed daytime sky.
	if Pasture.block_light(world,at,8) >= 8: return true
	if world.dimension != "overworld" or not world.loaded_at(Vector3(at)): return false
	RedstoneSensors.natural_light(world,at)
	return RedstoneSensors._natural_light(world,at,14) >= 14

# Place both halves. Returns false (and places nothing) if the upper cell is not
# free, so a large plant never half-forms.
static func place(game: Node3D, at: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if not can_place(world,at): return false
	var above: int = world.node_at(at+Vector3i.UP)
	if above != Nodes.AIR and not Nodes.plant(above): return false
	if not world.set_node(at,PEONY+(_bottom_from_held(game.inventory.held().id))): return false
	var bottom_id: int = world.node_at(at)
	if not world.set_node(at+Vector3i.UP,top(bottom_id)):
		world.set_node(at,Nodes.AIR)
		return false
	return true

# Kept explicit so the placement id stays readable.
static func _bottom_from_held(held: int) -> int: return bottom(held)-PEONY

# The pairing on break: removing either half removes the other, and only the bottom
# yields the item, which is the source's `after_dig_node`.
static func partner(world: VoxelWorld, p: Vector3i, id: int) -> Vector3i:
	var other: Vector3i = p+Vector3i.UP if is_bottom(id) else p+Vector3i.DOWN
	var want: int = top(id) if is_bottom(id) else bottom(id)
	return other if world.node_at(other) == want else p

# --- art ---------------------------------------------------------------------

# The bottom half draws the lower stem; the top half draws the stem's upper part
# and the bloom. Both are drawn as a thin cross so the two cells read as one plant.
const STEM = "548448"

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = color(id)
	if is_bottom(id):
		# Lower stem with a small leaf either side.
		if x in [7,8] and y >= 4: return Color(STEM)
		if y in [9,10] and x in [4,5,6]: return Color(STEM)
		if y in [11,12] and x in [9,10,11]: return Color(STEM)
		return Color.TRANSPARENT
	# Upper half: stem lower third, then the bloom above it.
	if x in [7,8] and y >= 9: return Color(STEM)
	return bloom_pixel(id,x,y,base,noise)

static func bloom_pixel(id: int, x: int, y: int, base: Color, _noise: Color) -> Color:
	var dx: int = x-7
	var dy: int = y-4
	if bottom(id) == SUNFLOWER:
		# A sunflower: a broad yellow head with a dark seed disc at its centre.
		var r: float = Vector2(x-7.5,y-5.0).length()
		if r > 6.0: return Color.TRANSPARENT
		if r > 4.6 and (x+y)%2 == 1: return Color.TRANSPARENT
		if r < 2.6: return Color("5a4326")
		return base.lightened(0.22 if (x*3+y*5)%4 == 0 else 0.0)
	if bottom(id) == PEONY:
		# A peony: overlapping rounded petals.
		var r: float = Vector2(x-7.5,y-4.5).length()
		if r > 5.0: return Color.TRANSPARENT
		if r < 1.6: return base.lightened(0.3)
		return base.lightened(0.14 if (x+y)%2 == 0 else 0.0).darkened(0.12 if r > 4.0 else 0.0)
	if bottom(id) == ROSE_BUSH:
		# A rose: a tight ring of petals around a darker heart.
		var r: float = Vector2(x-7.5,y-4.5).length()
		if r > 4.6: return Color.TRANSPARENT
		if r > 3.6 and (x+y)%2 == 1: return Color.TRANSPARENT
		if r < 1.4: return base.darkened(0.25)
		return base.lightened(0.24 if (x*5+y*3)%5 == 0 else 0.08)
	# Lilac: a spray of small florets on a short branch.
	var floret: bool = (absi(dx)+absi(dy) <= 3 and (x+y)%2 == 0) or (dx*dx+dy*dy <= 5)
	if not floret: return Color.TRANSPARENT
	return base.lightened(0.26 if (x*7+y*3)%5 == 0 else 0.05)

static func draw(img: Image, id: int) -> void:
	for y in 16:
		for x in 16:
			var noise: Color = Color(DATA[id].color)*(0.88+float((x*7+y*13+id)%9)*0.03)
			img.set_pixel(x,y,pixel(id,x,y,noise))

# --- recipes -----------------------------------------------------------------

# The source's `_mcl_crafting_output`: two of the plant's dye from one plant.
static func recipes(inv: Inventory) -> void:
	for id in BOTTOMS:
		var dye: int = dye_of(id)
		if dye != 0: inv._recipe(Nodes.title(dye),dye,2,[id],1)
