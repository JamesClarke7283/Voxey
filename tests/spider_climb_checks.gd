extends RefCounted

# Focused regression for the spider's three source behaviours: `always_climb`
# wall climbing, the one-in-a-hundred skeleton jockey, and the cave spider with
# its venomous bite. Reference: mobs_mc/spider.lua and mcl_mobs/physics.lua.

static func spawned(kind: String, game: Node3D, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	if mob != null: mob.set_physics_process(false)
	return mob

# A flat arena with a solid wall to the east of the spawn point and a roof over
# the whole arena, so a climbing spider runs out of ceiling rather than merely
# running out of wall. Returns the wall column and the roof's own cell.
static func arena(world: VoxelWorld) -> Dictionary:
	var base := Vector3i(8,169,8)
	for x in range(-4,7):
		for z in range(-4,5):
			world.set_node(Vector3i(base.x+x,base.y,base.z+z),Nodes.STONE)
			for y in range(1,25): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)
	# The wall stands two blocks east of the arena's centre and runs taller than
	# the roof, so the rise is stopped by the roof and not by the wall's own top.
	var wall_x: int = base.x+2
	for z in range(-4,5):
		for y in range(1,21): world.set_node(Vector3i(wall_x,base.y+y,base.z+z),Nodes.STONE)
	# The roof caps the arena ten cells up, which is one full spider body above
	# the tallest point the climb can reach.
	for x in range(-4,7):
		for z in range(-4,5): world.set_node(Vector3i(base.x+x,base.y+10,base.z+z),Nodes.STONE)
	return {"base":base,"wall_x":wall_x,"top":base.y+10}

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_difficulty: int = game.difficulty
	var old_effects: Dictionary = game.survival.effect_snapshot()
	var old_health: float = game.player.health
	var old_position: Vector3 = game.player.position
	game.gamemode = "survival"
	for mob in game.creatures.get_children(): mob.free()

	# --- registry ---------------------------------------------------------
	suite.check(SpiderClimb.is_climbing_kind("spider") and SpiderClimb.is_climbing_kind("cave_spider"),"both spider kinds climb, as `always_climb` is inherited through the source's table merge")
	suite.check(not SpiderClimb.is_climbing_kind("zombie"),"a zombie does not climb")
	suite.check(not SpiderClimb.is_climbing_kind("silverfish"),"a silverfish does not climb, since the source sets the flag on the spider alone")
	suite.check(SpiderClimb.is_cave_spider("cave_spider") and not SpiderClimb.is_cave_spider("spider"),"only the cave spider is a cave spider")
	suite.check(Creature.KINDS.has("cave_spider"),"the cave spider is a registered creature")

	# --- the cave spider's own numbers ------------------------------------
	var spider: Dictionary = Creature.KINDS["spider"]
	var cave: Dictionary = Creature.KINDS["cave_spider"]
	suite.check(is_equal_approx(cave.health,12.0),"a cave spider has the source's twelve health")
	suite.check(cave.health < spider.health,"a cave spider has less health than an ordinary spider")
	suite.check(cave.width < spider.width and cave.height < spider.height,"a cave spider is smaller than a spider, as the source's collisionbox is")
	suite.check(cave.damage == spider.damage,"a cave spider inherits the spider's melee damage, which the source does not override")
	suite.check(cave.get("poisonous",false) and not spider.get("poisonous",false),"the cave spider carries the poison behaviour flag and the spider does not")
	suite.check(cave.pitch > spider.pitch,"a cave spider sounds higher pitched, as the source raises its base_pitch")
	suite.check(cave.get("neutral_by_day",false) == spider.get("neutral_by_day",false) and cave.get("leaps",false) == spider.get("leaps",false),"a cave spider inherits the spider's daylight neutrality and leap")
	suite.check(cave.drops == spider.drops,"a cave spider inherits the spider's drop table")
	suite.check(SpiderClimb.is_poisonous_kind("cave_spider") and not SpiderClimb.is_poisonous_kind("spider") and not SpiderClimb.is_poisonous_kind("zombie"),"only the cave spider's bites are venomous")
	suite.check(SpiderClimb.SOURCE_HALF["spider"] > SpiderClimb.SOURCE_HALF["cave_spider"],"the cave spider's source half-width is the smaller of the two")

	# --- the climb constants come from the shared physics -----------------
	suite.check(is_equal_approx(SpiderClimb.CLIMB_SPEED,4.0),"the climb rises at the source's `v.y = 4.0`")
	suite.check(is_equal_approx(SpiderClimb.LATERAL_CLAMP,3.0),"the climb keeps the source's 3.0 lateral clamp")

	# --- `navigation_step`'s obstruction test -----------------------------
	suite.check(SpiderClimb.climbing_obstruction(Vector3(0,0,0),Vector3(5,0.5,0),0.7),"a distant destination counts as an obstruction half a block below it")
	suite.check(not SpiderClimb.climbing_obstruction(Vector3(0,0,0),Vector3(0.3,0.5,0),0.7),"a destination within half a body width is not climbed toward")
	suite.check(SpiderClimb.climbing_obstruction(Vector3(0,1,0.8),Vector3(0.6,0.5,0),0.7) and not SpiderClimb.climbing_obstruction(Vector3(0,1,0.2),Vector3(0.6,0.5,0),0.7),"a spider level with its destination needs the source's full 0.7-block body width, not half of it")

	# --- climbing a wall --------------------------------------------------
	var room: Dictionary = arena(world)
	var wall_x: int = int(room.wall_x)
	var top: int = int(room.top)
	var floor_y: float = float(room.base.y)+1.0
	# Each climber starts with its own body just short of the wall face, since the
	# cave spider's body is half the spider's and a shared position would leave it
	# floating in clear air.
	var start := Vector3(float(wall_x)-0.6,floor_y,float(room.base.z)+0.5)
	var climber: Creature = spawned("spider",game,start)
	suite.check(climber != null,"a spider can be spawned into the arena")
	climber.direction = Vector3.RIGHT
	suite.check(not world.intersects(climber.position,climber.width,climber.height),"the spider starts in clear air beside the wall")
	suite.check(world.intersects(climber.position+Vector3.RIGHT*(climber.width+SpiderClimb.PROBE_MARGIN),climber.width,climber.height),"the wall is directly in front of the spider")
	climber.velocity = Vector3(9.0,-9.0,0.0)
	var rose: bool = SpiderClimb.climb(climber,0.05)
	suite.check(rose,"a spider touching a wall climbs it")
	suite.check(climber.position.y > start.y,"the climb raised the spider's height")
	suite.check(climber.velocity.x <= SpiderClimb.LATERAL_CLAMP,"the climb clamps lateral speed to the source's 3.0")
	# The rise is the source's 4.0 blocks/s, not a decaying remainder of it: over
	# a second of steps the spider climbs four blocks less the one-frame settle.
	var rate: Creature = spawned("spider",game,start)
	rate.direction = Vector3.RIGHT
	var rate_start: float = rate.position.y
	for i in 20: SpiderClimb.climb(rate,0.05)
	suite.check(rate.position.y-rate_start > 3.4,"twenty steps of a twentieth of a second lift the spider a little over the source's four blocks per second")
	rate.free()
	var steps: int = 0
	while steps < 200 and SpiderClimb.climb(climber,0.05): steps += 1
	suite.check(steps > 5,"the spider keeps climbing for many steps while the wall lasts")
	suite.check(climber.position.y > start.y+1.0,"repeated climbs lift the spider well clear of its starting height")
	suite.check(climber.position.y+climber.height <= float(top)+0.001,"the spider stops at the ceiling rather than climbing through it")
	var ceiling_y: float = climber.position.y
	suite.check(SpiderClimb.climb(climber,0.05) and is_equal_approx(climber.position.y,ceiling_y),"a spider pinned at the ceiling is still climbing but gains no height, which is where the source's engine collision leaves it")
	# The climb is only for obstructed spiders: the same kind in open air stays put.
	var flyer: Creature = spawned("spider",game,start+Vector3(-1.5,3.0,0.0))
	flyer.direction = Vector3.LEFT
	suite.check(not SpiderClimb.climb(flyer,0.05) and is_equal_approx(flyer.position.y,start.y+3.0),"an unobstructed spider in open air does not climb")
	# And the cave spider climbs too, since it merges the same table. It starts
	# hard against the wall because its own body is half the spider's width, which
	# is exactly how far a smaller mob may approach before it touches.
	var cave_start := Vector3(float(wall_x)-0.27,floor_y,float(room.base.z)+0.5)
	var cave_climber: Creature = spawned("cave_spider",game,cave_start)
	cave_climber.direction = Vector3.RIGHT
	suite.check(not world.intersects(cave_climber.position,cave_climber.width,cave_climber.height) and world.intersects(cave_climber.position+Vector3.RIGHT*(cave_climber.width+SpiderClimb.PROBE_MARGIN),cave_climber.width,cave_climber.height),"the cave spider starts in clear air with the wall in front of it")
	suite.check(SpiderClimb.climb(cave_climber,0.05) and cave_climber.position.y > cave_start.y,"a cave spider climbs the same wall")
	# Facing away from the wall, neither kind climbs.
	var away: Creature = spawned("spider",game,start)
	away.direction = Vector3.LEFT
	suite.check(not SpiderClimb.climb(away,0.05),"a spider facing away from the wall does not climb it")
	for mob in [climber,flyer,cave_climber,away]: mob.free()

	# --- the one-in-a-hundred jockey roll ---------------------------------
	suite.check(SpiderClimb.JOCKEY_CHANCE == 100,"the source's `math.random (100) == 1` is one roll in a hundred")
	var hit := RandomNumberGenerator.new(); hit.seed = 34
	suite.check(SpiderClimb.jockey_roll(hit),"a seeded roll of 1 spawns a jockey")
	var miss := RandomNumberGenerator.new(); miss.seed = 1
	suite.check(not SpiderClimb.jockey_roll(miss),"a seeded roll other than 1 does not")
	var fires: int = 0
	var rolls := RandomNumberGenerator.new(); rolls.seed = 91
	for i in 20000:
		if SpiderClimb.jockey_roll(rolls): fires += 1
	suite.check(fires > 100 and fires < 300,"the roll fires about one time in a hundred over many draws")
	suite.check(SpiderClimb.jockey_allowed("spider") and not SpiderClimb.jockey_allowed("cave_spider"),"a cave spider never spawns as a jockey, as the source's `on_spawn` override leaves its body empty")

	# --- the jockey itself ------------------------------------------------
	var mount: Creature = spawned("spider",game,start)
	mount.prey_target = game.player
	mount.provoked = true
	mount.last_seen = 12.0
	var rider: Creature = SpiderClimb.spawn_jockey(game,mount)
	suite.check(rider != null and rider.kind == "skeleton","the jockey is a skeleton")
	if rider != null:
		suite.check(rider.position.distance_to(mount.position) < 0.01,"the jockey is spawned at the spider's own position")
		suite.check(rider.prey_target == mount.prey_target and rider.prey_target == game.player,"the jockey hunts the spider's own victim")
		suite.check(rider.provoked == mount.provoked and is_equal_approx(rider.last_seen,mount.last_seen),"the jockey inherits the spider's provocation and chase clock")
		suite.check(int(rider.get_meta("jockey",0)) == mount.get_instance_id(),"the jockey is tagged with its mount's instance id")
		suite.check(int(mount.get_meta("jockey",0)) == rider.get_instance_id(),"the spider is tagged with its rider's instance id")
	rider.free(); mount.free()

	# --- the per-step hook rolls once per spider --------------------------
	# The runner pauses the game, and the hook is a per-step one, so it is driven
	# from a playing state exactly as the real frame loop would.
	var old_state: String = game.state
	game.state = "playing"
	SpiderClimb.reset(world)
	var rolled: Creature = spawned("spider",game,start)
	SpiderClimb.update(game,1.0)
	suite.check(rolled.has_meta("jockey_rolled"),"the per-step hook rolls for a spider exactly once")
	var riders_after_first: int = jockey_count(game)
	SpiderClimb.update(game,1.0)
	suite.check(jockey_count(game) == riders_after_first,"a spider already rolled a jockey is never rolled again")
	var cave_rolled: Creature = spawned("cave_spider",game,start)
	SpiderClimb.update(game,1.0)
	suite.check(not cave_rolled.has_meta("jockey_rolled") and jockey_count(game) == riders_after_first,"a cave spider is not even a jockey candidate, as the source's `on_spawn` override is an empty body")
	for mob in game.creatures.get_children(): mob.free()
	SpiderClimb.reset(world)
	game.state = old_state

	# --- the cave spider's poison ----------------------------------------
	suite.check(is_equal_approx(SpiderClimb.poison_duration(0),0.0),"poison lasts the source's `dur_easy` of zero on easy difficulty")
	suite.check(is_equal_approx(SpiderClimb.poison_duration(1),7.0),"poison lasts the source's seven seconds on its middle setting")
	suite.check(is_equal_approx(SpiderClimb.poison_duration(2),15.0),"poison lasts the source's fifteen seconds on hard difficulty")
	suite.check(SpiderClimb.POISON_LEVEL == 1,"the source's `dealt_effect` uses level one")
	var biter: Creature = spawned("cave_spider",game,start)
	PotionEffects.clear(game.player); game.player.health = 20
	game.difficulty = 2
	SpiderClimb.poison_on_hit(biter,game.player)
	suite.check(PotionEffects.level(game.player,"poison") > 0,"a cave spider's landed hit poisons the player")
	suite.check(float(game.survival.effects.get("poison",-1)) > 0.0,"the poison effect is registered on the survival clock set")
	PotionEffects.clear(game.player)
	game.difficulty = 0
	SpiderClimb.poison_on_hit(biter,game.player)
	suite.check(PotionEffects.level(game.player,"poison") == 0,"the source's zero-duration easy setting applies no poison at all")
	# An ordinary spider bites without venom, and a spider cannot be poisoned.
	game.difficulty = 2
	var plain: Creature = spawned("spider",game,start)
	SpiderClimb.poison_on_hit(plain,game.player)
	suite.check(PotionEffects.level(game.player,"poison") == 0,"an ordinary spider's bite carries no poison")
	SpiderClimb.poison_on_hit(biter,biter)
	suite.check(PotionEffects.level(biter,"poison") == 0,"the source's poison immunity spares every spider kind, as its resistance check matches on the name")
	suite.check(SpiderClimb.is_poison_immune("spider") and SpiderClimb.is_poison_immune("cave_spider"),"the source's name match covers both spider kinds")
	suite.check(not SpiderClimb.is_poison_immune("silverfish") and not SpiderClimb.is_poison_immune("zombie"),"the source's name match does not cover a silverfish or a zombie")
	PotionEffects.clear(game.player)
	for mob in [biter,plain]: mob.free()

	# --- cleanup ----------------------------------------------------------
	for mob in game.creatures.get_children(): mob.free()
	SpiderClimb.reset(world)
	game.difficulty = old_difficulty
	game.player.position = old_position
	game.player.health = old_health
	game.player.damage_cooldown = 0
	game.survival.restore_effects(old_effects)

static func jockey_count(game: Node3D) -> int:
	var count: int = 0
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.has_meta("jockey") and mob.kind == SpiderClimb.JOCKEY_KIND: count += 1
	return count
