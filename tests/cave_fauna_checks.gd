extends RefCounted

# Focused regression for the bat, the endermite and the polar bear, and for the
# shared `hunts` rule that sends an enderman after an endermite. Reference:
# mobs_mc/{bat,endermite,polar_bear,enderman}.lua and mcl_throwing/register.lua.

static func spawned(kind: String, game: Node3D, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	if mob != null: mob.set_physics_process(false)
	return mob

# A dark cave pocket below sea level: a stone box with an air room inside.
static func cave(world: VoxelWorld, base: Vector3i) -> void:
	for x in range(-4,5):
		for z in range(-4,5):
			for y in range(-1,6):
				var edge: bool = absi(x) == 4 or absi(z) == 4 or y == -1 or y == 5
				world.set_node(base+Vector3i(x,y,z),Nodes.STONE if edge else Nodes.AIR)

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_position: Vector3 = game.player.position
	var old_mode: String = game.gamemode
	var old_health: float = game.player.health
	game.gamemode = "survival"
	for mob in game.creatures.get_children(): mob.free()

	# --- registry ---------------------------------------------------------------
	for kind in ["bat","endermite","polar_bear"]:
		suite.check(Creature.KINDS.has(kind),"the %s is a registered creature" % kind)
	var bat_info: Dictionary = Creature.KINDS["bat"]
	suite.check(is_equal_approx(bat_info.health,6.0) and bat_info.drops.is_empty() and int(bat_info.get("xp",0)) == 0 and bat_info.get("can_despawn",false),"a bat has six health, no drops, no experience and despawns")
	var mite: Dictionary = Creature.KINDS["endermite"]
	suite.check(mite.hostile and is_equal_approx(mite.health,8.0) and mite.damage == 2 and int(mite.reach) == 1 and int(mite.xp) == 3,"an endermite has eight health, two damage at reach one and three experience")
	suite.check(mite.armor.has("arthropod"),"an endermite is an arthropod, so Bane of Arthropods applies")
	var bear: Dictionary = Creature.KINDS["polar_bear"]
	suite.check(not bear.hostile and is_equal_approx(bear.health,30.0) and bear.damage == 6 and int(bear.reach) == 2,"a polar bear is an animal with thirty health and six damage at reach two")
	suite.check(not bear.get("can_freeze",true) and not bear.get("runaway",true),"a polar bear does not freeze and an adult does not flee")
	suite.check(Creature.KINDS["enderman"].get("hunts",[]).has("endermite"),"endermen hunt endermites")

	# --- the bat's flight rules ----------------------------------------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var offsets: Dictionary = {}
	for i in 3000:
		var t: Vector3i = Bats.pick_target(Vector3i.ZERO,rng)
		if absi(t.x) > 6 or absi(t.z) > 6 or t.y < -2 or t.y > 3: suite.check(false,"a bat target lies within the source's offsets"); break
		offsets[t.y] = true
	suite.check(offsets.size() == 6,"a bat's vertical target offset spans -2 to 3")
	suite.check(is_equal_approx(Bats.steer(0.0,5.0,10.0,0.05),1.0),"one tick moves a tenth of the way toward ten nodes per second")
	suite.check(is_equal_approx(Bats.steer(0.0,-5.0,14.0,0.05),-1.4),"vertically the pull is toward fourteen")
	suite.check(is_equal_approx(Bats.steer(10.0,5.0,10.0,0.05),10.0),"at full speed the steering holds")
	suite.check(Bats.scale_chance(100,0.05) == 100 and Bats.scale_chance(100,0.1) == 50 and Bats.scale_chance(1,1.0) == 1,"per-tick odds scale with the step length and never fall below one")
	suite.check(Bats.halloween_week({"month":10,"day":20}) and Bats.halloween_week({"month":11,"day":3}) and not Bats.halloween_week({"month":11,"day":4}),"Halloween week runs 20 October to 3 November")
	suite.check(Bats.max_light({"month":6,"day":1}) == 3 and Bats.max_light({"month":10,"day":31}) == 6,"bats spawn at light three, or six in Halloween week")

	# A dark cave room below sea level accepts a bat; the surface does not.
	var sea: int = TerrainGenerator.SEA
	var room := Vector3i(8,sea-30,8)
	cave(world,room)
	var summer: Dictionary = {"month":6,"day":1}
	suite.check(Bats.spawn_allowed(world,room,summer),"a dark cave floor below sea level can spawn a bat")
	suite.check(not Bats.spawn_allowed(world,room+Vector3i(0,-1,0),summer),"a solid cell cannot")
	world.set_node(room+Vector3i(1,0,0),Nodes.TORCH)
	suite.check(not Bats.spawn_allowed(world,room,summer),"a torch-lit cell is too bright for a bat")
	world.set_node(room+Vector3i(1,0,0),Nodes.AIR)
	suite.check(not Bats.spawn_allowed(world,Vector3i(8,sea+2,8),summer),"nothing above sea level spawns a bat")

	# A live bat flies and hangs.
	var bat: Creature = spawned("bat",game,Vector3(room)+Vector3(0.5,1.0,0.5))
	suite.check(bat is Bats.Mob,"a bat spawns as its own flying body")
	game.player.position = Vector3(room)+Vector3(30.5,0,0.5)
	var start: Vector3 = bat.position
	for i in 40: Bats.step(game,bat,0.05,rng)
	suite.check(bat.position.distance_to(start) > 0.3,"a flying bat moves")
	suite.check(bat.position.y >= float(room.y) and bat.position.y < float(room.y+5),"a bat stays inside its cave")
	# Under the room's ceiling, the resting roll eventually fires.
	bat.position = Vector3(room)+Vector3(0.5,4.2,0.5)
	bat.resting = false
	var rested: bool = false
	for i in 4000:
		bat.target = Vector3i(room.x,room.y+4,room.z)
		bat.position = Vector3(room)+Vector3(0.5,4.2,0.5); bat.velocity = Vector3.ZERO
		Bats.step(game,bat,0.05,rng)
		if bat.resting: rested = true; break
	suite.check(rested,"a bat under a ceiling starts to hang")
	Bats.step(game,bat,0.05,rng)
	suite.check(bat.resting and is_equal_approx(bat.position.y,float(room.y+5)-Bats.HANG_BELOW),"a hanging bat sits just under the ceiling and stays still")
	game.player.position = bat.position+Vector3(2,0,0)
	Bats.step(game,bat,0.05,rng)
	suite.check(not bat.resting,"a player within four nodes wakes a hanging bat")
	game.player.position = Vector3(room)+Vector3(30.5,0,0.5)
	bat.free()
	# Pack spawning honours the ambient cap.
	var made: Array = Bats.spawn_pack(game,Vector3(room)+Vector3(0.5,0,0.5),rng)
	suite.check(made.size() >= 1 and made.size() <= Bats.AMBIENT_CAP,"a bat pack spawns within the ambient cap (%d)" % made.size())
	var more: Array = Bats.spawn_pack(game,Vector3(room)+Vector3(0.5,0,0.5),rng)
	suite.check(Bats.ambient_count(game) <= Bats.AMBIENT_CAP,"a second pack never exceeds the cap")
	for b in made+more: if is_instance_valid(b): b.free()

	# --- the endermite ------------------------------------------------------------------
	suite.check(Endermites.pearl_spawns(1) and not Endermites.pearl_spawns(2) and not Endermites.pearl_spawns(10),"one pearl roll in ten leaves an endermite")
	var mites: int = 0
	var pearl_rng := RandomNumberGenerator.new(); pearl_rng.seed = 17
	for i in 2000:
		var m: Node3D = Endermites.after_pearl(game,Vector3(room)+Vector3(0.5,0,0.5),pearl_rng)
		if m != null: mites += 1; m.free()
	suite.check(absf(float(mites)/2000.0-0.1) < 0.025,"about one pearl in ten leaves an endermite (%d of 2000)" % mites)
	var arena := Vector3i(8,170,8)
	for x in range(-8,9):
		for z in range(-8,9):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(0,4): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	var enderman: Creature = spawned("enderman",game,Vector3(arena)+Vector3(0.5,0,0.5))
	var mite_mob: Creature = spawned("endermite",game,Vector3(arena)+Vector3(4.5,0,0.5))
	suite.check(enderman.nearest_villager() == mite_mob,"an enderman targets a nearby endermite")
	var zombie: Creature = spawned("zombie",game,Vector3(arena)+Vector3(-4.5,0,0.5))
	suite.check(zombie.nearest_villager() != mite_mob,"a zombie ignores endermites")
	zombie.free(); enderman.free(); mite_mob.free()

	# --- the polar bear -------------------------------------------------------------------
	var adult: Creature = spawned("polar_bear",game,Vector3(arena)+Vector3(0.5,0,0.5))
	suite.check(adult.head != null and adult.legs.size() == 4,"a polar bear builds a four-legged body")
	suite.check(not adult.aggressive(),"a lone unprovoked adult bear leaves the player alone")
	var cub: Creature = spawned("polar_bear",game,Vector3(arena)+Vector3(6.5,0,0.5))
	PolarBears.make_cub(cub)
	suite.check(PolarBears.cub(cub) and cub.model.scale.x < 1.0,"a cub is a small bear")
	suite.check(adult.aggressive(),"an adult with a cub within eight nodes turns on the player")
	suite.check(not cub.aggressive(),"a cub never attacks")
	cub.position = Vector3(arena)+Vector3(8.6,0,0.5)
	suite.check(not adult.aggressive(),"a cub more than eight nodes away does not count")
	cub.position = Vector3(arena)+Vector3(4.5,0,0.5)
	game.gamemode = "creative"
	suite.check(not adult.aggressive(),"bears ignore a creative player")
	game.gamemode = "survival"
	cub.free()
	# Retaliation and the cub's alert.
	var lone: Creature = spawned("polar_bear",game,Vector3(arena)+Vector3(-3.5,0,0.5))
	lone.hit(1.0,game.player.position)
	suite.check(lone.provoked and lone.aggressive() and lone.scared <= 0,"a struck adult retaliates instead of fleeing")
	suite.check(not adult.provoked,"a struck adult alerts no other bear")
	var baby: Creature = spawned("polar_bear",game,Vector3(arena)+Vector3(3.5,0,3.5))
	PolarBears.make_cub(baby)
	var far: Creature = spawned("polar_bear",game,Vector3(arena)+Vector3(0.5,0,0.5)+Vector3(25,0,0))
	baby.hit(1.0,game.player.position)
	suite.check(baby.scared > 0 and not baby.aggressive(),"a struck cub runs away")
	suite.check(adult.provoked,"a struck cub provokes an adult within twenty nodes")
	suite.check(not far.provoked,"an adult beyond twenty nodes is not alerted")
	# Drops.
	var drop_rng := RandomNumberGenerator.new(); drop_rng.seed = 23
	var cod: int = 0; var salmon: int = 0
	for i in 8000:
		for entry in PolarBears.roll_drops(drop_rng,0):
			if entry[0] == VillageContent.RAW_COD: cod += int(entry[1])
			elif entry[0] == VillageContent.RAW_SALMON: salmon += int(entry[1])
	suite.check(absf(float(cod)/8000.0-0.5) < 0.05,"a bear drops an average of half a cod (0-2 at 1 in 2): %d" % cod)
	suite.check(absf(float(salmon)/8000.0-0.25) < 0.04,"and a quarter of a salmon (0-2 at 1 in 4): %d" % salmon)
	var xp_seen: Dictionary = {}
	for i in 200: xp_seen[adult.xp_reward()] = true
	suite.check(xp_seen.keys().all(func(v): return v >= 1 and v <= 3) and xp_seen.size() == 3,"a bear pays one to three experience")
	# Growing up.
	PolarBears.tick(baby,Farming.GROW_TIME+1.0,false,99.0)
	suite.check(not PolarBears.cub(baby) and is_equal_approx(baby.model.scale.x,1.0),"a cub grows into an adult after twenty minutes")
	# Rearing.
	suite.check(PolarBears.rearing(3.0,true,2.7) and not PolarBears.rearing(2.0,true,2.7) and not PolarBears.rearing(3.0,false,2.7) and not PolarBears.rearing(6.0,true,2.7),"a bear rears just outside its reach while chasing")
	# Spawning.
	world.set_node(arena+Vector3i(0,-1,0),Nodes.SNOW_BLOCK)
	var cold: bool = Weather.snowy_biome(world.generator.biome(arena.x,arena.z))
	suite.check(PolarBears.spawn_allowed(world,arena) == cold,"bears spawn on snow only in the cold biome")
	suite.check(is_equal_approx(PolarBears.spawn_share(),1.0/11.0),"the bear's weight is one against the rabbit's ten")
	var pack: Array = PolarBears.spawn_pack(game,Vector3(arena)+Vector3(0.5,0,0.5),RandomNumberGenerator.new())
	suite.check(pack.size() >= 1 and pack.size() <= 2,"a bear pack has one or two bears")
	if pack.size() == 2: suite.check(not PolarBears.cub(pack[0]) and PolarBears.cub(pack[1]),"the second bear of a pack is a cub")

	for mob in game.creatures.get_children(): mob.free()
	game.player.position = old_position
	game.player.health = old_health
	game.gamemode = old_mode
