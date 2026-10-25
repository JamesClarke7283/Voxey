extends RefCounted

static func spawn(game: Node3D, kind: String, at: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,at); mob.set_physics_process(false)
	mob.mob_armor = MobArmor.empty_slots(); mob.mob_armor_drops = [0,0,0,0]; mob.mob_armor_pickup = true
	MobArmor.refresh(mob)
	return mob

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_mode: String = game.gamemode; var old_health: float = game.player.health; var old_light: float = game.daylight
	var old_difficulty: int = game.difficulty
	var old_armor: Array = game.player.armor_slots.duplicate(true); var old_effects: Dictionary = game.survival.effect_snapshot()
	for child in game.creatures.get_children(): child.free()
	for child in game.drops.get_children(): child.free()
	game.world.adventure_state["farm_animals"] = {}
	var at := Vector3(8.5,1400,8.5)
	for x in range(3,15):
		for z in range(3,15):
			for y in range(1399,1405): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1399 else Nodes.AIR)
	game.player.position = at+Vector3(0,0,-1.5); game.player.health = 100; game.player.armor_slots = MobArmor.empty_slots(); game.gamemode = "survival"; game.daylight = 0; game.state = "playing"
	PotionEffects.clear(game.player)
	var skeleton: Creature = spawn(game,"skeleton",at)
	var sword: Dictionary = {"id":Nodes.TOOLS+13,"count":1,"wear":7,"data":{"custom_name":"Recovered blade","enchantments":{"Sharpness":3,"Fire Aspect":2,"Knockback":2}}}
	MobWeapons.set_item(skeleton,MobWeapons.empty_item(),0)
	var drop: ItemDrop = game.spawn_drop(at+Vector3(1,0,0),sword.id,1,sword.wear,sword.data); drop.set_physics_process(false); drop.age = 0.99
	MobWeapons.pickup(skeleton)
	t.check(skeleton.bow_weapon.id == 0,"weapon pickup waits for the source item-age gate")
	drop.age = 1; MobWeapons.pickup(skeleton)
	t.check(drop.is_queued_for_deletion() and skeleton.bow_weapon.id == sword.id and skeleton.bow_weapon.data.custom_name == "Recovered blade","a skeleton picks up a dropped sword with its wear and metadata")
	t.check(not skeleton.ranged() and skeleton.held_weapon_model.visible and not skeleton.bow_model.visible and skeleton.held_weapon_probability == 2,"a sword switches the skeleton to melee and changes its held mesh")
	t.check(not skeleton.has_meta("persistent"),"weapon pickup preserves the source distinction from persistent armor pickup")
	var wear: int = Durability.normalized(skeleton.bow_weapon)
	var expected: float = MobWeapons.damage_plan(skeleton.bow_weapon,2,{"fleshy":100},1,false,RegionalDifficulty.source_level(game.difficulty)).damage
	game.player.damage_cooldown = 0; skeleton._physics_process(0.05)
	t.check(is_equal_approx(game.player.health,100-expected) and PotionEffects.level(game.player,"burning") == 1,"the real melee tick uses the held sword's damage and Fire Aspect")
	t.check(Durability.normalized(skeleton.bow_weapon) == wear and is_equal_approx(skeleton.attack_cooldown,1.0),"mob melee uses the source one-second interval without wearing its weapon")
	PotionEffects.apply(skeleton,"strength",10,2)
	for difficulty in 3:
		game.difficulty = difficulty; game.player.health = 100; game.player.damage_cooldown = 0
		var scaled: float = MobWeapons.damage_plan(skeleton.bow_weapon,2,{"fleshy":100},1.6,false,difficulty+1).damage
		MobWeapons.attack(skeleton,game.player)
		t.check(is_equal_approx(game.player.health,100-scaled),"player melee damage scales difficulty before the attacker's Strength modifier: "+str(difficulty))
	PotionEffects.clear(skeleton); game.difficulty = old_difficulty
	PotionEffects.clear(game.player); game.player.health = 100; game.player.damage_cooldown = 0; skeleton.position = at; skeleton.attack_cooldown = 0
	game.world.set_node(Vector3i(8,1401,7),Nodes.STONE)
	skeleton._physics_process(0.05)
	t.check(game.player.health == 100,"melee attacks require line of sight even when the target is within reach")
	game.world.set_node(Vector3i(8,1401,7),Nodes.AIR)
	# Force a second loadout to exercise the shared bow/melee mode transition.
	var bow: Dictionary = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Power":2}}}
	MobWeapons.set_item(skeleton,bow,2)
	t.check(skeleton.ranged() and skeleton.bow_model.visible and not skeleton.held_weapon_model.visible,"equipping a bow restores ranged AI and the bow mesh")
	var zombie: Creature = spawn(game,"zombie",at+Vector3(4,0,0)); MobWeapons.set_item(zombie,MobWeapons.empty_item(),0)
	var bone: ItemDrop = game.spawn_drop(zombie.position,Nodes.BONE,5); bone.set_physics_process(false); bone.age = 1
	MobWeapons.pickup(zombie)
	t.check(zombie.held_weapon.id == Nodes.BONE and zombie.held_weapon.count == 5 and bone.is_queued_for_deletion(),"an empty-handed mob can collect an entire ordinary item stack")
	var collected: Dictionary = MobWeapons.drop_item(zombie,EnchantRolls.new(1),0.9)
	t.check(collected.id == Nodes.BONE and collected.count == 5,"collected item stacks retain their guaranteed drop count")
	var drowned: Creature = spawn(game,"drowned",at+Vector3(-4,0,0))
	MobWeapons.set_item(drowned,{"id":VillageContent.TRIDENT,"count":1,"wear":11},2)
	t.check(drowned.ranged() and not MobWeapons.equip(drowned,sword) and UndeadVariants.wield(drowned) == VillageContent.TRIDENT,"a drowned holding a trident retains it and keeps ranged attacks")
	t.check(not UndeadVariants.roll_drops(drowned.kind,RandomNumberGenerator.new(),0,drowned).any(func(row): return row[0] == VillageContent.TRIDENT),"the ordinary drowned loot roll does not duplicate its real held weapon")
	var wither: Creature = spawn(game,"wither_skeleton",at+Vector3(0,0,4))
	t.check(wither.bow_weapon.id == Nodes.TOOLS+8 and not wither.ranged() and wither.arms.size() == 2 and wither.held_weapon_model.visible,"a wither skeleton starts with a visible stone sword and a melee body")
	game.player.damage_cooldown = 0; game.player.health = 100
	MobWeapons.attack(wither,game.player)
	t.check(PotionEffects.level(game.player,"withering") == 1,"a wither skeleton's sword attack applies its ten-second Wither effect")
	PotionEffects.apply(wither,"withering",10)
	t.check(PotionEffects.level(wither,"withering") == 0,"the wither skeleton itself is immune to Wither")
	PotionEffects.clear(game.player)
	MobWeapons.set_item(wither,bow,2)
	t.check(wither.ranged() and wither.bow_model.visible and wither.bow_model.mesh != null and not MobBows.qualifies_for_sniper(wither.kind,"arrow",true,21),"a bow-equipped wither skeleton uses bow combat while retaining its achievement exception")
	var spider: Creature = spawn(game,"spider",at+Vector3(3,0,3)); spider.health = 100; spider.grounded = true
	MobWeapons.set_item(zombie,{"id":Nodes.TOOLS+13,"count":1,"wear":0,"data":{"enchantments":{"Bane of Arthropods":2,"Knockback":2}}},2)
	var planned: Dictionary = MobWeapons.damage_plan(zombie.held_weapon,3,MeleeCombat.armor_groups(spider),1,true)
	MobWeapons.attack(zombie,spider)
	t.check(is_equal_approx(spider.health,100-planned.damage) and PotionEffects.level(spider,"slowness") == 4 and spider.knock.length() > 10,"mob weapon attacks use target damage groups, Bane and enchanted knockback")
	MobWeapons.set_item(zombie,MobWeapons.empty_item(),0); PotionEffects.apply(zombie,"burning",10)
	var chance: float = RegionalDifficulty.regional(game,zombie.position)*0.3
	for seed_value in 1000:
		var probe := RandomNumberGenerator.new(); probe.seed = seed_value
		if probe.randf() < chance:
			MobArmor.rng_for(game.world).native.seed = seed_value; break
	game.player.health = 100; game.player.damage_cooldown = 0; MobWeapons.attack(zombie,game.player)
	t.check(PotionEffects.level(game.player,"burning") == 1,"an unarmed burning zombie can ignite its target using regional difficulty")
	PotionEffects.clear(zombie); PotionEffects.clear(game.player)
	MobWeapons.set_item(zombie,sword,2)
	var converted: Creature = UndeadVariants.replace(game,zombie,"drowned"); converted.set_physics_process(false)
	t.check(converted.held_weapon.id == sword.id and converted.held_weapon.data.custom_name == "Recovered blade" and converted.held_weapon_probability == 2,"undead conversion preserves the acquired weapon and its drop rule")
	var curing: Creature = spawn(game,"zombie_villager",at+Vector3(5,0,2))
	MobWeapons.set_item(curing,sword,2); curing.set_meta("curing",true); curing.set_meta("cure_timer",0.01)
	var count_before: int = game.drops.get_child_count(); ZombieVillagers.update(game,curing,0.1)
	t.check(curing.is_queued_for_deletion() and game.drops.get_child_count() == count_before+1 and game.drops.get_children().any(func(dropped): return dropped.item_id == sword.id and dropped.data.get("custom_name","") == "Recovered blade"),"curing returns the zombie villager's acquired weapon with its metadata")
	# Both persistence owners must keep equipment and a partly drawn bow.
	skeleton.bow_ai = MobBows.initial(); skeleton.bow_ai.using = 0.45; skeleton.bow_ai.attacking = true
	var identity: String = skeleton.farm_id; var second_identity: String = converted.farm_id
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var stop_spawn: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(stop_spawn)
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(stop_spawn)
	var restored: Creature; var restored_drowned: Creature
	for child in game.creatures.get_children():
		if child.farm_id == identity: restored = child
		if child.farm_id == second_identity: restored_drowned = child
	t.check(restored != null and restored.bow_weapon.id == Nodes.BOW and restored.held_weapon_probability == 2 and is_equal_approx(restored.bow_ai.using,0.45),"world reload preserves the acquired bow and an in-progress draw")
	t.check(restored_drowned != null and restored_drowned.held_weapon.id == sword.id and restored_drowned.held_weapon.data.custom_name == "Recovered blade","world reload preserves a drowned's converted weapon")
	if restored != null:
		Trials.bind(game.world,Vector3i.ZERO,"weapon-saved",Trials.mob_record(restored))
		var trial: Creature = Trials.runtime(game.world).mobs["weapon-saved"]; trial.set_physics_process(false)
		t.check(trial.bow_weapon.id == Nodes.BOW and trial.held_weapon_probability == 2 and is_equal_approx(trial.bow_ai.using,0.45),"trial snapshots preserve acquired equipment and partial draws")
		Trials.forget(game.world,"weapon-saved"); trial.queue_free()
	for ominous in [false,true]:
		var key: String = "weapon-new-"+str(ominous)
		Trials.bind(game.world,Vector3i.ZERO,key,{"kind":"skeleton","position":[8.5,1400,8.5],"health":20,"ominous":ominous})
		var trial: Creature = Trials.runtime(game.world).mobs[key]; trial.set_physics_process(false)
		t.check(is_equal_approx(trial.held_weapon_probability,0.085 if ominous else 0),"new trial weapon drop probability matches its ominous state "+str(ominous))
		Trials.forget(game.world,key); trial.queue_free()
	# The raised floor must not become a roof over later sunlight fixtures.
	for x in range(3,15):
		for z in range(3,15):
			for y in range(1399,1405): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_pos; game.gamemode = old_mode; game.player.health = old_health; game.daylight = old_light; game.difficulty = old_difficulty; game.player.armor_slots = old_armor; game.survival.restore_effects(old_effects)
	game.player.damage_cooldown = 0
