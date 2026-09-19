extends RefCounted

# Focused regression for pillager outposts (Mineclonia `mcl_structures/pillager_outpost`
# plus the `mobs_mc:parrot` it spawns).
#
# The outpost is a watchtower with a **raiding party**: the source's `after_place`
# spawns five pillagers, three parrots and one iron golem, and carries a damaged
# anvil. The parrots are the part Voxey lacked entirely — there was no parrot
# creature at all — so this batch adds the bird as well as the tower.

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

	# --- the parrot exists --------------------------------------------------
	# The source's parrot is six health, drops feathers and glides.
	t.check(Creature.KINDS.has("parrot"),"the parrot creature is registered")
	if Creature.KINDS.has("parrot"):
		var info: Dictionary = Creature.KINDS["parrot"]
		t.check(is_equal_approx(float(info.health),6.0),"the parrot has the source's six health")
		t.check(info.get("glides",false) == true,"the parrot glides rather than falling, as a bird does")
		t.check(info.get("hostile",true) == false,"the parrot is passive")
		t.check(Creature.PASSIVE.has("parrot"),"the parrot counts as a passive animal")
	# It drops the feather range the source sets.
	var parrot: Creature = game.spawn_creature("parrot",game.player.position+Vector3(0,3,0))
	t.check(parrot != null,"a parrot can be spawned")
	if parrot != null:
		var feathers: Array = parrot.info().drops
		var has_feathers: bool = false
		for entry in feathers:
			if int(entry[0]) == Nodes.FEATHER: has_feathers = true
		t.check(has_feathers,"a parrot drops feathers, which is the source's own drop")
		t.check(parrot.model.get_child_count() > 0,"the parrot builds a visible model")
		parrot.queue_free()

	# --- the source's party counts ------------------------------------------
	t.check(PillagerOutposts.PILLAGERS == 5,"the source's five pillagers are used")
	t.check(PillagerOutposts.PARROTS == 3,"the source's three parrots are used")
	t.check(PillagerOutposts.GOLEMS == 1,"the source's single iron golem is used")
	# The tower needs the materials it is built from.
	t.check(Nodes.COBBLE != 0 and Nodes.PLANKS != 0,"the tower's materials exist")
	t.check(VillageContent.ANVIL != 0,"the anvil the source constructs exists")

	# --- an outpost exists --------------------------------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in PillagerOutposts.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a pillager outpost exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned outpost builds blocks")
	# The tower is a shell, so a player can climb it, not a solid block.
	var has_ladder: bool = false
	var has_wall: bool = false
	for p in found.voxels:
		if int(found.voxels[p]) == Nodes.LADDER: has_ladder = true
		if int(found.voxels[p]) in [PillagerOutposts.WALL,PillagerOutposts.POST]: has_wall = true
	t.check(has_wall,"an outpost has wooden walls")
	t.check(has_ladder,"an outpost has a ladder, so its platform is reachable")

	# --- the raiding party --------------------------------------------------
	t.check(not found.party.is_empty(),"an outpost carries a raiding party")
	var counts: Dictionary = {}
	for member in found.party:
		counts[String(member[0])] = int(counts.get(String(member[0]),0))+1
	t.check(int(counts.get("pillager",0)) == PillagerOutposts.PILLAGERS,"the party has the source's five pillagers")
	t.check(int(counts.get("parrot",0)) == PillagerOutposts.PARROTS,"the party has the source's three parrots")
	t.check(int(counts.get("iron_golem",0)) == PillagerOutposts.GOLEMS,"the party has the source's one iron golem")
	# Every party member must be a kind the game can actually spawn, or the
	# outpost would report a party it cannot place.
	var spawnable: bool = true
	for member in found.party:
		if not Creature.KINDS.has(String(member[0])): spawnable = false
	t.check(spawnable,"every party member is a spawnable creature kind")

	# --- the chest uses its own table ---------------------------------------
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	PillagerOutposts.fill_chest(chest,88)
	t.check(chest.label == "Pillager outpost chest","the outpost chest is labelled from its own table")
	var filled: int = 0
	var has_crossbow: bool = false
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
		if int(slot.get("id",0)) == VillageContent.CROSSBOW: has_crossbow = true
	t.check(filled >= 5,"the chest holds the source's four groups")
	# The source's last group is a guaranteed crossbow, so every outpost has one.
	t.check(has_crossbow,"the outpost chest always holds a crossbow, as the source's guaranteed group gives")

	# --- it reaches the world ----------------------------------------------
	var world: VoxelWorld = game.world
	# The tower is 32 blocks wide, so it straddles several columns; every one it
	# reaches must be generated for its blocks to appear.
	var lo_c := Vector2i(floori(found.bounds_min.x/16.0),floori(found.bounds_min.z/16.0))
	var hi_c := Vector2i(floori(found.bounds_max.x/16.0),floori(found.bounds_max.z/16.0))
	for cx in range(lo_c.x,hi_c.x+1):
		for cz in range(lo_c.y,hi_c.y+1):
			world._apply_column(gen.generate_column(Vector2i(cx,cz),world.edits))
	var placed: int = 0
	for p in found.voxels:
		if not world.loaded_at(Vector3(p)): continue
		if world.node_at(p) == int(found.voxels[p]): placed += 1
	t.check(placed > 0,"outpost blocks reach the generated world")
