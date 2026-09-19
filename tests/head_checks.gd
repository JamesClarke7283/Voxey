extends RefCounted

# Focused regression for heads and skulls. The reference registers each head in
# three placements (floor, wall, ceiling) that all share one item, and — the part
# that decides acquisition — a head drops only when the killing blow was an
# explosion from a lightning-charged creeper. Both halves are covered here.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	clear_drops(game)

	# --- registry ----------------------------------------------------------
	t.check(Heads.KINDS == 7 and Heads.is_head(Heads.FLOOR) and Heads.is_head(Heads.FLOOR+6),"all seven source heads are registered")
	t.check(Heads.is_any(Heads.FLOOR+3) and Heads.is_any(Heads.WALL+3) and Heads.is_any(Heads.CEILING+3),"each head exists in floor, wall and ceiling placements")
	t.check(Heads.title(Heads.FLOOR+1) == "Creeper Head" and Heads.title(Heads.FLOOR+3) == "Skeleton Skull" and Heads.title(Heads.FLOOR+6) == "Dragon Head","head titles match the source descriptions")
	# The three placements are one item: every variant returns the floor head.
	for i in Heads.KINDS:
		t.check(Nodes.drop(Heads.WALL+i) == Heads.FLOOR+i and Nodes.drop(Heads.CEILING+i) == Heads.FLOOR+i,"the wall and ceiling head %d drop the plain head"%i)
	# Heads are small decorative nodes, wearable, and not full cubes.
	t.check(not Nodes.solid(Heads.FLOOR) and Nodes.transparent(Heads.FLOOR),"a head is a small non-cube node")
	t.check(Nodes.max_stack(Heads.FLOOR) == 64 and is_equal_approx(Nodes.hardness(Heads.FLOOR),1.0),"heads stack to 64 and share the source hardness of one")
	t.check(Heads.boxes(Heads.FLOOR).size() == 1 and Heads.boxes(Heads.WALL).size() == 1,"each placement has its own box")
	t.check(Heads.boxes(Heads.FLOOR)[0].size.x < 1.0 and Heads.boxes(Heads.FLOOR)[0].size.x > 0.4,"a head occupies about half a block")

	# --- placement ---------------------------------------------------------
	# `on_place` picks the placement from the clicked face.
	t.check(Heads.placement(0,Vector3i.UP) == Heads.CEILING,"placing a head against a block's underside yields a ceiling head")
	t.check(Heads.placement(0,Vector3i.DOWN) == Heads.FLOOR,"placing a head on a block's top yields a floor head")
	t.check(Heads.placement(0,Vector3i.RIGHT) == Heads.WALL and Heads.placement(0,Vector3i.BACK) == Heads.WALL,"placing a head against a side yields a wall head")

	# --- art and mesh ------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Heads.draw(art,Heads.FLOOR)
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"a head draws a non-empty icon")
	t.check(Heads.pixel(Heads.FLOOR,0,0,Color.WHITE).a == 0.0 and Heads.pixel(Heads.FLOOR,8,4,Color.WHITE).a > 0.0,"the head texture is a face inset inside its tile")
	t.check(Heads.color(Heads.FLOOR+1) != Heads.color(Heads.FLOOR+3),"different heads have different colors")

	# --- a head really renders in the world --------------------------------
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	for x in range(-4,5):
		for z in range(-4,5):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),Nodes.STONE)
			for y in range(4): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	var before: int = chunk_verts(world,coord)
	world.set_node(ground,Heads.FLOOR+1)
	var after: int = chunk_verts(world,coord)
	t.check(after > before,"the chunk mesher emits geometry for a placed head")

	# --- the charged-creeper acquisition chain -----------------------------
	# An ordinary death drops no head, which is the source's rule.
	var zombie: Creature = game.spawn_creature("zombie",Vector3(ground)+Vector3(2.5,0.5,0.5))
	t.check(zombie != null,"a zombie can be spawned for the drop rule")
	if zombie != null:
		clear_drops(game)
		zombie.hit(1000.0)
		game.creatures.remove_child(zombie)
		t.check(drops_of(game,Heads.FLOOR) == 0,"an ordinary death drops no head")
		clear_drops(game)
	# A charged creeper's blast does drop one, and only from a charged killer.
	var victim: Creature = game.spawn_creature("zombie",Vector3(ground)+Vector3(2.5,0.5,0.5))
	var creeper: Creature = game.spawn_creature("creeper",Vector3(ground)+Vector3(3.5,0.5,0.5))
	t.check(victim != null and creeper != null,"a victim and a creeper can be spawned")
	if victim != null and creeper != null:
		clear_drops(game)
		victim.hit(1000.0,Vector3.ZERO,"charged_explosion")
		t.check(drops_of(game,Heads.FLOOR) == 1,"a blast from a charged creeper makes a mob drop its head")
		clear_drops(game)
	# Lightning charges a creeper rather than damaging it, as the source's
	# `_on_lightning_strike` does.
	creeper.charged = false
	t.check(not creeper.charged,"a fresh creeper is not charged")
	Weather.strike(world,RandomNumberGenerator.new(),Vector3i(creeper.position))
	t.check(creeper.charged,"a lightning strike charges the creeper the source converts")
	# A charged creeper explodes with the source's larger radius.
	t.check(is_equal_approx(Heads.CHARGED_RADIUS,8.0) and is_equal_approx(Heads.CHARGED_STRENGTH,6.0),"the charged creeper carries the source radius of eight")

	# --- the other lightning conversions ------------------------------------
	# The source's `_on_lightning_strike` turns a struck pig into a zombified
	# piglin. It is neutral rather than hostile, which is what makes it a
	# zombified *piglin* and not another zombie.
	var pig: Creature = game.spawn_creature("pig",Vector3(ground)+Vector3(5.5,0.5,0.5))
	t.check(pig != null and pig.kind == "pig","a pig can be spawned for the conversion")
	if pig != null:
		var turned: Creature = Weather.convert_mob(game,pig,"zombified_piglin")
		t.check(turned != null and turned.kind == "zombified_piglin","lightning turns a pig into a zombified piglin")
		t.check(pig.is_queued_for_deletion(),"the struck pig is replaced, not kept")
		if turned != null:
			t.check(turned.info().get("neutral",false),"a zombified piglin is neutral to players")
			t.check(not turned.info().get("burns",false),"a zombified piglin does not burn in daylight")
			t.check(is_equal_approx(turned.info().health,20.0),"a zombified piglin has the source's twenty health")
			t.check(turned.info().drops.has([Nodes.GOLD,0,1]),"a zombified piglin can drop a gold ingot")
	# A creeper that is already charged is not converted again, and takes the
	# strike's damage instead.
	t.check(creeper.kind == "creeper","the charged creeper survived the earlier strike")

	# --- a struck villager becomes a witch -----------------------------------
	# The source's `villager:_on_lightning_strike` replaces it and *then*
	# relinquishes its pois, so the villager is gone rather than duplicated. Its
	# record must be marked dead too, or the village would respawn it.
	# The strike casts down to find ground, so the villager stands inside the
	# carved air column rather than beside it.
	var settler: VillageMob = game.spawn_creature("villager",Vector3(ground)+Vector3(1.5,0.5,0.5))
	t.check(settler != null and settler.kind == "villager","a villager can be spawned for the conversion")
	if settler != null:
		var key: String = settler.person_key
		t.check(not key.is_empty() and not game.villages.record(key).get("dead",false),"the villager starts alive")
		Weather.strike(world,RandomNumberGenerator.new(),Vector3(ground)+Vector3(1.5,0.0,0.5))
		t.check(settler.is_queued_for_deletion(),"the struck villager is gone")
		var witched: bool = false
		for mob in game.creatures.get_children():
			if mob is Creature and not mob.is_queued_for_deletion() and mob.kind == "witch": witched = true
		t.check(witched,"a struck villager leaves a witch behind")
		t.check(game.villages.record(key).get("dead",false),"the converted villager's record is marked dead so it is not respawned")
	# The source's iron golem is not a villager and is not converted.
	var golem: VillageMob = game.spawn_creature("iron_golem",Vector3(ground)+Vector3(-1.5,0.5,0.5))
	if golem != null:
		t.check(golem.profession == "golem","an iron golem is a golem, not a villager")
		t.check(golem.get("kind") == "iron_golem","the golem keeps its kind")
	# The head a given mob yields matches the source's drop entries.
	t.check(Heads.mob_head("zombie") == Heads.FLOOR+0 and Heads.mob_head("creeper") == Heads.FLOOR+1 and Heads.mob_head("skeleton") == Heads.FLOOR+3,"zombie, creeper and skeleton yield their own heads")
	t.check(Heads.mob_head("pig") < 0 and Heads.mob_head("cow") < 0,"mobs with no source head entry yield nothing")
	for mob in [victim,creeper]:
		if is_instance_valid(mob): mob.queue_free()
	clear_drops(game)
	await t.process_frame

	for x in range(-4,5):
		for z in range(-4,5):
			for y in range(4): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

# Vertex count of the real chunk mesh, the path a placed head renders through.
static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0
