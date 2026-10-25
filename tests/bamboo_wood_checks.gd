extends RefCounted

static func craft(inv: Inventory, id: int, ingredients: Array, station: String = "table") -> Dictionary:
	inv.restore([])
	for entry in ingredients: inv.add_item(entry[0],entry[1])
	var index: int = inv.recipe_index(id)
	if index < 0 or not inv.fill_grid(index,station): return {}
	return inv.take_grid_result(station)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var inv := Inventory.new()
	t.check(WoodTypes.species(BambooWood.BLOCK) == 11 and WoodTypes.is_planks(BambooWood.PLANKS),"bamboo joins wood recipes as its own material")
	t.check(TrialLoot.item_id("mcl_trees:wood_bamboo") == BambooWood.PLANKS and TrialLoot.item_id("mcl_signs:hanging_sign_bamboo") == BambooWood.HANGING,"source trial loot resolves both bamboo entries to obtainable items")
	t.check(WoodTypes.sapling_id(11) == 0 and WoodTypes.leaves_id(11) == 0 and not Nodes.exists(BambooWood.BLOCK+5),"bamboo has no invented saplings, leaves or bark blocks")
	var all_items: Array = Nodes.all_ids()
	t.check(all_items.count(BambooWood.DOOR) == 1,"bamboo door appears exactly once in the item catalog")
	for id in BambooWood.WOOD_DATA:
		t.check(Nodes.exists(id) and not Signs.is_sign(id) and not Doors.is_door(id) and not BuildingShapes.is_shape(id),"bamboo resource range is registered without overlap: "+str(id))
		if not BambooWood.WOOD_DATA[id].get("hidden",false): t.check(all_items.has(id),"bamboo resource is in the item catalog: "+str(id))
	var made: Dictionary = craft(inv,BambooWood.BLOCK,[[Bamboo.BAMBOO_ITEM,9]])
	t.check(made.get("count",0) == 1 and inv.count_item(Bamboo.BAMBOO_ITEM) == 0,"nine harvested bamboo stalks craft one bamboo block")
	for block in [BambooWood.BLOCK,BambooWood.STRIPPED]:
		made = craft(inv,BambooWood.PLANKS,[[block,1]],"hand")
		# recipe_index picks the raw-block recipe; explicitly use the alternate
		# source recipe when testing the stripped block.
		if block == BambooWood.STRIPPED:
			inv.restore([]); inv.grid[0] = {"id":block,"count":1,"wear":0}; made = inv.take_grid_result("hand")
		t.check(made.get("id") == BambooWood.PLANKS and made.get("count") == 2,"one bamboo block produces exactly two planks: "+str(block))
	t.check(Nodes.smelt_result(BambooWood.BLOCK) == 0 and Nodes.smelt_result(BambooWood.STRIPPED) == Nodes.CHARCOAL,"raw bamboo blocks cannot smelt; stripped blocks retain source charcoal behavior")
	var slab: int = BuildingShapes.slab_for(BambooWood.PLANKS)
	var mosaic_slab: int = BuildingShapes.slab_for(BambooWood.MOSAIC)
	t.check(slab > 0 and mosaic_slab > slab and BuildingShapes.slab_for(6005) == BuildingShapes.EXTRA_FIRST+BuildingShapes.EXTRA_MATERIALS.size()*16,"new bamboo shape families preserve every preexisting bark-shape ID")
	made = craft(inv,BambooWood.MOSAIC,[[slab,2]],"hand")
	t.check(made.get("count") == 1 and made.get("id") == BambooWood.MOSAIC,"two vertically stacked bamboo slabs craft one mosaic block")
	inv.restore([]); inv.grid[0] = {"id":slab,"count":1,"wear":0}; inv.grid[1] = {"id":slab,"count":1,"wear":0}
	t.check(inv.matching_recipe("hand") < 0,"horizontal bamboo slabs cannot make mosaic")
	t.check(BuildingShapes.stonecutter_inputs(BambooWood.MOSAIC).is_empty() and BuildingShapes.stonecutter_inputs(BambooWood.PLANKS).is_empty(),"neither bamboo planks nor mosaic gain an invented stonecutter route")
	for material in [BambooWood.PLANKS,BambooWood.MOSAIC]:
		made = craft(inv,BuildingShapes.slab_for(material),[[material,3]])
		t.check(made.get("count") == 6 and Nodes.fuel_time(BuildingShapes.slab_for(material)) == 7.5,"bamboo material makes six half-fuel slabs: "+str(material))
		made = craft(inv,BuildingShapes.stair_for(material),[[material,6]])
		t.check(made.get("count") == 4 and Nodes.fuel_time(BuildingShapes.stair_for(material)) == 15,"bamboo material makes four full-fuel stairs: "+str(material))
	var button: int = RedstoneInputs.FIRST+15*8
	for item in [BambooWood.DOOR,BambooWood.TRAPDOOR,BambooWood.FENCE,BambooWood.FENCE+1,BambooWood.SIGN,BambooWood.PLATE,button]:
		var index: int = inv.recipe_index(item)
		t.check(index >= 0 and all_items.has(item),"bamboo product has a survival recipe and catalog entry: "+str(item))
		if index < 0: continue
		inv.restore([]); inv.add_item(BambooWood.PLANKS,16); inv.add_item(Nodes.STICK,16)
		t.check(inv.fill_grid(index,"table") and inv.take_grid_result("table").get("id") == item,"recipe guide makes the matching bamboo product: "+str(item))
	t.check(RedstoneInputs.wooden(button) and RedstoneInputs.duration(button) == 1.5 and RedstoneInputs.fuel_time(button) == 5,"bamboo button retains wood projectile activation, timing and fuel")
	inv.restore([])
	for i in [0,1,3]: inv.grid[i] = {"id":BambooWood.PLANKS,"count":1,"wear":0}
	inv.grid[4] = {"id":WoodTypes.PLANKS[1],"count":1,"wear":0}
	t.check(inv.take_grid_result("hand").get("id") == Nodes.WORKBENCH,"bamboo planks mix with other wood in generic recipes")
	var smoker: Dictionary = inv.recipes[inv.recipe_index(VillageContent.SMOKER)]
	t.check(Inventory.ingredient_key(smoker,BambooWood.BLOCK) != Nodes.LOG,"source bamboo blocks do not acquire the generic tree group")
	t.check(Signs.BASES.size() == 12 and Signs.HANGING_BASES.size() == 12,"every source wood has ordinary and hanging signs")
	for base in Signs.BASES:
		var species: int = Signs.SPECIES[base]
		t.check(Signs.material(base) == WoodTypes.PLANKS[species] and Nodes.title(base).to_lower().begins_with(WoodTypes.NAMES[species].to_lower()),"sign name and material remain aligned: "+str(base))
		for state in 20: t.check(not Doors.is_door(base+state),"sign state never overlaps a copper door: "+str(base+state))
	for i in Signs.HANGING_BASES.size():
		var recipe: Dictionary = inv.recipes[inv.recipe_index(Signs.HANGING_ITEMS[i])]
		var stripped: int = WoodTypes.base(i)+4
		t.check(recipe.count == 6 and recipe.pattern == [CopperDecor.CHAIN,0,CopperDecor.CHAIN,stripped,stripped,stripped,stripped,stripped,stripped],"hanging-sign recipe uses six matching stripped blocks and two chains: "+str(i))
	var legacy_pos := Vector3i(6,840,6); var copper_pos := Vector3i(7,840,6)
	world.edits[legacy_pos] = Signs.LEGACY_BASES[2]+8
	world.edits[copper_pos] = Signs.LEGACY_BASES[2]+8
	world.stations[VoxelWorld.station_key(legacy_pos)] = {"kind":"sign","text":"Kept my writing","serial":27}
	world.adventure_state.erase("sign_ranges"); Signs.restore_legacy(world)
	t.check(world.edits[legacy_pos] == Signs.REPLACEMENT_BASES[2]+8 and world.stations[VoxelWorld.station_key(legacy_pos)].text == "Kept my writing","legacy sign migration keeps facing and text")
	t.check(world.edits[copper_pos] == Signs.LEGACY_BASES[2]+8,"legacy migration leaves untagged copper-door states intact")
	for i in Signs.LEGACY_BASES.size(): t.check(Inventory.clean_slot({"id":Signs.LEGACY_BASES[i],"count":1}).id == Signs.REPLACEMENT_BASES[i],"legacy sign item migrates to its new safe range: "+str(i))
	for x in range(2,15):
		for z in range(2,15):
			for y in range(844,850): world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 844 else Nodes.AIR)
	var p := Vector3i(5,845,5)
	world.set_node(p,WoodTypes.oriented(BambooWood.BLOCK,Vector3i.RIGHT))
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.TOOLS+1,"count":1,"wear":0}
	game.inventory.selected = 0
	t.check(WoodTypes.use(game,{"id":world.node_at(p),"pos":p}) and world.node_at(p) == BambooWood.BLOCK+10 and game.inventory.held().wear > 0,"axe stripping preserves horizontal bamboo orientation and wears the axe")
	t.check(Nodes.drop(world.node_at(p)) == BambooWood.STRIPPED and Nodes.tile(world.node_at(p),0) != Nodes.tile(world.node_at(p),2),"stripped bamboo exposes end grain and drops the canonical block")
	await signs(t,game)
	await rafts(t,game)

static func signs(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var p := Vector3i(6,848,6)
	for x in range(4,10):
		for y in range(847,851):
			for z in range(4,10): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	world.set_node(p+Vector3i.UP,BambooWood.PLANKS)
	world.set_node(p,BambooWood.HANGING)
	t.check(NodeInfo.mesh_kind(BambooWood.HANGING,false) == 8 and not (NodeInfo.of(BambooWood.HANGING)&NodeInfo.CUBE),"hanging sign uses custom geometry instead of a full cube")
	var oak: Array = BlockMesher._empty(); var bamboo: Array = BlockMesher._empty()
	Signs.mesh(oak,Vector3.ZERO,Signs.HANGING_BASES[0]); Signs.mesh(bamboo,Vector3.ZERO,BambooWood.HANGING)
	t.check(bamboo[0].size() > 24 and bamboo[3] != oak[3],"hanging sign has suspended board geometry with the matching wood texture")
	t.check(Signs.icon_faces(BambooWood.SIGN) != Signs.icon_faces(Signs.OAK),"ordinary sign icons use their own species texture")
	t.check(is_equal_approx(Signs.yaw(BambooWood.HANGING+3),3*TAU/16) and is_equal_approx(Signs.yaw(BambooWood.HANGING+17),PI/2),"hanging board and writing share stored ceiling and wall rotations")
	var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,0.3,2),Vector3.FORWARD,2.0)
	t.check(hit.get("id",0) == BambooWood.HANGING,"a ray hits the hanging sign's board")
	hit = world.raycast(Vector3(p)+Vector3(0.5,0.8,2),Vector3.FORWARD,2.0)
	t.check(hit.is_empty(),"a ray passes through the gap above a hanging sign board")
	t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.1,0.5),0.1,0.4),"ceiling hanging signs remain non-walkable")
	var state: Dictionary = Signs.station(world,p); state.text = "Bamboo\nWorkshop"; state.written = true
	game.player.position = Vector3(p)+Vector3(2,0,2)
	game.survival.refresh_displays()
	var key: String = VoxelWorld.station_key(p)
	t.check(game.survival.displays.has(key) and game.survival.displays[key].get_node("SignText").text == "Bamboo\nWorkshop","hanging sign writing reaches the live text display")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":VillageContent.GLOW_INK_SAC,"count":2,"wear":0}; game.inventory.selected = 0
	game.player.target = {"id":BambooWood.HANGING,"pos":p,"normal":Vector3i.BACK,"distance":3.0}
	t.check(GlowInk.apply(game,{"id":BambooWood.HANGING,"pos":p}) and state.glow and game.inventory.held().count == 1,"glow ink reaches hanging signs and consumes one sac")
	var before: int = game.drops.get_child_count()
	world.set_node(p+Vector3i.UP,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and game.drops.get_child_count() == before+1,"removing the ceiling automatically drops a hanging sign")
	world.set_node(p+Vector3i.FORWARD,BambooWood.PLANKS)
	world.set_node(p,BambooWood.HANGING+16)
	t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.1,0.5),0.1,0.4) and world.intersects(Vector3(p)+Vector3(0.5,0.88,0.5),0.1,0.1),"wall hanging signs collide only with their top support bar")
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.FORWARD,Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,BambooWood.PLANKS); world.set_node(p,BambooWood.SIGN+4)
	before = game.drops.get_child_count(); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	var dropped: bool = false
	for i in range(before,game.drops.get_child_count()):
		if game.drops.get_child(i).item_id == BambooWood.SIGN: dropped = true
	t.check(dropped,"detaching an ordinary sign returns its own wood species")
	await t.process_frame

static func rafts(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	var world: VoxelWorld = game.world
	var inv := Inventory.new()
	for index in range(6,Boats.ORDINARY.size()):
		var id: int = Boats.ORDINARY[index]
		var result: Dictionary = craft(inv,id,[[Boats.MATERIALS[index],5]])
		t.check(result.get("id") == id and Nodes.fuel_time(id) == 60,"new source hull crafts from five matching planks: "+str(id))
		result = craft(inv,Boats.CHESTS[index],[[id,1],[Nodes.CHEST,1]],"hand")
		t.check(result.get("id") == Boats.CHESTS[index],"source chest hull crafts from matching boat or raft: "+str(id))
	t.check(Boats.hull(BambooWood.RAFT) == AABB(Vector3(-0.25,0,-0.55),Vector3(0.5,0.3,1.25)),"bamboo raft uses source asymmetric collision dimensions")
	t.check(Boats.selection(BambooWood.RAFT) == AABB(Vector3(-0.7,0,-0.7),Vector3(1.4,0.3,1.4)) and Boats.selection(BambooWood.CHEST_RAFT) == Boats.selection(BambooWood.RAFT),"both rafts use the source low selection box")
	var at := Vector3(8.3,845.01,8.5)
	world.set_node(Vector3i(7,845,8),Nodes.STONE)
	t.check(not Boats.hull_blocked(world,BambooWood.RAFT,at) and Boats.hull_blocked(world,Boats.ORDINARY[0],at),"the narrower raft clears a wall that blocks an ordinary boat")
	world.set_node(Vector3i(7,845,8),Nodes.AIR)
	world.set_node(Vector3i(8,845,9),Nodes.STONE)
	t.check(Boats.hull_blocked(world,BambooWood.RAFT,Vector3(8.5,845.01,8.4)),"the longer raft hull cannot clip through an obstacle beyond the boat footprint")
	world.set_node(Vector3i(8,845,9),Nodes.AIR)
	var raft: BoatEntity = game.boats.spawn(BambooWood.CHEST_RAFT,Vector3(8.5,845.01,8.5))
	t.check(raft != null,"a chest raft can be placed in clear space")
	if raft == null: return
	raft.set_physics_process(false)
	raft.saved.slots[0] = {"id":Nodes.DIAMOND,"count":17,"wear":0}
	raft.saved.slots[1] = {"id":BambooWood.SIGN,"count":3,"wear":0}
	game.player.position = raft.position+Vector3(0,0,2)
	t.check(game.boats.board(raft) and is_equal_approx(game.player.position.y-raft.position.y,0.25),"raft rider uses the source elevated seat")
	game.boats.dismount()
	var key: String = raft.key
	t.check(game.save_game("user://bamboo_wood.json"),"new bamboo cargo and raft state save to disk")
	game.set_process(true); game.load_world_data(game.read_save("user://bamboo_wood.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.boats.active.has(key),"reload restores the same persistent raft identity")
	if game.boats.active.has(key):
		raft = game.boats.active[key]; raft.set_physics_process(false)
		t.check(raft.item_id == BambooWood.CHEST_RAFT and raft.saved.slots[0].count == 17 and raft.saved.slots[1].id == BambooWood.SIGN,"real reload preserves raft type and new bamboo cargo IDs")
		game.boats.destroy(raft)
	for path in ["user://bamboo_wood.json","user://bamboo_wood.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
