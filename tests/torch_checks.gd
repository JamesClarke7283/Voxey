extends RefCounted

# Focused regression for the copper torch. `mcl_copper/nodes.lua`:288-303 registers
# it through the same `mcl_torches.register_torch` the default torch uses — light 14,
# the same floor and wall placements, and the recipe of `mcl_copper/crafting.lua`
# (nugget over coal over stick, four). It is the second torch *family*, so a placed
# copper torch is not a plain torch and drops copper back.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)

	t.check(Torches.COPPER == 1297 and Torches.COPPER_WALLS == [1298,1299,1302,1303],"the copper torch keeps its ids")
	t.check(Torches.is_copper(Torches.COPPER) and Torches.is_copper(Torches.COPPER_WALLS[0]) and not Torches.is_copper(Nodes.TORCH),"only the copper family reports as copper")
	t.check(Torches.is_torch(Torches.COPPER) and Torches.is_torch(Nodes.TORCH),"both families are torches")
	t.check(Nodes.exists(Torches.COPPER) and Nodes.placeable(Torches.COPPER),"the copper torch item is placeable")
	for wall in Torches.COPPER_WALLS:
		t.check(Nodes.exists(wall) and not Nodes.placeable(wall),"copper wall torches exist but are not items")
	t.check(Nodes.drop(Torches.COPPER_WALLS[1]) == Torches.COPPER and Nodes.drop(Torches.COPPER) == Torches.COPPER,"every copper torch state drops the one item")

	# The floor/wall placement is family-aware.
	t.check(Torches.placed_for(Torches.COPPER,Vector3i.UP) == Torches.COPPER,"a copper torch on a floor places the copper floor node")
	t.check(Torches.placed_for(Nodes.TORCH,Vector3i.UP) == Nodes.TORCH,"a plain torch on a floor still places the plain node")
	t.check(Torches.placed_for(Torches.COPPER,Vector3i.RIGHT) in Torches.COPPER_WALLS,"a copper torch on a wall places a copper wall node")
	t.check(Torches.placed_for(Nodes.TORCH,Vector3i.RIGHT) in Torches.WALLS,"a plain torch on a wall still places a plain wall node")

	# Light 14, and a distinct atlas tile that the GIMP override supplies.
	game.world.set_node(Vector3i(8,1800,8),Torches.COPPER)
	t.check(Pasture.emission(game.world,Vector3i(8,1800,8)) == 14,"the copper torch emits the source's light 14")
	game.world.set_node(Vector3i(8,1800,8),Nodes.AIR)
	t.check(NodeInfo.mesh_kind(Torches.COPPER,false) == 14,"the copper torch is meshed as a torch")
	t.check(Nodes.tile(Torches.COPPER,0) == Torches.copper_tile() and Torches.copper_tile() >= 137,"the copper torch has its own atlas tile")

	# The recipe: nugget over coal over stick, four out.
	var inv := Inventory.new()
	var recipe: Dictionary = inv.recipes[inv.recipe_index(Torches.COPPER)]
	t.check(recipe.count == 4 and recipe.ingredients.get(RawOres.COPPER_NUGGET,0) == 1 and recipe.ingredients.get(Nodes.COAL,0) == 1 and recipe.ingredients.get(Nodes.STICK,0) == 1,"the copper torch recipe is the source's nugget/coal/stick for four")

	# The GIMP-authored tile must load and be 16x16.
	var path: String = "res://assets/textures/tiles/tile_1297.png"
	t.check(ResourceLoader.exists(path),"the GIMP copper-torch tile ships in assets")
	if ResourceLoader.exists(path):
		var img: Image = Image.load_from_file(path)
		t.check(img != null and img.get_width() == 16 and img.get_height() == 16,"the copper-torch tile is a 16x16 image")

	# The Blender-authored model replaces the procedural mesh, with its UVs remapped
	# into the id's atlas cell; an id with no model falls back to the procedural mesh.
	t.check(ModelOverrides.exists(Torches.COPPER),"the Blender copper-torch model ships in assets")
	var model: ArrayMesh = ModelOverrides.mesh(Torches.COPPER)
	t.check(model != null and model.get_surface_count() == 1,"the copper torch uses the imported model")
	if model != null:
		var uvs: PackedVector2Array = model.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var cell: Rect2 = ModelOverrides._atlas_cell(Torches.COPPER)
		var inside: bool = true
		for uv in uvs:
			if uv.x < cell.position.x-0.001 or uv.x > cell.end.x+0.001 or uv.y < cell.position.y-0.001 or uv.y > cell.end.y+0.001: inside = false
		t.check(inside,"the model's UVs are remapped onto the id's atlas cell")
	t.check(ModelOverrides.mesh(1296) == null,"an id with no model falls back to the procedural mesh")
