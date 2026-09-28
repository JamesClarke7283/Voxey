extends RefCounted

# Focused regression for the wolf: taming, orders, feeding and collars, the owner
# rules, following and teleporting, breeding, persistence, wetness, biome
# variants and the skeleton's fear of wolves. Reference: mobs_mc/wolf.lua,
# mcl_mobs/breeding.lua and mobs_mc/skeleton+stray.lua.

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
	var old_time: float = game.day_time
	game.gamemode = "survival"
	game.inventory.selected = 0
	for mob in game.creatures.get_children(): mob.free()
	var arena := Vector3i(8,170,8)
	for x in range(-20,21):
		for z in range(-20,21):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(0,4): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,0.5)

	# --- registry ---------------------------------------------------------------
	var info: Dictionary = Creature.KINDS["wolf"]
	suite.check(not info.hostile and is_equal_approx(info.health,8.0) and info.damage == 4 and int(info.reach) == 2,"a wild wolf has eight health and four damage at reach two")
	suite.check(info.drops.is_empty() and int(info.xp) == 1 and int(info.xp_max) == 3,"a wolf drops nothing and pays one to three experience")
	suite.check(Farming.supports("wolf"),"wolves are persistent breeding animals")
	suite.check(Wolves.heal_for(VillageContent.COOKED_BEEF) == 8 and Wolves.heal_for(VillageContent.RABBIT_STEW) == 10 and Wolves.heal_for(Nodes.ROTTEN_FLESH) == 4 and Wolves.heal_for(VillageContent.PUFFERFISH) == 1,"a wolf's foods heal by the source's table")
	suite.check(not Wolves.is_food(Nodes.BONE) and not Wolves.is_food(Nodes.BREAD),"a bone and bread are not wolf food")
	suite.check(Wolves.COLLARS.size() == 16 and Wolves.collar_for("brown") == "#663300" and Wolves.collar_for("silver") == "#C0C0C0","all sixteen dyes map to the source's collar colours")
	suite.check(Creature.KINDS["skeleton"].get("runaway_from",[]).has("wolf") and Creature.KINDS["stray"].get("runaway_from",[]).has("wolf"),"skeletons and strays keep away from wolves")

	# --- taming -------------------------------------------------------------------
	suite.check(Wolves.bone_tames(1) and not Wolves.bone_tames(2) and not Wolves.bone_tames(3),"a bone tames at one in three")
	var wolf: Creature = spawned("wolf",game,Vector3(arena)+Vector3(2.5,0,0.5))
	suite.check(wolf.head != null and wolf.legs.size() == 4,"a wolf builds a four-legged body")
	hold(game,Nodes.BREAD,5)
	suite.check(not Wolves.use(game,wolf),"a wild wolf ignores anything but a bone")
	hold(game,Nodes.BONE,64)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var tries: int = 0
	while not Wolves.tamed(wolf) and tries < 60:
		Wolves.use(game,wolf,rng); tries += 1
	suite.check(Wolves.tamed(wolf),"bones eventually tame a wolf")
	suite.check(game.inventory.held().count == 64-tries,"every bone is used, tamed or not")
	suite.check(Wolves.owner(wolf) == game.player_id and Wolves.sitting(wolf),"the new owner is the player and the wolf starts sitting")
	suite.check(is_equal_approx(wolf.health,40.0) and is_equal_approx(Wolves.max_health(wolf),40.0),"a tamed wolf has the source's forty health")
	var collar_seen: bool = false
	for part in wolf.parts:
		if is_instance_valid(part) and part.has_meta("wolf_collar"): collar_seen = part.visible
	suite.check(collar_seen,"a tamed wolf wears its collar")
	var angry_wolf: Creature = spawned("wolf",game,Vector3(arena)+Vector3(-4.5,0,0.5))
	angry_wolf.provoked = true
	var bones_before: int = game.inventory.held().count
	suite.check(not Wolves.use(game,angry_wolf,rng) and game.inventory.held().count == bones_before,"an angry wolf cannot be tamed and keeps the bone")
	angry_wolf.free()

	# --- orders, food and collars ---------------------------------------------------
	hold(game,0,0)
	Wolves.use(game,wolf)
	suite.check(not Wolves.sitting(wolf),"the owner's empty-handed click stands a sitting wolf up")
	Wolves.use(game,wolf)
	suite.check(Wolves.sitting(wolf),"and the next click sits it down again")
	wolf.health = 30.0
	hold(game,VillageContent.COOKED_BEEF,3)
	suite.check(Wolves.use(game,wolf) and is_equal_approx(wolf.health,38.0) and game.inventory.held().count == 2,"steak heals a hurt tamed wolf by eight")
	Wolves.use(game,wolf)
	suite.check(is_equal_approx(wolf.health,40.0),"healing stops at forty")
	suite.check(wolf.love_time <= 0.0,"feeding a hurt wolf does not put it in love")
	Wolves.use(game,wolf)
	suite.check(wolf.love_time <= 0.0 and not Wolves.sitting(wolf),"at full health a sitting wolf is not bred: the click stands it up instead")
	Wolves.use(game,wolf)
	suite.check(wolf.love_time > 0.0,"food at full health puts a standing tamed wolf in love")
	hold(game,VillageContent.DYE_BLUE,2)
	Wolves.use(game,wolf)
	suite.check(Wolves.collar(wolf) == "#0000BB" and game.inventory.held().count == 1,"blue dye recolours the owner's wolf collar")
	Wolves.use(game,wolf)
	suite.check(game.inventory.held().count == 1,"the same colour again uses no dye")

	# --- the owner rules -------------------------------------------------------------
	wolf.set_meta("sitting",false); wolf.love_time = 0.0
	var sheep: Creature = spawned("sheep",game,Vector3(arena)+Vector3(6.5,0,0.5))
	var wild: Creature = spawned("wolf",game,Vector3(arena)+Vector3(5.5,0,3.5))
	suite.check(Wolves.target(game,wild) == sheep,"a wild wolf hunts a nearby sheep")
	suite.check(Wolves.target(game,wolf) == null,"a tamed wolf leaves sheep alone")
	var bones: Creature = spawned("skeleton",game,Vector3(arena)+Vector3(-7.5,0,0.5))
	suite.check(Wolves.target(game,wolf) == bones,"a tamed wolf still hunts skeletons")
	suite.check(bones.runaway_threat(["wolf"]) == Vector3.INF,"a skeleton more than six away from a wolf does not flee")
	bones.position = wolf.position+Vector3(-4,0,0)
	suite.check(bones.runaway_threat(["wolf"]).is_equal_approx(wolf.position),"a skeleton within six of a wolf flees it")
	bones.free()
	var zombie: Creature = spawned("zombie",game,Vector3(arena)+Vector3(0.5,0,6.5))
	Wolves.record_player_hurt(game,zombie)
	suite.check(Wolves.target(game,wolf) == zombie,"a tamed wolf goes for whatever hurt its owner")
	game.day_time += 6.0/1200.0
	suite.check(Wolves.target(game,wolf) != zombie,"the owner's assailant is forgotten after five seconds")
	var creeper: Creature = spawned("creeper",game,Vector3(arena)+Vector3(0.5,0,-6.5))
	Wolves.record_player_struck(game,creeper)
	suite.check(Wolves.target(game,wolf) != creeper,"a wolf never follows its owner onto a creeper")
	Wolves.record_player_struck(game,zombie)
	suite.check(Wolves.target(game,wolf) == zombie,"a wolf joins its owner's attack on another mob")
	Wolves.record_player_struck(game,wild)
	suite.check(Wolves.may_attack(wolf,wild),"a wild wolf the owner strikes is fair game")
	creeper.free(); zombie.free()
	game.day_time += 6.0/1200.0
	# Striking wolves.
	wolf.hit(1.0,game.player.position)
	suite.check(not wolf.provoked and not Wolves.aggressive(game,wolf),"a tamed wolf struck by its owner never turns on them")
	var packmate: Creature = spawned("wolf",game,Vector3(arena)+Vector3(-8.5,0,3.5))
	var far_wolf: Creature = spawned("wolf",game,Vector3(arena)+Vector3(5.5,0,-14.5))
	wild.hit(1.0,game.player.position)
	suite.check(wild.provoked and Wolves.aggressive(game,wild),"a struck wild wolf turns on the player")
	suite.check(packmate.provoked,"it calls the wild wolves within sixteen")
	suite.check(not far_wolf.provoked,"a wolf beyond sixteen stays calm")
	suite.check(not wolf.provoked,"the call does not turn a tamed wolf on its owner")
	game.gamemode = "creative"
	suite.check(not Wolves.aggressive(game,wild),"angry wolves ignore a creative player")
	game.gamemode = "survival"
	var biter: Creature = spawned("zombie",game,wolf.position+Vector3(1,0,0))
	wolf.hit(1.0,biter.position)
	suite.check(Wolves.attacker_of(wolf) == biter and Wolves.target(game,wolf) == biter,"a wolf struck by a mob fights back")
	biter.free(); packmate.free(); far_wolf.free(); sheep.free(); wild.free()

	# --- following, sitting and teleporting -----------------------------------------------
	wolf.set_meta("wolf_attacker",0)
	wolf.set_meta("sitting",true)
	suite.check(Wolves.direction(wolf) != Vector3.ZERO,"a sitting wolf struck by a mob gets up while its owner is near")
	game.day_time += 6.0/1200.0
	suite.check(Wolves.direction(wolf) == Vector3.ZERO,"a sitting wolf stays put")
	wolf.set_meta("sitting",false)
	wolf.position = game.player.position+Vector3(4,0,0)
	suite.check(Wolves.direction(wolf) == Vector3.INF,"a standing wolf near its owner roams freely")
	wolf.position = game.player.position+Vector3(11,0,0)
	var back: Vector3 = Wolves.direction(wolf)
	suite.check(back.x < -0.9,"past ten nodes a tamed wolf walks back to its owner")
	wolf.position = game.player.position+Vector3(5,0,0)
	suite.check(Wolves.direction(wolf).x < -0.9,"once travelling it keeps coming until within two")
	wolf.position = game.player.position+Vector3(1.5,0,0)
	suite.check(Wolves.direction(wolf) == Vector3.INF,"and stops within two")
	wolf.position = game.player.position+Vector3(18,0,0)
	Wolves.step(game,wolf,0.05)
	suite.check(wolf.position.distance_to(game.player.position) < 5.0,"past twelve nodes it teleports beside its owner")
	wolf.set_meta("sitting",true)
	wolf.position = game.player.position+Vector3(18,0,0)
	Wolves.step(game,wolf,0.05)
	suite.check(wolf.position.distance_to(game.player.position) > 17.0,"a sitting wolf never teleports")
	wolf.set_meta("sitting",false)

	# --- wetness --------------------------------------------------------------------------
	wolf.position = game.player.position+Vector3(3,0,0)
	var puddle := Vector3i(wolf.position.floor())
	world.set_node(puddle,Nodes.WATER)
	Wolves.step(game,wolf,0.05)
	suite.check(bool(wolf.get_meta("wolf_wet",false)),"water soaks a wolf")
	world.set_node(puddle,Nodes.AIR)
	wolf.grounded = true
	for i in 30: Wolves.step(game,wolf,0.05)
	suite.check(not bool(wolf.get_meta("wolf_wet",false)),"on dry ground it shakes dry within a second and a half")

	# --- breeding -------------------------------------------------------------------------
	var mate: Creature = spawned("wolf",game,wolf.position+Vector3(1,0,0))
	Wolves.tame(mate,game.player_id); mate.set_meta("sitting",false)
	Wolves.set_variant(mate,"black")
	wolf.love_time = Farming.LOVE_TIME; mate.love_time = Farming.LOVE_TIME
	wolf.breed_cooldown = 0; mate.breed_cooldown = 0
	var before: int = game.creatures.get_child_count()
	for i in 12:
		Farming.tick(wolf,0.5); Farming.tick(mate,0.5)
	var pup: Creature = null
	for mob in game.creatures.get_children():
		if mob.kind == "wolf" and mob.growth_remaining > 0: pup = mob
	suite.check(game.creatures.get_child_count() == before+1 and pup != null,"two tamed wolves in love have a pup")
	if pup != null:
		suite.check(Wolves.tamed(pup) and Wolves.owner(pup) == game.player_id and not Wolves.sitting(pup),"the pup is born tamed to the owner")
		suite.check(Wolves.variant(pup) in [Wolves.variant(wolf),"black"],"the pup takes a parent's variant")
		pup.free()
	var loner: Creature = spawned("wolf",game,wolf.position+Vector3(0,0,1))
	loner.love_time = Farming.LOVE_TIME
	Farming.tick(loner,0.5)
	suite.check(loner.farm_mate.is_empty(),"a wild wolf never breeds")
	loner.free(); mate.free()

	# --- persistence ------------------------------------------------------------------------
	Wolves.set_variant(wolf,"woods")
	wolf.set_meta("collar","#FF8401")
	wolf.set_meta("sitting",true)
	wolf.health = 33.0
	var record: Dictionary = JSON.parse_string(JSON.stringify(Farming.state(wolf)))
	var copy: Creature = spawned("wolf",game,Vector3(arena)+Vector3(-2.5,0,-2.5))
	Farming.restore_state(copy,record)
	suite.check(Wolves.tamed(copy) and Wolves.owner(copy) == game.player_id and Wolves.sitting(copy),"a tamed wolf's owner and orders survive a save")
	suite.check(Wolves.collar(copy) == "#FF8401" and Wolves.variant(copy) == "woods","its collar and coat survive a save")
	suite.check(is_equal_approx(copy.health,33.0),"its health above the wild maximum survives a save")
	var legacy: Dictionary = record.duplicate(true); legacy.erase("wolf")
	var old_wolf: Creature = spawned("wolf",game,Vector3(arena)+Vector3(-2.5,0,2.5))
	Farming.restore_state(old_wolf,legacy)
	suite.check(not Wolves.tamed(old_wolf) and Wolves.variant(old_wolf) == "pale" and is_equal_approx(old_wolf.health,8.0),"a record without wolf fields loads as a wild pale wolf at full wild health")
	var bad: Dictionary = record.duplicate(true); bad.wolf = {"tamed":true,"variant":"plaid","collar":"#123456"}
	var odd: Creature = spawned("wolf",game,Vector3(arena)+Vector3(2.5,0,-2.5))
	Farming.restore_state(odd,bad)
	suite.check(Wolves.variant(odd) == "pale" and Wolves.collar(odd) == Wolves.DEFAULT_COLLAR,"an unknown variant or collar falls back to the defaults")
	copy.free(); old_wolf.free(); odd.free()

	# --- variants and spawning ---------------------------------------------------------------
	suite.check(Wolves.variant_for_biome("Oakwood meadow") == "woods" and Wolves.variant_for_biome("Frostpine highlands") == "ashen" and Wolves.variant_for_biome("Swamp") == "pale","the coat follows the spawn biome")
	suite.check(is_equal_approx(Wolves.spawn_share("Frostpine highlands"),8.0/48.0) and is_equal_approx(Wolves.spawn_share("Oakwood meadow"),5.0/45.0) and Wolves.spawn_share("Sunwash desert") == 0.0,"wolves spawn in taiga and forest at their source weights")
	suite.check(Wolves.spawn_allowed(world,arena+Vector3i(0,0,-10)) == false,"wolves do not spawn on stone")
	world.set_node(arena+Vector3i(0,-1,-10),Nodes.GRASS)
	suite.check(Wolves.spawn_allowed(world,arena+Vector3i(0,0,-10)),"wolves spawn on grass")
	world.set_node(arena+Vector3i(0,-1,-10),Nodes.STONE)

	for mob in game.creatures.get_children(): mob.free()
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode
	game.day_time = old_time
	if game.has_meta("wolf_memory"): game.remove_meta("wolf_memory")
