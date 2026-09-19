extends RefCounted

# Focused regression for ruined portals (Mineclonia `mcl_structures/ruined_portal`).
#
# The structure matters for two reasons beyond decoration:
#   * Its obsidian is the surface route to the material a player needs to build a
#     Nether portal, and its crying obsidian is the source's respawn-anchor
#     material.
#   * The source does not place a clean frame. It **degrades** one, with an
#     independent chance per material, and the obsidian has two rolls so a frame
#     block can become crying obsidian, vanish, or both in sequence.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the source's own degradation chances -------------------------------
	t.check(RuinedPortals.GOLD_TO_AIR == 30,"the source's thirty percent gold removal is used")
	t.check(RuinedPortals.LAVA_TO_MAGMA == 20,"the source's twenty percent lava conversion is used")
	t.check(RuinedPortals.RACK_TO_MAGMA == 7,"the source's seven percent netherrack conversion is used")
	t.check(RuinedPortals.OBBY_TO_CRYING == 15,"the source's fifteen percent crying obsidian is used")
	t.check(RuinedPortals.OBBY_TO_AIR == 10,"the source's ten percent obsidian removal is used")
	t.check(RuinedPortals.BRICK_TO_CRACKED == 50,"the source's fifty percent brick cracking is used")

	# --- the prerequisites exist -------------------------------------------
	# The frame needs obsidian and stone bricks, and the degradation needs crying
	# obsidian, magma and cracked bricks, none of which the structure could use
	# without the supporting blocks existing.
	t.check(Nodes.OBSIDIAN != 0,"obsidian exists as the frame material")
	t.check(Nodes.BRICKS != 0,"stone bricks exist as the base material")
	t.check(Bastions.CRYING_OBSIDIAN != 0,"crying obsidian exists as a degradation result")
	t.check(Magma.ID != 0,"magma exists as a degradation result")
	t.check(Masonry.CRACKED_BRICKS != 0,"cracked stone bricks exist as a degradation result")
	t.check(VillageContent.DATA.has(Masonry.CRACKED_BRICKS),"cracked stone bricks are registered")
	t.check(VillageContent.DATA.has(Masonry.CHISELED_BRICKS),"chiseled stone bricks are registered")
	t.check(VillageContent.DATA.has(Masonry.MOSSY_BRICKS),"mossy stone bricks are registered")
	# The plain bricks smelt into the cracked variant, which is the source's own
	# `_mcl_cooking_output`.
	t.check(Nodes.smelt_result(Nodes.BRICKS) == Masonry.CRACKED_BRICKS,"plain stone bricks smelt into cracked ones")

	# --- a portal exists ----------------------------------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in RuinedPortals.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a ruined portal exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned portal builds blocks")
	# Every planned block carries a material tag, which is what the degradation
	# rules are applied by.
	var tagged: bool = true
	for p in found.voxels:
		if String(found.materials.get(p,"")).is_empty(): tagged = false
	t.check(tagged,"every planned block carries the material its rule needs")
	# The frame is obsidian and its base is stone bricks.
	var obsidian: int = 0
	var bricks: int = 0
	for p in found.voxels:
		if String(found.materials.get(p,"")) == "obsidian": obsidian += 1
		if String(found.materials.get(p,"")) == "brick": bricks += 1
	t.check(obsidian > 0,"a portal has an obsidian frame")
	t.check(bricks > 0,"a portal has a stone brick base")

	# --- the degradation really happens -------------------------------------
	# Across many portals the rules must fire, and at roughly the source's rates.
	var totals: Dictionary = {}
	var converted: Dictionary = {}
	for rx in range(-14,15):
		for rz in range(-14,15):
			for candidate in RuinedPortals.region_plans(gen,Vector2i(rx,rz)):
				for p in candidate.voxels:
					var kind: String = String(candidate.materials.get(p,""))
					if kind.is_empty(): continue
					totals[kind] = int(totals.get(kind,0))+1
					var after: int = int(candidate.degraded.get(p,candidate.voxels[p]))
					if after != int(candidate.voxels[p]):
						converted[kind] = int(converted.get(kind,0))+1
	# Each material's conversion must land near its source chance, within a wide
	# band so the test is not a coin flip.
	var rates: Dictionary = {"gold":RuinedPortals.GOLD_TO_AIR,"lava":RuinedPortals.LAVA_TO_MAGMA,
		"rack":RuinedPortals.RACK_TO_MAGMA,"brick":RuinedPortals.BRICK_TO_CRACKED}
	for kind in rates:
		var total: int = int(totals.get(kind,0))
		if total < 200: continue
		var observed: float = 100.0*float(converted.get(kind,0))/float(total)
		var wanted: float = float(rates[kind])
		t.check(absi(int(observed-wanted)) <= 8,"the %s conversion fires at the source's rate" % kind)

	# The obsidian's two rules must both be reachable, and crying obsidian must
	# appear as a result.
	var crying: bool = false
	var removed_obsidian: bool = false
	for rx in range(-14,15):
		for rz in range(-14,15):
			for candidate in RuinedPortals.region_plans(gen,Vector2i(rx,rz)):
				for p in candidate.voxels:
					if String(candidate.materials.get(p,"")) != "obsidian": continue
					var after: int = int(candidate.degraded.get(p,candidate.voxels[p]))
					if after == Bastions.CRYING_OBSIDIAN: crying = true
					elif after == Nodes.AIR: removed_obsidian = true
	t.check(crying,"a portal frame can degrade to crying obsidian, the source's own route to it")
	t.check(removed_obsidian,"a portal frame block can be missing, as the source's removal rule gives")

	# --- the chest uses its own table ---------------------------------------
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	RuinedPortals.fill_chest(chest,55)
	t.check(chest.label == "Ruined portal chest","the portal chest is labelled from its own table")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 4,"the portal chest holds the source's supplies and treasure")

	# --- it reaches the world ----------------------------------------------
	var world: VoxelWorld = game.world
	var column := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
	if not world.loaded_at(Vector3(found.bounds_min)):
		world._apply_column(gen.generate_column(column,world.edits))
	var placed: int = 0
	for p in found.voxels:
		if not world.loaded_at(Vector3(p)): continue
		var wanted: int = int(found.degraded.get(p,found.voxels[p]))
		if world.node_at(p) == wanted: placed += 1
	t.check(placed > 0,"degraded portal blocks reach the generated world")
