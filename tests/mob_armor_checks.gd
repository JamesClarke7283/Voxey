extends RefCounted

static func blank(mob: Creature) -> void:
	mob.mob_armor = MobArmor.empty_slots(); mob.mob_armor_drops = [0.0,0.0,0.0,0.0]; MobArmor.refresh(mob)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_light: float = game.daylight; var old_mode: String = game.gamemode; var old_hp: float = game.player.health
	var old_armor: Array = game.player.armor_slots.duplicate(true)
	for child in game.creatures.get_children(): child.free()
	for child in game.drops.get_children(): child.free()
	game.world.adventure_state["farm_animals"] = {}
	var at := Vector3(8.5,1300,8.5)
	for x in range(3,15):
		for z in range(3,15):
			for y in range(1299,1305): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1299 else Nodes.AIR)
	game.player.position = at+Vector3(5,0,0); game.player.health = 20; game.player.armor_slots = MobArmor.empty_slots(); game.gamemode = "survival"; game.daylight = 0; game.state = "playing"
	var zombie: Creature = game.spawn_creature("zombie",at); zombie.set_physics_process(false); blank(zombie)
	t.check(zombie.mob_armor_ready and zombie.mob_armor.size() == 4,"an armor-capable mob owns four equipment slots")
	for i in 4:
		var id: int = MobArmor.COPPER_HELMET+i
		var recipe: Dictionary = game.inventory.recipes[game.inventory.recipe_index(id)]
		t.check(recipe.id == id and recipe.ingredients.has(Nodes.COPPER) and Nodes.armor_points(id) == [2,4,3,1][i] and Enchanting.ability(id) == 8,"copper armor piece %d has its source recipe, defense and enchantability"%i)
		t.check(Nodes.smelt_result(id) == RawOres.COPPER_NUGGET and Anvils.repair_material(id) == Nodes.COPPER,"copper armor piece %d can be smelted and repaired with source materials"%i)
	zombie.mob_armor[1] = {"id":Nodes.armor_id(1,1),"count":1,"wear":0}
	zombie.mob_armor_drops[1] = 0.085; MobArmor.refresh(zombie)
	var before: float = zombie.health
	zombie.hit(8,game.player.position,"arrow",0,game.player)
	t.check(zombie.health < before and zombie.health > before-8 and Durability.normalized(zombie.mob_armor[1]) > 0,"a real arrow hit consumes armor durability and reduces mob damage")
	zombie.health = 20; Durability.set_normalized(zombie.mob_armor[1],65534)
	zombie.hit(8,game.player.position,"arrow",0,game.player)
	t.check(zombie.mob_armor[1].id == 0 and zombie.health > 12,"a piece protects against the hit that breaks it")
	blank(zombie); zombie.health = 20
	zombie.mob_armor[1] = {"id":Nodes.armor_id(1,1),"count":1,"wear":0,"data":{"enchantments":{"Fire Protection":4}}}
	PotionEffects.apply(zombie,"burning",3); PotionEffects.update(zombie,1)
	t.check(is_equal_approx(zombie.health,19.32) and Durability.normalized(zombie.mob_armor[1]) == 0,"ongoing fire uses fire protection without physical armor wear")
	PotionEffects.clear(zombie); zombie.health = 20
	zombie.mob_armor[1].data.enchantments = {"Protection":4}
	PotionEffects.apply(zombie,"withering",3); PotionEffects.update(zombie,2)
	t.check(is_equal_approx(zombie.health,19.16) and Durability.normalized(zombie.mob_armor[1]) == 0,"withering uses magic protection without physical armor wear")
	PotionEffects.clear(zombie)
	blank(zombie); zombie.health = 20
	zombie.mob_armor[1] = {"id":Nodes.armor_id(1,1),"count":1,"wear":0,"data":{"enchantments":{"Thorns":3}}}
	var chosen_seed: int = 1
	for seed_value in 200:
		var probe := RandomNumberGenerator.new(); probe.seed = seed_value
		if probe.randf() < 0.45: chosen_seed = seed_value; break
	MobArmor.rng_for(game.world).native.seed = chosen_seed; game.player.damage_cooldown = 0
	zombie.hit(1,game.player.position,"player_melee",0,game.player)
	t.check(game.player.health < 20 and Durability.normalized(zombie.mob_armor[1]) > 0,"a mob's Thorns retaliates against the actual attacker")
	blank(zombie); zombie.mob_armor_pickup = true
	var helm: Dictionary = {"id":MobArmor.COPPER_HELMET,"count":1,"wear":12,"data":{"custom_name":"Recovered copper","enchantments":{"Protection":2}}}
	var dropped: ItemDrop = game.spawn_drop(at+Vector3(1,0,0),helm.id,1,helm.wear,helm.data); dropped.set_physics_process(false); dropped.age = 0.99
	MobArmor.pickup(zombie)
	t.check(zombie.mob_armor[0].id == 0,"mob pickup waits until the dropped item is a second old")
	dropped.age = 1; MobArmor.pickup(zombie)
	t.check(zombie.mob_armor[0].id == helm.id and zombie.mob_armor[0].data.custom_name == "Recovered copper" and dropped.is_queued_for_deletion() and zombie.mob_armor_drops[0] == 2 and zombie.has_meta("persistent"),"pickup preserves armor metadata and makes the wearer persistent")
	zombie.mob_armor[0].data.enchantments["Curse of Binding"] = 1
	t.check(not MobArmor.equip(zombie,{"id":Nodes.armor_id(3,0),"count":1,"wear":0}),"Binding prevents replacing a mob's worn helmet")
	zombie.mob_armor[0].data.enchantments.erase("Curse of Binding")
	var saved_wear: int = Durability.normalized(zombie.mob_armor[0])
	var recovered: Dictionary = MobArmor.dropped(zombie.mob_armor[0],2,0,EnchantRolls.new(1),0)
	t.check(Durability.normalized(recovered) == saved_wear and recovered.data.custom_name == "Recovered copper","collected armor drops without a second durability randomization")
	var dispenser_at := Vector3i(7,1300,8)
	var boots: Dictionary = {"id":Nodes.armor_id(1,3),"count":1,"wear":0}
	var outcome: Dictionary = Dispensers.equip_action(game,dispenser_at,Vector3i.RIGHT,boots)
	t.check(outcome.get("applied",false) and zombie.mob_armor[3].id == boots.id and zombie.mob_armor_drops[3] == 2,"a dispenser equips an empty mob armor slot")
	t.check(not Dispensers.equip_action(game,dispenser_at,Vector3i.RIGHT,boots).get("applied",false),"a dispenser does not replace occupied mob armor")
	game.player.position = zombie.position
	var leggings: Dictionary = {"id":MobArmor.COPPER_HELMET+2,"count":1,"wear":0}
	Dispensers.equip_action(game,dispenser_at,Vector3i.RIGHT,leggings.duplicate(true))
	t.check(zombie.mob_armor[2].id == leggings.id and game.player.armor_slots[2].id == 0,"dispenser entity equipment takes priority over the nearby player")
	Dispensers.equip_action(game,dispenser_at,Vector3i.RIGHT,leggings.duplicate(true))
	t.check(game.player.armor_slots[2].id == leggings.id,"an occupied mob slot allows the empty player slot to receive armor")
	t.check(Dispensers.equip_action(game,dispenser_at,Vector3i.RIGHT,leggings.duplicate(true)).is_empty(),"a dispenser preserves armor when both recipient slots are occupied")
	game.player.position = at+Vector3(5,0,0)
	t.check(not zombie.mob_armor_models.is_empty(),"equipped armor builds visible body and joint pieces")
	# The reference's sunlight roll is one in two; breaking a helmet does not
	# ignite in the same callback, but the next successful empty-head roll does.
	blank(zombie); zombie.mob_armor[0] = {"id":MobArmor.COPPER_HELMET,"count":1,"wear":0}; Durability.set_normalized(zombie.mob_armor[0],65534)
	game.daylight = 1; PotionEffects.clear(zombie)
	for seed_value in 1000:
		var rolls := RandomNumberGenerator.new(); rolls.seed = seed_value
		if rolls.randi_range(1,2) == 1 and rolls.randi_range(1,2) == 1: chosen_seed = seed_value; break
	MobArmor.rng_for(game.world).native.seed = chosen_seed; zombie.weather_step(0.05)
	t.check(zombie.mob_armor[0].id == 0 and PotionEffects.level(zombie,"burning") == 0,"sunlight can break headgear before the mob starts burning")
	MobArmor.rng_for(game.world).native.seed = chosen_seed; zombie.weather_step(0.05)
	t.check(PotionEffects.level(zombie,"burning") > 0,"an uncovered mob ignites on the next successful sunlight check")
	PotionEffects.clear(zombie); game.world.set_node(Vector3i(8,1303,8),Nodes.STONE)
	MobArmor.rng_for(game.world).native.seed = chosen_seed; zombie.weather_step(0.05)
	t.check(PotionEffects.level(zombie,"burning") == 0,"an overhead roof prevents sunlight ignition")
	game.world.set_node(Vector3i(8,1303,8),Nodes.AIR); game.daylight = 0
	blank(zombie); zombie.mob_armor[0] = helm.duplicate(true); zombie.mob_armor_drops[0] = 2
	zombie.mob_armor_pickup = true; zombie.health = 20; MobArmor.refresh(zombie)
	var converted: Creature = UndeadVariants.replace(game,zombie,"drowned"); converted.set_physics_process(false)
	t.check(converted.mob_armor[0].data.custom_name == "Recovered copper" and converted.mob_armor_drops[0] == 2,"undead conversion retains armor and its collected-item drop rule")
	var identity: String = converted.farm_id
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var stop_spawn: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(stop_spawn)
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(stop_spawn)
	var restored: Creature
	for child in game.creatures.get_children():
		if child.farm_id == identity: restored = child
	t.check(restored != null and restored.mob_armor[0].data.custom_name == "Recovered copper" and restored.mob_armor_drops[0] == 2 and restored.mob_armor_pickup,"an actual world reload retains equipped armor, wear, metadata and pickup state")
	if restored != null:
		Trials.bind(game.world,Vector3i.ZERO,"armor-fixture",Trials.mob_record(restored))
		var trial: Creature = Trials.runtime(game.world).mobs["armor-fixture"]; trial.set_physics_process(false)
		t.check(trial.mob_armor[0].id == helm.id and trial.mob_armor[0].data.custom_name == "Recovered copper","trial snapshots restore real armor slots")
		Trials.forget(game.world,"armor-fixture"); trial.queue_free()
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_pos; game.daylight = old_light; game.gamemode = old_mode; game.player.health = old_hp; game.player.armor_slots = old_armor
