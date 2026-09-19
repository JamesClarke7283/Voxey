class_name EndMud
extends RefCounted

# Mineclonia ITEMS/mcl_end/building.lua, ITEMS/mcl_end/chorus_plant.lua and
# ITEMS/mcl_mud/init.lua, GPL-3.0-or-later. Original GDScript using the sources as
# a behaviour reference; every tile below is original procedural Voxey art.
#
# The three sources register this family:
#   building.lua:3-26      mcl_end:end_stone          (Voxey already has 230)
#   building.lua:16-26     mcl_end:end_bricks         (231)
#   building.lua:28-37     mcl_end:purpur_block       (236)
#   building.lua:39-52     mcl_end:purpur_pillar      -> 11440
#   building.lua:54-127    mcl_end:end_rod            (238)
#   building.lua:129       mcl_end:dragon_egg         (239)
#   chorus_plant.lua:113   mcl_end:chorus_flower      -> 11441
#   chorus_plant.lua:207   mcl_end:chorus_flower_dead -> 11442
#   chorus_plant.lua:242   mcl_end:chorus_plant       (237)
#   chorus_plant.lua:543   mcl_end:chorus_fruit       (274)
#   chorus_plant.lua:558   mcl_end:chorus_fruit_popped -> 11443
#   mcl_mud/init.lua:3     mcl_mud:mud                (VillageContent.MUD, 683)
#   mcl_mud/init.lua:23    mcl_mud:packed_mud         -> 11444
#   mcl_mud/init.lua:36    mcl_mud:mud_bricks         -> 11445
# End stone, end bricks, the purpur block, the end rod, the dragon egg, the chorus
# stem and the chorus fruit are existing Voxey ids. This module closes the six
# remaining contents of the family.
#
# Orientation, and why the purpur pillar has none. The source is
# `paramtype2 = "facedir"` with `on_place = mcl_util.rotate_axis` and
# `on_rotate = screwdriver.rotate_3way` (building.lua:42,44,47), and it carries
# three tiles: the end grain on the two axis faces and the fluted side on the other
# four (:45). Voxey models that rotation with **extra ids**: `DenseMaterials` keeps
# `BONE_X`/`BONE_Z` plus the hidden `BONE_END` tile, and `WoodTypes` keeps four axis
# parts per species. Both need spare ids, and `Nodes.tile(id,face)` can only vary by
# id - it takes no position, so an axis kept per node would be unobservable, and
# `VillageArt.mesh` only runs for non-"cube" shapes, which `Nodes.transparent`
# reports as see-through, so a mesh-drawn pillar would stop occluding its
# neighbours. This module's allocation is exactly 11440..11445 with all six
# contents assigned, so there is no id for an axis variant or an end tile. The
# pillar is therefore one cube id whose tile is 4-fold symmetric: `BlockMesher._quad`
# rotates a tile by 90 degrees between the +/-X and the +/-Z faces, so a symmetric
# fluted pattern is the only art that reads the same from every direction, and it
# carries the source's concentric end-grain rings in its centre. Voxey's existing
# pillar, `VillageContent.QUARTZ_PILLAR` (542), resolves the same conflict the same
# way: one striated tile and no axis.

const PURPUR_PILLAR = 11440
const CHORUS_FLOWER = 11441
const CHORUS_FLOWER_DEAD = 11442
const POPPED_CHORUS_FRUIT = 11443
const PACKED_MUD = 11444
const MUD_BRICKS = 11445

# 11443 is a craftitem, so it is not an atlas tile.
const BLOCKS = [PURPUR_PILLAR,CHORUS_FLOWER,CHORUS_FLOWER_DEAD,PACKED_MUD,MUD_BRICKS]

# Source `MAX_FLOWER_AGE = 5` (chorus_plant.lua:8): a flower whose age reaches it
# dies, and so does one that cannot grow.
const MAX_FLOWER_AGE = 5
# Source ABM (chorus_plant.lua:460-468): interval 35, chance 4, over every
# `mcl_end:chorus_flower`, calling one `grow_chorus_plant_step`.
const INTERVAL = 35.0
const CHANCE = 4
# The source's `around` table (chorus_plant.lua:351-356), in its own order, which
# is both the branch direction list and the adjacency test `on_place` counts.
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.BACK,Vector3i.FORWARD]

const DATA = {
	# Source building.lua:39-52: `pickaxey=1, building_block=1, material_stone=1`,
	# `_mcl_blast_resistance = 6`, `_mcl_hardness = 1.5`.
	11440:{"name":"Purpur pillar","block":true,"shape":"cube","color":"ab7ead","hardness":1.5,"blast_resistance":6.0,"tool":0,"note_material":"stone","source_node":"mcl_end:purpur_pillar"},
	# Source chorus_plant.lua:113-206: `handy=1, axey=1, deco_block=1,
	# chorus_plant=1, unsticky=1`, `_mcl_hardness = 0.4` and no blast resistance, so
	# mcl_explosions falls back to the hardness
	# (mods/CORE/mcl_explosions/init.lua:40-41). The nodebox is a flower-sized box,
	# which Voxey's "plant" shape renders as crossed quads, and `sunlight_propagates`
	# is a non-occluding shape. The axe group is why `tool` is 1 and not 0: a
	# pickaxe-only value would make the flower unbreakable by hand.
	11441:{"name":"Chorus flower","block":true,"shape":"plant","color":"9a6ba6","hardness":0.4,"blast_resistance":0.4,"tool":1,"transparent":true,"source_node":"mcl_end:chorus_flower"},
	# Source chorus_plant.lua:207-241: same groups and hardness, plus
	# `not_in_creative_inventory = 1`, `_mcl_blast_resistance = 2` and
	# `drop = "mcl_end:chorus_flower"`, so a dead flower harvested by hand yields a
	# fresh one that grows again.
	11442:{"name":"Dead chorus flower","block":true,"shape":"plant","color":"a99a80","hardness":0.4,"blast_resistance":2.0,"tool":1,"drop":11441,"transparent":true,"hidden":true,"source_node":"mcl_end:chorus_flower_dead"},
	# Source chorus_plant.lua:558-565: `groups = {craftitem = 1}` and a `square2`
	# crafting output of four purpur blocks. It has no food group and no durability,
	# so it is an ordinary 64-stack material.
	11443:{"name":"Popped chorus fruit","color":"c8a6cc","stack":64,"source_node":"mcl_end:chorus_fruit_popped"},
	# Source mcl_mud/init.lua:23-34: `handy=1, pickaxey=1, building_block=1`,
	# `_mcl_blast_resistance = 3`, `_mcl_hardness = 1`.
	11444:{"name":"Packed mud","block":true,"shape":"cube","color":"8a6b4f","hardness":1.0,"blast_resistance":3.0,"tool":0,"source_node":"mcl_mud:packed_mud"},
	# Source mcl_mud/init.lua:36-43: the same groups plus `stonecuttable = 1`,
	# `_mcl_blast_resistance = 3`, `_mcl_hardness = 1.5`.
	11445:{"name":"Mud bricks","block":true,"shape":"cube","color":"8b6a4c","hardness":1.5,"blast_resistance":3.0,"tool":0,"note_material":"stone","source_node":"mcl_mud:mud_bricks"},
}

# --- predicates --------------------------------------------------------------

static func is_purpur_pillar(id: int) -> bool: return id == PURPUR_PILLAR
static func is_chorus_flower(id: int) -> bool: return id == CHORUS_FLOWER or id == CHORUS_FLOWER_DEAD
static func is_living_flower(id: int) -> bool: return id == CHORUS_FLOWER
static func is_dead_flower(id: int) -> bool: return id == CHORUS_FLOWER_DEAD
static func is_popped_fruit(id: int) -> bool: return id == POPPED_CHORUS_FRUIT
static func is_mud(id: int) -> bool: return id == PACKED_MUD or id == MUD_BRICKS
# Everything the source plants as one chorus plant: the two flower states and the
# stem, all in `group:chorus_plant` (chorus_plant.lua:138, 231, 275).
static func is_chorus_part(id: int) -> bool: return is_chorus_flower(id) or id == Nodes.CHORUS_PLANT

# Source's dead flower `drop` (:224). The living flower has no `drop`, so it drops
# itself, and the stem's own table is `Nodes.drop`'s existing business.
static func drop_id(id: int) -> int: return CHORUS_FLOWER if is_dead_flower(id) else id

# Source `_mcl_cooking_output = "mcl_end:chorus_fruit_popped"` on the chorus fruit
# (:555). That input is the existing id `Nodes.CHORUS_FRUIT`, so the output cannot
# live in a `smelt` key on this module's own DATA: `Nodes.smelt_result` should
# consult this first, exactly as it already does for `NetherBlocks.smelt_output`.
static func smelt_output(id: int) -> int: return POPPED_CHORUS_FRUIT if id == Nodes.CHORUS_FRUIT else 0

# --- recipes -----------------------------------------------------------------

# Every material is reachable from content Voxey already has: mud generates in the
# swamp surface (terrain_generator.gd:191), wheat from `Nodes.GRAIN`, chorus fruit
# from the chorus stem's own drop and the end city.
static func recipes(inv: Inventory) -> void:
	# Source mcl_mud/init.lua:66-73: the shapeless mud + wheat recipe. Voxey's wheat
	# is `Nodes.GRAIN` (71), the source's `mcl_farming:wheat_item`.
	inv._shapeless("Packed mud",PACKED_MUD,1,[VillageContent.MUD,Nodes.GRAIN])
	# Source mcl_mud/init.lua:33, packed mud's `square2` output of four mud bricks.
	inv._recipe("Mud bricks",MUD_BRICKS,4,[PACKED_MUD,PACKED_MUD,PACKED_MUD,PACKED_MUD],2)
	# Source chorus_plant.lua:564, the popped fruit's `square2` output of four
	# purpur blocks. Voxey already registers purpur from four *raw* chorus fruit
	# (inventory.gd:107), which is the newer rule this checkout does not have; both
	# are kept because the popped fruit would otherwise be a crafting dead end.
	inv._recipe("Purpur from popped chorus fruit",Nodes.PURPUR,4,
		[POPPED_CHORUS_FRUIT,POPPED_CHORUS_FRUIT,POPPED_CHORUS_FRUIT,POPPED_CHORUS_FRUIT],2)

# --- chorus flower growth ----------------------------------------------------

# The source keeps the flower's age in `param2`; Voxey has no per-node param2
# table, so the age lives in `block_states` exactly as `Kelp` stores its height and
# age and `Decor` stores a pot's plant.
static func age(world: VoxelWorld, p: Vector3i) -> int:
	return int(world.block_states.get(VoxelWorld.station_key(p),{}).get("chorus_age",0))

static func set_age(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	if value <= 0: state.erase("chorus_age")
	else: state["chorus_age"] = value
	if state.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = state

# Source `on_place` (chorus_plant.lua:144-201). Placement is legal on top of end
# stone or a chorus stem, or over air beside **exactly one** stem - one stem, not
# one or more, and the cell under the flower must then be air.
static func placement_ok(world: VoxelWorld, at: Vector3i) -> bool:
	var below: int = world.node_at(at+Vector3i.DOWN)
	if below == Nodes.END_STONE or below == Nodes.CHORUS_PLANT: return true
	if below != Nodes.AIR: return false
	var stems: int = 0
	for side in SIDES:
		if world.node_at(at+side) == Nodes.CHORUS_PLANT:
			stems += 1
			if stems > 1: return false
	return stems == 1

static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != CHORUS_FLOWER or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current): return true
	if not placement_ok(world,at):
		game.toast("Chorus flowers only grow on end stone or a chorus plant.")
		return true
	if not world.set_node(at,CHORUS_FLOWER): return true
	set_age(world,at,0)
	registered(world,at)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,CHORUS_FLOWER)
	return true

# Source `grow_chorus_plant_step` (chorus_plant.lua:349-455): one growth step of a
# flower, returning the cells that became fresh flowers so the full-plant generator
# can grow them in turn. Every threshold below is the source's `grow_chance` table.
static func grow_step(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator) -> Array:
	var buds: Array = []
	if world.node_at(p) != CHORUS_FLOWER: return buds
	var above: Vector3i = p+Vector3i.UP
	if world.node_at(above) != Nodes.AIR: return _die(world,p,buds)
	# The cell above must be free on all four sides too, which is the source's
	# `air_around` test against the cell *above* the flower.
	for side in SIDES:
		if world.node_at(above+side) != Nodes.AIR: return _die(world,p,buds)
	var height: int = 0
	var branching: bool = false
	for y in range(1,5):
		var below: Vector3i = p+Vector3i(0,-y,0)
		if world.node_at(below) != Nodes.CHORUS_PLANT: break
		height = y
		if branching: continue
		for side in SIDES:
			if world.node_at(below+side) == Nodes.CHORUS_PLANT: branching = true
	# `h <= 1` is 100, `h == 2` is 60 upright and 50 branched, `h == 3` is 40 and
	# 25, `h == 4` is 20 upright only. A four-cell stem that already branches has no
	# entry, so the step can only fail and the flower dies - the source's cap on a
	# plant whose chunk border was passed (chorus_plant.lua:450-451).
	var chance: int = 0
	if height <= 1: chance = 100
	elif height == 2: chance = 50 if branching else 60
	elif height == 3: chance = 25 if branching else 40
	elif height == 4 and not branching: chance = 20
	if chance == 0: return _die(world,p,buds)
	var flower_age: int = age(world,p)
	var targets: Array = []
	if rng.randi_range(1,100) <= chance:
		targets.append(above)
	else:
		# A failed roll ages the flower and sprouts branches sideways instead; each
		# branch needs air directly under it, so a branch cannot hang.
		flower_age += 1
		var branches: int = rng.randi_range(0,3) if branching else rng.randi_range(1,4)
		for _i in branches:
			var branch: Vector3i = p+SIDES[rng.randi_range(0,SIDES.size()-1)]
			if world.node_at(branch+Vector3i.DOWN) == Nodes.AIR: targets.append(branch)
	if targets.is_empty(): return _die(world,p,buds)
	for at in targets:
		# The source only refuses a cell that already holds a flower in either form
		# (`nn ~= "mcl_end:chorus_flower" and nn ~= "mcl_end:chorus_flower_dead"`,
		# :428-439): a branch that lands on a stem or on end stone is planted over.
		if is_chorus_flower(world.node_at(at)): continue
		# An aged-out flower is planted dead, and yields no bud to continue from.
		if flower_age >= MAX_FLOWER_AGE:
			world.set_node(at,CHORUS_FLOWER_DEAD)
			continue
		if world.set_node(at,CHORUS_FLOWER):
			set_age(world,at,flower_age)
			buds.append(at)
	# The flower becomes part of the stem: the stem is what holds the plant up, and
	# every new flower hangs off it.
	world.set_node(p,Nodes.CHORUS_PLANT)
	return buds

# The source's `if not grown` branch: a flower that could not grow - blocked above,
# boxed in, out of chances, or past the age cap - turns dead.
static func _die(world: VoxelWorld, p: Vector3i, buds: Array) -> Array:
	world.set_node(p,CHORUS_FLOWER_DEAD)
	return buds

# The ABM, swept once per second by the world's active simulation. Its interval and
# chance are the source's `interval = 35.0, chance = 4.0`.
static func update(world: VoxelWorld, delta: float) -> void:
	var tracked: Dictionary = _tracked(world)
	if tracked.is_empty(): return
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < INTERVAL:
		tracked["clock"] = clock
		world.set_meta("chorus",tracked)
		return
	tracked["clock"] = 0.0
	var rng: RandomNumberGenerator = Corals._rng(world)
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		if world.node_at(p) != CHORUS_FLOWER:
			tracked.erase(p)
			set_age(world,p,0)
			continue
		if rng.randi_range(1,CHANCE) != 1: continue
		grow_step(world,p,rng)
	world.set_meta("chorus",tracked)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("chorus"): world.set_meta("chorus",{})
	return world.get_meta("chorus")

# Flower cells are tracked so the sweep has a bounded working set, as the other
# stateful modules do.
static func registered(world: VoxelWorld, p: Vector3i) -> void:
	var tracked: Dictionary = _tracked(world)
	tracked[p] = true
	world.set_meta("chorus",tracked)

# Called from `VoxelWorld.set_node` for every change, so a placed or grown flower
# joins the sweep and a stem that replaces one leaves it.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id == id: return
	var tracked: Dictionary = _tracked(world)
	if is_living_flower(id): tracked[p] = true
	else:
		tracked.erase(p)
		if is_chorus_flower(old_id): set_age(world,p,0)
	world.set_meta("chorus",tracked)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _tracked(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	world.set_meta("chorus",tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("chorus"): world.set_meta("chorus",{})

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if is_chorus_flower(id): return flower_pixel(id,x,y,noise,base)
	if id == PURPUR_PILLAR:
		# A 4-fold symmetric carved pattern. Symmetry is not decoration: the mesher
		# gives the +/-X and the +/-Z faces different UV rotations, so any asymmetric
		# pattern would turn and look wrong on half the sides. Distances are measured
		# from the tile **centre**, which lies on the shared corner of the four middle
		# pixels at 15/2, so they are doubled to stay exact integers; every term below
		# is then a function of `{u,v}` alone, and the face rotation swaps u and v.
		# The pattern is the source `_top` tile's concentric end-grain rings crossed by
		# four flutes meeting at the centre.
		var u: int = absi(2*x-15)
		var v: int = absi(2*y-15)
		var ring: int = maxi(u,v)
		var inner: int = mini(u,v)
		if ring == 15: return base.darkened(0.32)
		if ring == 13: return base.lightened(0.16)
		if ring <= 1: return base.lightened(0.12)
		if inner <= 1: return base.darkened(0.11)
		if ring in [5,9]: return base.darkened(0.14)
		if posmod(ring+inner,7) == 0: return base.lightened(0.07)
		return noise.lerp(base,0.75)
	if id == PACKED_MUD:
		# Damp earth: broad darker patches with a few lighter, still-wet flecks.
		if posmod(x/2*5+y/2*7,11) < 3: return base.darkened(0.17)
		if posmod(x*3+y*5,17) == 0: return base.lightened(0.13)
		return noise.lerp(base,0.72)
	# Mud bricks are the same running bond as the other brick courses, in mud tones
	# with no stone-grey mortar.
	if y%4 == 0 or posmod(x+(4 if y/4%2 else 0),8) == 0: return base.darkened(0.2)
	return noise.lerp(base.lightened(0.05),0.85) if y%4 == 1 else noise.lerp(base,0.8)

# A flower is drawn as a compact petal cluster over a short stalk, transparent
# everywhere else so the crossed plant quads do not read as a block. The dead form
# is the same silhouette dried out: bleached petals over a pale bone core, against
# the living flower's saturated violet petals over a mid lavender core.
static func flower_pixel(id: int, x: int, y: int, noise: Color, base: Color) -> Color:
	var dead: bool = is_dead_flower(id)
	var core := Color("e2dbc6") if dead else Color("c9a9d9")
	var stalk := Color("8a7f66") if dead else Color("7b5580")
	if y >= 13: return stalk if x in range(6,10) else Color(0,0,0,0)
	var distance: float = Vector2(x-7.5,y-6.5).length()
	if distance > 6.6: return Color(0,0,0,0)
	if distance > 3.4:
		# Petals with darker veins between the four lobes.
		if posmod(x+y,4) == 0: return noise.lerp(base.darkened(0.18),0.5)
		return noise.lerp(base,0.9)
	return core
