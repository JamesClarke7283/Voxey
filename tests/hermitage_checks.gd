extends RefCounted

# Focused regression for the ancient hermitage
# (Mineclonia `MAPGEN/mcl_structures/ancient_hermitage.lua`, GPL-3.0-or-later).
#
# The hermitage is the only source of the echo shard — and the echo shard is the whole
# recovery compass recipe — and its chest is the only source of the sculk catalyst the
# death-driven spread needs. These checks pin the depth window, the place-on set, the
# loot table's two headline entries, the three-roll chest and the overlay's deep merge.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var gen: TerrainGenerator = game.world.generator

	# --- the depth window (`mg_overworld_min + 12` .. `+ 72`) ----------------
	t.check(AncientHermitage.depth_allowed(-116),"the hermitage reaches its upper depth")
	t.check(AncientHermitage.depth_allowed(-56),"the hermitage reaches its lower depth")
	t.check(not AncientHermitage.depth_allowed(-117),"the hermitage does not sit above its window")
	t.check(not AncientHermitage.depth_allowed(-55),"the hermitage does not sit below its window")
	t.check(not AncientHermitage.depth_allowed(40),"the hermitage is never placed on the surface")

	# --- the place-on set (`place_on = { deepslate, sculk }`) ----------------
	t.check(AncientHermitage.ground_allowed(Nodes.DEEPSLATE),"the hermitage places on deepslate")
	t.check(AncientHermitage.ground_allowed(Sculk.SCULK),"the hermitage places on sculk")
	t.check(not AncientHermitage.ground_allowed(Nodes.GRASS),"the hermitage never places on grass")
	t.check(not AncientHermitage.ground_allowed(Nodes.SAND),"the hermitage never places on sand")

	# --- the loot table (`ancient_hermitage.lua:29-63`) ----------------------
	var shard_entry: Array = []
	var catalyst_entry: Array = []
	for entry in AncientHermitage.LOOT:
		if int(entry[0]) == Sculk.ECHO_SHARD: shard_entry = entry
		if int(entry[0]) == Sculk.CATALYST: catalyst_entry = entry
	t.check(shard_entry.size() == 4 and int(shard_entry[1]) == 3 and int(shard_entry[2]) == 1 and int(shard_entry[3]) == 3,"the hermitage's echo shard is weight three for one to three")
	t.check(catalyst_entry.size() == 4 and int(catalyst_entry[1]) == 2 and int(catalyst_entry[2]) == 1 and int(catalyst_entry[3]) == 2,"the hermitage's catalyst is weight two for one to two")
	# The two armour trims the source names, drawn from the armour-trim registry.
	var trim_ok: bool = true
	for key in ["ward","silence"]:
		var index: int = ArmorTrims.KEYS.find(key)
		var found: bool = false
		for entry in AncientHermitage.LOOT:
			if int(entry[0]) == ArmorTrims.FIRST+index: found = true
		if index < 0 or not found: trim_ok = false
	t.check(trim_ok,"the hermitage carries the ward and silence trims")

	# --- the chest: three rolls, one stack each ------------------------------
	var station: Dictionary = game.world._new_station("chest",27)
	AncientHermitage.fill_chest(station,4242)
	var filled: int = 0
	for slot in station.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled == AncientHermitage.STACKS_MIN,"the hermitage chest rolls the source's three stacks")
	t.check(station.label == "Ancient hermitage chest","the hermitage chest is labelled")

	# --- planning and the overlay --------------------------------------------
	# A hermitage only stands where the deep buffer is deepslate, which the region
	# scan finds. The scan is bounded so a seed without one cannot hang the suite.
	var found: Dictionary = {}
	var rng := RandomNumberGenerator.new(); rng.seed = 20311
	for rx in range(-6,7):
		for rz in range(-6,7):
			for candidate in AncientHermitage.region_plans(gen,Vector2i(rx,rz)):
				if not candidate.chests.is_empty(): found = candidate; break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a hermitage is found in the generated deep dark")
	if not found.is_empty():
		var chest_at: Vector3i = found.chests.keys()[0]
		t.check(int(found.voxels.get(chest_at,-1)) == Nodes.CHEST,"the hermitage's reported chest is a chest node")
		t.check(not found.chests.is_empty(),"the hermitage reports its chest")
		# Every hermitage cell sits inside the source's depth window and below y zero,
		# which is where the overlay writes.
		var in_window: bool = true
		for p in found.voxels:
			if p.y < gen.min_y() or p.y >= 0: in_window = false
		t.check(in_window,"every hermitage cell lands in the deep buffer")
		# The overlay merges the ruin where the rock is deepslate or air.
		var data := PackedInt32Array(); data.resize(18*18*gen.terrain_ceiling())
		var deep := PackedInt32Array(); deep.resize(18*18*absi(gen.min_y()))
		var base: Vector2i = Vector2i(floori(chest_at.x/16.0),floori(chest_at.z/16.0))*16-Vector2i.ONE
		var index: int = (chest_at.x-base.x)+(chest_at.z-base.y)*18+(chest_at.y-gen.min_y())*324
		deep[index] = Nodes.DEEPSLATE
		var merged: Dictionary = AncientHermitage.overlay(gen,Vector2i(floori(chest_at.x/16.0),floori(chest_at.z/16.0)),data,deep)
		t.check(int(deep[index]) == Nodes.CHEST,"the overlay writes the chest into the deep buffer")
		t.check(merged.chests.has(chest_at),"the overlay reports the chest it placed")

	# --- the route the shard unlocks -----------------------------------------
	# `RecoveryCompass.recipe_entries` is eight echo shards around a compass, and it
	# recorded that the shard had no acquisition route. The hermitage is that route.
	var recipe: Array = RecoveryCompass.recipe_entries()
	var uses_shard: bool = false
	if not recipe.is_empty():
		for entry in recipe[0][3]:
			if int(entry) == Sculk.ECHO_SHARD: uses_shard = true
	t.check(uses_shard,"the recovery compass recipe consumes the echo shard the hermitage supplies")
