extends RefCounted

# Focused regression for the hanging sign
# (Mineclonia `ITEMS/mcl_signs/init.lua`, MIT). The source registers three placements:
# a ceiling `hanging_sign`, an `attached` form under a non-full support, and a `wall`
# form on a side. Voxey models the ceiling and attached forms as one block (the support's
# shape decides which), and the wall form as four facings in the block's last four ids.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var world: VoxelWorld = game.world

	# --- the registry --------------------------------------------------------
	t.check(Signs.HANGING_BASES.size() == 11 and Signs.HANGING_ITEMS.size() == 11,"a hanging sign exists for every species")
	for index in Signs.HANGING_BASES.size():
		var base: int = Signs.HANGING_BASES[index]
		var item: int = Signs.HANGING_ITEMS[index]
		t.check(base == item and Signs.is_hanging(base) and Signs.hanging_item(base) == item,"hanging %d's item is its base"%index)
		t.check(Nodes.exists(item) and Nodes.placeable(item) and Nodes.max_stack(item) == 16,"hanging %d has one usable 16-stack item"%index)
		# Every state is registered and drops the one item.
		var states_ok: bool = true
		for offset in 20:
			if not Nodes.exists(base+offset) or Nodes.drop(base+offset) != item or Nodes.placeable(base+offset) != (offset == 0): states_ok = false
		t.check(states_ok,"hanging %d's twenty states exist, are hidden but for the item, and drop it"%index)

	# --- the two forms -------------------------------------------------------
	var base: int = Signs.HANGING_BASES[0]
	t.check(not Signs.hanging_wall(base) and Signs.hanging_wall(base+16) and Signs.hanging_wall(base+19),"the ceiling form occupies the first sixteen ids and the wall form the last four")
	var face_ok: bool = true
	for face in 4:
		if not Signs.hanging_wall(base+16+face) or Signs.hanging_facing(base+16+face) != face: face_ok = false
	t.check(face_ok,"each wall state reports its own facing")

	# --- placement -----------------------------------------------------------
	t.check(Signs.hanging_placement_id(0,Vector3i.DOWN,0.0) == base,"placing under a block yields the ceiling form")
	t.check(Signs.hanging_placement_id(0,Vector3i.RIGHT,0.0) == base+16+Signs.SUPPORT.find(-Vector3i.RIGHT),"placing against a side yields the matching wall facing")
	t.check(Signs.hanging_placement_id(0,Vector3i.UP,0.0) == 0,"a hanging sign is not placed on a floor")

	# --- a real placement in the world --------------------------------------
	# A stone block with air below it: the hanging sign attaches to the stone's underside.
	var ground := Vector3i(8,600,8)
	for x in range(4,13):
		for z in range(4,13):
			for y in range(596,604): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	world.set_node(ground,Nodes.STONE)
	game.player.position = Vector3(ground)+Vector3(0.5,-2.0,0.5)
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":base,"count":1,"wear":0}
	# The placement call itself, with the underside target the player would produce.
	Signs.try_place(game,{"pos":ground,"id":Nodes.STONE,"normal":Vector3i.DOWN,"distance":3,"replace":ground+Vector3i.DOWN})
	var placed: int = world.node_at(ground+Vector3i.DOWN)
	t.check(Signs.is_hanging(placed) and not Signs.hanging_wall(placed),"a hanging sign actually attaches under its support")
	t.check(game.inventory.held().count == 0,"placing consumes one item")
	t.check(Signs.station(world,ground+Vector3i.DOWN).serial > 0,"a placed hanging sign carries a text identity")

	# Removing the support drops exactly the one item.
	world.set_node(ground,Nodes.AIR)
	Signs.validate_support(world,ground+Vector3i.DOWN)
	t.check(world.node_at(ground+Vector3i.DOWN) == Nodes.AIR,"removing the support removes the hanging sign")
	var dropped: bool = false
	for node in game.drops.get_children():
		if node.item_id == base: dropped = true
	t.check(dropped,"the unsupported hanging sign drops its one item")

	# --- the recipe ----------------------------------------------------------
	var inv := Inventory.new()
	var index: int = inv.recipe_index(base)
	t.check(index >= 0,("the hanging sign has a recipe" if index >= 0 else "MISSING recipe for %d"%base))
	if index >= 0:
		var recipe: Dictionary = inv.recipes[index]
		t.check(recipe.count == 6 and recipe.ingredients.get(WoodTypes.log_id(0),0) == 3 and recipe.ingredients.get(CopperDecor.CHAIN,0) == 2,"the source's stripped-log-over-two-chains recipe yields six")
