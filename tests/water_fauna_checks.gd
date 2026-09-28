extends RefCounted

# Focused regression for the dolphin and the axolotl. Reference:
# mobs_mc/{dolphin,axolotl}.lua and mcl_potions' `dolphin_grace`.

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
	var old_effects: Dictionary = game.survival.effect_snapshot()
	game.gamemode = "survival"
	game.inventory.selected = 0
	for mob in game.creatures.get_children(): mob.free()
	# A walled pool, ten deep, with dry ground around it.
	var pool := Vector3i(8,160,8)
	for x in range(-12,13):
		for z in range(-12,13):
			for y in range(-1,14):
				var edge: bool = absi(x) == 12 or absi(z) == 12 or y == -1
				var water: bool = not edge and y < 10 and absi(x) <= 8 and absi(z) <= 8
				world.set_node(pool+Vector3i(x,y,z),Nodes.STONE if edge or (y < 10 and not water) else (Nodes.WATER if water else Nodes.AIR))
	game.player.position = Vector3(pool)+Vector3(0.5,11,0.5)

	# --- registry ------------------------------------------------------------------
	var dolphin: Dictionary = Creature.KINDS["dolphin"]
	var axolotl: Dictionary = Creature.KINDS["axolotl"]
	suite.check(not dolphin.hostile and is_equal_approx(dolphin.health,10.0) and is_equal_approx(dolphin.damage,2.5) and dolphin.swims,"a dolphin is a neutral swimmer with ten health and 2.5 damage")
	suite.check(dolphin.drops == [[VillageContent.RAW_COD,0,1]] and int(dolphin.xp) == 1 and int(dolphin.xp_max) == 3,"a dolphin drops up to one cod and pays one to three experience")
	suite.check(is_equal_approx(axolotl.health,14.0) and axolotl.damage == 2 and int(axolotl.xp_max) == 7 and axolotl.can_despawn,"an axolotl has fourteen health, pays up to seven and may despawn")
	suite.check(Farming.supports("axolotl") and not Farming.supports("dolphin"),"axolotls breed; dolphins do not")
	suite.check(FishBuckets.bucket_for("axolotl") == Axolotls.BUCKET and VillageContent.DATA.has(Axolotls.BUCKET),"a bucket of axolotl is a registered fish bucket")

	# --- the dolphin's air and moisture ---------------------------------------------------
	var step: Array = Dolphins.breathe(10.0,120.0,true,true,1.0)
	suite.check(is_equal_approx(step[0],9.0) and is_equal_approx(step[1],120.0) and step[2] == 0.0,"under water a dolphin spends air and stays moist")
	step = Dolphins.breathe(10.0,50.0,false,true,1.0)
	suite.check(is_equal_approx(step[0],240.0),"at the surface its air refills to 240")
	step = Dolphins.breathe(0.5,120.0,true,true,1.0)
	suite.check(step[0] == 0.0 and step[2] > 0.0,"out of air it drowns")
	step = Dolphins.breathe(240.0,0.5,false,false,1.0)
	suite.check(step[1] == 0.0 and step[2] > 0.0,"out of water for 120 seconds it dries out")
	step = Dolphins.breathe(240.0,60.0,false,true,1.0)
	suite.check(is_equal_approx(step[1],120.0),"rain or water keeps it moist")
	var swimmer: Creature = spawned("dolphin",game,Vector3(pool)+Vector3(0.5,4,0.5))
	suite.check(swimmer.head != null,"a dolphin builds its body")
	swimmer.set_meta("dolphin_air",3.0)
	suite.check(Dolphins.direction(game,swimmer) == Vector3.ZERO and Dolphins.lift(game,swimmer) > 0.0,"below five seconds of air it heads straight up")
	swimmer.set_meta("dolphin_air",240.0)
	# Beached, it dries and is hurt without being provoked.
	swimmer.position = Vector3(pool)+Vector3(0.5,10,11.5)
	world.set_node(Vector3i(pool)+Vector3i(0,9,11),Nodes.STONE)
	swimmer.set_meta("dolphin_moisture",0.5)
	var before: float = swimmer.health
	for i in 4: Dolphins.step(game,swimmer,0.5,RandomNumberGenerator.new())
	suite.check(swimmer.health < before and not swimmer.provoked,"a dry dolphin loses health without turning on anyone")
	swimmer.position = Vector3(pool)+Vector3(0.5,4,0.5)
	swimmer.health = 10.0

	# --- swimming with the player and Dolphin's Grace ------------------------------------------
	game.player.position = Vector3(pool)+Vector3(6.5,4,0.5)
	suite.check(Dolphins.player_swimming(game),"a player in the pool is swimming")
	var toward: Vector3 = Dolphins.direction(game,swimmer)
	suite.check(toward.x > 0.9,"a dolphin joins a swimming player")
	game.player.position = swimmer.position+Vector3(1,0,0)
	suite.check(Dolphins.direction(game,swimmer) == Vector3.ZERO,"and holds within 2.5 of them")
	PotionEffects.clear(game.player)
	var grace_rng := RandomNumberGenerator.new(); grace_rng.seed = 3
	for i in 60: Dolphins.step(game,swimmer,0.05,grace_rng)
	suite.check(PotionEffects.level(game.player,"dolphins_grace") == 1,"swimming beside a dolphin grants Dolphin's Grace")
	game.player.position = Vector3(pool)+Vector3(0.5,11,0.5)

	# --- treasure ---------------------------------------------------------------------------------
	var chest_at := Vector3i(pool)+Vector3i(7,0,7)
	world.set_node(chest_at,Nodes.CHEST)
	world.get_station(chest_at,"chest")
	suite.check(Dolphins.nearest_chest(world,Vector3i(swimmer.position.floor())) == chest_at,"a dolphin finds the nearest chest in reach")
	hold(game,Nodes.BREAD,2)
	suite.check(not Dolphins.feed(game,swimmer),"bread does not feed a dolphin")
	hold(game,VillageContent.RAW_COD,2)
	suite.check(Dolphins.feed(game,swimmer) and game.inventory.held().count == 1,"raw cod feeds it")
	var lead: Vector3 = Dolphins.direction(game,swimmer)
	suite.check(lead.x > 0.5 and lead.z > 0.5,"a fed dolphin leads toward the chest")
	swimmer.position = Vector3(chest_at)+Vector3(1.5,3,0.5)
	suite.check(Dolphins.direction(game,swimmer) == Vector3.ZERO and not bool(swimmer.get_meta("dolphin_fed",true)),"within two nodes of it the dolphin stops and the treat is spent")
	world.set_node(chest_at,Nodes.WATER)
	world.stations.erase(chest_at)

	# --- leaping -------------------------------------------------------------------------------------
	suite.check(Dolphins.can_leap(world,Vector3i(pool)+Vector3i(0,9,0),Vector3(1,0,0)),"water ahead with air above lets a dolphin breach")
	suite.check(not Dolphins.can_leap(world,Vector3i(pool)+Vector3i(0,4,0),Vector3(1,0,0)),"deep under water it cannot")
	var jumper: Creature = spawned("dolphin",game,Vector3(pool)+Vector3(0.5,9,0.5))
	Dolphins.leap(jumper,Vector3(1,0,0))
	suite.check(jumper.velocity.y >= 14.0 and jumper.knock.x >= 12.0 and jumper.has_meta("dolphin_leaping"),"a breach adds the source's (12, 14) push")
	jumper.free()

	# --- retaliation ---------------------------------------------------------------------------------
	var podmate: Creature = spawned("dolphin",game,Vector3(pool)+Vector3(-4.5,4,0.5))
	swimmer.hit(1.0,game.player.position)
	suite.check(swimmer.provoked and Dolphins.aggressive(game,swimmer) and podmate.provoked,"a struck dolphin fights back and calls its pod")
	podmate.free(); swimmer.free()
	var calm: Creature = spawned("dolphin",game,Vector3(pool)+Vector3(4.5,4,4.5))
	var neighbour: Creature = spawned("dolphin",game,Vector3(pool)+Vector3(2.5,4,4.5))
	var guard: Creature = spawned("guardian",game,Vector3(pool)+Vector3(4.5,4,5.5))
	Dolphins.struck(game,calm,guard)
	suite.check(not neighbour.provoked,"a guardian's blow calls no dolphin, as the source ignores guardians")
	guard.free(); calm.free(); neighbour.free()

	# --- Dolphin's Grace speeds a swimmer ----------------------------------------------------------------
	suite.check(PotionEffects.NAMES.has("dolphins_grace"),"Dolphin's Grace is an effect")

	# --- the axolotl -------------------------------------------------------------------------------------
	var axo: Creature = spawned("axolotl",game,Vector3(pool)+Vector3(0.5,3,0.5))
	suite.check(axo.head != null and axo.legs.size() == 4,"an axolotl builds its body")
	suite.check(Axolotls.COLOURS.has(Axolotls.colour(axo)),"it has one of the seven colours")
	var seen: Dictionary = {}
	var colour_rng := RandomNumberGenerator.new(); colour_rng.seed = 9
	for i in 400: seen[Axolotls.pick_colour(colour_rng)] = true
	suite.check(seen.size() == 7,"all seven colours occur")
	# Playing dead.
	suite.check(Axolotls.plays_dead(1,0,1.0,14.0,14.0,true,true),"a hit above the roll plays dead")
	suite.check(not Axolotls.plays_dead(2,0,1.0,14.0,14.0,true,true),"the other half of the coin does not")
	suite.check(not Axolotls.plays_dead(1,2,1.0,14.0,14.0,true,true),"a hit no bigger than the roll does not at full health")
	suite.check(Axolotls.plays_dead(1,2,1.0,6.0,14.0,true,true),"below half health any hit does")
	suite.check(not Axolotls.plays_dead(1,0,20.0,14.0,14.0,true,true),"a killing blow does not")
	suite.check(not Axolotls.plays_dead(1,0,1.0,14.0,14.0,false,true),"on land it does not")
	suite.check(not Axolotls.plays_dead(1,0,1.0,14.0,14.0,true,false),"an unsourced hurt does not")
	axo.set_meta("axolotl_dead",Axolotls.PLAY_DEAD_SECONDS)
	PotionEffects.apply(axo,"regeneration",Axolotls.PLAY_DEAD_SECONDS,1)
	suite.check(Axolotls.playing_dead(axo) and PotionEffects.level(axo,"regeneration") == 1,"playing dead grants ten seconds of regeneration")
	suite.check(Axolotls.target(game,axo) == null,"a dead-playing axolotl hunts nothing")
	for i in 21: Axolotls.step(game,axo,0.5)
	suite.check(not Axolotls.playing_dead(axo),"after ten seconds it gets up")
	# Hunting.
	var cod: Creature = spawned("cod",game,Vector3(pool)+Vector3(3.5,3,0.5))
	suite.check(Axolotls.target(game,axo) == cod,"an axolotl hunts fish")
	cod.set_meta("player_struck",true)
	game.player.position = Vector3(pool)+Vector3(0.5,3,4.5)
	PotionEffects.clear(game.player)
	PotionEffects.apply(game.player,"fatigue",30.0,1)
	Axolotls.killed(game,axo,cod)
	suite.check(PotionEffects.level(game.player,"regeneration") == 1 and PotionEffects.level(game.player,"fatigue") == 0,"a kill the player helped with gives regeneration and clears mining fatigue")
	suite.check(is_equal_approx(Axolotls.cooldown(axo),120.0) and Axolotls.target(game,axo) == null,"a kill starts the 120-second hunting cooldown")
	var guardian: Creature = spawned("guardian",game,Vector3(pool)+Vector3(-3.5,3,0.5))
	suite.check(Axolotls.target(game,axo) == guardian,"guardians are hunted even on cooldown")
	guardian.free(); cod.free()
	# Out of water.
	axo.position = Vector3(pool)+Vector3(0.5,10,11.5)
	axo.set_meta("axolotl_air",0.5)
	var dry_before: float = axo.health
	for i in 4: Axolotls.step(game,axo,0.5)
	suite.check(axo.health < dry_before,"an axolotl out of water for its 300 seconds of air takes damage")
	axo.position = Vector3(pool)+Vector3(0.5,3,0.5)
	axo.health = 14.0
	# Feeding and breeding.
	hold(game,FishBuckets.TROPICAL_FISH_BUCKET,1)
	suite.check(Axolotls.feed(game,axo) and axo.love_time > 0.0,"a bucket of tropical fish breeds an axolotl")
	suite.check(game.inventory.count_item(Nodes.WATER_BUCKET) >= 1,"and the source hands back a water bucket")
	# The bucket.
	hold(game,Nodes.WATER_BUCKET,1)
	axo.custom_name = "Wiggles"
	Axolotls.set_colour(axo,"white")
	suite.check(Axolotls.colour(axo) == "white" and axo.head != null,"a colour change rebuilds the body")
	var keep_colour: String = Axolotls.colour(axo)
	suite.check(Axolotls.capture(game,axo),"a water bucket catches an axolotl")
	var bucket_slot: Dictionary = {}
	for slot in game.inventory.slots:
		if int(slot.get("id",0)) == Axolotls.BUCKET: bucket_slot = slot
	suite.check(not bucket_slot.is_empty() and str(bucket_slot.get("data",{}).get("colour","")) == keep_colour and str(bucket_slot.data.get("name","")) == "Wiggles","the bucket keeps its colour and name")
	if not bucket_slot.is_empty():
		var index: int = game.inventory.slots.find(bucket_slot)
		game.inventory.selected = index if index < 9 else 0
		game.inventory.slots[game.inventory.selected] = bucket_slot
		FishBuckets.place(game,{"pos":Vector3i(pool)+Vector3i(2,0,2),"normal":Vector3i.UP,"id":Nodes.WATER,"distance":2.0})
		var back: Creature = null
		for mob in game.creatures.get_children():
			if mob.kind == "axolotl" and not mob.is_queued_for_deletion(): back = mob
		suite.check(back != null and Axolotls.colour(back) == keep_colour and back.custom_name == "Wiggles" and back.has_meta("persistent"),"releasing it restores its colour and name, and it no longer despawns")
		game.inventory.selected = 0
	# Persistence.
	var saved_axo: Creature = spawned("axolotl",game,Vector3(pool)+Vector3(-2.5,3,-2.5))
	Axolotls.set_colour(saved_axo,"yellow")
	saved_axo.set_meta("persistent",true)
	var record: Dictionary = JSON.parse_string(JSON.stringify(Farming.state(saved_axo)))
	var restored: Creature = spawned("axolotl",game,Vector3(pool)+Vector3(2.5,3,-2.5))
	Farming.restore_state(restored,record)
	suite.check(Axolotls.colour(restored) == "yellow" and restored.has_meta("persistent"),"an axolotl's colour and persistence survive a save")
	# Despawning.
	var stray: Creature = spawned("axolotl",game,Vector3(pool)+Vector3(0.5,3,-6.5))
	game.player.position = Vector3(pool)+Vector3(200,11,0.5)
	suite.check(Farming.sleep_if_unloaded(stray) and stray.is_queued_for_deletion() and not Farming.records(game).has(stray.farm_id),"a wild axolotl far from the player despawns rather than sleeps")
	suite.check(Farming.sleep_if_unloaded(restored) and Farming.records(game).has(restored.farm_id),"a persistent one sleeps and is kept")
	game.player.position = Vector3(pool)+Vector3(0.5,11,0.5)
	# Spawning.
	world.set_node(Vector3i(pool)+Vector3i(0,-1,0),Nodes.CLAY)
	# The pool is open to the sky, which the axolotl's cave spawn refuses; a roof
	# over it makes the same cell acceptable.
	# Earlier groups may have left a roof over this column, so it is cleared first.
	for y in range(pool.y+14,world.generator.max_y()): world.set_node(Vector3i(pool.x,y,pool.z),Nodes.AIR)
	suite.check(not Axolotls.spawn_allowed(world,Vector3i(pool)),"an axolotl never spawns under open sky")
	for x in range(-12,13):
		for z in range(-12,13): world.set_node(pool+Vector3i(x,13,z),Nodes.STONE)
	suite.check(Axolotls.spawn_allowed(world,Vector3i(pool)),"an axolotl may spawn in covered water over clay")
	suite.check(not Axolotls.spawn_allowed(world,Vector3i(pool)+Vector3i(0,0,11)),"nor out of water")

	for mob in game.creatures.get_children(): mob.free()
	for x in range(-12,13):
		for z in range(-12,13):
			for y in range(-1,14): world.set_node(pool+Vector3i(x,y,z),Nodes.AIR)
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode
	PotionEffects.clear(game.player)
	game.survival.restore_effects(old_effects)
