extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	var saved_inventory: Array = game.inventory.slots.duplicate(true)
	var saved_mode: String = game.gamemode
	var saved_target: Dictionary = game.player.target.duplicate(true)
	game.gamemode = "survival"
	PotionEffects.clear(game.player)
	var expected: Dictionary = {
		37:"mcl_copper:block",210:"mcl_core:stone_with_redstone",
		6004:"mcl_trees:stripped_oak",6005:"mcl_trees:bark_oak",6006:"mcl_trees:bark_stripped_oak",
		13001:"mcl_trees:tree_cherry_blossom",13035:"mcl_mangrove:propagule",13521:"mcl_bamboo:bamboo_mosaic",
		18:"mcl_torches:torch",13200:"mcl_trees:tree_bamboo",
		29:"mcl_farming:wheat",562:"mcl_farming:beetroot",561:"mcl_farming:beetroot_2",
		7518:"mcl_farming:pumpkintige_linked_r",7521:"mcl_farming:pumpkintige_linked_b",
		11415:"mcl_flowers:wildflowers_1",11419:"mcl_flowers:peony_top",
		1241:"mcl_daylight_detector:daylight_detector_inverted",9321:"mcl_minecarts:golden_rail_on",
		11446:"mcl_anvils:anvil_damage_1",11281:"mcl_candles:candle_cake_lit",
		1180:"mcl_chests:ender_chest_small",1189:"mcl_chests:violet_shulker_box_small",
	}
	for id in expected:
		t.check(ToolCapabilities.node_name(id) == expected[id],"mining selects the registered placed node: "+str(id)+" "+expected[id])
	for stage in range(1,6):
		for direction in [-1,1]:
			var id: int = PointedDripstone.node_for(stage,direction)
			t.check(ToolCapabilities.node_name(id) == "mcl_dripstone:dripstone_"+("top_" if direction > 0 else "bottom_")+PointedDripstone.STAGES[stage-1],"pointed dripstone resolves stage "+str(stage)+" direction "+str(direction))
	var doors_valid: bool = true
	for item in Doors.ITEMS+Copper.DOOR_ITEMS+[13300,13301,13302,13303,13304,BambooWood.DOOR]:
		if not Doors.is_item(item): continue
		for opened in [false,true]:
			for upper in [false,true]:
				var id: int = Doors.state_id(item,2,true,opened,upper)
				var name: String = ToolCapabilities.node_name(id)
				doors_valid = doors_valid and name.ends_with(("_t_" if upper else "_b_")+("2" if opened else "1"))
	t.check(doors_valid,"wood, iron and oxidized copper doors map their actual upper/lower and open/closed states")
	t.check(ToolCapabilities.node_name(BuildingShapes.slab_for(Masonry.POLISHED_TUFF)) == "mcl_stairs:slab_tuff_polished" and ToolCapabilities.node_name(BuildingShapes.stair_for(MinecloniaOres.TUFF)) == "mcl_stairs:stair_tuff","tuff and polished tuff shapes retain distinct identities")
	t.check(ToolCapabilities.node_name(BuildingShapes.slab_for(6006)).is_empty() and not MiningNodes.native_reason(BuildingShapes.slab_for(6006)).is_empty(),"native stripped bark shapes do not borrow an unstripped source registration")
	t.check(not Nodes.placeable(Archaeology.BRUSH) and not Nodes.placeable(9910),"brushes and pottery sherds are items, so ordinary placement cannot turn them into blocks")
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mining_reference.json"))
	var index: Dictionary = {}
	for i in reference.nodes.size(): index[reference.nodes[i].name] = i
	var pick: Dictionary = {}
	for section in reference.cases:
		if int(section.input.id) == 95 and int(section.input.efficiency) == 0: pick = section
	# Integration through the player mining path: every timed dig is interrupted
	# first, then completed, with the real oracle's wear checked on the held tool.
	var p: Vector3i = Vector3i(game.player.position.floor())+Vector3i(0,4,0)
	var original: int = game.world.node_at(p)
	for id in [37,GlassColors.FIRST,BuildingShapes.slab_for(Nodes.COBBLE),BuildingShapes.stair_for(Masonry.POLISHED_TUFF),Copper.CUT_STAGES[2],PaleOak.RESIN_BLOCK]:
		game.inventory.slots[game.inventory.selected] = {"id":95,"count":1,"wear":0}
		ToolCapabilities.reset(game.player)
		game.player.mining_tool = -1
		game.world.set_node(p,id)
		game.player.target = {"pos":p,"id":id,"normal":Vector3i.UP}
		var value: Dictionary = pick.results[index[ToolCapabilities.node_name(id)]]
		if float(value.time) > 0:
			game.player.mine(float(value.time)*0.45)
			t.check(game.world.node_at(p) == id and Durability.normalized(game.inventory.held()) == 0,"partial source dig leaves block and tool intact: "+Nodes.title(id))
		game.player.mine(float(value.time)*0.56+0.001)
		t.check(game.world.node_at(p) == Nodes.AIR and Durability.normalized(game.inventory.held()) == int(value.wear),"completed source dig removes block and applies exact wear: "+Nodes.title(id))
	# Plant stages use dig_immediate, even when the held tool is unsuitable.
	game.inventory.slots[game.inventory.selected] = {"id":83,"count":1,"wear":0}
	game.world.set_node(p,Nodes.RIPE_WHEAT)
	game.player.mining_tool = -1
	game.player.target = {"pos":p,"id":Nodes.RIPE_WHEAT,"normal":Vector3i.UP}
	game.player.mine(0.001)
	t.check(game.world.node_at(p) == Nodes.AIR and Durability.normalized(game.inventory.held()) == 0,"mature wheat breaks immediately and does not wear an unsuitable sword")
	# Unbreakable source nodes cannot be removed through the mining path.
	game.world.set_node(p,Nodes.END_FRAME)
	game.player.mining_tool = -1
	game.player.target = {"pos":p,"id":Nodes.END_FRAME,"normal":Vector3i.UP}
	game.player.mine(1000)
	t.check(game.world.node_at(p) == Nodes.END_FRAME,"the source end portal frame remains unbreakable in survival")
	game.world.set_node(p,original)
	game.inventory.slots = saved_inventory
	game.gamemode = saved_mode
	game.player.target = saved_target
	game.player.mining_tool = -1
	ToolCapabilities.reset(game.player)
