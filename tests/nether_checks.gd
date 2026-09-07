extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause()
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position
	var old_xp: float = game.experience
	var old_mode: String = game.gamemode
	game.gamemode = "survival"
	for child in game.drops.get_children(): child.free()
	for child in game.entities.get_children(): child.free()
	for child in game.creatures.get_children(): child.free()
	var p := Vector3i(8,44,8)
	for x in range(-5,6):
		for z in range(-5,6):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(0,6): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	game.inventory.selected = 0
	for slot in game.inventory.slots: slot.clear(); slot.merge({"id":Nodes.STONE,"count":64,"wear":0})
	game.spawn_drop(game.player.position+Vector3(1,0,0),Nodes.ARROW_ITEM,2)
	var drop: ItemDrop = game.drops.get_children().back()
	drop.set_physics_process(false); drop.age = 1; drop.velocity = Vector3.ZERO
	var original: Vector3 = drop.position
	game.state = "playing"; drop._physics_process(0.1); game.state = "paused"
	suite.check(drop.position.is_equal_approx(original) and drop.amount == 2,"full inventory does not attract or consume a ground pickup")
	game.inventory.slots[0] = {"id":Nodes.ARROW_ITEM,"count":63,"wear":0}
	game.state = "playing"; drop._physics_process(0.1); game.state = "paused"
	suite.check(drop.position.is_equal_approx(original) and drop.amount == 2,"a stack stays on the ground until the whole pickup fits")
	game.inventory.slots[1] = {"id":0,"count":0,"wear":0}
	drop.position = game.player.position+Vector3.UP*0.8
	game.state = "playing"; drop._physics_process(0.01); game.state = "paused"
	suite.check(drop.is_queued_for_deletion() and game.inventory.count_item(Nodes.ARROW_ITEM) == 65,"pickup fills compatible stacks and uses free inventory space")
	var arrow: Arrow = game.spawn_arrow(game.player.position+Vector3(3,0.4,0),Vector3.ZERO)
	arrow.set_physics_process(false); arrow.stuck = true; arrow.life = 599
	game.state = "playing"; arrow._physics_process(0.5); game.state = "paused"
	suite.check(not arrow.is_queued_for_deletion(),"grounded arrow persists until ten active minutes")
	game.state = "playing"; arrow._physics_process(0.5); game.state = "paused"
	suite.check(arrow.is_queued_for_deletion(),"grounded arrow expires at ten minutes")
	arrow = game.spawn_arrow(game.player.position+Vector3(0.3,0.5,0),Vector3.ZERO)
	arrow.set_physics_process(false); arrow.stuck = true
	var before_count: int = game.inventory.count_item(Nodes.ARROW_ITEM)
	game.state = "playing"; arrow._physics_process(0.01); game.state = "paused"
	suite.check(arrow.is_queued_for_deletion() and game.inventory.count_item(Nodes.ARROW_ITEM) == before_count+1,"both enemy and player ground arrows can be recovered")
	var skeleton: Creature = game.spawn_creature("skeleton",game.player.position+Vector3(0,0,-8))
	skeleton.set_physics_process(false)
	skeleton.model.rotation.y = 0
	suite.check(not skeleton.facing_player(),"skeleton cannot shoot a player behind its model")
	var shots_before: int = game.entities.get_child_count()
	game.state = "playing"; skeleton._physics_process(0.01); game.state = "paused"
	suite.check(game.entities.get_child_count() == shots_before,"skeleton physics does not fire backward while turning")
	skeleton.model.rotation.y = PI
	suite.check(skeleton.facing_player(),"skeleton may shoot after facing the player")
	game.state = "playing"; skeleton._physics_process(0.01); game.state = "paused"
	suite.check(game.entities.get_child_count() == shots_before+1,"facing skeleton fires from its bow after turning")
	skeleton.free()
	for d in VoxelWorld.SIDES:
		game.world.set_node(p,Nodes.LAVA)
		game.world.set_node(p+d,Nodes.WATER)
		suite.check(game.world.node_at(p) == Nodes.OBSIDIAN,"water converts a lava source on side "+str(d))
		game.world.set_node(p+d,Nodes.AIR)
	game.world.set_node(p,Nodes.WATER); game.world.set_node(p+Vector3i.RIGHT,Nodes.LAVA)
	suite.check(game.world.node_at(p+Vector3i.RIGHT) == Nodes.OBSIDIAN,"placing lava beside existing water also creates obsidian")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	for result_id in [Nodes.BOOK,Nodes.BOOKSHELF,Nodes.WRITABLE_BOOK,Nodes.ENCHANTING_TABLE]:
		var bag := Inventory.new()
		var recipe: Dictionary = bag.recipes[bag.recipe_index(result_id)]
		for ingredient in recipe.ingredients: bag.add_item(ingredient,recipe.ingredients[ingredient])
		suite.check(bag.fill_grid(bag.recipe_index(result_id),recipe.station) and bag.take_grid_result(recipe.station).id == result_id,"crafting guide produces "+Nodes.title(result_id))
	for id in Nodes.NETHER_NODES:
		var mesh: ArrayMesh = Art.build_node_mesh(id)
		suite.check(mesh.get_surface_count() > 0,Nodes.title(id)+" has visible geometry")
		if id == Nodes.ENCHANTING_TABLE:
			suite.check(load("res://tests/content_checks.gd")._outward(mesh),"enchanting table and floating book faces point outward")
	var gen := TerrainGenerator.new(8675309)
	var lava_found: bool = false; var lapis_found: bool = false
	for z in range(-2,3):
		for x in range(-2,3):
			var col: Dictionary = gen.generate_column(Vector2i(x,z),{})
			for block in col.blocks:
				lava_found = lava_found or block.data.has(Nodes.LAVA)
				lapis_found = lapis_found or block.data.has(Nodes.LAPIS_ORE)
	suite.check(lava_found and lapis_found,"overworld caves naturally contain lava and lapis ore")
	var nether := TerrainGenerator.new(8675309,"nether")
	var column: Dictionary = nether.generate_column(Vector2i.ZERO,{})
	var same: Dictionary = nether.generate_column(Vector2i.ZERO,{})
	suite.check(column.blocks[1].data == same.blocks[1].data,"Nether terrain generation is deterministic")
	suite.check(column.blocks[8].data[0] == Nodes.BEDROCK and column.blocks[0].data[0] == Nodes.BEDROCK,"Nether has a bedrock ceiling and floor")
	var has_water: bool = false; var has_lava: bool = false
	for block in column.blocks:
		has_water = has_water or block.data.has(Nodes.WATER)
		has_lava = has_lava or block.data.has(Nodes.LAVA)
	for x in range(-128,129,16):
		for z in range(-128,129,16): has_lava = has_lava or nether.nether_node(x,13,z) == Nodes.LAVA
	suite.check(has_lava and not has_water,"Nether generates lava seas without overworld water")
	for axis in [Vector3i.RIGHT,Vector3i.BACK]:
		var base: Vector3i = p+Vector3i(0,1,0)
		for x in range(-1,3):
			for y in range(-1,4): game.world.set_node(base+axis*x+Vector3i.UP*y,Nodes.OBSIDIAN if x in [-1,2] or y in [-1,3] else Nodes.AIR)
		suite.check(game.world.ignite_portal(base) and game.world.node_at(base) == Nodes.NETHER_PORTAL,"obsidian frame ignites on axis "+str(axis))
		game.world.set_node(base-axis+Vector3i.UP,Nodes.AIR)
		suite.check(game.world.node_at(base) == Nodes.AIR,"breaking frame collapses the connected portal")
		for x in range(-1,3):
			for y in range(-1,4): game.world.set_node(base+axis*x+Vector3i.UP*y,Nodes.AIR)
	game.world.set_node(p,Nodes.ENCHANTING_TABLE)
	for slot in game.inventory.slots: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
	game.inventory.add_item(95); game.inventory.add_item(Nodes.LAPIS,8)
	game.experience = 1395 # Level 34, enough to exercise all tiers.
	var xp: float = game.experience
	suite.check(not game.enchant_item(0,3,p) and game.experience == xp and game.inventory.count_item(Nodes.LAPIS) == 8,"missing bookshelves block enchanting without spending XP or lapis")
	for x in range(-2,3):
		for z in range(-2,3):
			if maxi(absi(x),absi(z)) == 2: game.world.set_node(p+Vector3i(x,0,z),Nodes.BOOKSHELF)
	for x in range(-1,2):
		for z in range(-1,2):
			if x != 0 or z != 0: game.world.set_node(p+Vector3i(x,0,z),Nodes.STONE)
	suite.check(game.bookshelf_power(p) == 0,"blocking the air gap disables bookshelf power")
	for x in range(-1,2):
		for z in range(-1,2):
			if x != 0 or z != 0: game.world.set_node(p+Vector3i(x,0,z),Nodes.AIR)
	suite.check(game.bookshelf_power(p) == 15,"fifteen unobstructed bookshelves provide maximum enchanting power")
	suite.check(game.enchant_item(0,3,p) and game.inventory.count_item(Nodes.LAPIS) == 5 and game.experience < xp and Inventory.enchantment(game.inventory.slots[0],"Efficiency") == 3,"tier III enchanting spends three lapis and three levels and upgrades the actual tool")
	xp = game.experience
	suite.check(not game.enchant_item(0,1,p) and game.experience == xp,"re-enchanting an enchanted item cannot spend resources")
	game.inventory.slots[1] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"title":"Cave notes","text":"Lava below.\nBring water."}}
	game.inventory.selected = 1
	game.open_book()
	game.inventory.selected = 0
	var editor: TextEdit
	for child in game.hud.layer.get_children().back().get_children():
		if child is TextEdit: editor = child
	suite.check(editor != null and editor.text.contains("Bring water"),"book editor loads the selected book's text")
	editor.text = "A saved draft"; editor.text_changed.emit()
	suite.check(game.inventory.slots[1].data.text == "A saved draft","book drafts write back to their own inventory item")
	game.resume(); game.pause()
	game.hud.cursor = {"id":0,"count":0,"wear":0}
	game.hud._slot_click(1,false,false)
	game.hud._slot_click(2,false,false)
	suite.check(game.inventory.slots[2].get("data",{}).get("text","") == "A saved draft" and game.inventory.slots[1].id == 0,"moving a book through the cursor preserves its draft")
	game.inventory.selected = 2; game.open_book()
	for child in game.hud.layer.get_children().back().get_children():
		if child is Button and child.text.begins_with("Sign"): child.pressed.emit(); break
	suite.check(game.inventory.slots[2].id == Nodes.WRITTEN_BOOK and game.inventory.slots[2].data.text == "A saved draft","signing preserves text and changes the book into a written book")
	game.open_book()
	var read_only: bool = false
	for child in game.hud.layer.get_children().back().get_children():
		if child is TextEdit: read_only = not child.editable
	suite.check(read_only,"signed books open for reading without allowing edits")
	game.resume(); game.pause(); game.inventory.selected = 0
	var saved_item: Dictionary = game.inventory.slots[0].duplicate(true)
	game.spawn_drop(Vector3(p)+Vector3(4,0,0),Nodes.ARROW_ITEM,1,0,{},597)
	arrow = game.spawn_arrow(Vector3(p)+Vector3(4,0.2,0),Vector3.ZERO)
	arrow.stuck = true; arrow.life = 590; arrow.set_physics_process(false)
	suite.check(game.save_game("user://nether_check.json"),"enchantments, books and grounded arrows save")
	var saved: Dictionary = game.read_save("user://nether_check.json")
	suite.check(Inventory.clean_slot(saved.inventory[0]) == saved_item and saved.inventory[2].data.text == "A saved draft","saved item metadata retains enchantments and book text")
	suite.check(saved.arrows.size() == 1 and saved.arrows[0].life == 590,"save preserves grounded arrow age")
	game.player.position = Vector3(p)+Vector3(0.5,1.01,3.5)
	game.travel_dimension("nether")
	var deadline: int = Time.get_ticks_msec()+30000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await suite.process_frame
	game.pause()
	suite.check(game.dimension == "nether" and game.world.dimension == "nether" and not game.world.intersects(game.player.position),"portal travel streams the Nether and creates a safe arrival")
	var nether_edit := Vector3i(game.player.position.floor())+Vector3i(3,0,0)
	game.world.set_node(nether_edit,Nodes.GOLD_BLOCK)
	game.travel_dimension("overworld")
	deadline = Time.get_ticks_msec()+30000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await suite.process_frame
	game.pause()
	suite.check(game.world.node_at(p) == Nodes.ENCHANTING_TABLE and game.inventory.slots[0] == saved_item,"returning to the Overworld restores edits and keeps enchanted inventory")
	suite.check(game.dimension_states.nether.edits.any(func(entry): return int(entry[3]) == Nodes.GOLD_BLOCK),"Nether edits are stored independently from Overworld edits")
	game.save_game("user://nether_check.json")
	saved = game.read_save("user://nether_check.json")
	suite.check(saved.dimensions.has("overworld") and saved.dimensions.has("nether"),"both dimensions persist in one world save")
	game.load_world_data(saved)
	deadline = Time.get_ticks_msec()+30000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await suite.process_frame
	game.pause()
	suite.check(game.inventory.slots[0] == saved_item and game.inventory.slots[2].data.text == "A saved draft","loading a saved world restores enchanted gear and written text")
	var restored_arrow: bool = false
	for entity in game.entities.get_children():
		if entity is Arrow and entity.stuck and entity.life > 580: restored_arrow = true
	suite.check(restored_arrow,"loading a world restores stuck arrows without resetting their lifetime")
	for kind in ["sheep","cow","pig","chicken","piglin","magma_cube"]:
		var mob: Creature = game.spawn_creature(kind,game.player.position+Vector3(3,0,0))
		mob.set_physics_process(false)
		mob.animate(0.1)
		suite.check(mob.parts.size() >= 10 and (mob.head != null or kind == "magma_cube"),kind+" has a detailed model")
		mob.free()
	suite.check(Creature.KINDS.cow.drops[1][1] >= 1,"cows guarantee at least one leather drop")
	for path in ["user://nether_check.json","user://nether_check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position; game.experience = old_xp; game.gamemode = old_mode
	game.pause()
