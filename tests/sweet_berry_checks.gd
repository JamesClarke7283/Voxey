extends RefCounted

# Sweet berry thorns (Mineclonia `mcl_farming/sweet_berry.lua`: the
# `sweet_berry_thorny` group and the half-second `berry_damage_check` globalstep;
# the slowdown tables in `mcl_mobs/physics.lua` and `mcl_serverplayer/player.lua`).
#
# The two rules are deliberately separate in the source and this suite keeps them
# apart: **thorniness gates the damage only**, while **every** stage of the bush is
# in both of the source's slow tables. The other half worth pinning down is the
# damage rule's velocity gate — a player standing still inside a berry patch is
# untouched, which is what makes the patch safe to camp in.

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var player: VoxeyPlayer = game.player
	# The world state this suite borrows: the cell it plants a bush in, the ground
	# under it, and everything about the player the bush can change.
	var cell := Vector3i(8,170,8)
	var old_above: int = world.node_at(cell)
	var old_below: int = world.node_at(cell+Vector3i.DOWN)
	var old_position: Vector3 = player.position
	var old_velocity: Vector3 = player.velocity
	var old_health: float = player.health
	var old_mode: String = game.gamemode
	var old_cooldown: float = player.damage_cooldown
	var old_armor: Array = player.armor_slots.duplicate(true)

	# --- the four stages --------------------------------------------------------
	suite.check(SweetBerryThorns.FIRST == VillageContent.SWEET_BERRIES_0 and SweetBerryThorns.COUNT == 4,"the module covers the four existing sweet berry stage nodes")
	for stage in 4:
		suite.check(SweetBerryThorns.is_bush(VillageContent.SWEET_BERRIES_0+stage),"stage %d is a sweet berry bush"%stage)
	suite.check(SweetBerryThorns.stage(VillageContent.SWEET_BERRIES_3) == 3 and SweetBerryThorns.stage(Nodes.SAPLING) == -1,"the stage helper reads the node and rejects anything else")
	suite.check(not SweetBerryThorns.is_bush(Nodes.SAPLING) and not SweetBerryThorns.is_bush(Nodes.AIR),"a sapling and air are not sweet berry bushes")

	# --- `if i > 0 then groups.sweet_berry_thorny = 1 end` ----------------------
	# The source leaves stage 0 out of the group and puts every later stage in it,
	# so a freshly planted bush is the only one that does not bite.
	suite.check(not SweetBerryThorns.thorny(VillageContent.SWEET_BERRIES_0),"the first stage is exempt from the source's thorny group")
	for stage in range(1,4):
		suite.check(SweetBerryThorns.thorny(VillageContent.SWEET_BERRIES_0+stage),"stage %d carries the source's thorny group"%stage)
	suite.check(not SweetBerryThorns.thorny(Nodes.SAPLING),"a sapling is never thorny")

	# --- the slowdown, which is not gated by thorniness -------------------------
	# Both of the source's tables list all four stages at x = 0.8, y = 0.75, z = 0.8,
	# so the harmless stage-0 bush drags down as much as the ripe one.
	for stage in 4:
		var factors: Vector3 = SweetBerryThorns.slow(VillageContent.SWEET_BERRIES_0+stage)
		suite.check(factors.is_equal_approx(Vector3(0.8,0.75,0.8)),"stage %d carries the source's per-axis slowdown"%stage)
	suite.check(SweetBerryThorns.slow(Nodes.SAPLING).is_equal_approx(Vector3.ONE) and SweetBerryThorns.slow(Nodes.AIR).is_equal_approx(Vector3.ONE),"anything that is not a sweet berry bush is not slowed")
	suite.check(SweetBerryThorns.slow(Nodes.SAPLING) == Vector3.ONE,"a non-bush multiplies speed by exactly one")

	# --- the damage rule, in a real cell ----------------------------------------
	# The bush needs ground under it, and the player's feet must be in the bush cell.
	world.set_node(cell+Vector3i.DOWN,Nodes.STONE)
	world.set_node(cell,VillageContent.SWEET_BERRIES_3)
	suite.check(world.node_at(cell) == VillageContent.SWEET_BERRIES_3,"a ripe bush stands in the test cell")
	player.position = Vector3(8.5,170.0,8.5)
	game.gamemode = "survival"
	player.armor_slots = []

	# A moving player takes the source's half point. The velocity is set because the
	# source gates on it: `step`'s `moving` flag alone must not be enough.
	player.health = 20.0; player.damage_cooldown = 0.0; player.velocity = Vector3(1,0,0)
	suite.check(SweetBerryThorns.step(game,player,true),"standing in a bush reports that it applied")
	suite.check(is_equal_approx(player.health,19.5),"a moving player in a ripe bush loses the source's half point")

	# The same cell, the same velocity, but no movement intent behind it.
	player.health = 20.0; player.damage_cooldown = 0.0; player.velocity = Vector3(1,0,0)
	SweetBerryThorns.step(game,player,false)
	suite.check(is_equal_approx(player.health,20.0),"a player who is not moving is not hurt by the bush")

	# Movement intent without actual motion is also safe: the source's own check is
	# on the velocity, so a player pressed against a wall inside a bush is unharmed.
	player.health = 20.0; player.damage_cooldown = 0.0; player.velocity = Vector3.ZERO
	SweetBerryThorns.step(game,player,true)
	suite.check(is_equal_approx(player.health,20.0),"a stationary player inside a bush is unharmed even while pushing against it")

	# Creative is immune, which the source's own player damage enforces.
	game.gamemode = "creative"
	player.health = 20.0; player.damage_cooldown = 0.0; player.velocity = Vector3(1,0,0)
	suite.check(not SweetBerryThorns.damage(game,player,VillageContent.SWEET_BERRIES_3),"the damage rule refuses a creative player")
	SweetBerryThorns.step(game,player,true)
	suite.check(is_equal_approx(player.health,20.0),"a creative player passing through a bush takes no damage")

	# A harmless stage: the same cell and motion, with the bush replaced by the one
	# stage the source leaves out of the thorny group.
	game.gamemode = "survival"
	world.set_node(cell,VillageContent.SWEET_BERRIES_0)
	player.health = 20.0; player.damage_cooldown = 0.0; player.velocity = Vector3(1,0,0)
	suite.check(not SweetBerryThorns.damage(game,player,VillageContent.SWEET_BERRIES_0),"the exempt first stage does not hurt a moving player")
	# `step` still reports true here: the stage-0 bush does not bite, but it is in
	# both of the source's slow tables, so it still drags the player down.
	suite.check(SweetBerryThorns.step(game,player,true),"a stage-0 bush still applies its slowdown")
	# The thorny gate is the only difference between stage 0 and stage 3: the same
	# cell, the same motion, the same slowdown, and only one of them hurts.
	suite.check(is_equal_approx(SweetBerryThorns.slow(VillageContent.SWEET_BERRIES_0).x,SweetBerryThorns.slow(VillageContent.SWEET_BERRIES_3).x),"the exempt stage slows exactly as much as the ripe one")
	suite.check(is_equal_approx(player.health,20.0),"walking through a stage-0 bush is harmless")
	world.set_node(cell,Nodes.AIR)

	# --- a creature ------------------------------------------------------------
	# The source's globalstep covers every `is_mob` entity, not only players, and a
	# mob has no gamemode to exempt it.
	world.set_node(cell,VillageContent.SWEET_BERRIES_3)
	var cow: Creature = game.spawn_creature("cow",Vector3(8.5,170.0,8.5))
	if cow != null:
		cow.velocity = Vector3(1,0,0)
		var mob_health: float = cow.health
		suite.check(SweetBerryThorns.damage(game,cow,VillageContent.SWEET_BERRIES_3),"a moving mob in a ripe bush is hurt")
		suite.check(is_equal_approx(cow.health,mob_health-0.5),"the mob loses the source's half point")
		cow.queue_free()
	else: suite.check(false,"the cow the berry checks need could be spawned")

	# --- restore ---------------------------------------------------------------
	world.set_node(cell,old_above)
	world.set_node(cell+Vector3i.DOWN,old_below)
	player.health = old_health; player.damage_cooldown = old_cooldown
	player.velocity = old_velocity; player.position = old_position
	player.armor_slots = old_armor
	game.gamemode = old_mode
