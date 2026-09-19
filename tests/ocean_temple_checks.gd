extends RefCounted

# Focused regression for ocean monuments (Mineclonia `mcl_structures` `ocean_temple`).
#
# The ocean monument is the **reason guardians exist**, and it closes the loop on
# two earlier batches:
#
#   * Voxey already had the guardian and elder guardian with their full drop
#     tables, including the elder's **guaranteed wet sponge** — which is the only
#     natural source of sponges. This structure gives them a home.
#   * It is the source's own large prismarine build, and prismarine is the
#     conduit's frame material, so the monument is also a source of the blocks a
#     conduit needs.
#
# The source's `after_place` spawns five guardians and one elder, so the garrison
# counts matter, and the elder is the one whose death yields the sponge.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator
	var world: VoxelWorld = game.world

	# --- the source's constants and the garrison ----------------------------
	t.check(OceanTemples.SIDE == 32,"the source's thirty-two block monument is used")
	t.check(OceanTemples.GUARDIANS == 5,"the source's five guardians are used")
	t.check(OceanTemples.ELDERS == 1,"the source's single elder guardian is used")
	t.check(OceanTemples.WATER_NEIGHBOURS == 4,"the source's four water neighbours are required")

	# --- every material it is built from exists -----------------------------
	# The monument is prismarine, so the whole family is a prerequisite.
	t.check(Conduits.PRISMARINE != 0,"prismarine exists, which the monument is built from")
	t.check(Conduits.PRISMARINE_BRICK != 0,"prismarine bricks exist")
	t.check(Conduits.PRISMARINE_DARK != 0,"dark prismarine exists, which the guardians stand on")
	t.check(Conduits.SEA_LANTERN != 0,"sea lanterns exist, which light the monument")

	# --- the guardians it garrisons exist, with their drops -----------------
	# The elder's wet sponge is the whole reason the monument matters: it is the
	# only natural sponge source.
	t.check(Guardians.is_guardian("guardian"),"the guardian exists, which the monument garrisons")
	t.check(Guardians.is_guardian("guardian_elder"),"the elder guardian exists")
	var elder_drops: Array = Guardians.drop_table("guardian_elder")
	var has_sponge: bool = false
	for entry in elder_drops:
		if int(entry[0]) == Sponges.WET: has_sponge = true
	t.check(has_sponge,"the elder still drops a wet sponge, which is the only natural sponge source")

	# --- a monument exists --------------------------------------------------
	var found: Dictionary = {}
	for rx in range(-8,9):
		for rz in range(-8,9):
			for candidate in OceanTemples.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"an ocean monument exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned monument builds blocks")
	# The monument uses the whole prismarine family, which is what makes it
	# recognisable and what makes it a prismarine source.
	var used: Dictionary = {}
	for p in found.voxels: used[int(found.voxels[p])] = true
	t.check(used.has(Conduits.PRISMARINE),"a monument is built from prismarine")
	t.check(used.has(Conduits.PRISMARINE_DARK),"a monument uses dark prismarine")
	t.check(used.has(Conduits.SEA_LANTERN),"a monument is lit by sea lanterns")
	# It is submerged, which the source's `y_max` requires.
	t.check(found.floor_y < TerrainGenerator.SEA,"a monument sits below the waterline")

	# --- the garrison is the source's party ---------------------------------
	t.check(not found.garrison.is_empty(),"a monument carries a garrison")
	var counts: Dictionary = {}
	for member in found.garrison:
		counts[String(member[0])] = int(counts.get(String(member[0]),0))+1
	t.check(int(counts.get("guardian",0)) == OceanTemples.GUARDIANS,"the garrison has the source's five guardians")
	t.check(int(counts.get("guardian_elder",0)) == OceanTemples.ELDERS,"the garrison has the source's single elder")
	# The guardians stand on dark prismarine, which is the source's spawn surface.
	t.check(found.spawn_surface.size() > 0,"a monument lays a spawn surface for its guardians")
	for member in found.garrison:
		t.check(Creature.KINDS.has(String(member[0])),"the garrison's %s is a spawnable creature" % String(member[0]))

	# --- the garrison is really spawned -------------------------------------
	# The check that matters: applying the monument's column must put guardians in
	# the world, not merely report them.
	var chest_at: Vector3i = found.chests.keys()[0] if not found.chests.is_empty() else Vector3i.ZERO
	t.check(chest_at != Vector3i.ZERO,"the monument has a chest that marks its garrison")
	if chest_at == Vector3i.ZERO: return
	var before: int = game.creatures.get_child_count()
	world._apply_column(gen.generate_column(Vector2i(floori(chest_at.x/16.0),floori(chest_at.z/16.0)),world.edits))
	var kinds: Array = []
	for mob in game.creatures.get_children(): kinds.append(String(mob.kind))
	t.check(game.creatures.get_child_count() > before,"applying the monument's column spawns its garrison")
	t.check(kinds.has("guardian"),"guardians are really spawned at the monument")
	t.check(kinds.has("guardian_elder"),"an elder guardian is really spawned at the monument")

	# --- the loot -----------------------------------------------------------
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	OceanTemples.fill_chest(chest,91)
	t.check(chest.label == "Ocean monument chest","the monument chest is labelled from its own table")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 9,"the chest holds the source's supplies, treasure and navigation")
