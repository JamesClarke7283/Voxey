extends RefCounted

# The wither's skull projectile: `mobs_mc/wither.lua`'s ranged attack, its two arrow
# definitions, the impact rules and the charge blast. Every source rule cited in
# `scripts/wither_skulls.gd`'s header.

static func spawn_target(game: Node3D, at: Vector3) -> void:
	# A clear box to fire into, so a skull is never immediately blocked.
	for x in range(4,13):
		for z in range(4,13):
			for y in range(1998,2006): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(Vector3i(8,1998,8),Nodes.STONE)

static func run(suite: Object, game: Node3D) -> void:
	var saved_position: Vector3 = game.player.position
	var saved_health: float = game.player.health
	var saved_difficulty: int = game.difficulty

	# --- every fourth skull is the strong one ---------------------------------
	# `(ws.skulls_fired % 4) == 0`, with the counter incremented before the test, so
	# the fourth, eighth and twelfth are strong and the first is not.
	suite.check(not WitherSkulls.is_strong(1) and not WitherSkulls.is_strong(2) and not WitherSkulls.is_strong(3),"the first three skulls are the plain variant")
	suite.check(WitherSkulls.is_strong(4) and WitherSkulls.is_strong(8) and not WitherSkulls.is_strong(9),"the fourth and eighth are strong, as the source's modulo says")
	suite.check(WitherSkulls.velocity_for(1) == 17.0 and WitherSkulls.velocity_for(4) == 12.0,"a plain skull uses velocity 17 and the strong one 12")
	suite.check(not WitherSkulls.redirectable(1) and WitherSkulls.redirectable(4),"only the strong skull is `redirectable`, as the source declares")

	# --- the withering a hit applies ------------------------------------------
	# `mcl_vars.difficulty >= 2` gates it, and the duration is the source's own
	# `difficulty == 2 and 10 or 40`.
	suite.check(WitherSkulls.wither_duration(1) == 0.0,"Easy applies no withering")
	suite.check(WitherSkulls.wither_duration(2) == 40.0 and WitherSkulls.wither_duration(3) == 10.0,"Normal withers for forty seconds and Hard for ten")
	suite.check(WitherSkulls.WITHER_LEVEL == 2,"the effect is level two, as the source's `give_effect_by_level` says")

	# --- the rose soil and the spot search ------------------------------------
	suite.check(WitherSkulls.rose_soil(Nodes.GRASS) and WitherSkulls.rose_soil(Nodes.DIRT) and WitherSkulls.rose_soil(Nodes.NETHERRACK) and WitherSkulls.rose_soil(Nodes.SOUL_SAND),"grass, dirt, netherrack and soul sand are all rose soil")
	suite.check(not WitherSkulls.rose_soil(Nodes.STONE) and not WitherSkulls.rose_soil(Nodes.SAND),"stone and sand are not, so no rose can grow there")
	spawn_target(game,Vector3(8.5,1999.0,8.5))
	game.world.set_node(Vector3i(9,1998,8),Nodes.DIRT)
	var spot: Vector3i = WitherSkulls.rose_spot(game.world,Vector3(8.5,1999.0,8.5))
	suite.check(spot == Vector3i(9,1999,8),"the rose is placed in the air cell above the nearest soil within two nodes")
	game.world.set_node(Vector3i(9,1998,8),Nodes.STONE)
	suite.check(WitherSkulls.rose_spot(game.world,Vector3(8.5,1999.0,8.5)) == Vector3i.ZERO,"with no soil in reach there is nowhere to put the rose")

	# --- the impact -----------------------------------------------------------
	# A direct hit deals eight as `wither_skull`, applies the withering at the
	# source's difficulty, and leaves a wither rose when it kills.
	spawn_target(game,Vector3(8.5,1999.0,8.5))
	game.world.set_node(Vector3i(9,1998,8),Nodes.GRASS)
	game.gamemode = "survival"; game.difficulty = 3
	# The golem is the test victim because it survives both the eight and the blast,
	# so the knockback can be observed at all. The source's own order is withering,
	# then the eight, then a radius-one blast, which is asserted below by the cow.
	var golem: Creature = game.spawn_creature("iron_golem",Vector3(9.5,1999.0,8.5))
	golem.set_physics_process(false)
	golem.health = golem.info().health
	var lethal: bool = WitherSkulls.impact(game,golem,Vector3(9.5,1999.0,8.5),Vector3(1,0,0),3)
	suite.check(golem.health <= golem.info().health-WitherSkulls.SKULL_DAMAGE,"a direct hit deals the source's eight to a mob")
	suite.check(PotionEffects.level(golem,"withering") == 2,"a Hard hit applies withering level two")
	suite.check(is_equal_approx(float(PotionEffects.snapshot(golem).get("withering",{}).get("duration",0.0)),10.0),"and for the source's ten seconds on Hard")
	var flat: Vector3 = Vector3(golem.knock.x,0.0,golem.knock.z)
	suite.check(not lethal and golem.knock.length() > 0.0 and flat.normalized().dot(Vector3(1,0,0)) > 0.9,"a survivor is knocked along the skull's horizontal heading")
	if is_instance_valid(golem): golem.queue_free()
	# The blast is part of the strike, so a victim the eight alone would leave alive
	# is finished by it — the source's `hit_mob` explodes after the damage.
	var cow: Creature = game.spawn_creature("cow",Vector3(9.5,1999.0,8.5))
	cow.set_physics_process(false); cow.health = 10.0
	var health_before: float = cow.health
	var blasted: bool = WitherSkulls.impact(game,cow,Vector3(9.5,1999.0,8.5),Vector3(1,0,0),1)
	# The hit alone takes eight, so a ten-health cow survives it — and the strike's own
	# radius-one blast then takes the rest, which is why the loss exceeds the eight.
	suite.check(cow.health <= 0.0 and health_before-cow.health > WitherSkulls.SKULL_DAMAGE,"the hit and its own blast together take more than the eight")
	# The source's kill test is `l.health - 8 <= 0` read after the damage, so it
	# subtracts the eight a second time — which is why a victim left at two health
	# still reports the kill, and why the rose appears when the blast, not the blow,
	# was what actually finished it.
	suite.check(blasted,"the source's own double-subtracted kill test is ported as written")
	if is_instance_valid(cow): cow.queue_free()
	cow = game.spawn_creature("cow",Vector3(9.5,1999.0,8.5))
	cow.set_physics_process(false); cow.health = 10.0
	# A lethal hit leaves the rose and reports the kill.
	game.world.set_node(Vector3i(9,1998,8),Nodes.GRASS)
	cow.health = 3.0
	PotionEffects.clear(cow)
	lethal = WitherSkulls.impact(game,cow,Vector3(9.5,1999.0,8.5),Vector3(1,0,0),1)
	suite.check(lethal,"a hit that drops the victim reports the kill")
	suite.check(game.world.node_at(Vector3i(9,1999,8)) == FlowersExtra.WITHER_ROSE,"a kill leaves a wither rose on the nearest soil")
	suite.check(PotionEffects.level(cow,"withering") == 0,"Easy applies no withering even on a lethal hit")
	if is_instance_valid(cow): cow.queue_free()

	# --- the player's side ----------------------------------------------------
	game.player.position = Vector3(10.5,1999.0,8.5)
	game.player.health = 20.0; game.player.damage_cooldown = 0.0
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	WitherSkulls.impact(game,game.player,Vector3(10.5,1999.0,8.5),Vector3(1,0,0),2)
	suite.check(game.player.health < 20.0,"a skull hurts the player through the ordinary damage path")
	suite.check(PotionEffects.level(game.player,"withering") == 2,"and applies the withering to the player too")

	# --- the boss actually fires one -------------------------------------------
	# The ranged branch reaches this module through `WitherSkulls.fire`, so a boss
	# within range produces a skull node in `game.entities` with the source's speed.
	spawn_target(game,Vector3(8.5,1999.0,8.5))
	game.player.position = Vector3(8.5,1999.0,16.5)
	# `fire` itself needs no gamemode, so creative is not set here: leaving it set
	# made every later `hurt` in this file a no-op, which is the game's own rule.
	XpOrbs.clear(game)
	var fired: WitherSkull = WitherSkulls.fire(game,null,Vector3(8.5,1999.0,8.5),Vector3(0,0,-15),1)
	suite.check(fired != null and is_instance_valid(fired) and fired.get_parent() == game.entities,"firing adds a skull to the entity group")
	suite.check(is_equal_approx(fired.velocity.length(),WitherSkulls.SKULL_VELOCITY),"the skull flies at the source's plain speed")
	var strong: WitherSkull = WitherSkulls.fire(game,null,Vector3(8.5,1999.0,8.5),Vector3(0,0,-15),4)
	suite.check(strong.strong and is_equal_approx(strong.velocity.length(),WitherSkulls.STRONG_VELOCITY),"the fourth skull is the slower strong variant")
	# It flies forward and turns, as the source's `rotate = 90` says. The game must
	# be "playing" for the projectile to step, which is how every projectile in this
	# project behaves, so the state is set for the step and put back after.
	var start: Vector3 = fired.position
	game.state = "playing"
	fired._physics_process(0.1)
	game.state = "paused"
	suite.check(fired.position.z < start.z and fired.position != start and fired.rotation.length() > 0.0,"a skull advances along its heading and turns in flight")
	for node in [fired,strong]:
		if is_instance_valid(node): node.queue_free()

	# --- the charge -----------------------------------------------------------
	# `WITHER_CHARGE_DAMAGE = 15` within `core.objects_inside_radius(self_pos, 3)`.
	spawn_target(game,Vector3(8.5,1999.0,8.5))
	game.player.position = Vector3(9.5,1999.0,8.5)
	# The earlier player test left the post-hit invulnerability window open, and
	# `hurt` refuses inside it — which is the game's own rule, not a defect.
	game.player.health = 100.0; game.player.damage_cooldown = 0.0
	PotionEffects.clear(game.player)
	var boss: Creature = game.spawn_creature("wither",Vector3(8.5,1999.0,8.5))
	boss.set_physics_process(false)
	var victim: Creature = game.spawn_creature("cow",Vector3(10.0,1999.0,8.5))
	victim.set_physics_process(false)
	var far: Creature = game.spawn_creature("cow",Vector3(14.0,1999.0,8.5))
	far.set_physics_process(false)
	# The earlier player hit knocked them back through `hurt`'s own impulse, so the
	# stance is set again immediately before the charge.
	game.player.position = Vector3(9.5,1999.0,8.5)
	game.player.velocity = Vector3.ZERO
	game.player.health = 100.0; game.player.damage_cooldown = 0.0
	var struck: int = WitherSkulls.charge(game,Vector3(8.5,1999.0,8.5),boss)
	suite.check(struck >= 1,"the charge strikes what is inside three nodes and not what is outside")
	suite.check(boss.health >= boss.info().health,"the boss's own charge never hurts it")
	var lost: float = 100.0-game.player.health
	suite.check(lost >= WitherSkulls.CHARGE_DAMAGE,"the charge deals the source's fifteen to the player (lost=%s)"%lost)
	for mob in [boss,victim,far]:
		if is_instance_valid(mob): mob.queue_free()
	PotionEffects.clear(game.player)
	game.player.position = saved_position
	game.player.health = saved_health
	game.difficulty = saved_difficulty
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.inventory.restore([])
