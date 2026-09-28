extends RefCounted

# Redstone ore's lit state (Mineclonia `mcl_core/nodes_base.lua`:71-149 and
# `mcl_deepslate/deepslate.lua`:57-68). Voxey's redstone ore could be mined but
# never glowed; this suite pins the two-node machine: both ores map to their own
# lit form, a punch or a walk-over lights the ore and starts the source's
# 68.28-second window, a second touch restarts that window, and the window's
# expiry writes the unlit ore back.

# The lit nodes' own source values, asserted against the registry the parent
# appends: `light_source = 9` (nodes_base.lua:122) and
# `not_in_creative_inventory = 1` (nodes_base.lua:123), which Voxey spells
# `hidden`, plus `_mcl_hardness = 3` (nodes_base.lua:140) and the pickaxe.
static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var cells: Array = [RedstoneOre.LIT,RedstoneOre.DEEP_LIT]

	# --- the registry rows ----------------------------------------------------
	# The parent appends each entry from `RedstoneOre.DATA` verbatim, so the row
	# the registry holds is the module's own: `light_source = 9`
	# (nodes_base.lua:122) and `not_in_creative_inventory = 1`
	# (nodes_base.lua:123), which Voxey spells `hidden`.
	var rows: bool = true
	for id in cells:
		var row: Dictionary = VillageContent.DATA.get(id,{})
		if not Nodes.exists(id) or not bool(row.get("hidden",false)): rows = false
		if int(row.get("light",0)) != RedstoneOre.LIGHT: rows = false
		if row.get("tool",-1) != 0: rows = false
	suite.check(rows,"both lit ores are registered, hidden rows carrying the source's light 9 and pickaxe tool")
	# A lit ore is a glowing cube, not a light-hole: solid, opaque, not a plant, and
	# at the source's `_mcl_hardness = 3` (nodes_base.lua:140).
	var physical: bool = true
	for id in cells:
		if not Nodes.solid(id) or Nodes.transparent(id) or Nodes.plant(id): physical = false
		if Nodes.hardness(id) != RedstoneOre.HARDNESS or Nodes.preferred_tool(id) != 0: physical = false
	suite.check(physical,"a lit ore is a solid, opaque pickaxe-mined block at the source's hardness")
	# The parent's edit sites, asserted through public API: the lit ore's item
	# paths resolve to the unlit ore, its xp is the source's 7, and its
	# `light_source = 9` reaches Voxey's light propagation as block light.
	suite.check(Nodes.drop(RedstoneOre.LIT) == Nodes.REDSTONE_WIRE and
		Nodes.drop(RedstoneOre.DEEP_LIT) == Nodes.REDSTONE_WIRE and
		Nodes.pick_item(RedstoneOre.LIT) == Nodes.REDSTONE_ORE and
		Nodes.pick_item(RedstoneOre.DEEP_LIT) == Nodes.DEEP_REDSTONE_ORE and
		Nodes.ore_xp(RedstoneOre.LIT) == 7 and Nodes.ore_xp(RedstoneOre.DEEP_LIT) == 7 and
		Nodes.harvestable(RedstoneOre.LIT,90) and not Nodes.harvestable(RedstoneOre.LIT,85),
		"a lit ore breaks into redstone, picks as the ore it was and pays the source's 7 xp")

	# --- the mapping ----------------------------------------------------------
	suite.check(RedstoneOre.lit_for(Nodes.REDSTONE_ORE) == RedstoneOre.LIT and
		RedstoneOre.lit_for(Nodes.DEEP_REDSTONE_ORE) == RedstoneOre.DEEP_LIT,
		"each unlit ore maps to its own lit form")
	suite.check(RedstoneOre.unlit_for(RedstoneOre.LIT) == Nodes.REDSTONE_ORE and
		RedstoneOre.unlit_for(RedstoneOre.DEEP_LIT) == Nodes.DEEP_REDSTONE_ORE,
		"each lit form reverts to its own unlit ore, which is the source's _mcl_ore_unlit")
	# Only the four ore ids answer; a lit node is not an ore that lights again, and
	# nothing else in the catalogue is touched.
	var only_ores: bool = true
	for id in [Nodes.REDSTONE_ORE,Nodes.DEEP_REDSTONE_ORE,RedstoneOre.LIT,RedstoneOre.DEEP_LIT]:
		if not RedstoneOre.is_ore(id): only_ores = false
	for id in [Nodes.STONE,Nodes.DEEPSLATE,Nodes.COAL_ORE,Nodes.DIAMOND_ORE,Nodes.LAPIS_ORE,Nodes.AIR,Nodes.REDSTONE_WIRE,0]:
		if RedstoneOre.is_ore(id) or RedstoneOre.lit_for(id) != 0 or RedstoneOre.unlit_for(id) != 0: only_ores = false
	suite.check(only_ores,"only the two ores and their two lit forms are redstone ore")
	suite.check(not RedstoneOre.is_lit(Nodes.REDSTONE_ORE) and not RedstoneOre.is_lit(Nodes.DEEP_REDSTONE_ORE) and
		RedstoneOre.is_lit(RedstoneOre.LIT) and RedstoneOre.is_lit(RedstoneOre.DEEP_LIT),
		"litness is exactly the two new ids")
	# The lit form is the same item as the ore it came from: the source's lit node
	# is `not_in_creative_inventory` and drops the plain ore.
	suite.check(RedstoneOre.item(RedstoneOre.LIT) == Nodes.REDSTONE_ORE and
		RedstoneOre.item(RedstoneOre.DEEP_LIT) == Nodes.DEEP_REDSTONE_ORE and
		RedstoneOre.item(Nodes.REDSTONE_ORE) == 0,
		"a lit ore resolves to the unlit ore it drops")
	# Source `groups.xp = 7` on both forms (nodes_base.lua:86 and 123).
	suite.check(RedstoneOre.xp(Nodes.REDSTONE_ORE) == 7 and RedstoneOre.xp(Nodes.DEEP_REDSTONE_ORE) == 7 and
		RedstoneOre.xp(RedstoneOre.LIT) == 7 and RedstoneOre.xp(RedstoneOre.DEEP_LIT) == 7 and
		RedstoneOre.xp(Nodes.COAL_ORE) == 0,
		"the source's groups.xp of 7 applies to both forms and only to redstone ore")

	# A lit ore's light must actually reach its surroundings through Voxey's
	# propagation, which is the parent's `Pasture.emission` line.
	var lamp := Vector3i(24,180,24)
	var light_saved: Dictionary = {}
	var light_saved_edits: Dictionary = {}
	for cell in [lamp,lamp+Vector3i.RIGHT]:
		light_saved[cell] = world.node_at(cell)
		if world.edits.has(cell): light_saved_edits[cell] = world.edits[cell]
	world.set_node(lamp+Vector3i.RIGHT,Nodes.AIR)
	world.set_node(lamp,RedstoneOre.LIT)
	suite.check(Pasture.emission(world,lamp) == 9 and Pasture.block_light(world,lamp+Vector3i.RIGHT) == 8,
		"a lit ore emits the source's light 9 into its neighbours")
	world.set_node(lamp,Nodes.REDSTONE_ORE)
	suite.check(Pasture.emission(world,lamp) == 0,"an unlit ore emits nothing")
	for cell in [lamp,lamp+Vector3i.RIGHT]:
		world.set_node(cell,int(light_saved.get(cell,Nodes.AIR)))
		if light_saved_edits.has(cell): world.edits[cell] = light_saved_edits[cell]
		else: world.edits.erase(cell)

	# --- the state machine ----------------------------------------------------
	var p := Vector3i(10,170,10)
	var floor_cell: Vector3i = p+Vector3i.DOWN
	var previous: Dictionary = {}
	var previous_edits: Dictionary = {}
	for cell in [p,floor_cell]:
		previous[cell] = world.node_at(cell)
		if world.edits.has(cell): previous_edits[cell] = world.edits[cell]
	var saved_meta: bool = world.has_meta("redstone_ore")
	var saved_cells: Dictionary = world.get_meta("redstone_ore",{}).duplicate(true) if saved_meta else {}
	RedstoneOre.reset(world)
	world.set_node(floor_cell,Nodes.STONE)

	world.set_node(p,Nodes.REDSTONE_ORE)
	suite.check(world.node_at(p) == Nodes.REDSTONE_ORE and RedstoneOre.is_ore(world.node_at(p)),
		"the test cell holds redstone ore")
	suite.check(not RedstoneOre.tracked(world,p),"an untouched ore carries no revert clock")
	# A punch on a non-ore must not start a window for whatever the player hit.
	suite.check(not RedstoneOre.activate(world,floor_cell) and not RedstoneOre.tracked(world,floor_cell),
		"touching a block that is not redstone ore does nothing")

	suite.check(RedstoneOre.activate(world,p) and world.node_at(p) == RedstoneOre.LIT and RedstoneOre.tracked(world,p),
		"touching an unlit ore swaps in the lit node and starts its clock")
	# The deepslate pair is the same machine on the deepslate ore.
	world.set_node(p+Vector3i.RIGHT,Nodes.DEEP_REDSTONE_ORE)
	suite.check(RedstoneOre.activate(world,p+Vector3i.RIGHT) and world.node_at(p+Vector3i.RIGHT) == RedstoneOre.DEEP_LIT,
		"touching deepslate redstone ore swaps in its own lit form")

	# The window is the source's 68.28 seconds: at 68.0 elapsed it is still lit, and
	# a further 0.3 crosses it.
	RedstoneOre.update(world,68.0)
	suite.check(world.node_at(p) == RedstoneOre.LIT and RedstoneOre.tracked(world,p),
		"the source's 68.28s window has not expired at 68.0s")
	RedstoneOre.update(world,0.3)
	suite.check(world.node_at(p) == Nodes.REDSTONE_ORE and not RedstoneOre.tracked(world,p),
		"the lit ore reverts to the unlit ore once 68.28s have passed")
	suite.check(world.node_at(p+Vector3i.RIGHT) == Nodes.DEEP_REDSTONE_ORE,
		"the deepslate lit ore reverts to deepslate redstone ore")

	# A second touch *restarts* the window rather than extending it: light the ore,
	# advance 60s, touch it again, and 68.5s from the first touch it is still lit.
	RedstoneOre.activate(world,p)
	RedstoneOre.update(world,60.0)
	suite.check(world.node_at(p) == RedstoneOre.LIT,"60s into the window the ore is still lit")
	suite.check(RedstoneOre.activate(world,p),"a second touch on a lit ore restarts its window")
	RedstoneOre.update(world,8.5)
	suite.check(world.node_at(p) == RedstoneOre.LIT and RedstoneOre.tracked(world,p),
		"68.5s after the first touch the restarted window still holds the ore lit")
	# The restart is a *reset*, not an addition: 68.0s after the second touch the
	# window closes at 68.28s from that touch, not at 128.28s from the first.
	RedstoneOre.update(world,59.5)
	suite.check(world.node_at(p) == RedstoneOre.LIT,"the restarted window is measured from the last touch")
	RedstoneOre.update(world,0.3)
	suite.check(world.node_at(p) == Nodes.REDSTONE_ORE,"the restarted window expires 68.28s after the restart")

	# A lit cell that arrives with a column is re-armed rather than left without a
	# clock, which is the reload rule in the module header.
	RedstoneOre.reset(world)
	world.set_node(p,RedstoneOre.LIT)
	suite.check(not RedstoneOre.tracked(world,p),"a lit node placed directly carries no clock until it is indexed")
	RedstoneOre.registered(world,p,RedstoneOre.LIT)
	suite.check(RedstoneOre.tracked(world,p),"indexing a loaded lit cell arms its clock")
	# Indexing is idempotent and only for the lit form: re-indexing an unlit ore
	# must not track it.
	RedstoneOre.registered(world,p,RedstoneOre.LIT)
	RedstoneOre.registered(world,p,Nodes.REDSTONE_ORE)
	suite.check(RedstoneOre.tracked(world,p) and not RedstoneOre.tracked(world,floor_cell),
		"re-indexing a lit cell is harmless and an unlit ore is never indexed")
	RedstoneOre.update(world,68.5)
	suite.check(world.node_at(p) == Nodes.REDSTONE_ORE,"an indexed lit cell reverts on the same window")

	# Mining the ore before its window runs out leaves nothing to revert, and the
	# cell must not be reverted into a different block later.
	RedstoneOre.activate(world,p)
	world.set_node(p,Nodes.AIR)
	RedstoneOre.update(world,68.5)
	suite.check(world.node_at(p) == Nodes.AIR and not RedstoneOre.tracked(world,p),
		"an ore mined before its window expires is not reverted into stone")

	# A column that leaves memory drops its clocks, so no clock outlives its column.
	world.set_node(p,Nodes.REDSTONE_ORE)
	RedstoneOre.activate(world,p)
	var column := Vector2i(floori(float(p.x)/16.0),floori(float(p.z)/16.0))
	RedstoneOre.unload(world,column)
	suite.check(not RedstoneOre.tracked(world,p),"a column unload drops its revert clocks")

	# --- restore --------------------------------------------------------------
	for cell in [p,p+Vector3i.RIGHT,floor_cell]:
		world.set_node(cell,int(previous.get(cell,Nodes.AIR)))
		if previous_edits.has(cell): world.edits[cell] = previous_edits[cell]
		else: world.edits.erase(cell)
	if saved_meta: world.set_meta("redstone_ore",saved_cells)
	else: RedstoneOre.reset(world)
	suite.check(not RedstoneOre.tracked(world,p),"the suite leaves no revert clock behind")
