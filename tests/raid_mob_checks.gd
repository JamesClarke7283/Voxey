extends RefCounted

# The two remaining raid roles: the ravager (mobs_mc/ravager.lua) and the vex
# (mobs_mc/vex.lua), plus the source's own wave composition.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(RaidMobs.RAVAGER_HEALTH == 100.0 and RaidMobs.RAVAGER_DAMAGE == 12.0,"the ravager has the source's hundred health and twelve damage")
	suite.check(RaidMobs.RAVAGER_KNOCKBACK_RESISTANCE == 0.75 and RaidMobs.attack_knockback() == 1.5,"the ravager keeps the source's knockback resistance and attack knockback")
	suite.check(RaidMobs.RAVAGER_CAPTAIN == false,"a ravager is never a raid captain, as the source's flag says")
	suite.check(RaidMobs.RAVAGER_DROPS == [[Nodes.SADDLE,1,1,1]],"a ravager drops a saddle at the source's guaranteed chance")
	suite.check(not RaidMobs.jockey_allowed(4) and RaidMobs.jockey_allowed(5),"a ravager may carry a rider from the source's fifth wave")
	suite.check(RaidMobs.VEX_HEALTH == 14.0 and RaidMobs.VEX_DAMAGE == 4.0 and RaidMobs.VEX_XP == 6,"the vex has the source's fourteen health, four damage and six experience")
	suite.check(not RaidMobs.VEX_PHYSICAL and not RaidMobs.VEX_FALL_DAMAGE and RaidMobs.environmental_damage() == 0.0,"a vex passes through blocks and takes no fall or environmental damage")
	# The life clock is `30 + random(90)`, and running it out is what disposes of it.
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var low: float = 999.0; var high: float = 0.0
	for i in 200:
		var life: float = RaidMobs.life_timer(rng)
		low = minf(low,life); high = maxf(high,life)
		if life < RaidMobs.VEX_LIFE_MIN or life > RaidMobs.VEX_LIFE_MIN+RaidMobs.VEX_LIFE_SPAN:
			suite.check(false,"the life clock stays in the source's range"); return
	suite.check(high-low > 30.0,"the vex life clock varies across the source's range")
	suite.check(RaidMobs.expired(0.0) and not RaidMobs.expired(1.0),"a vex expires only once its clock reaches zero")
	# Both kinds are registered and build their own models.
	for kind in [RaidMobs.RAVAGER,RaidMobs.VEX]:
		if not Creature.KINDS.has(kind):
			suite.check(false,"both raid roles are registered"); return
	suite.check(true,"both raid roles are registered as creatures")
	var ravager: Creature = game.spawn_creature(RaidMobs.RAVAGER,game.player.position+Vector3(3,0,0))
	var vex: Creature = game.spawn_creature(RaidMobs.VEX,game.player.position+Vector3(3,0,3))
	suite.check(ravager != null and ravager.health == RaidMobs.RAVAGER_HEALTH,"a spawned ravager has its source health")
	suite.check(vex != null and vex.health == RaidMobs.VEX_HEALTH,"a spawned vex has its source health")
	suite.check(ravager.get_child_count() > 0 and vex.get_child_count() > 0,"both raid roles build a visible model")
	# The source's wave composition, which the raid now follows.
	suite.check(RaidMobs.WAVE_TABLE["pillager"] == [4,3,3,4,4,4,2] and RaidMobs.WAVE_TABLE["ravager"] == [0,0,1,0,1,0,2],"the raid wave table matches the source's own counts")
	suite.check(RaidMobs.count_for("pillager",1) == 4 and RaidMobs.count_for("ravager",3) == 1 and RaidMobs.count_for("witch",4) == 3,"a wave's role counts come from the matching table column")
	suite.check(RaidMobs.count_for("ravager",9) == 2 and RaidMobs.count_for("nobody",1) == 0,"a wave past the table keeps its last column, and an unknown role brings nothing")
	suite.check(RaidMobs.ordinary_waves(0) == 1 and RaidMobs.ordinary_waves(1) == 3,"the ordinary wave count is the source's one plus twice the difficulty")
	# The ravager's roar pushes without damaging.
	var bodies: Array = [ravager]
	var pushed: Array = RaidMobs.roar_targets(Vector3.ZERO,bodies,4.0)
	suite.check(pushed.size() == (1 if Vector3.ZERO.distance_to(ravager.position) <= 4.0 else 0),"the roar only reaches bodies within its radius")
	suite.check(RaidMobs.resist_knockback(4.0) == 1.0,"the ravager's knockback resistance leaves a quarter of an incoming push")
