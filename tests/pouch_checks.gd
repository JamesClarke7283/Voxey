extends RefCounted

static func item(id: int, count: int = 1, data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id":id,"count":count,"wear":0}
	if not data.is_empty(): result.data = data.duplicate(true)
	return result

static func run(suite: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	var all_ids: bool = true
	for level in range(1,6):
		for color in 16:
			var id: int = Pouches.SINGLE+(level-1)*16+color
			all_ids = all_ids and Nodes.exists(id) and Pouches.size_of(id) == 27*level and Nodes.max_stack(id) == 1
	suite.check(all_ids,"all eighty colored pouch variants have five levels and the expected capacities")
	var previous_pixels: int = 0; var growing_art: bool = true
	for level in range(1,6):
		var sprite: Image = ItemArt.texture(Pouches.SINGLE+(level-1)*16+6).get_image()
		var pixels: int = 0
		for y in 16:
			for x in 16:
				if sprite.get_pixel(x,y).a > 0: pixels += 1
		growing_art = growing_art and pixels > previous_pixels
		previous_pixels = pixels
	suite.check(growing_art,"each successive pouch texture has a larger visible silhouette")
	var basic: int = -1
	var base_recipe_count: int = 0; var costly_recipe: bool = false
	for i in inv.recipes.size():
		var recipe: Dictionary = inv.recipes[i]
		if recipe.id == Pouches.SINGLE and recipe.ingredients == {Nodes.STRING:4}: basic = i
		if Pouches.level_of(recipe.id) == 1:
			var uses_pouch: bool = false
			for ingredient in recipe.ingredients:
				if Pouches.is_pouch(ingredient): uses_pouch = true
				if ingredient == Nodes.CHEST or ingredient == Nodes.WOOL or ingredient in range(VillageContent.WOOL_WHITE,VillageContent.WOOL_BROWN+1): costly_recipe = true
			if not uses_pouch: base_recipe_count += 1
	inv.add_item(Nodes.STRING,4)
	suite.check(basic >= 0 and inv.craft(basic,"hand") and inv.count_item(Pouches.SINGLE) == 1 and inv.count_item(Nodes.STRING) == 0,"four string alone hand-craft a level-one white pouch")
	suite.check(base_recipe_count == 1 and not costly_recipe,"only one base pouch recipe remains and no level-one guide recipe charges wool or a chest")
	inv = Inventory.new()
	for index in [0,1,3,4]: inv.grid[index] = item(Nodes.STRING)
	var handmade: Dictionary = inv.take_grid_result("hand")
	suite.check(handmade.get("id",0) == Pouches.SINGLE and handmade.count == 1 and inv.grid[0].id == 0 and inv.grid[4].id == 0,"the actual two-by-two string grid produces a pouch instead of the former wool recipe")
	inv = Inventory.new(); inv.add_item(Nodes.STRING,8)
	suite.check(inv.fill_grid(inv.recipe_index(Pouches.SINGLE),"hand",true) and inv.grid[0].count == 2 and inv.grid[4].count == 2 and inv.craft_grid_to_inventory("hand") and inv.craft_grid_to_inventory("hand") and inv.count_item(Pouches.SINGLE) == 2 and inv.count_item(Nodes.STRING) == 0,"recipe-guide batch filling spends exactly eight string for two pouches")
	for color in 16:
		var wool: int = Nodes.WOOL if color == 0 else VillageContent.WOOL_WHITE+color
		inv = Inventory.new(); inv.grid[4] = item(wool,2)
		var strings: Dictionary = inv.take_grid_result("hand")
		suite.check(strings.get("id",0) == Nodes.STRING and strings.count == 4 and inv.grid[4].count == 1,"hand crafting one %s produces four string and retains the second wool"%Nodes.title(wool).to_lower())
		var wool_recipe: int = -1
		for i in inv.recipes.size():
			if inv.recipes[i].id == Nodes.STRING and inv.recipes[i].ingredients == {wool:1}: wool_recipe = i
		inv = Inventory.new(); inv.add_item(wool)
		suite.check(wool_recipe >= 0 and inv.fill_grid(wool_recipe,"hand") and inv.craft_grid_to_inventory("hand") and inv.count_item(Nodes.STRING) == 4 and inv.count_item(wool) == 0,"recipe-guide filling also unpacks %s into four string"%Nodes.title(wool).to_lower())
	inv = Inventory.new(); inv.grid[0] = item(VillageContent.WOOL_WHITE)
	suite.check(inv.take_grid_result("hand").get("count",0) == 4,"the legacy white-wool identifier uses the same four-string conversion")
	# Exercise the real guide controls, not only the recipe registration helper.
	game.hud.return_cursor(); game.inventory = Inventory.new(); game.inventory.changed.connect(game.hud.refresh_slots)
	game.inventory.add_item(Nodes.STRING,4); game.open_inventory("hand")
	game.hud._select_recipe(game.inventory.recipe_index(Pouches.SINGLE)); game.hud._fill_grid()
	suite.check(game.hud.output_icon.item_id == Pouches.SINGLE and game.inventory.grid[0].id == Nodes.STRING and game.inventory.grid[4].id == Nodes.STRING,"the hand-crafting guide displays and fills the requested two-by-two pouch recipe")
	game.hud._take_output()
	suite.check(game.hud.cursor.id == Pouches.SINGLE and game.inventory.count_item(Nodes.STRING) == 0,"taking the guide output yields exactly one pouch on the cursor")
	game.hud.return_cursor(); game.pause()
	var cargo_book: Dictionary = item(Nodes.WRITTEN_BOOK,1,{"title":"Travels","text":"Across every dimension"})
	var cargo_bow: Dictionary = item(Nodes.BOW,1,{"enchantments":{"Power":5}}); cargo_bow.wear = 13
	for level in range(1,5):
		inv = Inventory.new()
		var a: Dictionary = item(Pouches.SINGLE+(level-1)*16+6)
		var b: Dictionary = item(Pouches.SINGLE+(level-1)*16+9)
		Pouches.contents(a)[0] = cargo_book.duplicate(true)
		Pouches.contents(b)[0] = cargo_bow.duplicate(true)
		inv.grid[0] = a; inv.grid[4] = b
		var expected_id: int = a.id+16
		var result: Dictionary = inv.take_grid_result("hand")
		suite.check(not result.is_empty() and result.id == expected_id and result.data.contents.has(cargo_book) and result.data.contents.has(cargo_bow),"level %d upgrade accepts two colors and retains cargo from both pouches"%(level+1))
		# The consumed dictionaries are empty; check their grid slots too.
		suite.check(inv.grid[0].id == 0 and inv.grid[4].id == 0,"level %d upgrade consumes exactly two pouches"%(level+1))
	inv = Inventory.new(); inv.grid[0] = item(Pouches.SINGLE+64); inv.grid[1] = item(Pouches.SINGLE+64)
	suite.check(inv.take_grid_result("hand").is_empty() and inv.grid[0].id != 0,"level five cannot be upgraded or consumed by another combination")
	inv.grid[1] = item(Pouches.SINGLE+48)
	suite.check(inv.take_grid_result("hand").is_empty(),"upgrading rejects mismatched levels")
	for i in 2:
		inv.grid[i] = item(Pouches.DOUBLE)
		for j in 54: Pouches.contents(inv.grid[i])[j] = cargo_bow.duplicate(true)
	var before: Array = inv.grid.duplicate(true)
	suite.check(inv.take_grid_result("hand").is_empty() and inv.grid == before,"an overflowing upgrade consumes neither pouch nor any cargo")
	for i in 2:
		inv.grid[i] = item(Pouches.DOUBLE)
		for j in 54: Pouches.contents(inv.grid[i])[j] = item(Nodes.DIAMOND,1)
	var merged: Dictionary = inv.take_grid_result("hand")
	var total: int = 0
	for cargo in merged.data.contents: total += cargo.count
	suite.check(total == 108 and merged.data.contents.size() == 81,"upgrade merges compatible stacks so both inventories can fit")
	inv = Inventory.new()
	for i in 3:
		inv.slots[i] = item(Pouches.SINGLE)
		Pouches.contents(inv.slots[i])[0] = item(Nodes.DIAMOND,i+1)
	suite.check(inv.craft(inv.recipe_index(Pouches.DOUBLE),"hand") and inv.slots[2].data.contents[0].count == 3,"recipe-guide combining consumes two matching pouches and leaves a third untouched")
	var result_cargo: int = 0
	for slot in inv.slots:
		if slot.id == Pouches.DOUBLE:
			for cargo in Pouches.contents(slot): result_cargo += cargo.count
	suite.check(result_cargo == 3,"recipe-guide output contains only the two consumed pouches' cargo")
	inv.grid[0] = item(Pouches.SINGLE+64); Pouches.contents(inv.grid[0])[134] = cargo_book.duplicate(true)
	inv.grid[1] = item(VillageContent.WOOL_RED)
	var red: Dictionary = inv.take_grid_result("hand")
	suite.check(red.id == Pouches.SINGLE+64+6 and red.data.contents[134] == cargo_book,"dyed wool recolors a level-five pouch without moving its last-slot cargo")
	inv = Inventory.new()
	inv.slots[0] = red.duplicate(true)
	suite.check(inv.slots.size() == 36 and inv.page_count() == 1,"a carried level-five pouch adds no inventory pages")
	inv.slots[0] = item(0,0)
	inv.exchange_pouch(0,red)
	suite.check(inv.slots.size() == 171 and inv.page_count() == 6 and inv.slots[170] == cargo_book,"equipping a pouch adds its pages and exposes its existing contents")
	inv.slots[170] = cargo_bow.duplicate(true); inv.changed.emit()
	suite.check(Pouches.contents(inv.pouch_slots[0])[134] == cargo_bow,"replacing a paged inventory slot updates its pouch metadata")
	var taken: Dictionary = inv.exchange_pouch(0,item(0,0))
	suite.check(inv.slots.size() == 36 and taken.data.contents[134] == cargo_bow,"unequipping removes pages and carries every stored item with the pouch")
	for i in 3: inv.exchange_pouch(i,item(Pouches.SINGLE+64+i))
	var rejected: Dictionary = item(Pouches.SINGLE)
	suite.check(inv.exchange_pouch(3,rejected) == rejected and inv.pouch_slots.size() == 3 and inv.slots.size() == 441 and inv.page_count() == 16,"three level-five pouches are the maximum equipment capacity")
	var mapping: Array = inv.page_indices(15)
	suite.check(mapping.slice(0,9) == range(9) and mapping[9] == 414 and mapping[35] == 440,"the last page retains the hotbar and maps to the correct cargo slots")
	for i in 36: inv.slots[i] = item(Nodes.COBBLE,64)
	suite.check(inv.capacity(Pouches.SINGLE) == 0 and inv.add_item(Pouches.SINGLE) == 1,"automatic pickup cannot nest a pouch in extended inventory slots")
	suite.check(inv.add_item(Nodes.DIAMOND,64) == 0 and inv.slots[36].id == Nodes.DIAMOND,"ordinary pickups use equipped pouch capacity when the backpack is full")
	inv.slots = inv.slots.duplicate(true); inv.slots[440] = cargo_book.duplicate(true); inv.changed.emit()
	suite.check(inv.pouch_slots[2].data.contents[134] == cargo_book,"inventory transactions which replace the flat array preserve equipped cargo")
	var restored := Inventory.new()
	restored.restore(JSON.parse_string(JSON.stringify(inv.slots.slice(0,36))),JSON.parse_string(JSON.stringify(inv.pouch_slots)))
	suite.check(restored.slots == inv.slots and restored.pouch_slots == inv.pouch_slots,"JSON loading restores all equipped levels, colors and cargo without duplication")
	restored.restore([cargo_book])
	suite.check(restored.slots.size() == 36 and restored.pouch_slots[0].id == 0 and restored.slots[1].id == 0,"legacy saves restore a plain backpack without retaining previous equipment")

	# Exercise actual storage controls, including two views onto equipped cargo.
	game.hud.return_cursor(); game.inventory = Inventory.new(); game.inventory.changed.connect(game.hud.refresh_slots)
	game.inventory.slots[0] = red.duplicate(true)
	game.open_inventory(); game.survival.open_pouch(0)
	suite.check(game.inventory.page_count() == 1 and game.hud.station_ui.size() == 27,"opening a carried pouch shows its own storage without expanding the backpack")
	game.hud._change_container_page(4)
	suite.check(game.hud.station_indices[26] == 134,"the portable pouch's last page maps to its final cargo slot")
	game.hud._slot_click(game.hud.station_indices[26],true,false)
	suite.check(game.hud.cursor == cargo_book and game.inventory.slots[0].data.contents[134].id == 0,"items can be taken from a carried pouch's last page")
	game.hud._slot_click(134,true,false); game.hud._close_pouch_view()
	game.hud._slot_click(0,false,false); game.hud._pouch_click(0,false)
	suite.check(game.inventory.pouch_slots[0].id == red.id and game.hud.pouch_ui.size() == 3 and game.inventory.page_count() == 6,"the equipment UI equips a carried pouch into one of three dedicated slots")
	game.hud.cursor = item(Nodes.DIAMOND,3); game.hud._change_inventory_page(5)
	suite.check(game.hud.cursor.count == 3 and game.hud.inventory_indices[35] == 170,"changing inventory pages preserves the cursor stack and correct slot mapping")
	game.hud._slot_click(169,false,false)
	suite.check(game.inventory.pouch_slots[0].data.contents[133].count == 3,"placing on a later inventory page writes into the equipped pouch")
	game.hud.cursor = item(Pouches.SINGLE); game.hud._slot_click(168,false,false)
	suite.check(game.hud.cursor.id == Pouches.SINGLE and game.inventory.slots[168].id == 0,"manual placement cannot nest pouches through a paginated slot")
	game.hud.return_cursor(); game.hud._pouch_click(0,true)
	game.hud._change_container_page(4)
	game.hud.shift_mode = true; game.hud._slot_click(133,true,false); game.hud.shift_mode = false
	suite.check(game.inventory.count_item(Nodes.DIAMOND) == 3 and game.inventory.slots[169].id == 0,"shift transfer from an equipped pouch avoids adding the item back into itself")
	game.hud.cursor = item(Nodes.DIAMOND,2); game.hud._slot_click(133,true,false)
	suite.check(game.inventory.slots[169].count == 2,"editing an equipped pouch view updates the matching inventory page immediately")
	game.hud._pouch_click(0,false)
	suite.check(game.hud.cursor.id == 0 and game.inventory.pouch_slots[0].id != 0,"the inspected pouch remains equipped until its view is closed")
	game.hud._close_pouch_view()
	game.hud._pouch_click(0,false)
	suite.check(game.inventory.page_count() == 1 and game.hud.inventory_page == 0 and game.hud.cursor.data.contents[133].count == 2,"unequipping from the last page clamps pagination and preserves cargo on the cursor")
	var dropped_pouch: Dictionary = game.hud.cursor.duplicate(true)
	var motion := InputEventMouseMotion.new(); motion.position = Vector2.ZERO
	suite.root.push_input(motion,true)
	var escape_key := InputEventKey.new(); escape_key.physical_keycode = KEY_ESCAPE; escape_key.pressed = true
	game._input(escape_key)
	var exact_drop: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == dropped_pouch.id and drop.data == dropped_pouch.data: exact_drop = true
	suite.check(exact_drop and game.hud.cursor.id == 0 and game.inventory.page_count() == 1,"dragging a filled pouch outside and pressing Escape drops it with its exact contents")
	game.open_inventory(); game.hud.cursor = dropped_pouch
	game.hud._pouch_click(2,false)
	game.hud.return_cursor(); game.pause()
	game.save_game("user://pouch_equipment_reload.json")
	var save: Dictionary = game.read_save("user://pouch_equipment_reload.json")
	suite.check(save.inventory.size() == 36 and save.pouches.size() == 3 and save.pouches[2].id == red.id,"world saves store cargo once inside three equipment slots")
	game.load_world_data(save)
	while game.state == "loading": await suite.process_frame
	game.pause()
	suite.check(game.inventory.slots.size() == 171 and game.inventory.slots[169].count == 2 and game.inventory.slots[170] == cargo_book,"real world reload restores equipped inventory pages and exact contents")
	for path in ["user://pouch_equipment_reload.json","user://pouch_equipment_reload.json.bak","user://pouch_equipment_reload.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	for drop in game.drops.get_children(): drop.free()
	game.gamemode = "survival"; game.die()
	var point: Array = game.world.adventure_state.last_recovery.position
	var chest_pos := Vector3i(point[0],point[1],point[2])
	var chest: Dictionary = game.world.get_station(chest_pos,"chest")
	var pouch_entries: int = 0; var loose_cargo: int = 0; var bones: int = 0
	for slot in chest.slots:
		if slot.id == red.id and slot.data.contents[134] == cargo_book and slot.data.contents[133].count == 2: pouch_entries += 1
		if slot.id == Nodes.WRITTEN_BOOK: loose_cargo += 1
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.BONE: bones += drop.amount
	suite.check(game.world.node_at(chest_pos) == VillageContent.RECOVERY_CHEST and pouch_entries == 1 and loose_cargo == 0 and game.inventory.slots.size() == 36,"death places the equipped pouch in a recovery chest with page contents packed inside exactly once")
	suite.check(bones == 2 and game.drops.get_child_count() == 1,"death leaves bones as the only loose drop")
	var original_chest: Dictionary = chest.duplicate(true)
	game.inventory = Inventory.new()
	for i in 36: game.inventory.slots[i] = item(Nodes.COBBLE,64)
	game.inventory.slots[0] = item(Pouches.SINGLE+9)
	Pouches.contents(game.inventory.slots[0])[26] = cargo_book.duplicate(true)
	for i in 3:
		var pouch: Dictionary = item(Pouches.SINGLE+64+i)
		Pouches.contents(pouch)[134] = cargo_bow.duplicate(true)
		game.inventory.exchange_pouch(i,pouch)
	for i in 4: game.player.armor_slots[i] = item(Nodes.armor_id(3,i))
	for i in 9: game.inventory.grid[i] = item(Nodes.DIAMOND,64)
	# The second hand is part of the carried loadout, so it must also be recovered.
	game.player.offhand_slot = item(VillageContent.SHIELD,1)
	game.hud.cursor = item(Nodes.GOLD,64)
	game.state = "paused"; game.die()
	point = game.world.adventure_state.last_recovery.position
	var full_chest_pos := Vector3i(point[0],point[1],point[2])
	var full_chest: Dictionary = game.world.get_station(full_chest_pos,"chest")
	var occupied: int = 0
	for slot in full_chest.slots:
		if slot.id != 0: occupied += 1
	suite.check(full_chest_pos != chest_pos and game.world.get_station(chest_pos,"chest") == original_chest,"another death nearby cannot overwrite a previous recovery chest")
	suite.check(occupied == 54 and full_chest.slots[53].id == Nodes.GOLD and full_chest.slots[43].id == VillageContent.SHIELD,"a completely full backpack, pouch equipment, armor, second hand, grid and cursor all fit in one recovery chest")
	suite.check(full_chest.slots[0].data.contents[26] == cargo_book,"a pouch carried in the main backpack also keeps its contents inside the recovery chest")
	suite.check(full_chest.slots[36].data.contents[134] == cargo_bow and full_chest.slots[38].data.contents[134] == cargo_bow,"all three full-sized pouches retain their last pages in the recovery chest")
	suite.check(game.hud.cursor.id == 0 and game.inventory.grid[0].id == 0 and game.player.armor_slots[0].id == 0 and game.inventory.pouch_slots[0].id == 0,"death clears every carried and equipped source after saving it in the chest")
	var snapshot: Dictionary = game.dimension_snapshot()
	suite.check(snapshot.stations.has(VoxelWorld.station_key(full_chest_pos)) and snapshot.stations[VoxelWorld.station_key(full_chest_pos)].slots[36].data.contents[134] == cargo_bow,"recovery chests and their pouch metadata are included in dimension persistence")
	game.save_game("user://recovery_chest_reload.json")
	var recovery_save: Dictionary = game.read_save("user://recovery_chest_reload.json")
	game.load_world_data(recovery_save)
	while game.state == "loading": await suite.process_frame
	game.pause()
	var reloaded_chest: Dictionary = game.world.get_station(full_chest_pos,"chest")
	suite.check(game.world.node_at(full_chest_pos) == VillageContent.RECOVERY_CHEST and reloaded_chest.slots == full_chest.slots,"recovery chest and every stored item survive a real world reload")
	game.open_inventory("chest",full_chest_pos)
	suite.check(game.hud.station_ui.size() == 54 and game.hud.station_data.slots[36].data.contents[134] == cargo_bow,"recovery chest opens all fifty-four slots for retrieving intact pouches")
	game.hud._slot_click(36,true,false); game.hud._slot_click(0,false,false)
	suite.check(game.inventory.slots[0].data.contents[134] == cargo_bow and reloaded_chest.slots[36].id == 0,"a pouch retrieved from the death chest retains its cargo")
	game.hud.return_cursor(); game.pause()
	game.inventory.selected = 0
	suite.check(game.survival.use() and game.hud.station_data.get("kind","") == "pouch" and game.hud.station_data.slots[134] == cargo_bow,"using a held pouch opens its recovered contents for interaction")
	game.hud.return_cursor(); game.pause()
	game.break_node(full_chest_pos,VillageContent.RECOVERY_CHEST,0)
	suite.check(not game.world.stations.has(VoxelWorld.station_key(full_chest_pos)),"breaking a recovery chest detaches its saved storage")
	var intact_dropped: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == Pouches.SINGLE+65 and drop.data.contents[134] == cargo_bow: intact_dropped = true
	suite.check(intact_dropped,"breaking the recovery chest drops each remaining pouch with its cargo intact")
	for path in ["user://recovery_chest_reload.json","user://recovery_chest_reload.json.bak","user://recovery_chest_reload.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# The End rebuilds its arrival platform: it must leave death chests intact.
	game.gamemode = "creative"; game.player.health = 20
	game.travel_dimension("end")
	while game.state == "loading": await suite.process_frame
	game.pause(); game.inventory = Inventory.new()
	game.inventory.slots[0] = item(Nodes.DIAMOND,17)
	game.die()
	var end_point: Array = game.world.adventure_state.last_recovery.position
	var end_chest := Vector3i(end_point[0],end_point[1],end_point[2])
	game.respawn()
	while game.state == "loading": await suite.process_frame
	game.pause(); game.travel_dimension("end")
	while game.state == "loading": await suite.process_frame
	game.pause()
	suite.check(game.world.node_at(end_chest) == VillageContent.RECOVERY_CHEST and game.world.get_station(end_chest,"chest").slots[0].count == 17,"returning to the End preserves the recovery chest on its rebuilt arrival platform")
	suite.check(not game.world.intersects(game.player.position),"returning to a chest on the End platform places the player in free space")
	game.player.position.y = -40; game.inventory.slots[0] = item(Nodes.DIAMOND,3)
	game.die()
	var void_point: Array = game.world.adventure_state.last_recovery.position
	suite.check(void_point[1] > game.world.generator.min_y() and game.world.node_at(Vector3i(void_point[0],void_point[1],void_point[2])) == VillageContent.RECOVERY_CHEST,"falling into the End void creates a recovery chest inside the world bounds")
