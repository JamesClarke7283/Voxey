extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	suite.check(PotionCatalog.DEFINITIONS.size() == 27,"water and all 26 source potion types are registered")
	var variants_valid: bool = true
	for id in PotionCatalog.ITEMS:
		variants_valid = variants_valid and Nodes.exists(id) and Nodes.max_stack(id) == (64 if PotionCatalog.ITEMS[id].form == "arrow" else 1)
	suite.check(variants_valid,"all 234 potion forms and strengths have correct stack limits")
	var awkward: int = PotionCatalog.find("awkward")
	var speed: int = PotionCatalog.find("swiftness")
	suite.check(PotionCatalog.brew(VillageContent.WATER_BOTTLE,VillageContent.NETHER_WART_ITEM) == awkward,"nether wart turns water into awkward potion")
	suite.check(PotionCatalog.brew(awkward,Nodes.SUGAR) == speed,"sugar turns awkward potion into swiftness")
	suite.check(PotionCatalog.brew(speed,VillageContent.FERMENTED_SPIDER_EYE) == PotionCatalog.find("slowness"),"fermented spider eye corrupts swiftness to slowness")
	var strong: int = PotionCatalog.brew(speed,VillageContent.GLOWSTONE_DUST)
	var extended: int = PotionCatalog.brew(strong,Nodes.REDSTONE_WIRE)
	suite.check(PotionCatalog.effects(strong)[0].level == 2 and PotionCatalog.effects(strong)[0].duration == 90,"strong swiftness is level II for 90 seconds")
	suite.check(PotionCatalog.effects(extended)[0].level == 1 and PotionCatalog.effects(extended)[0].duration == 480,"redstone replaces potency with eight-minute duration")
	var splash: int = PotionCatalog.brew(extended,Nodes.GUNPOWDER)
	var lingering: int = PotionCatalog.brew(splash,VillageContent.DRAGON_BREATH)
	suite.check(PotionCatalog.ITEMS[lingering].form == "lingering" and PotionCatalog.effects(lingering)[0].duration == 120,"splash and lingering brewing retain extended potion strength")
	suite.check(PotionCatalog.brew(speed,Nodes.DIRT) == 0 and PotionCatalog.brew(extended,Nodes.REDSTONE_WIRE) == 0,"invalid and redundant brews do nothing")
	var station: Dictionary = VoxelWorld._new_station("brewing",5)
	station.slots[0] = {"id":VillageContent.NETHER_WART_ITEM,"count":2,"wear":0}
	station.slots[1] = {"id":Nodes.BLAZE_POWDER,"count":1,"wear":0}
	for i in range(2,5): station.slots[i] = {"id":VillageContent.WATER_BOTTLE,"count":1,"wear":0}
	suite.check(not Brewing.step(station,9) and station.slots[2].id == VillageContent.WATER_BOTTLE,"brewing waits ten active seconds")
	suite.check(Brewing.step(station,1) and station.slots[2].id == awkward and station.slots[4].id == awkward and station.slots[0].count == 1 and station.fuel_batches == 19,"one ingredient brews three bottles using one of twenty fuel batches")
	station.slots[0] = {"id":Nodes.SUGAR,"count":1,"wear":0}
	Brewing.step(station,5)
	station.slots[0] = {"id":Nodes.BLAZE_POWDER,"count":1,"wear":0}
	Brewing.step(station,5)
	suite.check(station.slots[2].id == awkward and station.progress == 5,"changing ingredients resets brewing progress")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(station))
	suite.check(Brewing.step(restored,5) and restored.slots[2].id == VillageContent.STRENGTH_POTION,"saved brewing progress resumes without consuming extra ingredient or fuel")
	var pouch: Dictionary = {"id":Pouches.SINGLE+6,"count":1,"wear":0}
	Pouches.contents(pouch)[3] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":{"title":"Cargo","text":"Do not lose me"}}
	Pouches.contents(pouch)[26] = {"id":Nodes.DIAMOND,"count":64,"wear":0}
	inv.slots[0] = pouch.duplicate(true)
	inv.add_item(Pouches.SINGLE+6)
	var upgrade: int = inv.recipe_index(Pouches.DOUBLE+6)
	suite.check(inv.fill_grid(upgrade,"table"),"a filled pouch can be placed into its upgrade recipe")
	suite.check(inv.craft_grid_to_inventory("table"),"two level-one pouches combine into level two")
	var upgraded: Dictionary = {}
	for slot in inv.slots:
		if slot.id == Pouches.DOUBLE+6: upgraded = slot
	suite.check(not upgraded.is_empty() and Pouches.contents(upgraded).size() == 54 and upgraded.data.contents[3].data.text == "Do not lose me" and upgraded.data.contents[26].count == 64,"upgrading preserves every item and book metadata")
	inv.grid[0] = upgraded.duplicate(true); upgraded.clear(); upgraded.merge({"id":0,"count":0,"wear":0})
	inv.grid[1] = {"id":VillageContent.DYE_BLUE,"count":1,"wear":0}
	var dyed: Dictionary = inv.take_grid_result("hand")
	suite.check(dyed.id == Pouches.DOUBLE+9 and dyed.data.contents[3].data.title == "Cargo" and inv.grid[0].id == 0,"dye changes pouch color and preserves contents while consuming the original")
	var saved_pouch: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(dyed)))
	suite.check(saved_pouch == dyed,"pouch contents and metadata survive JSON save and load")
	var invalid: Dictionary = {"id":Pouches.SINGLE,"count":1,"wear":0,"data":{"contents":[dyed]}}
	suite.check(Inventory.clean_slot(invalid).data.contents[0].id == 0,"nested pouches are rejected when loading")
	for color in 16:
		inv = Inventory.new(); var recipe: Dictionary = inv.recipes[inv.recipe_index(Pouches.SINGLE+color)]
		for id in recipe.ingredients: inv.add_item(id,recipe.ingredients[id])
		suite.check(inv.craft(inv.recipe_index(Pouches.SINGLE+color),"table") and inv.count_item(Pouches.SINGLE+color) == 1,"pouch crafting uses wool color %d"%color)
	suite.check(Enchantments.DATA.size() == 41,"all source enchantments plus Aqua Affinity and Sweeping Edge are registered")
	var sword: int = Nodes.TOOLS+18
	var clean: Dictionary = Inventory.clean_slot({"id":sword,"count":1,"wear":7,"data":{"enchantments":{"Sharpness":5,"Smite":5,"Lure":3,"Unbreaking":99}}})
	suite.check(Inventory.enchantment(clean,"Sharpness") == 5 and Inventory.enchantment(clean,"Unbreaking") == 3 and Inventory.enchantment(clean,"Smite") == 0 and Inventory.enchantment(clean,"Lure") == 0,"enchantment loading keeps source limits and rejects conflicts or wrong equipment")
	suite.check(Enchantments.combine(sword,{"Sharpness":4},{"Sharpness":4}).Sharpness == 5,"anvil combines matching level IV enchantments into level V")
	suite.check(not Enchantments.accepts(Nodes.BOW,"Mending",true) and Enchantments.accepts(Nodes.BOW,"Mending"),"treasure enchantments apply through books instead of the enchanting table")
	game.gamemode = "survival"; game.player.health = 20
	PotionEffects.apply_item(game.player,strong)
	suite.check(PotionEffects.level(game.player,"swiftness") == 2 and is_equal_approx(PotionEffects.speed(game.player),1.4),"level II swiftness actually changes player speed")
	var saved_effects: Dictionary = game.survival.effect_snapshot()
	PotionEffects.clear(game.player); game.survival.restore_effects(saved_effects)
	suite.check(PotionEffects.level(game.player,"swiftness") == 2,"saving and loading keeps potion potency")
	PotionEffects.apply(game.player,"poison",10,1); PotionEffects.update(game.player,1.25)
	suite.check(game.player.health == 19,"poison uses the source damage interval")
	game.player.health = 1; PotionEffects.update(game.player,1.25)
	suite.check(game.player.health == 1,"poison cannot kill")
	PotionEffects.clear(game.player)
	suite.check(game.survival.effects.is_empty() and PotionEffects.level(game.player,"swiftness") == 0,"milk-style clearing removes durations and strengths")
	game.player.health = 20; game.gamemode = "creative"

	# Storage UI prevents moving its open pouch or nesting another pouch.
	game.inventory = Inventory.new(); game.inventory.slots[0] = dyed.duplicate(true)
	game.inventory.slots[1] = {"id":Pouches.SINGLE,"count":1,"wear":0}
	game.survival.open_pouch(0)
	game.hud._slot_click(0,false,false)
	suite.check(game.hud.cursor.id == 0 and game.inventory.slots[0].id == dyed.id,"the open pouch cannot be lifted out of its owner slot")
	game.hud._slot_click(1,false,false); game.hud._slot_click(0,true,false)
	suite.check(game.hud.cursor.id == Pouches.SINGLE and game.hud.station_data.slots[0].id == 0,"pouch UI rejects nested storage")
	game.hud.return_cursor(); game.survival.open_pouch(0)
	game.hud.cursor = {"id":Nodes.BOW,"count":1,"wear":10,"data":{"enchantments":{"Power":5}}}
	game.hud._slot_click(7,true,false)
	suite.check(game.inventory.slots[0].data.contents[7].wear == 10 and game.hud.cursor.id == 0,"pouch UI writes exact item metadata into the portable item")
	game.resume(); game.pause()
	# Book combining must distinguish two separate identical book stacks.
	game.inventory = Inventory.new(); game.gamemode = "survival"; game.experience = 1000
	var book: Dictionary = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"wear":0,"data":{"enchantments":{"Sharpness":4}}}
	game.inventory.slots[0] = book.duplicate(true); game.inventory.slots[1] = book.duplicate(true)
	suite.check(game.survival.equipment_work(0,VillageContent.ANVIL) and Inventory.enchantment(game.inventory.slots[0],"Sharpness") == 5 and game.inventory.slots[1].id == 0,"two identical books combine without confusing the source and target")
	game.inventory.slots[0] = {"id":Nodes.BOW,"count":1,"wear":10,"data":{"enchantments":{"Mending":1,"Curse of Vanishing":1}}}
	suite.check(game.survival.equipment_work(0,VillageContent.GRINDSTONE) and Inventory.enchantment(game.inventory.slots[0],"Mending") == 0 and Inventory.enchantment(game.inventory.slots[0],"Curse of Vanishing") == 1,"grindstone removes ordinary enchantments while retaining curses")
	game.inventory.slots[0] = {"id":Nodes.BOW,"count":1,"wear":10,"data":{"enchantments":{"Mending":1}}}
	suite.check(Enchantments.mend(game,3) == 0 and game.inventory.slots[0].wear == 4,"mending repairs two durability per XP point")
	var helmet: int = Nodes.armor_id(1,0)
	game.player.armor_slots[0] = {"id":helmet,"count":1,"wear":0,"data":{"enchantments":{"Curse of Binding":1}}}
	game.inventory.slots[1] = {"id":Nodes.armor_id(3,0),"count":1,"wear":0}
	suite.check(not game.player.equip_armor(game.inventory.slots[1]) and game.player.armor_slots[0].id == helmet,"bound armor cannot be replaced by equipping another item")
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	var p := Vector3i(8,50,8)
	game.world.set_node(p,VillageContent.BREWING_STAND)
	game.open_inventory("brewing",p)
	suite.check(game.world.active and game.hud.station_ui.size() == 5 and game.hud.station_data.slots.size() == 5,"brewing screen exposes all five live slots and keeps the station running")
	game.hud.cursor = {"id":Nodes.DIRT,"count":1,"wear":0}; game.hud._slot_click(2,true,false)
	suite.check(game.hud.cursor.id == Nodes.DIRT and game.hud.station_data.slots[2].id == 0,"brewing bottle slots reject unrelated items")
	game.resume(); game.pause(); game.gamemode = "creative"
	for kind in ["silverfish","phantom","turtle","breeze","pillager"]:
		var mob: Creature = game.spawn_creature(kind,Vector3(p)+Vector3(3,1,0)); mob.set_physics_process(false)
		suite.check(mob.parts.size() >= 3 and mob.health > 0,"alchemy ingredient creature has a visible model: "+kind)
		mob.free()
	var cow: Creature = game.spawn_creature("cow",Vector3(p)+Vector3(4,1,0)); cow.set_physics_process(false)
	PotionEffects.apply(cow,"oozing",20); cow.hit(100)
	var slime_count: int = 0
	for mob in game.creatures.get_children():
		if mob.kind == "slime" and not mob.is_queued_for_deletion(): slime_count += 1
	suite.check(slime_count >= 2,"oozing causes a dying mob to release medium slimes")
	# Simulate distinct session identities to verify future multiplayer isolation.
	var player_a: String = PlayerIdentity.OFFLINE
	game.identity.session_id = player_a
	var home_a: Vector3 = game.player.position
	game.execute_command("/sethome")
	var player_b: String = "network-test-player"
	game.identity.session_id = player_b
	suite.check("No home" in game.execute_command("/home"),"another session identity cannot use the offline player's home")
	game.player.position += Vector3(3,0,0); var home_b: Vector3 = game.player.position
	game.execute_command("/sethome")
	suite.check(game.player_homes.size() >= 2 and VillageLife.vec(game.player_homes[player_a].position) == home_a and VillageLife.vec(game.player_homes[player_b].position) == home_b,"each session identity stores a separate home in the same world")
	game.identity.session_id = player_a
	var identity := PlayerIdentity.new(game.saves.root_path)
	suite.check(identity.session_id == "player" and not game.hud.has_method("show_profiles"),"offline identity is player with no player selector")
	game.execute_command("/home")
	while game.state == "loading": await suite.process_frame
	suite.check(game.player.position.distance_to(home_a) < 0.2,"home returns the current session player to its own position")
	var save: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	suite.check(save.homes.has(player_a) and save.homes.has(player_b),"world saves include each player's home")
	game.travel_dimension("nether")
	while game.state == "loading": await suite.process_frame
	game.execute_command("/home")
	while game.state == "loading": await suite.process_frame
	suite.check(game.dimension == "overworld" and game.player.position.distance_to(home_a) < 0.2,"home crosses dimensions without constructing an arrival portal")
	game.pause()

	# Combat behavior uses the same potion and enchantment definitions as inventory metadata.
	game.gamemode = "survival"; game.inventory = Inventory.new(); game.player.health = 20
	var origin := Vector3(8.5,51.0,8.5)
	var zombie: Creature = game.spawn_creature("zombie",origin); zombie.set_physics_process(false)
	PotionEffects.apply_item(zombie,VillageContent.HEALING_POTION)
	suite.check(zombie.health == 16,"healing potion damages undead by the source amount")
	game.inventory.slots[0] = {"id":sword,"count":1,"wear":0,"data":{"enchantments":{"Smite":5}}}
	suite.check(Enchantments.melee(game.player,zombie) >= 22,"Smite V increases melee damage against undead")
	zombie.free()
	var spider: Creature = game.spawn_creature("spider",origin); spider.set_physics_process(false)
	game.inventory.slots[0].data.enchantments = {"Bane of Arthropods":3}
	Enchantments.melee(game.player,spider)
	suite.check(PotionEffects.level(spider,"slowness") == 4,"Bane of Arthropods applies Slowness IV")
	spider.free()
	var bow: Dictionary = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Infinity":1,"Flame":1,"Punch":2}}}
	game.inventory.slots[0] = bow; game.inventory.add_item(Nodes.ARROW_ITEM,1)
	game.player.use()
	var infinite_shot: Arrow
	for entity in game.entities.get_children():
		if entity is Arrow and not entity.is_queued_for_deletion(): infinite_shot = entity
	suite.check(infinite_shot != null and not infinite_shot.recoverable and infinite_shot.flame and infinite_shot.punch == 2 and game.inventory.count_item(Nodes.ARROW_ITEM) == 1,"Infinity keeps its arrow while Flame and Punch reach the fired projectile")
	if infinite_shot != null: infinite_shot.free()
	game.inventory.slots[0] = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"enchantments":{"Quick Charge":3,"Multishot":1}}}
	game.survival.fire_crossbow()
	suite.check(is_equal_approx(game.inventory.slots[0].data.charge,0.5),"Quick Charge III reduces crossbow loading to half a second")
	game.inventory.slots[0].data.charge = 0
	var arrows_before: int = 0
	for entity in game.entities.get_children():
		if entity is Arrow: arrows_before += 1
	game.survival.fire_crossbow()
	var arrows_after: int = 0; var recoverable: int = 0
	for entity in game.entities.get_children():
		if entity is Arrow:
			arrows_after += 1
			if entity.recoverable: recoverable += 1
	suite.check(arrows_after-arrows_before == 3 and recoverable == 1,"Multishot fires three arrows with only one recoverable copy")
	for entity in game.entities.get_children():
		if entity is Arrow: entity.free()
	var victim: Creature = game.spawn_creature("cow",origin); victim.set_physics_process(false)
	var bottle := PotionProjectile.new(); bottle.game = game; bottle.item_id = PotionCatalog.find("poison","splash","strong"); bottle.position = origin; game.entities.add_child(bottle); bottle.set_physics_process(false)
	bottle.impact(victim)
	suite.check(PotionEffects.level(victim,"poison") == 2,"splash impact applies the selected potion's potency")
	PotionEffects.clear(victim)
	var cloud := PotionProjectile.new(); cloud.game = game; cloud.item_id = PotionCatalog.find("slowness","lingering"); cloud.position = origin; game.entities.add_child(cloud); cloud.set_physics_process(false); cloud.impact()
	game.state = "playing"; cloud._physics_process(0.6); game.state = "paused"
	suite.check(PotionEffects.level(victim,"slowness") == 1 and cloud.radius < 3,"lingering clouds affect nearby mobs and shrink on use")
	cloud.free(); victim.free()
	var helmet_slot: Dictionary = {"id":helmet,"count":1,"wear":0,"data":{"enchantments":{"Projectile Protection":4}}}
	game.player.armor_slots[0] = helmet_slot
	suite.check(Enchantments.protection(game.player,"projectile") < Enchantments.protection(game.player,"fire"),"specialist protection reduces its matching damage category")
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.gamemode = "creative"

	# Save and reload a linked resident, linked animal, and loaded colored pouch together.
	var linked_cow: Creature = game.spawn_creature("cow",game.player.position+Vector3(3,0,0)); linked_cow.set_physics_process(false)
	var linked_villager: Creature = game.spawn_creature("villager",game.player.position+Vector3(-3,0,0)); linked_villager.set_physics_process(false)
	var resident_key: String = linked_villager.person_key
	game.leads.attach(linked_cow,false); game.leads.attach(linked_villager,false)
	PotionEffects.apply(linked_cow,"swiftness",80,2)
	game.inventory.slots[0] = dyed.duplicate(true)
	game.save_game("user://alchemy_reload.json")
	var whole_save: Dictionary = game.read_save("user://alchemy_reload.json")
	game.load_world_data(whole_save)
	while game.state == "loading": await suite.process_frame
	game.pause()
	var linked_residents: int = 0; var restored_cow: Creature
	for link in game.leads.leads:
		if link.mob.kind == "villager" and link.mob.person_key == resident_key: linked_residents += 1
		if link.mob.kind == "cow": restored_cow = link.mob
	suite.check(linked_residents == 1 and game.leads.leads.size() == 2,"real world reload restores animal and resident leads exactly once")
	suite.check(restored_cow != null and PotionEffects.level(restored_cow,"swiftness") == 2,"linked animal potion strength survives reload")
	suite.check(game.inventory.slots[0] == dyed,"real world reload restores a dyed pouch with its exact contents")
	for path in ["user://alchemy_reload.json","user://alchemy_reload.json.bak","user://alchemy_reload.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

	inv = Inventory.new(); inv.add_item(VillageContent.WOOL_WHITE,1)
	suite.check(inv.count_item(Nodes.WOOL) == 1 and Inventory.clean_slot({"id":VillageContent.WOOL_WHITE,"count":1,"wear":0}).id == Nodes.WOOL,"legacy and colored white wool share one usable inventory identity")
	inv.grid[0] = {"id":Nodes.WOOL,"count":1,"wear":0}; inv.grid[1] = {"id":Nodes.WOOL,"count":1,"wear":0}
	var white_recipe: int = inv.matching_recipe("hand")
	suite.check(white_recipe >= 0 and inv.recipes[white_recipe].id == VillageContent.CARPET_WHITE,"white wool from sheep crafts the new white carpet")
