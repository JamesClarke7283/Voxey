extends RefCounted

# Raw ores (mcl_raw_ores/init.lua, mcl_copper/items.lua): mining an ore yields its
# raw form, raw forms compress into storage blocks, and copper nuggets pack into
# ingots.
static func run(suite: Object, game: Node3D) -> void:
	# The source drops raw ore, not the ingot.
	suite.check(Nodes.drop(Nodes.IRON_ORE) == RawOres.RAW_IRON and Nodes.drop(Nodes.GOLD_ORE) == RawOres.RAW_GOLD,"iron and gold ore drop their raw forms")
	suite.check(Nodes.drop(Nodes.DEEP_IRON_ORE) == RawOres.RAW_IRON and Nodes.drop(Nodes.DEEP_GOLD_ORE) == RawOres.RAW_GOLD,"deepslate iron and gold ore drop the same raw forms")
	suite.check(RawOres.drop_for(Nodes.COPPER_ORE) == RawOres.RAW_COPPER,"copper ore drops raw copper")
	# Raw ore smelts back into the ingot it came from.
	suite.check(Nodes.smelt_result(RawOres.RAW_IRON) == Nodes.IRON and Nodes.smelt_result(RawOres.RAW_GOLD) == Nodes.GOLD and Nodes.smelt_result(RawOres.RAW_COPPER) == Nodes.COPPER,"each raw ore smelts into its ingot")
	suite.check(Nodes.smelt_result(Nodes.DEEP_COPPER_ORE) == Nodes.COPPER,"deepslate copper ore still smelts into copper")
	# Copper ore rolls the source's two-to-five count and widens with Fortune.
	# Source `mcl_core.fortune_drop_ore`: the multiplier's chance is
	# `1 - 2/(fortune+2)`, which at Fortune 0 is exactly zero, so an unenchanted
	# pickaxe always yields the ore's base drop of two.
	var plain: int = RawOres.harvest(Nodes.COPPER_ORE,{"id":Nodes.TOOLS,"count":1,"wear":0})[0][1]
	suite.check(plain == 2,"an unenchanted pickaxe yields the source's base two raw copper")
	var rolls: Dictionary = {}
	var only_raw: bool = true
	for i in 400:
		var entry: Array = RawOres.harvest(Nodes.COPPER_ORE,{"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Fortune":3}}})[0]
		if entry[0] != RawOres.RAW_COPPER: only_raw = false
		rolls[entry[1]] = true
	# The source multiplies the ore's base drop of two by `random(2, 1 + fortune)`
	# when its chance `1 - 2/(fortune + 2)` passes, so Fortune 3 yields either the
	# untouched base of two (the 40% miss) or an even count from four to eight.
	suite.check(only_raw and rolls.has(2) and rolls.size() >= 2 and rolls.keys().all(func(v): return v == 2 or (v >= 4 and v <= 8 and v % 2 == 0)),"Fortune multiplies the base copper drop by the source's discrete uniform roll")
	var lucky: Array = RawOres.harvest(Nodes.COPPER_ORE,{"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Fortune":3}}})[0]
	suite.check(lucky[0] == RawOres.RAW_COPPER and lucky[1] >= 1,"Fortune widens the copper roll")
	suite.check(RawOres.harvest(Nodes.IRON_ORE,{"id":Nodes.TOOLS,"count":1,"wear":0}).is_empty(),"only copper ore has its own count table")
	# Blocks exist and pair with their raw items.
	suite.check(RawOres.RAW_IRON == 11300 and RawOres.RAW_IRON_BLOCK == 11303 and RawOres.COPPER_NUGGET == 11306,"raw ore ids match the allocated block")
	var all_ok: bool = true
	for pair in [[RawOres.RAW_IRON,RawOres.RAW_IRON_BLOCK],[RawOres.RAW_GOLD,RawOres.RAW_GOLD_BLOCK],[RawOres.RAW_COPPER,RawOres.RAW_COPPER_BLOCK]]:
		if RawOres.block_for(pair[0]) != pair[1] or RawOres.raw_for(pair[1]) != pair[0]: all_ok = false
		if not Nodes.exists(pair[0]) or not Nodes.exists(pair[1]): all_ok = false
		if not Nodes.placeable(pair[1]) or Nodes.placeable(pair[0]): all_ok = false
		if Nodes.hardness(pair[1]) != 5.0: all_ok = false
	suite.check(all_ok,"the three raw forms pair with a placeable storage block at the source's hardness")
	suite.check(not Nodes.placeable(RawOres.COPPER_NUGGET) and Nodes.max_stack(RawOres.COPPER_NUGGET) == 64,"a copper nugget is an item, not a block")
	# No second copper block: Voxey's own id stays the single one.
	suite.check(not Nodes.exists(11307) and Copper.BLOCK_STAGES[0] == Nodes.COPPER_NODE,"the copper block keeps its single existing id rather than gaining a duplicate")
	# Recipes both ways for each storage block, and the nugget pair.
	var inv := Inventory.new()
	inv.add_item(RawOres.RAW_IRON,9)
	var pack: int = inv.recipe_index(RawOres.RAW_IRON_BLOCK)
	suite.check(pack >= 0 and inv.can_craft(inv.recipes[pack],"table") and inv.craft(pack,"table") and inv.count_item(RawOres.RAW_IRON_BLOCK) == 1,"nine raw iron compress into one block of raw iron")
	inv = Inventory.new(); inv.add_item(RawOres.RAW_IRON_BLOCK,1)
	var unpack: int = inv.recipe_index(RawOres.RAW_IRON)
	suite.check(unpack >= 0 and inv.craft(unpack,"hand") and inv.count_item(RawOres.RAW_IRON) == 9,"one block of raw iron unpacks into nine raw iron")
	inv = Inventory.new(); inv.add_item(RawOres.COPPER_NUGGET,9)
	# `recipe_index` returns the first recipe producing an id, and copper already has
	# a block-driven one, so find the nugget recipe by its ingredients.
	var nuggets: int = -1
	for i in inv.recipes.size():
		if inv.recipes[i].ingredients == {RawOres.COPPER_NUGGET:9}: nuggets = i; break
	suite.check(nuggets >= 0 and inv.can_craft(inv.recipes[nuggets],"table") and inv.craft(nuggets,"table") and inv.count_item(Nodes.COPPER) == 1,"nine copper nuggets make one copper ingot")
	inv = Inventory.new(); inv.add_item(Nodes.COPPER,1)
	var split: int = inv.recipe_index(RawOres.COPPER_NUGGET)
	suite.check(split >= 0 and inv.craft(split,"hand") and inv.count_item(RawOres.COPPER_NUGGET) == 9,"one copper ingot splits into nine nuggets")
	# Art.
	var varied: bool = false
	for x in 16:
		for y in 16:
			if RawOres.pixel(RawOres.RAW_IRON_BLOCK,x,y,Color(0.5,0.5,0.5)) != Color(0.5,0.5,0.5): varied = true
	suite.check(varied and Nodes.tile(RawOres.RAW_IRON_BLOCK,0) != 0,"raw ore blocks have their own tile and procedural art")
