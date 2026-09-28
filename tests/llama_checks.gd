extends RefCounted

# Focused regression for llamas: statistics, strength and coats, food and temper
# taming, chests sized by strength, carpets, breeding, following a hay bale,
# spitting back and at wolves, wolves' fear of llamas, caravans, persistence,
# death drops and spawning. Reference: mobs_mc/{llama,wolf,wandering_trader}.lua.

static func spawned(kind: String, game: Node3D, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	if mob != null: mob.set_physics_process(false)
	return mob

static func hold(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.slots[game.inventory.selected] = {"id":id,"count":count,"wear":0}

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position
	var old_mode: String = game.gamemode
	game.gamemode = "survival"
	game.inventory.selected = 0
	game.survival.mount = null
	for mob in game.creatures.get_children(): mob.free()
	var arena := Vector3i(8,170,8)
	for x in range(-18,19):
		for z in range(-18,19):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.GRASS)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,8.5)

	# --- registry and statistics ------------------------------------------------------
	var info: Dictionary = Creature.KINDS["llama"]
	suite.check(is_equal_approx(info.health,15.0) and info.drops == [[Nodes.LEATHER,0,2]] and int(info.xp_max) == 3,"a llama has the source's health floor, zero to two leather and one to three experience")
	suite.check(Equines.is_equine("llama") and not Equines.is_equine("trader_llama") and not Creature.PASSIVE.has("llama"),"the wild llama joins the horse family and never spawns from the generic pool")
	suite.check(not bool(info.get("runaway",true)),"a struck llama stands and spits rather than fleeing at once")
	suite.check(Creature.KINDS["wolf"].get("runaway_from",[]).has("llama") and Creature.KINDS["wolf"].get("runaway_from",[]).has("trader_llama"),"wolves keep away from llamas and trader llamas")
	suite.check(Llamas.roll_strength(0.03,4) == 5 and Llamas.roll_strength(0.5,4) == 3 and Llamas.roll_strength(0.5,0) == 1,"strength is 1 + random(0, 4) at a 4% chance, otherwise 1 + random(0, 2)")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var strengths: Dictionary = {}
	var coats: Dictionary = {}
	for i in 400:
		var probe := Node3D.new()
		Llamas.initialize(probe,rng)
		strengths[Llamas.strength(probe)] = true
		coats[Llamas.coat(probe)] = int(coats.get(Llamas.coat(probe),0))+1
		probe.free()
	suite.check(strengths.has(1) and strengths.has(3) and not strengths.has(6),"rolled strengths fall between one and five")
	suite.check(coats.size() == 4 and int(coats.creamy) > int(coats.brown),"four coats, with creamy twice as common because the default texture is creamy")
	var llama: Creature = spawned("llama",game,Vector3(arena)+Vector3(0.5,0,0.5))
	suite.check(llama is RuralAnimal and llama.head != null and Llamas.COAT_NAMES.has(Llamas.coat(llama)),"a llama spawns with a coat and a body")
	suite.check(Equines.max_health(llama) >= 15.0 and Equines.max_health(llama) <= 32.0,"a llama rolls the horse's health")
	suite.check(Llamas.child_strength(3,2,3,0.5) == 3 and Llamas.child_strength(3,2,2,0.01) == 3 and Llamas.child_strength(5,5,5,0.01) == 5 and Llamas.child_strength(2,1,9,0.9) == 2,"a cria's strength is random(1, max) with a 5% bonus that stops at five")

	# --- food and taming -------------------------------------------------------------------
	llama.health = 3.0
	hold(game,Nodes.GRAIN,4)
	Equines.use(game,llama)
	suite.check(is_equal_approx(llama.health,5.0) and Equines.temper(llama) == 3 and game.inventory.held().count == 3,"wheat heals two and adds three temper")
	hold(game,Nodes.HAY_BALE,4)
	Equines.use(game,llama)
	suite.check(is_equal_approx(llama.health,15.0) or llama.health >= 14.9,"a hay bale heals ten")
	suite.check(Equines.temper(llama) == 9,"and adds six temper")
	for i in 6: Equines.feed(game,llama,Nodes.HAY_BALE)
	suite.check(Equines.temper(llama) == Llamas.MAX_TEMPER and Equines.max_temper("llama") == 30 and Equines.max_temper("horse") == 120,"a llama's temper stops at thirty")
	hold(game,Nodes.HAY_BALE,1)
	var hay_before: int = game.inventory.held().count
	Equines.use(game,llama)
	suite.check(llama.love_time <= 0.0 and game.inventory.held().count == hay_before,"an untamed llama at full temper and health does not eat or breed")
	hold(game,Nodes.CHEST,1)
	Equines.use(game,llama)
	suite.check(not llama.has_meta("equine_chest"),"an untamed llama takes no chest")
	hold(game,0,0)
	Equines.use(game,llama)
	suite.check(game.survival.mount == llama and bool(llama.get_meta("evaluating",false)),"an empty hand mounts an untamed llama to tame it")
	suite.check(Equines.evaluate(game,llama,10.0,rng) == "tamed" and Equines.tamed(llama),"at full temper the evaluation always tames")
	suite.check(not Equines.drivable(llama),"a llama is never steered")
	llama.saddled = true
	suite.check(not Equines.drivable(llama),"not even with a saddle")
	llama.saddled = false
	var think_before: float = llama.think
	llama.think = 0.0
	Equines.ridden_wander(llama,0.05)
	suite.check(llama.think >= 1.5 and llama.think != think_before,"a llama carrying a rider keeps pacing on its own")
	game.survival.mount = null

	# --- chest and carpet -------------------------------------------------------------------
	llama.set_meta("llama_strength",2)
	hold(game,Nodes.CHEST,1)
	Equines.use(game,llama)
	suite.check(Equines.chest(llama).size() == 6 and Equines.chest_slots(llama) == 6 and game.inventory.held().count == 0,"a tamed llama of strength two takes a chest of six slots")
	hold(game,Nodes.SADDLE,1)
	Equines.use(game,llama)
	suite.check(not llama.saddled and game.inventory.held().count == 1,"a llama takes no saddle")
	game.survival.mount = null
	hold(game,VillageContent.CARPET_RED,2)
	Equines.use(game,llama)
	suite.check(Llamas.carpet(llama) == VillageContent.CARPET_RED and game.inventory.held().count == 1,"a carpet goes on as the llama's decor")
	hold(game,VillageContent.CARPET_BLUE,1)
	Equines.use(game,llama)
	suite.check(Llamas.carpet(llama) == VillageContent.CARPET_RED and game.inventory.held().count == 1,"a second carpet does not replace the first")
	game.survival.mount = null
	for child in game.drops.get_children(): child.free()
	hold(game,Nodes.SHEARS,1)
	Equines.use(game,llama)
	var sheared: Array = []
	for drop in game.drops.get_children(): sheared.append(drop.item_id)
	suite.check(Llamas.carpet(llama) == 0 and sheared.has(VillageContent.CARPET_RED),"shears take the carpet back")
	for child in game.drops.get_children(): child.free()
	suite.check(Llamas.is_carpet(VillageContent.CARPET_BLUE) and not Llamas.is_carpet(Nodes.GRAIN),"only the sixteen carpets count as decor")

	# --- following and breeding ------------------------------------------------------------------
	var follower: Creature = spawned("llama",game,Vector3(arena)+Vector3(0.5,0,4.5))
	hold(game,Nodes.HAY_BALE,1)
	var lure: Vector3 = Equines.follow_direction(game,follower)
	suite.check(lure != Vector3.INF and lure.z > 0.9,"a llama walks after a player holding a hay bale")
	follower.position = Vector3(arena)+Vector3(0.5,0,7.5)
	suite.check(Equines.follow_direction(game,follower) == Vector3.ZERO,"and stops within two")
	follower.position = Vector3(arena)+Vector3(0.5,0,-4.5)
	suite.check(Equines.follow_direction(game,follower) == Vector3.INF,"but only from within six")
	hold(game,Nodes.GRAIN,1)
	follower.position = Vector3(arena)+Vector3(0.5,0,4.5)
	suite.check(Equines.follow_direction(game,follower) == Vector3.INF,"wheat is food but not a lure")
	var horse: Creature = spawned("horse",game,Vector3(arena)+Vector3(-3.5,0,6.5))
	hold(game,VillageContent.GOLDEN_CARROT,1)
	suite.check(Equines.follow_direction(game,horse) != Vector3.INF,"a horse follows a golden carrot")
	horse.free()
	suite.check(Equines.mate_kind("llama","llama") == "llama" and Equines.mate_kind("llama","horse") == "" and Equines.breeds("llama"),"llamas breed only with llamas")
	var mate: Creature = spawned("llama",game,Vector3(arena)+Vector3(2.5,0,0.5))
	mate.trust = Equines.TAMED_TRUST
	llama.set_meta("owner","tester")
	llama.set_meta("llama_strength",4); mate.set_meta("llama_strength",2)
	var cria: Node3D = Equines.make_foal(game,llama,mate,rng)
	suite.check(cria != null and cria.kind == "llama" and cria.growth_remaining > 0.0 and cria.has_meta("persistent"),"two llamas make a cria")
	suite.check(cria != null and Llamas.strength(cria) >= 1 and Llamas.strength(cria) <= 5,"the cria's strength stays in range")
	suite.check(cria != null and not Equines.tamed(cria),"the source copies an owner onto the cria but not the tamed flag")
	if cria != null: cria.free()
	hold(game,Nodes.HAY_BALE,1)
	llama.love_time = 0.0; llama.breed_cooldown = 0.0
	Equines.use(game,llama)
	suite.check(llama.love_time > 0.0,"a hay bale puts a tamed llama in love")
	llama.love_time = 0.0

	# --- spit --------------------------------------------------------------------------------------
	var origin := Vector3(0,1.6,0)
	var heading: Vector3 = Llamas.aim(origin,Vector3(10,1.6,0))
	suite.check(heading.y > 0.03 and heading.x > 0.99,"spit is aimed a little high, by 0.04 of the distance")
	var sheep: Creature = spawned("sheep",game,Vector3(arena)+Vector3(-6.5,0,-6.5))
	var sheep_health: float = sheep.health
	var gob: Node3D = Llamas.discharge(game,mate,sheep.center())
	suite.check(gob is Llamas.Spit and is_equal_approx(gob.velocity.length(),Llamas.SPIT_SPEED),"a llama spits at forty")
	gob.position = sheep.center()
	suite.check(gob.hit_something() and sheep.health < sheep_health and sheep.health >= sheep_health-1.01,"spit deals one to the mob it meets")
	var own: Node3D = Llamas.discharge(game,mate,sheep.center())
	own.position = mate.center()
	sheep.position += Vector3(0,0,30)
	suite.check(not own.hit_something(),"spit never hits its own llama")
	own.free()
	sheep.free()
	# Retaliation: struck by the player, the llama spits once, then flees what is left
	# of its five seconds.
	var angry: Creature = spawned("llama",game,Vector3(arena)+Vector3(0.5,0,-2.5))
	angry.hit(1.0,game.player.position)
	angry.set_meta("player_struck",true)
	Llamas.targeting_step(game,angry,0.05)
	suite.check(Llamas.target(angry) == game.player and Llamas.rule(angry) == "retaliate","a struck llama turns on the player who struck it")
	suite.check(angry.scared <= 0.0,"it does not flee first")
	suite.check(Llamas.direction(game,angry) != Vector3.INF,"it holds its ground or closes in while it aims")
	suite.check(Llamas.attack_step(game,angry,1.0) == null,"it waits out the four-second ranged timer")
	angry.set_meta("llama_seen",1.0)
	var shot: Node3D = Llamas.attack_step(game,angry,3.5)
	suite.check(shot != null and Llamas.has_spit(angry),"then spits")
	if shot != null: shot.free()
	angry.life = float(angry.get_meta("llama_hit_at"))+4.0
	Llamas.targeting_step(game,angry,0.05)
	suite.check(Llamas.target(angry) == null and angry.scared > 0.5 and angry.scared <= 1.01,"after one spit it calls the attack off and flees for the rest of its five seconds")
	game.gamemode = "creative"
	angry.set_meta("player_struck",true)
	Llamas.targeting_step(game,angry,0.05)
	suite.check(Llamas.target(angry) == null,"a creative player is never spat at")
	game.gamemode = "survival"
	angry.set_meta("llama_seek",0.0)
	# Wolves.
	var wolf: Creature = spawned("wolf",game,Vector3(arena)+Vector3(6.5,0,-2.5))
	Llamas.targeting_step(game,angry,0.05)
	suite.check(Llamas.target(angry) == wolf and Llamas.rule(angry) == "wolf","a llama spits at an untamed wolf within ten")
	Llamas.end_attack(angry)
	Wolves.tame(wolf,game.player_id)
	angry.set_meta("llama_seek",0.0)
	Llamas.targeting_step(game,angry,0.05)
	suite.check(Llamas.target(angry) == null,"but leaves a tamed wolf alone")
	wolf.free()
	var strong: Creature = spawned("llama",game,Vector3(arena)+Vector3(-10.5,0,-10.5))
	strong.set_meta("llama_strength",5)
	var runner: Creature = spawned("wolf",game,Vector3(arena)+Vector3(-10.5,0,-2.5))
	suite.check(runner.runaway_threat(["llama","trader_llama"],16.0).distance_to(strong.position) < 0.01,"a wolf within sixteen of a strength-five llama runs from it")
	var fled: int = 0
	var roller := RandomNumberGenerator.new(); roller.seed = 11
	strong.set_meta("llama_strength",1)
	for i in 400:
		runner.remove_meta("avoiding_llama")
		if Llamas.frightens(runner,strong,roller): fled += 1
	suite.check(fled > 100 and fled < 220,"a strength-one llama frightens a wolf about two times in five")
	runner.set_meta("avoiding_llama",strong.get_instance_id()); runner.set_meta("avoid_until",runner.life+1.0)
	suite.check(Llamas.frightens(runner,strong,roller),"a wolf already running keeps running")
	runner.free(); strong.free()
	angry.free()

	# --- caravans ------------------------------------------------------------------------------------
	mate.free()
	follower.free()
	var lead: Creature = spawned("llama",game,Vector3(arena)+Vector3(-12.5,0,10.5))
	var second: Creature = spawned("llama",game,Vector3(arena)+Vector3(-7.5,0,10.5))
	var third: Creature = spawned("llama",game,Vector3(arena)+Vector3(-2.5,0,10.5))
	game.leads.attach(lead,false)
	suite.check(Llamas.leashed(game,lead) and not Llamas.leashed(game,second),"a llama on a lead leads a caravan")
	Llamas.caravan_step(game,second,0.05)
	suite.check(Llamas.head(second) == lead and Llamas.tail(lead) == second,"a llama within nine joins the leashed one")
	Llamas.caravan_step(game,third,0.05)
	suite.check(Llamas.head(third) == second and Llamas.count_ahead(third) == 2,"the next joins the straggler at the end of the line")
	var along: Vector3 = Llamas.caravan_direction(third)
	suite.check(along.x < -1.5 and is_equal_approx(along.length(),Llamas.CARAVAN_SPEED),"it walks after the one ahead at the caravan's pace")
	third.position = second.position+Vector3(2,0,0)
	suite.check(Llamas.caravan_direction(third) == Vector3.ZERO,"and stops within three")
	# Beyond 26 it speeds up, and gives up once that runs out.
	third.position = second.position+Vector3(30,0,0)
	var gave_up: bool = false
	for i in 80:
		Llamas.caravan_step(game,third,0.05)
		if Llamas.head(third) == null: gave_up = true; break
	suite.check(gave_up and Llamas.tail(second) == null,"a llama left beyond 26 gives up once its speed-up runs out")
	# A line of more than seven turns a newcomer away.
	var line: Array = [lead,second]
	for i in 7:
		var link: Creature = spawned("llama",game,Vector3(arena)+Vector3(-12.5+float(i),0,-12.5))
		Llamas.join(link,line.back())
		line.append(link)
	third.position = line.back().position+Vector3(2,0,0)
	third.set_meta("caravan_clock",0.0)
	Llamas.caravan_step(game,third,0.05)
	suite.check(Llamas.count_ahead(line.back()) == 8 and Llamas.head(third) == null,"a straggler with more than seven ahead of it is not joined")
	# Releasing the lead lets the line come apart from the front.
	game.leads.detach(lead,false)
	Llamas.caravan_step(game,lead,0.05)
	suite.check(Llamas.tail(lead) == null and Llamas.head(second) == null,"releasing the lead disbands the front of the caravan")
	for mob in line: mob.free()
	third.free()
	var trader_llama: Creature = spawned("trader_llama",game,Vector3(arena)+Vector3(10.5,0,10.5))
	suite.check(trader_llama.has_meta("llama_strength") and trader_llama.head != null and not Llamas.leashed(game,trader_llama),"a trader llama rolls a llama's strength and coat, and without its trader it is no caravan head")
	suite.check(is_equal_approx(float(Creature.KINDS["trader_llama"].speed),float(info.speed)),"a trader llama walks at a llama's pace")
	trader_llama.free()

	# --- persistence and death ---------------------------------------------------------------------------
	llama.set_meta("llama_strength",4)
	llama.remove_meta("equine_chest")
	Equines.add_chest(llama)
	Equines.chest(llama)[2] = {"id":Nodes.COBBLE,"count":9,"wear":0}
	Llamas.set_carpet(llama,VillageContent.CARPET_BLUE)
	llama.set_meta("llama_coat","gray")
	var record: Dictionary = JSON.parse_string(JSON.stringify(Equines.snapshot(llama)))
	var copy: Creature = spawned("llama",game,Vector3(arena)+Vector3(-6.5,0,-6.5))
	copy.trust = Equines.TAMED_TRUST
	Equines.restore(copy,record)
	suite.check(Llamas.strength(copy) == 4 and Llamas.coat(copy) == "gray" and Llamas.carpet(copy) == VillageContent.CARPET_BLUE,"a llama's strength, coat and carpet survive a save")
	suite.check(Equines.chest(copy).size() == 12 and int(Equines.chest(copy)[2].count) == 9,"its chest keeps its size and contents")
	suite.check(Equines.temper(copy) == Equines.temper(llama),"and its temper")
	var found: Dictionary = {}
	for entry in game.survival.animal_snapshot():
		if entry.kind == "llama" and entry.get("equine",{}).get("llama") is Dictionary: found = entry
	suite.check(not found.is_empty(),"the world's animal snapshot carries the llama record")
	Equines.restore(copy,{"llama":{"strength":99,"coat":"plaid","carpet":Nodes.GRAIN},"temper":1000})
	suite.check(Llamas.strength(copy) == 5 and Llamas.coat(copy) == "gray" and Llamas.carpet(copy) == 0 and Equines.temper(copy) == 30,"a damaged record is clamped rather than trusted")
	copy.free()
	for child in game.drops.get_children(): child.free()
	llama.die()
	var drops: Dictionary = {}
	for drop in game.drops.get_children(): drops[drop.item_id] = int(drops.get(drop.item_id,0))+drop.amount
	suite.check(drops.has(Nodes.CHEST) and drops.has(VillageContent.CARPET_BLUE) and int(drops.get(Nodes.COBBLE,0)) == 9,"a dying llama drops its chest, its contents and its carpet")
	for child in game.drops.get_children(): child.free()

	# --- spawning --------------------------------------------------------------------------------------
	suite.check(is_equal_approx(Llamas.spawn_share("Frostpine highlands"),5.0/45.0) and Llamas.spawn_share("Oakwood meadow") == 0.0,"llamas spawn only in the highlands, at weight five")
	var pack: Array = Llamas.spawn_pack(game,Vector3(arena)+Vector3(0.5,0,-10.5),rng)
	suite.check(pack.size() >= 1 and pack.size() <= Llamas.PACK_MAX,"a pack is up to six llamas")

	for mob in game.creatures.get_children(): mob.free()
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode
	game.survival.mount = null
