extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,58,8)
	for x in range(-3,4):
		for z in range(-3,4):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(p+Vector3i(x,y,z),0)
	game.player.position = Vector3(p)+Vector3(3,0,2); game.gamemode = "survival"
	game.inventory.restore([]); game.inventory.selected = 0; game.inventory.add_item(VillageContent.GRINDSTONE,2)
	GrindstoneRepair.try_place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE})
	t.check(GrindstoneRepair.is_grindstone(game.world.node_at(p)) and game.inventory.count_item(VillageContent.GRINDSTONE) == 1,"Grindstone uses source placement and consumes one item")
	t.check(game.world.collision_boxes(p).size() == 5,"World uses the five source grindstone collision boxes")
	game.open_inventory("grindstone",p)
	var s: Dictionary = game.hud.station_data
	t.check(s.kind == "grindstone" and s.slots.size() == 3,"Grindstone opens with two selected inputs and one virtual output")
	var pick: int = Nodes.TOOLS+10
	game.inventory.slots[3] = {"id":pick,"count":1,"wear":100}
	game.hud.cursor = {"id":pick,"count":1,"wear":200,"data":{"enchantments":{"Efficiency":3,"Curse of Vanishing":1},"custom_name":"First","pwp":4,"trim":{"material":"gold"}}}
	Durability.set_normalized(game.hud.cursor,50000)
	game.hud._slot_click(0,true,false)
	t.check(s.slots[0].id == pick and s.slots[2].id == pick and game.inventory.slots[3].wear == 100,"Single-item preview leaves other carried tools untouched")
	t.check(Durability.normalized(s.slots[2]) == 50000 and s.slots[2].data.custom_name == "First" and not s.slots[2].data.has("pwp") and not s.slots[2].data.has("trim"),"Disenchantment preserves exact wear and name while removing prior-work and trim metadata")
	game.hud.cursor = {"id":pick,"count":1,"wear":0}; game.hud._slot_click(1,true,false)
	t.check(Durability.normalized(s.slots[2]) == 0 and s.slots[0].id == pick and s.slots[1].id == pick,"An undamaged second input is accepted and repairs the result without consuming preview inputs")
	var before_xp: float = game.experience; var orb_before: int = 0
	for orb in XpOrbs.orbs(game): orb_before += orb.xp
	game.hud._slot_click(2,true,false)
	var emitted: int = -orb_before
	for orb in XpOrbs.orbs(game): emitted += orb.xp
	t.check(game.hud.cursor.id == pick and s.slots[0].id == 0 and s.slots[1].id == 0 and s.slots[2].id == 0,"Taking a repair output consumes exactly the two selected inputs")
	t.check(emitted >= 21 and emitted <= 39 and game.experience == before_xp,"Disenchantment throws physical XP instead of crediting a menu preview")
	t.check(game.hud.cursor.data.enchantments == {"Curse of Vanishing":1},"Output retains curses and removes ordinary enchantments")
	game.hud._slot_click(2,true,false)
	t.check(game.hud.cursor.id == pick and s.slots[2].id == 0,"Grindstone output rejects insertion")
	game.hud.return_cursor()
	game.hud.cursor = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"wear":0,"data":{"enchantments":{"Curse of Binding":1}}}; game.hud._slot_click(1,true,false)
	t.check(s.slots[2].id == VillageContent.ENCHANTED_BOOK and s.slots[2].data.enchantments == {"Curse of Binding":1},"A curse-only book still has the source's zero-XP output")
	game.hud._slot_click(2,true,false); game.hud.return_cursor()
	game.hud.cursor = {"id":Nodes.DIRT,"count":8,"wear":0}; game.hud._slot_click(0,true,false)
	t.check(s.slots[0].count == 8 and s.slots[2].id == 0,"Arbitrary input items may be stored without producing a result")
	game.hud.cursor = {"id":pick,"count":1,"wear":0}; game.hud._slot_click(0,true,false); game.hud.return_cursor()
	game.hud.cursor = {"id":pick,"count":1,"wear":0}; game.hud._slot_click(1,true,false)
	t.check(s.slots[2].id == pick and s.slots[2].wear == 0,"Two undamaged tools still combine as in the source")
	game.open_inventory("grindstone",p)
	t.check(s.slots[2].id == pick,"Reopening refreshes the preview from the real inputs")
	game.world.set_node(p,GrindstoneRepair.placed(13))
	game.villages.state().people["grindstone-poi"] = {"dead":false,"profession":"weaponsmith","job":[p.x,p.y,p.z]}
	t.check(p in VillagePois.points(game),"Wall-mounted grindstone remains a weaponsmith jobsite")
	game.villages.state().people.erase("grindstone-poi")
	t.check(game.world.circuits.container(p).is_empty(),"Source grindstone is excluded from hopper and comparator containers")
	game.resume(); game.set_process(false)
	t.check(game.save_game("user://grindstone-check.json"),"Mounted grindstone and selected inputs save")
	game.set_process(true); game.load_world_data(game.read_save("user://grindstone-check.json"))
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	s = game.world.get_station(p,"grindstone")
	t.check(GrindstoneRepair.facing(game.world.node_at(p)) == 13 and s.slots[0].id == pick and s.slots[1].id == pick,"Grindstone orientation and selected inputs survive reload")
	var dropped: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == pick: dropped += drop.amount
	game.break_node(p,game.world.node_at(p),Nodes.TOOLS+15)
	var after: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == pick: after += drop.amount
	t.check(after-dropped == 2,"Breaking a grindstone drops both real inputs without duplicating the output")
	game.resume(); game.set_process(false)
