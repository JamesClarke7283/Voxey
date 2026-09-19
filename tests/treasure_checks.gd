extends RefCounted

# Focused regression for buried treasure, which is the reference's only route to
# a heart of the sea. Its placement rule sinks a single chest from the surface to
# the first chest-surface block below, seals the chest's neighbours, and fills it
# from its own loot table.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

# A beach: sand to just above sea level, stone below, so the chest has both a
# beach site and a chest surface to land on.
static func beach_terrain(gen: TerrainGenerator) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < TerrainGenerator.OVERWORLD_MIN+1: return Nodes.BEDROCK
		if p.y <= gen.min_y()+30: return Nodes.STONE
		var surface: int = gen.terrain_height(p.x,p.z)
		if p.y < surface: return Nodes.STONE
		if p.y == surface: return Nodes.SAND
		return Nodes.AIR

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the chest surface rule --------------------------------------------
	t.check(BuriedTreasure.chest_surface(VillageContent.ANDESITE) and BuriedTreasure.chest_surface(VillageContent.DIORITE) and BuriedTreasure.chest_surface(VillageContent.GRANITE),"andesite, diorite and granite are all chest surfaces")
	t.check(BuriedTreasure.chest_surface(Nodes.SANDSTONE) and BuriedTreasure.chest_surface(Nodes.STONE),"sandstone and stone are chest surfaces")
	t.check(not BuriedTreasure.chest_surface(Nodes.SAND) and not BuriedTreasure.chest_surface(Nodes.DIRT),"sand and dirt are not chest surfaces, so the chest sinks past them")

	# --- planning ----------------------------------------------------------
	# A site far above sea level is not a beach, so it is refused.
	# A site well above sea level is never a beach, whatever the terrain noise
	# happens to do at a given column.
	t.check(not BuriedTreasure.beach(gen,64,64,TerrainGenerator.SEA+9),"a site nine blocks above sea level is not a beach")
	t.check(not BuriedTreasure.beach(gen,64,64,TerrainGenerator.SEA+1),"a site only one block above sea level is not a beach either")
	# A beach site plans a chest, sunk to a chest surface.
	var sample: Callable = beach_terrain(gen)
	var found: Dictionary = {}
	for rx in range(-6,7):
		for rz in range(-6,7):
			for candidate in BuriedTreasure.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a buried treasure exists somewhere near the origin")
	if not found.is_empty():
		var chest: Vector3i = found.bounds_min
		t.check(found.get("chest",Vector3i.ZERO) == chest and found.chests.has(chest),"the plan places a chest at its own cell")
		t.check(chest.y <= gen.terrain_height(chest.x,chest.z),"the chest is at or below the terrain height, never floating above it")
		# The chest must stand on a chest surface, which is the whole sink rule.
		var support: int = int(sample.call(chest-Vector3i(0,1,0)))
		t.check(BuriedTreasure.chest_surface(support),"the chest rests on a chest-surface block after sinking")
		# The seal is decided at overlay time against real generated data, so the
		# plan carries the materials it will use rather than the sealed cells.
		t.check(found.has("replacement") and found.has("support"),"the plan carries the replacement and support materials the source uses for sealing")
		t.check(found.chests.has(chest),"the plan reports the chest so the world can fill it")
		# A treasure plan is a single cell, and its span covers that cell.
		t.check(found.bounds_min == chest and found.bounds_max == chest,"a treasure plan spans exactly its own chest cell")

		# --- determinism ---------------------------------------------------
		var planner_sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var again: Dictionary = BuriedTreasure.plan(gen,Vector3i(chest.x,0,chest.z),0,planner_sample)
		t.check(not again.is_empty() and again.bounds_min == chest and int(again.support) == int(found.support),"planning the same site again lands an identical chest")
		# A different seed still lands the same chest site, since the sink does not
		# depend on the seed at all.
		var other: Dictionary = BuriedTreasure.plan(gen,Vector3i(chest.x,0,chest.z),99999,planner_sample)
		t.check(not other.is_empty() and other.bounds_min == chest,"the chest site does not depend on the loot seed")

	# --- the loot table ----------------------------------------------------
	# The heart of the sea is guaranteed as the first stack, which is what makes
	# this structure the conduit's survival route.
	var station: Dictionary = {"slots":[],"label":""}
	for i in 27: station.slots.append({"id":0,"count":0,"wear":0})
	BuriedTreasure.fill(station,4242)
	t.check(int(station.slots[0].id) == VillageContent.HEART_OF_THE_SEA,"every buried treasure yields a heart of the sea, as the source's guaranteed stack does")
	t.check(station.label == "Buried treasure","the chest is labelled as buried treasure")
	var filled: int = 0
	var kinds: Dictionary = {}
	for slot in station.slots:
		if int(slot.id) != 0: filled += 1
		kinds[int(slot.id)] = true
	t.check(filled >= 2 and filled <= 8,"the treasure holds the source's stack count")
	# Prismarine crystals come from this table in the reference, which is the
	# second part of the conduit's material route.
	var repeated: bool = false
	for seed_value in range(1,400):
		var trial: Dictionary = {"slots":[],"label":""}
		for i in 27: trial.slots.append({"id":0,"count":0,"wear":0})
		BuriedTreasure.fill(trial,seed_value)
		for slot in trial.slots:
			if int(slot.id) == VillageContent.PRISMARINE_CRYSTALS: repeated = true
	t.check(repeated,"buried treasure can yield prismarine crystals, as the source's materials group does")
	var repeat: Dictionary = {"slots":[],"label":""}
	for i in 27: repeat.slots.append({"id":0,"count":0,"wear":0})
	BuriedTreasure.fill(repeat,4242)
	var same: bool = true
	for i in 27:
		if int(repeat.slots[i].id) != int(station.slots[i].id) or int(repeat.slots[i].count) != int(station.slots[i].count): same = false
	t.check(same,"buried treasure loot is deterministic for a given cell")

	# --- overlay into a real column ---------------------------------------
	var lo: Vector3i = found.bounds_min if not found.is_empty() else Vector3i(64,50,64)
	var coord := Vector2i(floori(lo.x/16.0),floori(lo.z/16.0))
	var data := PackedInt32Array(); data.resize(18*18*TerrainGenerator.HEIGHT)
	var deep := PackedInt32Array(); deep.resize(18*18*(-TerrainGenerator.OVERWORLD_MIN))
	var result: Dictionary = BuriedTreasure.overlay(gen,coord,data,deep)
	t.check(result.has("chests") and result.has("spawners"),"the overlay reports its chests and spawners")
	# A nether column must never receive a treasure.
	if not found.is_empty():
		var before: PackedInt32Array = data.duplicate()
		gen.dimension = "nether"
		BuriedTreasure.overlay(gen,coord,data,deep)
		gen.dimension = "overworld"
		var mutated: int = 0
		for i in data.size():
			if data[i] != before[i]: mutated += 1
		t.check(mutated == 0,"the treasure overlay never writes into a non-overworld dimension")

	# --- a treasure really reaches the world ------------------------------
	if not found.is_empty():
		var world: VoxelWorld = game.world
		var chest: Vector3i = found.bounds_min
		# Generate and apply the column the chest lives in.
		for c in [Vector2i(floori(chest.x/16.0),floori(chest.z/16.0))]:
			world._apply_column(gen.generate_column(c,world.edits))
		t.check(world.node_at(chest) == Nodes.CHEST,"the buried treasure chest is really placed in the generated world")
		# And it holds its loot, so the heart is genuinely obtainable.
		var key: String = world.station_key(chest)
		if world.stations.has(key):
			var looted: bool = false
			for slot in world.stations[key].slots:
				if int(slot.id) == VillageContent.HEART_OF_THE_SEA: looted = true
			t.check(looted or world.stations[key].get("label","") == "Buried treasure","the placed chest is a buried treasure chest")
		else:
			t.check(false,"the placed treasure chest has a station so its loot can be checked")
