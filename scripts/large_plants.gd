class_name LargePlants
extends RefCounted

# Mineclonia ITEMS/mcl_flowers/{init,register}.lua and
# ITEMS/mcl_lush_caves/nodes.lua, GPL-3.0-or-later. Original GDScript and art.
#
# A large plant occupies two cells. Placement needs two buildable cells over
# `soil_flower`, with the source's light check. Removing either half removes its
# matching partner. The four flowers drop their bottom item on either half;
# double grass and double fern instead use the ordinary wheat-seed table, or two
# small plants when shears are used. Neither family has a Silk Touch override.
#
# The four large flowers have their own one-item bone-meal callback. Double
# grass/fern have no callback and must not inherit that flower duplication.
# Bone meal on the *small* grass/fern grows the corresponding pair.

const PEONY = 11418
const ROSE_BUSH = 11420
const LILAC = 11422
const SUNFLOWER = 11424
const DOUBLE_GRASS = 11426
const DOUBLE_FERN = 11428
# Keep BOTTOMS as the original four-flower selection: terrain and dye recipes
# must not acquire the two non-flower plants merely by joining the pair family.
const BOTTOMS = [PEONY,ROSE_BUSH,LILAC,SUNFLOWER]
const HERB_BOTTOMS = [DOUBLE_GRASS,DOUBLE_FERN]
const ALL_BOTTOMS = BOTTOMS+HERB_BOTTOMS
const BLOCKS = [PEONY,PEONY+1,ROSE_BUSH,ROSE_BUSH+1,LILAC,LILAC+1,SUNFLOWER,SUNFLOWER+1,DOUBLE_GRASS,DOUBLE_GRASS+1,DOUBLE_FERN,DOUBLE_FERN+1]

# The dye each large flower yields, two at a time (`_mcl_crafting_output`).
const DYE = {PEONY:VillageContent.DYE_PINK,ROSE_BUSH:VillageContent.DYE_RED,LILAC:VillageContent.DYE_MAGENTA,SUNFLOWER:VillageContent.DYE_YELLOW}

# Every available Voxey analogue of source `soil_flower`.
const SOIL = [Nodes.GRASS,Nodes.SNOW,Nodes.DIRT,DryTerrain.COARSE_DIRT,VillageContent.SWAMP_GRASS,VillageContent.MUD,LushCaves.MOSS,LushCaveExtra.ROOTED_DIRT,PaleOak.PALE_MOSS,Nodes.CLAY,Farmland.DRY,Farmland.WET,SoilVariants.PODZOL,SoilVariants.SNOWY_PODZOL,SoilVariants.MYCELIUM,SoilVariants.SNOWY_MYCELIUM]

const DATA = {
	PEONY:{"name":"Peony","block":true,"shape":"plant","color":"e07aa0","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:peony"},
	PEONY+1:{"name":"Peony","block":true,"shape":"plant","color":"e07aa0","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:peony"},
	ROSE_BUSH:{"name":"Rose bush","block":true,"shape":"plant","color":"b83d41","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:rose_bush"},
	ROSE_BUSH+1:{"name":"Rose bush","block":true,"shape":"plant","color":"b83d41","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:rose_bush"},
	LILAC:{"name":"Lilac","block":true,"shape":"plant","color":"b878cc","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:lilac"},
	LILAC+1:{"name":"Lilac","block":true,"shape":"plant","color":"b878cc","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:lilac"},
	SUNFLOWER:{"name":"Sunflower","block":true,"shape":"plant","color":"e8c23a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":65,"large_bottom":true,"source_node":"mcl_flowers:sunflower"},
	SUNFLOWER+1:{"name":"Sunflower","block":true,"shape":"plant","color":"e8c23a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:sunflower"},
	DOUBLE_GRASS:{"name":"Tall grass","block":true,"shape":"plant","color":"6fa03c","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":50,"large_bottom":true,"source_node":"mcl_flowers:double_grass"},
	DOUBLE_GRASS+1:{"name":"Tall grass","block":true,"shape":"plant","color":"6fa03c","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:double_grass"},
	DOUBLE_FERN:{"name":"Large fern","block":true,"shape":"plant","color":"5c8a45","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":50,"large_bottom":true,"source_node":"mcl_flowers:double_fern"},
	DOUBLE_FERN+1:{"name":"Large fern","block":true,"shape":"plant","color":"5c8a45","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"hidden":true,"source_node":"mcl_flowers:double_fern"},
}

static func is_large(id: int) -> bool: return id in BLOCKS
static func is_bottom(id: int) -> bool: return id in ALL_BOTTOMS
static func is_top(id: int) -> bool: return is_large(id) and not is_bottom(id)
static func is_herb(id: int) -> bool: return bottom(id) in HERB_BOTTOMS
static func bottom(id: int) -> int: return id if is_bottom(id) else id-1
static func top(id: int) -> int: return id+1 if is_bottom(id) else id
static func dye_of(id: int) -> int: return int(DYE.get(bottom(id),0))
static func color(id: int) -> Color: return Color(DATA[id].color)
static func small_form(id: int) -> int:
	if bottom(id) == DOUBLE_GRASS: return FoodFeatures.TALL_GRASS
	if bottom(id) == DOUBLE_FERN: return FlowersExtra.FERN
	return bottom(id)

# Source `buildable_to`, using Voxey's shared replacement vocabulary. Large
# halves themselves are not buildable_to even though Nodes.plant includes them.
static func buildable_to(id: int) -> bool: return not is_large(id) and Doors.replaceable(id)

# The bottom and upper cells must both be present and replaceable. In particular,
# checking only soil/light used to let the generic player path overwrite a solid
# upper cell or leave a half-formed pair at a world boundary.
static func can_place(world: VoxelWorld, at: Vector3i) -> bool:
	var above: Vector3i = at+Vector3i.UP
	if not world.loaded_at(Vector3(at+Vector3i.DOWN)) or not world.loaded_at(Vector3(at)) or not world.loaded_at(Vector3(above)): return false
	if not SOIL.has(world.node_at(at+Vector3i.DOWN)): return false
	if not buildable_to(world.node_at(at)) or not buildable_to(world.node_at(above)): return false
	# Flower light rule: artificial light eight, or unobstructed daytime sky.
	if Pasture.block_light(world,at,8) >= 8: return true
	if world.dimension != "overworld": return false
	RedstoneSensors.natural_light(world,at)
	return RedstoneSensors._natural_light(world,at,14) >= 14

# Pair construction shared by conversion and moss vegetation. This deliberately
# does not re-run placement soil/light rules: neither source callback does so.
static func place_pair(world: VoxelWorld, at: Vector3i, id: int) -> bool:
	if not is_bottom(id): return false
	var above: Vector3i = at+Vector3i.UP
	var previous: int = world.node_at(at)
	if not buildable_to(previous) or not buildable_to(world.node_at(above)): return false
	if not world.loaded_at(Vector3(at)) or not world.loaded_at(Vector3(above)): return false
	if not world.set_node(at,id): return false
	if world.set_node(above,id+1): return true
	world.set_node(at,previous)
	return false

# Place the held pair with the full on_place checks. Inventory consumption and
# placed events remain with the caller, as in the existing generic player path.
static func place(game: Node3D, at: Vector3i) -> bool:
	var id: int = int(game.inventory.held().id)
	return is_bottom(id) and can_place(game.world,at) and place_pair(game.world,at,id)

static func partner(world: VoxelWorld, p: Vector3i, id: int) -> Vector3i:
	if not is_large(id): return p
	var other: Vector3i = p+Vector3i.UP if is_bottom(id) else p+Vector3i.DOWN
	var want: int = top(id) if is_bottom(id) else bottom(id)
	return other if world.node_at(other) == want else p

# Registered drops are shared with Harvesting so the top and bottom use exactly
# the same source table. Double plants have no `silk` entry: Silk Touch alone
# still rolls seeds, while shears return two small items before Fortune matters.
static func harvest(id: int, slot: Dictionary, random: EnchantRolls = null) -> Array:
	if not is_large(id): return []
	var result: Dictionary = Harvesting.harvest(id,slot,random)
	return result.get("drops",[]) if result.get("handled",false) else []

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	return not world.loaded_at(Vector3(below)) or world.node_at(below) != Nodes.AIR

# `mcl_attached.drop_attached_node` and piston digging use ordinary, empty-hand
# drops rather than the player's shears. Pair removal itself never adds a second
# drop for the partner.
static func environmental_break(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_large(id): return false
	var other: Vector3i = partner(world,p,id)
	var drops: Array = harvest(id,{"id":0})
	if not world.set_node(p,Nodes.AIR): return false
	if other != p and world.node_at(other) == (bottom(id) if is_top(id) else top(id)): world.set_node(other,Nodes.AIR)
	var game: Node = world.get_parent()
	if game != null and game.has_method("spawn_drop"):
		for entry in drops: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,int(entry[0]),int(entry[1]))
	return true

# Live replacement implements both after_destruct directions. Checking p and
# p+UP also catches a plant whose support was just removed. Unloaded support is
# explicitly safe; piston transactions defer the same validation until finished.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if PistonPush.defer_support(world,p): return
	if old_id != id and is_large(old_id):
		var other: Vector3i = partner(world,p,old_id)
		if other != p: world.set_node(other,Nodes.AIR)
	for at in [p,p+Vector3i.UP]:
		if is_large(world.node_at(at)) and not supported(world,at): environmental_break(world,at)

# The game break path uses the actual held slot (including enchantments), removes
# one clicked half and its partner, and emits drops only for that clicked node.
static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int = 0) -> bool:
	if not is_large(id): return false
	var world: VoxelWorld = game.world
	var other: Vector3i = partner(world,p,id)
	var drops: Array = harvest(id,game.inventory.held()) if game.gamemode != "creative" else []
	if not world.set_node(p,Nodes.AIR): return true
	if other != p and world.node_at(other) == (bottom(id) if is_top(id) else top(id)): world.set_node(other,Nodes.AIR)
	for entry in drops: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,int(entry[0]),int(entry[1]))
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

static func bone_meal_target(id: int) -> bool:
	return is_large(id) or id in [FoodFeatures.TALL_GRASS,FlowersExtra.FERN]

# Small grass/fern callbacks return nil when the upper cell is blocked. The
# dispatcher therefore consumes and emits effects even when `grew` is false.
# Existing large flowers return `duplicate` for their source one-item drop;
# double grass/fern have no callback and must not use that flower path.
static func bone_meal(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var id: int = world.node_at(p)
	if is_large(id):
		return {"consume":true,"grew":false,"duplicate":bottom(id)} if bottom(id) in BOTTOMS else {"consume":false,"grew":false}
	var pair: int = DOUBLE_GRASS if id == FoodFeatures.TALL_GRASS else DOUBLE_FERN if id == FlowersExtra.FERN else 0
	if pair == 0: return {"consume":false,"grew":false}
	return {"consume":true,"grew":place_pair(world,p,pair)}

# `set_moss_with_chance_vegetation` in lush caves and pale oak. If the second
# vegetation cell is not buildable_to, double grass falls back to short grass;
# all non-double selections are placed directly by the same consumer hook.
static func place_moss_vegetation(world: VoxelWorld, p: Vector3i, vegetation: int) -> bool:
	if vegetation != DOUBLE_GRASS: return world.set_node(p,vegetation)
	if place_pair(world,p,DOUBLE_GRASS): return true
	return world.set_node(p,FoodFeatures.TALL_GRASS)

# --- art ---------------------------------------------------------------------

# Flowers keep their lower-stem/upper-bloom split. Grass and fern instead share
# a 16x32 drawing space so each cell contains its actual half of the herb.
const STEM = "548448"

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = color(id)
	if is_herb(id): return herb_pixel(id,x,y,base)
	if is_bottom(id):
		# Lower stem with a small leaf either side.
		if x in [7,8] and y >= 4: return Color(STEM)
		if y in [9,10] and x in [4,5,6]: return Color(STEM)
		if y in [11,12] and x in [9,10,11]: return Color(STEM)
		return Color.TRANSPARENT
	# Upper half: stem lower third, then the bloom above it.
	if x in [7,8] and y >= 9: return Color(STEM)
	return bloom_pixel(id,x,y,base,noise)

static func herb_pixel(id: int, x: int, y: int, base: Color) -> Color:
	var whole_y: int = y+(16 if is_bottom(id) else 0)
	if bottom(id) == DOUBLE_FERN:
		if x in [7,8] and whole_y >= 4: return base.darkened(0.12)
		# Paired arching fronds, widest around the middle of the whole plant.
		for frond in [[5,3],[9,5],[13,7],[18,8],[23,6]]:
			var dy: int = whole_y-int(frond[0])
			if dy < 0 or dy > 5: continue
			var reach: int = roundi(float(dy)*float(frond[1])/5.0)
			if absi(x-7) in [reach,reach+1]: return base.lightened(0.08 if (x+whole_y)%2 == 0 else 0.0)
		return Color.TRANSPARENT
	# Uneven blades continue across the cell seam instead of repeating one tuft.
	for blade in [[4,20,-2],[6,27,-1],[8,30,1],[10,25,2],[12,18,1],[2,14,-1]]:
		var top_y: int = 32-int(blade[1])
		if whole_y < top_y: continue
		var t: float = float(whole_y-top_y)/float(blade[1])
		var centre: float = float(blade[0])+float(blade[2])*(1.0-t)
		if absf(float(x)-centre) <= 0.65: return base.lightened(0.10 if (x+whole_y)%3 == 0 else 0.0).darkened(0.08 if t > 0.8 else 0.0)
	return Color.TRANSPARENT

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
