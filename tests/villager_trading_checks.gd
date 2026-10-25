extends RefCounted
static func resident(game: Node3D, profession: String, at: Vector3) -> VillageMob:
	var mob: VillageMob = game.spawn_creature("villager",at); mob.set_physics_process(false)
	var p: Dictionary = game.villages.make_record(mob.person_key,profession,at,Vector3i(at),Vector3i(at),Vector3i(at)); mob.bind(p)
	return mob
static func xp(game: Node3D) -> int:
	var result: int = 0
	for orb in XpOrbs.orbs(game): result += orb.xp
	return result
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.save_game("user://trading_baseline.json"); var baseline: Dictionary = game.read_save("user://trading_baseline.json")
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.player.position = Vector3(11,2000,8); game.day_time = 0.35; game.gamemode = "survival"
	for x in range(5,16):
		for z in range(5,13):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var cleric: VillageMob = resident(game,"cleric",Vector3(8.5,2000,8.5)); var p: Dictionary = game.villages.record(cleric.person_key)
	t.check(p.offers.size() == 2 and p.offers.all(func(o): return o.tier == 1),"a fresh cleric rolls only its two Novice offers")
	var initial_rng: int = p.trade_rng; var first: Dictionary = p.offers[0]
	cleric.health = 10; p.health = 10; game.inventory.restore([]); game.inventory.add_item(Nodes.ROTTEN_FLESH,64)
	var before_xp: int = xp(game)
	game.villages.open(cleric); game.villages.trade(p.key,0)
	t.check(p.level == 1 and p.xp == 12 and p.levelup_in == 2 and p.offers.size() == 2,"a threshold-crossing trade schedules a two-second promotion without exposing new offers")
	t.check(game.villages.costs(p,first)[0][1] == 31,"the real trade callback refreshes prices using its newly earned reputation")
	t.check(cleric.health == 10 and xp(game)-before_xp >= 9 and xp(game)-before_xp <= 11,"the trade grants normal plus qualification XP and does not heal immediately")
	game._process(1.9)
	t.check(p.level == 1 and p.levelup_in > 0,"the open trading screen waits through the promotion delay")
	game._process(0.11)
	t.check(p.level == 2 and p.offers.size() == 4 and p.trade_rng != initial_rng,"promotion activates only the next tier and advances the saved offer RNG")
	t.check(p.offers[0] == first and first.uses == 1 and game.hud.screen == "trading","promotion preserves previous trades and refreshes the open trading panel")
	t.check(PotionEffects.level(cleric,"regeneration") == 1 and cleric.health == 10,"promotion grants timed Regeneration I instead of an immediate four-point heal")
	PotionEffects.update(cleric,2.5)
	t.check(cleric.health == 11,"the promotion's regeneration heals through the normal effect timer")
	# Every qualifying purchase restarts the delay and grants its five XP.
	p.xp = 69; game.inventory.add_item(Nodes.ROTTEN_FLESH,64)
	before_xp = xp(game); game.villages.trade(p.key,0); game._process(1)
	game.inventory.add_item(Nodes.ROTTEN_FLESH,64); game.villages.trade(p.key,0)
	t.check(p.level == 2 and p.levelup_in == 2 and xp(game)-before_xp >= 18 and xp(game)-before_xp <= 22,"another qualifying trade restarts the delay and grants its own bonus XP")
	game._process(1.99); t.check(p.level == 2,"a restarted promotion waits another full two seconds")
	game._process(0.02); t.check(p.level == 3 and p.offers.size() == 6,"the rescheduled promotion adds the Journeyman tier once")
	p.xp = 999; game.inventory.add_item(Nodes.ROTTEN_FLESH,64); game.villages.trade(p.key,0); game._process(2.1)
	t.check(p.level == 4,"an oversized XP balance advances one tier per scheduled promotion")
	game._process(3); t.check(p.level == 4,"excess XP alone does not schedule another promotion")
	# Restocking follows the reference's next-day and strict cooldown branches.
	var farmer: VillageMob = resident(game,"farmer",Vector3(12.5,2000,8.5)); var f: Dictionary = game.villages.record(farmer.person_key)
	f.restock_day = -1; f.restock_time = -1; game.villages.restock(f,100,5)
	t.check(f.restock_time == 100 and f.restock_day == -1 and f.restocks == 2,"a first workstation visit starts the clock without consuming a restock")
	f.offers[0].uses = 16; game.villages.restock(f,101,5)
	t.check(f.restocks == 1 and f.offers[0].uses == 0 and f.offers[0].demand == 16,"the first used offer restocks and updates every active offer's demand")
	f.offers[0].uses = 1; game.villages.restock(f,221,5)
	t.check(f.offers[0].uses == 1,"exactly 120 seconds does not satisfy the second-restock cooldown")
	game.villages.restock(f,221.01,5)
	t.check(f.offers[0].uses == 0 and f.restocks == 0,"the second restock becomes eligible strictly after 120 seconds")
	f.offers[0].uses = 3; game.villages.restock(f,900,5)
	t.check(f.offers[0].uses == 3 and f.restocks == 2,"the 600-second fallback renews allowance without restocking when no prior allowance remains")
	game.villages.restock(f,900.1,5)
	t.check(f.offers[0].uses == 0 and f.restocks == 1,"a subsequent workstation check performs the renewed restock")
	f.restocks = 2; f.offers[0].uses = 16; f.offers[0].demand = 0; game.villages.restock(f,901,6)
	t.check(f.offers[0].demand == 0 and f.offers[0].uses == 0 and f.restocks == 2,"a new day catches up both unused restocks and returns without consuming today's allowance")
	# Legacy pre-rolled offers are retained verbatim for their eventual unlock.
	var legacy: Dictionary = {"level":1,"xp":0,"profession":"farmer","offers":[{"tier":1,"uses":3,"data":{"custom_name":"Old"}},{"tier":2,"uses":0,"data":{"enchantments":{"Mending":1}}}],"restock_day":4,"restock_time":50,"restocks":1}
	VillagerTrading.initialize(legacy,123); var held: Dictionary = legacy.future_offers[0].duplicate(true)
	t.check(legacy.offers.size() == 1 and legacy.future_offers.size() == 1 and legacy.offers[0].uses == 3,"legacy saves retain active stock and archive their pre-rolled locked offers")
	legacy.level = 2; VillagerTrading.activate(legacy,2)
	t.check(legacy.offers.size() == 2 and legacy.offers[1] == held and legacy.future_offers.is_empty(),"legacy offers keep their original metadata and counts when unlocked")
	# Pending promotions and regeneration must survive an actual world reload.
	game.pause(); p.levelup_in = 1.25; p.xp = 999; cleric.store_record(); farmer.store_record()
	var key: String = cleric.person_key; var rng_state: int = p.trade_rng; var offer_count: int = p.offers.size()
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var freeze: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(saved); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.villages.timer = 0; game.villages.update(0)
	game.pause(); game.set_process(false); game.world.set_process(false); game.creatures.child_entered_tree.disconnect(freeze)
	p = game.villages.record(key); cleric = null
	for mob in game.creatures.get_children():
		if mob is VillageMob and mob.person_key == key: cleric = mob
	t.check(p.levelup_in == 1.25 and int(p.trade_rng) == rng_state and p.offers.size() == offer_count,"world reload preserves pending promotion, active offers and future random-stream position")
	t.check(cleric != null and PotionEffects.level(cleric,"regeneration") == 1,"villager regeneration survives world reload")
	VillagerTrading.tick(cleric,1.26)
	t.check(p.level == 5 and p.offers.size() == 10,"the resumed promotion unlocks Master without duplicating earlier offers")
	var zombie: Creature = game.spawn_creature("zombie_villager",cleric.position,"",{"baby":false,"jockey":false}); zombie.set_physics_process(false)
	p.levelup_in = 1; ZombieVillagers.infect(game,zombie,p)
	t.check(zombie.get_meta("incarnation").levelup_in == 0 and not zombie.get_meta("incarnation").has("effects"),"infection exports trade identity but drops the pending promotion and active potion effects like the source")
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(baseline); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	deadline = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(freeze); game.pause(); game.set_process(false); game.world.set_process(false); game.villages.timer = 0
	t.check(game.state == "paused","the trading fixture restores the original world for later checks")
