class_name BonusChest
extends RefCounted

# Mineclonia PLAYER/mcl_bonus_chest/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# A new survival world hands the player a going-away present: one chest of
# weighted loot beside the spawn point, ringed by four torches. The source has
# three parts, and all three are reproduced here.
#
# * **The loot table** (init.lua:12-93) is fourteen groups, each with
#   `stacks_min = 1` and `stacks_max = 1`, so a chest draws one stack from every
#   group and therefore always holds fourteen stacks. A
#   group whose entries carry no
#   `amount_min`/`amount_max` yields a single item, exactly as
#   `ItemStack(itemstring)` does in `mcl_loot.get_loot`
#   (CORE/mcl_loot/init.lua:66-79); every other entry rolls its own inclusive
#   range. The wooden tool in each tool group carries the source's 3:1 weight
#   over its stone counterpart.
# * **The placement** (init.lua:130-149): search `pos + (-5,-3,-5)` to
#   `pos + (5,3,5)` for supports that have air above them — `core.find_nodes_in_area_under_air`
#   over dirt-with-grass, stone and `group:solid` — pick one at random, and put
#   the chest in the air cell above it. Then, for each of the four horizontal
#   neighbours (`adj`, init.lua:4-9), place a torch when the neighbour is a
#   `buildable_to` node.
# * **The offer** (init.lua:151-161): only a brand-new world in survival gets one,
#   and only once — the source guards it with a `mcl_bonus_chest:deployed`
#   storage flag. `mcl_bonus_chest` itself ships **off** (`core.settings:get_bool`
#   defaults to `false`); Voxey has no server setting for it, so the parent's
#   startup call site is what enables it and `should_offer` answers only the
#   survival half.
#
# Two Voxey-side notes:
#
# * The source's default `pr` is
#   `PcgRandom(core.hash_node_position(pos) + core.get_mapgen_setting("seed"))`
#   (init.lua:131), i.e. a chest's contents are a function of its position and the
#   world seed. `rng_at` is that analogue, so a reload re-rolls the same chest.
#   The source threads that one `pr` through both the site pick and the loot; the
#   two halves live in separate calls here (`site` then `place`), so the site pick
#   seeds from the spawn anchor and the loot seeds from the chest cell.
# * `mcl_trees:wood_oak` is the source's **planks** node (`mcl_trees.register_wood`
#   registers `mcl_trees:wood_<name>` with the planks texture,
#   ITEMS/mcl_trees/api.lua:403-408), while `mcl_trees:tree_<name>` is the log. The
#   table's `wood_oak` entry is therefore oak planks and its `tree_*` entries are
#   the six Voxey logs.
# * Voxey has no cherry blossom wood, so that group's seventh sapling has no id.
#   Its entry is dropped, which the saplings constant explains.

# The four horizontal neighbours, in the source's `adj` order (init.lua:4-9).
const SIDES = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]
# `site` reports this when the source's `find_nodes_in_area_under_air` found no
# support at all, which is also the sentinel the other structure planners use.
const NOWHERE = Vector3i(0,2147483647,0)
# The source's `mcl_bonus_chest:deployed` storage flag, kept in the world's
# adventure state so a reloaded world never hands out a second chest.
const DEPLOYED = "bonus_chest"
const OFFERED_LABEL = "Bonus chest"

# Voxey tool ids are `Nodes.TOOLS + kind + tier*5` (nodes.gd:595,597) with kind 0
# the pickaxe and 1 the axe (nodes.gd:400, `KIND_NAMES`) and tier 0 wood, 1 stone.
const PICK_WOOD = Nodes.TOOLS
const AXE_WOOD = Nodes.TOOLS+1
const PICK_STONE = Nodes.TOOLS+5
const AXE_STONE = Nodes.TOOLS+6

# `mcl_tools:axe_wood` / `axe_stone`, weight 3 / 1 (init.lua:16-19).
const AXES = [[AXE_WOOD,3,1,1],[AXE_STONE,1,1,1]]
# `mcl_tools:pick_wood` / `pick_stone`, weight 3 / 1 (init.lua:24-27).
const PICKS = [[PICK_WOOD,3,1,1],[PICK_STONE,1,1,1]]
const APPLES = [[Nodes.APPLE,1,1,3]]
const BREADS = [[Nodes.BREAD,1,1,2]]
const SALMON = [[VillageContent.RAW_SALMON,1,1,2]]
const STICKS = [[Nodes.STICK,1,1,12]]
# `mcl_trees:wood_oak`, which is Oak Planks rather than a log (see the header).
const PLANKS = [[Nodes.PLANKS,1,1,12]]
const MUSHROOMS = [[Nodes.BROWN_MUSHROOM,1,1,12]]
# `mcl_trees:sapling_<name>`. The source lists seven species — oak, spruce,
# birch, dark oak, acacia, jungle and cherry blossom — and Voxey has the first
# six as `WoodTypes.SAPLINGS` in a different order, which the indices pick out.
# Cherry blossom has no Voxey wood type, so its entry is **dropped** rather than
# kept as a zero id: every entry in this group weighs 1, so dropping it leaves the
# six real saplings at equal odds and, unlike the zero-id convention, preserves
# the source's guaranteed fourteen stacks per chest.
const SAPLINGS = [[WoodTypes.SAPLINGS[0],1,1,4],[WoodTypes.SAPLINGS[1],1,1,4],[WoodTypes.SAPLINGS[2],1,1,4],
	[WoodTypes.SAPLINGS[5],1,1,4],[WoodTypes.SAPLINGS[4],1,1,4],[WoodTypes.SAPLINGS[3],1,1,4]]
# `mcl_trees:tree_acacia` / `tree_dark_oak` (init.lua:90-95).
const ACACIA_AND_DARK_OAK = [[WoodTypes.LOGS[4],1,1,3],[WoodTypes.LOGS[5],1,1,3]]
# `mcl_trees:tree_birch`, `tree_jungle`, `tree_oak`, `tree_spruce` (init.lua:96-103).
const TREES = [[WoodTypes.LOGS[2],1,1,3],[WoodTypes.LOGS[3],1,1,3],[WoodTypes.LOGS[0],1,1,3],[WoodTypes.LOGS[1],1,1,3]]
const ROOTS = [[VillageContent.POTATO,1,1,2],[VillageContent.CARROT,1,1,2]]
const SEEDS = [[FruitCrops.PUMPKIN_SEEDS,1,1,2],[FruitCrops.MELON_SEEDS,1,1,2],[VillageContent.BEETROOT_SEEDS,1,1,2]]
const COCOA_AND_CACTUS = [[VillageContent.COCOA_BEANS,1,1,2],[Nodes.CACTUS,1,1,2]]

# The source's `bonus_loot`, one entry per group with its own
# `stacks_min`/`stacks_max`, both 1 in every group (init.lua:12-93).
const GROUPS = [[AXES,1,1],[PICKS,1,1],[APPLES,1,1],[BREADS,1,1],[SALMON,1,1],[STICKS,1,1],[PLANKS,1,1],
	[MUSHROOMS,1,1],[SAPLINGS,1,1],[ACACIA_AND_DARK_OAK,1,1],[TREES,1,1],[ROOTS,1,1],[SEEDS,1,1],[COCOA_AND_CACTUS,1,1]]

# `mcl_loot.get_multi_loot` (CORE/mcl_loot/init.lua:104-113): every group rolls
# `stacks_min`..`stacks_max` stacks, and each stack is one weighted pick with its
# own amount roll. `Dungeons.weighted` is this project's shared implementation of
# that pick, including the zero-id convention.
static func roll(rng: RandomNumberGenerator) -> Array:
	var items: Array = []
	for group in GROUPS:
		for stack in rng.randi_range(int(group[1]),int(group[2])):
			var pick: Dictionary = Dungeons.weighted(rng,group[0])
			if pick.is_empty(): continue
			if not pick.has("data"): pick.data = {}
			items.append(pick)
	return items

# The source offers a chest only for a brand-new world in survival; the "new" half
# is the call site's job (init.lua:151-161).
static func should_offer(gamemode: String) -> bool:
	return gamemode == "survival"

# The source's default `pr` (init.lua:131), which is also what makes a chest's
# contents stable. `TerrainGenerator.hash_at` already folds in the world seed.
static func rng_at(world: VoxelWorld, at: Vector3i) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.generator.hash_at(at.x,at.y,at.z)
	return rng

# `find_nodes_in_area_under_air(pos + (-5,-3,-5), pos + (5,3,5), {...})` followed
# by `pp[pr:next(1,#pp)]` and the `+1` on y: returns the chest cell itself, or
# `NOWHERE` when the box holds no supported air cell (init.lua:133-135).
static func site(world: VoxelWorld, near: Vector3i) -> Vector3i:
	var candidates: Array = []
	for y in range(near.y-3,near.y+4):
		for z in range(near.z-5,near.z+6):
			for x in range(near.x-5,near.x+6):
				var p := Vector3i(x,y,z)
				# Unloaded cells read as bedrock, and a structure may never be
				# planned from them.
				if not world.loaded_at(Vector3(p)): continue
				var id: int = world.node_at(p)
				if id != Nodes.GRASS and id != Nodes.STONE and not Nodes.solid(id): continue
				# The engine's own "under air" rule: the cell above must be air.
				if world.node_at(p+Vector3i.UP) != Nodes.AIR: continue
				candidates.append(p)
	if candidates.is_empty(): return NOWHERE
	var rng: RandomNumberGenerator = rng_at(world,near)
	return candidates[rng.randi_range(0,candidates.size()-1)]+Vector3i.UP

# Put a filled chest at exactly `at`, then a torch in each of the four neighbours
# that the source would accept (init.lua:130-149). Returns whether the chest went
# in: a non-air cell is never overwritten, which is the source's `place_node`
# refusing anything that is not `buildable_to`.
static func place(game: Node3D, at: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.node_at(at) != Nodes.AIR: return false
	if not world.set_node(at,Nodes.CHEST): return false
	# One generator for the loot and the slot shuffle, as the source threads a
	# single `pr` through `get_multi_loot` and `fill_inventory`.
	var rng: RandomNumberGenerator = rng_at(world,at)
	_fill(world.get_station(at,"chest"),roll(rng),rng)
	for side in SIDES:
		var t: Vector3i = at+side
		if not _replaceable(world.node_at(t)): continue
		# A floor torch is `attached_node`: the source's engine drops it again
		# unless the cell below it is walkable, so it is only placed where it stays.
		if not BuildingShapes.supports(world,t+Vector3i.DOWN,Vector3i.UP): continue
		world.set_node(t,Nodes.TORCH)
	return true

# The whole of `register_on_newplayer`: the survival check, the once-only
# `deployed` flag, the site search and the placement. The source's five-second
# `core.after` delay exists only because the player's position is not final at
# `on_newplayer` time; Voxey calls this once the spawn position is settled.
static func offer(game: Node3D, near: Vector3) -> bool:
	var world: VoxelWorld = game.world
	if not should_offer(game.gamemode): return false
	if bool(world.adventure_state.get(DEPLOYED,false)): return false
	var at: Vector3i = site(world,Vector3i(near.floor()))
	var placed: bool = at != NOWHERE and place(game,at)
	# The source sets its flag after the attempt, successful or not
	# (init.lua:157-158).
	world.adventure_state[DEPLOYED] = true
	return placed

# `mcl_loot.fill_inventory` (CORE/mcl_loot/init.lua:133-164): the stacks go into
# slots drawn without replacement, which is `get_random_slots`. The source's
# second pass only matters when there are more stacks than slots, and this table
# has fourteen groups against a chest's twenty-seven.
static func _fill(station: Dictionary, items: Array, rng: RandomNumberGenerator) -> void:
	var order: Array = []
	var free: Array = range(station.slots.size())
	while not free.is_empty():
		var pick: int = rng.randi_range(0,free.size()-1)
		order.append(free[pick]); free.remove_at(pick)
	for i in mini(items.size(),station.slots.size()): station.slots[order[i]] = items[i].duplicate(true)
	station.label = OFFERED_LABEL

# The source's `buildable_to` set: air, liquids, snow layers, plants and fire are
# the nodes a torch may replace.
static func _replaceable(id: int) -> bool:
	return id == Nodes.AIR or SnowCover.is_snow(id) or Nodes.plant(id) or Fluids.liquid(id) or Fire.is_fire(id)

# PARENT WIRING (not applied; every line below belongs to a file this module must
# not edit):
#
# 1. `scripts/game.gd`, `_finish_loading`, in the new-world `else:` branch (the
#    source's `register_on_newplayer`, init.lua:151-161), beside
#    `player.camera.rotation.x=-0.12`:
#        BonusChest.offer(self,player.position)
#    `offer` does the survival check, the once-per-world flag, the source's
#    `find_nodes_in_area_under_air` search and the chest-plus-torches placement,
#    and it is a no-op on a reloaded world. Do not call it in the
#    `if pending_save.has(...)` load path: the source offers a chest to a new
#    world only.
# 2. `tests/lifecycle_runner.gd`: the default checks array already ends with
#    "bonus_chest" (applied with this module); keep every earlier entry.
#
# No registry, dispatcher, recipe, metadata allow-list or art entry is needed:
# the chest and the torches are existing nodes and every item comes from the
# existing catalogue. Persistence is `world.adventure_state["bonus_chest"]`,
# which is already part of the save's `adventure` snapshot.
