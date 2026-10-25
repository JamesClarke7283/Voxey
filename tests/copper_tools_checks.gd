extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var inventory: Array = game.inventory.slots.duplicate(true); var grid: Array = game.inventory.grid.duplicate(true)
	var selected: int = game.inventory.selected; var mode: String = game.gamemode; var player_at: Vector3 = game.player.position
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/copper_tools_reference.json"))
	var world: VoxelWorld = game.world; var p := Vector3i(8,1800,8)
	game.player.position = Vector3(2,1800,2); game.inventory.selected = 0
	for x in range(6,11):
		for z in range(6,11):
			for y in range(1799,1803): world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1799 else Nodes.AIR)
	var target_ids: Dictionary = {"mcl_trees:tree_oak":Nodes.LOG,"mcl_core:dirt_with_grass":Nodes.GRASS,"mcl_core:dirt":Nodes.DIRT,"mcl_copper:block_exposed":Copper.BLOCK_STAGES[1],"mcl_core:coarse_dirt":DryTerrain.COARSE_DIRT,"mcl_core:grass_path":VillageContent.PATH}
	for row in source.actions:
		var plain_name: String = str(row.node).replace("_preserved","")
		var id: int = target_ids[plain_name]
		world.set_node(p+Vector3i.UP,Nodes.STONE if row.blocked else Nodes.AIR)
		world.set_node(p,id); Copper.set_waxed(world,p,str(row.node).ends_with("_preserved"))
		game.inventory.slots[0] = {"id":int(row.id),"count":1,"wear":0}
		if row.unbreaking > 0: game.inventory.slots[0]["data"] = {"enchantments":{"Unbreaking":int(row.unbreaking)}}
		Durability.set_normalized(game.inventory.slots[0],int(row.initial)); game.gamemode = "creative" if row.creative else "survival"
		var target: Dictionary = {"pos":p,"id":id,"normal":Vector3i.UP}
		if id == Nodes.LOG: WoodTypes.use(game,target)
		elif Copper.is_copper(id): Copper.use_axe(game,target)
		elif id == DryTerrain.COARSE_DIRT: DryTerrain.use(game,target)
		else: Farmland.use(game,target)
		var actual: String = ToolCapabilities.node_name(world.node_at(p))
		if Copper.waxed(world,p): actual += "_preserved"
		var wear: int = -1 if game.inventory.held().id == 0 else Durability.normalized(game.inventory.held())
		t.check(actual == row.node_after and wear == row.wear,"source copper action "+row.node+" blocked="+str(row.blocked)+" creative="+str(row.creative)+" Unbreaking="+str(row.unbreaking)+" initial="+str(row.initial)+" -> "+actual+" wear="+str(wear))
	game.gamemode = "survival"
	for normal in [Vector3i.DOWN,Vector3i.LEFT,Vector3i.UP]:
		world.set_node(p,Nodes.DIRT); world.set_node(p+Vector3i.UP,Nodes.AIR)
		game.inventory.slots[0] = {"id":CopperTools.FIRST+2,"count":1,"wear":0}
		Farmland.use(game,{"pos":p,"id":Nodes.DIRT,"normal":normal})
		t.check(world.node_at(p) == (Nodes.DIRT if normal.y < 0 else VillageContent.PATH) and Durability.normalized(game.inventory.held()) == (0 if normal.y < 0 else 344),"copper shovel lower/side/top face rule: "+str(normal))
	for id in CopperTools.IDS:
		t.check(Nodes.all_ids().has(id) and not Nodes.placeable(id) and ItemArt.texture(id).get_width() == 16 and ItemArt.mesh(id).get_surface_count() > 0,"copper tool has catalog entry, icon and held/drop mesh: "+Nodes.title(id))
		var item: Dictionary = {"id":id,"count":1,"wear":0,"data":{"custom_name":"Copper keepsake","enchantments":{"Unbreaking":3}}}
		Durability.set_normalized(item,40000)
		var repaired: Dictionary = Anvils.plan(item,{"id":Nodes.COPPER,"count":1,"wear":0})
		t.check(not repaired.is_empty() and Durability.normalized(repaired.output) == 23616 and repaired.output.data.custom_name == "Copper keepsake" and Inventory.enchantment(repaired.output,"Unbreaking") == 3,"copper ingot repairs a quarter of the tool and retains metadata: "+str(id))
		t.check(Anvils.plan(item,{"id":Nodes.IRON,"count":1,"wear":0}).is_empty() and Netherite.upgrade_id(id) == 0,"copper rejects iron repair and diamond-only smithing: "+str(id))
		var book: Dictionary = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"data":{"enchantments":{"Mending":1}}}
		var enchanted: Dictionary = Anvils.plan(item,book)
		t.check(not enchanted.is_empty() and Inventory.enchantment(enchanted.output,"Mending") == 1 and Enchanting.ability(id) == 13,"copper has source enchantability and accepts a Mending book: "+str(id))
	# Drive the real one-second station tick, with source ten-second cooking.
	var stations: Dictionary = world.stations; var growth: Dictionary = world.growth
	world.stations = {}; world.growth = {}
	for id in CopperTools.IDS:
		for device in [Nodes.FURNACE,VillageContent.BLAST_FURNACE,VillageContent.SMOKER]:
			world.stations = {}; world.set_node(p,device)
			var station: Dictionary = world.get_station(p,"furnace"); station.device = device
			station.slots[0] = {"id":id,"count":1,"wear":150,"data":{"enchantments":{"Unbreaking":3}}}
			station.slots[1] = {"id":Nodes.COAL,"count":1,"wear":0}
			var seconds: int = 5 if device == VillageContent.BLAST_FURNACE else 10
			for i in seconds-1: world._simulate()
			t.check(station.slots[2].id == 0 and station.slots[0].id == id,"copper recycling waits for its full cooking time: "+str([id,device]))
			world._simulate()
			t.check((station.slots[2].id == 0 and station.slots[0].id == id and station.slots[1].count == 1) if device == VillageContent.SMOKER else (station.slots[2].id == Harvesting.item_id("mcl_copper:copper_nugget") and station.slots[2].count == 1 and station.slots[0].id == 0),"normal/blast recycling and smoker exclusion: "+str([id,device]))
	world.stations = stations; world.growth = growth
	for row in [[Nodes.IRON_ORE,true],[Nodes.COPPER_ORE,true],[Nodes.LAPIS_ORE,true],[Nodes.GOLD_ORE,false],[Nodes.DIAMOND_ORE,false],[Nodes.REDSTONE_ORE,false],[Nodes.OBSIDIAN,false]]:
		var result: Dictionary = Harvesting.harvest(row[0],{"id":CopperTools.FIRST},EnchantRolls.new(12))
		t.check(result.harvestable == row[1],"copper pick source harvest level: "+Nodes.title(row[0]))
	for drop in game.drops.get_children(): drop.free()
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Nodes.IRON_ORE)
	game.inventory.slots[0] = {"id":CopperTools.FIRST,"count":1,"wear":0}
	game.player.target = {"pos":p,"id":Nodes.IRON_ORE,"normal":Vector3i.UP,"point":Vector3(p)+Vector3.ONE*0.5,"distance":2.0}
	game.player.mine(10.0)
	var iron: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == RawOres.RAW_IRON: iron += drop.amount
	t.check(world.node_at(p) == Nodes.AIR and iron == 1 and Durability.normalized(game.inventory.held()) == 343,"actual copper pick mining drops raw iron and adds source mining wear")
	game.inventory.restore([])
	for i in 5:
		game.inventory.slots[i] = {"id":CopperTools.IDS[i],"count":1,"wear":0,"data":{"custom_name":"Saved copper "+str(i),"enchantments":{"Unbreaking":3}}}
		Durability.set_normalized(game.inventory.slots[i],20000+i)
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	game.inventory.restore(saved.inventory)
	for i in 5: t.check(game.inventory.slots[i].id == CopperTools.IDS[i] and Durability.normalized(game.inventory.slots[i]) == 20000+i and Inventory.enchantment(game.inventory.slots[i],"Unbreaking") == 3 and game.inventory.slots[i].data.custom_name == "Saved copper "+str(i),"copper tool inventory persists exact wear and metadata: "+str(i))
	for x in range(6,11):
		for z in range(6,11):
			for y in range(1799,1803): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.inventory.slots = inventory; game.inventory.grid = grid; game.inventory.selected = selected; game.gamemode = mode; game.player.position = player_at
	for drop in game.drops.get_children(): drop.free()
	XpOrbs.clear(game)
