extends RefCounted

static func spawn(game: Node3D, kind: String, at: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,at,"",{"jockey":false}); mob.set_physics_process(false)
	mob.mob_armor = MobArmor.empty_slots(); MobArmor.refresh(mob)
	return mob

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_mode: String = game.gamemode; var old_light: float = game.daylight; var old_hp: float = game.player.health
	for node in game.creatures.get_children(): node.free()
	game.world.adventure_state["farm_animals"] = {}
	var at := Vector3(8.5,1800,8.5)
	for x in range(3,16):
		for z in range(3,16):
			for y in range(1799,1804): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1799 else Nodes.AIR)
	game.player.position = at+Vector3(0,0,-5); game.gamemode = "creative"; game.daylight = 0; game.state = "playing"
	for kind in ["baby_zombie","baby_husk","baby_drowned"]:
		var child: Creature = spawn(game,kind,at)
		t.check(MobBabies.baby(child) and child.kind == MobBabies.base(kind) and child.width == 0.25 and child.height == 0.99,"the source baby variant has its own permanent child dimensions: "+kind)
		t.check(is_equal_approx(child.info().speed,Creature.KINDS[child.kind].speed*1.5) and child.info().reach == 1 and child.xp_reward() == 12,"baby speed, reach and XP use the source values: "+kind)
		Farming.tick(child,3600)
		t.check(MobBabies.baby(child) and child.growth_remaining == 0 and child.model.scale == Vector3.ONE*0.5,"baby undead remain small instead of aging like farm animals: "+kind)
		Farming.forget(child); child.free()
	t.check(MobBabies.natural("zombie",0.049999) == "baby_zombie" and MobBabies.natural("zombie",0.05) == "zombie","the five-percent natural baby roll uses the source strict boundary")
	var natural: Creature = spawn(game,"baby_zombie",at+Vector3(16,0,16)); natural.set_meta("no_jockey",false)
	for seed_value in 100000:
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1,100) <= 5 and rng.randi_range(1,100) <= 5:
			MobJockeys.rng_for(game.world).seed = seed_value; break
	MobJockeys.spawn_for(natural)
	t.check(MobJockeys.vehicle(natural) == null,"a successful existing-chicken roll with no chicken does not fall through to spawning one")
	for seed_value in 100000:
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		if rng.randi_range(1,100) > 5 and rng.randi_range(1,100) <= 5:
			MobJockeys.rng_for(game.world).seed = seed_value; break
	MobJockeys.spawn_for(natural)
	t.check(MobJockeys.vehicle(natural) != null,"the second source roll can spawn and mount a new chicken")
	var generated: Creature = MobJockeys.vehicle(natural)
	if generated != null: MobJockeys.detach(natural); Farming.forget(generated); generated.free()
	Farming.forget(natural); natural.free()
	var child: Creature = spawn(game,"baby_husk",at)
	var chicken: Creature = spawn(game,"chicken",at)
	chicken.custom_name = "Jockey keeper"; chicken.set_meta("persistent",true)
	var sword: Dictionary = {"id":Nodes.TOOLS+13,"count":1,"wear":7,"data":{"custom_name":"Small rider's sword","enchantments":{"Sharpness":3}}}
	MobWeapons.set_item(child,sword,2)
	t.check(MobJockeys.attach(child,chicken) and MobJockeys.vehicle(child) == chicken,"a baby undead can mount an available chicken")
	t.check(not Farming.managed(child) and not Farming.records(game).has(child.farm_id) and Farming.state(chicken).jockey.baby,"the chicken owns its rider's saved record without a duplicate farm entry")
	var second: Creature = spawn(game,"baby_zombie",at)
	t.check(not MobJockeys.attach(second,chicken) and not Boats.can_ride(child),"an occupied chicken refuses another rider and an attached rider cannot board a boat")
	Farming.forget(second); second.free()
	var before: Vector3 = chicken.position
	MobJockeys.move(child,0.1,Vector3.RIGHT)
	t.check(chicken.position.x > before.x and child.position.is_equal_approx(chicken.position+MobJockeys.SEAT) and is_equal_approx(chicken.velocity.x,chicken.info().speed),"rider movement uses chicken speed and keeps the source seat attachment")
	var eggs: int = game.drops.get_child_count(); chicken.egg_timer = 0.01; chicken._physics_process(0.1)
	t.check(game.drops.get_child_count() == eggs and chicken.xp_reward() == 10,"a jockey chicken suppresses eggs and gives ten XP")
	var boat: BoatEntity = game.boats.spawn(Boats.ORDINARY[0],at+Vector3(3,0.5,3))
	if boat != null:
		t.check(boat.attach_mob(chicken),"a chicken and its rider can occupy a boat passenger seat together")
		t.check(boat.saved.passenger.jockey.baby and boat.saved.passenger.jockey.weapon_state.item.data.custom_name == "Small rider's sword","the boat passenger record contains the nested baby and its real equipment")
		var seat: Vector3 = chicken.position; MobJockeys.move(child,0.1,Vector3.RIGHT)
		t.check(chicken.position == seat and child.position.is_equal_approx(chicken.position+MobJockeys.SEAT),"a boat controls the passenger while the jockey follows its nested seat")
		boat.release_mob(); game.boats.destroy(boat,false)
	else: t.check(false,"the jockey boat fixture can be placed")
	MobBabies.after_attack(child,1)
	t.check(MobBabies.pacing(child,0.1) and is_equal_approx(child.get_meta("baby_pace"),0.4),"a successful source baby attack roll briefly interrupts pursuit")
	var converted: Creature = UndeadVariants.replace(game,child,"zombie"); converted.set_physics_process(false)
	t.check(MobBabies.baby(converted) and MobJockeys.vehicle(converted) == chicken and converted.held_weapon.data.custom_name == "Small rider's sword","husk conversion preserves baby status, mount and held equipment")
	child = converted
	var patient: Creature = spawn(game,"baby_zombie_villager",at+Vector3(3,0,0))
	var carrier: Creature = spawn(game,"chicken",patient.position); carrier.set_meta("persistent",true)
	MobJockeys.attach(patient,carrier); patient.set_meta("curing",true); patient.set_meta("cure_timer",0.01)
	ZombieVillagers.update(game,patient,0.1)
	var cured: Creature = MobJockeys.rider(carrier)
	t.check(cured != null and cured is VillageMob and not MobBabies.baby(cured),"curing a baby zombie villager retains its chicken attachment as an adult villager")
	var cured_identity: String = carrier.farm_id
	var identity: String = chicken.farm_id
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var stop_spawn: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(stop_spawn)
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(stop_spawn)
	chicken = Farming.active(game,identity)
	carrier = Farming.active(game,cured_identity)
	t.check(carrier != null and MobJockeys.rider(carrier) is VillageMob,"the cured villager's mount and village identity survive a world reload")
	t.check(chicken != null and MobJockeys.rider(chicken) != null,"a real world reload restores the chicken and its single attached rider")
	if chicken != null and MobJockeys.rider(chicken) != null:
		child = MobJockeys.rider(chicken)
		t.check(MobBabies.baby(child) and child.held_weapon.data.custom_name == "Small rider's sword" and child.held_weapon_probability == 2,"the restored baby retains held item metadata and its acquired drop probability")
		var riders: int = 0
		for mob in game.creatures.get_children():
			if MobJockeys.vehicle(mob) == chicken: riders += 1
		t.check(riders == 1,"loading does not duplicate a rider saved inside its vehicle")
		var nearby: Vector3 = game.player.position; game.player.position += Vector3(500,0,0)
		t.check(Farming.sleep_if_unloaded(chicken) and child.is_queued_for_deletion(),"unloading a persistent chicken stores and suspends its rider as one pair")
		game.player.position = nearby; chicken = Farming.resolve(game,identity); child = MobJockeys.rider(chicken)
		t.check(child != null and child.held_weapon.data.custom_name == "Small rider's sword" and not Farming.records(game).has(child.farm_id),"waking the pair restores one equipped rider without an independent record")
		chicken.health = 0; chicken.die()
		t.check(MobJockeys.vehicle(child) == null and not child.is_queued_for_deletion() and Farming.managed(child),"killing the chicken dismounts its living rider and restores independent persistence")
		var fresh: Creature = spawn(game,"chicken",at); MobJockeys.attach(child,fresh)
		child.health = 0; child.die()
		t.check(MobJockeys.rider(fresh) == null and not fresh.is_queued_for_deletion() and fresh.get_meta("chicken_jockey",false),"killing the rider leaves its chicken alive with the permanent jockey flag")
		fresh.egg_timer = 0.01; eggs = game.drops.get_child_count(); fresh._physics_process(0.1)
		t.check(game.drops.get_child_count() == eggs,"a former jockey chicken does not resume laying eggs")
	Trials.bind(game.world,Vector3i.ZERO,"baby-jockey-test",{"kind":"zombie","position":[8.5,1800,8.5],"health":20,"baby":true,"jockey_vehicle":{}})
	var trial: Creature = Trials.runtime(game.world).mobs["baby-jockey-test"]; trial.set_physics_process(false)
	var mount: Creature = spawn(game,"chicken",trial.position); MobJockeys.attach(trial,mount)
	var trial_saved: Dictionary = Trials.mob_record(trial)
	t.check(MobBabies.baby(trial) and not Farming.managed(mount) and not Farming.records(game).has(mount.farm_id) and not trial_saved.jockey_vehicle.is_empty(),"trial encounters own both the baby and its chicken without a second farm owner")
	t.check(game.leads.record({"mob":mount}).jockey.is_empty(),"a lead record does not independently save the trial-owned rider")
	var transformed: Creature = UndeadVariants.replace(game,trial,"drowned"); transformed.set_physics_process(false)
	t.check(Trials.runtime(game.world).mobs["baby-jockey-test"] == transformed and MobJockeys.vehicle(transformed) == mount,"conversion keeps the trial's rider identity and mounted vehicle")
	trial_saved = Trials.mob_record(transformed)
	var mount_identity: int = mount.get_instance_id()
	MobJockeys.detach(transformed); transformed.free()
	Trials.bind(game.world,Vector3i.ZERO,"baby-jockey-test",trial_saved)
	trial = Trials.runtime(game.world).mobs["baby-jockey-test"]; trial.set_physics_process(false); mount = MobJockeys.vehicle(trial)
	t.check(mount != null and mount.get_instance_id() == mount_identity and MobBabies.baby(trial) and trial.kind == "drowned","trial restore reuses a chicken already restored by another owner")
	Trials.forget(game.world,"baby-jockey-test"); trial.free()
	t.check(mount == null or mount.is_queued_for_deletion(),"removing a trial rider also removes its encounter-owned chicken")
	for x in range(3,16):
		for z in range(3,16):
			for y in range(1799,1804): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_pos; game.gamemode = old_mode; game.daylight = old_light; game.player.health = old_hp
