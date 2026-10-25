class_name LushCaveExtra
extends RefCounted

# Mineclonia ITEMS/mcl_lush_caves/{nodes,dripleaf,crafting,init,lg_register}.lua,
# Original GDScript using the source as a behaviour reference; all art is original
# procedural code.
#
# `LushCaves` already owns the biome's vines, glow berry, moss, moss carpet and
# hanging roots. This module closes the rest of the source's node set:
#
#   * **Rooted dirt** (nodes.lua:236-268): dirt with hanging roots through it, the
#     soil the source's azalea trees stand on. Bone meal on it turns the *air below*
#     it into hanging roots (nodes.lua:246-253), and a hoe tills it like dirt while
#     collecting the roots below (nodes.lua:254-266).
#   * **Spore blossom** (nodes.lua:371-401): a ceiling plant whose `on_place`
#     accepts only an opaque block, an upright stair or a bottom slab above it. The
#     checkout gives it **no `light_source`** (nodes.lua:211 is the lit cave vine,
#     which `LushCaves` owns), so it emits nothing and `light_level` is zero.
#   * **Azalea / flowering azalea** (nodes.lua:405-484): bushes that need
#     `group:soil_flower` below, carry `compostability` 65 and 85, are the source's
#     own flower-pot entries (init.lua:221-231) and grow into the shipped
#     azalea1.mts under bone meal (nodes.lua:439-451). `AzaleaTrees` owns that
#     decoded structure, its levelgen entry point and moss vegetation.
#   * **Azalea leaves** (nodes.lua:344-366): `mcl_trees.register_leaves` called with
#     *both* azalea forms as their "sapling" entries and no apples, so an ordinary
#     break rolls the shared stick/sapling table (mcl_trees/api.lua:296-330) and
#     shears or Silk Touch recover the leaf.
#   * **Dripleaf** (dripleaf.lua): a two-cell small plant that bone meal grows into
#     a stem column, and a big leaf with per-player tipping holds, independent
#     half/full node timers and the source's adjacent digging cascade.
#
# Shaped collision is exposed through `collision_boxes`; the shared world dispatcher
# delegates big-leaf cells here. Upright and half-tipped leaves have a thin top
# plate, while the source's `walkable = false` full-tipped form has no collision.
# Azalea's compound bush silhouette remains outside Voxey's single-box vocabulary.

const ROOTED_DIRT = 11470
const SPORE_BLOSSOM = 11471
const AZALEA = 11472
const AZALEA_FLOWERING = 11473
const AZALEA_LEAVES = 11474
const AZALEA_LEAVES_FLOWERING = 11475
const DRIPLEAF_SMALL_STEM = 11476
const DRIPLEAF_SMALL = 11477
const DRIPLEAF_BIG_STEM = 11478
const DRIPLEAF_BIG = 11479
const DRIPLEAF_BIG_TIPPED_HALF = 11480
const DRIPLEAF_BIG_TIPPED_FULL = 11481
# Numeric aliases avoid introducing content-registry cycles for nodes owned by
# other modules. Both are real members of the source's current soil lists.
const COARSE_DIRT = 13600
const PALE_MOSS = 11526
const BLOCKS = [ROOTED_DIRT,SPORE_BLOSSOM,AZALEA,AZALEA_FLOWERING,AZALEA_LEAVES,AZALEA_LEAVES_FLOWERING,
	DRIPLEAF_SMALL_STEM,DRIPLEAF_SMALL,DRIPLEAF_BIG_STEM,DRIPLEAF_BIG,DRIPLEAF_BIG_TIPPED_HALF,DRIPLEAF_BIG_TIPPED_FULL]

# Source timings for the big leaf's three stages (dripleaf.lua:301-307 and
# :267-287): the globalstep tips an upright leaf after 0.5 s of a player standing
# on it, `tipped_half` starts its own 0.5 s timer and `tipped_full` a 3.0 s one, so
# a leaf is down for 3.5 s in total.
const TIP_STAND_TIME = 0.5
const TIP_HALF_TIME = 0.5
const TIP_FULL_TIME = 3.0

const DATA = {
	# Drops itself: the source sets no `drop` on it, and a shovel is its tool
	# (`shovely=1`). `soil_flower`/`soil_generic_plant`/`converts_to_moss`/
	# `converts_to_mud` are the placement rules in `azalea_soil`/`dripleaf_soil`.
	ROOTED_DIRT:{"name":"Rooted dirt","block":true,"family":"lush_caves","color":"8b6444","hardness":0.5,"tool":2,"source_node":"mcl_lush_caves:rooted_dirt"},
	# `handy=1, plant=1, attached_node=4`, no tool group, `_mcl_hardness = 0.5`.
	SPORE_BLOSSOM:{"name":"Spore blossom","block":true,"family":"lush_caves","shape":"plant","color":"d9869f","hardness":0.5,"tool":-1,"transparent":true,"source_node":"mcl_lush_caves:spore_blossom"},
	# `_mcl_hardness = 0`, `handy=1, shearsy=1, plant=1`, compostability 65
	# (nodes.lua:468).
	AZALEA:{"name":"Azalea","block":true,"family":"lush_caves","shape":"plant","color":"3f6b34","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"source_node":"mcl_lush_caves:azalea"},
	# Same template plus `flower = 1` and compostability 85 (nodes.lua:484).
	AZALEA_FLOWERING:{"name":"Flowering azalea","block":true,"family":"lush_caves","shape":"plant","color":"43703a","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"source_node":"mcl_lush_caves:azalea_flowering"},
	# `mcl_trees` leaves template: `_mcl_hardness = 0.2`, `hoey=1`, compostability
	# 30, and an ordinary break drops the stick/sapling table, not the leaf
	# (`drop` 0, `leaf_drops`).
	AZALEA_LEAVES:{"name":"Azalea leaves","block":true,"family":"lush_caves","shape":"cube","color":"4a7a35","hardness":0.2,"tool":4,"blast_resistance":0.2,"transparent":true,"flammable":true,"drop":0,"source_node":"mcl_trees:leaves_azalea"},
	AZALEA_LEAVES_FLOWERING:{"name":"Flowering azalea leaves","block":true,"family":"lush_caves","shape":"cube","color":"4a7a35","hardness":0.2,"tool":4,"blast_resistance":0.2,"transparent":true,"flammable":true,"drop":0,"source_node":"mcl_trees:leaves_azalea_flowering"},
	# The small plant's lower half. `drop = ""`, `not_in_creative_inventory`.
	DRIPLEAF_SMALL_STEM:{"name":"Small dripleaf stem","block":true,"family":"lush_caves","shape":"plant","color":"5c8b3c","hardness":0.0,"tool":-1,"transparent":true,"drop":0,"hidden":true,"source_node":"mcl_lush_caves:dripleaf_small_stem"},
	# `drop = ""` with `_mcl_shears_drop = true`, compostability 30
	# (dripleaf.lua:118), `walkable = false`.
	DRIPLEAF_SMALL:{"name":"Small dripleaf","block":true,"family":"lush_caves","shape":"plant","color":"6d9e42","hardness":0.0,"tool":-1,"transparent":true,"drop":0,"source_node":"mcl_lush_caves:dripleaf_small"},
	# `drop = "mcl_lush_caves:dripleaf_big"` (dripleaf.lua:202), `not_in_creative_inventory`.
	DRIPLEAF_BIG_STEM:{"name":"Big dripleaf stem","block":true,"family":"lush_caves","shape":"plant","color":"6f9a44","hardness":0.0,"tool":-1,"transparent":true,"drop":DRIPLEAF_BIG,"hidden":true,"source_node":"mcl_lush_caves:dripleaf_big_stem"},
	# Walkable with the source's collision plate, compostability 65
	# (dripleaf.lua:224).
	DRIPLEAF_BIG:{"name":"Big dripleaf","block":true,"family":"lush_caves","shape":"cube","color":"6d9e42","hardness":0.0,"tool":-1,"transparent":true,"source_node":"mcl_lush_caves:dripleaf_big"},
	# The two tipped stages merge the big definition, so they keep its
	# compostability and its (absent) `drop`, and add `not_in_creative_inventory`.
	DRIPLEAF_BIG_TIPPED_HALF:{"name":"Big dripleaf","block":true,"family":"lush_caves","shape":"cube","color":"6d9e42","hardness":0.0,"tool":-1,"transparent":true,"hidden":true,"source_node":"mcl_lush_caves:dripleaf_big_tipped_half"},
	DRIPLEAF_BIG_TIPPED_FULL:{"name":"Big dripleaf","block":true,"family":"lush_caves","shape":"cube","color":"6d9e42","hardness":0.0,"tool":-1,"transparent":true,"hidden":true,"source_node":"mcl_lush_caves:dripleaf_big_tipped_full"},
}

# --- predicates --------------------------------------------------------------

# The module's whole id block, so one range test can dispatch art and BLOCKS.
static func is_extra(id: int) -> bool: return id >= ROOTED_DIRT and id <= DRIPLEAF_BIG_TIPPED_FULL
static func is_azalea(id: int) -> bool: return id == AZALEA or id == AZALEA_FLOWERING
static func is_azalea_leaves(id: int) -> bool: return id == AZALEA_LEAVES or id == AZALEA_LEAVES_FLOWERING
static func is_ceiling_plant(id: int) -> bool: return id == SPORE_BLOSSOM or id == LushCaves.HANGING_ROOTS
static func is_dripleaf(id: int) -> bool: return is_dripleaf_leaf(id) or is_dripleaf_stem(id)
static func is_dripleaf_leaf(id: int) -> bool: return id in [DRIPLEAF_SMALL,DRIPLEAF_BIG,DRIPLEAF_BIG_TIPPED_HALF,DRIPLEAF_BIG_TIPPED_FULL]
static func is_dripleaf_stem(id: int) -> bool: return id == DRIPLEAF_SMALL_STEM or id == DRIPLEAF_BIG_STEM
static func is_big_leaf(id: int) -> bool: return id == DRIPLEAF_BIG or is_dripleaf_tipped(id)
# `group:dripleaf=1` is present on the small plant, both stems and upright big
# leaf. The tipped table.merge replaces that group table, so tipped forms are not
# traversed by the source's adjacent digging callback.
static func is_dripleaf_group(id: int) -> bool: return id in [DRIPLEAF_SMALL_STEM,DRIPLEAF_SMALL,DRIPLEAF_BIG_STEM,DRIPLEAF_BIG]
static func needs_placement_rule(id: int) -> bool: return is_extra(id) or id == LushCaves.HANGING_ROOTS
static func is_dripleaf_tipped(id: int) -> bool: return id == DRIPLEAF_BIG_TIPPED_HALF or id == DRIPLEAF_BIG_TIPPED_FULL

# Source `light_source`: the checkout sets one only on the lit cave vine
# (nodes.lua:211), which `LushCaves` already owns, so every id here emits nothing.
# Kept so the parent's emission dispatch stays uniform.
static func light_level(_id: int) -> int: return 0

# Source `compostability` groups: azalea 65 and flowering azalea 85
# (nodes.lua:468,484), the leaves template 30 (mcl_trees/api.lua:194), the small
# dripleaf 30 and the big dripleaf 65 (dripleaf.lua:118,224; the two tipped forms
# merge the big definition). Rooted dirt, the spore blossom and both stems carry no
# compostability group at all and so are 0.
static func compostability(id: int) -> int:
	if id == AZALEA_FLOWERING: return 85
	if id == AZALEA or id == DRIPLEAF_BIG or is_dripleaf_tipped(id): return 65
	if is_azalea_leaves(id) or id == DRIPLEAF_SMALL: return 30
	return 0

# The item a node drops on an ordinary break, which is the source's `drop` field.
# `0` means nothing: the small dripleaf and its stem set `drop = ""`
# (dripleaf.lua:105,132) and an azalea leaf's drop is the stick/sapling table
# rather than the leaf (`leaf_drops`). A big stem drops the big leaf
# (dripleaf.lua:202). The two tipped stages inherit the big definition's absent
# `drop` through `table.merge`, so the source really does drop the tipped node
# itself; that is a quirk of the merge, not a choice, and is reported.
static func item(id: int) -> int:
	if is_azalea_leaves(id) or id == DRIPLEAF_SMALL or id == DRIPLEAF_SMALL_STEM: return 0
	if id == DRIPLEAF_BIG_STEM: return DRIPLEAF_BIG
	return id

# The block a tool returns instead of `item`: shears or Silk Touch, the source's
# `_mcl_shears_drop`/`_mcl_silk_touch_drop`. The leaves and the small dripleaf set
# them (mcl_trees/api.lua:199,202; dripleaf.lua:133); the stems set neither, and the
# big leaf has no drop override to preserve.
static func shears_item(id: int) -> int:
	return id if is_azalea_leaves(id) or id == DRIPLEAF_SMALL else 0

# `mcl_trees.generate_leaves_def` with both azalea forms as the sapling entries and
# `drop_apples = false` (nodes.lua:344-348), i.e. the shared table of
# mcl_trees/api.lua:296-330: `max_items = 1`, so the attempts below are ordered and
# the first success is the drop. The sapling row is the source's {20,16,12,10} for
# Fortune 0-3, extended by a repeated last value for Fortune 4 exactly as
# `WoodTypes.harvest` does for every other species.
static func leaf_drops(id: int, slot: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if not is_azalea_leaves(id): return []
	var held: int = int(slot.get("id",0))
	if held == Nodes.SHEARS or held != 0 and Inventory.enchantment(slot,"Silk Touch") > 0: return [[id,1]]
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var fortune: int = clampi(Inventory.enchantment(slot,"Fortune"),0,4) if held != 0 else 0
	var sticks: int = [50,45,30,35,10][fortune]
	if rng.randi_range(1,sticks) == 1: return [[Nodes.STICK,1]]
	if rng.randi_range(1,sticks) == 1: return [[Nodes.STICK,2]]
	var saplings: int = [20,16,12,10,10][fortune]
	# The source reaches both entries through `pairs`, whose order is unspecified;
	# the list's own order is used here so the roll is reproducible.
	if rng.randi_range(1,saplings) == 1: return [[AZALEA_FLOWERING,1]]
	if rng.randi_range(1,saplings) == 1: return [[AZALEA,1]]
	return []

# --- soil and placement rules ------------------------------------------------

# Source `group:soil_flower` members that exist in Voxey: grass block and dirt
# (mcl_core/nodes_base.lua:341,473), coarse dirt (:483), clay (:649), both
# farmland forms (mcl_farming/soil.lua:22,45), moss and rooted dirt
# (mcl_lush_caves/nodes.lua:83,241), mud (mcl_mud/init.lua:13) and pale moss.
# Mangrove mud roots are the remaining source-only soil variant.
static func azalea_soil(id: int) -> bool:
	return id in [Nodes.GRASS,Nodes.DIRT,COARSE_DIRT,VillageContent.SWAMP_GRASS,VillageContent.MUD,LushCaves.MOSS,
		Nodes.CLAY,Farmland.DRY,Farmland.WET,ROOTED_DIRT,PALE_MOSS,13602,13604]

# The source's `dripleaf_allowed` list (dripleaf.lua:3-15) mapped onto Voxey: dirt,
# coarse dirt, dirt with grass, rooted dirt, moss, both farmland forms, clay, mud,
# podzol and mycelium. Mangrove roots remain a separate source-only variant.
static func dripleaf_soil(id: int) -> bool:
	return id in [Nodes.DIRT,COARSE_DIRT,Nodes.GRASS,VillageContent.SWAMP_GRASS,ROOTED_DIRT,LushCaves.MOSS,
		Farmland.DRY,Farmland.WET,Nodes.CLAY,VillageContent.MUD,13602,13604]

# A big leaf may also stand on another big leaf (dripleaf.lua:240-243), which is
# how the source stacks a column; a small dripleaf may not.
static func big_dripleaf_soil(id: int) -> bool:
	return id == DRIPLEAF_BIG or dripleaf_soil(id)

# The one gate the parent needs at the placement point, mirroring
# `FlowersExtra.soil_ok`: azalea needs `soil_flower`, a small dripleaf
# `dripleaf_allowed`, a big leaf either list.
static func soil_ok(id: int, below: int) -> bool:
	if id == DRIPLEAF_SMALL or id == DRIPLEAF_SMALL_STEM: return dripleaf_soil(below)
	if id == DRIPLEAF_BIG: return big_dripleaf_soil(below)
	if is_azalea(id): return azalea_soil(below)
	return true

# Both source azaleas are explicit mcl_flowerpots registrations, not merely
# plants admitted by a broad group. Decor stores the returned id as pot_plant.
static func pottable(id: int) -> bool: return is_azalea(id)

# World-space placement hook. `normal` is the clicked face pointing into the new
# cell. Hanging roots' own on_place accepts only an underside click; the shared
# attached_node=4 check additionally requires a walkable support above. A spore
# blossom can be clicked from any face but applies its stricter support predicate.
static func can_place(world: VoxelWorld, p: Vector3i, id: int, normal: Vector3i = Vector3i.UP) -> bool:
	if id == LushCaves.HANGING_ROOTS: return normal == Vector3i.DOWN and attached_supported(world,p)
	if id == SPORE_BLOSSOM: return ceiling_supported(world,p)
	if is_azalea(id) or is_dripleaf(id): return soil_ok(id,world.node_at(p+Vector3i.DOWN))
	return true

static func attached_supported(world: VoxelWorld, p: Vector3i) -> bool:
	var above: Vector3i = p+Vector3i.UP
	return world.loaded_at(Vector3(above)) and Nodes.solid(world.node_at(above))

# Source `on_place` for the spore blossom (nodes.lua:387-400): the cell above must be
# opaque, an upright stair or a bottom slab. `Nodes.transparent` is Voxey's opacity
# test; the stair and slab cases need naming because Voxey counts every building
# shape as transparent.
static func ceiling_supported(world: VoxelWorld, p: Vector3i) -> bool:
	var above: int = world.node_at(p+Vector3i.UP)
	if BuildingShapes.is_shape(above):
		if BuildingShapes.variant(above) == 2: return true
		return (BuildingShapes.stair(above) or BuildingShapes.half_slab(above)) and not BuildingShapes.upper(above)
	return Nodes.solid(above) and not Nodes.transparent(above)

# Source `after_place_node`, which Voxey has no generic hook for: placing a small
# dripleaf leaves its **stem** behind and puts the leaf one cell up
# (dripleaf.lua:141-156), and placing a big leaf on another big leaf turns the lower
# one into a stem (dripleaf.lua:244-250).
static func placed(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if id == DRIPLEAF_SMALL:
		var above: int = world.node_at(p+Vector3i.UP)
		if above == Nodes.AIR or Nodes.plant(above):
			if world.set_node(p+Vector3i.UP,DRIPLEAF_SMALL): world.set_node(p,DRIPLEAF_SMALL_STEM)
	elif id == DRIPLEAF_BIG and world.node_at(p+Vector3i.DOWN) == DRIPLEAF_BIG:
		world.set_node(p+Vector3i.DOWN,DRIPLEAF_BIG_STEM)

# --- rooted dirt and interaction --------------------------------------------

# Source `_on_bone_meal` (nodes.lua:246-253): the air *below* rooted dirt becomes
# hanging roots, and nothing happens if that cell is occupied.
static func bone_meal_rooted_dirt(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	if world.node_at(below) != Nodes.AIR: return false
	return world.set_node(below,LushCaves.HANGING_ROOTS)

static func _bone_meal_feedback(game: Node3D, p: Vector3i) -> void:
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
	game.puff(Vector3(p+Vector3i.UP)+Vector3.ONE*0.5,Color("b8e07a"),8)
	game.sound("place"); game.player.swing = 1

# One dispatcher entry covers rooted dirt, moss, azaleas and the already-owned
# dripleaf bone-meal path. `rng` is optional and exists for deterministic world
# generation checks; ordinary player calls use a randomized generator.
static func use(game: Node3D, target: Dictionary, rng: RandomNumberGenerator = null) -> bool:
	if target.is_empty(): return false
	var p: Vector3i = target.pos
	var id: int = int(target.id)
	var held: int = int(game.inventory.held().id)
	if held == Nodes.BONE_MEAL:
		var grown: bool = false
		if id == ROOTED_DIRT: grown = bone_meal_rooted_dirt(game.world,p)
		elif is_azalea(id):
			grown = AzaleaTrees.grow(game.world,p,rng)
			# The source callback returns nil on a failed roll or clearance check;
			# nil still consumes bone meal and emits both dispatcher effects.
			_bone_meal_feedback(game,p)
			return true
		elif id == LushCaves.MOSS: grown = AzaleaTrees.bone_meal_moss(game.world,p,rng)
		elif bone_meal_target(id) != 0: grown = bone_meal(game.world,p,rng)
		else: return false
		if grown: _bone_meal_feedback(game,p)
		return true
	if id != ROOTED_DIRT: return false
	# mcl_core.bottle_dirt is registered on rooted dirt too.
	if held == VillageContent.WATER_BOTTLE: return MudBottles.convert(game,p)
	var kind: int = Nodes.tool_kind(held)
	if kind not in [2,4]: return false
	var above: Vector3i = p+Vector3i.UP
	if not game.world.loaded_at(Vector3(above)) or game.world.node_at(above) != Nodes.AIR: return true
	# Shovel paths reject only the clicked underside; the hoe accepts every face.
	if kind == 2 and target.get("normal",Vector3i.UP).y < 0: return true
	var converted: bool = false
	if kind == 4:
		# Source quirk: cultivate_dirt, not cultivate_soil. Rooted dirt becomes
		# ordinary dirt, then a hanging root below is removed and dropped.
		converted = game.world.set_node(p,Nodes.DIRT)
		if converted:
			var below: Vector3i = p+Vector3i.DOWN
			if game.world.node_at(below) == LushCaves.HANGING_ROOTS:
				game.world.set_node(below,Nodes.AIR)
				if game.gamemode != "creative": game.spawn_drop(Vector3(below)+Vector3.ONE*0.5,LushCaves.HANGING_ROOTS)
	else:
		converted = game.world.set_node(p,VillageContent.PATH)
	if converted:
		if game.gamemode != "creative": ToolCapabilities.action_wear(game.inventory)
		game.sound("dig"); game.player.swing = 1
	return true

# --- dripleaf ----------------------------------------------------------------

# Source `grow_big_dripleaf` (dripleaf.lua:18-31): the leaf at `p` moves one cell up
# and `p` becomes the stem under it, which needs the destination to be air.
static func grow(world: VoxelWorld, p: Vector3i) -> bool:
	if not is_dripleaf(world.node_at(p)) or world.node_at(p+Vector3i.UP) != Nodes.AIR: return false
	if not world.set_node(p+Vector3i.UP,DRIPLEAF_BIG): return false
	return world.set_node(p,DRIPLEAF_BIG_STEM)

# The topmost cell of the contiguous dripleaf column a node belongs to, which is
# `mcl_util.traverse_tower_group(pos, 1, "dripleaf")` in the source.
static func tower_top(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var top: Vector3i = p
	while is_dripleaf(world.node_at(top+Vector3i.UP)): top += Vector3i.UP
	return top

# The bone-meal result of a node: the small dripleaf's column ends in a big leaf,
# and a stem or a big leaf grows the column one cell (dripleaf.lua:208-212, :260-262).
# Returning the *stem* for a small dripleaf is deliberate: the node that bone meal
# rewrites in place is the stem of the new column.
static func bone_meal_target(id: int) -> int:
	# Bone meal on a small dripleaf grows the **leaf** into its big form; the stem
	# underneath is what `grow` raises to the big stem. Returning the stem here
	# would leave a stem with no leaf on top.
	if id == DRIPLEAF_SMALL: return DRIPLEAF_BIG
	if id == DRIPLEAF_BIG_STEM or id == DRIPLEAF_BIG: return DRIPLEAF_BIG
	return 0

# Source `_on_bone_meal` for a small dripleaf (dripleaf.lua:158-188). The source
# re-rolls `math.random(0,3)` on every pass, so the column usually stops early; each
# cell must be air or another dripleaf, and the leaf lands wherever the last pass
# left `i` — including on the small dripleaf's own cell when the first roll breaks.
static func bone_meal(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	var id: int = world.node_at(p)
	if id == DRIPLEAF_BIG_STEM or id == DRIPLEAF_BIG: return grow(world,tower_top(world,p))
	if id != DRIPLEAF_SMALL: return false
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var i: int = 0
	while i < rng.randi_range(0,3):
		var here: int = world.node_at(p+Vector3i(0,i,0))
		if here != Nodes.AIR and not is_dripleaf(here): break
		if not world.set_node(p+Vector3i(0,i,0),DRIPLEAF_BIG_STEM): break
		i += 1
	return world.set_node(p+Vector3i(0,i,0),DRIPLEAF_BIG)

# The source's own three-stage cycle (dripleaf.lua:301-307, :267-287): standing on an
# upright leaf gives `tipped_half`, that stage's half-second timer gives
# `tipped_full`, and its three-second timer returns the leaf to upright. `step`
# advances that many stages, so `tip(BIG,1)` is the half-tipped leaf and
# `tip(TIPPED_FULL,1)` is upright again.
static func tip(id: int, step: int = 1) -> int:
	var order: Array = [DRIPLEAF_BIG,DRIPLEAF_BIG_TIPPED_HALF,DRIPLEAF_BIG_TIPPED_FULL]
	var index: int = order.find(id)
	return order[posmod(index+step,order.size())] if index >= 0 else id

# The globalstep's own condition (dripleaf.lua:294-321): an upright big leaf that
# carries no redstone power. Powered leaves are absent from `current`, so arrival
# of power also discards an unfinished hold on the next globalstep.
static func tips(world: VoxelWorld, p: Vector3i) -> bool:
	return world.node_at(p) == DRIPLEAF_BIG and world.circuits.input_power(p) == 0

# The cell under one player's feet. Mineclonia nodes are centre-addressed while
# Voxey cells are minimum-corner addressed, hence the -0.5 coordinate conversion
# before applying dripleaf.lua:302's collisionbox-bottom + 0.45 sample.
static func standing_cell(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x),floori(position.y-0.05),floori(position.z))

# Only the upright big leaf tips; the tipped forms are already down.
static func tips_leaf(id: int) -> bool: return id == DRIPLEAF_BIG

# --- recipes -----------------------------------------------------------------

# The source has no recipe for any of these twelve ids. `crafting.lua` holds only
# the two moss recipes `LushCaves` already ports, `nodes.lua:109` is the moss
# carpet recipe (`moss_carpet 3` from two moss, which `LushCaves.recipes` does not
# include), and `dripleaf.lua` registers no craft at all; neither do the other mods
# that mention these names (the hoe and water-bottle placement tables in
# mcl_farming/hoes.lua:51 and mcl_potions/init.lua:189, and the wandering trader's
# `dripleaf_small 2`/`rooted_dirt 2` offers at
# mobs_mc/wandering_trader.lua:119,123). Acquisition is generation, trade and bone
# meal (including moss vegetation), so nothing is invented here.
static func recipes(_inv: Inventory) -> void:
	pass

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == ROOTED_DIRT: return rooted_pixel(x,y,noise)
	if id == SPORE_BLOSSOM: return blossom_pixel(x,y,noise)
	if is_azalea(id): return azalea_pixel(id == AZALEA_FLOWERING,x,y,noise)
	if is_azalea_leaves(id): return azalea_leaves_pixel(id == AZALEA_LEAVES_FLOWERING,x,y,noise)
	if is_dripleaf_stem(id): return stem_pixel(id,x,y,noise)
	if id == DRIPLEAF_SMALL: return small_leaf_pixel(x,y,noise)
	return big_leaf_pixel(id,x,y,noise)

# Dirt with pale root strands running down through it, the block's own look in the
# source's texture.
static func rooted_pixel(x: int, y: int, noise: Color) -> Color:
	if x in [2,6,10,13] and y%5 != 4 and (x*3+y)%7 < 6: return Color("cdbb95").darkened(0.10*float(y%3))
	return noise.darkened(0.12) if (x/2+y/2)%3 == 0 else noise

# A spore blossom hangs from a ceiling, so the stalk is at the top of the tile and
# the flower below it. The pale centre is the flower's throat, not a light: the
# checkout gives this node no `light_source`.
static func blossom_pixel(x: int, y: int, noise: Color) -> Color:
	if y < 4 and x in [7,8]: return Color("6f8f4a").darkened(0.10*float(y%2))
	if y == 4 and x in range(5,11): return Color("5d7c3f")
	var dx: float = x-7.5
	var dy: float = y-8.5
	if dx*dx*0.8+dy*dy > 13.0: return Color(0,0,0,0)
	if dy > 2.0: return noise.lerp(Color("b8637f"),0.8)
	if absf(dx) < 1.5: return Color("f2e6ec")
	return Color("d9869f").darkened(0.08*float((x+y)%3))

# A bush: a rounded leaf mass over a short trunk, with pink blossoms on the
# flowering form.
static func azalea_pixel(flowering: bool, x: int, y: int, noise: Color) -> Color:
	if y >= 12 and x in [7,8]: return Color("6b4a33").darkened(0.12*float(y%3))
	var dx: float = x-7.5
	var dy: float = y-7.0
	if dx*dx*0.9+dy*dy > 30.0: return Color(0,0,0,0)
	if flowering and (x*5+y*7)%17 < 3: return Color("dd8eac")
	if (x*7+y*3)%11 < 2: return Color("4e7f3c")
	return noise.darkened(0.14) if (x+y)%3 == 0 else noise

# Dense small leaves. The tile is opaque on purpose: an azalea leaf is a `cube` in
# Voxey and `Nodes.transparent` resolves a `VillageContent` cube to *occluding*, so
# a punched hole would expose the neighbour faces the mesher culls.
static func azalea_leaves_pixel(flowering: bool, x: int, y: int, noise: Color) -> Color:
	if flowering and (x*5+y*3)%23 < 2: return Color("dd8eac")
	if (x*7+y*11+x*y)%19 in [0,1]: return noise.darkened(0.34)
	if (x/3+y/3)%2 == 0: return noise.darkened(0.18)
	return noise.lightened(0.05)

# A stem is a ribbed strand down the middle of the tile. The big stem is the
# source's wider column, six pixels across to a small stem's two.
static func stem_pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var edge: float = absf(x+0.5-8.0)
	if edge > (3.0 if id == DRIPLEAF_BIG_STEM else 1.0): return Color(0,0,0,0)
	if y%4 == 0: return noise.darkened(0.20)
	return noise.lightened(0.08) if edge > 1.0 else noise

# The small dripleaf's blade hangs in the lower half of the tile off the stem above
# it, which is why the source's own selection box reaches a full cell below the
# node (dripleaf.lua:127-130).
static func small_leaf_pixel(x: int, y: int, noise: Color) -> Color:
	if y < 3 and x in [7,8]: return Color("5c8b3c")
	if y < 5: return Color(0,0,0,0)
	var dx: float = x-7.5
	var dy: float = y-10.5
	if dx*dx*0.55+dy*dy > 20.0: return Color(0,0,0,0)
	if x in [7,8]: return noise.darkened(0.30)
	if dy > 3.0: return noise.darkened(0.20)
	return noise.lightened(0.06) if (x+y)%3 == 0 else noise

# The big leaf, opaque because it is a `cube` (see the header): the midrib runs down
# the centre, the fold ridge sits near the top, and the two tipped stages swing the
# blade down so the three states read apart at a glance.
static func big_leaf_pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var tip: int = 0 if id == DRIPLEAF_BIG else (1 if id == DRIPLEAF_BIG_TIPPED_HALF else 2)
	var ridge: int = 3+tip*3
	var middle: bool = x in [7,8]
	if y < ridge: return noise.darkened(0.30) if middle else noise.darkened(0.16)
	if middle: return noise.darkened(0.26)
	if y >= ridge+3 and tip < 2 and (x*5+y*3)%17 < 2: return noise.lightened(0.12)
	return noise.darkened(0.10) if (x+y)%4 == 0 else noise

# --- simulation --------------------------------------------------------------

const DIG_CASCADE_DELAY = 0.05
const PLAYER_HALF_WIDTH = 0.29
const PLAYER_COLLISION_BOTTOM = 0.0

# Upright and half-tipped leaves retain the big definition's top collision plate:
# source local Y 0.45..0.5 becomes Voxey cell Y 0.95..1.0 (a literal 0.05 height).
# Full-tipped merges `walkable = false`; despite inheriting the collision_box
# field, Luanti does not make it walkable, so its live collision set is empty.
static func collision_boxes(id: int) -> Array:
	if id == DRIPLEAF_BIG or id == DRIPLEAF_BIG_TIPPED_HALF:
		return [AABB(Vector3(0,0.95,0),Vector3(1,0.05,1))]
	return []

static func walkable(id: int) -> bool:
	return id == DRIPLEAF_BIG or id == DRIPLEAF_BIG_TIPPED_HALF

# Source get_player_dripleaves scans the whole X/Z footprint, not merely the cell
# containing the player's origin. Its small 0.501/0.499 epsilons are retained;
# positions are converted from Voxey's minimum-corner cells to source-centred
# cells before applying them. Only upright, unpowered leaves enter a hold.
static func player_dripleaves(world: VoxelWorld, position: Vector3, half_width: float = PLAYER_HALF_WIDTH, collision_bottom: float = PLAYER_COLLISION_BOTTOM) -> Dictionary:
	var found: Dictionary = {}
	var min_x: int = floori(position.x-0.5-half_width+0.501)
	var max_x: int = floori(position.x-0.5+half_width+0.499)
	var min_z: int = floori(position.z-0.5-half_width+0.501)
	var max_z: int = floori(position.z-0.5+half_width+0.499)
	var y: int = floori(position.y-0.5+collision_bottom+0.45)
	for x in range(min_x,max_x+1):
		for z in range(min_z,max_z+1):
			var p := Vector3i(x,y,z)
			if world.loaded_at(Vector3(p)) and tips(world,p): found[p] = true
	return found

# Per-player holds exactly follow player_dripleaf in the source: a hold belongs to
# one player and one leaf, and only currently occupied cells survive into the next
# globalstep. Consequently stepping off, losing power and disconnecting all reset
# an unfinished hold. Half/full timers are independent of every player.
static func update(world: VoxelWorld, delta: float, players: Variant = null) -> void:
	if world.network_replica or not is_finite(delta) or delta < 0: return
	var state: Dictionary = runtime(world)
	_advance_timers(world,state,delta)
	var samples: Array = connected_players(world) if players == null else players
	var active: Dictionary = {}
	for sample in samples:
		var normalized: Dictionary = _player_sample(sample)
		if normalized.is_empty(): continue
		var key: Variant = normalized.key
		active[key] = true
		var previous: Dictionary = state.holds.get(key,{}).duplicate()
		var current: Dictionary = player_dripleaves(world,normalized.position,normalized.width,normalized.bottom)
		var next: Dictionary = {}
		for p in current:
			var elapsed: float = float(previous.get(p,0.0))+delta
			if elapsed > TIP_STAND_TIME:
				# Another player may have tipped this leaf earlier in the same step.
				if tips(world,p):
					if world.set_node(p,DRIPLEAF_BIG_TIPPED_HALF): state.timers[p] = 0.0
			else: next[p] = elapsed
		if next.is_empty(): state.holds.erase(key)
		else: state.holds[key] = next
	for key in state.holds.keys():
		if not active.has(key): state.holds.erase(key)

static func _advance_timers(world: VoxelWorld, state: Dictionary, delta: float) -> void:
	for key in state.timers.keys():
		if not key is Vector3i: state.timers.erase(key); continue
		var p: Vector3i = key
		if not world.loaded_at(Vector3(p)): state.timers.erase(p); continue
		var id: int = world.node_at(p)
		if not is_dripleaf_tipped(id): state.timers.erase(p); continue
		var elapsed: float = float(state.timers[p])+delta
		var limit: float = TIP_HALF_TIME if id == DRIPLEAF_BIG_TIPPED_HALF else TIP_FULL_TIME
		if elapsed < limit:
			state.timers[p] = elapsed
			continue
		var next: int = tip(id,1)
		if not world.set_node(p,next): state.timers.erase(p)
		elif next == DRIPLEAF_BIG: state.timers.erase(p)
		else: state.timers[p] = 0.0

# Records contain key, position and optional width/bottom. The optional argument
# is a deterministic/test adapter and a seam for alternative player providers.
static func _player_sample(sample: Variant) -> Dictionary:
	if sample is Node3D:
		if not is_instance_valid(sample): return {}
		return {"key":sample.get_instance_id(),"position":sample.position,"width":PLAYER_HALF_WIDTH,"bottom":PLAYER_COLLISION_BOTTOM}
	if not sample is Dictionary or not sample.get("position",null) is Vector3: return {}
	return {"key":sample.get("key",sample.get("id",0)),"position":sample.position,
		"width":float(sample.get("width",PLAYER_HALF_WIDTH)),"bottom":float(sample.get("bottom",PLAYER_COLLISION_BOTTOM))}

# Authority-side local player plus every network roster member. Roster positions
# are used directly, so a valid but not-yet-created avatar cannot omit a player.
static func connected_players(world: VoxelWorld) -> Array:
	var result: Array = []
	var game: Node = world.get_parent()
	if game == null: return result
	var local_key: Variant = 0
	var network: Node = game.get("network")
	if network != null and network.active() and not network.client(): local_key = network.multiplayer.get_unique_id()
	if is_instance_valid(game.player): result.append({"key":local_key,"position":game.player.position})
	if network != null and network.active() and not network.client():
		for key in network.players:
			if key == local_key: continue
			var record: Dictionary = network.players[key]
			if record.get("position",null) is Vector3: result.append({"key":key,"position":record.position})
	return result

static func player_left(world: VoxelWorld, key: Variant) -> void:
	runtime(world).holds.erase(key)

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("dripleaf"): world.set_meta("dripleaf",{"holds":{},"timers":{}})
	return world.get_meta("dripleaf")

static func _erase_cell_holds(state: Dictionary, p: Vector3i) -> void:
	for key in state.holds.keys():
		state.holds[key].erase(p)
		if state.holds[key].is_empty(): state.holds.erase(key)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if world.network_replica: return
	var state: Dictionary = runtime(world)
	if old_id != id:
		state.timers.erase(p)
		_erase_cell_holds(state,p)
	registered(world,p,id)
	validate_support(world,p)
	validate_support(world,p+Vector3i.DOWN)

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not world.loaded_at(Vector3(p)): return
	var state: Dictionary = runtime(world)
	if is_dripleaf_tipped(id) and not state.timers.has(p): state.timers[p] = 0.0
	if is_ceiling_plant(id): validate_support(world,p)

# attached_node=4 placement uses the stricter on_place predicates above, while
# subsequent support checks only require the support to remain walkable. Thus a
# spore blossom placed under stone survives replacement by non-opaque glass.
static func validate_support(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if not is_ceiling_plant(id) or not world.loaded_at(Vector3(p+Vector3i.UP)) or attached_supported(world,p): return
	if not world.set_node(p,Nodes.AIR): return
	# Hanging roots have source drop="" and attached loss supplies no shears.
	if id == SPORE_BLOSSOM:
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_drop"): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,id)

# Source after_dig_node schedules both vertical neighbours after 0.05 s. Recursive
# core.dig_node calls continue the cascade, but only through group:dripleaf nodes.
static func dug(game: Node3D, p: Vector3i, old_id: int) -> void:
	if not is_dripleaf(old_id) or game.network != null and game.network.client(): return
	_delayed_dig(game,p)

static func _delayed_dig(game: Node3D, p: Vector3i) -> void:
	await game.get_tree().create_timer(DIG_CASCADE_DELAY).timeout
	if not is_instance_valid(game) or not is_instance_valid(game.world): return
	_dig_adjacent(game,p+Vector3i.UP)
	_dig_adjacent(game,p+Vector3i.DOWN)

static func _dig_adjacent(game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	if not world.loaded_at(Vector3(p)): return
	var id: int = world.node_at(p)
	if not is_dripleaf_group(id) or not world.set_node(p,Nodes.AIR): return
	game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.drop(id))
	dug(game,p,id)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if world.network_replica: return
	for p in world.column_edits(column):
		if world.loaded_at(Vector3(p)): registered(world,p,world.node_at(p))
	# A ceiling plant may live immediately below the newly arrived column.
	for p in world.edits_near(column):
		validate_support(world,p)
		validate_support(world,p+Vector3i.DOWN)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("dripleaf"): return
	var state: Dictionary = runtime(world)
	for p in state.timers.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: state.timers.erase(p)
	for key in state.holds.keys():
		for p in state.holds[key].keys():
			if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: state.holds[key].erase(p)
		if state.holds[key].is_empty(): state.holds.erase(key)

static func reset(world: VoxelWorld) -> void:
	world.set_meta("dripleaf",{"holds":{},"timers":{}})
