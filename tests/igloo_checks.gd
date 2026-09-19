extends RefCounted

# Focused regression for igloos (Mineclonia `mcl_structures/igloo`).
#
# An igloo is not a loot hut. It is a **self-contained cure puzzle**: the hut
# hides a basement with a brewing stand, a jukebox, a bookshelf, a villager and a
# zombie villager — and its chest's first group is a **guaranteed golden apple**.
# The shaft down to it is lined with infested bricks, so the way in is an ambush.
#
# Three earlier batches were prerequisites: infested blocks, the zombie villager
# and its cure, and the brewing stand. All are now present, so this structure
# could finally be built.

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the source's constants --------------------------------------------
	t.check(Igloos.SIDE == 16,"the source's sixteen-block hut is used")
	t.check(Igloos.BASEMENT_CHANCE == 2,"the source's fifty percent basement chance is used")
	t.check(Igloos.INFESTED_CHANCE == 10,"one shaft brick in ten is infested, as the source's own roll gives")
	t.check(Igloos.CRACKED_CHANCE == 3,"one in three of the shaft's bricks is cracked")

	# --- the cure puzzle's ingredients must all exist ----------------------
	# The basement is a cure puzzle, so every part of the puzzle is a prerequisite.
	t.check(Nodes.GOLDEN_APPLE != 0,"the golden apple exists, which is the cure item")
	t.check(VillageContent.BREWING_STAND != 0,"the brewing stand exists, for the weakness potion")
	t.check(Creature.KINDS.has(ZombieVillagers.KIND),"the zombie villager exists, which the basement hides")
	t.check(MonsterEggs.BRICKS != 0,"infested bricks exist, which line the shaft")
	t.check(Masonry.CRACKED_BRICKS != 0,"cracked bricks exist, which also line the shaft")
	t.check(PotionEffects.NAMES.has("weakness"),"the weakness effect exists, which the cure requires")

	# --- igloos exist, and half have basements ------------------------------
	var total: int = 0
	var basements: int = 0
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in Igloos.region_plans(gen,Vector2i(rx,rz)):
				total += 1
				if candidate.residents.has("villager"): basements += 1
	t.check(total > 0,"igloos exist somewhere near the origin")
	if total == 0: return
	# The source makes half of all igloos a plain hut, so the rate must be near
	# fifty percent rather than all or none.
	var rate: float = 100.0*float(basements)/float(total)
	t.check(rate > 30.0 and rate < 70.0,"the basement appears at roughly the source's fifty percent rate")

	# --- a basement igloo is the cure puzzle --------------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in Igloos.region_plans(gen,Vector2i(rx,rz)):
				if candidate.residents.has("villager"): found = candidate
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"an igloo with a basement exists")
	if found.is_empty(): return

	# The hut is snow, and its shaft is lined with the source's brick mix.
	var snow: int = 0
	for p in found.voxels:
		if int(found.voxels[p]) == Nodes.SNOW_BLOCK: snow += 1
	t.check(snow > 0,"an igloo is built from snow")
	t.check(found.shaft.size() > 0,"a basement igloo has a ladder shaft")
	var infested: int = 0
	var cracked: int = 0
	var plain: int = 0
	for p in found.shaft:
		var id: int = int(found.voxels[p])
		if MonsterEggs.is_infested(id): infested += 1
		elif id == Masonry.CRACKED_BRICKS: cracked += 1
		elif id == Nodes.BRICKS: plain += 1
	# This is the ambush: the shaft really does contain infested blocks.
	t.check(infested > 0,"the shaft contains infested bricks, so the way down is a trap")
	t.check(cracked > 0,"the shaft contains cracked bricks, as the source's roll gives")
	t.check(plain > 0,"the shaft also contains ordinary bricks")
	# The infested share must be near the source's one in ten, not every brick.
	var infested_share: float = 100.0*float(infested)/float(maxi(1,infested+cracked+plain))
	t.check(infested_share > 4.0 and infested_share < 18.0,"the infested share is near the source's one in ten")

	# Each rotation puts the shaft in a different corner, which is the source's
	# own `rotation` rule.
	var rotations: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in Igloos.region_plans(gen,Vector2i(rx,rz)):
				if candidate.has("shaft_pos"): rotations[candidate.rotation] = true
	t.check(rotations.size() > 1,"igloos use more than one rotation, as the source randomises it")

	# --- the residents are the two halves of the cure -----------------------
	t.check(found.residents.has("villager"),"the basement holds a villager")
	t.check(found.residents.has("zombie_villager"),"the basement holds a zombie villager")
	t.check(found.residents.has("brewing_stand"),"the basement holds a brewing stand, for the weakness potion")
	# Every resident must be a kind the game can spawn.
	for kind in ["villager","zombie_villager"]:
		t.check(Creature.KINDS.has(kind),"the basement's %s is a spawnable creature" % kind)

	# --- the chest is the cure's other half ---------------------------------
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	Igloos.fill_chest(chest,5)
	t.check(chest.label == "Igloo chest","the igloo chest is labelled from its own table")
	# The source's first group is a *guaranteed* golden apple, which is what makes
	# the cure reachable from the structure rather than only by crafting.
	t.check(int(chest.slots[0].id) == Nodes.GOLDEN_APPLE,"the chest always holds a golden apple, as the source's first group gives")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 3,"the chest holds the source's stores as well")

	# --- it reaches the world ----------------------------------------------
	var world: VoxelWorld = game.world
	var lo_c := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
	var hi_c := Vector2i(floori(found.bounds_max.x/16.0),floori(found.bounds_max.z/16.0))
	for cx in range(lo_c.x,hi_c.x+1):
		for cz in range(lo_c.y,hi_c.y+1):
			world._apply_column(gen.generate_column(Vector2i(cx,cz),world.edits))
	var placed: int = 0
	for p in found.voxels:
		if not world.loaded_at(Vector3(p)): continue
		if world.node_at(p) == int(found.voxels[p]): placed += 1
	t.check(placed > 0,"igloo blocks reach the generated world")
	# The shaft's infested bricks must really be in the world and really infested.
	var infested_placed: int = 0
	for p in found.shaft:
		if not world.loaded_at(Vector3(p)): continue
		if MonsterEggs.is_infested(world.node_at(p)): infested_placed += 1
	if infested > 0:
		t.check(infested_placed > 0,"the shaft's infested bricks reach the world, so the ambush is real")
