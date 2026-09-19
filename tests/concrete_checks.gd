extends RefCounted

# Concrete (mcl_colorblocks): powder falls, hardens on water contact into the
# concrete of its own colour, and the recipe is shapeless sand/gravel/dye.
static func run(suite: Object, game: Node3D) -> void:
	var p: Vector3i = game.world.spawn_point() if game.world.has_method("spawn_point") else Vector3i(0,80,0)
	p = Vector3i(4,game.world.generator.terrain_height(4,4)+2,4)
	for x in range(2,7):
		for z in range(2,7):
			for y in range(p.y-1,p.y+3): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	# Every colour exists, is placeable, and hardens to its own colour.
	suite.check(Concrete.POWDER_FIRST == 11040 and Concrete.BLOCK_FIRST == 11056 and Concrete.COUNT == 16,"concrete ids match the sixteen-colour block")
	var all_ok: bool = true
	for i in Concrete.COUNT:
		var powder: int = Concrete.POWDER_FIRST+i
		var solid: int = Concrete.BLOCK_FIRST+i
		if not Nodes.exists(powder) or not Nodes.exists(solid): all_ok = false
		if not Nodes.placeable(powder) or not Nodes.placeable(solid): all_ok = false
		if Concrete.hardened(powder) != solid: all_ok = false
		if VillageContent.DATA[solid].family != "concrete" or VillageContent.DATA[powder].family != "concrete_powder": all_ok = false
	suite.check(all_ok,"all sixteen powder and concrete blocks exist, are placeable and pair by colour")
	suite.check(Nodes.falls(Concrete.POWDER_FIRST) and not Nodes.falls(Concrete.BLOCK_FIRST),"concrete powder falls but concrete does not")
	suite.check(Concrete.hardened(Concrete.BLOCK_FIRST) == 0,"concrete does not harden again")
	# Water contact hardens in place.
	var in_place: Vector3i = p
	game.world.set_node(in_place,Concrete.POWDER_FIRST+6)
	game.world.set_node(in_place+Vector3i.RIGHT,Nodes.WATER)
	suite.check(Concrete.nearby_water(game.world,in_place),"powder beside water sees the water")
	Concrete.update(game.world,2.0)
	suite.check(game.world.node_at(in_place) == Concrete.BLOCK_FIRST+6,"powder hardens into the concrete of its own colour")
	game.world.set_node(in_place+Vector3i.RIGHT,Nodes.AIR)
	# Powder resting on water sinks the concrete into the water cell.
	var above_water: Vector3i = p+Vector3i(0,2,2)
	game.world.set_node(above_water+Vector3i.DOWN,Nodes.WATER)
	game.world.set_node(above_water,Concrete.POWDER_FIRST+12)
	Concrete.update(game.world,2.0)
	suite.check(game.world.node_at(above_water+Vector3i.DOWN) == Concrete.BLOCK_FIRST+12 and game.world.node_at(above_water) == Nodes.AIR,"powder above water hardens into the water cell and clears its own")
	# An unsupported column of powder falls.
	var column: Vector3i = p+Vector3i(4,0,4)
	game.world.set_node(column+Vector3i.DOWN,Nodes.AIR)
	game.world.set_node(column,Concrete.POWDER_FIRST)
	var before: int = game.entities.get_child_count()
	game.settle(column)
	suite.check(game.entities.get_child_count() > before and game.world.node_at(column) == Nodes.AIR,"unsupported powder becomes a falling node like sand")
	# Recipe: shapeless sand, gravel and dye makes eight powder.
	var inv := Inventory.new()
	for id in [Nodes.SAND,Nodes.GRAVEL]: inv.add_item(id,4)
	inv.add_item(VillageContent.DYE_RED,1)
	var index: int = inv.recipe_index(Concrete.POWDER_FIRST+6)
	suite.check(index >= 0 and inv.can_craft(inv.recipes[index],"table") and inv.recipes[index].shapeless,"the source's shapeless sand, gravel and dye recipe makes red concrete powder")
	suite.check(inv.craft(index,"table") and inv.count_item(Concrete.POWDER_FIRST+6) == 8,"crafting yields the source's eight powder")
	suite.check(not Concrete.is_concrete(Concrete.POWDER_FIRST-1) and not Concrete.is_concrete(Concrete.BLOCK_FIRST+16),"the concrete id range does not leak into neighbouring content")
	# Art must be produced rather than falling back to flat noise.
	var varied: bool = false
	for x in 16:
		for y in 16:
			if Concrete.pixel(Concrete.POWDER_FIRST, x, y, Color(0.5,0.5,0.5)) != Color(0.5,0.5,0.5): varied = true
	suite.check(varied and Nodes.tile(Concrete.BLOCK_FIRST,0) != 0,"concrete has its own atlas tile and procedural art")
