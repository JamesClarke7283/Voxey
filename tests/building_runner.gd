extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-building-tests-"+str(OS.get_process_id()))
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)
func volume(bits: int) -> int:
	var count: int = 0
	for i in 8:
		if bits & (1<<i): count += 1
	return count
func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/stair-reference.json"))
	var index: int = 0; var same: bool = true
	for inverted in 2:
		for facing in 4:
			for encoded in 625:
				var neighbors: Array = []; var value: int = encoded
				for side in 4:
					var digit: int = value%5; value /= 5
					neighbors.append(0 if digit == 0 else 4003+digit-1+inverted*4)
				if BuildingShapes.mask(4003+facing+inverted*4,neighbors) != int(reference.masks[index]): same = false
				index += 1
	check(same and index == 5000,"all 5,000 stair corners match the local Mineclonia resolver")
	var inv := Inventory.new()
	for base in BuildingShapes.MATERIALS:
		var slab: int = BuildingShapes.slab_for(base); var stair: int = BuildingShapes.stair_for(base)
		var recipe: Dictionary = inv.recipes[inv.recipe_index(slab)]
		var stair_recipe: Dictionary = inv.recipes[inv.recipe_index(stair)]
		check(recipe.count == 6 and recipe.ingredients[base] == 3 and stair_recipe.count == 4 and stair_recipe.ingredients[base] == 6,"source slab and stair crafting yields for "+Nodes.title(base))
	check(BuildingShapes.items().size() == (BuildingShapes.MATERIALS.size()+BuildingShapes.EXTRA_MATERIALS.size())*2 and not Nodes.all_ids().has(4001) and not Nodes.all_ids().has(4002),"catalog exposes a slab and stair for every material and hides placement-only variants")
	# The materials added after the original 51 keep their own band, so the original
	# families' ids are untouched and the appended ones do not collide with the
	# barrier families at 5000.
	for base in BuildingShapes.EXTRA_MATERIALS:
		var slab: int = BuildingShapes.slab_for(base); var stair: int = BuildingShapes.stair_for(base)
		check(slab >= BuildingShapes.EXTRA_FIRST and BuildingShapes.is_shape(slab) and BuildingShapes.material(slab) == base and BuildingShapes.item(slab) == slab and BuildingShapes.item(stair) == stair,"extra material has a slab and stair in the extra band: "+Nodes.title(base))
	check(BuildingShapes.slab_for(Nodes.STONE) == 4016 and BuildingShapes.family(BuildingShapes.EXTRA_FIRST) == BuildingShapes.EXTRA_FIRST and not BuildingShapes.is_shape(5000),"the original material ids are unchanged and the extra band does not overlap the barriers")
	check(BuildingShapes.stonecutter_inputs(Nodes.GOLD_BLOCK).is_empty() and BuildingShapes.stonecutter_inputs(Nodes.PLANKS).is_empty(),"wood and decorative metal shapes have no source stonecutter recipes")
	check(BuildingShapes.stonecutter_inputs(Nodes.DEEPSLATE_BRICKS).has(Nodes.DEEPSLATE) and BuildingShapes.stonecutter_inputs(Nodes.BRICKS).has(Nodes.STONE),"stonecutter accepts source raw materials for finished shapes")
	check(Nodes.fuel_time(4000) == 7.5 and Nodes.fuel_time(4003) == 15,"wood slabs retain the source fractional fuel duration")
	for id in range(4000,4011):
		var bits: int = BuildingShapes.mask(id)
		check(volume(bits) == (4 if id < 4002 else (8 if id == 4002 else 6)),"shape has the expected solid volume for state "+str(id))
		check(BuildingShapes.visuals(bits).cracks.get_surface_count() == 1,"selection/crack meshes cover the actual shape for state "+str(id))
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Building tests","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.world.set_process(false)
	load("res://tests/masonry_checks.gd").run(self,game)
	var origin := Vector3i(8,52,8)
	for x in range(-4,5):
		for z in range(-4,5):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(origin)+Vector3(-2,0.01,0.5)
	game.world.set_node(origin,4000)
	check(not game.world.intersects(Vector3(origin)+Vector3(0.5,0.51,0.5)) and game.world.intersects(Vector3(origin)+Vector3(0.5,0.25,0.5)),"lower slab collision leaves its upper half empty")
	var ray: Dictionary = game.world.raycast(Vector3(origin)+Vector3(-2,0.75,0.5),Vector3.RIGHT,3)
	check(ray.is_empty(),"targeting passes through the empty upper half of a slab")
	ray = game.world.raycast(Vector3(origin)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
	check(ray.get("pos") == origin and is_equal_approx(ray.point.y,52.5) and ray.normal == Vector3i.UP,"slab targeting finds its half-height surface")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":4000,"count":3,"wear":0}; game.inventory.selected = 0
	game.gamemode = "survival"; game.player.target = ray; game.player.use()
	check(game.world.node_at(origin) == 4002 and game.inventory.held().count == 2,"placing on a matching lower slab combines it and consumes one slab")
	check(Enchantments.harvest(4002,{} ) == [[4000,2]],"breaking a double slab returns two ordinary slabs")
	game.world.set_node(origin,Nodes.AIR)
	game.player.target = {"pos":origin+Vector3i.LEFT,"normal":Vector3i.RIGHT,"id":Nodes.STONE,"distance":2.0,"point":Vector3(origin)+Vector3(0,0.8,0.5)}
	game.player.use()
	check(game.world.node_at(origin) == 4001,"placing on the upper portion of a wall makes an upper slab")
	check(not BuildingShapes.supports(game.world,origin,Vector3i.RIGHT) and BuildingShapes.supports(game.world,origin,Vector3i.UP),"upper slabs support attachments only on their full top face")
	game.world.set_node(origin,Nodes.AIR)
	game.inventory.slots[0] = {"id":4000,"count":16,"wear":0}
	game.player.target = {"pos":origin+Vector3i.UP,"normal":Vector3i.DOWN,"id":Nodes.STONE,"distance":2.0,"point":Vector3(origin)+Vector3(0.5,1,0.5)}
	game.player.use()
	check(game.world.node_at(origin) == 4001,"placing against a ceiling makes an upper slab")
	game.player.target = {"pos":origin,"normal":Vector3i.DOWN,"id":4001,"distance":2.0,"point":Vector3(origin)+Vector3(0.5,0.5,0.5)}
	game.player.use()
	check(game.world.node_at(origin) == 4002,"placing below a matching upper slab combines the halves")
	game.world.set_node(origin,4000)
	game.inventory.slots[0] = {"id":4016,"count":16,"wear":0}
	game.player.target = {"pos":origin,"normal":Vector3i.UP,"id":4000,"distance":2.0,"point":Vector3(origin)+Vector3(0.5,0.5,0.5)}
	game.player.use()
	check(game.world.node_at(origin) == 4000 and game.world.node_at(origin+Vector3i.UP) == 4016,"different slab materials remain separate blocks")
	game.world.set_node(origin+Vector3i.UP,Nodes.AIR)
	game.inventory.slots[0] = {"id":4003,"count":16,"wear":0}
	for inverted in 2:
		for facing in 4:
			game.world.set_node(origin,Nodes.AIR)
			game.player.camera.look_at(game.player.camera.global_position+Vector3(BuildingShapes.DIRECTIONS[facing]))
			var normal: Vector3i = Vector3i.DOWN if inverted else Vector3i.UP
			game.player.target = {"pos":origin-normal,"normal":normal,"id":Nodes.STONE,"distance":2.0,"point":Vector3(origin)+Vector3(0.5,inverted,0.5)}
			game.player.use()
			check(game.world.node_at(origin) == 4003+facing+inverted*4,"actual stair placement preserves facing %d and inversion %d"%[facing,inverted])
	game.world.set_node(origin,Nodes.AIR)
	game.player.position = Vector3(origin)+Vector3(0.5,0.01,0.5)
	var before: int = game.inventory.held().count
	game.player.use()
	check(game.world.node_at(origin) == Nodes.AIR and game.inventory.held().count == before,"placing stairs cannot intersect the player or consume the blocked item")
	game.player.position = Vector3(origin)+Vector3(-3,0.01,0.5)
	game.world.set_node(origin,4001)
	game.world.set_node(origin+Vector3i.UP,Nodes.REDSTONE_WIRE)
	game.world.set_node(origin,4002)
	check(game.world.node_at(origin+Vector3i.UP) == Nodes.REDSTONE_WIRE,"combining an upper slab preserves supported redstone")
	game.world.set_node(origin,4000)
	check(game.world.node_at(origin+Vector3i.UP) == Nodes.AIR,"redstone drops when a changed shape no longer supports it")
	game.world.set_node(origin,4003)
	game.world.set_node(origin+Vector3i.BACK,Torches.placed(Vector3i.BACK))
	game.world.set_node(origin+Vector3i.FORWARD,4004)
	check(Torches.is_torch(game.world.node_at(origin+Vector3i.BACK)),"a stair's full back face supports a wall torch through an inner corner")
	game.world.set_node(origin+Vector3i.FORWARD,Nodes.AIR)
	game.world.set_node(origin+Vector3i.BACK,Nodes.AIR)
	game.world.set_node(origin,4000)
	game.player.position = Vector3(origin)+Vector3(-0.6,0.01,0.5); game.player.velocity = Vector3(4,0,0)
	game.player._move(Vector3(1.1,0,0),false)
	check(game.player.position.x > origin.x+0.4 and game.player.position.y > origin.y+0.49,"players walk onto a half slab without jumping")
	game.world.set_node(origin,4003)
	game.player.position = Vector3(origin)+Vector3(0.5,0.01,-0.6); game.player.velocity = Vector3(0,0,4)
	for i in 10: game.player._move(Vector3(0,0,0.15),false)
	check(game.player.position.z > origin.z+0.8 and game.player.position.y > origin.y+0.99,"players walk up both stair steps without jumping")
	game.world.set_node(origin,Nodes.STONE)
	game.player.position = Vector3(origin)+Vector3(-0.6,0.01,0.5); game.player.velocity = Vector3(4,0,0)
	game.player._move(Vector3(1.1,0,0),false)
	check(game.player.position.x < origin.x,"automatic stepping cannot climb a full block")
	game.world.set_node(origin,4003); game.world.set_node(origin+Vector3i.BACK,4004)
	check(volume(BuildingShapes.world_mask(game.world,origin)) == 5,"perpendicular leading stairs form an outer corner")
	game.world.set_node(origin+Vector3i.BACK,Nodes.AIR)
	game.world.set_node(origin+Vector3i.FORWARD,4004)
	check(volume(BuildingShapes.world_mask(game.world,origin)) == 7,"perpendicular trailing stairs form an inner corner")
	game.world.set_node(origin+Vector3i.FORWARD,Nodes.AIR)
	check(volume(BuildingShapes.world_mask(game.world,origin)) == 6,"removing neighboring stairs restores the original straight shape")
	check(game.save_game("user://building-check.json"),"building variants save")
	game.load_world_data(game.read_save("user://building-check.json"))
	while game.state == "loading": await process_frame
	game.pause()
	check(game.world.node_at(origin) == 4003 and BuildingShapes.world_mask(game.world,origin) == BuildingShapes.mask(4003),"stair orientation and collision survive a save reload")
	print("BUILDING TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)
