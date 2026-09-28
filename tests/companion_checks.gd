extends RefCounted

# Focused regression for cats and parrots: taming, orders, collars, following,
# sleeping with the owner and dawn gifts, resting spots, village spawning,
# creepers' fear of cats, parrot perching, dancing, imitation and cookies, and
# persistence. Reference: mobs_mc/{ocelot,parrot,creeper}.lua.

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
	for x in range(-16,17):
		for z in range(-16,17):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,0.5)

	# --- cats ---------------------------------------------------------------------------
	var cat_info: Dictionary = Creature.KINDS["cat"]
	suite.check(is_equal_approx(cat_info.health,10.0) and cat_info.drops == [[Nodes.STRING,0,2]] and cat_info.can_despawn,"a cat has ten health, drops up to two string and may despawn")
	suite.check(Creature.KINDS["creeper"].get("runaway_from",[]).has("cat"),"creepers keep away from cats")
	suite.check(Cats.coats_for(false,false).size() == 10 and Cats.coats_for(false,true).size() == 11 and Cats.coats_for(true,false) == [Cats.ALL_BLACK],"ten coats, the all-black one only under a full moon or in a witch hut")
	var cat: Creature = spawned("cat",game,Vector3(arena)+Vector3(3.5,0,0.5))
	suite.check(Cats.COAT_COLOURS.has(Cats.coat(cat)) and cat.head != null,"a cat spawns with a coat and a body")
	hold(game,Nodes.BREAD,1)
	suite.check(not Cats.use(game,cat),"a wild cat ignores bread")
	hold(game,VillageContent.RAW_COD,64)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var tries: int = 0
	while not Cats.tamed(cat) and tries < 60:
		Cats.use(game,cat,rng); tries += 1
	suite.check(Cats.tamed(cat) and Cats.sitting(cat) and Cats.owner(cat) == game.player_id,"raw cod eventually tames a cat, which sits")
	suite.check(game.inventory.held().count == 64-tries and cat.has_meta("persistent"),"every fish is eaten and a fed cat is kept")
	hold(game,VillageContent.DYE_PINK,1)
	Cats.use(game,cat)
	suite.check(Cats.collar(cat) == "#FF65B5","dye recolours the collar")
	hold(game,0,0)
	Cats.use(game,cat)
	suite.check(not Cats.sitting(cat),"the owner's click stands it up")
	cat.health = 6.0
	hold(game,VillageContent.RAW_SALMON,2)
	Cats.use(game,cat)
	suite.check(is_equal_approx(cat.health,8.0),"salmon heals a hurt cat by two")
	cat.health = 10.0
	Cats.use(game,cat)
	suite.check(cat.love_time > 0.0,"fish at full health breeds a standing cat")
	cat.love_time = 0.0
	# Following.
	cat.position = game.player.position+Vector3(11,0,0)
	suite.check(Cats.direction(game,cat).x < -0.9,"past ten nodes a tamed cat walks to its owner")
	cat.position = game.player.position+Vector3(6,0,0)
	suite.check(Cats.direction(game,cat).x < -0.9,"and keeps coming until within five")
	cat.position = game.player.position+Vector3(4,0,0)
	suite.check(Cats.direction(game,cat) == Vector3.INF,"then stops")
	cat.position = game.player.position+Vector3(14,0,0)
	Cats.step(game,cat,0.05)
	suite.check(cat.position.distance_to(game.player.position) < 5.0,"past twelve it teleports to its owner")
	# Resting on a chest.
	world.set_node(arena+Vector3i(2,0,2),Nodes.CHEST)
	cat.position = Vector3(arena)+Vector3(2.5,0,-0.5)
	cat.set_meta("cat_rest_clock",2.5)
	Cats.step(game,cat,0.05)
	suite.check(cat.has_meta("cat_rest") and cat.get_meta("cat_rest") == arena+Vector3i(2,1,2),"an idle tamed cat picks a chest to sit on")
	suite.check(Cats.direction(game,cat).z > 0.5,"and walks to it")
	world.set_node(arena+Vector3i(2,0,2),Nodes.AIR)
	cat.set_meta("cat_rest_clock",0.0)
	Cats.step(game,cat,0.05)
	suite.check(not cat.has_meta("cat_rest"),"it gives up when the chest is gone")
	# Hunting: a wild cat goes for rabbits; a tamed one does not.
	var wild: Creature = spawned("cat",game,Vector3(arena)+Vector3(-6.5,0,0.5))
	var rabbit: Creature = spawned("rabbit",game,Vector3(arena)+Vector3(-9.5,0,0.5))
	suite.check(Cats.target(game,wild) == rabbit and Cats.target(game,cat) == null,"a wild cat hunts rabbits and a tamed one leaves them")
	rabbit.free()
	# Creepers flee cats.
	var creeper: Creature = spawned("creeper",game,Vector3(arena)+Vector3(-3.5,0,0.5))
	suite.check(creeper.runaway_threat(["cat","ocelot"]).distance_to(wild.position) < 0.01,"a creeper within six of a cat backs away from it")
	creeper.free()
	# Sleeping with the owner and the dawn gift.
	suite.check(Cats.wake_gift(0.1,rng) == 0 and Cats.wake_gift(0.5,rng) == 0,"no gift outside the dawn window")
	var gifts: int = 0
	var gift_rng := RandomNumberGenerator.new(); gift_rng.seed = 5
	for i in 2000:
		var gift: int = Cats.wake_gift(0.27,gift_rng)
		if gift != 0:
			gifts += 1
			if not Cats.GIFTS.has(gift): suite.check(false,"a gift is from the source's table"); break
	suite.check(absf(float(gifts)/2000.0-0.7) < 0.04,"seven dawns in ten bring a gift (%d of 2000)" % gifts)
	game.day_time = floorf(game.day_time)+1.27
	cat.position = game.player.position+Vector3(3,0,0)
	for child in game.drops.get_children(): child.free()
	var bed_at := arena+Vector3i(-4,0,-4)
	var sleep_rng := RandomNumberGenerator.new(); sleep_rng.seed = 11
	var brought: Array = []
	for i in 20:
		cat.position = game.player.position+Vector3(3,0,0)
		brought += Cats.owner_slept(game,bed_at,sleep_rng)
	suite.check(cat.position.distance_to(Vector3(bed_at)+Vector3(0.5,0.6,0.5)) < 0.1,"a standing tamed cat curls up on its owner's bed")
	suite.check(not brought.is_empty(),"it brings dawn gifts")
	cat.set_meta("sitting",true)
	cat.position = game.player.position+Vector3(3,0,0)
	Cats.owner_slept(game,bed_at,sleep_rng)
	suite.check(cat.position.distance_to(game.player.position+Vector3(3,0,0)) < 0.1,"a sitting cat stays where it was told")
	cat.set_meta("sitting",false)
	for child in game.drops.get_children(): child.free()
	# Village spawning.
	suite.check(Cats.village_allows(5,4) and not Cats.village_allows(4,0) and not Cats.village_allows(9,5),"a village needs five homes and at most four cats")
	var village: Dictionary = VillageGenerator.nearest(world.generator,Vector3(0,40,0))
	suite.check(Cats.homes_near(game,Vector3(village.center)) >= 5,"a village's centre has at least five homes within 48")
	suite.check(Cats.homes_near(game,Vector3(village.center)+Vector3(200,0,200)) == 0,"open country has none")
	# Breeding.
	var mate: Creature = spawned("cat",game,cat.position+Vector3(1,0,0))
	mate.set_meta("tamed",true); mate.set_meta("owner",game.player_id)
	cat.love_time = Farming.LOVE_TIME; mate.love_time = Farming.LOVE_TIME
	var kitten: Node3D = null
	for i in 10:
		kitten = Cats.breed_step(game,cat,0.5)
		if kitten == null: kitten = Cats.breed_step(game,mate,0.5)
		if kitten != null: break
	suite.check(kitten != null and Cats.tamed(kitten) and kitten.growth_remaining > 0.0,"two tamed cats in love have a tamed kitten")
	if kitten != null: kitten.free()
	mate.free()
	# Persistence.
	Cats.set_coat(cat,"siamese")
	var record: Dictionary = JSON.parse_string(JSON.stringify(Farming.state(cat)))
	var copy: Creature = spawned("cat",game,Vector3(arena)+Vector3(-2.5,0,-6.5))
	Farming.restore_state(copy,record)
	suite.check(Cats.coat(copy) == "siamese" and Cats.tamed(copy) and Cats.collar(copy) == "#FF65B5" and copy.has_meta("persistent"),"a tamed cat's coat, collar and ownership survive a save")
	suite.check(Farming.managed(copy) and not Farming.managed(wild),"tamed cats are kept; wild ones are not")
	copy.free(); wild.free()

	# --- parrots ------------------------------------------------------------------------------
	var parrot: Creature = spawned("parrot",game,Vector3(arena)+Vector3(0.5,0,-3.5))
	suite.check(Parrots.COLOURS.has(Parrots.colour(parrot)) and parrot.head != null,"a parrot has one of the five colours")
	hold(game,Nodes.SEEDS,200)
	var seed_rng := RandomNumberGenerator.new(); seed_rng.seed = 21
	var used: int = 0
	while not Parrots.tamed(parrot) and used < 150:
		Parrots.use(game,parrot,seed_rng); used += 1
	suite.check(Parrots.tamed(parrot) and used > 1,"seeds tame a parrot at one in ten (%d seeds)" % used)
	hold(game,0,0)
	Parrots.use(game,parrot)
	suite.check(Parrots.sitting(parrot),"the owner's click sits it down")
	Parrots.use(game,parrot)
	suite.check(not Parrots.sitting(parrot),"and stands it up")
	# Perching.
	game.player.position = Vector3(arena)+Vector3(0.5,0,0.5)
	parrot.position = game.player.position+Vector3(0,1.2,0.2)
	parrot.set_meta("perch_cooldown",0.0)
	suite.check(Parrots.step(game,parrot,0.05,rng) and Parrots.perch(parrot) == "left","a tamed parrot beside its owner perches on the left shoulder")
	var second: Creature = spawned("parrot",game,game.player.position+Vector3(0,1.2,-0.2))
	second.set_meta("tamed",true); second.set_meta("owner",game.player_id)
	suite.check(Parrots.step(game,second,0.05,rng) and Parrots.perch(second) == "right","a second takes the right shoulder")
	var third: Creature = spawned("parrot",game,game.player.position+Vector3(0.2,1.2,0))
	third.set_meta("tamed",true); third.set_meta("owner",game.player_id)
	suite.check(not Parrots.step(game,third,0.05,rng) and Parrots.perch(third).is_empty(),"a third finds no shoulder")
	third.free(); second.free()
	Parrots.step(game,parrot,0.05,rng)
	suite.check(parrot.position.distance_to(game.player.position) < 2.0,"a perched parrot rides with its owner")
	game.player.position.y += 3.0
	Parrots.step(game,parrot,0.05,rng)
	suite.check(Parrots.perch(parrot).is_empty(),"it hops off when its owner is over air")
	game.player.position.y -= 3.0
	# Dancing.
	world.set_node(arena+Vector3i(0,0,-8),Jukeboxes.ID)
	Jukeboxes.play(world,arena+Vector3i(0,0,-8),Jukeboxes.DISC_13)
	parrot.set_meta("perch_cooldown",5.0)
	parrot.position = Vector3(arena)+Vector3(0.5,0,-6.5)
	Parrots.step(game,parrot,0.05,rng)
	suite.check(Parrots.dancing(parrot) and Parrots.direction(game,parrot) == Vector3.ZERO,"a parrot within three of a playing jukebox dances")
	Jukeboxes.stop(world,arena+Vector3i(0,0,-8))
	world.set_node(arena+Vector3i(0,0,-8),Nodes.AIR)
	Parrots.step(game,parrot,0.05,rng)
	suite.check(not Parrots.dancing(parrot),"and stops when the music does")
	# Imitation.
	var zombie: Creature = spawned("zombie",game,parrot.position+Vector3(4,0,0))
	var heard: String = Parrots.imitate(game,parrot,RandomNumberGenerator.new())
	suite.check(not heard.is_empty(),"a parrot imitates a nearby mob")
	zombie.free()
	# Persistence.
	Parrots.set_colour(parrot,"blue")
	var parrot_record: Dictionary = JSON.parse_string(JSON.stringify(Farming.state(parrot)))
	var parrot_copy: Creature = spawned("parrot",game,Vector3(arena)+Vector3(4.5,0,-6.5))
	Farming.restore_state(parrot_copy,parrot_record)
	suite.check(Parrots.colour(parrot_copy) == "blue" and Parrots.tamed(parrot_copy),"a tamed parrot's colour and ownership survive a save")
	parrot_copy.free()
	# The cookie.
	hold(game,VillageContent.COOKIE,1)
	Parrots.use(game,parrot)
	suite.check(parrot.health <= 0.0 or parrot.is_queued_for_deletion(),"a cookie kills a parrot")

	for mob in game.creatures.get_children(): mob.free()
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode
	game.day_time = old_time
