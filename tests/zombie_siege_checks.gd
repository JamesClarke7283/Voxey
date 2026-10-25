extends RefCounted

# Zombie sieges (mcl_zombie_sieges): a one-in-ten midnight roll sends zombies at a
# village rather than at the player.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(ZombieSiege.CHANCE_IN == 10 and ZombieSiege.HEAT_MIN == 5 and ZombieSiege.BEARING_DISTANCE == 32,"the siege uses the source's one-in-ten roll, five heat and thirty-two block bearing")
	suite.check(ZombieSiege.OUTER_ATTEMPTS == 20 and ZombieSiege.INNER_ATTEMPTS == 10,"the summon makes the source's twenty outer and ten inner attempts")
	var world: VoxelWorld = game.world
	var state: Dictionary = ZombieSiege.runtime(world)
	suite.check(state.has("night") and state.has("rng") and state.has("active"),"siege state is created on demand with a seeded generator")
	# The chance roll is a one-in-ten, so it must be able to fail.
	var rng := RandomNumberGenerator.new()
	var hits: int = 0
	for i in 200:
		if rng.randi_range(0,ZombieSiege.CHANCE_IN-1) == 0: hits += 1
	suite.check(hits > 0 and hits < 60,"the one-in-ten roll both fires and fails over two hundred draws")
	# A daylit moment never qualifies, and neither does an early day.
	rng.seed = 1
	game.daylight = 1.0
	suite.check(not ZombieSiege.choose_attack_point(game,rng).is_finite(),"the siege never starts in daylight")
	game.daylight = ZombieSiege.NIGHT_DAYLIGHT_MAX+0.01
	suite.check(not ZombieSiege.choose_attack_point(game,rng).is_finite(),"a moment above the source's night threshold does not qualify")
	# With no villagers nearby there is no heat, so no siege.
	game.daylight = 0.0
	suite.check(ZombieSiege.village_heat(game,game.player.position) == 0 and not ZombieSiege.choose_attack_point(game,rng).is_finite(),"a village with no residents produces no heat and so no siege")
	# Only valid claimed POIs seed the source heat field.
	var village: Dictionary = VillageGenerator.nearest(world.generator,game.player.position)
	var bed := Vector3i(game.player.position.floor())
	var before: int = world.node_at(bed)
	world.set_node(bed,VillageContent.BED_RED)
	game.villages.make_record(village.key+"/siege","farmer",game.player.position,bed,bed,bed)
	suite.check(ZombieSiege.village_heat(game,game.player.position) == 6,"a living resident's claimed bed seeds six levels of POI heat")
	var people: Dictionary = game.villages.state().people
	people[village.key+"/siege"].dead = true
	suite.check(ZombieSiege.village_heat(game,game.player.position) == 0,"a dead resident does not count towards the heat")
	world.set_node(bed,before)
	# The night guard makes the event one-shot.
	suite.check(ZombieSiege.night_of(5,0.0) == 4 and ZombieSiege.night_of(5,0.8) == 5,"a night belongs to the day that started it")
	# Ending the event clears its bookkeeping.
	state = ZombieSiege.runtime(world)
	state["active"] = true
	world.set_meta("zombie_siege",state)
	suite.check(ZombieSiege.finished(game),"an active siege with no marked mobs alive finishes")
	suite.check(not bool(ZombieSiege.runtime(world).get("active",true)),"finishing a siege clears its active flag")
	suite.check(not ZombieSiege.finished(game),"a finished siege does not finish twice")
	ZombieSiege.reset(world)
	suite.check(not world.has_meta("zombie_siege"),"resetting a world drops the siege state")
