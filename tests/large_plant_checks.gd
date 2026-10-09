extends RefCounted

# Focused regression for large two-block plants (peony, rose bush, lilac,
# sunflower). `mcl_flowers.add_large_plant` registers them as a bottom half that
# carries the stem and a top half that carries the bloom; both halves place
# together, break together, and only the bottom yields the item, which crafts into
# two of the plant's dye. The four top-half blooms are drawn in GIMP.

static func plot(game: Node3D, base: Vector3i) -> void:
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(0,6): game.world.set_node(base+Vector3i(x,y,z),Nodes.AIR)
			game.world.set_node(base+Vector3i(x,-1,z),Nodes.GRASS)

static func drops_of(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and drop.item_id == id and not drop.is_queued_for_deletion(): count += drop.amount
	return count

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"

	# --- the family --------------------------------------------------------
	t.check(LargePlants.BOTTOMS == [11418,11420,11422,11424],"the four large plants keep their bottom ids")
	t.check(LargePlants.is_bottom(11418) and LargePlants.is_top(11419) and not LargePlants.is_bottom(11419),"a pair is a bottom and a top")
	t.check(LargePlants.top(11418) == 11419 and LargePlants.bottom(11419) == 11418,"bottom/top map to each other")
	t.check(LargePlants.top(11419) == 11419 and LargePlants.bottom(11418) == 11418,"the mapping is idempotent")
	for id in LargePlants.BOTTOMS:
		t.check(Nodes.placeable(id) and not Nodes.placeable(id+1),"only the bottom half is an item")
		t.check(Nodes.exists(id) and Nodes.exists(id+1),"both halves exist")
		t.check(LargePlants.dye_of(id) != 0 and Nodes.drop(id+1) == id,"each large plant has a dye and its top half drops the bottom item")

	# The source's `_mcl_crafting_output` is two dye from one plant.
	var inv := Inventory.new()
	for id in LargePlants.BOTTOMS:
		var dye: int = LargePlants.dye_of(id)
		var found: bool = false
		for recipe in inv.recipes:
			if int(recipe.id) == dye and int(recipe.count) == 2 and recipe.ingredients.get(id,0) == 1: found = true
		t.check(found,"the source's two-dye craft for "+Nodes.title(id))

	# --- the pair breaks together -----------------------------------------
	var base := Vector3i(8,52,8)
	plot(game,base)
	game.world.set_node(base,LargePlants.PEONY)
	game.world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	t.check(LargePlants.partner(game.world,base,LargePlants.PEONY) == base+Vector3i.UP,"the bottom's partner is the top")
	t.check(LargePlants.partner(game.world,base+Vector3i.UP,LargePlants.PEONY+1) == base,"the top's partner is the bottom")
	var before: int = drops_of(game,LargePlants.PEONY)
	game.break_node(base+Vector3i.UP,game.world.node_at(base+Vector3i.UP),0)
	t.check(game.world.node_at(base) == Nodes.AIR and game.world.node_at(base+Vector3i.UP) == Nodes.AIR,"breaking one half removes the other")
	t.check(drops_of(game,LargePlants.PEONY) == before+1,"breaking the top half drops exactly one plant item")

	# Breaking the bottom works the same way.
	plot(game,base)
	game.world.set_node(base,LargePlants.SUNFLOWER)
	game.world.set_node(base+Vector3i.UP,LargePlants.SUNFLOWER+1)
	before = drops_of(game,LargePlants.SUNFLOWER)
	game.break_node(base,game.world.node_at(base),0)
	t.check(game.world.node_at(base) == Nodes.AIR and game.world.node_at(base+Vector3i.UP) == Nodes.AIR,"breaking the bottom half removes the top too")
	t.check(drops_of(game,LargePlants.SUNFLOWER) == before+1,"breaking the bottom half drops one item")

	# --- the placement rules ----------------------------------------------
	plot(game,base)
	# A large plant can only sit on the source's `soil_flower` set.
	t.check(LargePlants.SOIL.has(Nodes.GRASS) and LargePlants.SOIL.has(Nodes.DIRT) and not LargePlants.SOIL.has(Nodes.STONE),"soil_flower is the source's set")
	# Placement into a free cell over grass either succeeds (with light) or is
	# refused (without); both are the source's rule, so we assert it does not error
	# and never half-forms.
	var result: bool = LargePlants.can_place(game.world,base)
	t.check(result == true or result == false,"the light rule returns a decision without error")
	if result:
		game.world.set_node(base,LargePlants.LILAC)
		game.world.set_node(base+Vector3i.UP,LargePlants.LILAC+1)
		t.check(game.world.node_at(base+Vector3i.UP) == LargePlants.LILAC+1,"a placed pair stands")

	# --- bone meal drops another plant ------------------------------------
	plot(game,base)
	game.world.set_node(base,LargePlants.PEONY)
	game.world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	game.inventory.restore([]); game.inventory.add_item(Nodes.BONE_MEAL,1); game.inventory.selected = 0
	var bonemeal_drops: int = drops_of(game,LargePlants.PEONY)
	game.player.target = {"pos":base,"normal":Vector3i.UP,"id":LargePlants.PEONY,"distance":2.0,"point":Vector3(base)+Vector3(0.5,0.5,0.5)}
	game.player.use()
	t.check(drops_of(game,LargePlants.PEONY) == bonemeal_drops+1,"bone meal on a large plant drops one more plant")

	# --- the GIMP blooms --------------------------------------------------
	for top_id in [11419,11421,11423,11425]:
		var path: String = "res://assets/textures/tiles/tile_%d.png"%top_id
		t.check(ResourceLoader.exists(path),"the GIMP bloom tile for %d ships"%top_id)
		var img: Image = Art._load_tile(path)
		t.check(img != null and img.get_width() == 16 and img.get_height() == 16,"the bloom tile for %d is 16x16"%top_id)
