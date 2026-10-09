extends RefCounted

# Focused regression for the screwdriver (Mineclonia `ITEMS/screwdriver/init.lua`,
# GPL-3.0-or-later). The source's node-rotation tool: use turns a node on its face axis,
# place turns it on the other axis. Every family stores its orientation differently, so
# the tool dispatches to the owning module's own state encoding.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var world: VoxelWorld = game.world

	t.check(Screwdriver.ID == 279 and Nodes.exists(Screwdriver.ID) and Nodes.all_ids().has(Screwdriver.ID),"the screwdriver is a catalog tool item")
	t.check(Screwdriver.USES == 200 and Nodes.title(Screwdriver.ID) == "Screwdriver","it carries the source's two hundred uses and name")

	var p := Vector3i(8,700,8)
	for x in range(4,13):
		for z in range(4,13): world.set_node(Vector3i(x,699,z),Nodes.STONE)

	# --- a stair turns on its face -- and the axis mode flips it -------------
	var stair: int = BuildingShapes.stair_for(Nodes.STONE)+3
	world.set_node(p,stair)
	var turned: bool = Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE)
	var after: int = world.node_at(p)
	t.check(turned and BuildingShapes.stair(after) and BuildingShapes.facing(after) == posmod(BuildingShapes.facing(stair)+1,4),"the use action turns a stair's facing")
	t.check(Screwdriver.turn(game,p,Screwdriver.ROTATE_AXIS),"the place action flips a stair's half")
	t.check(BuildingShapes.variant(world.node_at(p)) >= 7 or BuildingShapes.upper(world.node_at(p)),"the stair is inverted after the axis turn")

	# --- a door turns while keeping its material and half -------------------
	var door: int = Doors.state_id(VillageContent.WOODEN_DOOR,0)
	world.set_node(p,door)
	t.check(Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE) and Doors.facing(world.node_at(p)) == 1,"a door turns on its face axis")
	t.check(Doors.item(world.node_at(p)) == VillageContent.WOODEN_DOOR,"the door keeps its material")

	# --- a fence gate turns, an open gate keeps its open flag ---------------
	var gate: int = Barriers.FENCE_BASES[0]+1
	world.set_node(p,gate)
	t.check(Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE) and Barriers.is_gate(world.node_at(p)),"a fence gate turns")

	# --- a log turns through its three axes ----------------------------------
	var log_id: int = WoodTypes.log_id(0)
	world.set_node(p,log_id)
	var axes: Dictionary = {}
	for i in 3:
		Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE)
		axes[WoodTypes.axis(world.node_at(p))] = true
	t.check(axes.size() == 3,"a log turns through all three axis orientations")

	# --- a worn tool and the recipe -----------------------------------------
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Screwdriver.ID,"count":1,"wear":0}
	world.set_node(p,stair)
	game.gamemode = "survival"
	t.check(Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE) and game.inventory.held().wear == 1,"a rotation wears the tool one use")
	game.gamemode = "creative"
	var before_wear: int = game.inventory.held().wear
	Screwdriver.turn(game,p,Screwdriver.ROTATE_FACE)
	t.check(game.inventory.held().wear == before_wear,"a creative rotation does not wear the tool")

	var inv := Inventory.new()
	t.check(inv.recipe_index(Screwdriver.ID) >= 0,"the screwdriver has a recipe")
	if inv.recipe_index(Screwdriver.ID) >= 0:
		var recipe: Dictionary = inv.recipes[inv.recipe_index(Screwdriver.ID)]
		t.check(recipe.ingredients.get(Nodes.IRON,0) == 1 and recipe.ingredients.get(Nodes.STICK,0) == 1,"the recipe is one iron ingot over one stick")
