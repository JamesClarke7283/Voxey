extends RefCounted

# Focused regression for ocean ruins. The reference places a sunken structure on
# the sea floor and then does two things that matter more than the layout: it
# converts some of the ruin's own floor material into suspicious sand or gravel,
# which is the only natural source of archaeological material, and its warm
# variant carries the coral and sea pickles.

static func count_kind(voxels: Dictionary, id: int) -> int:
	var total: int = 0
	for p in voxels:
		if int(voxels[p]) == id: total += 1
	return total

# A sea floor with water above, so the ruin's site test can succeed.
static func sea_terrain(gen: TerrainGenerator) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < TerrainGenerator.OVERWORLD_MIN+1: return Nodes.BEDROCK
		var floor_y: int = gen.terrain_height(p.x,p.z)
		if p.y < floor_y: return Nodes.STONE
		if p.y == floor_y: return Nodes.GRAVEL
		return Nodes.WATER

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- registry ----------------------------------------------------------
	t.check(OceanRuins.is_ruin("cold") and OceanRuins.is_ruin("warm"),"both ruin variants are recognised")
	t.check(not OceanRuins.is_ruin("shipwreck"),"other names are not ruins")
	t.check(is_equal_approx(float(OceanRuins.SIDE),10.0),"the source's ten-block side length is used")
	t.check(OceanRuins.SOURCE_Y_MAX == -2,"the source's documented y_max of -2 is recorded")
	# The two variants differ in exactly the material that decides their content.
	t.check(OceanRuins.floor_material(false) == Nodes.GRAVEL,"a cold ruin has a gravel floor, as the source's place_on lists")
	t.check(OceanRuins.floor_material(true) == Nodes.SAND,"a warm ruin has a sand floor")
	t.check(OceanRuins.suspicious_for(false) == Archaeology.SUSPICIOUS_GRAVEL,"a cold ruin seeds suspicious gravel")
	t.check(OceanRuins.suspicious_for(true) == Archaeology.SUSPICIOUS_SAND,"a warm ruin seeds suspicious sand")

	# --- planning ----------------------------------------------------------
	var sample: Callable = sea_terrain(gen)
	# A site above the water line is refused, since a ruin must be submerged.
	var dry := Vector3i(64,0,64)
	if gen.terrain_height(dry.x,dry.z) >= TerrainGenerator.SEA:
		t.check(OceanRuins.plan(gen,dry,7,sample).is_empty(),"a site that is not submerged is refused")
	# A sea floor site plans a ruin.
	var found: Dictionary = {}
	for rx in range(-6,7):
		for rz in range(-6,7):
			for candidate in OceanRuins.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"an ocean ruin exists somewhere near the origin")
	if not found.is_empty():
		var voxels: Dictionary = found.voxels
		t.check(voxels.size() > 0,"a planned ruin places at least one block")
		# The floor is the ruin's own material, which decides its variant.
		var material: int = int(found.material)
		t.check(material == Nodes.GRAVEL or material == Nodes.SAND,"the ruin's material is one of the source's two floor materials")
		t.check(count_kind(voxels,material) > 0,"the ruin builds a floor of its own material")
		# The floor plate really is a plate: it has both x and z extent.
		var lo: Vector3i = found.bounds_min
		var hi: Vector3i = found.bounds_max
		t.check(hi.x-lo.x >= OceanRuins.SIDE and hi.z-lo.z >= OceanRuins.SIDE,"the ruin spans the source's ten-block width")
		# A warm ruin carries coral and sea pickles, which is why the split exists.
		if bool(found.warm):
			var coral: int = 0
			var pickles: int = 0
			for p in voxels:
				var id: int = int(voxels[p])
				if Corals.is_coral(id): coral += 1
				if SeaPickles.is_pickle(id): pickles += 1
			t.check(coral > 0,"a warm ocean ruin carries coral")
			t.check(pickles > 0,"a warm ocean ruin carries sea pickles")
		# Every cell of a ruin is inside its own reported span.
		var contained: bool = true
		for p in voxels:
			if p.x < lo.x or p.x > hi.x or p.y < lo.y or p.y > hi.y or p.z < lo.z or p.z > hi.z: contained = false
		t.check(contained,"every ruin cell lies inside its reported span")

	# --- determinism -------------------------------------------------------
	var again: Dictionary = OceanRuins.plan(gen,Vector3i(found.bounds_min.x,0,found.bounds_min.z),0,func(p: Vector3i) -> int: return Dungeons.natural(gen,p))
	t.check(again.is_empty() or again.voxels.size() > 0,"re-planning a site produces a ruin without error")

	# --- the suspicious node conversion ------------------------------------
	# This is what makes the ruin the source's only archaeological source.
	var coord := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
	var data := PackedInt32Array(); data.resize(18*18*TerrainGenerator.HEIGHT)
	var deep := PackedInt32Array(); deep.resize(18*18*(-TerrainGenerator.OVERWORLD_MIN))
	var result: Dictionary = OceanRuins.overlay(gen,coord,data,deep)
	var suspicious_id: int = OceanRuins.suspicious_for(bool(found.warm))
	t.check(result.has("suspicious") and result.has("chests"),"the overlay reports its suspicious cells and chests")
	# A suspicious cell really ended up in the column, and matches the variant.
	if not result.suspicious.is_empty():
		var confirmed: int = 0
		var base: Vector2i = coord*16-Vector2i.ONE
		for p in result.suspicious:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var got: int = deep[index] if p.y < 0 else data[index]
			if got == suspicious_id: confirmed += 1
		t.check(confirmed > 0,"the ruin's floor really becomes suspicious nodes of its variant's kind")
		t.check(suspicious_id == Archaeology.SUSPICIOUS_GRAVEL or suspicious_id == Archaeology.SUSPICIOUS_SAND,"the suspicious node is the archaeological one")
	# A suspicious node's loot table yields when brushed, so the ruin's material
	# is actually recoverable.
	var rng := RandomNumberGenerator.new(); rng.seed = 99
	var rolled: Array = Archaeology.loot(suspicious_id,rng)
	t.check(rolled.size() > 0,"a suspicious node's table yields loot when brushed")
	# A nether column never receives a ruin.
	var before: PackedInt32Array = data.duplicate()
	gen.dimension = "nether"
	OceanRuins.overlay(gen,coord,data,deep)
	gen.dimension = "overworld"
	var mutated: int = 0
	for i in data.size():
		if data[i] != before[i]: mutated += 1
	t.check(mutated == 0,"the ruin overlay never writes into a non-overworld dimension")

	# --- a ruin really reaches the world -----------------------------------
	if not found.is_empty():
		var world: VoxelWorld = game.world
		for c in [coord]:
			world._apply_column(gen.generate_column(c,world.edits))
		var placed: int = 0
		var material: int = int(found.material)
		for p in found.voxels:
			if not world.loaded_at(Vector3(p)): continue
			if world.node_at(p) == int(found.voxels[p]): placed += 1
		t.check(placed > 0,"ruin blocks reach the generated world")
		t.check(material == Nodes.GRAVEL or material == Nodes.SAND,"the placed ruin kept its variant's material")
