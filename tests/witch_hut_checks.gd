extends RefCounted

# Focused regression for witch huts (Mineclonia `mcl_structures/witch_hut`), plus
# the witch and cat creatures the structure needed.
#
# A witch hut is a stilted shack in a swamp whose residents are the point: the
# source's `after_place` finds the hut's cauldron, looks for the hut's wooden
# posts at that level, and puts a **witch** and an **all-black cat** on them.
# Neither creature existed in Voxey before this batch.
#
# This suite also checks the thing an earlier batch's tests missed: that the
# residents are **actually spawned into the world**, not merely planned. A
# structure that reports a party it never places is a dead feature.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator
	var world: VoxelWorld = game.world

	# --- the two creatures exist --------------------------------------------
	t.check(Creature.KINDS.has(Witches.KIND),"the witch creature is registered")
	t.check(Creature.KINDS.has(Witches.CAT),"the cat creature is registered")
	if Creature.KINDS.has(Witches.KIND):
		var info: Dictionary = Creature.KINDS[Witches.KIND]
		t.check(is_equal_approx(float(info.health),26.0),"the witch has the source's twenty-six health")
		t.check(info.get("ranged",false) == true,"the witch attacks at range, as the source gives her")
		t.check(info.get("hostile",false) == true,"the witch is hostile")
	# The cat is a small passive animal.
	if Creature.KINDS.has(Witches.CAT):
		var cat: Dictionary = Creature.KINDS[Witches.CAT]
		t.check(is_equal_approx(float(cat.health),10.0),"the cat has the source's ten health")
		t.check(cat.get("hostile",true) == false,"the cat is passive")

	# --- the witch's drop table ---------------------------------------------
	# Her chance field is a denominator, so her redstone always drops and the
	# brewing supplies roll one in eight. This is the same convention the guardian
	# and aquatic drops use.
	var rng := RandomNumberGenerator.new(); rng.seed = 31
	var always: bool = true
	var saw_other: bool = false
	for i in 200:
		var drops: Array = Witches.roll_drops(rng)
		var ids: Array = []
		for entry in drops: ids.append(int(entry[0]))
		if not ids.has(Nodes.REDSTONE_WIRE): always = false
		if ids.size() > 1: saw_other = true
	t.check(always,"a witch always drops redstone, as the source's chance of one gives")
	t.check(saw_other,"a witch also drops the source's rarer brewing supplies")
	# The redstone amount is the source's four to eight.
	var redstone_rng := RandomNumberGenerator.new(); redstone_rng.seed = 41
	var amounts: Array = []
	for i in 100:
		for entry in Witches.roll_drops(redstone_rng):
			if int(entry[0]) == Nodes.REDSTONE_WIRE: amounts.append(int(entry[1]))
	if not amounts.is_empty():
		t.check(amounts.min() >= 4 and amounts.max() <= 8,"the redstone amount is the source's four to eight")

	# --- a hut exists, with a cauldron and residents ------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in WitchHuts.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a witch hut exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned hut builds blocks")
	# The cauldron is the anchor the source's spawn rule reads.
	var has_cauldron: bool = false
	for p in found.voxels:
		if int(found.voxels[p]) == VillageContent.CAULDRON: has_cauldron = true
	t.check(has_cauldron,"a hut has the cauldron the source's spawn rule looks for")
	t.check(found.residents.has("cauldron"),"the hut records its cauldron as the resident marker")
	t.check(found.residents.has("witch"),"the hut has a witch")
	t.check(found.residents.has("cat"),"the hut has a cat")
	# The hut is raised on stilts, which the source converts to oak logs.
	var has_posts: bool = false
	for p in found.legs:
		if int(found.voxels[p]) == WitchHuts.POST: has_posts = true
	t.check(has_posts,"a hut is raised on wooden stilts")

	# --- the residents are really spawned -----------------------------------
	# This is the check an earlier batch's tests missed for other structures: the
	# party must reach the world, not just the plan.
	var cauldron: Vector3i = found.residents.get("cauldron",Vector3i.ZERO)
	t.check(cauldron != Vector3i.ZERO,"the hut's cauldron marker is a real position")
	if cauldron == Vector3i.ZERO: return
	var before: int = game.creatures.get_child_count()
	var coord := Vector2i(floori(cauldron.x/16.0),floori(cauldron.z/16.0))
	world._apply_column(gen.generate_column(coord,world.edits))
	var kinds: Array = []
	for mob in game.creatures.get_children(): kinds.append(String(mob.kind))
	t.check(game.creatures.get_child_count() > before,"applying the hut's column spawns its residents")
	t.check(kinds.has(Witches.KIND),"a witch is really spawned at the hut")
	t.check(kinds.has(Witches.CAT),"the hut's cat is really spawned")
	# Each resident must be a kind the game can spawn, or the hut would report a
	# resident it cannot place.
	for kind in ["witch","cat"]:
		t.check(Creature.KINDS.has(kind),"the hut's %s is a spawnable creature" % kind)
