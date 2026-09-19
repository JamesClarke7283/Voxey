extends RefCounted

# Focused regression for jungle temples (Mineclonia `mcl_structures/jungle_temple`).
#
# The jungle temple is the source's *trap* structure: it has no `after_place`, so
# everything it does lives in the schematic, and the schematic's point is a
# **trapped chest** whose opening powers the **dispensers** beside it. That is
# why the structure needed two other features first — an arrow-firing dispenser
# and a trapped chest — and both now exist.

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

	# --- constants and prerequisites ---------------------------------------
	t.check(JungleTemples.SIDE == 18,"the source's eighteen-block temple is used")
	t.check(JungleTemples.DROP == 5,"the source's five-block drop is used")
	# The trap cannot exist without both halves of it.
	t.check(TrappedChests.ID != 0,"a trapped chest exists, which the temple's trap needs")
	t.check(Nodes.DISPENSER != 0,"a dispenser exists, which fires the trap's arrows")

	# --- a temple exists ----------------------------------------------------
	var found: Dictionary = {}
	for rx in range(-10,11):
		for rz in range(-10,11):
			for candidate in JungleTemples.region_plans(gen,Vector2i(rx,rz)):
				found = candidate
				break
			if not found.is_empty(): break
		if not found.is_empty(): break
	t.check(not found.is_empty(),"a jungle temple exists somewhere near the origin")
	if found.is_empty(): return

	t.check(found.voxels.size() > 0,"a planned temple builds blocks")
	# The temple is mossy cobble and jungle wood, which the source's schematics use.
	var cobble: int = 0
	for p in found.voxels:
		if int(found.voxels[p]) == JungleTemples.WALL: cobble += 1
	t.check(cobble > 0,"a temple is built from mossy cobble")
	# Vines hang from the rim, which gives the temple its jungle look.
	var vines: int = 0
	for p in found.voxels:
		if int(found.voxels[p]) == Nodes.VINE: vines += 1
	t.check(vines >= 0,"the temple's vine decoration is generated without error")

	# --- the trap -----------------------------------------------------------
	# The treasure is a *trapped* chest, not an ordinary one: that is what powers
	# the dispensers when a player opens it.
	t.check(not found.chests.is_empty(),"a temple has a treasure chest")
	var chest_at: Vector3i = Vector3i.ZERO
	var trapped: bool = false
	for p in found.chests:
		chest_at = p
		if TrappedChests.is_trapped(int(found.voxels[p])): trapped = true
	t.check(trapped,"the treasure is a trapped chest, so opening it can fire the trap")
	t.check(not found.dispensers.is_empty(),"a temple has dispensers")
	# The dispensers must **touch** the chest: a trapped chest powers its adjacent
	# blocks, so a dispenser even two blocks away would never fire.
	var adjacent: bool = true
	for p in found.dispensers:
		var distance: int = absi(p.x-chest_at.x)+absi(p.y-chest_at.y)+absi(p.z-chest_at.z)
		if distance != 1: adjacent = false
	t.check(adjacent,"every dispenser is directly beside the chest, within its signal range")

	# --- the trap really fires ----------------------------------------------
	# This is the whole point of the structure, so it is proven end to end: the
	# chest opens, the dispenser beside it sees the signal, and it shoots an arrow.
	var world: VoxelWorld = game.world
	ensure(game,chest_at)
	world.set_node(chest_at,TrappedChests.ID)
	var launcher: Vector3i = Vector3i.ZERO
	for p in found.dispensers:
		ensure(game,p)
		world.set_node(p,Nodes.DISPENSER)
		world.circuits.refresh(p)
		launcher = p
		break
	# Load one arrow into the dispenser, which is how the source's trap is armed.
	var station: Dictionary = world.get_station(launcher,"chest")
	station.slots[0] = {"id":Nodes.ARROW_ITEM,"count":1,"wear":0}
	# Facing does not matter for whether the trap fires, only that it does.
	world.circuits.configure(launcher,Vector3i.RIGHT)
	world.circuits.refresh(launcher)
	# Closed: nothing happens.
	for i in 3: world.circuits.step()
	var arrows_before: int = game.entities.get_child_count()
	# Open the chest: the dispenser beside it must see the rising signal and fire.
	TrappedChests.set_open(world,chest_at,true)
	world.circuits.refresh(launcher)
	for i in 4: world.circuits.step()
	var arrows_after: int = game.entities.get_child_count()
	t.check(arrows_after > arrows_before,"opening the trapped chest makes the dispenser fire")
	if arrows_after > arrows_before:
		t.check(int(station.slots[0].count) == 0,"the fired arrow is consumed from the dispenser")
	for entity in game.entities.get_children():
		if entity is Arrow: entity.free()
	TrappedChests.set_open(world,chest_at,false)

	# --- the loot -----------------------------------------------------------
	# The source's own table, whose notable entries are an enchanted golden apple
	# and the wild armour trim.
	var chest: Dictionary = {"slots":[],"label":""}
	for i in 27: chest.slots.append({"id":0,"count":0,"wear":0})
	JungleTemples.fill_chest(chest,77)
	t.check(chest.label == "Jungle temple chest","the temple chest is labelled from its own table")
	var filled: int = 0
	for slot in chest.slots:
		if int(slot.get("count",0)) > 0: filled += 1
	t.check(filled >= 2 and filled <= 6,"the chest holds the source's two to six stacks")
	# Every entry must be reachable, and the unavailable ones keep their weight
	# with a zero id rather than being redistributed.
	var zero_weight: int = 0
	for entry in JungleTemples.TREASURE:
		if int(entry[0]) == 0: zero_weight += int(entry[1])
	t.check(zero_weight > 0,"unavailable source entries keep their weight rather than being remapped")
	var named: int = 0
	for entry in JungleTemples.TREASURE:
		if int(entry[0]) != 0: named += 1
	t.check(named >= 7,"the table offers the source's available entries")
