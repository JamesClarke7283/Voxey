extends RefCounted
static func resident(game: Node3D, at: Vector3, profession: String = "farmer") -> VillageMob:
	var mob: VillageMob = game.spawn_creature("villager",at); mob.set_physics_process(false)
	var p: Dictionary = game.villages.record(mob.person_key); p.profession = profession; mob.profession = profession
	p.gossips = {}; p.reputations = {}; return mob
static func memory(game: Node3D, mob: VillageMob) -> Dictionary: return game.villages.record(mob.person_key)
static func same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for player in a:
		if not b.has(player) or a[player].size() != b[player].size(): return false
		for kind in a[player]:
			if not b[player].has(kind) or int(a[player][kind]) != int(b[player][kind]): return false
	return true
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.save_game("user://gossip_baseline.json")
	var baseline: Dictionary = game.read_save("user://gossip_baseline.json")
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.villages.state().clock = 100; game.gamemode = "survival"; game.day_time = 0.67
	game.player.position = Vector3(20.5,2000,15.5)
	for x in range(3,29):
		for z in range(3,19):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var migration_ok: bool = true
	for score in range(-620,81):
		var old: Dictionary = {"reputations":{"player":score,"another":-7}}
		VillagerGossip.initialize(old)
		migration_ok = migration_ok and VillagerGossip.reputation(old,"player") == clampi(score,-600,65) and VillagerGossip.reputation(old,"another") == -7
	t.check(migration_ok,"legacy standing migrates across the full representable range while retaining other players")
	var identity := PlayerIdentity.new("/tmp/nonexistent-voxey-gossip-identity"); identity.legacy_offline_id = "previous"
	var migrated: Dictionary = {"gossip_version":1,"gossips":{"previous":{"major_positive":20},"another":{"minor_negative":3}},"reputations":{"previous":20}}
	identity.migrate_save(migrated); VillagerGossip.initialize(migrated)
	t.check(VillagerGossip.reputation(migrated,"player") == 20 and VillagerGossip.reputation(migrated,"another") == -3,"offline identity migration includes typed memories")
	VillagerGossip.record(migrated,"player","major_positive",-5)
	t.check(migrated.gossips.previous.major_positive == 20 and migrated.gossips.player.major_positive == 15,"migrated player memories do not alias the preserved legacy identity")
	var a: VillageMob = resident(game,Vector3(8.5,2000,8.5)); var b: VillageMob = resident(game,Vector3(10.5,2000,8.5))
	var pa: Dictionary = memory(game,a); var pb: Dictionary = memory(game,b)
	var offer: Dictionary = {"tier":1,"cost":[[VillageContent.EMERALD,20]],"give":[Nodes.BREAD,1],"uses":0,"stock":100,"xp":0,"data":{},"demand":0,"multiplier":0.2}
	pa.offers = [offer]; pa.level = 1; game.inventory.restore([]); game.inventory.add_item(VillageContent.EMERALD,64)
	game.villages.open(a)
	t.check(game.state == "trading" and game.villages.costs(pa,offer)[0][1] == 20,"opening trade captures the player's starting reputation")
	for i in 5: game.villages.transaction(pa,offer,true)
	# The first three trades use sixty emeralds, so replenish and finish the remaining trades.
	game.inventory.add_item(VillageContent.EMERALD,64)
	while offer.uses < 5: game.villages.transaction(pa,offer,true)
	t.check(pa.gossips.player.trading == 10 and game.villages.reputation(pa) == 10,"successful trades add two trading memory each")
	t.check(game.villages.costs(pa,offer)[0][1] == 20,"a low-level transaction keeps the current quote until the trade UI refreshes")
	t.check(not pb.gossips.has("player"),"transactions do not broadcast reputation to nearby villagers")
	game.state = "paused"; game.villages.open(a)
	t.check(game.villages.costs(pa,offer)[0][1] == 18,"reopening the trade panel applies accumulated trading reputation")
	PotionEffects.apply(game.player,"hero_of_village",120,1); game.state = "paused"; game.villages.open(a)
	t.check(game.villages.costs(pa,offer)[0][1] == 12,"hero discount uses the source thirty-six-and-a-quarter-percent factor after reputation")
	PotionEffects.clear_one(game.player,"hero_of_village")
	t.check(game.villages.costs(pa,offer)[0][1] == 12,"hero prices remain captured until the next trade UI refresh")
	game.pause(); game.state = "paused"; pa.gossips = {}; pa.reputations = {}
	# The recipient's one-minute cooldown applies even to a different speaker.
	VillagerGossip.record(pa,"player","major_negative",25); VillagerGossip.record(pa,"player","minor_positive",25); VillagerGossip.record(pa,"player","major_positive",20); VillagerGossip.record(pa,"player","trading",20)
	VillagerSocial.emit_share(a,b)
	t.check(pb.gossips.player.major_negative == 15 and pb.gossips.player.minor_positive == 20 and pb.gossips.player.major_positive == 0 and pb.gossips.player.trading == 0,"social conversation transfers each memory with its own decay")
	t.check(VillagerGossip.reputation(pb,"player") == -55,"mixed good and bad memories retain their independent weights")
	var c: VillageMob = resident(game,Vector3(12.5,2000,8.5)); var pc: Dictionary = memory(game,c)
	VillagerGossip.record(pc,"player","major_negative",100)
	game.villages.state().clock = 159; VillagerSocial.emit_share(c,b)
	t.check(pb.gossips.player.major_negative == 15,"a second speaker cannot bypass the recipient's global cooldown")
	game.villages.state().clock = 160; VillagerSocial.emit_share(c,b)
	t.check(pb.gossips.player.major_negative == 90,"the next conversation is eligible exactly sixty seconds later")
	# Hurt events require actual accepted damage attributed to this player.
	pa.gossips = {}; pa.reputations = {}; a.health = 20; a.hit(1,game.player.position,"player_melee",0,game.player)
	t.check(pa.gossips.player.minor_negative == 25 and game.villages.reputation(pa) == -25,"a surviving player hit adds twenty-five minor-negative memory")
	a.spawn_invulnerable = 1; a.hit(1,game.player.position,"player_melee",0,game.player); a.spawn_invulnerable = 0
	t.check(pa.gossips.player.minor_negative == 25,"rejected damage does not add gossip")
	var cow: Creature = game.spawn_creature("cow",Vector3(14.5,2000,8.5)); cow.set_physics_process(false)
	a.hit(1,cow.position,"mob_melee",0,cow); a.hit(1,Vector3.INF,"fall")
	t.check(pa.gossips.player.minor_negative == 25,"NPC and environmental damage are not blamed on the player")
	a.hit(1,Vector3(18,2001,8),"arrow",0,game.player)
	t.check(pa.gossips.player.minor_negative == 50,"a projectile hit uses its explicit shooter for reputation")
	# Witnesses must be villagers, visible, alive and within sixteen blocks.
	pa.gossips = {}; pa.reputations = {}; pb.gossips = {}; pb.reputations = {}; pc.gossips = {}; pc.reputations = {}
	var blocked: VillageMob = resident(game,Vector3(8.5,2000,14.5)); var far: VillageMob = resident(game,Vector3(26,2000,8.5))
	for x in range(6,11):
		for y in range(2000,2003): game.world.set_node(Vector3i(x,y,11),Nodes.STONE)
	t.check(not a._sees(blocked.center()) and a._sees(b.center()),"witness scene contains both a clear view and an opaque wall")
	a.hit(1000,game.player.position,"player_melee",0,game.player)
	t.check(a.is_queued_for_deletion() and pa.gossips.player.major_negative == 25 and not pa.gossips.player.has("minor_negative"),"a lethal hit records major gossip without adding a surviving-hit penalty")
	t.check(pb.gossips.player.major_negative == 25 and pc.gossips.player.major_negative == 25,"visible nearby villagers report the murder")
	t.check(memory(game,blocked).gossips.is_empty() and memory(game,far).gossips.is_empty(),"walls and the sixteen-block witness radius prevent distant reports")
	var iron: VillageMob = game.spawn_creature("iron_golem",Vector3(11,2000,8.5)); iron.set_physics_process(false)
	t.check(iron.iron_target() == game.player,"a witnessed murder crosses the golem's negative-one-hundred threshold")
	pb.gossips = {}; pc.gossips = {}; VillagerGossip.record(pb,"player","minor_negative",100)
	t.check(iron.iron_target() == null,"a standing of exactly negative one hundred does not trigger golem aggression")
	# Curing merges positive memories into the restored villager and persists them.
	var before_key: String = b.person_key; VillagerGossip.record(pb,"player","trading",12)
	var zombie: Creature = game.spawn_creature("zombie_villager",b.position,"",{"baby":false,"jockey":false}); zombie.set_physics_process(false)
	ZombieVillagers.infect(game,zombie,pb); b.queue_free(); zombie.set_meta("curing",true); zombie.set_meta("curer","player"); zombie.set_meta("cure_timer",0.01)
	ZombieVillagers.update(game,zombie,1)
	var restored: VillageMob
	for mob in game.creatures.get_children():
		if mob is VillageMob and not mob.is_queued_for_deletion() and mob.person_key == before_key: restored = mob; mob.set_physics_process(false)
	var pr: Dictionary = memory(game,restored)
	t.check(pr.gossips.player.major_positive == 20 and pr.gossips.player.minor_positive == 25 and pr.gossips.player.trading == 12 and pr.gossips.player.minor_negative == 100,"curing adds both positive memories while preserving the villager's previous history")
	t.check(game.villages.reputation(pr) == -43,"cure reputation combines with the pre-existing grudge and trading history")
	pr.gossip_decay_at = 100; VillagerGossip.step(pr,1300)
	t.check(pr.gossips.player.major_positive == 20 and pr.gossips.player.minor_positive == 24 and pr.gossips.player.trading == 10 and pr.gossips.player.minor_negative == 80,"one game day decays each memory at its source rate")
	VillagerGossip.step(pr,10000)
	t.check(pr.gossips.player.trading == 8 and pr.gossip_decay_at == 10000,"a long gap decays once on the next active step without catch-up loops")
	restored.store_record(); game.save_game()
	var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var expected: Dictionary = pr.gossips.duplicate(true)
	var freeze: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(saved); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(freeze); game.pause(); game.set_process(false); game.world.set_process(false)
	var reloaded: Dictionary = game.villages.record(before_key)
	t.check(same(reloaded.gossips,expected) and reloaded.gossip_version == 1 and reloaded.gossip_decay_at == 10000 and reloaded.gossip_received_at == 160,"world reload preserves typed memories and both gossip clocks")
	# A social meeting retains its golem request even when no gossip may transfer.
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.villages.state().clock = 2000
	var crowd: Array = []
	for i in 5:
		var mob: VillageMob = resident(game,Vector3(7.5+i,2000,6.5)); crowd.append(mob)
		memory(game,mob).slept_at = 2000
	memory(game,crowd[1]).gossip_received_at = 2000
	VillagerSocial.emit_share(crowd[0],crowd[1])
	t.check(game.creatures.get_children().filter(func(m): return m.kind == "iron_golem" and not m.is_queued_for_deletion()).size() == 1,"social conversation can summon a golem during the recipient's gossip cooldown")
	var timed: Dictionary = memory(game,crowd[0]); VillagerGossip.record(timed,"player","trading",20); timed.gossip_decay_at = 100
	game.villages.state().clock = 1299.5; game.villages.timer = 0; game.villages.update(0.5)
	t.check(timed.gossips.player.trading == 18 and timed.gossip_decay_at == 1300,"loaded villagers apply daily gossip decay from the active village clock")
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(baseline); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	deadline = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(freeze); game.pause(); game.set_process(false); game.world.set_process(false); game.villages.timer = 0
	t.check(game.state == "paused","the gossip fixture restores the original world and loaded area for later suites")
