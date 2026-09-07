extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause()
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_position: Vector3 = game.player.position
	var old_selected: int = game.inventory.selected
	var old_mode: String = game.gamemode
	var old_health: float = game.player.health
	game.gamemode = "survival"
	game.inventory.selected = 0
	game.player.position = Vector3(8.5,45,8.5)
	for drop in game.drops.get_children(): drop.free()
	game.inventory.slots[0] = {"id":Nodes.PLANKS,"count":5,"wear":0}
	var q := InputEventKey.new(); q.physical_keycode = KEY_Q; q.pressed = true
	game.state = "playing"; game._unhandled_input(q); game.state = "paused"
	var dropped: ItemDrop = game.drops.get_children().back()
	dropped.set_physics_process(false)
	suite.check(game.inventory.slots[0].count == 4 and dropped.amount == 1,"Q removes and throws exactly one inventory item")
	suite.check(dropped.velocity.dot(-game.player.camera.global_basis.z) > 3 and dropped.pickup_delay == 1.5,"manual drops travel forward with a pickup cooldown")
	var count: int = game.drops.get_child_count()
	q.echo = true; game.state = "playing"; game._unhandled_input(q); game.state = "paused"
	suite.check(game.drops.get_child_count() == count,"keyboard repeat cannot drop extra items from one Q press")
	q.echo = false
	var metadata: Dictionary = {"title":"Deep notes","text":"Bedrock at -128"}
	game.inventory.slots[0] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":3,"data":metadata}
	game.drop_stack(game.inventory.slots[0])
	dropped = game.drops.get_children().back(); dropped.set_physics_process(false)
	suite.check(dropped.data == metadata and dropped.wear == 3 and game.inventory.slots[0].id == 0,"manual dropping preserves written text and durability")
	game.open_inventory()
	game.hud.cursor = {"id":Nodes.STONE,"count":9,"wear":0}
	game.hud.drop_cursor(true)
	suite.check(game.hud.cursor.count == 8 and game.drops.get_children().back().amount == 1,"Q on a carried stack drops one and keeps the remainder")
	# Position the panel away from the current pointer to simulate dragging out.
	game.hud.inventory_panel.position = game.hud.get_global_mouse_position()+Vector2(100,100)
	var esc := InputEventKey.new(); esc.physical_keycode = KEY_ESCAPE; esc.pressed = true
	game._input(esc)
	suite.check(game.playing() and game.hud.cursor.id == 0 and game.drops.get_children().back().amount == 8,"Escape with the carried stack outside inventory drops it and closes the screen")
	game.open_inventory()
	game.hud.cursor = {"id":Nodes.STONE,"count":3,"wear":0}
	game.hud.inventory_panel.position = game.hud.get_global_mouse_position()-Vector2(30,30)
	count = game.drops.get_child_count()
	game._input(esc)
	suite.check(game.playing() and game.drops.get_child_count() == count and game.hud.cursor.id == 0,"Escape inside the inventory safely returns the carried stack")
	game.open_inventory()
	game.hud.recipe_search.grab_focus()
	game.hud.cursor = {"id":Nodes.STONE,"count":2,"wear":0}
	game._input(q)
	suite.check(game.hud.cursor.count == 2,"typing Q in recipe search does not drop items")
	game.hud.recipe_search.release_focus()
	game.hud.drop_cursor(false)
	game.resume(); game.pause()
	# Deep world generation stays deterministic while replacing the old Y=0 floor.
	var gen := TerrainGenerator.new(8675309)
	var column: Dictionary = gen.generate_column(Vector2i.ZERO,{})
	var again: Dictionary = gen.generate_column(Vector2i.ZERO,{})
	suite.check(gen.min_y() == -128 and column.blocks.size() == 12,"Overworld extends through twelve mapblocks down to Y -128")
	var found: Dictionary = {}
	var deterministic: bool = true
	for i in column.blocks.size():
		if column.blocks[i].data != again.blocks[i].data: deterministic = false
		if column.blocks[i].y < 0:
			for id in column.blocks[i].data: found[id] = true
	suite.check(deterministic and found.has(Nodes.DEEPSLATE) and found.has(Nodes.AIR),"deep terrain and caves generate deterministically")
	suite.check(column.blocks[0].data[0] != Nodes.BEDROCK and gen.deep_node(0,-128,0) == Nodes.BEDROCK,"old bedrock at zero opens into new terrain with a protected floor at -128")
	var all_resources: bool = true
	for id in [Nodes.DEEP_DIAMOND_ORE,Nodes.DEEP_IRON_ORE,Nodes.DEEP_GOLD_ORE,Nodes.DEEP_LAPIS_ORE]:
		if not found.has(id): all_resources = false
	suite.check(all_resources,"new deepslate layers contain diamond, iron, gold, and lapis deposits")
	var p := Vector3i(8,-80,8)
	for x in range(-2,3):
		for z in range(-2,3):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.DEEPSLATE)
			for y in range(0,4): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	suite.check(game.world.node_at(Vector3i(8,-128,8)) == Nodes.BEDROCK and not game.world.set_node(Vector3i(8,-129,8),Nodes.STONE),"world collision and editing respect the new lower boundary")
	suite.check(game.world.set_node(Vector3i(15,-81,8),Nodes.DEEPSLATE_BRICKS) and game.world.dirty.has(Vector3i(1,-6,0)),"negative-Y edits remesh neighboring mapblock boundaries")
	var floor_pos: Vector3 = game.world.cave_spawn(Vector3(p),3)
	suite.check(not is_inf(floor_pos.x) and floor_pos.y < -70 and not game.world.intersects(floor_pos),"cave spawning finds a local dry floor instead of the surface")
	game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	game.player.health = 20; game.player.hunger = 20; game.player.damage_cooldown = 0; game.player.survival_timer = 1.0
	game.state = "playing"; game.player._physics_process(0.01); game.state = "paused"
	suite.check(game.player.health == 20 and game.player.position.y < -70,"walking in the deep world does not trigger the old void death limit")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.LAVA); game.world.set_node(p+Vector3i(2,0,0),Nodes.WATER)
	suite.check(game.world.node_at(p+Vector3i.RIGHT) == Nodes.OBSIDIAN,"water and lava reactions work below zero")
	game.world.set_node(p+Vector3i(0,0,2),Nodes.CHEST)
	var chest: Dictionary = game.world.get_station(p+Vector3i(0,0,2),"chest")
	chest.slots[0] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":metadata}
	game.spawn_drop(game.player.position+Vector3(1,1,0),Nodes.DEEP_DIAMOND_ORE,2)
	suite.check(game.save_game("user://depth_check.json"),"deep edits, station contents, and player position save")
	var saved: Dictionary = game.read_save("user://depth_check.json")
	game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+30000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await suite.process_frame
	game.pause()
	chest = game.world.get_station(p+Vector3i(0,0,2),"chest")
	suite.check(game.player.position.y < -70 and game.world.node_at(p+Vector3i(0,0,2)) == Nodes.CHEST and chest.slots[0].data == metadata,"loading restores the player and their chest deep underground")
	var furnace: Dictionary = game.world.get_station(p+Vector3i(0,0,-2),"furnace")
	furnace.slots[0] = {"id":Nodes.DEEP_IRON_ORE,"count":1,"wear":0}
	furnace.slots[1] = {"id":Nodes.LAVA_BUCKET,"count":1,"wear":0}
	for tick in 8: game.world._simulate()
	suite.check(furnace.slots[2].id == Nodes.IRON and furnace.slots[1].id == Nodes.BUCKET and furnace.burn > 900,"lava buckets smelt deep ores and return an empty bucket")
	suite.check(not Nodes.harvestable(Nodes.DEEP_DIAMOND_ORE,85) and Nodes.harvestable(Nodes.DEEP_DIAMOND_ORE,90),"deepslate ores preserve pickaxe progression")
	for result_id in [Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS]:
		var bag := Inventory.new()
		var recipe: Dictionary = bag.recipes[bag.recipe_index(result_id)]
		for id in recipe.ingredients: bag.add_item(id,recipe.ingredients[id])
		suite.check(bag.craft(bag.recipe_index(result_id),"hand") and bag.count_item(result_id) == 4,"crafting produces "+Nodes.title(result_id))
	var atlas: Image = Art.make_atlas().get_image()
	for id in Nodes.DEEP_NODES:
		var tile: int = Nodes.tile(id,0)
		suite.check(Nodes.placeable(id) and Art.build_node_mesh(id).get_surface_count() > 0 and atlas.get_pixel(tile%8*16,tile/8*16).a > 0,Nodes.title(id)+" has a placeable model and atlas texture")
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position; game.player.health = old_health; game.gamemode = old_mode
	game.pause()
	for path in ["user://depth_check.json","user://depth_check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
