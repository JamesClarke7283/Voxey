extends RefCounted

static func arrows(game: Node3D) -> Array:
	return game.entities.get_children().filter(func(node): return node is Arrow and not node.is_queued_for_deletion())

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_position: Vector3 = game.player.position; var old_mode: String = game.gamemode; var old_hp: float = game.player.health; var old_light: float = game.daylight
	var old_effects: Dictionary = game.survival.effect_snapshot()
	for child in game.creatures.get_children(): child.free()
	game.world.adventure_state["farm_animals"] = {}
	for child in arrows(game): child.free()
	var at := Vector3(8.5,900,8.5)
	for x in range(3,15):
		for z in range(-12,15):
			for y in range(899,904): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 899 else Nodes.AIR)
	game.player.position = at+Vector3(0,0,-14); game.player.health = 100; game.player.damage_cooldown = 0; game.gamemode = "survival"; game.daylight = 0; game.state = "playing"
	var mob: Creature = game.spawn_creature("skeleton",at); mob.set_physics_process(false)
	t.check(mob.bow_weapon.id == Nodes.BOW and mob.bow_model.mesh != null,"a skeleton equips a real bow with a visible mesh")
	t.check(is_equal_approx(mob.width,0.3) and is_equal_approx(mob.height,1.99),"the archer uses the source collision box")
	for i in 10: mob._physics_process(0.1)
	t.check(arrows(game).is_empty() and mob.bow_ai.using >= 0.8,"a skeleton draws rather than firing immediately")
	for i in 3: mob._physics_process(0.1)
	t.check(arrows(game).size() == 1,"the first NPC bow shot follows a full one-second draw")
	var shot: Arrow = arrows(game)[0]
	t.check(not shot.critical and not shot.recoverable and shot.shooter_id == mob.get_instance_id() and shot.velocity.length() > 27,"skeleton arrows use NPC speed, provenance and noncollectible flags")
	t.check(mob.bow_ai.mode == "strafe" and mob.direction.length() < 0.8,"visible targets within range trigger a slow sideways strafe")
	for arrow in arrows(game): arrow.free()
	# A full draw behind cover cannot fire, and expires after three unseen seconds.
	mob.position = at; mob.bow_ai = MobBows.initial(); mob.bow_ai.attacking = true; mob.bow_ai.using = 0.9; mob.bow_target = game.player
	for y in range(900,904): game.world.set_node(Vector3i(8,y,2),Nodes.STONE)
	for i in 20: mob._physics_process(0.1)
	t.check(arrows(game).is_empty(),"a drawn bow does not fire through a wall")
	for y in range(900,904): game.world.set_node(Vector3i(8,y,2),Nodes.AIR)
	mob._physics_process(0.1)
	t.check(arrows(game).size() == 1,"the held draw fires when sight returns before its timeout")
	for arrow in arrows(game): arrow.free()
	game.gamemode = "creative"; MobBows.stop(mob)
	var villager: Creature = game.spawn_creature("villager",at+Vector3(0,0,-8)); villager.set_physics_process(false)
	t.check(MobBows.choose_target(mob,0.1) == null,"skeletons ignore creative players and do not hunt villagers")
	var golem: Creature = game.spawn_creature("iron_golem",at+Vector3(0,0,-10)); golem.set_physics_process(false)
	t.check(MobBows.choose_target(mob,0.1) == golem,"skeletons acquire iron golems independently of the player")
	var other: Creature = game.spawn_creature("skeleton",at+Vector3(3,0,0)); other.set_physics_process(false)
	MobBows.struck_by(mob,other)
	t.check(MobBows.choose_target(mob,0.1) == other and other.bow_revenge == null,"skeleton retaliation can target another skeleton without recruiting allies")
	mob.bow_revenge = null
	var wolf: Creature = game.spawn_creature("wolf",at+Vector3(2,0,0)); wolf.set_physics_process(false)
	mob.bow_ai.using = 0.6
	t.check(not MobBows.step(mob,0.1).active and mob.bow_ai.using < 0,"wolf avoidance interrupts drawing before combat")
	for actor in [wolf,other,villager,golem]: Farming.forget(actor); actor.free()
	game.gamemode = "survival"; mob.position = at
	mob.bow_weapon = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Power":5,"Punch":2,"Flame":1}}}
	var params: Dictionary = MobBows.projectile(mob.bow_weapon,at+Vector3.UP*1.5,game.player.position,1.8,2,[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5])
	t.check(is_equal_approx(params.damage,5.22) and params.punch == 2 and params.flame,"equipped bow enchantments affect actual NPC projectiles")
	mob.position = at+Vector3(5,0,0); game.player.position = at+Vector3(0,0,-8); game.player.damage_cooldown = 0
	var stray: Creature = game.spawn_creature("stray",at); stray.set_physics_process(false)
	var slow: Arrow = MobBows.shoot(stray,game.player.position,1.8,[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]); slow.set_physics_process(false)
	t.check(slow.item_id == VillageContent.SLOWNESS_ARROW and not slow.critical and not slow.recoverable,"a stray fires its source slowness arrow")
	for i in 12:
		if slow.attached or slow.is_queued_for_deletion(): break
		slow._physics_process(0.05)
	t.check(game.player.health < 100 and PotionEffects.level(game.player,"slowness") > 0,"the stray's actual arrow hits and slows the player")
	Farming.forget(stray); stray.free(); slow.free()
	game.player.position = at+Vector3(0,0,-14); mob.position = at
	var rng := RandomNumberGenerator.new(); rng.seed = 88
	t.check(not MobBows.drop_weapon(mob,rng,0.085).is_empty() and MobBows.drop_weapon(mob,rng,0.085001).is_empty(),"the equipped bow uses the source inclusive 8.5-percent drop chance")
	mob.bow_weapon.data.enchantments["Curse of Vanishing"] = 1
	t.check(MobBows.drop_weapon(mob,rng,0).is_empty(),"Vanishing prevents bow drops")
	mob.bow_weapon.data.enchantments.erase("Curse of Vanishing")
	var doomed: Creature = game.spawn_creature("skeleton",at+Vector3(2,0,0)); doomed.set_physics_process(false)
	doomed.bow_weapon = mob.bow_weapon.duplicate(true)
	for seed_value in 1000:
		rng.seed = seed_value
		if rng.randf() <= 0.085:
			MobBows.rng_for(game.world).seed = seed_value; break
	doomed.health = 0; doomed.die()
	t.check(game.drops.get_children().any(func(drop): return drop.item_id == Nodes.BOW and int(drop.data.get("enchantments",{}).get("Power",0)) == 5),"death can drop the actual enchanted bow with randomized wear")
	var victim: Creature = game.spawn_creature("stray",at+Vector3(4,0,0)); victim.set_physics_process(false)
	game.player.position = victim.position+Vector3(0,0,-20.01); game.achievements.unlocked.erase("sniper_duel")
	var killer: Arrow = game.spawn_arrow(victim.position+Vector3(0,1,-1),Vector3(0,0,32)); killer.set_physics_process(false)
	killer.from_player = true; killer.shooter_id = game.player.get_instance_id(); killer.damage = 100
	killer.trace_segment(killer.position,killer.position+Vector3(0,0,2))
	t.check(game.achievements.is_unlocked("sniper_duel"),"a player's arrow killing a stray over twenty blocks away awards the inherited source achievement")
	game.player.position = at+Vector3(0,0,-14)
	# Conversion preserves the actual enchanted weapon, not a newly rolled bow.
	var converted: Creature = UndeadVariants.replace(game,mob,"stray"); converted.set_physics_process(false)
	t.check(Inventory.enchantment(converted.bow_weapon,"Power") == 5 and converted.kind == "stray","freezing conversion keeps the equipped enchanted bow")
	mob = converted; mob.custom_name = ""; mob.bow_ai = MobBows.initial(); mob.bow_ai.attacking = true; mob.bow_ai.using = 0.45
	var identity: String = mob.farm_id
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
	t.check(restored != null and restored.custom_name.is_empty() and Inventory.enchantment(restored.bow_weapon,"Power") == 5 and is_equal_approx(restored.bow_ai.using,0.45),"an unnamed archer, equipped bow and partial draw survive a real world reload")
	if restored != null:
		Trials.bind(game.world,Vector3i.ZERO,"bow-fixture",Trials.mob_record(restored))
		var trial_mob: Creature = Trials.runtime(game.world).mobs["bow-fixture"]
		trial_mob.set_physics_process(false)
		t.check(Inventory.enchantment(trial_mob.bow_weapon,"Power") == 5 and is_equal_approx(trial_mob.bow_ai.using,0.45) and not Farming.records(game).has(trial_mob.farm_id),"trial restoration keeps the bow state under a single encounter owner")
		Trials.forget(game.world,"bow-fixture"); trial_mob.queue_free()
	var distant: Creature = game.spawn_creature("skeleton",Vector3(300,900,300)); distant.set_physics_process(false)
	var distant_key: String = distant.farm_id
	t.check(Farming.sleep_if_unloaded(distant) and not Farming.records(game).has(distant_key),"an ordinary distant archer despawns and leaves no restorable record")
	var named: Creature = game.spawn_creature("skeleton",Vector3(302,900,300)); named.set_physics_process(false); named.custom_name = "Remember me"
	named.bow_weapon = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Power":3}}}
	var named_key: String = named.farm_id
	t.check(Farming.sleep_if_unloaded(named) and Farming.records(game).has(named_key) and int(Farming.records(game)[named_key].bow.weapon.data.enchantments.Power) == 3,"a named unloaded archer keeps its equipped bow in its saved record")
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_position; game.gamemode = old_mode; game.player.health = old_hp; game.daylight = old_light; game.survival.restore_effects(old_effects)
