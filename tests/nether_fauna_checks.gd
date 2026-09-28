extends RefCounted

# Focused regression for the strider, the hoglin and zoglin, and the Nether's
# per-biome spawn tables. Reference: mobs_mc/{strider,hoglin+zoglin,ghast,
# piglin,blaze,skeleton_wither,slime+magma_cube,enderman}.lua.

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
	var old_dimension: String = game.dimension
	game.gamemode = "survival"
	game.inventory.selected = 0
	for mob in game.creatures.get_children(): mob.free()
	var arena := Vector3i(8,170,8)
	for x in range(-18,19):
		for z in range(-18,19):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,15.5)

	# --- registry --------------------------------------------------------------------
	var strider: Dictionary = Creature.KINDS["strider"]
	var hoglin: Dictionary = Creature.KINDS["hoglin"]
	var zoglin: Dictionary = Creature.KINDS["zoglin"]
	suite.check(not strider.hostile and is_equal_approx(strider.health,20.0) and int(strider.xp) == 9 and strider.get("water_sensitive",false),"a strider is a water-sensitive animal with twenty health and nine experience")
	suite.check(hoglin.hostile and is_equal_approx(hoglin.health,40.0) and hoglin.damage == 6 and int(hoglin.reach) == 3 and int(hoglin.xp) == 9,"a hoglin has forty health, six damage at reach three and nine experience")
	suite.check(hoglin.armor == {"fleshy":90} and zoglin.armor == {"undead":90,"fleshy":90},"the zoglin adds the undead armour group to the hoglin's")
	suite.check(Fire.resistant("strider") and Fire.resistant("hoglin") and Fire.resistant("zoglin"),"all three are fire-resistant")
	suite.check(PotionEffects.UNDEAD.has("zoglin") and not PotionEffects.UNDEAD.has("hoglin"),"only the zoglin is undead")
	suite.check(Farming.supports("strider") and Farming.supports("hoglin") and not Farming.supports("zoglin"),"striders and hoglins breed; zoglins never do")

	# --- Nether spawn tables ---------------------------------------------------------------
	suite.check(NetherSpawns.pick(NetherSpawns.MONSTERS["Nether wastes"],0.0)[0] == "zombified_piglin" and NetherSpawns.pick(NetherSpawns.MONSTERS["Nether wastes"],0.999)[0] == "enderman","the wastes table runs from zombified piglins to endermen")
	var counts: Dictionary = {}
	var rng := RandomNumberGenerator.new(); rng.seed = 13
	for i in 16800:
		var kind: String = NetherSpawns.pick(NetherSpawns.MONSTERS["Nether wastes"],rng.randf())[0]
		counts[kind] = int(counts.get(kind,0))+1
	suite.check(absf(float(counts.get("zombified_piglin",0))/16800.0-100.0/168.0) < 0.02 and absf(float(counts.get("ghast",0))/16800.0-50.0/168.0) < 0.02,"the wastes draw follows the source's weights (%s)" % str(counts))
	for biome in NetherSpawns.MONSTERS:
		for entry in NetherSpawns.MONSTERS[biome]:
			if entry[0] in ["blaze","wither_skeleton"]: suite.check(false,"%s never spawns outside a fortress" % entry[0])
	suite.check(NetherSpawns.table_for("Crimson forest",false)[0][0] == "hoglin","hoglins lead the crimson forest")
	suite.check(NetherSpawns.table_for("Crimson forest",true) == NetherSpawns.FORTRESS,"inside a fortress the fortress table applies whatever the biome")
	suite.check(NetherSpawns.FORTRESS.any(func(e): return e[0] == "blaze") and NetherSpawns.FORTRESS.any(func(e): return e[0] == "wither_skeleton"),"blazes and wither skeletons spawn in fortresses")
	suite.check(NetherSpawns.table_for("Nowhere",false) == NetherSpawns.MONSTERS["Nether wastes"],"an unknown biome falls back to the wastes")
	var inside: int = 0; var agree: bool = true
	for x in range(-40,41,3):
		for z in range(-40,41,3):
			for y in [26,28,33,40,42]:
				var p := Vector3i(60+x,y,60+z)
				if NetherSpawns.in_fortress(p): inside += 1
				if WorldStructures.fortress_node(p) >= 0 and not NetherSpawns.in_fortress(p) and y >= 27: agree = false
	suite.check(inside > 0 and agree,"every fortress cell above its floor counts as inside the fortress")
	suite.check(not NetherSpawns.in_fortress(Vector3i(60+50,30,60)),"open Nether beside a fortress does not")
	var ghast_ok: int = 0
	for i in 2000:
		if NetherSpawns.allowed("ghast",world,arena,rng): ghast_ok += 1
	suite.check(absf(float(ghast_ok)/2000.0-0.05) < 0.02,"a ghast's position test passes one time in twenty (%d of 2000)" % ghast_ok)
	world.set_node(arena+Vector3i(0,-1,0),NetherBlocks.NETHER_WART_BLOCK)
	suite.check(not NetherSpawns.allowed("hoglin",world,arena,rng) and not NetherSpawns.allowed("piglin",world,arena,rng) and NetherSpawns.allowed("magma_cube",world,arena,rng),"hoglins and piglins never spawn on a nether wart block")
	world.set_node(arena+Vector3i(0,-1,0),Nodes.STONE)

	# --- the strider -------------------------------------------------------------------------
	var pool := arena+Vector3i(-10,0,-10)
	for x in range(0,5):
		for z in range(0,5):
			world.set_node(pool+Vector3i(x,-1,z),Nodes.LAVA)
	var walker: Creature = spawned("strider",game,Vector3(pool)+Vector3(2.5,-0.6,2.5))
	suite.check(walker is RuralAnimal,"a strider is a rideable animal")
	Striders.step(game,walker,0.05)
	suite.check(is_equal_approx(walker.position.y,float(pool.y)) and not Striders.aground(walker),"a strider in lava stands on its surface and is warm")
	walker.position = Vector3(arena)+Vector3(0.5,0,0.5)
	Striders.step(game,walker,0.05)
	suite.check(Striders.aground(walker) and is_equal_approx(Striders.speed_factor(walker),0.66),"out of lava it is cold and slowed to 0.66")
	suite.check(walker.rest_tint()[1] > 0.0,"a cold strider turns purple")
	walker.position = Vector3(pool)+Vector3(-3.5,0,2.5)
	walker.set_meta("strider_search",0.0)
	Striders.step(game,walker,0.05)
	var heading: Vector3 = Striders.direction(walker)
	suite.check(heading != Vector3.INF and heading.x > 0.5,"a cold strider heads for the nearest lava")
	suite.check(Striders.nearest_lava(world,Vector3i(arena)+Vector3i(0,0,15)) == Vector3i.MAX,"lava more than eight away is out of its search")
	suite.check(is_equal_approx(Striders.drive_bonus(walker),0.35),"a cold strider is driven at 0.35")
	walker.position = Vector3(pool)+Vector3(2.5,0,2.5)
	Striders.step(game,walker,0.05)
	suite.check(is_equal_approx(Striders.drive_bonus(walker),0.55),"a warm strider is driven at 0.55")
	# Riding.
	suite.check(PigRiding.drives(walker,PigRiding.WARPED_FUNGUS_ON_A_STICK) and not PigRiding.drives(walker,PigRiding.CARROT_ON_A_STICK),"a strider is steered by the warped-fungus stick, not the carrot stick")
	suite.check(PigRiding.mountable(walker),"an adult strider can take a saddle")
	PigRiding.equip_saddle(walker)
	suite.check(walker.saddled,"a saddle goes on a strider")
	game.survival.mount = walker
	suite.check(Striders.rider_protected(game),"its rider is protected from lava")
	hold(game,PigRiding.WARPED_FUNGUS_ON_A_STICK,1)
	var before: Vector3 = walker.position
	PigRiding.steer(game,walker,0.1,Vector3(1,0,0))
	suite.check(walker.position.x > before.x and is_equal_approx(walker.position.y,float(pool.y)),"a driven strider walks across the lava surface")
	game.survival.mount = null
	suite.check(not Striders.rider_protected(game),"on foot the lava burns again")
	var drop_rng := RandomNumberGenerator.new(); drop_rng.seed = 1
	var saddled_strings: Dictionary = {}; var plain_strings: Dictionary = {}
	for i in 400:
		saddled_strings[Striders.roll_drops(true,drop_rng)[0][1]] = true
		plain_strings[Striders.roll_drops(false,drop_rng)[0][1]] = true
	suite.check(saddled_strings.keys().all(func(n): return n >= 1 and n <= 3) and plain_strings.keys().all(func(n): return n >= 2 and n <= 5) and plain_strings.size() == 4,"a saddled strider drops one to three string and a bare one two to five")
	# Warped fungus breeds without healing.
	walker.health = 10.0
	hold(game,CrimsonPlants.WARPED_FUNGUS,3)
	Farming.use(game,walker)
	suite.check(is_equal_approx(walker.health,10.0),"warped fungus never heals a strider")
	walker.health = 20.0
	Farming.use(game,walker)
	suite.check(walker.love_time > 0.0,"warped fungus puts a strider in love")
	walker.love_time = 0.0
	# The rider rolls.
	var jockeys: int = 0; var babies: int = 0
	var rider_rng := RandomNumberGenerator.new(); rider_rng.seed = 29
	for i in 900:
		var rider: Node3D = Striders.spawn_rider(game,walker,rider_rng)
		if rider != null:
			if rider.kind == "zombified_piglin": jockeys += 1
			else: babies += 1
			rider.free()
	suite.check(absf(float(jockeys)/900.0-1.0/30.0) < 0.02,"one strider in thirty carries a zombified piglin (%d of 900)" % jockeys)
	suite.check(absf(float(babies)/900.0-(29.0/30.0)/10.0) < 0.03,"one in ten of the rest carries a baby strider (%d of 900)" % babies)
	walker.free()

	# --- the hoglin ----------------------------------------------------------------------------
	var roll_seen: Dictionary = {}
	for roll in 6: roll_seen[Hoglins.damage_roll(6,false,roll)] = true
	suite.check(roll_seen.keys().min() == 3.0 and roll_seen.keys().max() == 8.0,"an adult hoglin's swing is three to eight")
	suite.check(Hoglins.damage_roll(6,true,5) == 0.5,"a baby hoglin's swing is half a heart")
	var toss_rng := RandomNumberGenerator.new(); toss_rng.seed = 2
	var highest: float = 0.0; var widest: float = 0.0
	for i in 400:
		var v: Vector3 = Hoglins.toss(Vector3.ZERO,Vector3(0,0,-3),0.0,true,toss_rng)
		highest = maxf(highest,v.y); widest = maxf(widest,Vector2(v.x,v.z).length())
	suite.check(highest <= 20.0 and highest > 15.0 and widest <= 14.0 and widest >= 10.0,"a player is thrown up to twenty high and fourteen wide")
	suite.check(Hoglins.toss(Vector3.ZERO,Vector3(0,0,-3),1.0,true,toss_rng) == Vector3.ZERO,"full knockback resistance cancels the toss")
	var boar: Creature = spawned("hoglin",game,Vector3(arena)+Vector3(0.5,0,0.5))
	suite.check(boar.head != null and boar.legs.size() == 4,"a hoglin builds a tusked four-legged body")
	suite.check(Hoglins.aggressive(game,boar),"a hoglin hunts the player")
	world.set_node(arena+Vector3i(4,0,0),CrimsonPlants.WARPED_FUNGUS)
	boar.set_meta("hoglin_sense",0.0)
	Hoglins.sense(game,boar,0.05)
	suite.check(Hoglins.passive(boar) and not Hoglins.aggressive(game,boar),"warped fungus within eight makes it passive")
	suite.check(Hoglins.direction(boar).x < -0.5,"and it backs away from the fungus")
	for i in 60: Hoglins.sense(game,boar,0.2)
	suite.check(Hoglins.passive(boar),"it stays passive while the fungus is near")
	world.set_node(arena+Vector3i(4,0,0),Nodes.AIR)
	boar.set_meta("hoglin_sense",0.0)
	Hoglins.sense(game,boar,0.05)
	for i in 52: Hoglins.sense(game,boar,0.2)
	suite.check(not Hoglins.passive(boar),"ten seconds after the fungus goes it is hostile again")
	world.set_node(arena+Vector3i(0,0,6),RespawnAnchors.for_charge(0))
	boar.set_meta("hoglin_sense",0.0)
	Hoglins.sense(game,boar,0.05)
	suite.check(Hoglins.passive(boar),"a respawn anchor also repels it")
	world.set_node(arena+Vector3i(0,0,6),Nodes.AIR)
	boar.provoked = true
	suite.check(Hoglins.aggressive(game,boar),"a passive hoglin still retaliates once struck")
	boar.provoked = false; boar.set_meta("hoglin_passive",0.0); boar.remove_meta("hoglin_repellent")
	# Calling kin and retreating.
	var kin: Creature = spawned("hoglin",game,Vector3(arena)+Vector3(4.5,0,0.5))
	kin.set_meta("hoglin_passive",5.0)
	boar.hit(1.0,game.player.position)
	suite.check(kin.provoked,"a struck hoglin calls the hoglins within sixteen")
	var piglet: Creature = spawned("hoglin",game,Vector3(arena)+Vector3(-4.5,0,0.5))
	Hoglins.make_baby(piglet)
	# A retreat ends at fifteen nodes, so the attacker stands close.
	game.player.position = piglet.position+Vector3(0,0,4)
	piglet.hit(1.0,game.player.position)
	suite.check(Hoglins.retreat_from(piglet) != null and not Hoglins.aggressive(game,piglet),"a struck baby hoglin retreats")
	piglet.free()
	game.player.position = Vector3(arena)+Vector3(0.5,0,15.5)
	var gang: Array = []
	for i in 3: gang.append(spawned("piglin",game,Vector3(arena)+Vector3(-3.5+i,0,-4.5)))
	var lone: Creature = spawned("hoglin",game,Vector3(arena)+Vector3(-3.5,0,-8.5))
	kin.position = Vector3(arena)+Vector3(16.5,0,16.5)
	boar.position = Vector3(arena)+Vector3(-16.5,0,16.5)
	var fight: bool = Hoglins.struck(game,lone,gang[0],gang[0].position,rng)
	suite.check(not fight and Hoglins.retreat_from(lone) != null,"a hoglin outnumbered by piglins retreats from them")
	for g in gang: g.free()
	Hoglins.tick_retreat(game,lone,0.1)
	suite.check(Hoglins.retreat_from(lone) != null,"without hoglins to back it the retreat continues")
	lone.free()
	# Conversion.
	game.dimension = "nether"
	var calm: Node3D = null
	for i in 20: calm = Hoglins.conversion_step(game,boar,1.0)
	suite.check(calm == null and is_equal_approx(float(boar.get_meta("hoglin_convert",0.0)),0.0),"in the Nether a hoglin never converts")
	game.dimension = "overworld"
	var zog: Node3D = null
	for i in 16:
		zog = Hoglins.conversion_step(game,boar,1.0)
		if zog != null: break
	suite.check(zog != null and zog.kind == "zoglin","fifteen seconds in the Overworld turns a hoglin into a zoglin")
	if zog != null:
		suite.check(PotionEffects.level(zog,"nausea") == 1,"the new zoglin has nausea")
		zog.set_physics_process(false)
		# The zoglin attacks any mob but creepers and zoglins.
		var cow: Creature = spawned("cow",game,zog.position+Vector3(3,0,0))
		var creeper: Creature = spawned("creeper",game,zog.position+Vector3(-2,0,0))
		suite.check(Hoglins.target(game,zog) == cow,"a zoglin goes for the nearest mob that is not a creeper")
		cow.free()
		suite.check(Hoglins.target(game,zog) == null,"it leaves creepers alone")
		creeper.free()
		suite.check(Hoglins.aggressive(game,zog),"a zoglin always hunts the player")
		zog.free()
	kin.free()
	# Drops.
	var chops: Dictionary = {}; var hides: int = 0
	for i in 800:
		for entry in Hoglins.roll_drops(drop_rng,0):
			if entry[0] == VillageContent.RAW_PORKCHOP: chops[entry[1]] = true
			elif entry[0] == Nodes.LEATHER: hides += int(entry[1])
	suite.check(chops.keys().min() == 2 and chops.keys().max() == 4,"a hoglin drops two to four porkchops")
	suite.check(absf(float(hides)/800.0-0.5) < 0.07,"and up to one leather (%d of 800)" % hides)
	# Breeding.
	var sow: Creature = spawned("hoglin",game,Vector3(arena)+Vector3(0.5,0,-10.5))
	sow.health = 30.0
	hold(game,CrimsonPlants.CRIMSON_FUNGUS,3)
	Farming.use(game,sow)
	suite.check(is_equal_approx(sow.health,34.0),"crimson fungus heals a hoglin by four")
	sow.health = 40.0
	Farming.use(game,sow)
	suite.check(sow.love_time > 0.0,"at full health crimson fungus puts it in love")
	suite.check(Farming.direction(sow) == Vector3.INF,"a hoglin does not trail a player holding crimson fungus")
	sow.free()

	for mob in game.creatures.get_children(): mob.free()
	for x in range(0,5):
		for z in range(0,5): world.set_node(pool+Vector3i(x,-1,z),Nodes.STONE)
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode
	game.dimension = old_dimension
	game.survival.mount = null
