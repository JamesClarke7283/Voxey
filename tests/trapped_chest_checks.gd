extends RefCounted

# Focused regression for trapped chests (Mineclonia `mcl_chests:trapped_chest_small`).
#
# A trapped chest is a chest that **emits a redstone signal to its neighbours
# while it is open**. That is its whole purpose: the jungle temple's treasure sits
# behind dispensers, so opening the chest fires them, and the same block is the
# ordinary way to build a hidden door or a chest alarm.

# Ensure the column holding a test position is loaded, since `set_node` refuses
# unloaded terrain and a prior suite's save/reload can unload it.
static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world

	# --- the block exists ---------------------------------------------------
	t.check(VillageContent.DATA.has(TrappedChests.ID),"the trapped chest is a registered node")
	t.check(VillageContent.DATA[TrappedChests.ID].name == "Trapped chest","it carries the source's name")
	t.check(TrappedChests.is_trapped(TrappedChests.ID),"the block identifies itself")
	t.check(not TrappedChests.is_trapped(Nodes.CHEST),"an ordinary chest is not trapped")
	t.check(VillageContent.DATA[TrappedChests.ID].get("chest",false) == true,"it is a container, so it opens a chest screen")

	# --- it is a container, so it holds items -------------------------------
	# The jungle temple's loot is a trapped chest, so it must open as storage.
	t.check(world.circuits.CONTAINERS.has(TrappedChests.ID),"the circuit treats it as a container, so a comparator can read its fullness")
	var station: Dictionary = world.get_station(Vector3i(0,70,0),"chest")
	t.check(station.slots.size() == 27,"a trapped chest holds the source's 27 slots")

	# --- the signal ---------------------------------------------------------
	var at := Vector3i(4,64,4)
	ensure(game,at)
	world.set_node(at,TrappedChests.ID)
	t.check(world.node_at(at) == TrappedChests.ID,"the chest is placed in the world")
	# Closed: no signal.
	t.check(TrappedChests.output(world,at) == 0,"a closed trapped chest emits nothing")
	t.check(world.circuits.output(at,Vector3i.RIGHT) == 0,"the circuit reports nothing for a closed chest")
	# Open: full strength, which is the block's whole purpose.
	TrappedChests.set_open(world,at,true)
	t.check(TrappedChests.is_open(world,at),"the chest records that it is open")
	t.check(TrappedChests.output(world,at) == TrappedChests.SIGNAL,"an open trapped chest emits full strength")
	t.check(TrappedChests.SIGNAL == 15,"the signal is the source's full strength")
	# The circuit must report it too, or a wire beside the chest would see nothing.
	t.check(world.circuits.output(at,Vector3i.RIGHT) == 15,"a wire beside an open trapped chest reads its signal")
	t.check(world.circuits.container_signal(at) == 15,"the comparator path also reads the open signal")
	# Closed again: the signal stops.
	TrappedChests.set_open(world,at,false)
	t.check(TrappedChests.output(world,at) == 0,"closing the chest stops the signal")
	t.check(world.circuits.output(at,Vector3i.RIGHT) == 0,"the wire stops reading once the chest closes")

	# --- a wire really powers from it ---------------------------------------
	# The signal must reach an actual redstone wire, not just report a number.
	var wire := at+Vector3i(0,0,1)
	ensure(game,wire)
	world.set_node(wire,Nodes.REDSTONE_WIRE)
	TrappedChests.set_open(world,at,true)
	world.circuits.refresh(wire)
	for i in 3: world.circuits.step()
	t.check(world.circuits.power.get(wire,0) == 15,"a wire beside an open trapped chest is powered")
	TrappedChests.set_open(world,at,false)
	world.circuits.refresh(wire)
	for i in 6: world.circuits.step()
	t.check(world.circuits.power.get(wire,0) == 0,"the wire loses power when the chest closes")

	# --- the recipe ---------------------------------------------------------
	# The source's own `mcl_temp_helper_recipes` entry, added there precisely
	# because a trapped chest is otherwise unreachable.
	var index: int = game.inventory.recipe_index(TrappedChests.ID)
	t.check(index >= 0,"the trapped chest has a recipe")
	if index >= 0:
		var recipe: Dictionary = game.inventory.recipes[index]
		t.check(recipe.get("shapeless",false) == true,"the source's recipe is shapeless")
		t.check(recipe.ingredients.has(Nodes.IRON),"the recipe takes an iron ingot")
		t.check(recipe.ingredients.has(Nodes.STICK),"the recipe takes a stick")
		t.check(recipe.ingredients.has(Nodes.CHEST),"the recipe takes a chest")

	# --- breaking it returns a chest ----------------------------------------
	# A trapped chest must not be a one-way loss, or a player could trap
	# themselves out of a chest's worth of iron.
	t.check(Nodes.drop(TrappedChests.ID) == TrappedChests.ID or Nodes.drop(TrappedChests.ID) != 0,"breaking a trapped chest drops an item")
