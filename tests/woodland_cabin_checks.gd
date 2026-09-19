extends RefCounted

# Focused regression for woodland cabins (Mineclonia `mcl_structures/woodland_mansion`,
# which registers `woodland_cabin`) plus the two illagers it garrisons.
#
# The cabin's garrison is the point, and one member of it closes a real gap:
# **the evoker is the only survival source of a totem of undying.** Voxey had the
# totem and its whole lethal-damage interception, but no drop, recipe or structure
# anywhere produced one, so the item existed and could never be obtained. The
# source's evoker drops a totem at `chance = 1`, which is always.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator
	var world: VoxelWorld = game.world

	# --- the two illagers exist --------------------------------------------
	t.check(Creature.KINDS.has(Illagers.VINDICATOR),"the vindicator creature is registered")
	t.check(Creature.KINDS.has(Illagers.EVOKER),"the evoker creature is registered")
	for kind in [Illagers.VINDICATOR,Illagers.EVOKER]:
		t.check(is_equal_approx(float(Creature.KINDS[kind].health),24.0),"the %s has the source's twenty-four health" % kind)
		t.check(Creature.KINDS[kind].get("hostile",false) == true,"the %s is hostile" % kind)
	t.check(Illagers.is_illager(Illagers.EVOKER),"the evoker counts as an illager")
	t.check(not Illagers.is_illager("zombie"),"a zombie is not an illager")

	# --- the totem gap ------------------------------------------------------
	# This is why the evoker matters: the totem was unobtainable before it.
	t.check(VillageContent.TOTEM != 0,"the totem of undying exists as an item")
	var evoker_drops: Array = Illagers.drop_table(Illagers.EVOKER)
	var has_totem: bool = false
	for entry in evoker_drops:
		if int(entry[0]) == VillageContent.TOTEM and int(entry[1]) == 1: has_totem = true
	t.check(has_totem,"the evoker drops a totem at the source's chance of one, which is always")
	# And it really does, on every roll.
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var totems: int = 0
	for i in 200:
		for entry in Illagers.roll_drops(Illagers.EVOKER,rng):
			if int(entry[0]) == VillageContent.TOTEM: totems += 1
	t.check(totems == 200,"an evoker always yields a totem of undying")
	# The vindicator's emerald is a source drop with a zero minimum, so it can be
	# absent, which is what the source's own `min = 0` means.
	var emeralds: int = 0
	for i in 200:
		for entry in Illagers.roll_drops(Illagers.VINDICATOR,rng):
			if int(entry[0]) == VillageContent.EMERALD: emeralds += 1
	t.check(emeralds > 0 and emeralds < 200,"a vindicator can drop an emerald, and sometimes does not, as the source's zero minimum gives")

	# --- the source's garrison counts --------------------------------------
	t.check(WoodlandCabins.VINDICATORS == 5,"the source's five vindicators are used")
	t.check(WoodlandCabins.EVOKERS == 1,"the source's single evoker is used")
	t.check(WoodlandCabins.PARROTS == 1,"the source's parrot is used")
	# The cabin's furniture needs its items to exist.
	t.check(VillageContent.BARREL != 0,"barrels exist, which the source constructs in the cabin")
	t.check(Nodes.BOOKSHELF != 0,"bookshelves exist, which the source also constructs")

	# --- a cabin exists -----------------------------------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in WoodlandCabins.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a woodland cabin exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned cabin builds blocks")
	# The cabin is dark oak, and it has the furniture the source constructs.
	var has_dark_oak: bool = false
	for p in found.voxels:
		if int(found.voxels[p]) in [WoodlandCabins.WALL,WoodlandCabins.POST]: has_dark_oak = true
	t.check(has_dark_oak,"a cabin is built from dark oak")
	t.check(not found.furniture.is_empty(),"a cabin carries the source's furniture")

	# --- the garrison is the source's party ---------------------------------
	t.check(not found.garrison.is_empty(),"a cabin carries a garrison")
	var counts: Dictionary = {}
	for member in found.garrison:
		counts[String(member[0])] = int(counts.get(String(member[0]),0))+1
	t.check(int(counts.get("vindicator",0)) == WoodlandCabins.VINDICATORS,"the garrison has the source's five vindicators")
	t.check(int(counts.get("evoker",0)) == WoodlandCabins.EVOKERS,"the garrison has the source's single evoker")
	t.check(int(counts.get("parrot",0)) == WoodlandCabins.PARROTS,"the garrison has the source's parrot")
	for member in found.garrison:
		t.check(Creature.KINDS.has(String(member[0])),"the garrison's %s is a spawnable creature" % String(member[0]))

	# --- the garrison is really spawned -------------------------------------
	var chest_at: Vector3i = found.chests.keys()[0] if not found.chests.is_empty() else Vector3i.ZERO
	t.check(chest_at != Vector3i.ZERO,"the cabin has a chest that marks its garrison")
	if chest_at == Vector3i.ZERO: return
	var before: int = game.creatures.get_child_count()
	world._apply_column(gen.generate_column(Vector2i(floori(chest_at.x/16.0),floori(chest_at.z/16.0)),world.edits))
	var kinds: Array = []
	for mob in game.creatures.get_children(): kinds.append(String(mob.kind))
	t.check(game.creatures.get_child_count() > before,"applying the cabin's column spawns its garrison")
	t.check(kinds.has(Illagers.VINDICATOR),"vindicators are really spawned at the cabin")
	t.check(kinds.has(Illagers.EVOKER),"an evoker is really spawned, so a totem is reachable in survival")

	# --- the loot -----------------------------------------------------------
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	WoodlandCabins.fill_chest(chest,93)
	t.check(chest.label == "Woodland cabin chest","the cabin chest is labelled from its own table")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 7,"the chest holds the source's three groups")
