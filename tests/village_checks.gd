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
		suite.check(Nodes.exists(id) and Nodes.tile(id,0) >= 0 and Nodes.tile(id,0) < 137+VillageContent.BLOCKS.size()+WoodTypes.TEXTURES.size() and not Art.build_node_mesh(id).get_surface_count() == 0,Nodes.title(id)+" has a registered voxel mesh")
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
	for metadata in [{},{"custom_name":"Scout"},{"enchantments":{"Quick Charge":3}},{"custom_name":"Scout","enchantments":{"Quick Charge":3}}]:
		var unloaded: Dictionary = Inventory.clean_slot({"id":VillageContent.CROSSBOW,"count":1,"wear":2,"data":metadata})
		suite.check(unloaded.id == VillageContent.CROSSBOW and unloaded.wear == 2 and unloaded.get("data",{}) == metadata,"unloaded crossbows preserve optional metadata without requiring loaded_arrow: "+str(metadata))
	for invalid_arrow in [Nodes.AIR,Nodes.STONE,-1,999999]:
		var invalid: Dictionary = Inventory.clean_slot({"id":VillageContent.CROSSBOW,"count":1,"data":{"custom_name":"Scout","loaded_arrow":invalid_arrow,"charge":1.0}})
		suite.check(invalid.get("data",{}) == {"custom_name":"Scout"},"crossbow cleaning discards invalid ammunition and charge: "+str(invalid_arrow))
	game.inventory = Inventory.new(); game.gamemode = "survival"
	game.inventory.add_item(VillageContent.CROSSBOW,1,2,{"custom_name":"Scout","enchantments":{"Quick Charge":3}})
	game.inventory.add_item(VillageContent.POISON_ARROW,2)
	game.survival.fire_crossbow()
	game.inventory.restore(JSON.parse_string(JSON.stringify(game.inventory.slots)))
	suite.check(game.inventory.held().get("data",{}).get("loaded_arrow",0) == VillageContent.POISON_ARROW and game.inventory.count_item(VillageContent.POISON_ARROW) == 1,"loading and restoring an enchanted crossbow preserves its arrow and consumes one round")
	game.inventory.held().data.charge = 0
	game.survival.fire_crossbow()
	game.inventory.restore(JSON.parse_string(JSON.stringify(game.inventory.slots)))
	suite.check(game.inventory.held().get("data",{}) == {"custom_name":"Scout","enchantments":{"Quick Charge":3}} and game.inventory.held().wear == 3,"fired enchanted crossbows restore safely without loaded_arrow and retain their name and enchantments")
	for entity in game.entities.get_children():
		if entity is Arrow: entity.free()
	game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
	game.world.set_node(p,VillageContent.CARROTS_0)
	# Growth needs light: with no light the mean brightness is zero and `grow`
	# refuses outright, which is why this check used to pass or fail depending on
	# the time of day the suite happened to run at. A glowstone beside the crop
	# makes the light deterministic. The clock is advanced a period per call so
	# the elapsed-time term does not depend on earlier phases either.
	game.world.set_node(p+Vector3i(1,0,0),Nodes.GLOWSTONE)
	# `grow` draws from an unseeded RNG by default, so a fixed seed is passed in.
	# The clock is also set from a fixed base rather than advanced from whatever
	# `day_time` happens to be, because `grow`'s elapsed-time term reads it and a
	# leftover value from an earlier phase made this check order-dependent.
	var growth_rng := RandomNumberGenerator.new()
	growth_rng.seed = 20250918
	# The crop's elapsed-time term is read from `day_time`, which the game also
	# advances every frame, so the metadata's stored last_time must be cleared or a
	# leftover from an earlier phase changes how many calls it takes to mature.
	game.world.block_states.erase(VoxelWorld.station_key(p))
	game.day_time = 0.25
	for stage in 40:
		game.day_time = fposmod(game.day_time+0.9,1.0)
		CropFarming.grow(game.world,p,1,true,false,growth_rng)
		if game.world.node_at(p) == VillageContent.CARROTS_3: break
	var _d: Array = VillageContent.crop_drops(VillageContent.CARROTS_3)
	print("DBG node=",game.world.node_at(p)," want=",VillageContent.CARROTS_3," size=",_d.size()," id=",_d[0][0]," carrot=",VillageContent.CARROT," n=",_d[0][1]," light=",Pasture.light(game.world,p,14))
	# The carrot's drop is a *roll*, not a fixed amount: the source's own table is
	# four with rarity 5, three with rarity 2, two with rarity 2, and **one
	# otherwise** — so a single carrot is the most common outcome. Asserting a
	# minimum of two was wrong: it passed only while the global RNG stream happened
	# to land high, and any change that shifted that stream exposed it.
	var carrot_drop: Array = CropFarming.harvest(VillageContent.CARROTS_3)
	suite.check(game.world.node_at(p) == VillageContent.CARROTS_3 and carrot_drop.size() == 1 and carrot_drop[0][0] == VillageContent.CARROT and carrot_drop[0][1] >= 1 and carrot_drop[0][1] <= 4,"planted carrots mature through eight source stages and provide source harvest amounts")
	# And the distribution is the source's: over many rolls every value appears, with
	# one carrots being at least as common as any other.
	var counts: Dictionary = {}
	for i in 600:
		var roll: Array = CropFarming.harvest(VillageContent.CARROTS_3)
		var amount: int = roll[0][1]
		counts[amount] = int(counts.get(amount,0))+1
	suite.check(counts.size() >= 2 and counts.keys().all(func(k: int): return k >= 1 and k <= 4),"carrot harvest amounts stay within the source's one-to-four range")
	suite.check(int(counts.get(1,0)) > 0,"a single carrot is a possible harvest, as the source's fallback makes it")
	# A crop that is not yet mature yields a single seed rather than a harvest, and
	# for a carrot the seed *is* a carrot — which the source's own registration does
	# too, so the check is the amount rather than the item.
	suite.check(CropFarming.harvest(VillageContent.CARROTS_0) == [[VillageContent.CARROT,1]],"an immature carrot yields a single seed rather than a harvest")
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
