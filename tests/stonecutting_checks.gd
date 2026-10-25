extends RefCounted
static func clean(inv: Inventory) -> void:
	inv.restore([]); inv.selected = 0
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,58,8)
	for x in range(-3,4):
		for z in range(-3,4):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(p+Vector3i(x,y,z),0)
	game.player.position = Vector3(p)+Vector3(3,0,2); game.gamemode = "survival"
	clean(game.inventory); game.inventory.add_item(VillageContent.STONECUTTER,2)
	Stonecutting.try_place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE})
	t.check(Stonecutting.is_cutter(game.world.node_at(p)) and game.inventory.count_item(VillageContent.STONECUTTER) == 1,"Stonecutter places with a saved facing")
	t.check(game.world.intersects(Vector3(p)+Vector3(0.5,0.5,0.2),0.01,0.01) and not game.world.intersects(Vector3(p)+Vector3(0.5,0.7,0.2),0.01,0.01),"Stonecutter collision ends at the source 9/16 height")
	var s: Dictionary = game.world.get_station(p,"stonecutter")
	t.check(s.kind == "stonecutter" and s.slots.size() == 2,"Stonecutter keeps an input and a virtual output")
	game.open_inventory("stonecutter",p)
	game.hud.cursor = {"id":Nodes.STONE,"count":5,"wear":0}; game.hud._slot_click(0,true,false)
	t.check(s.slots[0].count == 5 and game.hud.cursor.id == 0 and game.hud.recipe_list.get_child_count() > 0,"UI accepts source material and lists its real cuts")
	game.hud._select_cut("mcl_stairs:slab_stone_rough"); game.hud._select_cut("mcl_stairs:slab_stone_rough")
	t.check(s.slots[1].count == 4 and s.slots[0].count == 5,"Selecting a cut twice adds two virtual batches without consuming input")
	game.hud._fill_cut()
	t.check(s.slots[1].count == 10,"Fill output previews all available slabs")
	game.hud._slot_click(1,true,true)
	t.check(game.hud.cursor.count == 5 and s.slots[0].count == 2 and s.slots[1].id == 0,"Taking five slabs rounds material consumption up to three blocks and clears the preview")
	game.hud._slot_click(1,true,false)
	t.check(game.hud.cursor.count == 5 and s.slots[1].id == 0,"Players cannot insert an item into the virtual output")
	game.hud.return_cursor(); game.hud._select_cut("mcl_core:stonebrick"); game.open_inventory("stonecutter",p)
	t.check(s.slots[1].id == 0 and s.slots[0].count == 2,"Reopening clears the preview and preserves real input")
	game.hud.cursor = {"id":Nodes.DIRT,"count":3,"wear":0}; game.hud._slot_click(0,true,false)
	t.check(s.slots[0].id == Nodes.DIRT and Stonecutting.choices(s.slots[0]).is_empty(),"Non-stonecuttable items can be stored but do not produce recipes")
	game.hud.return_cursor(); s.slots[0] = {"id":Nodes.COPPER_NODE,"count":2,"wear":0,"data":{"copper_waxed":true}}
	game.hud.refresh_slots(); game.hud._select_cut("mcl_copper:block_cut_preserved"); game.hud._fill_cut()
	t.check(s.slots[1].count == 8 and Copper.waxed_item(s.slots[1]),"Waxed copper previews four preserved cut blocks per input")
	game.hud._slot_click(1,true,false)
	t.check(game.hud.cursor.count == 8 and Copper.waxed_item(game.hud.cursor) and s.slots[0].id == 0,"Withdrawing preserved copper retains wax and consumes the right inputs")
	game.hud.return_cursor(); s.slots[0] = {"id":Nodes.STONE,"count":6,"wear":0}
	Stonecutting.select(s,"mcl_core:stonebrick")
	game.world.set_node(p,VillageContent.STONECUTTER)
	clean(game.inventory); game.inventory.add_item(Screwdriver.ID,1)
	for i in 5: Screwdriver.turn(game,p,Screwdriver.ROTATE_AXIS)
	t.check(Stonecutting.facing(game.world.node_at(p)) == 20 and s.slots[0].count == 6,"All-axis screwdriver rotation preserves the input inventory")
	game.villages.state().people["stonecutting-poi"] = {"dead":false,"profession":"mason","job":[p.x,p.y,p.z]}
	t.check(p in VillagePois.points(game),"A rotated stonecutter remains a mason jobsite")
	game.villages.state().people.erase("stonecutting-poi")
	t.check(game.world.circuits.container(p).is_empty(),"The source's stonecutter is excluded from hopper container automation")
	var saved_id: int = game.world.node_at(p)
	game.resume(); game.set_process(false)
	t.check(game.save_game("user://stonecutter-check.json"),"Stonecutter inventory and facing save")
	game.set_process(true); game.load_world_data(game.read_save("user://stonecutter-check.json"))
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	s = game.world.get_station(p,"stonecutter")
	t.check(game.world.node_at(p) == saved_id and s.slots[0].count == 6,"Stored stonecutter input and orientation survive reload")
	game.open_inventory("stonecutter",p); Stonecutting.select(s,"mcl_core:stonebrick")
	var before: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.STONE: before += drop.amount
	game.break_node(p,game.world.node_at(p),Nodes.TOOLS+15)
	var after: int = 0; var previews: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.STONE: after += drop.amount
		if drop.item_id == Nodes.BRICKS: previews += drop.amount
	t.check(after-before == 6 and previews == 0,"Breaking the stonecutter drops real input without duplicating virtual output")
	game.resume(); game.set_process(false)
