extends RefCounted

# Ore scatter rules and their two limits in Voxey's world: the biome names the
# generator cannot produce, and the bands that lie above its height ceiling. Both
# were silent before this batch — an unreachable string comparison reads like a
# working filter, and a truncated band looks like a smaller deposit.

static func xp_from_break(suite: Object, game: Node3D, id: int) -> int:
	# Break a real ore in a loaded cell and report what the payout threw. The world
	# is paused between checks, so the whole reward is still on the ground as orbs.
	var p := Vector3i(8,2000,8)
	for x in range(6,11):
		for z in range(6,11):
			for y in range(1998,2003): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(p,Nodes.STONE)
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.world.set_node(p,id)
	XpOrbs.clear(game)
	game.gamemode = "survival"
	game.inventory.restore([])
	game.inventory.slots[0] = {"id":Nodes.TOOLS+15,"count":1,"wear":0}
	game.inventory.selected = 0
	game.break_node(p,id,Nodes.TOOLS+15)
	var total: int = 0
	for orb in XpOrbs.orbs(game): total += int(orb.xp)
	XpOrbs.clear(game)
	return total

static func run(suite: Object, game: Node3D) -> void:
	# --- the biome gate -------------------------------------------------------
	# `TerrainGenerator.biome` classifies the surface and can only ever return these
	# strings, so any other name in a rule's filter is unreachable.
	var outcomes: Array = ["Sunwash desert","Frostpine highlands","Swamp","Willow shores","Oakwood meadow"]
	var generator := TerrainGenerator.new(8675309)
	var seen: Dictionary = {}
	for x in range(-600,600,37):
		for z in range(-600,600,37): seen[generator.biome(x,z)] = true
	suite.check(seen.keys().all(func(name): return name in outcomes),"the generator only ever reports the five known surface biomes")
	suite.check(MinecloniaOres.biome_matches("Oakwood meadow",[]) and MinecloniaOres.biome_matches("Sunwash desert",["Sunwash desert"]),"an empty filter accepts everything and an exact name matches")
	suite.check(MinecloniaOres.biome_matches("Frostpine highlands",["ExtremeHills","ExtremeHills_ocean"]) and not MinecloniaOres.biome_matches("Swamp",["ExtremeHills"]),"the source's mountain family maps onto the one mountain biome Voxey has")
	suite.check(not MinecloniaOres.biome_matches("Sunwash desert",["Mesa","Mesa_ocean"]) and not MinecloniaOres.biome_matches("Oakwood meadow",["DripstoneCave","DripstoneCave_deep_underground"]),"the badlands and cave-biome families name biomes this generator cannot produce, so their rules never place")
	# The gap is named rather than hidden: ten rules sit behind those two families.
	var unreachable: Array = MinecloniaOres.unrepresentable()
	var kinds: Dictionary = {}
	for rule in unreachable: kinds[rule.id] = int(kinds.get(rule.id,0))+1
	suite.check(unreachable.size() == 10,"exactly ten source rules are gated on a biome this generator cannot produce")
	suite.check(int(kinds.get(Nodes.GOLD_ORE,0)) == 1 and int(kinds.get(Nodes.COPPER_ORE,0)) == 7 and int(kinds.get(Nodes.DEEP_COPPER_ORE,0)) == 2,"the unreachable rules are the badlands gold band and the nine cave-biome copper bands")
	suite.check(MinecloniaOres.unrepresentable().all(func(rule): return rule.id in [Nodes.GOLD_ORE,Nodes.COPPER_ORE,Nodes.DEEP_COPPER_ORE]),"no other ore family is affected, so each of them still has a reachable route")

	# --- the height ceiling ---------------------------------------------------
	# Voxey's Overworld stops at Y64 (`TerrainGenerator.HEIGHT`), so a source band
	# that starts above it has nowhere to exist. Every family keeps a lower band, so
	# nothing is unobtainable — but the mountain distribution is the loss, and it is
	# named instead of implied.
	var high: Array = MinecloniaOres.above_ceiling(generator)
	var high_kinds: Dictionary = {}
	for rule in high: high_kinds[rule.id] = int(high_kinds.get(rule.id,0))+1
	suite.check(high.size() == 15,"fifteen source rules sit entirely above the Overworld ceiling")
	suite.check(int(high_kinds.get(VillageContent.EMERALD_ORE,0)) == 4 and int(high_kinds.get(Nodes.IRON_ORE,0)) == 7 and int(high_kinds.get(Nodes.COAL_ORE,0)) == 4,"the truncated rules are the four high emerald bands, seven iron bands and four coal bands")
	# Each of those families still generates from a band inside the world.
	for entry in [[VillageContent.EMERALD_ORE,"emerald"],[Nodes.IRON_ORE,"iron"],[Nodes.COAL_ORE,"coal"]]:
		var reachable: bool = false
		for rule in MinecloniaOreRules.DATA:
			if rule.id != entry[0] or rule.dimension != "overworld": continue
			if rule.min <= generator.terrain_ceiling()-1: reachable = true
		suite.check(reachable,"%s still has a band inside the world, so it is obtainable"%entry[1])
	# A taller world would move the number, so the count is derived from the ceiling
	# rather than hardcoded twice.
	var derived: int = 0
	for rule in MinecloniaOreRules.DATA:
		if rule.dimension == "overworld" and rule.min > generator.terrain_ceiling()-1: derived += 1
	suite.check(derived == high.size(),"the ceiling report is derived from `terrain_ceiling()`, so a height change updates it")

	# --- the ore payout is paid exactly once ----------------------------------
	# The redstone branch pays its own experience and so must not also fall through
	# to the generic ore payout; it did, and a broken redstone ore paid 14.
	suite.check(Nodes.ore_xp(Nodes.REDSTONE_ORE) == 7 and Nodes.ore_xp(RedstoneOre.LIT) == 7,"redstone ore carries the source's seven, lit or unlit")
	suite.check(xp_from_break(suite,game,Nodes.REDSTONE_ORE) == 7,"an unlit redstone ore pays its seven once")
	suite.check(xp_from_break(suite,game,RedstoneOre.LIT) == 7,"a lit redstone ore pays its seven once")
	suite.check(xp_from_break(suite,game,Nodes.COAL_ORE) == 1 and xp_from_break(suite,game,Nodes.DIAMOND_ORE) == 4,"coal and diamond pay the source's per-ore values")
	suite.check(xp_from_break(suite,game,Nodes.IRON_ORE) == 0,"iron ore carries no xp group in the source, so it pays nothing")
	suite.check(xp_from_break(suite,game,VillageContent.EMERALD_ORE) == 6,"emerald ore pays the source's six")
	game.inventory.restore([])
