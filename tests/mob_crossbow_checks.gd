extends RefCounted

static func arrows(game: Node3D) -> Array:
	return game.entities.get_children().filter(func(node): return node is Arrow and not node.is_queued_for_deletion())

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_mode: String = game.gamemode; var old_hp: float = game.player.health
	for child in game.creatures.get_children(): child.free()
	for child in game.entities.get_children():
		if child is Arrow: child.free()
	var at := Vector3(8.5,900,8.5)
	for x in range(4,14):
		for z in range(-12,15):
			for y in range(899,904): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 899 else Nodes.AIR)
	game.player.position = at+Vector3(0,0,-14); game.player.health = 100; game.gamemode = "survival"; game.state = "playing"
	var mob: Creature = game.spawn_creature("pillager",at); mob.set_physics_process(false)
	t.check(mob.crossbow_weapon.id == VillageContent.CROSSBOW and mob.crossbow_model.mesh != null and mob.arms.size() == 2,"pillager spawns with a real equipped crossbow and two aiming arms")
	for i in 20: mob._physics_process(0.1)
	t.check(arrows(game).is_empty() and mob.crossbow_ai.phase in [1,2],"actual pillager AI charges and waits instead of firing immediately")
	t.check(mob.direction == Vector3.ZERO,"pillager holds position after a quarter second of clear sight within twenty blocks")
	for i in 22: mob._physics_process(0.1)
	t.check(arrows(game).size() >= 1,"actual pillager AI completes the charge-delay-fire cycle")
	var first: Arrow = arrows(game)[0]
	t.check(first.critical and not first.recoverable and first.shooter_id == mob.get_instance_id() and first.shooter_kind == "pillager" and first.damage == 2,"NPC crossbow shots carry source critical, base damage, provenance and pickup flags")
	t.check(first.velocity.length() > 28 and first.velocity.length() < 36,"NPC crossbow uses the source 32-speed shot with difficulty spread")
	for shot in arrows(game): shot.free()
	# Ready crossbows wait behind cover, then release only when sight returns.
	mob.position = at; mob.crossbow_ai = MobCrossbows.initial(true); mob.crossbow_ai.attacking = true; mob.crossbow_ai.phase = 3
	mob.crossbow_weapon.data.crossbow_loaded = true; mob.crossbow_target = game.player
	for y in range(900,904): game.world.set_node(Vector3i(8,y,2),Nodes.STONE)
	mob._physics_process(0.1)
	t.check(arrows(game).is_empty() and mob.crossbow_ai.phase == 3,"ready pillager waits for line of sight instead of shooting through a wall")
	for y in range(900,904): game.world.set_node(Vector3i(8,y,2),Nodes.AIR)
	mob._physics_process(0.1)
	t.check(arrows(game).size() == 1 and mob.crossbow_ai.phase == 0,"ready pillager discharges when the wall is removed")
	for shot in arrows(game): shot.free()
	# The same actor hunts villagers and golems while the player is in creative.
	game.gamemode = "creative"; game.player.position = at+Vector3(4,0,-14)
	var villager: Creature = game.spawn_creature("villager",at+Vector3(0,0,-10)); villager.set_physics_process(false)
	MobCrossbows.stop(mob); mob.position = at; mob.think = 10
	for i in 45: mob._physics_process(0.1)
	t.check(mob.crossbow_target == villager and not arrows(game).is_empty(),"pillager selects a villager independently of player survival mode")
	# Difficulty spread can legitimately miss. Use the centre sample to check
	# collision separately from the random AI shot above.
	for shot in arrows(game): shot.free()
	for shot in MobCrossbows.shoot(mob,villager.position,[0.5,0.5,0.5,0.5,0.5,0.5]):
		shot.set_physics_process(false)
		for j in 12:
			if shot.is_queued_for_deletion(): break
			shot._physics_process(0.05)
	t.check(villager.health < villager.info().health,"its actual arrow can damage the chosen villager")
	for shot in arrows(game): shot.free()
	villager.free()
	game.gamemode = "survival"; game.player.position = at+Vector3(0,0,-14)
	# Buffs use source wave thresholds and preserve a directly applied Piercing.
	mob.crossbow_weapon.data.enchantments = {"Piercing":1}
	var rng := RandomNumberGenerator.new(); rng.seed = 193
	MobCrossbows.raid_buff(mob,6,5,rng,0)
	var clean: Dictionary = Inventory.clean_slot(mob.crossbow_weapon)
	t.check(Inventory.enchantment(clean,"Quick Charge") == 2 and Inventory.enchantment(clean,"Multishot") == 1 and Inventory.enchantment(clean,"Piercing") == 1,"raid equipment preserves the source's forced Multishot/Piercing combination through cleaning")
	var actual: Array = MobCrossbows.shoot(mob,game.player.position,[0.5,0.5,0.5,0.5,0.5,0.5])
	t.check(actual.size() == 3 and actual.all(func(shot): return shot.piercing == 1 and shot.critical and not shot.recoverable),"buffed pillager shoots three noncollectible piercing arrows")
	for shot in actual: shot.free()
	t.check(not MobCrossbows.drop_weapon(mob,rng,0.085).is_empty() and MobCrossbows.drop_weapon(mob,rng,0.085001).is_empty(),"crossbow drop chance includes its exact 8.5-percent boundary")
	mob.crossbow_weapon.data.crossbow_loaded = true
	var held_before: Dictionary = game.inventory.held().duplicate(true)
	game.inventory.slots[game.inventory.selected] = Inventory.clean_slot(MobCrossbows.drop_weapon(mob,rng,0))
	t.check(CrossbowUse.loaded_form(game.inventory.held()) and not CrossbowUse.loaded(game.inventory.held()),"a dropped NPC's loaded crossbow carries no free player ammunition")
	var shots_before: int = arrows(game).size()
	t.check(CrossbowUse.fire(game.player).is_empty() and not CrossbowUse.loaded_form(game.inventory.held()) and arrows(game).size() == shots_before,"the empty loaded NPC form dry-fires once without wear or projectile")
	game.inventory.slots[game.inventory.selected] = held_before; mob.crossbow_weapon.data.crossbow_loaded = false
	mob.crossbow_weapon.data.enchantments["Curse of Vanishing"] = 1
	t.check(MobCrossbows.drop_weapon(mob,rng,0).is_empty(),"Vanishing prevents a generated crossbow from dropping")
	mob.crossbow_weapon.data.enchantments.erase("Curse of Vanishing")
	# Retaliation recruits idle pillagers but never targets raid allies.
	var ally: Creature = game.spawn_creature("pillager",at+Vector3(2,0,0)); ally.set_physics_process(false)
	var attacker: Creature = game.spawn_creature("zombie",at+Vector3(0,0,5)); attacker.set_physics_process(false)
	MobCrossbows.struck_by(mob,attacker)
	t.check(MobCrossbows.choose_target(mob,0.1) == attacker and MobCrossbows.choose_target(ally,0.1) == attacker,"a hurt pillager recruits an idle ally against its attacker")
	ally.crossbow_revenge = null; MobCrossbows.struck_by(ally,mob)
	t.check(ally.crossbow_revenge == null,"pillager retaliation ignores fellow raid mobs")
	# The hit point is near the unrelated zombie, but the actual shooter is
	# another pillager. It must not fall back to guessing from that hit point.
	ally.hit(1,attacker.position,"arrow")
	t.check(ally.crossbow_revenge == null,"an arrow hit never mistakes a nearby bystander for its shooter")
	attacker.free(); ally.free(); mob.crossbow_revenge = null
	# No ordinary ominous bottle or invented emerald drops.
	for drop in game.drops.get_children(): drop.free()
	var ordinary: Creature = game.spawn_creature("pillager",at); ordinary.set_physics_process(false); ordinary.health = 0; ordinary.die()
	t.check(game.drops.get_children().all(func(drop): return drop.item_id in [Nodes.ARROW_ITEM,VillageContent.CROSSBOW]),"ordinary pillager death drops only source arrows or its equipped crossbow")
	for drop in game.drops.get_children(): drop.free()
	var captain: Creature = game.spawn_creature("pillager",at); captain.set_physics_process(false); captain.set_meta(PillagerPatrols.CAPTAIN_META,true)
	# Use the same captain flag as the patrol spawner.
	captain.health = 0; captain.die()
	var bottles: Array = game.drops.get_children().filter(func(drop): return PotionCatalog.ITEMS.has(drop.item_id) and PotionCatalog.ITEMS[drop.item_id].potion == "ominous")
	t.check(bottles.size() == 1 and int(bottles[0].data.get("potion_level",0)) in range(1,6),"a non-raid captain drops exactly one ominous bottle at a source level from one to five")
	# Pause/reload resumes a partially drawn equipped weapon.
	mob.custom_name = "Crossbow sentinel"; mob.position = at
	mob.set_meta(PillagerPatrols.CAPTAIN_META,true); mob.set_meta(PillagerPatrols.PATROL_META,true)
	mob.crossbow_ai = MobCrossbows.initial(); mob.crossbow_ai.attacking = true; mob.crossbow_ai.phase = 1; mob.crossbow_ai.using = 0.45
	mob.crossbow_weapon.data.crossbow_loaded = false
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
		if child.custom_name == "Crossbow sentinel": restored = child
	t.check(restored != null and restored.crossbow_ai.phase == 1 and is_equal_approx(restored.crossbow_ai.using,0.45) and Inventory.enchantment(restored.crossbow_weapon,"Multishot") == 1,"equipped weapon, forced enchantments and partial charge survive an actual world reload")
	t.check(restored != null and PillagerPatrols.is_captain(restored) and PillagerPatrols.is_patrol_member(restored),"patrol captain identity survives with its weapon across world reloads")
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_pos; game.gamemode = old_mode; game.player.health = old_hp
