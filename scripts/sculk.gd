class_name Sculk
extends RefCounted

# Mineclonia ITEMS/mcl_sculk/{init.lua,lg_register.lua}, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference; all art is original
# procedural code. Nothing is copied from the source textures.
#
# What the checkout actually registers
# ------------------------------------
# `mcl_sculk` is a live mod (`mods/ITEMS/mcl_sculk/mod.conf`), but two of its four
# content families are commented out in this checkout, and the levelgen half is a
# stub. Ported here: **sculk, sculk vein, sculk catalyst and the echo shard**, which
# are the four registrations that are *not* inside a comment block:
#
#   - `init.lua:184` `mcl_sculk:sculk`      live
#   - `init.lua:206` `mcl_sculk:vein`       live
#   - `init.lua:234` `mcl_sculk:catalyst`   live
#   - `init.lua:289` `mcl_sculk:echo_shard` live
#
# **Absent from the source, and therefore absent here:**
#
#   - `mcl_sculk:sensor` (`init.lua:253-269`) and `mcl_sculk:shrieker`
#     (`init.lua:270-286`) are inside `--[[ ... --]]` opened at `init.lua:252`
#     and closed at `init.lua:287`, so neither node is registered. The source
#     textures exist on disk, but a texture is not a registration.
#   - The whole detection block is commented out too: `init.lua:27` opens `--[[`
#     and `init.lua:71` closes `--]]`, covering `sensor_action` (`:28`), the
#     `core.sound_play` override (`:44`) and the `mcl_walkover.register_global`
#     scan (`:59`). `SENSOR_RANGE`, `SENSOR_DELAY` and `SHRIEKER_COOLDOWN` are
#     commented per-line at `init.lua:14-16`; only `SPREAD_RANGE` (`:13`) is live.
#   - The shrieker/sensor *generation* branch inside `spread_sculk` is commented:
#     `init.lua:141` comments out `local d = math.random(100)` and `init.lua:142`
#     opens `--[[ --enable to generate shriekers and sensors`, which runs to
#     `init.lua:153` (`else --]]`). The `if d <= 1 then` shrieker branch and the
#     `elseif d <= 9 then` sensor branch are therefore dead. The live code is only
#     the plain `sculk`/`vein` loop at `init.lua:156-169`.
#   - `lg_register.lua` registers mapgen features but performs nothing: the sculk
#     spread logic (`:16-40`) and the patch iterator (`:46-90`) are both comment
#     blocks, `mcl_sculk:sculk_patch`'s `place` stub returns `false` (`:94-98`),
#     and both placed-feature modifier lists are empty with `-- Not yet
#     implemented.` (`:131-135`, `:141-143`). So there is **no world generation of
#     sculk anywhere in the checkout**, and no DeepDark biome in Voxey either.
#   - There is no Warden, and nothing in the checkout references one.
#
# With no sensor, no shrieker, no Warden and no generation, the only live way sculk
# enters a world is the death-driven spread below, and the only live way to *obtain*
# a sculk block is Silk Touch.
#
# Source rules reproduced here:
#
# * **Drops.** `mcl_sculk:sculk` and `mcl_sculk:catalyst` carry `drop = ""` with
#   `_mcl_silk_touch_drop = true` (`init.lua:195/203`, `:241/249`), and
#   `mcl_sculk:vein` carries `drop = ""` with `_mcl_shears_drop = true`
#   (`init.lua:227-228`). So an ordinary break yields nothing at all, Silk Touch
#   returns the block, and a vein needs *shears*. `ENTITIES/mcl_item_entity/
#   init.lua:171-187` is where the engine picks between the two: shears are tested
#   first, Silk Touch only as the `elseif`. `"drop": 0` records "drops nothing" in
#   the DATA, which is this project's annotation for it (`scripts/glass_colors.gd:
#   44-45`, and `Amethyst` buds, `DenseMaterials` ice and `Beehives` use the same).
#   Note `Nodes.drop` has no generic `"drop"` reader for `VillageContent.DATA`
#   entries, so the annotation is documentation until the parent wires the branch;
#   `harvest` below is the reader.
# * **Experience.** `sculk_after_dig_node` (`init.lua:82-107`) throws the node's
#   stored `xp` metadata, or `1` when the node's `param2 == 1`, and throws none when
#   Silk Touch was used *and* the tool could harvest the node. Voxey has no param2
#   table and no experience orbs, so the stored value lives in `world.block_states`
#   and the param2 rule is reproduced by presence: a player-placed block has no
#   stored value, which is exactly the `place_param2 = 1` case, so it yields 1.
# * **Spread.** `spread_sculk` (`init.lua:135-173`): a catalyst within
#   `SPREAD_RANGE = 8` (`:13`, max-metric, `core.find_node_near`) gates it; the
#   replaceable set is `spread_to` (`init.lua:4`) filtered to nodes with an adjacent
#   non-solid cell (`has_air`, `:109-113`), sorted nearest-first (`:121-133`); a
#   random count `r = min(random(#nn), xp_amount)` of the nearest cells become
#   sculk, each storing `floor(xp_amount/r)` and the first getting the remainder;
#   then for each new sculk, the first adjacent solid non-sculk cell with air beside
#   it takes a **vein above it** at `param2 = 1` (`:162-167`). `param2 = 1` is
#   wallmounted `y-` (Luanti `lua_api.md`: "0 = y+, 1 = y-"), i.e. mounted under
#   the block above it, which is the same thing as hanging on the non-sculk
#   neighbour's face.
# * **The hook.** `core.register_on_dieplayer(function(player) ... handle_death(
#   player:get_pos(), 5) end)` (`init.lua:180-182`), so a death spreads five points
#   of sculk from the death position.
#
# What the parent needs to wire
# -----------------------------
# This module is self-contained but inert until these calls exist:
#
#  1. **The death hook.** Call `Sculk.handle_death(world,pos,rng,5)` when the player
#     dies, from wherever `DeathRecovery` records the death position
#     (`scripts/death_recovery.gd`). `rng` can be a world-seeded generator.
#  2. **Break wiring.** In `Game.break_node`'s drop path, `Sculk.harvest(id,slot)` is
#     the drop list for these ids (empty on an ordinary break, the block under Silk
#     Touch, the vein under shears only). `Sculk.harvest_xp(...)` is the experience
#     to add, which the source suppresses under Silk Touch. Neither is reachable
#     through `Nodes.drop`, whose generic `"drop"` reader does not cover
#     `VillageContent.DATA` entries yet.
#  3. **Light.** Add `Sculk.light_level(id)` to `Pasture.emission`, next to the
#     `Amethyst`, `Copper` and `Candles` branches, so the catalyst emits 6.
#  4. **Climbing.** Add `Sculk.climbable(world,cell)` to the vine/ladder test in
#     `Player`'s movement, beside `LushCaves.climbable` and `Scaffolding.climbable`,
#     because the vein is `climbable = true`.
#  5. **Placement support.** The vein is `buildable_to` and `wallmounted` in the
#     source and is *only* produced by the spread, which places it in the cell above
#     a non-sculk neighbour. If the parent lets a player place one, the cell to use
#     is `target.pos+target.normal`'s opposite face; the source's `on_rotate = false`
#     (`init.lua:231`) means no rotation handling is wanted.
#  6. **Piston and fluid groups.** The source marks sculk and the catalyst
#     `unmovable_by_piston = 1` (`init.lua:196`, `:243`) and the vein `dig_by_piston
#     = 1`, `destroy_by_lava_flow = 1`, `dig_by_water = 1` (`init.lua:224`). These
#     belong to `RedstoneCircuit`'s movability test
#     (`scripts/redstone_circuit.gd:483`) and the fluid rules, not to this module.
#  7. **Recipes.** `recipes` registers nothing on purpose: the source has none. See
#     the note there for the echo shard's real acquisition.

const SCULK = 11507
const VEIN = 11508
const CATALYST = 11509
const ECHO_SHARD = 11510
const BLOCKS = [SCULK,VEIN,CATALYST]

# Source `init.lua:13`, live. Used both as the catalyst search radius and as the
# half-extent of the spreadable-node scan (`:122`).
const SPREAD_RANGE = 8
# Source `init.lua:181`: `mcl_sculk.handle_death(player:get_pos(), 5)`.
const DEATH_XP = 5
# Source `light_source = 6` on the catalyst only (`init.lua:247`).
const CATALYST_LIGHT = 6
# Source `_mcl_silk_touch_drop` on sculk, vein and catalyst.
const SILK_TOUCH = "Silk Touch"
# A per-node key inside `world.block_states`, which is where this project keeps the
# state a Luanti node would carry in its metadata or param2.
const XP_KEY = "sculk_xp"

# The source's `spread_to` list (`init.lua:4`), mapped to the ids that exist here.
# `group:grass_block` becomes `Nodes.GRASS` and `group:dirt` becomes `Nodes.DIRT`,
# which are the two groups the source list names; the individual `mcl_core:stone`,
# `:dirt`, `:sand`, `:andesite`, `:diorite`, `:granite`, `:end_stone`,
# `:netherrack`, `:basalt`, `:soul_sand`, `:gravel` and `:deepslate` entries are the
# ids themselves. `mcl_deepslate:tuff` is `MinecloniaOres.TUFF`.
#
# Four ids are written as literals because `VillageContent.DATA` references
# `Sculk.DATA`, so a const initialiser here naming `VillageContent` or `Campfires`
# would close a dependency cycle. `village_content.gd:32-36` writes the lush-cave
# ids out for exactly this reason.
const ANDESITE = 535 # VillageContent.ANDESITE
const DIORITE = 534 # VillageContent.DIORITE
const GRANITE = 533 # VillageContent.GRANITE
const SOUL_SOIL = 1223 # Campfires.SOUL_SOIL
#
# **Left out of the list, with the reason:**
#   - `mcl_core:mycelium` — Voxey has no mycelium (`scripts/huge_mushrooms.gd:140`
#     records the same gap).
#   - `mcl_core:coarse_dirt` — Voxey has no coarse dirt (same note).
#   - `mcl_mud:mud` — the source's `mcl_mud:mud` does carry `grass_block=1`
#     (`ITEMS/mcl_mud/init.lua:13`) so `group:grass_block` selects it, but
#     `docs/mineclonia-parity.md:223` lists `mcl_mud` as **Unreviewed**, so Voxey's
#     `VillageContent.MUD` (683) is not confirmed to be that node. Adding it would
#     be a guess; the parent can append it once that is settled.
const SPREAD_TO = [
	Nodes.STONE,Nodes.DIRT,Nodes.SAND,Nodes.GRASS,
	ANDESITE,DIORITE,GRANITE,
	Nodes.END_STONE,Nodes.NETHERRACK,Nodes.BASALT,Nodes.SOUL_SAND,
	SOUL_SOIL,Nodes.WARPED_NYLIUM,Nodes.CRIMSON_NYLIUM,
	Nodes.GRAVEL,Nodes.DEEPSLATE,MinecloniaOres.TUFF,
]

# Source `init.lua:4-13` groups, hardness and drops. `tool` is this project's single
# preferred tool (`Nodes.preferred_tool`): sculk and the catalyst carry `hoey=1` and
# no other tool group, so they are hoe blocks, exactly as `NetherBlocks.
# NETHER_WART_BLOCK` is for the same group. The vein carries `handy=1, axey=1,
# shearsy=1, swordy=1` (`init.lua:222-225`) with **no** dominant kind, so its
# `"tool": -1` records that hand is always allowed and no tool is required, which is
# the same reading `GlassColors` gives `handy=1`.
#
# `blast_resistance`: sculk declares `_mcl_blast_resistance = 0.2` (`init.lua:201`).
# The vein and the catalyst declare none, and `mcl_explosions/init.lua:40-41` falls
# back to `_mcl_hardness`, so their values below are that fallback written out, as
# `NetherBlocks` does.
#
# `"family": "sculk"` groups the four ids. Nothing reads it today: it is not one of
# the families the recipe loops or `Beacons.beam_color` match.
const DATA = {
	SCULK:{"name":"Sculk","block":true,"shape":"cube","color":"123a3c","family":"sculk","hardness":0.6,"blast_resistance":0.2,"tool":4,"drop":0,"note_material":"stone","source_node":"mcl_sculk:sculk"},
	VEIN:{"name":"Sculk vein","block":true,"shape":"plant","color":"2a7d74","family":"sculk","hardness":0.2,"blast_resistance":0.2,"tool":-1,"drop":0,"transparent":true,"plant":true,"climbable":true,"source_node":"mcl_sculk:vein"},
	CATALYST:{"name":"Sculk catalyst","block":true,"shape":"cube","color":"165054","family":"sculk","hardness":3.0,"blast_resistance":3.0,"tool":4,"drop":0,"light":CATALYST_LIGHT,"emits":CATALYST_LIGHT,"note_material":"stone","source_node":"mcl_sculk:catalyst"},
	# Source `init.lua:289-294`: `groups = {craftitem = 1, rarity = 1}` with no
	# `drop`, no hardness and no placement, which is why `"block"` is absent. The
	# `rarity = 1` group is presentation only; `Amethyst.SHARD` is this project's
	# precedent for a shard item that omits `tool`, so this does too.
	ECHO_SHARD:{"name":"Echo shard","color":"a9e6e8","family":"sculk","stack":64,"glint":true,"source_node":"mcl_sculk:echo_shard"},
}

# --- predicates --------------------------------------------------------------

# Source `group:sculk`, which all three registered nodes carry (`init.lua:196`,
# `:224`, `:243`). This is the family predicate, because the source's own
# `has_nonsculk` (`:115-120`) tests that group and the spread rule depends on it.
static func is_sculk(id: int) -> bool: return id == SCULK or id == VEIN or id == CATALYST
# The plain block specifically, for a caller that wants the mass and not the growth.
static func is_sculk_block(id: int) -> bool: return id == SCULK
static func is_vein(id: int) -> bool: return id == VEIN
static func is_catalyst(id: int) -> bool: return id == CATALYST
static func is_echo_shard(id: int) -> bool: return id == ECHO_SHARD

# Source `light_source = 6` on the catalyst, and none on sculk or the vein. Every
# other light-emitting module in this project exposes this accessor for
# `Pasture.emission`, so the catalyst follows that shape rather than being
# special-cased there.
static func light_level(id: int) -> int: return CATALYST_LIGHT if is_catalyst(id) else 0

# Source `climbable = true` on the vein (`init.lua:217`), so a player can hold
# forward against a growth and go up it. Wired the way `LushCaves.climbable` and
# `Scaffolding.climbable` are: `player.gd` asks each module in turn.
static func climbable(world: VoxelWorld, cell: Vector3i) -> bool:
	return is_vein(world.node_at(cell))

# --- drops -------------------------------------------------------------------

# The source tests shears *before* Silk Touch for a node with `_mcl_shears_drop`
# (`ENTITIES/mcl_item_entity/init.lua:175-187`), so a vein yields itself to shears
# and nothing else.
static func shears_drop(id: int) -> bool: return is_vein(id)

# The source's `drop = ""` on all three: an ordinary break yields nothing.
static func drops_nothing(id: int) -> bool: return is_sculk(id)

# What a break of `id` yields, as `Amethyst.harvest` and `Nodes.drop` consumers
# expect: a list of `[id, count]` pairs, empty for nothing. Shears win over Silk
# Touch on the vein, as the engine's own order does.
static func harvest(id: int, slot: Dictionary) -> Array:
	# `slot` is an inventory slot ("id"/"count"/"wear"/"data"), which is what
	# `Inventory.enchantment` and every other `harvest` here take.
	if shears_drop(id): return [[VEIN,1]] if int(slot.get("id",0)) == Nodes.SHEARS else []
	if drops_nothing(id) and Inventory.enchantment(slot,SILK_TOUCH) > 0: return [[id,1]]
	return []

# The single drop id, for a caller that only needs the id. 0 means "nothing", which
# is the convention `Nodes.drop` uses for a seagrass node and an infested block.
static func drop_for(id: int, slot: Dictionary) -> int:
	var entries: Array = harvest(id,slot)
	return int(entries[0][0]) if not entries.is_empty() else 0

# --- per-node experience ------------------------------------------------------

# Source `get_node_xp`/`set_node_xp` (`init.lua:73-80`) use the node's Luanti
# metadata. Voxey has no per-node metadata table, so the value lives in
# `world.block_states`, which is where `Copper` keeps `copper_waxed` and
# `Archaeology` keeps `pot_facing`.
static func node_xp(world: VoxelWorld, p: Vector3i) -> int:
	return int(world.block_states.get(VoxelWorld.station_key(p),{}).get(XP_KEY,0))
static func set_node_xp(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	world.block_states[key][XP_KEY] = value
# Whether this cell carries a stored value at all, i.e. whether it was placed by the
# spread rather than by a player. A player-placed block is the source's
# `place_param2 = 1` case, which always yields exactly 1.
static func has_node_xp(world: VoxelWorld, p: Vector3i) -> bool:
	return world.block_states.get(VoxelWorld.station_key(p),{}).has(XP_KEY)

# Source `sculk_after_dig_node` (`init.lua:82-107`). Experience is a number here
# because Voxey has no experience orbs; the parent adds it to `game.experience`.
# Silk Touch suppresses it only when the tool could harvest the node, which is the
# source's `mcl_autogroup.can_harvest` guard; `Nodes.harvestable` is this project's
# equivalent.
static func harvest_xp(world: VoxelWorld, p: Vector3i, id: int, slot: Dictionary) -> int:
	if not drops_nothing(id): return 0
	var tool: int = int(slot.get("id",0))
	if Inventory.enchantment(slot,SILK_TOUCH) > 0 and Nodes.harvestable(id,tool): return 0
	# `if oldnode.param2 == 1 then xp = 1 end`.
	if not has_node_xp(world,p): return 1
	return node_xp(world,p)

# --- the spread rule ----------------------------------------------------------

# Source `has_air` (`init.lua:109-113`): true when any of the six neighbours is not
# a solid node. `get_item_group(name,"solid") <= 0` is `not Nodes.solid(id)` here.
#
# The source's `core.get_node` on an unloaded cell yields `ignore`, whose solid
# group is 0, so an unloaded neighbour counts as air there. `VoxelWorld.node_at`
# instead reports BEDROCK, which is solid, so an unloaded cell is skipped rather
# than counted. That is the conservative reading — it can only decline a spread the
# source would have made, never place one into terrain this client has not seen.
static func has_air(world: VoxelWorld, p: Vector3i) -> bool:
	for offset in VoxelWorld.SIDES:
		var at: Vector3i = p+offset
		if not world.loaded_at(Vector3(at)): continue
		if not Nodes.solid(world.node_at(at)): return true
	return false

# Source `has_nonsculk` (`init.lua:115-120`): the first adjacent cell that is solid
# but not sculk. Returned as `[]` or `[pos]` so an unset result is never confused
# with a real position.
static func has_nonsculk(world: VoxelWorld, p: Vector3i) -> Array:
	for offset in VoxelWorld.SIDES:
		var at: Vector3i = p+offset
		if not world.loaded_at(Vector3(at)): continue
		var id: int = world.node_at(at)
		if not is_sculk(id) and Nodes.solid(id): return [at]
	return []

# The cells the source's `spread_to` set matches.
static func replaceable_for_spread(id: int) -> bool: return SPREAD_TO.has(id)

# Source `core.find_node_near(p, SPREAD_RANGE, {"mcl_sculk:catalyst"})`
# (`init.lua:136`). `lua_api.md` gives `find_node_near` a **maximum metric**, and
# `search_center` defaults to false so the origin is not tested. Scanning shells of
# growing max-metric radius reproduces both.
static func nearest_catalyst(world: VoxelWorld, origin: Vector3i) -> Array:
	for radius in range(1,SPREAD_RANGE+1):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				for z in range(-radius,radius+1):
					if maxi(absi(x),maxi(absi(y),absi(z))) != radius: continue
					var at: Vector3i = origin+Vector3i(x,y,z)
					if world.node_at(at) == CATALYST: return [at]
	return []

# Source `retrieve_close_spreadable_nodes` (`init.lua:121-133`): every match of the
# replaceable set that has air beside it, nearest-first. The source sorts on
# `vector.distance`; comparing squared distances gives the same order without a
# square root per comparison.
static func spreadable_near(world: VoxelWorld, origin: Vector3i) -> Array:
	var found: Array = []
	for x in range(-SPREAD_RANGE,SPREAD_RANGE+1):
		for y in range(-SPREAD_RANGE,SPREAD_RANGE+1):
			for z in range(-SPREAD_RANGE,SPREAD_RANGE+1):
				var at: Vector3i = origin+Vector3i(x,y,z)
				if not world.loaded_at(Vector3(at)): continue
				if not replaceable_for_spread(world.node_at(at)): continue
				if not has_air(world,at): continue
				found.append(at)
	var target := Vector3(origin)
	found.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector3(a).distance_squared_to(target) < Vector3(b).distance_squared_to(target))
	return found

# Where the source puts a vein after a cell became sculk (`init.lua:162-167`): find
# a solid non-sculk neighbour, and if it has air beside it, mount the vein in the
# cell **above** that neighbour at `param2 = 1`. Returns `[]` or `[pos]`.
static func vein_target(world: VoxelWorld, p: Vector3i) -> Array:
	var neighbour: Array = has_nonsculk(world,p)
	if neighbour.is_empty(): return []
	var at: Vector3i = neighbour[0]
	if not has_air(world,at): return []
	return [at+Vector3i.UP]

# Source `spread_sculk` (`init.lua:135-173`), without the shrieker/sensor branch,
# which the checkout has commented out. `origin` is the position the spread is
# anchored at — for the live caller it is the **death position**, from which a
# nearby catalyst is searched; the source does not pass the catalyst's own position.
# `xp_amount` is the source's second argument.
#
# Returns the positions that became sculk, which is empty when the rule did not
# fire, so a caller can tell whether anything happened without reading the world
# back.
static func spread(world: VoxelWorld, origin: Vector3i, rng: RandomNumberGenerator, xp_amount: int = DEATH_XP) -> Array:
	if nearest_catalyst(world,origin).is_empty(): return []
	if xp_amount <= 0: return []
	var candidates: Array = spreadable_near(world,origin)
	if candidates.is_empty(): return []
	# `local r = math.min(math.random(#nn), xp_amount)`.
	var count: int = mini(rng.randi_range(1,candidates.size()),xp_amount)
	var converted: Array = []
	for i in count:
		var at: Vector3i = candidates[i]
		if not world.set_node(at,SCULK): continue
		set_node_xp(world,at,xp_amount/count)
		converted.append(at)
	if converted.is_empty(): return []
	for at in converted:
		var vein: Array = vein_target(world,at)
		# Source sets the vein unconditionally at the target cell; `set_node`
		# refuses an unloaded or out-of-range cell, which is the guard the source
		# has no need for.
		if not vein.is_empty(): world.set_node(vein[0],VEIN)
	# `set_node_xp(nn[1], get_node_xp(nn[1]) + xp_amount % r)`.
	var first: Vector3i = converted[0]
	set_node_xp(world,first,node_xp(world,first)+xp_amount%count)
	return converted

# Source `mcl_sculk.handle_death` (`init.lua:175-178`), which is what the
# `register_on_dieplayer` hook calls with five points.
static func handle_death(world: VoxelWorld, pos: Vector3i, rng: RandomNumberGenerator, xp_amount: int = DEATH_XP) -> Array:
	return spread(world,pos,rng,xp_amount)

# A world-seeded generator, which is the contract this module documents for its
# callers: the spread is deterministic per world rather than per process.
static func death_rng(world: VoxelWorld) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value+9109
	return rng

# --- recipes -----------------------------------------------------------------

# The source has **no crafting recipes for any of these four ids**: `init.lua` ends
# with a single `register_craftitem` (`:289`) and contains no `register_craft` call
# at all, and `lg_register.lua` only registers mapgen features. Rather than invent
# one, this is where the echo shard's real acquisition would go — see the header.
# The signature is kept so the parent's recipe pass has a stable seam.
static func recipes(_inv: Inventory) -> void:
	pass

# The echo shard is an item, so it also needs a sprite for inventory icons, held
# items and pickups: `ItemArt.texture` asks `VillageItemArt.draw` when the id is in
# `VillageContent.DATA`, and nothing matches the id there, so without this the
# shard would fall through to the generic blob. Same original drawing as `pixel`
# above.
static func draw(img: Image) -> void:
	ItemArt._polygon(img,[[3,12],[8,2],[12,1],[14,5],[8,14],[5,15]],Color("4f8f94"))
	ItemArt._polygon(img,[[4,11],[9,3],[12,2],[11,8],[7,13]],Color("a9e6e8"))
	ItemArt._polygon(img,[[9,3],[12,2],[13,5],[11,8]],Color("e6fbfc"))
	ItemArt._line(img,Vector2(5,10),Vector2(9,4),Color("cdf3f5"))

# --- art ---------------------------------------------------------------------

# The source tiles are animated sculk (a dark teal mass with lighter cyan speckles),
# a signlike vein and a top/bottom/side catalyst set. These are original drawings of
# the same ideas, not copies. Block faces go through the terrain shader, whose alpha
# scissor is 0.5, so the vein must return alpha 0 outside its tendrils to leave the
# cell open, exactly as `LushCaves`' vine does.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if is_vein(id):
		# Two vertical tendrils joined by a couple of horizontal runs, so the
		# growth reads as branching rather than as a full tile.
		var tendril: bool = (x in [4,5] and y > 2) or (x in [10,11] and y > 5) or (y in [5,6] and x > 4 and x < 12) or (y in [11,12] and x > 5 and x < 11)
		if not tendril: return Color(0,0,0,0)
		return base.lightened(0.14) if posmod(x+y,5) == 0 else base
	if is_echo_shard(id):
		# A small pale-cyan crystal, drawn in the tile too so a pixel route works.
		# 11510 is not in BLOCKS, so no atlas tile is generated for it.
		var radius: float = Vector2(x-7.5,y-7.5).length()
		if radius > 6.4: return Color(0,0,0,0)
		if posmod(x+y*3,7) == 0: return base.lightened(0.34)
		return base.darkened(0.22) if radius > 4.2 else base
	# Sculk and catalyst share the mass. The catalyst carries a brighter cyan core,
	# which is what its `light_source = 6` looks like; sculk only speckles.
	var speckle: bool = posmod(x*7+y*13+x*y*3,29) < 3
	var c: Color = base.lightened(0.32) if speckle else base
	if is_catalyst(id) and Vector2(x-7.5,y-7.5).length() < 4.6:
		c = Color("7fe6de") if posmod(x+y*2,7) < 4 else base.lightened(0.46)
	# The faint glow: a light wash near the tile's centre on both masses.
	if Vector2(x-7.5,y-7.5).length() < 2.6 and posmod(x*3-y,11) < 2: c = c.lightened(0.18)
	return noise.lerp(c,0.74)
