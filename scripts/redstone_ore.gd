class_name RedstoneOre
extends RefCounted

# Mineclonia ITEMS/mcl_core/nodes_base.lua:71-149 and
# ITEMS/mcl_deepslate/deepslate.lua:57-68, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; art is original procedural code.
#
# Redstone ore glows when it is touched. The source builds that out of a two-node
# state machine on one 68.28-second node timer:
#
#   * `local redstone_timer = 68.28` (nodes_base.lua:71).
#   * The **unlit** node (nodes_base.lua:82-107) carries `on_punch` *and*
#     `_on_object_over`, both `redstone_ore_activate` (nodes_base.lua:72-80):
#     the *current* node's `_mcl_ore_lit` is written into the cell, then
#     `t:start(redstone_timer)` arms a fresh window.
#   * The **lit** node (nodes_base.lua:117-149) is the same ore with
#     `light_source = 9` and `not_in_creative_inventory = 1`, and both of its
#     hooks are `redstone_ore_reactivate` (nodes_base.lua:109-115), which only
#     restarts the timer. The window therefore follows the *last* touch, so
#     standing on lit ore keeps it lit.
#   * `on_timer` (nodes_base.lua:136-139) writes back the *current* node's
#     `_mcl_ore_unlit`, so an ore nobody touches reverts to plain ore.
#   * The deepslate pair is the same machine on the deepslate variants
#     (deepslate.lua:57-68); its lit node also names the unlit deepslate ore as
#     its Silk Touch drop.
#
# `activate` is both source hooks: it lights an unlit ore and restarts a lit one,
# because either hook runs on every punch and every walk-over. There is no
# punch-forward here — the source's `core.node_punch` re-entry exists so the lit
# node's own `on_punch` fires after the swap, while in Voxey the punch is already
# the caller.
#
# Two source facts are deliberately not duplicated in this module:
#
#   * **Drops.** The lit node's drop table is identical to the unlit one's
#     (nodes_base.lua:87-93 and 124-130: four or five redstone, `max_items = 1`),
#     so the lit form is not a separate item. `item()` names the unlit ore the
#     parent resolves `Nodes.drop` and `Nodes.pick_item` through, which is also
#     what the source's `_mcl_silk_touch_drop` yields (nodes_base.lua:141).
#   * **Experience.** Both forms carry `groups.xp = 7` (nodes_base.lua:86 and
#     123). `xp()` is the single accessor for that value; the parent routes
#     `Nodes.ore_xp` through it, so a broken ore pays 7 exactly once from
#     whichever form it was in, and no second payout is added here.
#
# The revert clock is runtime state on the world node, like `Concrete`'s powder
# sweep and `Amethyst`'s growth jobs. Luanti keeps every node timer in the world
# database, so a timer there survives its block leaving memory; this port cannot
# do that, and instead drops a column's clocks when the column unloads (`unload`)
# and re-arms a full window when the lit cell comes back (`registered`). The lit
# node itself *is* saved, because it is an ordinary `world.edits` entry, so a
# reloaded world shows a lit ore that reverts one window after it is revisited
# rather than mid-count.

# One lit node per existing ore, in the order of `Nodes.REDSTONE_ORE` and
# `Nodes.DEEP_REDSTONE_ORE`.
const LIT = 11590
const DEEP_LIT = 11591

# Source `local redstone_timer = 68.28` (nodes_base.lua:71): the window a touched
# ore stays lit, restarted by every later touch.
const TIMER = 68.28
# Source `light_source = 9` (nodes_base.lua:122).
const LIGHT = 9
# Source `_mcl_hardness = 3` (nodes_base.lua:140, and inherited by the deepslate
# variants through `table.copy`).
const HARDNESS = 3.0
# Source `groups = {pickaxey = 4, ..., xp = 7, ...}` (nodes_base.lua:123).
const XP = 7

# Constant keys, so the content table can reference this without a const cycle.
const DATA = {
	11590: {"name":"Lit redstone ore","block":true,"shape":"cube","color":"8a5a5c","hardness":HARDNESS,
		"tool":0,"light":LIGHT,"emits":LIGHT,"hidden":true},
	11591: {"name":"Lit deepslate redstone ore","block":true,"shape":"cube","color":"6a4650","hardness":HARDNESS,
		"tool":0,"light":LIGHT,"emits":LIGHT,"hidden":true},
}

# --- the family ---------------------------------------------------------------

# Any redstone ore, lit or unlit.
static func is_ore(id: int) -> bool:
	return id == Nodes.REDSTONE_ORE or id == Nodes.DEEP_REDSTONE_ORE or id == LIT or id == DEEP_LIT

static func is_lit(id: int) -> bool: return id == LIT or id == DEEP_LIT

# The lit form of an unlit ore, or 0 when the node is not an unlit ore.
static func lit_for(id: int) -> int:
	if id == Nodes.REDSTONE_ORE: return LIT
	return DEEP_LIT if id == Nodes.DEEP_REDSTONE_ORE else 0

# The unlit ore a lit node reverts to, or 0 when the node is not lit. This is the
# source's `_mcl_ore_unlit` (nodes_base.lua:148, deepslate.lua:59 and 65).
static func unlit_for(id: int) -> int:
	if id == LIT: return Nodes.REDSTONE_ORE
	return Nodes.DEEP_REDSTONE_ORE if id == DEEP_LIT else 0

# The block a lit ore's item form resolves to, which is the unlit ore: the lit
# node is `not_in_creative_inventory` and its Silk Touch drop is the plain ore
# (nodes_base.lua:141, deepslate.lua:66). 0 for anything else.
static func item(id: int) -> int: return unlit_for(id)

# The source's `light_source`, for the parent's light propagation.
static func light_level(id: int) -> int: return LIGHT if is_lit(id) else 0

# The source's `groups.xp` value, which both forms carry.
static func xp(id: int) -> int: return XP if is_ore(id) else 0

# --- the revert clock ---------------------------------------------------------

static func _state(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("redstone_ore"): world.set_meta("redstone_ore",{})
	return world.get_meta("redstone_ore")

# Whether the cell is a lit ore carrying a running revert clock.
static func tracked(world: VoxelWorld, p: Vector3i) -> bool:
	return _state(world).has(p)

# Light the ore at `p`, or restart the clock of one already lit. Returns whether
# the cell held a redstone ore at all, so a caller can tell "touched ore" from
# "touched anything else". Both source hooks route here: `redstone_ore_activate`
# swaps the unlit node and starts the timer, `redstone_ore_reactivate` restarts
# it, and because either runs on every punch and every walk-over, the window
# follows the last touch.
static func activate(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	var lit: int = lit_for(id)
	if lit == 0 and not is_lit(id): return false
	# `core.set_node(pos, {name = nodedef._mcl_ore_lit})` only changes the node for
	# the unlit form; a lit ore keeps its node and only re-arms.
	if lit != 0 and not world.set_node(p,lit): return false
	var cells: Dictionary = _state(world)
	cells[p] = TIMER
	world.set_meta("redstone_ore",cells)
	return true

# Index a lit cell found while a column arrives, which is where the parent calls
# this. Luanti's node timer keeps counting while its block is out of memory; a
# reloaded lit ore here is armed with a *fresh* full window instead (see the
# header), so it can never be left lit forever by a lost clock.
static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_lit(id) or not world.loaded_at(Vector3(p)): return
	var cells: Dictionary = _state(world)
	cells[p] = TIMER
	world.set_meta("redstone_ore",cells)

# Advance every running clock and revert the cells whose window ran out. The
# tracked set is only ever the lit ores a player recently touched, so it stays
# tiny; a cell in a column that left memory is dropped rather than advanced,
# which is the unload rule `unload` applies up front.
static func update(world: VoxelWorld, delta: float) -> void:
	var cells: Dictionary = _state(world)
	if cells.is_empty(): return
	var step: float = maxf(0.0,delta) if is_finite(delta) else 0.0
	var expired: Array = []
	for key in cells.keys():
		var p: Vector3i = key
		if not world.loaded_at(Vector3(p)):
			expired.append(p); continue
		# An ore mined before its window ran out leaves nothing to revert, so the
		# cell simply stops being tracked.
		if not is_lit(world.node_at(p)):
			expired.append(p); continue
		var remaining: float = float(cells[p])-step
		if remaining <= 0.0: expired.append(p)
		else: cells[p] = remaining
	for key in expired:
		var p: Vector3i = key
		var unlit: int = unlit_for(world.node_at(p))
		cells.erase(p)
		# Source `on_timer`: the lit node reverts to its own `_mcl_ore_unlit`. An
		# unloaded cell has no readable node and nothing to write back.
		if unlit != 0: world.set_node(p,unlit)
	world.set_meta("redstone_ore",cells)

# Drop the clocks of a column that left memory, so a dropped clock can never
# outlive the column it belongs to.
static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var cells: Dictionary = _state(world)
	for key in cells.keys():
		var p: Vector3i = key
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: cells.erase(p)
	world.set_meta("redstone_ore",cells)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("redstone_ore"): world.set_meta("redstone_ore",{})

# --- art ---------------------------------------------------------------------

# The source draws both states with the *same* texture
# (`mcl_core_redstone_ore.png`, nodes_base.lua:85 and 120) and the glow comes
# from `light_source` alone, so this tile keeps the unlit ore's rock and flecks
# (`scripts/art.gd` tiles 104 and 105, the two expansion tiles for these ores) and
# only lifts the flecks to a lit red.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_lit(id): return Color(0,0,0,0)
	var rock: Color = Color("654853") if id == DEEP_LIT else Color("857274")
	var fleck: Color = Color("ee5a52") if id == DEEP_LIT else Color("f0625a")
	if posmod(x/2*7+y/2*11,13) < 4:
		return fleck.lerp(Color("ffd0a6"),0.28*float((x+y)%3))
	return rock.darkened(0.05*float((x*3+y*5)%3))

# --- PARENT WIRING -----------------------------------------------------------
# Every line below belongs to a file this module must not edit. The module is
# complete without them except for the registry append, which is what makes the
# two ids exist at all; there is no recipe and no item-metadata allow-list entry
# (both source nodes are plain blocks, and the clock is transient world state
# rather than saved item data).
#
# 1. scripts/village_content.gd — the registry append. Two DATA rows and two
#    BLOCKS entries:
#
#        11590:RedstoneOre.DATA[11590],
#        11591:RedstoneOre.DATA[11591],
#
#    and, in `BLOCKS`, `11590,11591,`.
#
# 2. scripts/nodes.gd — the ore's drop and pick paths, its tool rule and its xp.
#    The lit node's drop table is the unlit one's (four or five redstone), so both
#    resolve through `item()`:
#
#      a. `drop(id)`, immediately before the existing
#         `if id in [REDSTONE_ORE,DEEP_REDSTONE_ORE]: return REDSTONE_WIRE`:
#             if RedstoneOre.is_lit(id): return drop(RedstoneOre.item(id))
#         (Not a DATA `drop` key: that key means "breaks into nothing / a repaired
#         form", while a lit ore breaks into exactly what the unlit one does.)
#      b. `pick_item(id)`, beside the other canonical-item rules:
#             if RedstoneOre.is_lit(id): return RedstoneOre.item(id)
#      c. `harvestable(id,tool)`, the existing line whose text is
#         `if id in [REDSTONE_ORE,DEEP_REDSTONE_ORE]: return tool_kind(tool) == 0
#         and tool_tier(tool) >= 2` — add `RedstoneOre.LIT,RedstoneOre.DEEP_LIT`
#         to the array, so the lit form still needs an iron pickaxe
#         (`pickaxey = 4`).
#      d. `ore_xp(id)`, replacing
#         `if id == REDSTONE_ORE or id == DEEP_REDSTONE_ORE: return 7` with a
#         call to the single accessor:
#             if RedstoneOre.xp(id) > 0: return RedstoneOre.xp(id)
#         `xp()` answers 7 for both lit forms and both unlit ores, so the payout is
#         unchanged for the existing ores and the lit ones already pay correctly.
#      e. **No `falls` line is needed.** Neither source node carries the
#         `falling_node` group — only sand, gravel, snow, suspicious blocks,
#         concrete powder and the anvil do — and `Nodes.falls` lists exactly those.
#      f. **No `smelt_result` line is needed.** The source's lit node carries no
#         cooking output of its own (`deepslate.lua:67` explicitly clears it), and
#         Voxey does not smelt the existing redstone ores either; if a later change
#         adds that, it must include the lit ids, which resolve through `item()`.
#      g. **No blast-resistance line is needed.** Neither source def sets
#         `_mcl_blast_resistance`, and the existing unlit ores keep the default in
#         the explosion path today.
#
# 3. scripts/pasture.gd — `emission(world,p)`, beside
#    `if LushCaves.is_lit_vine(id): return LushCaves.LIT_LIGHT`:
#
#        if RedstoneOre.light_level(id) > 0: return RedstoneOre.light_level(id)
#
#    That is the source's `light_source = 9` reaching Voxey's light propagation.
#    `Pasture.TRACKED` needs no entry: a cell whose `emission` is positive is
#    indexed when its column is tracked, and the lit ore is never a switched-off
#    light. No shader change is needed either — the terrain shader's hardcoded
#    emissive tiles are its full-brightness set, and a 9 is meant to read as
#    dimmer than those.
#
# 4. scripts/voxel_world.gd — four sites:
#
#      a. `configure`, beside `Concrete.reset(self)`:
#             RedstoneOre.reset(self)
#      b. `_process`, inside the `if active:` block, beside
#         `Concrete.update(self,delta)`:
#             RedstoneOre.update(self,delta)
#      c. `_unload(c)`, beside `Concrete.unload(self,c)`:
#             RedstoneOre.unload(self,c)
#      d. `_apply_column`, in the trailing `for p in edits:` re-index loop,
#         immediately after `var id: int = node_at(p)`:
#             if RedstoneOre.is_lit(id): RedstoneOre.registered(self,p,id)
#         That loop is the one that reconciles saved edits, and a lit ore is a
#         normal edit, so this is where a reloaded lit cell is re-armed. The
#         worker-side `special` list needs no entry: the lit form is never
#         generated, only touched.
#
# 5. scripts/game.gd — `break_node`, the existing redstone branch whose text is
#    `elif id in [Nodes.REDSTONE_ORE,Nodes.DEEP_REDSTONE_ORE]:` (it spawns
#    `randi_range(4,5)` redstone and throws `Nodes.ore_xp`). Add the two lit ids to
#    that array:
#
#        elif id in [Nodes.REDSTONE_ORE,Nodes.DEEP_REDSTONE_ORE,RedstoneOre.LIT,RedstoneOre.DEEP_LIT]:
#
#    This is the "do not double-pay" half of the xp port: the branch pays once per
#    break, and the `if ... Nodes.ore_xp(id) > 0` line further down pays the same 7
#    for Silk Touch-free breaks, exactly as it already does for the unlit ores.
#
# 6. scripts/player.gd — the two source hooks.
#
#      a. **Punch** — `mine(delta)`, inside the
#         `if target.pos != mining_pos or held != mining_tool:` block, immediately
#         after the existing `NoteBlocks.punch(game,target)`:
#
#             # Source `on_punch = redstone_ore_activate`: the first hit lights the
#             # ore, and a hit on the lit form restarts its 68.28s window.
#             RedstoneOre.activate(game.world,target.pos)
#
#      b. **Walk-over** — `_physics_process`, beside the existing
#         `Magma.step(game)` call, using the same stand cell that `Magma.step`
#         reads (`position - UP*0.1`), which is the source's
#         `mcl_player.node_offsets.stand`:
#
#             # Source `_on_object_over` (`mcl_walkover/init.lua`): the node the
#             # player stands on is tested every globalstep, so walking over ore
#             # lights it and standing on lit ore keeps its window restarted.
#             RedstoneOre.activate(game.world,Vector3i((position-Vector3(0,0.1,0)).floor()))
#
#         The source runs this from `mcl_player.register_globalstep`, i.e. once per
#         step, which is what `_physics_process` is — not from the 0.5s slow tick
#         the neighbouring contact effects share.
#
# 7. scripts/enchantments.gd — `harvest`, the `ores` array (its text begins
#    `var ores: Array = [MinecloniaOres.NETHER_GOLD,...]`), which drives both Silk
#    Touch and Fortune. Add `RedstoneOre.LIT,RedstoneOre.DEEP_LIT`, since the
#    source's lit node carries `_mcl_silk_touch_drop` and `_mcl_fortune_drop`
#    exactly as the unlit one does.
#
# Optional faithfulness line, if you want it: `scripts/note_blocks.gd`, whose
# `STONE` list holds `Nodes.REDSTONE_ORE` because the source gives redstone ore
# `material_stone = 1`. The lit node carries the same group
# (nodes_base.lua:123), so `if id in [RedstoneOre.LIT,RedstoneOre.DEEP_LIT]: return
# "stone"` keeps a lit ore sounding like the stone it is.
