extends RefCounted

# Focused regression for the conduit and its prismarine frame. The reference's
# `check_conduit` has three parts — enough water, enough frame blocks from its own
# 42-position list, and a range of floor(frame/7)*16 — and an active conduit gives
# conduit power to nearby players in water and damages hostile creatures.

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# Build a 3x3x3 water volume around a cell, so the water test can pass.
static func flood(world: VoxelWorld, p: Vector3i) -> void:
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				if Vector3i(x,y,z) == Vector3i.ZERO: continue
				world.set_node(p+Vector3i(x,y,z),Nodes.WATER)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var base := Vector3i(8,1800,8)
	for x in range(-12,13):
		for z in range(-12,13):
			world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)
			for y in range(12): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)
	var centre := base+Vector3i(0,4,0)
	clear_drops(game)

	# --- registry ----------------------------------------------------------
	t.check(Conduits.is_conduit(VillageContent.CONDUIT),"the conduit node is registered")
	t.check(Conduits.is_frame(VillageContent.PRISMARINE) and Conduits.is_frame(VillageContent.PRISMARINE_BRICK) and Conduits.is_frame(VillageContent.PRISMARINE_DARK) and Conduits.is_frame(VillageContent.SEA_LANTERN),"all four source frame blocks count towards activation")
	t.check(not Conduits.is_frame(VillageContent.PRISMARINE_SHARD),"the crafting shard is not a frame block")
	t.check(Nodes.title(VillageContent.CONDUIT) == "Conduit" and Nodes.title(VillageContent.PRISMARINE) == "Prismarine","the conduit and prismarine are named as the source names them")
	t.check(is_equal_approx(Nodes.hardness(VillageContent.CONDUIT),3.0),"the conduit has the source hardness of three")
	world.set_node(base+Vector3i(6,0,6),VillageContent.SEA_LANTERN)
	t.check(Pasture.emission(world,base+Vector3i(6,0,6)) == 15,"the sea lantern lights at the source maximum")
	world.set_node(base+Vector3i(6,0,7),VillageContent.CONDUIT)
	t.check(Pasture.emission(world,base+Vector3i(6,0,7)) == 15,"the conduit lights at the source maximum")
	t.check(Conduits.FRAME_OFFSETS.size() == 42 and Conduits.MIN_FRAME == 16,"the source's 42 frame positions and 16 block minimum are used")

	# --- activation needs water, then frame --------------------------------
	world.set_node(centre,VillageContent.CONDUIT)
	# Dry: no water at all, so no power even with a full frame.
	for offset in Conduits.FRAME_OFFSETS: world.set_node(centre+offset,VillageContent.PRISMARINE)
	t.check(Conduits.power(world,centre) == 0,"a conduit with a full frame but no water does not activate")
	# Watered but frameless: still nothing.
	for offset in Conduits.FRAME_OFFSETS: world.set_node(centre+offset,Nodes.AIR)
	flood(world,centre)
	t.check(Conduits.power(world,centre) == 0,"a conduit in water with no frame does not activate")
	# A partial frame below the minimum stays off.
	for i in Conduits.MIN_FRAME-1: world.set_node(centre+Conduits.FRAME_OFFSETS[i],VillageContent.PRISMARINE)
	t.check(Conduits.power(world,centre) == 0,"a frame below the 16 block minimum does not activate")
	# Reaching the minimum activates, with the source's range formula.
	world.set_node(centre+Conduits.FRAME_OFFSETS[Conduits.MIN_FRAME-1],VillageContent.PRISMARINE)
	var reach: int = Conduits.power(world,centre)
	t.check(reach == 32,"a 16 block frame gives the source range of floor(16/7)*16 = 32")
	# A larger frame reaches further, exactly per the formula.
	for i in range(Conduits.MIN_FRAME,21): world.set_node(centre+Conduits.FRAME_OFFSETS[i],VillageContent.PRISMARINE)
	t.check(Conduits.power(world,centre) == 48,"a 21 block frame gives floor(21/7)*16 = 48")
	# The sea lantern counts as frame just as prismarine does.
	for i in range(Conduits.MIN_FRAME,21): world.set_node(centre+Conduits.FRAME_OFFSETS[i],Nodes.AIR)
	for i in Conduits.MIN_FRAME: world.set_node(centre+Conduits.FRAME_OFFSETS[i],VillageContent.SEA_LANTERN)
	t.check(Conduits.power(world,centre) == 32,"sea lanterns count towards the frame as the source's list says")
	# Both water thresholds are honoured: a node needs all 27, an entity 26.
	var water_cells: int = 0
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				if Fluids.water(world.node_at(centre+Vector3i(x,y,z))): water_cells += 1
	t.check(water_cells >= 26,"the flooded volume provides the source's water requirement")
	t.check(Conduits.power(world,centre) == 32,"the conduit node activates with the source's 26 water cells")

	# --- conduit power to a nearby player in water -------------------------
	PotionEffects.clear(game.player)
	# A player is affected while standing in water; the conduit's own cell holds
	# the conduit, so stand in an adjacent flooded cell.
	var water_cell: Vector3i = centre+Vector3i(1,0,0)
	world.set_node(water_cell,Nodes.WATER)
	game.player.position = Vector3(water_cell)+Vector3(0.5,0.0,0.5)
	Conduits.apply_to(game,centre,32)
	t.check(PotionEffects.level(game.player,"conduit_power") > 0,"an active conduit gives conduit power to a player in water at its centre")
	# Out of reach there is no effect.
	PotionEffects.clear(game.player)
	world.set_node(centre+Vector3i(60,0,0),Nodes.WATER)
	game.player.position = Vector3(centre)+Vector3(60.5,0.0,0.5)
	Conduits.apply_to(game,centre,32)
	t.check(PotionEffects.level(game.player,"conduit_power") == 0,"a player outside the conduit's range gets no effect")
	# Out of water there is no effect even in range, as the source requires.
	PotionEffects.clear(game.player)
	game.player.position = Vector3(water_cell)+Vector3(0.5,0.0,0.5)
	world.set_node(water_cell,Nodes.AIR)
	Conduits.apply_to(game,centre,32)
	t.check(PotionEffects.level(game.player,"conduit_power") == 0,"a player out of water gets no conduit power")
	world.set_node(water_cell,Nodes.WATER)
	PotionEffects.clear(game.player)

	# --- hostile creatures in water take damage ----------------------------
	var dry_mob: Creature = game.spawn_creature("zombie",Vector3(centre)+Vector3(2.5,0.5,0.5))
	t.check(dry_mob != null,"a hostile creature can be spawned for the damage check")
	if dry_mob != null:
		var before: float = dry_mob.health
		Conduits.damage_hostiles(game,centre)
		t.check(is_equal_approx(dry_mob.health,before),"a creature out of water takes no conduit damage")
		# In water within nine blocks it is damaged.
		world.set_node(Vector3i(dry_mob.position.floor()),Nodes.WATER)
		Conduits.damage_hostiles(game,centre)
		t.check(dry_mob.health < before,"a hostile creature in water within nine blocks takes conduit damage")
		# A passive creature is never damaged.
		dry_mob.queue_free()
	var passive: Creature = game.spawn_creature("pig",Vector3(centre)+Vector3(2.5,0.5,0.5))
	if passive != null:
		world.set_node(Vector3i(passive.position.floor()),Nodes.WATER)
		var passive_before: float = passive.health
		Conduits.damage_hostiles(game,centre)
		t.check(is_equal_approx(passive.health,passive_before),"a passive creature takes no conduit damage")
		passive.queue_free()

	# --- recipes -----------------------------------------------------------
	var inv := Inventory.new()
	var conduit_index: int = inv.recipe_index(VillageContent.CONDUIT)
	t.check(conduit_index >= 0,"the conduit has its source recipe")
	if conduit_index >= 0:
		var recipe: Dictionary = inv.recipes[conduit_index]
		t.check(recipe.ingredients.get(VillageContent.NAUTILUS_SHELL,0) == 8 and recipe.ingredients.get(VillageContent.HEART_OF_THE_SEA,0) == 1,"the conduit takes eight nautilus shells around a heart of the sea")
	t.check(inv.recipe_index(VillageContent.PRISMARINE) >= 0 and inv.recipe_index(VillageContent.SEA_LANTERN) >= 0 and inv.recipe_index(VillageContent.PRISMARINE_DARK) >= 0,"the prismarine family and sea lantern are craftable")
	var prismarine_index: int = inv.recipe_index(VillageContent.PRISMARINE)
	if prismarine_index >= 0:
		t.check(inv.recipes[prismarine_index].ingredients.get(VillageContent.PRISMARINE_SHARD,0) == 4,"prismarine takes four shards, as the source recipe does")

	# --- acquisition -------------------------------------------------------
	# The nautilus shell keeps its source route: a fishing-treasure drop. The
	# other ocean materials come from guardians and buried treasure, which Voxey
	# does not implement yet, so the conduit is only craftable in creative until
	# those exist. The gap is recorded rather than papered over with a fake
	# source, and the fishing table still matches the reference exactly.
	var treasure_ids: Array = []
	for entry in Fishing.TREASURE: treasure_ids.append(int(entry.get("id",0)) if entry is Dictionary else 0)
	t.check(treasure_ids.has(VillageContent.NAUTILUS_SHELL),"fishing treasure yields a nautilus shell, as the source table does")
	t.check(Fishing.TREASURE.size() == 7,"the fishing treasure table still matches the source's seven entries")
	t.check(not treasure_ids.has(VillageContent.HEART_OF_THE_SEA) and not treasure_ids.has(VillageContent.PRISMARINE_SHARD),"the ocean materials are not invented into the fishing table")

	# --- art and mesh ------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Conduits.draw(art,VillageContent.CONDUIT)
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"the conduit draws a non-empty icon")
	t.check(Conduits.pixel(VillageContent.SEA_LANTERN,0,0,Color.WHITE) != Conduits.pixel(VillageContent.PRISMARINE,0,0,Color.WHITE),"the sea lantern and prismarine render distinct textures")
	var coord := Vector3i(centre.x/16,centre.y/16,centre.z/16)
	# Clear the frame first so the baseline is a genuinely empty plot.
	var frame_cell: Vector3i = centre+Conduits.FRAME_OFFSETS[0]
	world.set_node(frame_cell,Nodes.AIR)
	var before_verts: int = chunk_verts(world,coord)
	world.set_node(frame_cell,VillageContent.SEA_LANTERN)
	t.check(chunk_verts(world,coord) > before_verts,"the chunk mesher emits geometry for prismarine blocks")

	PotionEffects.clear(game.player)
	for x in range(-12,13):
		for z in range(-12,13):
			for y in range(12): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)
	clear_drops(game)

static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0
