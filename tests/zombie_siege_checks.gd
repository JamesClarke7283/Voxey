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
	# The heat score counts living records near a point.
	var village: Dictionary = VillageGenerator.nearest(world.generator,game.player.position)
	game.villages.make_record(village.key+"/siege","farmer",game.player.position,village.center,village.center,village.center)
	suite.check(ZombieSiege.village_heat(game,game.player.position) >= 1,"a living resident near the point raises the heat score")
	var people: Dictionary = game.villages.state().people
	people[people.keys()[0]].dead = true
	suite.check(ZombieSiege.village_heat(game,game.player.position) == 0,"a dead resident does not count towards the heat")
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
