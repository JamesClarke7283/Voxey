class_name PaleOak
extends RefCounted

# Mineclonia ITEMS/mcl_pale_oak/{resin_blocks,plants}.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference; all art is original
# procedural code.
#
# The pale oak tree's own wooden family (logs, planks, doors and so on) belongs to
# `WoodTypes` and needs the PaleGarden biome, so it is out of scope here. What this
# module adds is the self-contained half the source registers beside it:
#
# - **Resin**: clump → block of resin → (smelt) resin brick → resin brick block,
#   with a chiseled variant, plus the block's own `single` decraft back to nine
#   clumps. Resin is also a **trim material**, which the source marks with
#   `_mcl_armor_trim_color = "#ff5315"`.
# - **Pale hanging moss**: a strand that grows **downward** to a maximum length of
#   eight, one block per bone-meal use, with a distinct tip state at the bottom.
#   The source's own `grow_hanging_moss` converts the old tip and places a new tip.
# - **Pale moss and pale moss carpet**: the pale ground cover, carpet being the flat
#   variant. Bone meal spreads pale moss over a `random(2,3)` by `random(2,3)` area.
# - **Eyeblossom**: a flower that opens at night and closes by day, on the source's
#   two-second ABM. Its closed form dyes grey and its open form orange, and it carries
#   the source's nausea and blindness stew effects.
#
# `resin_clump` has **no acquisition route** in the source checkout: the creaking mob
# that would drop it is not in this reference, and nothing else produces it. It is
# registered here for completeness and recorded, not invented.

const RESIN_CLUMP = 11519
const RESIN_BRICK = 11520
const RESIN_BLOCK = 11521
const RESIN_BRICK_BLOCK = 11522
const CHISELED_RESIN_BRICK = 11523
const HANGING_MOSS = 11524
const HANGING_MOSS_TIP = 11525
const PALE_MOSS = 11526
const PALE_MOSS_CARPET = 11527
const EYEBLOSSOM = 11528
const EYEBLOSSOM_OPEN = 11529
const COUNT = 11
# Only the placeable nodes take a generated atlas tile.
const BLOCKS = [11521,11522,11523,11524,11525,11526,11527,11528,11529]

const DATA = {
	# The items. `resin_clump` is not in BLOCKS because it is never placed.
	RESIN_CLUMP:{"name":"Resin clump","color":"ff8a3d","family":"resin","stack":64},
	RESIN_BRICK:{"name":"Resin brick","color":"d9662a","family":"resin","stack":64,"smelt":0},
	# `_mcl_hardness = 0` and `dig_immediate`: a block of resin is soft.
	RESIN_BLOCK:{"name":"Block of resin","block":true,"shape":"cube","color":"e2762f","hardness":0.0,"tool":-1,"family":"resin"},
	RESIN_BRICK_BLOCK:{"name":"Resin bricks","block":true,"shape":"cube","color":"c25a24","hardness":1.5,"tool":0,"blast_resistance":6.0,"family":"resin"},
	CHISELED_RESIN_BRICK:{"name":"Chiseled resin brick","block":true,"shape":"cube","color":"b5541f","hardness":1.5,"tool":0,"blast_resistance":6.0,"family":"resin"},
	# Hanging moss hangs; the tip is the hidden bottom state.
	HANGING_MOSS:{"name":"Pale hanging moss","block":true,"shape":"plant","color":"c8cbb0","hardness":0.0,"tool":-1,"transparent":true,"family":"pale_moss","hangs":true},
	HANGING_MOSS_TIP:{"name":"Pale hanging moss","block":true,"shape":"plant","color":"b7ba9e","hardness":0.0,"tool":-1,"transparent":true,"hidden":true,"family":"pale_moss","hangs":true},
	# `converts_to_moss`: pale moss spreads onto the blocks the source lists.
	PALE_MOSS:{"name":"Pale moss block","block":true,"shape":"cube","color":"bfc2a4","hardness":0.1,"tool":2,"family":"pale_moss","converts_to_moss":true},
	PALE_MOSS_CARPET:{"name":"Pale moss carpet","block":true,"shape":"carpet","color":"bfc2a4","hardness":0.1,"tool":2,"family":"pale_moss","compostability":30},
	# Eyeblossom has a closed and an open state; the source swaps them on a 2s ABM.
	EYEBLOSSOM:{"name":"Closed eyeblossom","block":true,"shape":"plant","color":"c9c3b6","hardness":0.0,"tool":-1,"transparent":true,"family":"flower","dye":"grey"},
	EYEBLOSSOM_OPEN:{"name":"Eyeblossom","block":true,"shape":"plant","color":"e9a24a","hardness":0.0,"tool":-1,"transparent":true,"hidden":true,"family":"flower","dye":"orange"},
}

# Source `grow_hanging_moss`: a tower of `pale_hanging_moss` at most eight long, each
# bone-meal step converting the old tip and placing a new one below it.
const MOSS_MAX_LENGTH = 8

static func is_resin(id: int) -> bool: return DATA.get(id,{}).get("family","") == "resin"
static func is_hanging_moss(id: int) -> bool: return id == HANGING_MOSS or id == HANGING_MOSS_TIP
static func is_pale_moss(id: int) -> bool: return id == PALE_MOSS or id == PALE_MOSS_CARPET
static func is_eyeblossom(id: int) -> bool: return id == EYEBLOSSOM or id == EYEBLOSSOM_OPEN
# The item a moss node drops: a strand yields itself only to shears or Silk Touch.
static func drop_id(id: int) -> int:
	if is_hanging_moss(id): return 0
	if is_eyeblossom(id): return id
	return id

# The source's tower walk. Hanging moss hangs **downward**, so the tip is found by
# walking down from `p` to the deepest strand and the length is that count — walking
# up would never leave the first cell, which is what it used to do.
static func tower(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var tip: Vector3i = p
	var length: int = 1
	while world.loaded_at(Vector3(tip+Vector3i.DOWN)) and is_hanging_moss(world.node_at(tip+Vector3i.DOWN)):
		tip += Vector3i.DOWN
		length += 1
	return {"tip":tip,"length":length}

# `grow_hanging_moss`: at most eight long, and only into an empty cell.
static func grow_hanging_moss(world: VoxelWorld, p: Vector3i) -> bool:
	var info: Dictionary = tower(world,p)
	if int(info.length) >= MOSS_MAX_LENGTH: return false
	var below: Vector3i = info.tip+Vector3i.DOWN
	if world.node_at(below) != Nodes.AIR: return false
	if not world.set_node(info.tip,HANGING_MOSS): return false
	return world.set_node(below,HANGING_MOSS_TIP)

# `on_construct`: a new strand under an existing tip converts that tip to a strand,
# which is what keeps only the lowest cell a tip.
static func placed(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if id != HANGING_MOSS and id != HANGING_MOSS_TIP: return
	var above: Vector3i = p+Vector3i.UP
	if world.node_at(above) == HANGING_MOSS_TIP: world.set_node(above,HANGING_MOSS)

# --- pale moss spreading -----------------------------------------------------

# `bone_meal_moss`: an area of `random(2,3)` by `random(2,3)` around the block, over
# three heights, converting blocks the source lists as `converts_to_moss` or an
# existing moss. The corners of the area are excluded, which is the source's own
# `x_distance == x_max and z_distance == z_max` test.
static func bone_meal_moss(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	if world.node_at(p+Vector3i.UP) != Nodes.AIR: return false
	var x_max: int = rng.randi_range(2,3) if rng != null else randi_range(2,3)
	var z_max: int = rng.randi_range(2,3) if rng != null else randi_range(2,3)
	var placed: bool = false
	for dx in range(-x_max,x_max+1):
		for dz in range(-z_max,z_max+1):
			# The corners are excluded.
			if absi(dx) == x_max and absi(dz) == z_max: continue
			for dy in range(-6,5):
				var at: Vector3i = p+Vector3i(dx,dy,dz)
				if not world.loaded_at(Vector3(at)): continue
				var id: int = world.node_at(at)
				if id != PALE_MOSS and not converts_to_moss(id): continue
				if world.node_at(at+Vector3i.UP) != Nodes.AIR: continue
				placed = world.set_node(at,PALE_MOSS) or placed
	return placed

# The source's `converts_to_moss` group. Voxey's grass, dirt and stone are the
# overworld blocks it names; the mod's own list also has moss and mycelium variants
# that Voxey does not have.
static func converts_to_moss(id: int) -> bool:
	return id in [Nodes.GRASS,Nodes.DIRT,Nodes.STONE,Nodes.COBBLE,LushCaves.MOSS,VillageContent.SWAMP_GRASS]

# --- eyeblossom --------------------------------------------------------------

# The source's `is_night()`: `timeofday <= 0.2 or >= 0.8`.
static func is_night(day_time: float) -> bool:
	return day_time <= 0.2 or day_time >= 0.8

# The source's two-second ABM: a closed eyeblossom opens at night. The source only
# opens (its second ABM closes the potted form), so this matches that asymmetry.
static func update(game: Node3D, delta: float) -> void:
	var world: VoxelWorld = game.world
	var tracked: Dictionary = _runtime(world)
	tracked["clock"] = float(tracked.get("clock",0.0))+delta
	if float(tracked["clock"]) < 2.0:
		world.set_meta("pale_oak",tracked)
		return
	tracked["clock"] = 0.0
	if not is_night(float(game.day_time)): world.set_meta("pale_oak",tracked); return
	for key in tracked.keys():
		if not key is Vector3i: continue
		var at: Vector3i = key
		if world.node_at(at) == EYEBLOSSOM: world.set_node(at,EYEBLOSSOM_OPEN)
	world.set_meta("pale_oak",tracked)

static func _runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("pale_oak"): world.set_meta("pale_oak",{})
	return world.get_meta("pale_oak")

static func registered(world: VoxelWorld, p: Vector3i) -> void:
	var tracked: Dictionary = _runtime(world)
	tracked[p] = true
	world.set_meta("pale_oak",tracked)

static func changed(world: VoxelWorld, p: Vector3i, _old_id: int, id: int) -> void:
	if is_eyeblossom(id): registered(world,p)
	elif world.has_meta("pale_oak"):
		var tracked: Dictionary = _runtime(world)
		tracked.erase(p)
		world.set_meta("pale_oak",tracked)
	placed(world,p,id)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _runtime(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	world.set_meta("pale_oak",tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("pale_oak"): world.set_meta("pale_oak",{})

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source `_mcl_crafting_output`: nine clumps make a block of resin, and one block
	# unpacks into nine clumps.
	inv._recipe("Block of resin",RESIN_BLOCK,1,[RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP,RESIN_CLUMP],3,"table")
	inv._recipe("Resin clumps",RESIN_CLUMP,9,[RESIN_BLOCK],1)
	# `square2`: four resin bricks make a resin brick block.
	inv._recipe("Resin bricks",RESIN_BRICK_BLOCK,1,[RESIN_BRICK,RESIN_BRICK,RESIN_BRICK,RESIN_BRICK],2)
	# The source registers **no recipe** for the chiseled form: it is a stonecutter
	# output of the resin brick block (the `_mcl_stonecutter_recipes` on the stairs'
	# overrides). Voxey's stonecutter path reads `Masonry.cuts`-style tables, so the
	# chiseled brick is produced there rather than by an invented grid recipe.
	# `smelt`: a clump cooks into a resin brick, which `Nodes.smelt_result` reads.
	# Pale moss carpet: two pale moss make three carpets, as the source registers.
	inv._recipe("Pale moss carpet",PALE_MOSS_CARPET,3,[PALE_MOSS,PALE_MOSS],2)
	# Eyeblossom: the closed form dyes grey and the open form orange, as the source's
	# per-form `_mcl_crafting_output` says.
	inv._recipe("Grey dye",VillageContent.DYE_GREY,1,[EYEBLOSSOM],1)
	inv._recipe("Orange dye",VillageContent.DYE_ORANGE,1,[EYEBLOSSOM_OPEN],1)

# A resin clump smelts into a resin brick; the input is this module's own item, so
# the mapping can live on its DATA.
static func smelt_output(id: int) -> int: return RESIN_BRICK if id == RESIN_CLUMP else 0

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if id == PALE_MOSS or id == PALE_MOSS_CARPET:
		# A pale, dry mat: denser speckle than grass and a few darker fibres.
		if (x*3+y*5)%11 < 2: return base.darkened(0.18)
		if (x*7+y)%13 == 0: return base.lightened(0.1)
		return noise.lerp(base,0.6)
	if id == RESIN_BRICK_BLOCK or id == CHISELED_RESIN_BRICK:
		# A running bond, with a carved square for the chiseled form.
		if id == CHISELED_RESIN_BRICK:
			var ring: int = maxi(absi(x-7),absi(y-7))
			if ring in [3,6]: return base.darkened(0.35)
			return noise
		if y%4 == 0 or posmod(x+(4 if y/4%2 else 0),8) == 0: return base.darkened(0.38)
		return noise.lightened(0.04) if y%4 == 1 else noise
	if is_hanging_moss(id):
		# A thin hanging strand; the tip is the last cell so it is drawn slightly
		# lighter, which is the only visual difference the source gives it.
		if absi(x-7) > 1 and absi(x-8) > 1: return Color(0,0,0,0)
		if id == HANGING_MOSS_TIP and y > 10: return base.lightened(0.12)
		return base if y%4 != 0 else base.darkened(0.14)
	if is_eyeblossom(id):
		# Closed: a pale bud. Open: four orange petals around a pale centre.
		if id == EYEBLOSSOM:
			if y < 5: return Color(0,0,0,0)
			if absi(x-7) <= 2 and y < 11: return base.darkened(0.1)
			return Color(0,0,0,0)
		if y < 5: return Color(0,0,0,0)
		if absi(x-7) <= 1 and absi(y-9) <= 1: return Color("f4e6c8")
		if maxi(absi(x-7),absi(y-9)) <= 3: return base
		return Color(0,0,0,0)
	return noise.lerp(base,0.7)
