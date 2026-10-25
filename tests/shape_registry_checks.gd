extends RefCounted

static func node(name: String) -> int:
	return {"air":0,"mcl_core:stone":Nodes.STONE,"mcl_stairs:slab_oak":4000,"mcl_stairs:slab_oak_top":4001,"mcl_stairs:slab_cobble":4032}.get(name,0)

static func run(t: SceneTree, game: Node3D) -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shapes_reference.json"))
	var origin := Vector3i(8,58,8)
	var passed: int = 0; var failed: int = 0
	game.gamemode = "survival"; game.inventory.selected = 0
	for row in source.placements:
		var normal := Vector3i(int(row.normal.x),int(row.normal.y),int(row.normal.z))
		var under: Vector3i = origin-normal
		for direction in [Vector3i.ZERO,Vector3i.UP,Vector3i.DOWN,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: game.world.set_node(origin+direction,0)
		var under_id: int = Nodes.STONE if row.kind == "stair" else node(row.under)
		game.world.set_node(under,under_id)
		if row.kind == "slab": game.world.set_node(origin,node(row.above))
		var held: int = 4003 if row.kind == "stair" else 4000
		game.inventory.slots[0] = {"id":held,"count":2,"wear":0}
		game.player.position = Vector3(origin)+Vector3.ONE*0.5+Vector3(float(row.relative.x),float(row.relative.y),float(row.relative.z)) if row.kind == "stair" else Vector3(origin)+Vector3(4,0,0)
		var point: Vector3 = Vector3(under)+Vector3.ONE*0.5+Vector3(normal)*0.5
		if normal.y == 0: point.y = under.y+float(row.height)
		BuildingShapes.try_place(game,{"pos":under,"normal":normal,"point":point,"id":under_id,"distance":3})
		var expected: int = 4000
		if row.kind == "stair":
			var rotation: int = int(row.result.param2)
			expected = 4003+([0,3,2,1][rotation-20]+4 if rotation >= 20 else rotation)
		elif str(row.result.name).ends_with("_double"): expected = 4002
		elif str(row.result.name).ends_with("_top"): expected = 4001
		var at: Vector3i = under if row.result.at == "under" else origin
		if game.world.node_at(at) == expected and game.inventory.held().count == 1: passed += 1
		else:
			failed += 1
			if failed < 5: t.check(false,"Source placement %s at %s h=%s: got %s expected %s"%[row.kind,normal,row.height,game.world.node_at(at),expected])
	t.check(failed == 0 and passed == source.placements.size(),"All %d actual source placement callbacks agree, including side thresholds and slab combinations"%source.placements.size())
	# The source's direct set_node combination also succeeds when the player
	# occupies the missing half. Ordinary placement still checks player collision.
	game.world.set_node(origin,4000); game.player.position = Vector3(origin)+Vector3(0.5,0.51,0.5)
	game.inventory.slots[0] = {"id":4000,"count":2,"wear":0}
	BuildingShapes.try_place(game,{"pos":origin,"normal":Vector3i.UP,"point":Vector3(origin)+Vector3(0.5,0.5,0.5),"id":4000})
	t.check(game.world.node_at(origin) == 4002 and game.inventory.held().count == 1,"Combining a slab follows the source's direct placement path")
	game.player.position = Vector3(origin)+Vector3(4,0,0)
	game.inventory.restore([])
	for pair in [[Nodes.SANDSTONE,ShapeMaterials.CUT_SANDSTONE,4],[ShapeMaterials.RED_SAND,ShapeMaterials.RED_SANDSTONE,1],[ShapeMaterials.RED_SANDSTONE,ShapeMaterials.CUT_RED_SANDSTONE,4],[Nodes.LAPIS,ShapeMaterials.LAPIS_BLOCK,1]]:
		var count: int = 9 if pair[0] == Nodes.LAPIS else 4
		game.inventory.restore([]); game.inventory.add_item(pair[0],count)
		t.check(game.inventory.craft(game.inventory.recipe_index(pair[1]),"table") and game.inventory.count_item(pair[1]) == pair[2],"Source base material crafting: "+Nodes.title(pair[1]))
	t.check(Nodes.falls(ShapeMaterials.RED_SAND),"Red sand participates in falling-node simulation")
	t.check(Nodes.smelt_result(ShapeMaterials.RED_SAND) == Nodes.GLASS and Nodes.smelt_result(ShapeMaterials.RED_SANDSTONE) == ShapeMaterials.SMOOTH_RED_SANDSTONE,"Red sand and red sandstone use source smelting recipes")
	var samples: Array = []
	for i in ShapeCatalog.data.new_families.size():
		var first: int = int(ShapeCatalog.data.new_families[i]); var p: Vector3i = origin+Vector3i(i%10-5,3,i/10-2)
		game.world.set_node(p,first+10); samples.append([p,first+10])
	t.check(game.save_game("user://shape-registry-check.json"),"New shape families save")
	game.set_process(true)
	game.load_world_data(game.read_save("user://shape-registry-check.json"))
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	var retained: bool = true
	for sample in samples:
		if game.world.node_at(sample[0]) != sample[1]: retained = false
	t.check(retained,"All 50 new families preserve inverted orientation through save/load")
