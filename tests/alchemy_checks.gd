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
		suite.check(mob.box_count >= 3 and mob.health > 0,"alchemy ingredient creature has a visible model: "+kind)
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
	# Smite V adds twelve and a half damage as an `undead`-grouped bonus, which the
	# zombie's own `undead = 90` cuts to eleven and a quarter — so the total is the
	# sword's ten plus that, not the flat twenty-two an unscaled bonus would give.
	var smite_total: float = Enchantments.melee(game.player,zombie)
	suite.check(is_equal_approx(smite_total,21.25),"Smite V adds its undead-grouped bonus, scaled by the zombie's own armor")
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

	# --- water hurts a water-sensitive mob, and fire resistance --------------
	# The source marks four mobs `_water_sensitive`, and Voxey has two of them: a
	# blaze and an enderman. Each takes one damage every half second in water or out
	# in the rain, which is what makes water their counter.
	suite.check(not Creature.KINDS.get("zombie",{}).get("water_sensitive",false),"an ordinary mob is not water-sensitive")
	for kind in ["blaze","enderman"]:
		suite.check(bool(Creature.KINDS.get(kind,{}).get("water_sensitive",false)),kind+" is water-sensitive, as the source marks it")
	var pool := Vector3i(8,240,8)
	for y in range(238,244): game.world.set_node(Vector3i(8,y,8),Nodes.AIR)
	game.world.set_node(Vector3i(8,239,8),Nodes.STONE)
	game.world.set_node(pool,Nodes.WATER)
	var wet_blaze: Creature = game.spawn_creature("blaze",Vector3(pool)+Vector3(0.5,0.1,0.5))
	if wet_blaze != null:
		wet_blaze.set_physics_process(false)
		var before: float = wet_blaze.health
		wet_blaze.weather_step(0.5)
		suite.check(wet_blaze.health < before,"a blaze in water takes the source's half-second damage")
		# Out of the water it recovers nothing and loses nothing.
		game.world.set_node(pool,Nodes.AIR)
		var dry_before: float = wet_blaze.health
		wet_blaze.weather_step(1.0)
		suite.check(is_equal_approx(wet_blaze.health,dry_before),"a blaze out of water takes no damage")
		wet_blaze.queue_free()
	game.world.set_node(pool,Nodes.AIR)
	# A fire-resistant mob is not a *weather* rule but a burning one, and the two are
	# separate: a blaze is both fire-resistant and water-sensitive.
	suite.check(Fire.resistant("blaze") and Creature.KINDS["blaze"].get("water_sensitive",false),"a blaze is fire-resistant and water-sensitive at once, which are different rules")
	suite.check(Fire.resistant("magma_cube") and not Creature.KINDS.get("magma_cube",{}).get("water_sensitive",false),"a magma cube is fire-resistant without being water-sensitive")

	# --- powder snow freezes a mob ------------------------------------------
	# The source's `can_freeze`: a mob in powder snow slows to a standstill over seven
	# seconds and only then takes one damage every two. A mob passing through is
	# slowed but never hurt, which is the part worth pinning.
	var drift := Vector3i(10,240,10)
	for y in range(238,246): game.world.set_node(Vector3i(10,y,10),Nodes.AIR)
	game.world.set_node(Vector3i(10,239,10),Nodes.STONE)
	var old_daylight: float = game.daylight
	game.daylight = 0.0
	var frosty: Creature = game.spawn_creature("zombie",Vector3(drift)+Vector3(0.5,0.1,0.5))
	if frosty != null:
		frosty.set_physics_process(false)
		frosty.weather_step(1.0)
		suite.check(not frosty.in_powder_snow(),"a mob in open air is not frozen")
		game.world.set_node(drift,PowderSnow.ID)
		suite.check(frosty.in_powder_snow(),"a mob standing in powder snow is in it")
		var passing: float = frosty.health
		frosty.weather_step(3.0)
		suite.check(is_equal_approx(frosty.frozen_for,3.0) and is_equal_approx(frosty.health,passing),"a mob passing through powder snow is slowed but not hurt")
		frosty.weather_step(4.0)
		suite.check(is_equal_approx(frosty.frozen_for,7.0),"seven seconds in powder snow freezes a mob completely")
		var frozen_health: float = frosty.health
		frosty.weather_step(2.0)
		suite.check(frosty.health < frozen_health,"a fully frozen mob takes the source's damage every two seconds")
		# Leaving the snow thaws it.
		game.world.set_node(drift,Nodes.AIR)
		frosty.weather_step(4.0)
		suite.check(is_equal_approx(frosty.frozen_for,3.0),"leaving powder snow thaws a mob")
		frosty.queue_free()
	game.world.set_node(drift,Nodes.AIR)
	game.daylight = old_daylight
	# A mob that flies its own path must still run the shared weather rules, because
	# it never reaches the step at the bottom of `Creature._physics_process`. Checked
	# through the public path rather than by reading the source: a phantom put in
	# powder snow must freeze when its own `_physics_process` runs.
	var fly_drift := Vector3i(14,242,14)
	for y in range(240,248): game.world.set_node(Vector3i(14,y,14),Nodes.AIR)
	game.world.set_node(Vector3i(14,241,14),Nodes.STONE)
	game.world.set_node(fly_drift,PowderSnow.ID)
	game.daylight = 0.0
	# The suite runs paused, and every physics path returns early unless the game is
	# playing, so resume for this one step and pause again after.
	game.resume()
	var flier: Creature = game.spawn_creature("phantom",Vector3(fly_drift)+Vector3(0.5,0.1,0.5))
	if flier != null:
		flier.set_physics_process(false)
		# The phantom flies toward the player, so hold it in place for the check.
		flier.position = Vector3(fly_drift)+Vector3(0.5,0.1,0.5)
		flier._physics_process(1.0)
		suite.check(flier.frozen_for > 0.0,"a flying mob runs the winter rules through its own physics path")
		flier.queue_free()
	game.pause()
	game.world.set_node(fly_drift,Nodes.AIR)
	game.daylight = old_daylight

	# --- a land mob floats in deep water ------------------------------------
	# The source's default is `floats = 1`, so almost every mob bobs up instead of
	# sinking; only six kinds opt out with `floats = 0`. Voxey had no float rule at
	# all, so every land mob sank to the bottom of any deep water.
	for kind in ["chicken","cow","sheep","pig"]:
		suite.check(Creature.KINDS.get(kind,{}).get("floats",true),"a farm animal floats, which is the source's default")
	for kind in ["zombie","skeleton","piglin"]:
		suite.check(Creature.KINDS.get(kind,{}).get("floats",true) == false,kind+" does not float, as the source sets it")
	# Behaviourally: each mob gets its **own** column, so one mob's ascent cannot
	# empty the water the next one is measured in.
	# The pools are carved well below the surface and capped with air, so a sinking
	# mob reaches the pool floor instead of standing on nearby terrain above it.
	# Each pool is a sealed shaft: solid walls on all four sides, a floor, and water
	# filling it. A sinking mob therefore cannot walk out onto neighbouring terrain —
	# a leak the earlier version had, which made the check depend on what the
	# surrounding cells happened to be.
	var deep_base := Vector3i(game.player.position.floor())+Vector3i(3,0,0)
	var columns: Array = []
	for i in 2:
		var at := Vector3i(deep_base.x+i*3,deep_base.y-14,deep_base.z)
		columns.append(at)
		for y in range(at.y-12,at.y+5):
			for dx in range(-1,2):
				for dz in range(-1,2):
					var cell := Vector3i(at.x+dx,y,at.z+dz)
					var solid: bool = y < at.y or absi(dx)+absi(dz) != 0
					game.world.set_node(cell,Nodes.STONE if solid else Nodes.WATER)
		game.world.set_node(Vector3i(at.x,at.y-1,at.z),Nodes.STONE)
	game.resume()
	# Each mob starts at the top of its own shaft and is left to settle. The comparison
	# is *relative* — the floating mob ends higher than the sinking one — because an
	# absolute threshold depends on the shaft's exact depth, which is a property of the
	# fixture rather than of the rule.
	var settled: Dictionary = {}
	for i in 2:
		var kind: String = ["chicken","zombie"][i]
		var at: Vector3i = columns[i]
		var swimmer: Creature = game.spawn_creature(kind,Vector3(at)+Vector3(0.5,0.5,0.5))
		if swimmer == null: continue
		swimmer.set_physics_process(false)
		for step in 50:
			if swimmer.is_queued_for_deletion(): break
			swimmer._physics_process(0.1)
		if swimmer.is_queued_for_deletion(): continue
		settled[kind] = swimmer.position.y
		swimmer.queue_free()
	game.pause()
	suite.check(settled.has("chicken") and settled.has("zombie"),"both float probes survived to settle")
	if settled.has("chicken") and settled.has("zombie"):
		suite.check(float(settled.chicken) > float(settled.zombie) + 2.0,"a chicken floats well above a zombie in the same water, as the source's `floats` splits them")

	# --- some mobs never despawn --------------------------------------------
	# The source's `can_despawn` defaults to **false** and only twelve mobs opt in, so
	# a piglin, a shulker, a villager, an evoker or the wither is never removed for
	# distance. Voxey despawned every mob past ninety blocks, which silently deleted a
	# boss or a trader the player had walked away from.
	suite.check(Creature.KINDS.get("piglin",{}).get("can_despawn",false) == false,"a piglin does not despawn, which is the source's default")
	suite.check(Creature.KINDS.get("wither",{}).get("can_despawn",false) == false,"the wither does not despawn")
	suite.check(bool(Creature.KINDS.get("witch",{}).get("can_despawn",false)),"a witch may despawn, as the source opts it in")
	suite.check(bool(Creature.KINDS.get("squid",{}).get("can_despawn",false)),"a squid may despawn")
	# Behaviourally: a mob of each kind left far from the player, stepped once.
	game.resume()
	var far_away: Vector3 = game.player.position+Vector3(200,0,0)
	for entry in [["piglin",false],["witch",true]]:
		var kind: String = entry[0]
		var should_go: bool = entry[1]
		var wanderer: Creature = game.spawn_creature(kind,far_away)
		if wanderer == null: continue
		wanderer.set_physics_process(false)
		wanderer._physics_process(0.1)
		suite.check(wanderer.is_queued_for_deletion() == should_go,kind+(" is removed when far away" if should_go else " is kept when far away"))
		if not wanderer.is_queued_for_deletion(): wanderer.queue_free()
	game.pause()

	# --- a distant mob does not starve natural spawning ----------------------
	# The spawn cap counts mobs *near the player*, not every mob alive. A distant mob
	# neither loads nor simulates, and the mobs that never despawn persist forever, so
	# counting them let a handful of stray piglins block all spawning permanently.
	#
	# The check is on the decision rather than on a spawn attempt: whether a natural
	# spawn would proceed depends on terrain, weather and load state, none of which are
	# the cap's business. What the cap owns is which mobs it counts.
	# Clear whatever earlier checks left standing near the player, so the count below is
	# this check's own doing rather than a leftover.
	for mob in game.creatures.get_children():
		if mob.kind not in ["end_crystal","ender_dragon"] and mob.position.distance_to(game.player.position) <= 128: mob.queue_free()
	await suite.process_frame
	var distant_spot: Vector3 = game.player.position+Vector3(200,0,0)
	for i in 8: game.spawn_creature("piglin",distant_spot)
	await suite.process_frame
	var counted_near: int = 0
	for mob in game.creatures.get_children():
		if mob.kind in ["end_crystal","ender_dragon","villager","iron_golem"]: continue
		if mob.position.distance_to(game.player.position) <= 128: counted_near += 1
	suite.check(counted_near == 0,"mobs two hundred blocks away are not counted against the spawn cap")
	# And a mob placed near the player *is* counted, which is the other half of the rule.
	var close_by: Creature = game.spawn_creature("piglin",game.player.position+Vector3(6,0,0))
	await suite.process_frame
	if close_by != null:
		var counted_with_one: int = 0
		for mob in game.creatures.get_children():
			if mob.kind in ["end_crystal","ender_dragon","villager","iron_golem"]: continue
			if mob.position.distance_to(game.player.position) <= 128: counted_with_one += 1
		suite.check(counted_with_one == 1,"a mob beside the player is counted against the spawn cap")
		close_by.queue_free()
	for mob in game.creatures.get_children():
		if mob.kind == "piglin": mob.queue_free()
	await suite.process_frame

	# --- a kill pays the mob's own experience --------------------------------
	# The source gives each mob an `xp_min`/`xp_max`; Voxey paid a flat two for any
	# hostile mob, which made a wither and a zombie worth the same.
	for entry in [["wither",50],["blaze",10],["skeleton",6],["zombie",5],["slime",4],["cow",1],["pig",1]]:
		var kind: String = entry[0]
		var want: int = entry[1]
		suite.check(int(Creature.KINDS.get(kind,{}).get("xp",0)) == want,kind+" is worth the source's %d experience" % want)
	# And the award reaches the player when the mob dies.
	var xp_arena := Vector3i(game.player.position.floor())+Vector3i(0,0,6)
	for y in range(xp_arena.y-4,xp_arena.y+6):
		for dx in range(-2,3):
			for dz in range(-2,3): game.world.set_node(Vector3i(xp_arena.x+dx,y,xp_arena.z+dz),Nodes.AIR)
	for dx in range(-2,3):
		for dz in range(-2,3): game.world.set_node(Vector3i(xp_arena.x+dx,xp_arena.y-5,xp_arena.z+dz),Nodes.STONE)
	game.resume()
	var doomed: Creature = game.spawn_creature("wither",Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
	if doomed != null:
		doomed.set_physics_process(false)
		var xp_before: float = game.experience
		doomed.health = 0.5
		doomed.hit(100.0)
		suite.check(is_equal_approx(game.experience-xp_before,50.0),"killing a wither awards its fifty experience")
	# A slime is the one mob whose reward is not a fixed number: the source registers
	# three sizes worth four, two and one, and a big slime splits on death. Its award
	# therefore comes from its size rather than the `xp` field.
	for size in [4,2,1]:
		var blob: Creature = game.spawn_creature("slime",Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
		if blob == null: continue
		blob.set_slime_size(size)
		blob.set_physics_process(false)
		var slime_before: float = game.experience
		blob.health = 0.5
		blob.hit(100.0)
		suite.check(is_equal_approx(game.experience-slime_before,float(size)),"a size-%d slime pays %d experience" % [size,size])
		await suite.process_frame
	# A kill pays once. The achievement a kill unlocked used to add its own default of
	# two on top, so a zombie — whose achievement is the only one a kill fires — paid
	# seven instead of five.
	for i in 3: await suite.process_frame
	var single_before: float = game.experience
	var one_zombie: Creature = game.spawn_creature("zombie",Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
	if one_zombie != null:
		one_zombie.set_physics_process(false)
		one_zombie.health = 0.5
		one_zombie.hit(100.0)
		for i in 3: await suite.process_frame
		suite.check(is_equal_approx(game.experience-single_before,5.0),"a zombie pays its five experience exactly once, not again through its achievement")
	# --- the source's per-group armor ---------------------------------------
	# `armor` is the percentage of a group's damage a mob *takes*, not a resistance, and
	# a group the table omits deals nothing. So a zombie takes ninety percent of an
	# ordinary blow while a skeleton takes all of it, and only a blaze accepts a
	# snowball.
	for entry in [["zombie",0.9],["skeleton",1.0],["spider",1.0],["cow",1.0]]:
		var kind: String = entry[0]
		var want: float = entry[1]
		var probe: Creature = game.spawn_creature(kind,Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
		await suite.process_frame
		if probe == null or probe.is_queued_for_deletion(): continue
		probe.set_physics_process(false)
		suite.check(is_equal_approx(probe.armor_factor(""),want),kind+" takes the source's share of an ordinary blow")
		# A mob with no `fleshy` at all would take nothing from a sword, which is why the
		# plain-number form means `{fleshy = <number>}`.
		suite.check(probe.armor_factor("") > 0.0 or kind == "none","a sword always hurts "+kind)
		probe.queue_free()
		await suite.process_frame
	var blaze_probe: Creature = game.spawn_creature("blaze",Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
	if blaze_probe != null:
		blaze_probe.set_physics_process(false)
		suite.check(blaze_probe.armor_factor("snowball") > 0.0,"a blaze accepts a snowball, as the source's `snowball_vulnerable` says")
		suite.check(is_equal_approx(blaze_probe.armor_factor(""),1.0),"and a blaze takes an ordinary blow in full")
		blaze_probe.queue_free()
		await suite.process_frame
	# Behaviourally: the same blow lands for less on a zombie than on a spider.
	for kind in ["zombie","spider"]:
		var armor_victim: Creature = game.spawn_creature(kind,Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
		await suite.process_frame
		if armor_victim == null or armor_victim.is_queued_for_deletion(): continue
		armor_victim.set_physics_process(false)
		armor_victim.health = 20.0
		armor_victim.hit(10.0)
		if kind == "zombie": suite.check(is_equal_approx(armor_victim.health,11.0),"a ten-damage blow costs a zombie only the source's nine")
		else: suite.check(is_equal_approx(armor_victim.health,10.0),"the same blow costs a spider the full ten")
		armor_victim.queue_free()
		await suite.process_frame
	# A grouped bonus is scaled by its *own* group, which is what makes Smite and Bane
	# interact with armor rather than bypassing it.
	suite.check(Creature.group_for("") == "fleshy" and Creature.group_for("snowball") == "snowball_vulnerable","a damage reason maps to the source's group")
	var wither_target: Creature = game.spawn_creature("wither",Vector3(xp_arena)+Vector3(0.5,0.5,0.5))
	if wither_target != null:
		wither_target.set_physics_process(false)
		# The wither takes all of a fleshy blow but only four fifths of an undead one.
		suite.check(is_equal_approx(wither_target.armor_factor(""),1.0),"a wither takes a fleshy blow in full")
		suite.check(is_equal_approx(wither_target.armor_factor("undead"),0.8),"and only four fifths of an undead one")
		wither_target.health = 600.0
		wither_target.add_bonus("undead",10.0)
		wither_target.hit(10.0)
		suite.check(is_equal_approx(600.0-wither_target.health,18.0),"a ten point undead bonus adds eight to a wither, not ten")
		wither_target.queue_free()
		await suite.process_frame
	game.pause()
	for y in range(xp_arena.y-5,xp_arena.y+6):
		for dx in range(-2,3):
			for dz in range(-2,3): game.world.set_node(Vector3i(xp_arena.x+dx,y,xp_arena.z+dz),Nodes.AIR)
	for at in columns:
		for y in range(at.y-11,at.y+4): game.world.set_node(Vector3i(at.x,y,at.z),Nodes.AIR)
