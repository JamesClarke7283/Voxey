extends RefCounted

# Player hazards, item physics, piglin anger and boss bars added by the parity
# batch: the source rules each one ports are cited in the module headers.

static func clear(game: Node3D) -> void:
	for mob in game.creatures.get_children(): mob.queue_free()
	for drop in game.drops.get_children(): drop.queue_free()

static func run(suite: Object, game: Node3D) -> void:
	hazards(suite,game)
	items(suite,game)
	anger(suite,game)
	bars(suite,game)


# --- suffocation and fall damage (`mcl_player`) ------------------------------

static func hazards(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	# The source's condition: a walkable full opaque cube without
	# `disable_suffocation`. Powder snow is the only carrier of that group in the
	# checkout, and it is deliberately non-solid.
	suite.check(Hazards.suffocates(Nodes.STONE) and Hazards.suffocates(Nodes.DIRT),"stone and dirt suffocate a buried player")
	suite.check(not Hazards.suffocates(Nodes.AIR) and not Hazards.suffocates(Nodes.GLASS),"air and glass do not suffocate")
	suite.check(not Hazards.suffocates(PowderSnow.ID),"powder snow carries the source's disable_suffocation and cannot suffocate")
	suite.check(not Hazards.suffocates(Nodes.WATER) and not Hazards.suffocates(Nodes.VINE),"water and vines do not suffocate")
	# The cell sampled is the head, or the feet in a low pose, as the source does
	# for a swimmer whose head node sits above the body.
	var old_position: Vector3 = game.player.position
	game.player.position = Vector3(8.5,170.2,8.5)
	suite.check(Hazards.sample_cell(game.player,false) == Vector3i(8,171,8),"the head cell is sampled while standing")
	suite.check(Hazards.sample_cell(game.player,true) == Vector3i(8,170,8),"the feet cell is sampled in a low pose")
	game.player.position = old_position
	# A player buried in stone takes the source's one point per half second.
	var old_state: String = game.state
	var old_mode: String = game.gamemode
	game.state = "playing"; game.gamemode = "survival"
	for x in range(6,11):
		for z in range(6,11):
			for y in range(169,173): world.set_node(Vector3i(x,y,z),Nodes.STONE)
	game.player.position = Vector3(8.5,170.2,8.5)
	game.player.health = 20.0; game.player.suffocation_clock = 0.0; game.player.damage_cooldown = 0.0
	var hurt: bool = Hazards.suffocate(world,game.player,false)
	suite.check(hurt and is_equal_approx(game.player.health,20.0-game.player.SUFFOCATION_DAMAGE),"a buried player takes the source's one point of in_wall damage")
	game.player.damage_cooldown = 0.0
	for x in range(6,11):
		for z in range(6,11):
			for y in range(169,173): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.player.health = 20.0; game.state = old_state; game.gamemode = old_mode
	game.player.position = old_position
	# A creature is hurt by the same rule.
	suite.check(Hazards.suffocates(Nodes.BEDROCK) and not Hazards.exempt(Nodes.BEDROCK),"only powder snow is in the source's disable_suffocation group")
	# The fall modifier cancels damage in each forgiving node the source names.
	suite.check(Hazards.forgiving(Nodes.WATER) and Hazards.forgiving(Nodes.END_PORTAL) and Hazards.forgiving(VillageContent.COBWEB) and Hazards.forgiving(Nodes.VINE) and Hazards.forgiving(PowderSnow.ID),"water, an End portal, a cobweb, a vine and powder snow all cancel a fall")
	suite.check(not Hazards.forgiving(Nodes.STONE) and not Hazards.forgiving(Nodes.GRASS),"stone and grass do not cancel a fall")
	# The trace runs along the fall direction, so landing in water below cancels it
	# even when the landing cell itself is solid.
	var lake := Vector3i(8,170,8)
	world.set_node(lake,Nodes.WATER)
	suite.check(Hazards.fall_damage(world,Vector3(lake)+Vector3(0.5,0.9,0.5),Vector3(0,-20,0),9.0) == 0.0,"a fall into water is cancelled by the trace")
	suite.check(Hazards.fall_damage(world,Vector3(lake)+Vector3(0.5,0.9,0.5),Vector3(0,-20,0),9.0,4) == 0.0,"a cancelled fall stays cancelled with Jump Boost")
	world.set_node(lake,Nodes.AIR)
	suite.check(Hazards.fall_damage(world,Vector3(lake),Vector3(0,-20,0),9.0) == 9.0,"a fall onto stone keeps its full damage")
	suite.check(Hazards.fall_damage(world,Vector3(lake),Vector3(0,-20,0),9.0,4) == 5.0,"Jump Boost subtracts one point per level, as the source's leaping rule does")
	suite.check(Hazards.fall_damage(world,Vector3(lake),Vector3(0,-20,0),9.0,12) == 0.0,"the subtraction floors at zero rather than healing")


# --- item physics (`mcl_item_entity`) ----------------------------------------

static func items(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	clear(game)
	var at := Vector3i(8,170,8)
	for x in range(6,11):
		for z in range(6,11):
			for y in range(169,173): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	world.set_node(at+Vector3i.DOWN,Nodes.STONE)
	var one: ItemDrop = game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,Nodes.COBBLE,3)
	var two: ItemDrop = game.spawn_drop(Vector3(at)+Vector3(0.55,0.5,0.55),Nodes.COBBLE,2)
	one.age = 0.0
	suite.check(ItemPhysics.mergeable(one,two),"two identical stacks in range are mergeable")
	suite.check(ItemPhysics.try_merge(one),"the merge runs on a resting pair")
	suite.check(one.amount == 5 and two.is_queued_for_deletion(),"the survivor absorbs the other's count and the other is freed")
	suite.check(one.age == 0.0,"a merged stack is handled as new, so its age resets")
	# A different wear, metadata or a full stack must refuse.
	var worn: ItemDrop = game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,Nodes.TOOLS,1,400)
	var fresh: ItemDrop = game.spawn_drop(Vector3(at)+Vector3(0.4,0.5,0.4),Nodes.TOOLS,1,7)
	suite.check(not ItemPhysics.mergeable(worn,fresh),"items of different wear never merge")
	var named: ItemDrop = game.spawn_drop(Vector3(at)+Vector3(0.5,0.5,0.5),Nodes.COBBLE,1,0,{"custom_name":"Keepsake"})
	suite.check(not ItemPhysics.mergeable(one,named),"metadata must match before a merge")
	named.data.clear()
	suite.check(ItemPhysics.mergeable(one,named),"clearing the metadata makes the pair mergeable again")
	one.amount = Nodes.max_stack(Nodes.COBBLE)
	suite.check(not ItemPhysics.mergeable(one,named),"a full stack cannot merge")
	clear(game)
	# A cactus in the item's own cell destroys it; a stone cell does not.
	var cactus := Vector3i(8,170,8)
	world.set_node(cactus,Nodes.CACTUS)
	var doomed: ItemDrop = game.spawn_drop(Vector3(cactus)+Vector3.ONE*0.5,Nodes.DIAMOND,1)
	suite.check(ItemPhysics.cactus(world,Vector3(cactus)+Vector3.ONE*0.5),"a cactus cell is detected")
	suite.check(ItemPhysics.step(doomed,0.05) and doomed.is_queued_for_deletion(),"a dropped item on a cactus is destroyed outright")
	world.set_node(cactus,Nodes.AIR)
	var safe: ItemDrop = game.spawn_drop(Vector3(cactus)+Vector3.ONE*0.5,Nodes.DIAMOND,1)
	suite.check(not ItemPhysics.step(safe,0.05) and not safe.is_queued_for_deletion(),"a dropped item on an empty cell survives")
	# A resting item in water with air above floats: the source's is_floating rule.
	world.set_node(cactus,Nodes.WATER)
	var floater: ItemDrop = game.spawn_drop(Vector3(cactus)+Vector3.ONE*0.5,Nodes.DIAMOND,1)
	floater.velocity = Vector3.ZERO
	suite.check(ItemPhysics.floats(world,floater.position,floater.velocity),"a stationary item with liquid below and air above floats")
	world.set_node(cactus+Vector3i.UP,Nodes.WATER)
	suite.check(not ItemPhysics.floats(world,floater.position,Vector3.ZERO),"a fully submerged item does not float")
	world.set_node(cactus+Vector3i.UP,Nodes.AIR)
	world.set_node(cactus,Nodes.AIR)
	clear(game)
	# The push-out picks the nearest free horizontal side, and upward when boxed in.
	# The source's `objects_inside_radius` scan sees whichever side is free, so the
	# test boxes every side but one to make the choice observable.
	var boxed := Vector3i(8,170,8)
	world.set_node(boxed,Nodes.STONE)
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: world.set_node(boxed+side,Nodes.STONE)
	world.set_node(boxed+Vector3i.LEFT,Nodes.AIR)
	suite.check(ItemPhysics.push_direction(world,Vector3(boxed)+Vector3(0.2,0.5,0.5)) == Vector3i.LEFT,"an item in a solid cell is pushed toward the only free side")
	world.set_node(boxed+Vector3i.LEFT,Nodes.STONE)
	world.set_node(boxed+Vector3i.UP,Nodes.AIR)
	suite.check(ItemPhysics.push_direction(world,Vector3(boxed)+Vector3(0.5,0.5,0.5)) == Vector3i.UP,"with all four sides blocked the item shoots upward")
	suite.check(ItemPhysics.stuck(world,Vector3(boxed)+Vector3(0.5,0.5,0.5)),"an item inside a solid opaque node is detected as stuck")
	world.set_node(boxed,Nodes.AIR)
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: world.set_node(boxed+side,Nodes.AIR)
	# The offhand is filled first, which is `core.item_pickup`'s rule.
	game.player.offhand_slot = {"id":0,"count":0,"wear":0}
	var pickup: ItemDrop = game.spawn_drop(Vector3(boxed)+Vector3.ONE*0.5,Nodes.TORCH,4)
	suite.check(ItemPhysics.offhand_room(game,pickup) == Nodes.max_stack(Nodes.TORCH),"an empty offhand can take a full stack")
	suite.check(ItemPhysics.fill_offhand(game,pickup) == 0 and game.player.offhand_slot.id == Nodes.TORCH and game.player.offhand_slot.count == 4,"a pickup lands in the empty offhand first")
	game.player.offhand_slot = {"id":VillageContent.SHIELD,"count":1,"wear":0}
	suite.check(ItemPhysics.offhand_room(game,pickup) == 0,"a different item in the offhand takes nothing")
	suite.check(ItemPhysics.fill_offhand(game,pickup) == 4,"a refused offhand returns the whole count to the main inventory")
	game.player.offhand_slot = {"id":0,"count":0,"wear":0}
	clear(game)


# --- piglin anger (`mobs_mc.enrage_piglins`) ---------------------------------

static func anger(suite: Object, game: Node3D) -> void:
	clear(game)
	suite.check(PiglinAnger.protected_node(Nodes.GOLD_ORE) and PiglinAnger.protected_node(Nodes.DEEP_GOLD_ORE) and PiglinAnger.protected_node(MinecloniaOres.NETHER_GOLD),"the source's piglin_protected group covers both gold ores and nether gold")
	suite.check(not PiglinAnger.protected_node(Nodes.IRON_ORE) and not PiglinAnger.protected_node(Nodes.STONE),"ordinary stone and iron ore do not provoke a piglin")
	suite.check(PiglinAnger.loves(Nodes.GOLD) and PiglinAnger.loves(Nodes.GOLDEN_APPLE) and PiglinAnger.loves(VillageContent.BELL),"the gold items a piglin accepts are recognised")
	suite.check(not PiglinAnger.loves(Nodes.IRON) and not PiglinAnger.loves(Nodes.DIAMOND),"iron and diamond are not gold items")
	# A piglin within range is enraged; one outside it is not.
	var old_position: Vector3 = game.player.position
	game.world.adventure_state.erase("nether_residents")
	game.world.adventure_state["nether_resident_serial"] = 0
	var near: Creature = game.spawn_creature("piglin",game.player.position+Vector3(4,0,0))
	var far: Creature = game.spawn_creature("piglin",game.player.position+Vector3(40,0,0))
	near.provoked = false; far.provoked = false
	# The source's container path passes the line-of-sight test, so the check runs
	# against a clear line: no geometry is placed between them here.
	var angered: int = PiglinAnger.enrage(game,false)
	suite.check(angered >= 1 and near.provoked,"opening a container inside sixteen nodes enrages a piglin")
	suite.check(not far.provoked,"a piglin beyond the source's sixteen-node cube is not enraged")
	# The dig path runs without the sight test, so it takes the same set.
	near.provoked = false
	PiglinAnger.on_protected_broken(game,Nodes.GOLD_ORE)
	suite.check(near.provoked,"breaking a gold-bearing node enrages a piglin with no sight test")
	near.provoked = false
	PiglinAnger.on_protected_broken(game,Nodes.STONE)
	suite.check(not near.provoked,"breaking ordinary stone does not enrage a piglin")
	game.player.position = old_position
	clear(game)


# --- boss bars (`mcl_bossbars`) ----------------------------------------------

static func bars(suite: Object, game: Node3D) -> void:
	clear(game)
	var before: int = BossBars.bars(game).size()
	suite.check(before == BossBars.bars(game).size(),"the bar list is rebuilt from live state, so repeated calls agree")
	var wither: Creature = game.spawn_creature("wither",game.player.position+Vector3(6,2,0))
	suite.check(wither != null,"a wither can be spawned for the bar check")
	var bars: Array = BossBars.bars(game)
	var found: Dictionary = {}
	for bar in bars:
		if str(bar.id).begins_with("mob:"): found = bar
	suite.check(not found.is_empty() and str(found.text) == "Wither" and str(found.color) == BossBars.WITHER_COLOR,"a summoned wither gets the source's dark purple bar")
	suite.check(float(found.fraction) > 0.99,"a full-health wither fills its bar")
	wither.health = 300.0
	bars = BossBars.bars(game)
	for bar in bars:
		if str(bar.id).begins_with("mob:"): found = bar
	suite.check(is_equal_approx(float(found.fraction),0.5),"half health halves the bar, as `update_boss` computes health over hp_max")
	# Past the source's eighty-node range no bar is drawn.
	wither.position = game.player.position+Vector3(200,0,0)
	var distant: bool = false
	for bar in BossBars.bars(game):
		if str(bar.id).begins_with("mob:"): distant = true
	suite.check(not distant,"a boss beyond the source's eighty-node range gets no bar")
	wither.position = game.player.position+Vector3(6,2,0)
	# The raid bar is the source's red static bar.
	game.world.adventure_state["raid"] = {"center":[8,64,8],"wave":2,"level":1,"alive":3,"size":6,"timer":5.0}
	var raid: Dictionary = {}
	for bar in BossBars.bars(game):
		if str(bar.id) == "raid": raid = bar
	suite.check(not raid.is_empty() and str(raid.color) == BossBars.RAID_COLOR,"a live raid gets the source's red bar")
	suite.check("2 of 3" in str(raid.text),"the raid bar names the wave out of the ordinary wave count")
	suite.check(is_equal_approx(float(raid.fraction),0.5),"the raid bar fills by surviving raiders")
	game.world.adventure_state.erase("raid")
	suite.check(BossBars.color("dark_purple") == Color("b975d3") and BossBars.color("red") == Color("cf5a52"),"the source's colour names map to sane tints")
	clear(game)
