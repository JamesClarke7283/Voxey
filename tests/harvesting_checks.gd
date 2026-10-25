extends RefCounted

static func dig(game: Node3D, p: Vector3i, id: int, tool: int, enchantments: Dictionary = {}) -> Dictionary:
	for drop in game.drops.get_children(): drop.free()
	XpOrbs.clear(game)
	game.inventory.slots[game.inventory.selected] = {"id":tool,"count":1 if tool else 0,"wear":0,"data":{"enchantments":enchantments}}
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.world.set_node(p,id)
	game.break_node(p,id,tool)
	var items: Dictionary = {}
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): items[drop.item_id] = int(items.get(drop.item_id,0))+drop.amount
	var xp: int = 0
	for orb in XpOrbs.orbs(game):
		if not orb.is_queued_for_deletion(): xp += int(orb.xp)
	return {"items":items,"xp":xp,"removed":game.world.node_at(p) != id}

static func run(t: SceneTree, game: Node3D) -> void:
	var inventory: Array = game.inventory.slots.duplicate(true)
	var mode: String = game.gamemode
	game.gamemode = "survival"
	var p := Vector3i(8,500,8)
	var saved: int = game.world.node_at(p)
	var cases: Array = [
		[Nodes.GRASS,0,{}, {Nodes.DIRT:1}],
		[Nodes.SNOW,0,{}, {Nodes.DIRT:1}],
		[Nodes.SNOW,97,{"Silk Touch":1}, {Nodes.GRASS:1}],
		[Nodes.BOOKSHELF,81,{}, {Nodes.BOOK:3}],
		[Nodes.BOOKSHELF,96,{"Silk Touch":1}, {Nodes.BOOKSHELF:1}],
		[Nodes.GLASS,95,{}, {}],
		[Nodes.GLASS,95,{"Silk Touch":1}, {Nodes.GLASS:1}],
		[Nodes.VINE,0,{}, {}],
		[Nodes.VINE,Nodes.SHEARS,{}, {Nodes.VINE:1}],
		[VillageContent.COBWEB,98,{}, {Nodes.STRING:1}],
		[VillageContent.COBWEB,Nodes.SHEARS,{}, {VillageContent.COBWEB:1}],
		[Nodes.IRON_ORE,80,{}, {}],
		[Nodes.IRON_ORE,85,{}, {RawOres.RAW_IRON:1}],
		[Nodes.IRON_ORE,95,{"Silk Touch":1}, {Nodes.IRON_ORE:1}],
		[SnowCover.BASE+7,97,{"Silk Touch":1}, {Nodes.SNOW_BLOCK:1}],
		[BuildingShapes.slab_for(Nodes.COBBLE)+2,95,{}, {BuildingShapes.slab_for(Nodes.COBBLE):2}],
		[SeaPickles.for_size(4,true),0,{}, {SeaPickles.FIRST:4}],
		[Copper.CUT_STAGES[0],80,{}, {}],
		[Copper.CUT_STAGES[0],85,{}, {Copper.CUT_STAGES[0]:1}],
	]
	for row in cases:
		var actual: Dictionary = dig(game,p,row[0],row[1],row[2])
		t.check(actual.removed and actual.items == row[3],"actual source harvest "+Nodes.title(row[0])+" with "+Nodes.title(row[1])+" "+str(row[2])+": "+str(actual.items))
	var diamond: Dictionary = dig(game,p,Nodes.DIAMOND_ORE,95)
	t.check(diamond.items == {Nodes.DIAMOND:1} and diamond.xp == 4,"a diamond ore pays one diamond and its four XP once")
	var silk: Dictionary = dig(game,p,Nodes.DIAMOND_ORE,95,{"Silk Touch":1})
	t.check(silk.items == {Nodes.DIAMOND_ORE:1} and silk.xp == 0,"an applicable Silk Touch drop suppresses ore XP")
	var book: Dictionary = Harvesting.harvest(Nodes.DIAMOND_ORE,{"id":VillageContent.ENCHANTED_BOOK,"data":{"enchantments":{"Fortune":3,"Silk Touch":1}}},EnchantRolls.new(19))
	t.check(book.harvestable == false and book.drops.is_empty(),"carrying an enchanted book neither mines ore nor applies its enchantments")
	var all: Dictionary = {}
	for seed in range(1,100):
		var result: Dictionary = Harvesting.harvest(Nodes.COPPER_ORE,{"id":95},EnchantRolls.new(seed))
		for entry in result.drops: all[int(entry[1])] = true
	t.check(all.keys().all(func(count): return count >= 2 and count <= 5) and all.size() == 4,"the source's unenchanted copper table reaches all four counts from two to five")
	var fortune: Dictionary = {}
	for seed in range(1,200):
		var result: Dictionary = Harvesting.harvest(Nodes.GRAVEL,{"id":97,"data":{"enchantments":{"Fortune":3}}},EnchantRolls.new(seed))
		for entry in result.drops: fortune[entry[0]] = true
	t.check(fortune.keys() == [Nodes.FLINT],"Fortune III gravel always yields flint through the registered drop table")
	game.world.set_node(p,saved)
	game.inventory.slots = inventory
	game.gamemode = mode
	XpOrbs.clear(game)
