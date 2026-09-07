extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/value-noise-reference.json"))
	var exact: bool = true; var worst: float = 0
	for row in reference.samples:
		var p := Vector3i(row[1],row[2],row[3])
		var noise := LuantiValueNoise.new(int(row[0]))
		var difference: float = absf(noise.sample(Vector3(p))-float(row[5]))
		worst = maxf(worst,difference)
		if absf(LuantiValueNoise.lattice(p,int(row[0]))-float(row[4])) > 0.00000015 or difference > 0.00002: exact = false
	t.check(exact,"Luanti value noise agrees with 28 compiled native samples (max error %.8f)"%worst)
	var gen := TerrainGenerator.new(8675309)
	var left: Dictionary = {}; var right: Dictionary = {}; var in_range: bool = true
	for coord in [Vector2i.ZERO,Vector2i.RIGHT]:
		for placement in MinecloniaBlobs.placements(gen,coord):
			var p: Vector3i = placement.pos
			if p.y < -128 or p.y > -46: in_range = false
			if p.x in [15,16]: (left if coord == Vector2i.ZERO else right)[p] = placement.id
	t.check(in_range and not left.is_empty() and left == right,"natural tuff keeps the source height range and agrees across column borders")
	t.check(MinecloniaBlobs.placements(TerrainGenerator.new(8675309,"nether"),Vector2i.ZERO).is_empty(),"Overworld tuff blobs do not alter the Nether")
	var found: bool = false
	for block in game.world.blocks.values():
		if block.data.has(MinecloniaOres.TUFF): found = true; break
	t.check(found,"the generated survival world contains harvestable natural tuff")
	var inv := Inventory.new()
	for pair in [[Nodes.DEEPSLATE_BRICKS,Masonry.DEEP_TILES],[MinecloniaOres.TUFF,Masonry.POLISHED_TUFF],[Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS]]:
		inv.restore([]); inv.add_item(pair[0],4)
		t.check(inv.craft(inv.recipe_index(pair[1]),"hand") and inv.count_item(pair[1]) == 4,"four base blocks craft four "+Nodes.title(pair[1]))
	for pair in [[Nodes.COBBLED_DEEPSLATE,Masonry.CHISELED_DEEP],[Masonry.POLISHED_TUFF,Masonry.CHISELED_TUFF],[Masonry.TUFF_BRICKS,Masonry.CHISELED_TUFF_BRICKS]]:
		inv.restore([]); inv.add_item(BuildingShapes.slab_for(pair[0]),2)
		t.check(inv.craft(inv.recipe_index(pair[1]),"hand") and inv.count_item(pair[1]) == 1,"stacked slabs craft "+Nodes.title(pair[1]))
	t.check(Nodes.smelt_result(Nodes.DEEPSLATE_BRICKS) == Masonry.CRACKED_DEEP_BRICKS and Nodes.smelt_result(Masonry.DEEP_TILES) == Masonry.CRACKED_DEEP_TILES,"smelting creates both source cracked deepslate variants")
	for id in Masonry.BLOCKS:
		t.check(Nodes.exists(id) and Nodes.placeable(id) and Nodes.harvestable(id,Nodes.TOOLS) and not Nodes.harvestable(id,0),"survival pickaxe acquisition for "+Nodes.title(id))
	t.check(Masonry.cuts()[Masonry.CHISELED_TUFF_BRICKS] == [MinecloniaOres.TUFF,Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS],"chiseled tuff bricks retain all source stonecutter inputs")
