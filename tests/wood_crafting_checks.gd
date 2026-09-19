extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	inv.restore([{"id":VillageContent.CAKE,"count":64,"wear":0}])
	t.check(inv.capacity(VillageContent.CAKE) == inv.slots.size()-1,"grandfathered cake stacks do not subtract capacity from other empty slots")
	inv.restore([])
	for species in 6:
		var planks: int = WoodTypes.PLANKS[species]
		var fence: int = Barriers.FENCE_BASES[0 if species == 0 else species+1]
		var trap: int = Trapdoors.ITEMS[0 if species == 0 else species+1]
		var door: int = Doors.ITEMS[0 if species == 0 else species+1]
		var door_mesh: ArrayMesh = Art.build_node_mesh(door)
		t.check(door_mesh.get_surface_count() == 1 and is_equal_approx(door_mesh.get_aabb().size.y,1) and door_mesh.get_aabb().size.z < 0.2 and door_mesh.surface_get_array_len(0) > 24,"held and dropped door renders both thin halves instead of a plank cube: "+str(species))
		var products: Array = [[BuildingShapes.slab_for(planks),6,3],[BuildingShapes.stair_for(planks),4,6],[fence,3,4],[fence+1,1,2],[trap,2,6],[door,3,6],[Boats.ORDINARY[species],1,5]]
		for product in products:
			var index: int = inv.recipe_index(product[0])
			t.check(index >= 0 and Nodes.exists(product[0]) and Nodes.all_ids().has(product[0]),"wood family product is registered and craftable: "+str(product[0]))
			if index < 0: continue
			var recipe: Dictionary = inv.recipes[index]
			t.check(recipe.count == product[1] and recipe.ingredients.get(planks,0) == product[2] and not recipe.wood_group,"named wood products preserve their exact material: "+str(product[0]))
			inv.restore([]); inv.add_item(planks,16); inv.add_item(Nodes.STICK,8)
			t.check(inv.fill_grid(index,"table") and inv.take_grid_result("table").get("id") == product[0],"recipe guide consumes the matching wood for "+str(product[0]))
		t.check(BuildingShapes.stonecutter_inputs(planks).is_empty() and Nodes.fuel_time(BuildingShapes.slab_for(planks)) == 7.5 and Nodes.fuel_time(trap) == 15 and Nodes.fuel_time(door) == 10,"all wood families retain source fuel and exclude stonecutting: "+str(species))
		t.check(Barriers.connects(fence,5000) and Barriers.connects(5000,fence+1) and not Barriers.connects(fence,5016),"different wood fences connect through the common wood group: "+str(species))
		for turn in 4:
			var gate: int = fence+5+turn; var state: int = Trapdoors.state_id(trap,turn,true,true)
			t.check(Nodes.exists(gate) and Barriers.item(gate) == fence+1 and Barriers.facing(gate) == turn and Nodes.exists(state) and Trapdoors.item(state) == trap and Trapdoors.upper(state) and Trapdoors.open(state),"new wood state ranges stay separate from walls and old trapdoors: %d/%d"%[species,turn])
		var chest: int = Boats.CHESTS[species]
		inv.restore([]); inv.add_item(Nodes.CHEST); inv.add_item(Boats.ORDINARY[species])
		t.check(Boats.is_boat(chest) and Nodes.max_stack(chest) == 1 and inv.fill_grid(inv.recipe_index(chest),"hand") and inv.take_grid_result("hand").get("id") == chest,"each renewable species has its matching chest boat: "+str(species))
	# Actual manual-grid and guide transactions must both use source wood groups.
	inv.restore([])
	for i in 4: inv.grid[[0,1,3,4][i]] = {"id":WoodTypes.PLANKS[i+1],"count":1,"wear":0}
	t.check(inv.take_grid_result("hand").get("id") == Nodes.WORKBENCH,"four mixed species craft one workbench in the ordinary 2x2 grid")
	inv.restore([])
	for id in WoodTypes.PLANKS.slice(1,5): inv.add_item(id)
	t.check(inv.can_craft(inv.recipes[inv.recipe_index(Nodes.WORKBENCH)],"hand") and inv.craft(inv.recipe_index(Nodes.WORKBENCH),"hand") and inv.count_item(Nodes.WORKBENCH) == 1,"direct crafting consumes actual mixed species without creating oak planks")
	for id in WoodTypes.PLANKS: t.check(inv.count_item(id) == 0,"mixed workbench consumed its required plank: "+str(id))
	inv.restore([]); inv.add_item(6035,3); inv.add_item(6067,3)
	t.check(inv.fill_grid(inv.recipe_index(Nodes.STICK),"hand",true),"shift guide finds a homogeneous stack for each mixed wood cell")
	t.check(inv.grid[0].id != inv.grid[3].id and inv.grid[0].count == 3 and inv.grid[3].count == 3,"shift guide retains two actual plank species across the largest feasible batch")
	for i in 3: t.check(inv.take_grid_result("hand").get("id") == Nodes.STICK,"mixed guide batch remains a valid source stick recipe: "+str(i))
	inv.restore([]); inv.add_item(6035,4); inv.add_item(6067,2)
	t.check(inv.fill_grid(inv.recipe_index(Nodes.STICK),"hand",true) and inv.grid[0].count == 2 and inv.grid[3].count == 2,"shift guide reduces a batch when a cell cannot mix species")
	inv.restore([]); inv.add_item(6035,8,0,{"custom_name":"Building supply"})
	t.check(inv.fill_grid(inv.recipe_index(Nodes.CHEST),"table") and inv.grid[0].get("data",{}).get("custom_name") == "Building supply","guide retains ingredient metadata while filling generic wood recipes")
	t.check(inv.take_grid_result("table").get("id") == Nodes.CHEST,"named non-oak planks still craft an ordinary chest")
	inv.restore([]); inv.add_item(6035,64)
	t.check(not inv.can_craft(inv.recipes[inv.recipe_index(VillageContent.WOODEN_DOOR)],"table"),"spruce cannot silently become an oak door through generic wood matching")
	var before: Array = inv.slots.duplicate(true)
	t.check(not inv.fill_grid(inv.recipe_index(VillageContent.WOODEN_DOOR),"table") and inv.slots == before,"failed material-specific guide fill is transactional")
	inv.restore([])
	for i in 6: inv.grid[i] = {"id":WoodTypes.PLANKS[i],"count":1,"wear":0}
	t.check(inv.matching_recipe("table") < 0,"mixed species cannot craft a material-specific trapdoor")
	for entry in [[VillageContent.SMOKER,[[6032,1],[6068,1],[6097+4,1],[Nodes.CRIMSON_STEM,1],[Nodes.FURNACE,1]]],[Campfires.LIT,[[Nodes.STICK,3],[Nodes.COAL,1],[6032,1],[6068,1],[Nodes.WARPED_STEM,1]]],[RedstoneSensors.DAYLIGHT,[[Nodes.GLASS,3],[Nodes.QUARTZ,3],[BuildingShapes.slab_for(6035),1],[BuildingShapes.slab_for(6067),1],[BuildingShapes.slab_for(6099),1]]]]:
		inv.restore([])
		for ingredient in entry[1]: inv.add_item(ingredient[0],ingredient[1])
		var recipe: Dictionary = inv.recipes[inv.recipe_index(entry[0])]
		t.check(inv.can_craft(recipe,"table") and inv.fill_grid(inv.recipe_index(entry[0]),"table") and inv.take_grid_result("table").get("id") == entry[0],"existing workstation guide and real grid accept the source mixed wood group: "+Nodes.title(entry[0]))
	inv.restore([])
	for i in [1,3,5,7]: inv.grid[i] = {"id":[6032,6068,6101,Nodes.CRIMSON_STEM][[1,3,5,7].find(i)],"count":1,"wear":0}
	inv.grid[4] = {"id":Nodes.FURNACE,"count":1,"wear":0}
	t.check(inv.take_grid_result("table").get("id") == VillageContent.SMOKER,"manual smoker accepts mixed logs, stripped logs, bark and Nether stems")
	inv.restore([])
	for id in WoodTypes.PLANKS: inv.add_item(BuildingShapes.slab_for(id),2)
	t.check(inv.fill_grid(inv.recipe_index(VillageContent.COMPOSTER),"table") and inv.take_grid_result("table").get("id") == VillageContent.COMPOSTER,"composter guide accepts seven mixed wooden slabs through source wood_slab group")
	inv.restore([])
	for i in [0,2,3,5,6,7,8]: inv.grid[i] = {"id":BuildingShapes.slab_for(WoodTypes.PLANKS[i%6]),"count":1,"wear":0}
	t.check(inv.take_grid_result("table").get("id") == VillageContent.COMPOSTER,"manual composter accepts a mix of all six wooden slab species")
	# New jungle hull goes through the real serialized entity registry.
	game.boats.reset(); game.boats.records().clear()
	var p := Vector3(8.5,550,8.5)
	for y in range(549,553): game.world.set_node(Vector3i(8,y,8),Nodes.AIR)
	var hull: BoatEntity = game.boats.spawn(Boats.JUNGLE_CHEST,p)
	t.check(hull != null and Boats.clean_record(hull.saved).get("id") == Boats.JUNGLE_CHEST and hull.saved.slots.size() == 27,"jungle chest hull spawns and sanitizes through the same persistent cargo path")
	if hull != null: game.boats.records().erase(hull.key); game.boats.active.erase(hull.key); hull.removed = true; hull.queue_free()
	game.inventory.restore([]); game.inventory.add_item(6035,4)
	game.hud.recipe_index = game.inventory.recipe_index(Nodes.WORKBENCH)
	game.open_inventory("hand")
	t.check(not game.hud.fill_button.disabled and game.hud.requirements_label.text.contains("Any wood planks  4 / 4"),"live recipe guide counts non-oak wood and enables its Fill grid button")
	game.hud._fill_grid()
	t.check(not game.hud.fill_button.disabled and game.hud.requirements_label.text.contains("Any wood planks  4 / 4") and game.inventory.matching_recipe("hand") == game.inventory.recipe_index(Nodes.WORKBENCH),"guide counts actual species already in its grid and keeps the generic recipe ready")
	game.pause()
	for entry in [[Doors.state_id(6200,3,true,true,true),6200],[Trapdoors.state_id(5380,2,true,true),5380],[FoodFeatures.cake_id(3),VillageContent.CAKE],[Signs.STANDING+7,Signs.OAK],[WoodTypes.oriented(6064,Vector3i.RIGHT),6064]]:
		t.check(Nodes.pick_item(entry[0]) == entry[1],"creative pick canonicalizes placed states without changing material: "+str(entry[0]))
