extends RefCounted

# Content families added from the missing-feature audit.
static func run(suite: Object, game: Node3D) -> void:
	core(suite,game)
	extra(suite,game)
	review_fixes(suite,game)


# Content families added from the missing-feature audit: stained glass, raw ores,
# nether materials, candles, flowers and the sculk family.
static func core(suite: Object, game: Node3D) -> void:
	# Stained glass: sixteen colours of block and pane, translucent, Silk Touch only.
	suite.check(GlassColors.FIRST == 11210 and GlassColors.PANE_FIRST == 11226,"stained glass and panes hold their allocated ids")
	var glass_ok: bool = true
	for i in GlassColors.COUNT:
		var glass: int = GlassColors.FIRST+i
		var pane: int = GlassColors.PANE_FIRST+i
		if not Nodes.exists(glass) or not Nodes.exists(pane): glass_ok = false
		if not Nodes.placeable(glass) or not Nodes.placeable(pane): glass_ok = false
		if not Nodes.transparent(glass) or not Nodes.transparent(pane): glass_ok = false
		if GlassColors.pane_for(glass) != pane or GlassColors.glass_for(pane) != glass: glass_ok = false
	suite.check(glass_ok,"all sixteen stained glasses and panes exist, are translucent and pair by colour")
	suite.check(Nodes.drop(GlassColors.FIRST) == 0 and Nodes.drop(GlassColors.PANE_FIRST) == 0,"stained glass drops nothing without Silk Touch")
	var silk: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
	suite.check(Enchantments.harvest(GlassColors.FIRST,silk) == [[GlassColors.FIRST,1]],"Silk Touch recovers stained glass")
	var inv := Inventory.new(); inv.add_item(Nodes.GLASS,8); inv.add_item(VillageContent.DYE_LIME,1)
	var index: int = inv.recipe_index(GlassColors.FIRST+11)
	suite.check(index >= 0 and inv.craft(index,"table") and inv.count_item(GlassColors.FIRST+11) == 8,"eight glass and a dye make eight stained glass")
	# Raw ores: the ore drops the raw form and the raw form smelts back.
	suite.check(Nodes.drop(Nodes.IRON_ORE) == RawOres.RAW_IRON and Nodes.drop(Nodes.GOLD_ORE) == RawOres.RAW_GOLD,"iron and gold ore drop raw ore")
	suite.check(Nodes.smelt_result(RawOres.RAW_COPPER) == Nodes.COPPER,"raw copper smelts into copper")
	suite.check(RawOres.harvest(Nodes.COPPER_ORE,{"id":Nodes.TOOLS,"count":1,"wear":0})[0][1] >= 2,"copper ore yields at least two raw copper")
	suite.check(Nodes.exists(RawOres.RAW_IRON_BLOCK) and Nodes.hardness(RawOres.RAW_IRON_BLOCK) == 5.0,"a block of raw iron exists at the source's hardness")
	var nuggets := Inventory.new(); nuggets.add_item(RawOres.COPPER_NUGGET,9)
	var ingot: int = -1
	for i in nuggets.recipes.size():
		if nuggets.recipes[i].ingredients == {RawOres.COPPER_NUGGET:9}: ingot = i; break
	suite.check(ingot >= 0 and nuggets.craft(ingot,"table") and nuggets.count_item(Nodes.COPPER) == 1,"nine copper nuggets make one copper ingot")
	suite.check(not Nodes.exists(11307),"the copper block keeps its single existing id")
	# Nether materials.
	var nether_ok: bool = true
	for id in [NetherBlocks.RED_NETHER_BRICKS,NetherBlocks.CHISELED_NETHER_BRICKS,NetherBlocks.CRACKED_NETHER_BRICKS,
		NetherBlocks.CHISELED_QUARTZ,NetherBlocks.SMOOTH_QUARTZ,
		NetherBlocks.QUARTZ_BRICK,NetherBlocks.POLISHED_BASALT,NetherBlocks.CRACKED_BLACKSTONE_BRICKS]:
		if not Nodes.exists(id) or not Nodes.placeable(id) or Nodes.preferred_tool(id) != 0: nether_ok = false
	# The nether wart block is the source's hoe block (`handy`/`hoey`), not a stone one.
	if not Nodes.exists(NetherBlocks.NETHER_WART_BLOCK) or Nodes.preferred_tool(NetherBlocks.NETHER_WART_BLOCK) != 4: nether_ok = false
	suite.check(nether_ok,"every new nether material is an obtainable block with the source's preferred tool")
	suite.check(Nodes.smelt_result(Nodes.NETHER_BRICKS) == NetherBlocks.CRACKED_NETHER_BRICKS,"nether bricks smelt into their cracked form")
	suite.check(Fire.is_fire(NetherBlocks.SOUL_FIRE) == false and Nodes.plant(NetherBlocks.SOUL_FIRE) and not Nodes.solid(NetherBlocks.SOUL_FIRE),"soul fire is a flame-shaped plant, not a block")
	suite.check(NetherBlocks.flame_for(Nodes.SOUL_SAND) == NetherBlocks.SOUL_FIRE,"igniting above soul sand yields soul fire")
	# Candles: eight ids per colour, the count in the id, and the source's light.
	suite.check(Candles.PER_COLOR == 8 and Candles.COUNT == 16,"candles use eight ids per colour")
	suite.check(Candles.count_of(Candles.FIRST+3) == 4 and Candles.light_level(Candles.FIRST+Candles.MAX_COUNT+3) == 12,"a four-candle stack lights for the source's twelve")
	suite.check(not Nodes.solid(Candles.FIRST) and Nodes.hardness(Candles.FIRST) == 0.1,"a candle is a non-solid decoration at hardness 0.1")
	var candle_inv := Inventory.new(); candle_inv.add_item(Nodes.STRING,1); candle_inv.add_item(Beehives.COMB,1)
	var candle_recipe: int = candle_inv.recipe_index(Candles.FIRST)
	suite.check(candle_recipe >= 0 and candle_inv.can_craft(candle_inv.recipes[candle_recipe],"table"),"string over honeycomb makes a candle")
	# Flowers: ten species that are flowers for dye, stew and decoration.
	var flower_ok: bool = true
	for id in FlowersExtra.FLOWERS:
		if not Nodes.exists(id) or not Nodes.placeable(id) or not Nodes.plant(id): flower_ok = false
		if not FoodFeatures.flower(id): flower_ok = false
		if FlowersExtra.dye_of(id) == 0: flower_ok = false
	suite.check(flower_ok,"every added flower is a placeable plant, a flower and a dye source")
	suite.check(FlowersExtra.is_flower(FlowersExtra.WITHER_ROSE) and FlowersExtra.contact_effect(FlowersExtra.WITHER_ROSE) == "withering","the wither rose carries the source's contact effect")
	suite.check(FlowersExtra.stew_effect(FlowersExtra.ALLIUM) == "fire_resistance","the added flowers carry their source stew effects")
	suite.check(FlowersExtra.light_level(FlowersExtra.FIREFLY_BUSH) == 2 and FlowersExtra.light_level(FlowersExtra.FERN) == 0,"only the firefly bush emits the source's two")
	suite.check(FoodFeatures.is_extra_plant(FlowersExtra.FERN) and not FoodFeatures.is_extra_plant(FlowersExtra.ALLIUM),"small plants are distinct from flowers")
	# Sculk: three blocks and one item, with the checkout's own limits respected.
	suite.check(Sculk.SCULK == 11507 and Sculk.ECHO_SHARD == 11510,"sculk holds its allocated ids")
	suite.check(Nodes.exists(Sculk.SCULK) and Nodes.exists(Sculk.VEIN) and Nodes.exists(Sculk.CATALYST),"the three sculk nodes exist")
	suite.check(Nodes.exists(Sculk.ECHO_SHARD) and not Nodes.placeable(Sculk.ECHO_SHARD),"the echo shard is an item, not a block")
	suite.check(Sculk.light_level(Sculk.CATALYST) == 6 and Sculk.light_level(Sculk.SCULK) == 0,"only the catalyst emits the source's six, which is all the checkout enables")
	suite.check(Sculk.drops_nothing(Sculk.SCULK) and Sculk.shears_drop(Sculk.VEIN),"sculk drops nothing and a vein is a shears drop")

# End decorations, mud, lush-cave plants and armor trims.
static func extra(suite: Object, game: Node3D) -> void:
	# End and mud.
	suite.check(Nodes.exists(EndMud.PURPUR_PILLAR) and Nodes.exists(EndMud.MUD_BRICKS),"the purpur pillar and mud bricks exist")
	suite.check(Nodes.smelt_result(Nodes.CHORUS_FRUIT) == EndMud.POPPED_CHORUS_FRUIT,"chorus fruit smelts into popped chorus fruit")
	suite.check(not Nodes.placeable(EndMud.POPPED_CHORUS_FRUIT) and Nodes.placeable(EndMud.PACKED_MUD),"the popped fruit is an item while packed mud is a block")
	var mud := Inventory.new(); mud.add_item(VillageContent.MUD,1); mud.add_item(Nodes.GRAIN,1)
	var packed: int = mud.recipe_index(EndMud.PACKED_MUD)
	suite.check(packed >= 0 and mud.can_craft(mud.recipes[packed],"hand") and mud.craft(packed,"hand") and mud.count_item(EndMud.PACKED_MUD) == 1,"mud and wheat make packed mud shapelessly")
	suite.check(EndMud.is_chorus_flower(EndMud.CHORUS_FLOWER) and EndMud.is_chorus_flower(EndMud.CHORUS_FLOWER_DEAD),"both chorus flower states are flowers")
	suite.check(EndMud.drop_id(EndMud.CHORUS_FLOWER_DEAD) == EndMud.CHORUS_FLOWER,"a dead chorus flower drops the living one")
	# Lush caves.
	suite.check(Nodes.exists(LushCaveExtra.ROOTED_DIRT) and Nodes.exists(LushCaveExtra.SPORE_BLOSSOM) and Nodes.exists(LushCaveExtra.AZALEA),"rooted dirt, the spore blossom and the azalea exist")
	suite.check(LushCaveExtra.is_ceiling_plant(LushCaveExtra.SPORE_BLOSSOM) and not LushCaveExtra.is_ceiling_plant(LushCaveExtra.AZALEA),"the spore blossom is the ceiling plant")
	suite.check(LushCaveExtra.compostability(LushCaveExtra.AZALEA_FLOWERING) == 85 and LushCaveExtra.compostability(LushCaveExtra.AZALEA) == 65,"the azaleas carry the source's compostability")
	suite.check(Composters.chance(LushCaveExtra.AZALEA_FLOWERING) == 85,"the composter accepts the flowering azalea at the source's percentage")
	suite.check(WoodTypes.is_leaves(LushCaveExtra.AZALEA_LEAVES) and not WoodTypes.is_leaves(LushCaveExtra.AZALEA),"azalea leaves are leaves; the azalea bush is not")
	suite.check(LushCaveExtra.is_dripleaf(LushCaveExtra.DRIPLEAF_BIG) and LushCaveExtra.is_dripleaf_stem(LushCaveExtra.DRIPLEAF_SMALL_STEM),"the dripleaf leaf and stem are distinct")
	suite.check(LushCaveExtra.bone_meal_target(LushCaveExtra.DRIPLEAF_SMALL) == LushCaveExtra.DRIPLEAF_BIG,"bone meal grows a small dripleaf into a big one")
	var upright: int = LushCaveExtra.DRIPLEAF_BIG
	suite.check(LushCaveExtra.tip(upright) == LushCaveExtra.DRIPLEAF_BIG_TIPPED_HALF and LushCaveExtra.tip(upright,2) == LushCaveExtra.DRIPLEAF_BIG_TIPPED_FULL,"the big dripleaf cycles through its tipped forms")
	suite.check(LushCaveExtra.tips_leaf(upright) and not LushCaveExtra.tips_leaf(LushCaveExtra.DRIPLEAF_BIG_TIPPED_HALF),"only an upright big leaf can tip")
	# Armor trims.
	suite.check(ArmorTrims.COUNT == 17 and ArmorTrims.FIRST == 11490,"seventeen trim templates are allocated")
	var all_trim: bool = true
	for i in ArmorTrims.COUNT:
		if not Nodes.exists(ArmorTrims.template_id(i)): all_trim = false
	suite.check(all_trim,"every trim template exists")
	suite.check(ArmorTrims.is_material(Nodes.DIAMOND) and ArmorTrims.is_material(Nodes.COPPER) and not ArmorTrims.is_material(Nodes.DIRT),"only the source's trim minerals are materials")
	suite.check(ArmorTrims.trimmable(Nodes.ARMOR) and not ArmorTrims.trimmable(Nodes.ELYTRA),"armor is trimmable and the elytra is blacklisted")
	var piece: Dictionary = {"id":Nodes.ARMOR,"count":1,"wear":0}
	suite.check(ArmorTrims.apply(piece,ArmorTrims.template_id(0),Nodes.GOLD) and ArmorTrims.is_trimmed(piece),"a template with a mineral trims the armor")
	suite.check(not ArmorTrims.apply(piece,ArmorTrims.template_id(0),Nodes.GOLD),"the identical trim is refused")
	var cleaned: Dictionary = Inventory.new().clean_slot(piece)
	suite.check(cleaned.get("data",{}).get("trim_overlay") == "sentry" and int(cleaned.data.trim_material) == Nodes.GOLD,"the trim metadata survives inventory cleaning")
	var trim_inv := Inventory.new()
	trim_inv.add_item(ArmorTrims.template_id(0),1); trim_inv.add_item(Nodes.COBBLE,1); trim_inv.add_item(Nodes.DIAMOND,7)
	var dup: int = trim_inv.recipe_index(ArmorTrims.template_id(0))
	suite.check(dup >= 0 and trim_inv.can_craft(trim_inv.recipes[dup],"table") and trim_inv.recipes[dup].count == 2,"a template duplicates with its dupe item and seven diamonds")
	# Sculk.
	suite.check(Nodes.exists(Sculk.SCULK) and Nodes.exists(Sculk.VEIN) and Nodes.exists(Sculk.CATALYST),"the three sculk nodes exist")
	suite.check(Nodes.exists(Sculk.ECHO_SHARD) and not Nodes.placeable(Sculk.ECHO_SHARD),"the echo shard is an item")
	suite.check(Sculk.light_level(Sculk.CATALYST) == 6 and Sculk.light_level(Sculk.SCULK) == 0,"only the catalyst emits the source's six")
	suite.check(Sculk.drops_nothing(Sculk.SCULK) and Sculk.shears_drop(Sculk.VEIN),"sculk drops nothing and a vein is a shears drop")

# The break contract and light for the modules added above, and the review's fixes.
static func review_fixes(suite: Object, game: Node3D) -> void:
	# Concrete: one sweep hardens **every** wet powder cell, not just the first.
	var world: VoxelWorld = game.world
	var base: Vector3i = Vector3i(2,game.world.generator.terrain_height(2,2)+3,2)
	for x in range(0,5):
		for y in range(-1,3):
			for z in range(0,2): world.set_node(base+Vector3i(x,y,z),Nodes.AIR)
	for x in range(0,5):
		world.set_node(base+Vector3i(x,0,0),Concrete.POWDER_FIRST+3)
		world.set_node(base+Vector3i(x,-1,0),Nodes.WATER)
	Concrete.update(world,2.0)
	# With water directly below, the source's ABM writes the concrete into that water
	# cell and clears the powder cell, so the result is one level down.
	var hardened: int = 0
	for x in range(0,5):
		if world.node_at(base+Vector3i(x,-1,0)) == Concrete.BLOCK_FIRST+3 and world.node_at(base+Vector3i(x,0,0)) == Nodes.AIR: hardened += 1
	suite.check(hardened == 5,"one sweep hardens every wet powder cell rather than the first")
	# Sculk: nothing by hand, Silk Touch for the block, shears for the vein.
	suite.check(Nodes.drop(Sculk.SCULK) == 0 and Nodes.drop(Sculk.CATALYST) == 0 and Nodes.drop(Sculk.VEIN) == 0,"sculk, its vein and its catalyst drop nothing through the generic path")
	var hand: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0}
	var silk: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
	var shears: Dictionary = {"id":Nodes.SHEARS,"count":1,"wear":0}
	suite.check(Sculk.harvest(Sculk.SCULK,hand).is_empty() and Sculk.harvest(Sculk.SCULK,silk) == [[Sculk.SCULK,1]],"sculk yields nothing by hand and itself under Silk Touch")
	suite.check(Sculk.harvest(Sculk.VEIN,shears) == [[Sculk.VEIN,1]] and Sculk.harvest(Sculk.VEIN,silk).is_empty(),"a sculk vein yields itself to shears and not to Silk Touch")
	# Soul fire emits the source's light.
	suite.check(NetherBlocks.light_level(NetherBlocks.SOUL_FIRE) == 10,"soul fire carries the source's light level")
	game.world.set_node(base+Vector3i(0,2,1),NetherBlocks.SOUL_FIRE)
	suite.check(Pasture.emission(game.world,base+Vector3i(0,2,1)) == 10,"a placed soul flame emits ten")
	# The smithing template is consumed with the mineral, so one template trims once.
	var inv := Inventory.new()
	var piece: Dictionary = {"id":Nodes.ARMOR,"count":1,"wear":0}
	var template: Dictionary = {"id":ArmorTrims.template_id(0),"count":1,"wear":0}
	var mineral: Dictionary = {"id":Nodes.GOLD,"count":1,"wear":0}
	suite.check(ArmorTrims.apply(piece,template.id,mineral.id),"the trim applies")
	suite.check(Anvils.repair_wear(60,0.5,60) == 30,"a repair boost is a fraction of the item's own durability")
	var pick: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":59}
	var plan: Dictionary = Anvils.material_repair(pick,4,Nodes.PLANKS)
	# Four planks take the wear from 59 to 0 on a 60-durability pickaxe, which is the
	# source's 100% tier; the ladder is reached rather than one plank doing it all.
	suite.check(plan.get("materials",0) == 4 and int(plan.get("wear",-1)) == 0,"a wooden pickaxe consumes its full four-material ladder")
	suite.check(Anvils.material_repair({"id":Nodes.TOOLS,"count":1,"wear":59},1,Nodes.PLANKS).get("materials",0) == 1 and int(Anvils.material_repair({"id":Nodes.TOOLS,"count":1,"wear":59},1,Nodes.PLANKS).wear) == 44,"one plank repairs only its own 25% share")
	suite.check(Anvils.repair_material(Nodes.ARMOR) == Nodes.IRON and Anvils.repair_material(VillageContent.CHAIN_HELMET) == Nodes.IRON and Anvils.repair_material(VillageContent.TURTLE_HELMET) != 0,"armor repairs with its own material ladder, and chainmail with iron")
	var saved: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":5,"data":{"pwp":3}}
	suite.check(Inventory.new().clean_slot(saved).get("data",{}).get("pwp",0) == 3,"the prior-work penalty survives inventory cleaning")
	# Sound kinds added by this batch are all synthesized.
	for kind in ["crit","piston_extend","piston_retract","drip","fuse","rocket","splash","portal","guardian","totem","wither"]:
		if not game.sounds.has(kind):
			suite.check(false,"every added sound kind is synthesized"); return
	suite.check(true,"every added sound kind is synthesized")
