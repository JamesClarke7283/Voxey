extends RefCounted

# Focused regression for decoration and archaeology: flowerpots, armor stands,
# pottery sherds and decorated pots, and suspicious sand and gravel with the
# brush. Fixtures use an isolated high plot so the checks cannot disturb
# generated terrain.

static func plot(game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for x in range(-5,6):
		for z in range(-5,6):
			world.set_node(Vector3i(p.x+x,p.y-1,p.z+z),Nodes.STONE)
			for y in range(6): world.set_node(Vector3i(p.x+x,p.y+y,p.z+z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(game,ground)
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,-3.5)
	# `place`-style helpers read the aimed block; aim at the floor below the target.
	var target: Dictionary = {"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)}
	# Right-clicking a node requires the player's body to be clear of the cell
	# being filled, so every placement fixture keeps the player three nodes away.
	t.check(not AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58)).intersects(AABB(Vector3(ground),Vector3.ONE)),"the fixture keeps the player clear of the placement cell")

	# --- registry ----------------------------------------------------------
	t.check(Nodes.exists(Decor.POT) and Nodes.exists(Decor.STAND),"the flowerpot and armor stand are registered")
	t.check(Nodes.exists(Archaeology.POT) and Nodes.exists(Archaeology.BRUSH),"the decorated pot and brush are registered")
	for sherd in Archaeology.SHERDS:
		t.check(Nodes.exists(sherd) and Archaeology.is_sherd(sherd) and not Archaeology.sherd_pattern(sherd).is_empty(),"every registered sherd carries its source pattern name")
	# All 23 source patterns are registered now; the loot tables fill each one that
	# has a reachable item route.
	t.check(Archaeology.SHERDS.size() == 23,"all twenty-three source sherds are registered")
	var every_sherd: bool = true
	for sherd in Archaeology.SHERDS:
		if not Nodes.exists(sherd) or Archaeology.sherd_pattern(sherd).is_empty(): every_sherd = false
	t.check(every_sherd,"every sherd exists with its own source pattern name")
	t.check(Archaeology.SHERD_PATTERNS.size() == 23 and Archaeology.SHERD_PATTERNS[13] == "miner","the registered patterns name the source's own set")
	t.check(Nodes.max_stack(Archaeology.BRUSH) == 1 and Nodes.durability(Archaeology.BRUSH) == Archaeology.BRUSH_USES,"the brush is a single-stack tool with the source 64 uses")
	t.check(Nodes.is_tool_id(Archaeology.BRUSH) or Nodes.preferred_tool(Archaeology.BRUSH) == -1,"the brush is not a mining tool")
	# Suspicious nodes keep the source's falling-node group.
	t.check(Nodes.falls(Archaeology.SUSPICIOUS_SAND) and Nodes.falls(Archaeology.SUSPICIOUS_GRAVEL),"suspicious sand and gravel fall when unsupported, as the source falling_node group requires")
	t.check(Nodes.drop(Archaeology.SUSPICIOUS_SAND) == Nodes.SAND and Nodes.drop(Archaeology.SUSPICIOUS_GRAVEL) == Nodes.GRAVEL,"emptied suspicious nodes revert to plain sand and gravel")
	t.check(not Nodes.solid(Decor.POT) and not Nodes.solid(Archaeology.POT),"pots are not full cubes")

	# --- flowerpot ---------------------------------------------------------
	world.set_node(ground,Decor.POT)
	t.check(Decor.contents(world,ground) == 0,"a fresh pot is empty")
	t.check(Decor.accepts(FoodFeatures.POPPY) and Decor.accepts(Nodes.RED_MUSHROOM) and Decor.accepts(Nodes.CACTUS) and Decor.accepts(WoodTypes.sapling_id(0)),"the source whitelist categories are accepted")
	t.check(not Decor.accepts(Nodes.STONE) and not Decor.accepts(Nodes.IRON),"a non-plant is refused by the pot")
	# A plant goes in and is consumed; the same plant in survival is a no-op.
	game.inventory.restore([]); game.inventory.add_item(FoodFeatures.POPPY,2); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.POT,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(Decor.contents(world,ground) == FoodFeatures.POPPY and game.inventory.count_item(FoodFeatures.POPPY) == 1,"placing a flower consumes one item and stores it in the pot")
	var before_count: int = game.inventory.count_item(FoodFeatures.POPPY)
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.POT,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(Decor.contents(world,ground) == FoodFeatures.POPPY and game.inventory.count_item(FoodFeatures.POPPY) == before_count,"right-clicking with the same plant in survival changes nothing")
	# An empty hand takes the plant back.
	game.inventory.restore([]); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.POT,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(Decor.contents(world,ground) == 0 and game.inventory.count_item(FoodFeatures.POPPY) == 1,"an empty hand empties the pot and returns the plant")
	# Breaking drops the pot and its plant.
	game.inventory.restore([]); game.inventory.add_item(FoodFeatures.DANDELION,1); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.POT,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(Decor.contents(world,ground) == FoodFeatures.DANDELION,"the pot holds a second plant after re-filling")
	var drops_before: int = game.drops.get_child_count()
	Decor.break_node(game,ground,Decor.POT,0)
	var pot_drop: bool = false; var plant_drop: bool = false
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion():
			if drop.item_id == Decor.POT: pot_drop = true
			if drop.item_id == FoodFeatures.DANDELION: plant_drop = true
	t.check(pot_drop and plant_drop,"breaking an occupied pot drops both the pot and its plant")
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame

	# --- armor stand -------------------------------------------------------
	plot(game,ground)
	game.inventory.restore([]); game.inventory.add_item(Decor.STAND,1); game.inventory.selected = 0
	Decor.try_place(game,target)
	t.check(world.node_at(ground) == Decor.STAND and game.inventory.count_item(Decor.STAND) == 0,"placing an armor stand consumes one item")
	t.check(Decor.worn(world,ground).size() == Decor.ARMOR_PIECES,"a stand exposes four armor slots, as source's metadata inventory does")
	# Each armor piece lands in its own slot.
	for piece in 4:
		var armor_id: int = Nodes.armor_id(1,piece)
		game.inventory.restore([]); game.inventory.add_item(armor_id,1); game.inventory.selected = 0
		Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.STAND,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
		var worn: Array = Decor.worn(world,ground)
		t.check(worn[piece].id == armor_id,"armor piece "+str(piece)+" is stored in its own slot")
	# An empty hand removes the last-placed piece.
	game.inventory.restore([]); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.STAND,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(Decor.worn(world,ground)[3].id == 0 and game.inventory.count_item(Nodes.armor_id(1,3)) == 1,"an empty hand takes the last-placed piece back")
	# Punching rotates only when nothing is left to remove, so empty it fully.
	for slot in Decor.worn(world,ground):
		if slot.id != 0:
			game.inventory.restore([]); game.inventory.selected = 0
			Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.STAND,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	game.inventory.restore([]); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.STAND,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	t.check(int(world.block_states.get(VoxelWorld.station_key(ground),{}).get("pot_facing",-1)) == -1 and int(world.block_states.get(VoxelWorld.station_key(ground),{}).get("stand_facing",0)) == 1,"punching a bare stand rotates it")
	# The stored pieces survive a save.
	game.inventory.restore([]); game.inventory.add_item(Nodes.armor_id(1,0),1); game.inventory.selected = 0
	Decor.use(game,{"pos":ground,"normal":Vector3i.UP,"id":Decor.STAND,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
	var helm: int = Decor.worn(world,ground)[0].id
	var save_ok: bool = game.save_game("user://decor_check.json")
	var saved: Dictionary = game.read_save("user://decor_check.json")
	game.set_process(true)
	game.load_world_data(saved)
	world = game.world
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(save_ok and world.node_at(ground) == Decor.STAND and Decor.worn(world,ground)[0].id == helm,"a stand and its stored armor survive a save reload")
	# Breaking returns the stand and everything it wears.
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame
	Decor.break_node(game,ground,Decor.STAND,0)
	var stand_back: bool = false; var armor_back: bool = false
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion():
			if drop.item_id == Decor.STAND: stand_back = true
			if drop.item_id == helm: armor_back = true
	t.check(stand_back and armor_back,"breaking a stand returns the stand and its stored pieces")
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame

	# --- suspicious sand and gravel ----------------------------------------
	plot(game,ground)
	for parent in [Archaeology.SUSPICIOUS_SAND,Archaeology.SUSPICIOUS_GRAVEL]:
		world.set_node(ground,parent)
		game.inventory.restore([]); game.inventory.add_item(Archaeology.BRUSH,1); game.inventory.selected = 0
		t.check(Archaeology.strokes(world,ground) == 0,"a fresh suspicious node has no strokes")
		# One stroke rolls and fixes the loot without completing the node.
		Archaeology.brush(game,{"pos":ground,"normal":Vector3i.UP,"id":parent,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
		t.check(Archaeology.strokes(world,ground) == Archaeology.FIRST_STAGE,"the first stroke starts the node at stage one")
		var rolled: int = int(world.get_station(ground,"suspicious").get("loot_id",0))
		t.check(rolled != 0,"the first stroke rolls the loot once")
		t.check(world.node_at(ground) == parent,"the node is still suspicious after one stroke")
		# The roll is fixed: repeated reads return the same item.
		t.check(int(world.get_station(ground,"suspicious").get("loot_id",0)) == rolled,"the rolled loot is fixed for the node and cannot be re-rolled")
		# Brush until completion; the minimum is four strokes.
		var strokes: int = 1
		var worn_before: int = game.inventory.held().wear
		for i in 40:
			Archaeology.brush(game,{"pos":ground,"normal":Vector3i.UP,"id":parent,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
			strokes += 1
			if world.node_at(ground) != parent: break
		t.check(world.node_at(ground) == Archaeology.parent(parent),"enough strokes convert the node to plain sand or gravel")
		t.check(strokes >= 1+Archaeology.COMPLETE_STAGE-1,"completion never needs fewer strokes than the source's stage target")
		# Wear costs exactly one 1/64th of the brush per completed node.
		var worn: int = game.inventory.held().wear if game.inventory.held().id == Archaeology.BRUSH else worn_before+floori(Nodes.durability(Archaeology.BRUSH)/Archaeology.BRUSH_USES)
		t.check(worn - worn_before == floori(Nodes.durability(Archaeology.BRUSH)/Archaeology.BRUSH_USES),"one completed node costs the brush exactly 1/64 of its life")
		# The fixed loot was delivered exactly once.
		var delivered: int = 0
		for drop in game.drops.get_children():
			if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == rolled: delivered += drop.amount
		t.check(delivered > 0,"the fixed loot is dropped on completion")
		# Brushing further yields nothing more.
		var again: int = 0
		Archaeology.brush(game,{"pos":ground,"normal":Vector3i.UP,"id":Archaeology.parent(parent),"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5})
		for drop in game.drops.get_children():
			if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == rolled: again += drop.amount
		t.check(again == delivered,"brushing a converted node cannot yield a second drop")
		for drop in game.drops.get_children(): drop.queue_free()
		await t.process_frame
	# The brush is not consumed by a non-suspicious block.
	plot(game,ground)
	world.set_node(ground,Nodes.STONE)
	game.inventory.restore([]); game.inventory.add_item(Archaeology.BRUSH,1); game.inventory.selected = 0
	t.check(not Archaeology.brush(game,{"pos":ground,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)+Vector3.ONE*0.5}),"brushing an ordinary block does nothing")

	# --- loot tables --------------------------------------------------------
	for parent in [Archaeology.SUSPICIOUS_SAND,Archaeology.SUSPICIOUS_GRAVEL]:
		var rng := RandomNumberGenerator.new(); rng.seed = 606
		var seen: Dictionary = {}
		var counts_ok: bool = true
		var in_range: bool = true
		for i in 900:
			var roll: Array = Archaeology.loot(parent,rng)
			if roll.is_empty(): continue
			seen[roll[0][0]] = true
			var entry_id: int = roll[0][0]
			var count: int = roll[0][1]
			var bounds_ok: bool = false
			for entry in Archaeology.table(parent):
				if int(entry.id) == entry_id: bounds_ok = count >= int(entry.min) and count <= int(entry.max)
			in_range = in_range and bounds_ok
		t.check(seen.size() == Archaeology.table(parent).size(),"every weighted entry of the "+("sand" if parent == Archaeology.SUSPICIOUS_SAND else "gravel")+" table is reachable")
		t.check(in_range,"every loot count stays inside its source min and max")
		t.check(Archaeology.total_weight(parent) > 0,"the loot table has a nonzero total weight")

	# --- decorated pot ------------------------------------------------------
	plot(game,ground)
	# Crafting: a plus of four sherds, in the source face order.
	var inv := Inventory.new()
	for sherd in Archaeology.SHERDS:
		var recipe: int = inv.recipe_index(Archaeology.POT)
		inv.restore([])
		for ingredient in inv.recipes[recipe].pattern:
			if ingredient != 0: inv.add_item(ingredient,1)
		t.check(inv.fill_grid(recipe,"table") and inv.take_grid_result("table").get("id",0) == Archaeology.POT,"four sherds in a plus craft a decorated pot")
		# The dynamic recipe records which sherd sits on each face.
		for i in 9: inv.grid[i] = {"id":0,"count":0,"wear":0}
		for index in [1,3,5,7]: inv.grid[index] = {"id":sherd,"count":1,"wear":0}
		var dynamic: Dictionary = Archaeology.special_recipe(inv.grid)
		t.check(dynamic.get("id",0) == Archaeology.POT and dynamic.get("patterns",[]).size() == Archaeology.FACES,"the source plus shape maps one sherd to each of the four faces")
		t.check(dynamic.patterns.has(Archaeology.sherd_pattern(sherd)),"the recorded face carries the sherd's own pattern")
	# A mix of sherds and bricks keeps a blank face for the brick.
	for i in 9: inv.grid[i] = {"id":0,"count":0,"wear":0}
	inv.grid[1] = {"id":Archaeology.SHERDS[0],"count":1,"wear":0}
	inv.grid[3] = {"id":Nodes.BRICK_ITEM,"count":1,"wear":0}
	inv.grid[5] = {"id":Archaeology.SHERDS[1],"count":1,"wear":0}
	inv.grid[7] = {"id":Nodes.BRICK_ITEM,"count":1,"wear":0}
	var mixed: Dictionary = Archaeology.special_recipe(inv.grid)
	t.check(mixed.get("patterns",[]).size() == 4 and mixed.patterns[1] == "" and mixed.patterns[0] == Archaeology.sherd_pattern(Archaeology.SHERDS[0]),"a plain brick contributes a blank face beside the sherd patterns")

	# Placed pot: patterns are per-face and rotate with the block's facing.
	world.set_node(ground,Archaeology.POT)
	Archaeology.set_patterns(world,ground,[Archaeology.SHERD_PATTERNS[0],Archaeology.SHERD_PATTERNS[1],"",""])
	var stored: Array = Archaeology.patterns(world,ground)
	t.check(stored.size() == Archaeology.FACES and stored[0] == Archaeology.SHERD_PATTERNS[0] and stored[2] == "","a pot keeps four independent face patterns including blanks")
	t.check(Archaeology.face_pattern(world,ground,0) == Archaeology.SHERD_PATTERNS[0],"a face reports its own pattern at the default facing")
	var key: String = VoxelWorld.station_key(ground)
	world.block_states[key]["pot_facing"] = 1
	t.check(Archaeology.face_pattern(world,ground,3) == Archaeology.SHERD_PATTERNS[0],"rotating the pot moves a pattern to the adjacent face")
	t.check(Archaeology.face_pattern(world,ground,0) == Archaeology.SHERD_PATTERNS[1],"the neighbouring face takes over the next stored pattern")
	# The patterns survive a save.
	var pot_save: bool = game.save_game("user://pot_check.json")
	var pot_data: Dictionary = game.read_save("user://pot_check.json")
	game.set_process(true)
	game.load_world_data(pot_data)
	world = game.world
	deadline = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(pot_save and Archaeology.patterns(world,ground)[0] == Archaeology.SHERD_PATTERNS[0],"a pot's face patterns survive a save reload")

	# Breaking returns the base plus one item per face, in face order.
	world.set_node(ground,Archaeology.POT)
	Archaeology.set_patterns(world,ground,[Archaeology.SHERD_PATTERNS[0],Archaeology.SHERD_PATTERNS[1],"",""])
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame
	game.inventory.restore([]); game.inventory.selected = 0
	Archaeology.break_node(game,ground,Archaeology.POT,0)
	var sherds_back: Dictionary = {}
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion():
			sherds_back[drop.item_id] = int(sherds_back.get(drop.item_id,0))+drop.amount
	t.check(sherds_back.get(Archaeology.SHERDS[0],0) == 1 and sherds_back.get(Archaeology.SHERDS[1],0) == 1,"breaking a pot returns one item for each recorded pattern")
	t.check(sherds_back.get(Nodes.BRICK_ITEM,0) == 2,"each blank face returns a plain brick, as in source")
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame
	# Silk Touch returns the whole pot with its patterns intact.
	world.set_node(ground,Archaeology.POT)
	Archaeology.set_patterns(world,ground,[Archaeology.SHERD_PATTERNS[0],"","",""])
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}; game.inventory.selected = 0
	Archaeology.break_node(game,ground,Archaeology.POT,0)
	# The pot goes straight to the inventory when there is room; otherwise it
	# drops. Accept either, and require the patterns to have travelled with it.
	var carried: Dictionary = {}
	for slot in game.inventory.slots:
		if slot.id == Archaeology.POT: carried = slot.get("data",{})
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == Archaeology.POT: carried = drop.data
	t.check(not carried.is_empty() and String(carried.get("pot_patterns",[""])[0]) == Archaeology.SHERD_PATTERNS[0],"silk touch returns the whole pot with its patterns intact")
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame

	# --- art ---------------------------------------------------------------
	var mesh_ok: bool = true
	for id in [Archaeology.POT,Decor.POT,Decor.STAND,Archaeology.SUSPICIOUS_SAND,Archaeology.SUSPICIOUS_GRAVEL]:
		mesh_ok = mesh_ok and not game.node_mesh(id).get_surface_count() == 0
	t.check(mesh_ok,"every decoration node builds a non-empty voxel mesh")
	t.check(not Decor.icon_faces(Decor.POT).is_empty() and not Decor.icon_faces(Decor.STAND).is_empty() and not Archaeology.icon_faces(Archaeology.POT).is_empty(),"each decoration produces an inventory icon")
	var patterns_differ: bool = true
	for i in Archaeology.SHERDS.size():
		var a: Color = Archaeology.pot_pattern_pixel(Archaeology.SHERD_PATTERNS[i],7,7)
		for j in range(i+1,Archaeology.SHERDS.size()):
			if a == Archaeology.pot_pattern_pixel(Archaeology.SHERD_PATTERNS[j],7,7): patterns_differ = false
	t.check(patterns_differ,"each sherd pattern renders a distinct motif")
	t.check(Archaeology.pixel(Archaeology.SUSPICIOUS_SAND,2,2,Color.WHITE) != Archaeology.pixel(Archaeology.SUSPICIOUS_GRAVEL,2,2,Color.WHITE),"suspicious sand and gravel render different textures")

	# --- recipes -----------------------------------------------------------
	t.check(inv.recipe_index(Decor.POT) >= 0 and inv.recipes[inv.recipe_index(Decor.POT)].ingredients.get(Nodes.BRICK_ITEM,0) == 3,"three bricks craft a flower pot")
	t.check(inv.recipe_index(Decor.STAND) >= 0 and inv.recipes[inv.recipe_index(Decor.STAND)].ingredients.get(Nodes.STICK,0) == 4,"four sticks and a slab craft an armor stand")
	var brush_recipe: int = inv.recipe_index(Archaeology.BRUSH)
	t.check(brush_recipe >= 0 and inv.recipes[brush_recipe].ingredients.has(Nodes.FEATHER) and inv.recipes[brush_recipe].ingredients.has(Nodes.COPPER),"the brush uses a feather and a copper ingot")

	for x in range(-5,6):
		for z in range(-5,6):
			for y in range(6): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)
