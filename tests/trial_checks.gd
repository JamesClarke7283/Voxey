extends RefCounted

static func live(game: Node3D) -> Array:
	return game.creatures.get_children().filter(func(m): return m.has_meta("trial_key") and not m.is_queued_for_deletion())

static func reward_count(game: Node3D) -> int:
	return game.drops.get_children().filter(func(d): return d.item_id != Nodes.ROTTEN_FLESH).size()

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false
	var world: VoxelWorld = game.world
	for x in range(1,16):
		for z in range(1,16):
			for y in range(730,742):
				world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 730 else Nodes.AIR)
	var p := Vector3i(8,734,8)
	world.set_node(p,Trials.SPAWNER)
	var s: Dictionary = Trials.station(world,p)
	game.player.position = Vector3(8.5,731,12.5)
	t.check(Nodes.exists(Trials.KEY) and Nodes.food(Trials.ENCHANTED_APPLE) == 4 and Nodes.drop(Trials.SPAWNER) == 0 and not world.circuits.movable(p),"trial content is registered, edible reward exists, cages drop nothing and resist pistons")
	t.check(Trials.limits(s,false) == Vector2i(6,2),"single-player trial requires six mobs and caps two simultaneous")
	s.players = ["a","b","c"]
	t.check(Trials.limits(s,false) == Vector2i(10,4),"late participants add two total mobs and one simultaneous mob each")
	s.mob = "spider"
	t.check(Trials.limits(s,true) == Vector2i(20,5),"ominous unarmored species doubles total and adds one simultaneous slot")
	s.mob = "zombie"; s.players = []
	game.player.position.x += 25
	Trials.update(world,1)
	t.check(world.node_at(p) == Trials.SPAWNER and live(game).is_empty(),"players outside the source14-block radius cannot activate a trial")
	game.player.position.x -= 25
	world.set_node(Vector3i(8,735,10),Nodes.STONE)
	# Close the whole sight line, including its lower section.
	for x in range(1,16):
		for y in range(731,741): world.set_node(Vector3i(x,y,10),Nodes.STONE)
	Trials.update(world,1)
	t.check(world.node_at(p) == Trials.SPAWNER,"a wall between player and cage prevents activation")
	for x in range(1,16):
		for y in range(731,741): world.set_node(Vector3i(x,y,10),Nodes.AIR)
	Trials.update(world,1)
	t.check(world.node_at(p) == Trials.ACTIVE and s.players == [Trials.identity(game)],"visible nearby player activates and is recorded once")
	Trials.update(world,2); Trials.update(world,2); Trials.update(world,2)
	t.check(live(game).size() == 2 and s.spawned == 2,"active trial spawns two real mobs and respects its simultaneous cap")
	for mob in live(game): mob.set_physics_process(false)
	var serial: int = s.serial
	Trials.snapshot(world)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s))
	t.check(saved.mobs.size() == 2 and saved.spawned == 2 and saved.serial == serial,"serialized encounter includes exact outstanding enemies, count and unique identities")
	Trials.unload(world,Vector2i(0,0)); await t.process_frame
	t.check(live(game).is_empty() and s.mobs.size() == 2,"unloading removes runtime enemies without counting them as defeated")
	Trials.registered(world,p); Trials.update(world,0)
	t.check(live(game).size() == 2 and s.spawned == 2,"reloading restores outstanding enemies without consuming or duplicating spawn quota")
	for mob in live(game): mob.set_physics_process(false)
	var before_completion: int = reward_count(game)
	for wave in 3:
		for mob in live(game): mob.hit(10000,Vector3.INF,"magic")
		await t.process_frame
		if wave == 2:
			# Remove the zombies' independent common/rare drops so this assertion
			# measures only the trial reward that follows the final kill.
			for drop in game.drops.get_children(): drop.queue_free()
			await t.process_frame
			before_completion = 0
		Trials.update(world,2); Trials.update(world,2)
		for mob in live(game): mob.set_physics_process(false)
	Trials.update(world,0)
	t.check(world.node_at(p) == Trials.SPAWNER and s.cooldown > 1790 and live(game).is_empty(),"killing all six completes the trial and starts the30-minute cooldown")
	t.check(reward_count(game) == before_completion+1,"completion ejects one key or a source loot stack per participant")
	var drop_count: int = game.drops.get_child_count()
	Trials.update(world,2)
	t.check(game.drops.get_child_count() == drop_count and s.rewards.is_empty(),"the completion reward ejects exactly once")
	Trials.update(world,1)
	t.check(world.node_at(p) == Trials.SPAWNER,"nearby players cannot bypass the cooldown")
	PotionEffects.apply(game.player,"bad_omen",600,3)
	Trials.update(world,0)
	t.check(world.node_at(p) == Trials.OMINOUS_ACTIVE and s.cooldown == 0 and PotionEffects.level(game.player,"bad_omen") == 0 and is_equal_approx(game.survival.effects.get("trial_omen",0),2700.0),"Bad OmenIII converts to45-minute Trial Omen and bypasses ordinary cooldown")
	Trials.update(world,2)
	t.check(s.spawned == 1 and live(game).size() == 1,"ominous conversion resets the wave and spawns a real combatant")
	world.set_node(p,Nodes.AIR)
	for mob in live(game): mob.queue_free()
	await t.process_frame
	PotionEffects.clear_one(game.player,"trial_omen")
	var v := Vector3i(5,731,5); world.set_node(v,Trials.VAULT)
	var vs: Dictionary = Trials.station(world,v)
	var wrong: Dictionary = {"id":Trials.OMINOUS_KEY,"count":3,"wear":0}
	t.check(not Trials.open_vault(world,v,"a",wrong) and wrong.count == 3 and vs.claims.is_empty(),"wrong key never consumes a key or claims a vault")
	var key: Dictionary = {"id":Trials.KEY,"count":3,"wear":0}
	t.check(Trials.open_vault(world,v,"a",key) and key.count == 2 and world.node_at(v) == Trials.VAULT_EJECT,"correct key is consumed once and begins source vault ejection")
	var loot: Array = vs.rewards.duplicate(true)
	t.check(loot.size() >= 2 and loot.size() <= 5 and not Trials.open_vault(world,v,"b",key),"vault rolls its three source pools once and refuses concurrent openings")
	Trials.update(world,0)
	t.check(vs.rewards.size() == loot.size()-1,"first vault reward ejects immediately")
	Trials.snapshot(world)
	var state_copy: Dictionary = JSON.parse_string(JSON.stringify(world.stations))
	world.stations = state_copy
	Trials.reset(world); Trials.registered(world,v)
	var remaining: int = Trials.station(world,v).rewards.size()
	Trials.update(world,0.49)
	t.check(Trials.station(world,v).rewards.size() == remaining,"saved ejection keeps the remaining half-second interval")
	Trials.update(world,0.02)
	t.check(Trials.station(world,v).rewards.size() == remaining-1,"saved ejection resumes the existing queue without rerolling")
	for i in 7: Trials.update(world,0.5)
	vs = Trials.station(world,v)
	t.check(not Trials.open_vault(world,v,"a",key) and key.count == 2,"claimed player cannot consume another key after ejection or serialization")
	t.check(Trials.open_vault(world,v,"b",key,true) and key.count == 2,"different player gets an independent entitlement and Creative preserves key")
	for i in 7: Trials.update(world,0.5)
	for i in 128: vs.claims.append("extra_"+str(i))
	vs.claims = vs.claims.slice(-128)
	t.check(Trials.can_claim(vs,"a"),"claim history uses the source bounded128-player ring policy")
	var rng := RandomNumberGenerator.new(); rng.seed = 404
	var ids: Dictionary = {}; var count: int = 0; var valid: bool = true
	for table_name in ["vault","ominous_vault","standard_spawner","ominous_spawner"]:
		for pool in TrialLoot.tables()[table_name]:
			for entry in pool.items:
				if entry.item == "": continue
				var stack: Dictionary = TrialLoot.stack(entry,rng)
				valid = valid and not stack.is_empty() and Nodes.exists(stack.id) and stack.count > 0
				if not stack.is_empty(): ids[stack.id] = true
				count += 1
	t.check(valid and count == 72 and ids.has(VillageContent.HEAVY_CORE) and ids.has(Trials.ENCHANTED_APPLE),"all72 nonempty source loot entries resolve to obtainable items with original quantities")
	var omen: Dictionary = Inventory.clean_slot({"id":PotionCatalog.find("ominous"),"count":1,"data":{"omen_level":5}})
	t.check(omen.get("data",{}).get("omen_level",0) == 5,"vault Ominous BottleV survives inventory and save normalization")
	Hunger.reset(game.player); game.player.health = 20
	Eating.food_effects(game.player,Trials.ENCHANTED_APPLE)
	t.check(PotionEffects.level(game.player,"absorption") == 4 and PotionEffects.level(game.player,"regeneration") == 2 and game.survival.effects.fire_resistance == 300,"enchanted golden apple applies source absorptionIV, regenerationII and five-minute resistance effects")
	var art: Array = BlockMesher._empty(); Trials.mesh(art,Vector3.ZERO,Trials.VAULT)
	t.check(not art[0].is_empty(),"trial cage and vault have real mesh geometry")
	world.set_node(v,Nodes.AIR)
	t.check(not world.stations.has(VoxelWorld.station_key(v)),"breaking a vault removes its local claims and pending rewards")
	# Exercise the ordinary generator -> worker result -> installation route.
	var plan: Dictionary = TrialChambers.plan(world.generator,Vector2i.ZERO)
	var room: Dictionary = {}
	for piece in plan.pieces:
		if "spawner" in piece.name: room = piece; break
	if not room.is_empty():
		var column := Vector2i(floori(room.origin.x/16.0),floori(room.origin.z/16.0))
		var generated: Dictionary = world.generator.generate_column(column,{},false)
		world._apply_column(generated)
		var installed: int = 0
		for pos in generated.trials.stations:
			var record: Dictionary = generated.trials.stations[pos]
			if record.has("mob") and Vector2i(pos.x >> 4,pos.z >> 4) == column and world.node_at(pos) == Trials.SPAWNER:
				installed += 1
				t.check(Trials.station(world,pos).mob == record.mob,"generated source trial spawner keeps its configured species through installation")
		t.check(installed > 0,"natural chamber source templates produce playable trial spawners")
		var snapshot: Dictionary = game.dimension_snapshot()
		t.check(snapshot.stations.size() >= installed,"normal world snapshots contain installed trial station state")
	else: t.check(false,"seed fixture has a source spawner room")
	# Destruction does not despawn survivors; external removal does not respawn.
	var orphan_pos := Vector3i(8,734,8); world.set_node(orphan_pos,Trials.SPAWNER)
	var orphan_state: Dictionary = Trials.station(world,orphan_pos)
	t.check(Trials.spawn_one(world,orphan_pos,orphan_state,false),"a trial survivor fixture spawns")
	var orphan_key: String = orphan_state.mobs.keys()[0]
	world.set_node(orphan_pos,Nodes.AIR)
	t.check(Trials.orphans(world).has(orphan_key),"breaking a cage preserves its surviving enemy in world state")
	var survivor: Creature = Trials.runtime(world).mobs[orphan_key]
	world.set_node(orphan_pos,Trials.SPAWNER)
	var replacement: Dictionary = Trials.station(world,orphan_pos)
	Trials.spawn_one(world,orphan_pos,replacement,false)
	t.check(not replacement.mobs.has(orphan_key),"replacing a cage cannot reuse a surviving enemy identity")
	survivor.queue_free(); await t.process_frame
	Trials.update(world,0)
	t.check(not Trials.orphans(world).has(orphan_key) and not Trials.runtime(world).mobs.has(orphan_key),"an externally removed trial enemy is pruned and cannot resurrect")
	for mob in live(game): mob.hit(10000,Vector3.INF,"magic")
	world.set_node(orphan_pos,Nodes.AIR)
	# Source containers retain player contents after merging and rediscovery.
	var chest_a := Vector3i(4,735,4); var chest_b: Vector3i = chest_a+Vector3i.RIGHT
	world.set_node(chest_a,Nodes.CHEST); world.set_node(chest_b,Nodes.CHEST)
	TrialChambers.fill_container(world,chest_a,"trial_chambers_chest_entrance_loot")
	TrialChambers.fill_container(world,chest_b,"trial_chambers_chest_entrance_loot")
	var storage: Dictionary = world.get_station(chest_a,"chest")
	for i in storage.slots.size(): storage.slots[i] = {"id":0,"count":0,"wear":0}
	storage.slots[31] = {"id":Nodes.DIAMOND,"count":17,"wear":0}
	var original: Array = storage.slots.duplicate(true)
	TrialChambers.fill_container(world,chest_a,"trial_chambers_chest_entrance_loot")
	TrialChambers.fill_container(world,chest_b,"trial_chambers_chest_entrance_loot")
	t.check(storage.slots == original,"revisiting paired trial chests preserves empty slots and player diamonds")
	PotionEffects.clear(game.player)
	Trials.reset(world)
	game.state = "paused"
