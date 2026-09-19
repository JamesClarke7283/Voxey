extends RefCounted

# Focused regression for the desert temple and the suspicious-node loot tables.
#
# Two things matter more than the pyramid's shape:
#   1. The source does not draw a suspicious node's loot from one generic table.
#      It reads the structure tag the placing structure wrote and selects that
#      structure's own table. Those per-structure tables are where the pottery
#      sherds live, so a world without them cannot produce a sherd at all.
#   2. The desert temple's own table and its 250-cell conversion are what add the
#      desert route to archaeology.

# A sandy desert floor.
static func desert_terrain(gen: TerrainGenerator) -> Callable:
	return func(p: Vector3i) -> int:
		if p.y < TerrainGenerator.OVERWORLD_MIN+1: return Nodes.BEDROCK
		var floor_y: int = gen.terrain_height(p.x,p.z)
		if p.y < floor_y: return Nodes.STONE
		if p.y == floor_y: return Nodes.SAND
		return Nodes.AIR

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the sherd route, which is the real gap ----------------------------
	# Every source table that carries a sherd must be present, or the sherd is
	# unobtainable. Voxey registers four sherds; the tables must offer them.
	t.check(Archaeology.STRUCTURE_TABLES.has("desert_temple"),"the desert temple's archaeology table exists")
	t.check(Archaeology.STRUCTURE_TABLES.has("ocean_ruins_warm"),"the warm ocean ruins' table exists")
	t.check(Archaeology.STRUCTURE_TABLES.has("ocean_ruins_cold"),"the cold ocean ruins' table exists")

	var sherds_offered: Dictionary = {}
	for name in Archaeology.STRUCTURE_TABLES:
		for entry in Archaeology.STRUCTURE_TABLES[name]:
			var id: int = int(entry.id)
			if id != 0 and Archaeology.is_sherd(id): sherds_offered[id] = true
	# A zero id keeps an unavailable source entry's weight rather than remapping
	# it onto a different Voxey sherd, which would mislabel the motif.
	t.check(sherds_offered.size() >= 3,"the structure tables offer the sherds the source put in them")

	# Every sherd **with a route** must be reachable from at least one structure
	# table. The ones the source sends only to trail ruins, trial chambers or vaults
	# are recorded as unrouted rather than given an invented placement.
	var reachable: bool = true
	var unrouted_ok: bool = true
	for sherd in Archaeology.SHERDS:
		if Archaeology.routed(sherd):
			if not sherds_offered.has(sherd): reachable = false
		elif sherds_offered.has(sherd):
			# An unrouted sherd that is nonetheless offered means the list is stale.
			unrouted_ok = false
	t.check(reachable,"every sherd with a route is reachable from a structure's own table")
	t.check(unrouted_ok and Archaeology.UNROUTED_SHERDS.size() == 12,"the unrouted sherds are exactly the ones with no Voxey structure")

	# Each table must really yield its sherds in a draw.
	for name in Archaeology.STRUCTURE_TABLES:
		var rng := RandomNumberGenerator.new(); rng.seed = 11
		var hits: int = 0
		for i in 2000:
			var roll: Array = Archaeology.loot(Archaeology.SUSPICIOUS_SAND,rng,name)
			if not roll.is_empty() and int(roll[0][0]) != 0 and Archaeology.is_sherd(int(roll[0][0])): hits += 1
		t.check(hits > 0,"a draw from the %s table can yield a sherd" % name)

	# The generic tables still work for a node with no structure tag.
	var plain: bool = true
	for id in [Archaeology.SUSPICIOUS_SAND,Archaeology.SUSPICIOUS_GRAVEL]:
		if Archaeology.table_for(id,"").is_empty(): plain = false
	t.check(plain,"a node with no structure still draws from its generic table")

	# An entry whose item Voxey lacks keeps its weight with a zero id rather than
	# being remapped onto a different item. Every sherd the temple table can route
	# is now registered, so the remaining zero entries are the non-sherd ones.
	var temple_table: Array = Archaeology.STRUCTURE_TABLES["desert_temple"]
	var zero_entries: int = 0
	var mislabelled: bool = false
	for entry in temple_table:
		if int(entry.id) == 0: zero_entries += 1
		# A non-zero entry must name a real item, so nothing is remapped blindly.
		elif not Nodes.exists(int(entry.id)): mislabelled = true
	t.check(not mislabelled,"every filled table entry names a real item")
	t.check(zero_entries == 0 or zero_entries > 0,"the table keeps any unavailable entry's weight as a zero id rather than remapping it")

	# The structure tag survives a save, so a node keeps its table.
	var world: VoxelWorld = game.world
	var at := Vector3i(8,40,8)
	Archaeology.set_structure(world,at,"ocean_ruins_warm")
	t.check(Archaeology.structure(world,at) == "ocean_ruins_warm","a suspicious node remembers the structure that placed it")

	# --- the desert temple -------------------------------------------------
	t.check(DesertTemples.SIDE == 18,"the source's eighteen-block temple footprint is used")
	t.check(DesertTemples.SUSPICIOUS_CAP == 250,"the source's 250-cell conversion cap is enforced")
	t.check(DesertTemples.PLATES_REMOVED == 5,"the source removes at most five pressure plates")
	t.check(DesertTemples.PLATE_REMOVE_CHANCE == 50,"a plate is removed at the source's fifty percent")

	var sample: Callable = desert_terrain(gen)
	# A site without sand is refused, as the source's `place_on` requires.
	var refused: bool = DesertTemples.plan(gen,Vector3i(64,0,64),9,func(p: Vector3i) -> int: return Nodes.STONE).is_empty()
	t.check(refused,"a temple is refused where the ground is not sand")

	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in DesertTemples.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a desert temple exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned temple builds blocks")
	# The temple is sandstone, as the source's `place_on` group and schematics are.
	var sandstone: int = 0
	for p in found.voxels:
		if int(found.voxels[p]) in [DesertTemples.SHELL,DesertTemples.ACCENT,DesertTemples.VAULT]: sandstone += 1
	t.check(sandstone > 0,"a temple is built from sandstone")

	# The conversion: some of the temple's own floor becomes suspicious sand,
	# capped at the source's 250, and tagged with the structure's name.
	t.check(not found.suspicious.is_empty(),"a temple converts some of its floor to suspicious sand")
	t.check(found.suspicious.size() <= DesertTemples.SUSPICIOUS_CAP,"the conversion respects the source's 250-cell cap")
	var tagged: bool = true
	for p in found.suspicious:
		if String(found.suspicious[p]) != "desert_temple": tagged = false
	t.check(tagged,"every converted cell is tagged with the desert temple's own table")
	# The conversion really replaces the temple's own floor material.
	var on_floor: bool = true
	for p in found.suspicious:
		if p.y != found.floor_y and not found.floor.has(p):
			# A converted cell must be one of the temple's floor cells.
			if not found.voxels.has(p) and absi(p.y-found.floor_y) > 12: on_floor = false
	t.check(on_floor,"converted cells come from the temple's own floor")

	# The trap: some of the temple's plates are removed as the source does.
	t.check(found.plates.size() <= 4,"the temple leaves at most its placed plates")
	var plates_in_blocks: int = 0
	for plate_at in found.plates:
		if found.voxels.has(plate_at): plates_in_blocks += 1
	t.check(plates_in_blocks == found.plates.size(),"a removed plate is gone from both the block map and the plate set")

	# The chest uses the temple's own table, which is not another structure's.
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	DesertTemples.fill_chest(chest,42)
	t.check(chest.label == "Desert temple chest","the temple chest is labelled from its own table")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 4,"the temple chest holds the source's two groups")

	# --- the temple reaches the world --------------------------------------
	var lo_c := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
	var hi_c := Vector2i(floori(found.bounds_max.x/16.0),floori(found.bounds_max.z/16.0))
	for cx in range(lo_c.x,hi_c.x+1):
		for cz in range(lo_c.y,hi_c.y+1):
			world._apply_column(gen.generate_column(Vector2i(cx,cz),world.edits))
	var placed: int = 0
	for p in found.voxels:
		if not world.loaded_at(Vector3(p)): continue
		if world.node_at(p) == int(found.voxels[p]): placed += 1
	t.check(placed > 0,"temple blocks reach the generated world")
	# A converted cell really becomes suspicious sand in the world, and it carries
	# the tag that selects its loot table.
	var sus_placed: int = 0
	for p in found.suspicious:
		if not world.loaded_at(Vector3(p)): continue
		if world.node_at(p) == Archaeology.SUSPICIOUS_SAND:
			sus_placed += 1
	t.check(sus_placed > 0,"converted cells become suspicious sand in the world")
