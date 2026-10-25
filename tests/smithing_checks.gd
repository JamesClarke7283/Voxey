extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,58,8)
	game.world.set_node(p, VillageContent.SMITHING_TABLE)
	game.player.position = Vector3(p)+Vector3(2,0,2); game.gamemode = "survival"
	game.inventory.restore([]); game.open_inventory("smithing",p)
	var s: Dictionary = game.hud.station_data
	t.check(s.kind == "smithing" and s.slots.size() == 4,"Smithing has three real input slots and one output")
	game.hud.cursor = {"id":Nodes.DIRT,"count":5,"wear":0}; game.hud._slot_click(0,true,false)
	t.check(s.slots[0].id == 0 and game.hud.cursor.id == Nodes.DIRT,"Equipment slot rejects arbitrary blocks")
	game.hud.return_cursor()
	game.hud.cursor = {"id":95,"count":1,"wear":0,"data":{"custom_name":"Remember me","enchantments":{"Efficiency":3},"pwp":5}}
	Durability.set_normalized(game.hud.cursor,32123); game.hud._slot_click(0,true,false)
	game.hud.cursor = {"id":Netherite.INGOT,"count":3,"wear":0}; game.hud._slot_click(1,true,false)
	game.hud.cursor = {"id":Netherite.TEMPLATE,"count":2,"wear":0}; game.hud._slot_click(2,true,false)
	t.check(s.slots[3].id == Netherite.TOOLS and s.slots[0].id == 95 and s.slots[1].count == 3 and s.slots[2].count == 2,"Upgrade preview does not consume any selected input")
	t.check(Durability.normalized(s.slots[3]) == 32123 and s.slots[3].data.custom_name == "Remember me" and s.slots[3].data.pwp == 5 and s.slots[3].data.enchantments == {"Efficiency":3},"Upgrade preserves exact normalized wear, names, enchantments and prior work")
	game.hud._slot_click(3,true,false)
	t.check(game.hud.cursor.id == Netherite.TOOLS and s.slots[0].id == 0 and s.slots[1].count == 2 and s.slots[2].count == 1 and s.slots[3].id == 0,"Taking output consumes exactly one equipment, mineral and template")
	game.hud._slot_click(3,true,false)
	t.check(game.hud.cursor.id == Netherite.TOOLS and s.slots[3].id == 0,"Smithing output rejects inserted items")
	game.hud.return_cursor()
	for i in 4: s.slots[i] = Smithing.empty()
	game.hud.cursor = {"id":Nodes.ARMOR,"count":1,"wear":0,"data":{"custom_name":"Keepsake","color":12345,"pwp":2}}
	Durability.set_normalized(game.hud.cursor,12345); game.hud._slot_click(0,true,false)
	game.hud.cursor = {"id":Nodes.QUARTZ,"count":2,"wear":0}; game.hud._slot_click(1,true,false)
	game.hud.cursor = {"id":ArmorTrims.FIRST,"count":2,"wear":0}; game.hud._slot_click(2,true,false)
	t.check(s.slots[3].data.trim_overlay == "sentry" and s.slots[3].data.trim_material == Nodes.QUARTZ and s.slots[3].data.color == 12345 and s.slots[3].data.pwp == 2,"Quartz trim preview preserves other armor metadata")
	t.check(game.hud.station_ui[3].item_data.get("trim_overlay","") == "sentry","Smithing output icon receives its visible trim metadata")
	game.hud._slot_click(3,true,false)
	t.check(s.slots[1].count == 1 and s.slots[2].count == 1 and game.achievements.is_unlocked("crafting_a_new_look"),"A trim consumes one material and template and unlocks its source achievement")
	game.hud._slot_click(0,true,false)
	t.check(s.slots[3].id == 0,"Reapplying the identical trim and material produces no output")
	game.hud.cursor = {"id":Netherite.SCRAP,"count":1,"wear":0}; game.hud._slot_click(1,true,false)
	t.check(game.hud.cursor.id == Netherite.SCRAP and s.slots[1].id == Nodes.QUARTZ,"Netherite scrap cannot enter the mineral slot")
	game.hud.return_cursor()
	for i in 4: s.slots[i] = Smithing.empty()
	game.inventory.restore([])
	game.inventory.slots[0] = {"id":Nodes.ARMOR,"count":1,"wear":0}
	game.inventory.slots[1] = {"id":Nodes.GOLD,"count":3,"wear":0}
	game.inventory.slots[2] = {"id":ArmorTrims.FIRST+4,"count":2,"wear":0}
	game.hud.shift_mode = true
	for i in [2,1,0]: game.hud._slot_click(i,false,false)
	game.hud.shift_mode = false
	t.check(s.slots[0].id == Nodes.ARMOR and s.slots[1].id == Nodes.GOLD and s.slots[2].id == ArmorTrims.FIRST+4 and s.slots[3].id == Nodes.ARMOR,"Shift transfer sorts templates, minerals and armor into their source slots")
	t.check(game.player.armor_slots[1].id != Nodes.ARMOR,"Shifted smithing armor is inserted instead of automatically equipped")
	var saved_achievements: Dictionary = game.achievements.to_save().duplicate(true)
	game.achievements.from_save({})
	for key in ["sentry","dune","coast","wild","eye","bolt","flow","host"]: Smithing.award(game,{"id":Nodes.ARMOR,"trimmed":true,"pattern":key})
	t.check(not game.achievements.is_unlocked("smithing_with_style") and game.achievements.count("smithing_with_style") == 0,"Eight arbitrary trim types do not unlock the required-eight achievement")
	for key in Smithing.REQUIRED_TRIMS: Smithing.award(game,{"id":Nodes.ARMOR,"trimmed":true,"pattern":key})
	t.check(game.achievements.is_unlocked("smithing_with_style"),"All eight source-required trim types unlock Smithing with Style")
	game.achievements.from_save({}); Smithing.award(game,{"id":Netherite.TOOLS})
	t.check(not game.achievements.is_unlocked("serious_dedication"),"Upgrading a pickaxe does not unlock the hoe achievement")
	Smithing.award(game,{"id":Netherite.TOOLS+4})
	t.check(game.achievements.is_unlocked("serious_dedication"),"A Netherite hoe unlocks Serious Dedication")
	game.achievements.from_save(saved_achievements)
	game.resume(); game.set_process(false)
	t.check(game.save_game("user://smithing-check.json"),"Smithing inputs and preview save")
	game.set_process(true); game.load_world_data(game.read_save("user://smithing-check.json"))
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	s = game.world.get_station(p,"smithing")
	t.check(s.slots[0].id == Nodes.ARMOR and s.slots[1].count == 3 and s.slots[2].count == 2 and s.slots[3].data.trim_overlay == "tide","Smithing input counts and preview survive reload")
	t.check(game.world.circuits.container(p).is_empty(),"Smithing is not a source hopper or comparator container")
	var before: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.ARMOR: before += drop.amount
	game.break_node(p,VillageContent.SMITHING_TABLE,Nodes.TOOLS+15)
	var after: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.ARMOR: after += drop.amount
	t.check(after-before == 1,"Breaking smithing returns the actual gear without duplicating the preview")
	game.resume(); game.set_process(false)
