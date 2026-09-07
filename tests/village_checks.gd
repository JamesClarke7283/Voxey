extends RefCounted
static func run(suite: SceneTree, game: Node3D) -> void:
	var gen := TerrainGenerator.new(8675309)
	var village: Dictionary = VillageGenerator.nearest(gen,Vector3(8,30,8))
	suite.check(village == VillageGenerator.nearest(TerrainGenerator.new(8675309),Vector3(8,30,8)),"villages are deterministic for a world seed")
	suite.check(VillageContent.PROFESSIONS.size() == 13 and VillageTrades.DATA.size() == 13,"all thirteen Mineclonia professions are available")
	var offers: int = 0; var valid: bool = true
	for profession in VillageTrades.DATA:
		var tiers: Dictionary = {}
		for offer in VillageTrades.DATA[profession]:
			offers += 1; tiers[offer.tier] = true
			for cost in offer.cost: valid = valid and Nodes.exists(cost[0]) and cost[1] > 0 and cost[2] <= Nodes.max_stack(cost[0])
			valid = valid and Nodes.exists(offer.give[0]) and offer.give[1] > 0
		suite.check(tiers.size() == 5,profession+" has offers at every profession level")
	suite.check(offers == 297 and valid,"all 297 source trade offers resolve to valid items and prices")
	suite.check(VillageContent.LEVELS == [0,10,70,150,250],"profession XP thresholds match local Mineclonia")
	for id in VillageContent.BLOCKS:
		suite.check(Nodes.exists(id) and Nodes.tile(id,0) >= 137 and not Art.build_node_mesh(id).get_surface_count() == 0,Nodes.title(id)+" has a registered voxel mesh")
	var column: Dictionary = gen.generate_column(Vector2i(floori(village.center.x/16.0),floori(village.center.z/16.0)),{})
	var wide: bool = false
	for block in column.blocks:
		for id in block.data:
			if id > 255: wide = true; break
	suite.check(wide,"generated columns retain village IDs above 255")
	var p := Vector3i(8,50,8)
	game.world.set_node(p,VillageContent.EMERALD_BLOCK)
	suite.check(game.world.node_at(p) == VillageContent.EMERALD_BLOCK,"world edits preserve wide node IDs")
	var person: Dictionary = game.villages.make_record("test-farmer","farmer",Vector3(p),p,p,p)
	var sell: Dictionary = person.offers[0]
	game.inventory = Inventory.new(); game.inventory.add_item(Nodes.GRAIN,20)
	suite.check(game.villages.transaction(person,sell,true).is_empty() and game.inventory.count_item(VillageContent.EMERALD) == 1 and game.inventory.count_item(Nodes.GRAIN) == 0,"farmer buys exactly 20 wheat for one emerald")
	suite.check(person.xp == 2 and sell.uses == 1,"trading spends stock and earns villager XP")
	var before: Array = game.inventory.slots.duplicate(true)
	suite.check(not game.villages.transaction(person,sell,true).is_empty() and before == game.inventory.slots and sell.uses == 1,"failed trades leave payment and stock untouched")
	person.reputations[game.player_id] = 0
	for slot in game.inventory.slots: slot.merge({"id":Nodes.STONE,"count":64,"wear":0},true)
	game.inventory.slots[0] = {"id":Nodes.GRAIN,"count":21,"wear":0}
	before = game.inventory.slots.duplicate(true)
	suite.check(not game.villages.transaction(person,sell,true).is_empty() and before == game.inventory.slots,"full inventory rejects trades atomically")
	game.inventory.slots[0].count = 20
	suite.check(game.villages.transaction(person,sell,true).is_empty() and game.inventory.count_item(VillageContent.EMERALD) == 1,"payment may free the output slot in a full inventory")
	var fletcher: Dictionary = game.villages.make_record("test-fletcher","fletcher",Vector3(p),p,p,p)
	var gravel: Dictionary = fletcher.offers[2]
	game.inventory = Inventory.new(); game.inventory.add_item(VillageContent.EMERALD,1); game.inventory.add_item(Nodes.GRAVEL,10)
	suite.check(game.villages.transaction(fletcher,gravel,true).is_empty() and game.inventory.count_item(Nodes.FLINT) == 10 and game.inventory.count_item(Nodes.GRAVEL) == 0,"two-input flint trade consumes emerald and ten gravel")
	person.reputations[game.player_id] = 0; sell.uses = sell.stock; var xp: int = person.xp
	suite.check(not game.villages.transaction(person,sell,true).is_empty() and person.xp == xp,"sold-out offers cannot trade")
	game.villages.restock(person,100,person.restock_day)
	suite.check(sell.uses == 0 and person.restocks == 1 and sell.demand == sell.stock,"workplace restocks reset stock and increase demand for sold-out offers")
	suite.check(game.villages.costs(person,sell)[0][1] > 20,"demand increases prices")
	sell.uses = 1; game.villages.restock(person,110,person.restock_day)
	suite.check(sell.uses == 1,"second restock waits over 120 seconds")
	game.villages.restock(person,221,person.restock_day)
	suite.check(sell.uses == 0 and person.restocks == 0,"second workplace restock works after its cooldown")
	sell.uses = 1; game.villages.restock(person,400,person.restock_day)
	suite.check(sell.uses == 1,"villagers have only two restocks per working day")
	var novice: Dictionary = game.villages.make_record("test-cleric","cleric",Vector3(p),p,p,p)
	game.inventory = Inventory.new(); game.inventory.add_item(Nodes.ROTTEN_FLESH,32)
	suite.check(game.villages.transaction(novice,novice.offers[0],true).is_empty() and novice.level == 2,"cleric's source 12-XP trade unlocks Apprentice")
	game.player.position = Vector3(p)+Vector3.RIGHT*2
	game.state = "trading"; game.villages.trading_key = novice.key
	game.hud.show_trading(novice.key)
	suite.check(game.hud.screen == "trading","trading screen renders costs, offers, levels and stock")
	game.pause()
	var loaded: Dictionary = Inventory.clean_slot({"id":VillageContent.CROSSBOW,"count":1,"wear":2,"data":{"loaded_arrow":VillageContent.POISON_ARROW}})
	suite.check(loaded.get("data",{}).get("loaded_arrow",0) == VillageContent.POISON_ARROW,"crossbow ammunition survives slot cleaning")
	game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
	game.world.set_node(p,VillageContent.CARROTS_0)
	for stage in 3: game.world.growth[p] = 30; game.world._simulate()
	suite.check(game.world.node_at(p) == VillageContent.CARROTS_3 and VillageContent.crop_drops(VillageContent.CARROTS_3) == [[VillageContent.CARROT,3]],"planted carrots mature through stages and provide a renewable harvest")
	var chunk_count: int = 0
	for x in range(-30,30):
		for z in range(-30,30):
			if SlimeSpawns.slime_chunk(8675309,Vector2i(x,z)): chunk_count += 1
	suite.check(chunk_count > 270 and chunk_count < 450,"roughly one tenth of positive and negative chunks are slime chunks")
	var chunk := Vector2i.ZERO
	while not SlimeSpawns.slime_chunk(8675309,chunk): chunk.x += 1
	suite.check(SlimeSpawns.underground(gen,Vector3(chunk.x*16,-30,0)) and not SlimeSpawns.underground(gen,Vector3(chunk.x*16,20,0)),"slime chunks spawn underground below -24, not at the surface")
	var swamp := Vector3.INF
	for x in range(-600,600,12):
		for z in range(-600,600,12):
			if gen.biome(x,z) == "Swamp": swamp = Vector3(x,gen.terrain_height(x,z)+1,z); break
		if not is_inf(swamp.x): break
	suite.check(not is_inf(swamp.x) and SlimeSpawns.surface(gen,swamp,0.1,1) and not SlimeSpawns.surface(gen,swamp,1,1) and not SlimeSpawns.surface(gen,swamp,0.1,5),"swamp slimes spawn at night and avoid the new moon")
	game.world.set_node(p,Nodes.AIR)
	for x in range(3,15):
		for z in range(3,13):
			game.world.set_node(Vector3i(x,49,z),Nodes.STONE)
			for y in range(50,54): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(5.5,50,8.5)
	var cow: Creature = game.spawn_creature("cow",Vector3(11.5,50,8.5))
	game.inventory = Inventory.new(); game.inventory.add_item(VillageContent.LEAD,2); game.gamemode = "survival"
	suite.check(game.leads.attach(cow) and game.inventory.count_item(VillageContent.LEAD) == 1,"a lead attaches to an animal and consumes one item")
	var distance: float = cow.position.distance_to(game.player.position)
	for step in 20: game.leads.update(0.05)
	suite.check(cow.position.distance_to(game.player.position) < distance and game.leads.leads[0].rope.get_child_count() == 12,"a visible segmented lead pulls the animal toward the player")
	var settler: Creature = game.spawn_creature("villager",Vector3(10.5,50,6.5))
	suite.check(game.leads.attach(settler) and game.leads.attached(settler),"villagers can be leashed as well")
	var snapshot: Dictionary = game.dimension_snapshot()
	suite.check(snapshot.leads.size() == 2 and snapshot.adventure.village_life.people.has(settler.person_key),"animal and villager leads are included in dimension saves")
	game.leads.detach(cow)
	suite.check(not game.leads.attached(cow),"releasing a lead removes the rope")
	game.leads.clear()
	var slime: Creature = game.spawn_creature("slime",Vector3(10,50,10)); slime.set_slime_size(4)
	suite.check(slime.health == 16 and slime.width > 0.9,"large slime size controls health and collision")
	var slime_count: int = game.creatures.get_children().filter(func(m): return m.kind == "slime" and not m.is_queued_for_deletion()).size()
	slime.die()
	suite.check(game.creatures.get_children().filter(func(m): return m.kind == "slime" and not m.is_queued_for_deletion()).size() > slime_count,"large slimes split into smaller slimes")
	game.gamemode = "creative"; game.inventory = Inventory.new()
	game.teleport(Vector3(village.center)+Vector3(4.5,1.01,4.5))
	while game.state == "loading": await suite.process_frame
	game.pause()
	while game.world.columns.size() < 25: await suite.process_frame
	game.villages.update(0.6)
	var villagers: int = game.creatures.get_children().filter(func(m): return m is VillageMob and m.kind == "villager" and not m.is_queued_for_deletion()).size()
	suite.check(villagers >= 5,"visiting a village creates its villagers")
	var state_before: int = game.villages.state().people.size(); game.villages.update(0.6)
	suite.check(game.villages.state().people.size() == state_before,"revisiting a village does not duplicate residents")
	game.survival.show_station(village.center,VillageContent.BREWING_STAND)
	suite.check(game.hud.screen == "workstation","brewing workstation exposes potion recipes")
	game.pause()
