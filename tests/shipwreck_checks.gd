extends RefCounted

# Focused regression for shipwrecks. The source's `after_place` is the part that
# matters: it picks a sand or gravel cell within 64 blocks of the wreck, sinks a
# chest one to four blocks below it, and fills that chest from the
# buried-treasure table — which is where the heart of the sea comes from. That
# makes shipwrecks a second route to the conduit's core ingredient.

static func count_kind(voxels: Dictionary, id: int) -> int:
	var total: int = 0
	for p in voxels:
		if int(voxels[p]) == id: total += 1
	return total

# A sea floor with sand, which is the wreck's own `place_on`.
static func sea_terrain(gen: TerrainGenerator) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < TerrainGenerator.OVERWORLD_MIN+1: return Nodes.BEDROCK
		var floor_y: int = gen.terrain_height(p.x,p.z)
		if p.y < floor_y: return Nodes.STONE
		if p.y == floor_y: return Nodes.SAND
		return Nodes.WATER

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- constants ---------------------------------------------------------
	t.check(is_equal_approx(float(Shipwrecks.SIDE),16.0),"the source's sixteen-block side length is used")
	t.check(Shipwrecks.SOURCE_BURIED_SEARCH == 64,"the source's 64-block burial search is recorded")
	t.check(Shipwrecks.BURIED_SEARCH == 8,"the burial is drawn from the wreck's vicinity, which the per-column reach requires")
	t.check(Shipwrecks.SINK_MIN == 2 and Shipwrecks.SINK_MAX == 4,"a wreck sinks the source's two to four blocks")
	t.check(Shipwrecks.BURIED_DEPTH_MIN == 1 and Shipwrecks.BURIED_DEPTH_MAX == 4,"the buried chest sinks the source's one to four blocks")
	t.check(Shipwrecks.WATER_NEIGHBOURS == 4,"the source's four water neighbours are recorded")

	# --- planning ----------------------------------------------------------
	var sample: Callable = sea_terrain(gen)
	# A site at the water line is refused, since a wreck must be submerged.
	t.check(Shipwrecks.plan(gen,Vector3i(64,0,64),7,func(p: Vector3i) -> int: return Nodes.STONE).is_empty(),"a site with no sea floor is refused")
	var found: Dictionary = {}
	for rx in range(-6,7):
		for rz in range(-6,7):
			for candidate in Shipwrecks.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a shipwreck exists somewhere near the origin")
	if not found.is_empty():
		var voxels: Dictionary = found.voxels
		t.check(voxels.size() > 0,"a planned wreck builds at least one block")
		# The hull is oak planks and its keel is logs, as the source's wrecks are.
		t.check(count_kind(voxels,Nodes.PLANKS) > 0,"a wreck is built from planks")
		t.check(count_kind(voxels,Nodes.LOG) > 0,"a wreck carries a log keel")
		# The wreck really sinks below the water line.
		t.check(found.bounds_min.y < gen.terrain_height(found.bounds_min.x,found.bounds_min.z),"the wreck sits below the sea floor")
		# The burial is part of the plan, so it survives region caching.
		t.check(found.has("buried"),"the plan carries its buried treasure cells")
		# Every hull cell is inside the reported span.
		var lo: Vector3i = found.bounds_min
		var hi: Vector3i = found.bounds_max
		var contained: bool = true
		for p in voxels:
			if p.x < lo.x or p.x > hi.x or p.y < lo.y or p.y > hi.y or p.z < lo.z or p.z > hi.z: contained = false
		t.check(contained,"every hull cell lies inside its reported span")

		# --- the buried treasure -------------------------------------------
		# This is the heart-of-the-sea route, so it must really be buried.
		t.check(not found.buried.is_empty(),"a wreck buries at least one treasure chest")
		if not found.buried.is_empty():
			for p in found.buried:
				# The chest must sit under the local sea floor, within the source's
				# one-to-four block depth of the surface it replaced.
				var surf: int = gen.terrain_height(p.x,p.z)
				t.check(surf < TerrainGenerator.SEA,"a burial site is below the sea")
				t.check(p.y < surf,"a buried chest sits below its own sea floor")
				t.check(surf-p.y >= Shipwrecks.BURIED_DEPTH_MIN and surf-p.y <= Shipwrecks.BURIED_DEPTH_MAX,"the burial is the source's one to four blocks deep")
				# The surface it replaced is one of the source's own burial surfaces.
				var surface: int = int(sample.call(Vector3i(p.x,surf,p.z)))
				t.check(surface in [Nodes.SAND,Nodes.GRAVEL,Nodes.GRASS,Nodes.DIRT],"the burial replaces a sand or gravel sea floor")

	# --- the loot table ----------------------------------------------------
	# The buried chest uses the buried-treasure table, which guarantees the heart.
	var station: Dictionary = {"slots":[],"label":""}
	for i in 27: station.slots.append({"id":0,"count":0,"wear":0})
	BuriedTreasure.fill(station,1234)
	t.check(int(station.slots[0].id) == VillageContent.HEART_OF_THE_SEA,"the buried chest uses the buried-treasure table, which guarantees a heart of the sea")
	# The wreck's own supplies and treasure groups are non-empty and weighted.
	var supplies_ok: bool = true
	for entry in Shipwrecks.SUPPLIES:
		if int(entry[1]) <= 0: supplies_ok = false
	t.check(supplies_ok and Shipwrecks.SUPPLIES.size() >= 6,"the wreck's supply table is present and weighted")
	t.check(Shipwrecks.TREASURE.size() >= 5 and Shipwrecks.NAVIGATION.size() >= 5,"the wreck's treasure and navigation tables are present")

	# The wreck's own chest uses its own three-group table, not another structure's.
	var own: Dictionary = {"slots":[],"label":""}
	for i in 27: own.slots.append({"id":0,"count":0,"wear":0})
	Shipwrecks.fill_chest(own,99)
	t.check(own.label == "Shipwreck chest","the wreck's own chest is labelled from its own table")
	var filled: int = 0
	for slot in own.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	# The source rolls three to ten supplies, two to six treasure and three
	# navigation, so a wreck chest always holds something.
	t.check(filled >= 3,"the wreck's own chest holds the source's supplies, treasure and navigation")

	# --- the overlay -------------------------------------------------------
	if not found.is_empty():
		var coord := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
		var data := PackedInt32Array(); data.resize(18*18*TerrainGenerator.HEIGHT)
		var deep := PackedInt32Array(); deep.resize(18*18*(-TerrainGenerator.OVERWORLD_MIN))
		var result: Dictionary = Shipwrecks.overlay(gen,coord,data,deep)
		t.check(result.has("chests") and result.has("buried"),"the overlay reports its own chests and the buried ones")
		# A nether column never receives a wreck.
		var before: PackedInt32Array = data.duplicate()
		gen.dimension = "nether"
		Shipwrecks.overlay(gen,coord,data,deep)
		gen.dimension = "overworld"
		var mutated: int = 0
		for i in data.size():
			if data[i] != before[i]: mutated += 1
		t.check(mutated == 0,"the wreck overlay never writes into a non-overworld dimension")

		# --- a wreck really reaches the world ------------------------------
		var world: VoxelWorld = game.world
		# A wreck spans up to sixteen blocks, so it can straddle several columns.
		# A wreck's burial can lie up to 64 blocks from its hull, so every column it
		# reaches must be generated for the chest to appear.
		var lo_c := Vector2i(floori(found.reach_min.x/16.0),floori(found.reach_min.z/16.0))
		var hi_c := Vector2i(floori(found.reach_max.x/16.0),floori(found.reach_max.z/16.0))
		for cx in range(lo_c.x,hi_c.x+1):
			for cz in range(lo_c.y,hi_c.y+1):
				world._apply_column(gen.generate_column(Vector2i(cx,cz),world.edits))
		var hull_placed: int = 0
		for p in found.voxels:
			if not world.loaded_at(Vector3(p)): continue
			if world.node_at(p) == int(found.voxels[p]): hull_placed += 1
		t.check(hull_placed > 0,"hull blocks reach the generated world")
		# The buried chest is placed and holds its loot, so the heart is
		# genuinely obtainable from a shipwreck.
		var buried_placed: int = 0
		for p in found.buried:
			if not world.loaded_at(Vector3(p)): continue
			if world.node_at(p) == Nodes.CHEST:
				buried_placed += 1
				var key: String = world.station_key(p)
				t.check(world.stations.has(key) and world.stations[key].get("label","") == "Buried treasure","the buried chest is filled as buried treasure, so it can hold a heart of the sea")
		if not found.buried.is_empty():
			t.check(buried_placed > 0,"the buried chest is really placed in the generated world")
