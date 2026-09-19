extends RefCounted
const Helper = preload("res://tests/boats_checks.gd")

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	for pair in [[DenseMaterials.PACKED_ICE,Nodes.ICE],[DenseMaterials.BLUE_ICE,DenseMaterials.PACKED_ICE],[DenseMaterials.BONE,Nodes.BONE_MEAL]]:
		var index: int = inv.recipe_index(pair[0]); inv.restore([]); inv.add_item(pair[1],9)
		t.check(index >= 0 and inv.recipes[index].ingredients == {pair[1]:9} and inv.recipes[index].count == 1 and inv.recipes[index].station == "table","source compression recipe has nine matching ingredients: "+Nodes.title(pair[0]))
		t.check(inv.fill_grid(index,"table") and inv.take_grid_result("table").get("id",0) == pair[0] and inv.count_item(pair[1]) == 0,"real guide transaction crafts compressed material without extra inputs: "+Nodes.title(pair[0]))
	inv.restore([]); inv.grid[0] = {"id":DenseMaterials.BONE,"count":1,"wear":0}
	var meal: Dictionary = inv.take_grid_result("hand")
	t.check(meal.get("id",0) == Nodes.BONE_MEAL and meal.get("count",0) == 9 and inv.grid[0].id == 0,"one bone block reverses into nine bone meal in hand crafting")
	for id in [DenseMaterials.PACKED_ICE,DenseMaterials.BLUE_ICE,DenseMaterials.BONE]:
		t.check(Nodes.exists(id) and Nodes.placeable(id) and Nodes.solid(id) and not Nodes.transparent(id),"new compressed material is an obtainable opaque full cube: "+Nodes.title(id))
	t.check(Nodes.hardness(DenseMaterials.PACKED_ICE) == 0.5 and Nodes.hardness(DenseMaterials.BLUE_ICE) == 2.8 and Nodes.hardness(DenseMaterials.BONE) == 2,"packed ice, blue ice and bone retain distinct source hardness")
	t.check(not Nodes.all_ids().has(DenseMaterials.BONE_X) and not Nodes.all_ids().has(DenseMaterials.BONE_Z) and not Nodes.all_ids().has(DenseMaterials.BONE_END) and not Nodes.placeable(DenseMaterials.BONE_END),"axis variants and atlas-only bone end stay out of the inventory catalog")
	for id in [Nodes.ICE,DenseMaterials.PACKED_ICE,DenseMaterials.BLUE_ICE]:
		t.check(Nodes.harvestable(id,0) and Nodes.harvestable(id,Nodes.TOOLS+2) and Nodes.preferred_tool(id) == 0,"source ice is handy with pickaxe preference: "+Nodes.title(id))
		t.check(DenseMaterials.harvest(id,{"id":Nodes.TOOLS,"data":{"enchantments":{"Fortune":3}}}).is_empty() and DenseMaterials.harvest(id,{"id":VillageContent.ENCHANTED_BOOK,"data":{"enchantments":{"Silk Touch":1}}}).is_empty(),"fortune and a held enchanted book cannot recover ice: "+Nodes.title(id))
	for id in [DenseMaterials.BONE,DenseMaterials.BONE_X,DenseMaterials.BONE_Z]:
		t.check(Nodes.drop(id) == DenseMaterials.BONE and Nodes.pick_item(id) == DenseMaterials.BONE and Nodes.harvestable(id,Nodes.TOOLS) and not Nodes.harvestable(id,0),"bone axes need a pickaxe and drop/pick the canonical bone block: "+str(id))
		for face in 6:
			t.check(DenseMaterials.end_tile(id,face) == (face/2 == DenseMaterials.axis(id)) and Nodes.tile(id,face) == 137+VillageContent.BLOCKS.find(DenseMaterials.BONE_END if DenseMaterials.end_tile(id,face) else DenseMaterials.BONE),"bone end-grain tile follows actual mesh face axis: %d/%d"%[id,face])
	t.check(DenseMaterials.slippery(Nodes.ICE) == 3 and DenseMaterials.slippery(DenseMaterials.PACKED_ICE) == 3 and DenseMaterials.slippery(DenseMaterials.BLUE_ICE) == 4 and DenseMaterials.acceleration(DenseMaterials.PACKED_ICE) == 8.75 and DenseMaterials.acceleration(DenseMaterials.PACKED_ICE,true) == 5 and is_equal_approx(DenseMaterials.acceleration(DenseMaterials.BLUE_ICE,true),35.0/9),"Luanti slippery factors slow acceleration and double slipperiness with idle input")
	var old: Dictionary = {"position":game.player.position,"rotation":game.player.rotation,"target":game.player.target,"mode":game.gamemode,"touch":game.touch,"inventory":game.inventory.slots.duplicate(true),"selected":game.inventory.selected,"flying":game.player.flying,"velocity":game.player.velocity}
	Helper.freeze(game); game.state = "playing"; game.gamemode = "survival"; game.touch = false; game.player.flying = false
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var world: VoxelWorld = game.world; var p := Vector3i(8,960,8)
	for x in range(-4,5):
		for z in range(-4,5):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.STONE if y == -1 else Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,3)
	for normal in [Vector3i.UP,Vector3i.RIGHT,Vector3i.BACK]:
		world.set_node(p,Nodes.AIR); world.set_node(p-normal,Nodes.STONE)
		Helper.equip(game,DenseMaterials.BONE,2); game.player.target = {"id":Nodes.STONE,"pos":p-normal,"normal":normal,"distance":3.0}
		game.player.use()
		t.check(world.node_at(p) == DenseMaterials.oriented(DenseMaterials.BONE,normal) and game.inventory.held().count == 1,"real use places a bone block aligned to the clicked face: "+str(normal))
		world.set_node(p-normal,Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	for id in [Nodes.ICE,DenseMaterials.PACKED_ICE,DenseMaterials.BLUE_ICE]:
		for silk in [false,true]:
			world.set_node(p,id); Helper.equip(game,Nodes.TOOLS,1,{"enchantments":{"Silk Touch":1}} if silk else {})
			var before: int = Helper.drops(game,id); game.break_node(p,id,Nodes.TOOLS)
			t.check(Helper.drops(game,id) == before+(1 if silk else 0) and world.node_at(p) == (Nodes.WATER if id == Nodes.ICE else Nodes.AIR),"real ice harvesting preserves source drop/melt behavior: %s, Silk Touch=%s"%[Nodes.title(id),str(silk)])
	world.set_node(p+Vector3i.DOWN,Nodes.AIR); world.set_node(p,Nodes.ICE); Helper.equip(game,Nodes.TOOLS)
	game.break_node(p,Nodes.ICE,Nodes.TOOLS)
	t.check(world.node_at(p) == Nodes.AIR,"unsupported ordinary ice leaves air")
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	var nether_p := Vector3i(8,100,8)
	var nether_old: Array = [world.node_at(nether_p),world.node_at(nether_p+Vector3i.DOWN)]
	world.set_node(nether_p+Vector3i.DOWN,Nodes.STONE); world.set_node(nether_p,Nodes.ICE)
	var dimension: String = world.generator.dimension; world.generator.dimension = "nether"
	game.break_node(nether_p,Nodes.ICE,Nodes.TOOLS); world.generator.dimension = dimension
	t.check(world.node_at(nether_p) == Nodes.AIR,"ordinary ice cannot create water in the Nether")
	world.set_node(nether_p,nether_old[0]); world.set_node(nether_p+Vector3i.DOWN,nether_old[1])
	for id in [Nodes.ICE,DenseMaterials.PACKED_ICE,DenseMaterials.BLUE_ICE]:
		game.gamemode = "creative"; world.set_node(p,id); var before: int = Helper.drops(game,id)
		game.break_node(p,id,Nodes.TOOLS)
		t.check(Helper.drops(game,id) == before and world.node_at(p) == (Nodes.WATER if id == Nodes.ICE else Nodes.AIR),"creative ice breaking keeps the source callback and creates no item drop: "+Nodes.title(id))
	game.gamemode = "survival"
	world.set_node(p,DenseMaterials.PACKED_ICE); Helper.equip(game,Nodes.TOOLS,1,{"enchantments":{"Silk Touch":1}})
	game.player.target = {"id":DenseMaterials.PACKED_ICE,"pos":p,"normal":Vector3i.UP,"distance":3.0}
	game.player.mining_pos = Vector3i(99999,99999,99999); game.player.mining = 0
	var mined_before: int = Helper.drops(game,DenseMaterials.PACKED_ICE)
	game.player.mine(1.0)
	t.check(world.node_at(p) == Nodes.AIR and Helper.drops(game,DenseMaterials.PACKED_ICE) == mined_before+1 and game.inventory.held().wear == 1,"real mining of packed ice consumes one tool durability and preserves Silk Touch output")
	for tool in [0,Nodes.TOOLS+2,Nodes.TOOLS]:
		world.set_node(p,DenseMaterials.BONE_X); Helper.equip(game,tool); var before: int = Helper.drops(game,DenseMaterials.BONE)
		game.break_node(p,DenseMaterials.BONE_X,tool)
		t.check(Helper.drops(game,DenseMaterials.BONE) == before+(1 if tool == Nodes.TOOLS else 0),"bone harvesting requires pickaxe and discards placed orientation: "+str(tool))
	var coast: Dictionary = {}; var driven: Dictionary = {}; var boat_speeds: Dictionary = {}
	for id in [Nodes.STONE,Nodes.ICE,DenseMaterials.PACKED_ICE,DenseMaterials.BLUE_ICE]:
		for x in range(-3,4):
			for z in range(-3,4): world.set_node(p+Vector3i(x,-1,z),id)
		game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5); game.player.rotation = Vector3.ZERO; game.player.velocity = Vector3(4,0,0); game.player.grounded = true; game.player.gliding = false; game.player.riptide_time = 0
		game.player._physics_process(0.1); coast[id] = game.player.velocity.x
		game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5); game.player.velocity = Vector3.ZERO; game.player.grounded = true
		Helper.press(KEY_D,true); game.player._physics_process(0.1); Helper.press(KEY_D,false); driven[id] = game.player.velocity.x
		var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p)+Vector3(0.5,0.1,0.5))
		boat.set_physics_process(false); boat.speed = 12; boat.control = Vector3.ZERO; boat._move_step(0.01); boat_speeds[id] = boat.speed
		game.boats.records().erase(boat.key); game.boats.active.erase(boat.key); boat.queue_free()
	t.check(coast[Nodes.ICE] > coast[Nodes.STONE]+2 and is_equal_approx(coast[Nodes.ICE],coast[DenseMaterials.PACKED_ICE]) and coast[DenseMaterials.BLUE_ICE] > coast[DenseMaterials.PACKED_ICE],"real player movement coasts on ice, with blue ice retaining more velocity than packed ice")
	t.check(driven[Nodes.STONE] > driven[Nodes.ICE] and is_equal_approx(driven[Nodes.ICE],0.875) and is_equal_approx(driven[DenseMaterials.PACKED_ICE],0.875) and is_equal_approx(driven[DenseMaterials.BLUE_ICE],0.7),"real held keyboard movement uses source input slipperiness rather than the doubled idle factor")
	t.check(boat_speeds[Nodes.STONE] <= 8 and boat_speeds[Nodes.ICE] > 11 and is_equal_approx(boat_speeds[Nodes.ICE],boat_speeds[DenseMaterials.PACKED_ICE]) and is_equal_approx(boat_speeds[Nodes.ICE],boat_speeds[DenseMaterials.BLUE_ICE]),"actual boat movement treats all source ice groups identically and avoids ordinary land slowdown")
	for offset in 5: world.set_node(p+Vector3i(offset,1,0),DenseMaterials.PACKED_ICE+offset)
	t.check(game.save_game("user://dense-materials.json"),"compressed materials and axis variants serialize through the real save")
	var saved: Dictionary = game.read_save("user://dense-materials.json"); game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	Helper.freeze(game); world = game.world
	for offset in 5: t.check(world.node_at(p+Vector3i(offset,1,0)) == DenseMaterials.PACKED_ICE+offset,"material state survives restart: "+str(DenseMaterials.PACKED_ICE+offset))
	for x in range(-4,5):
		for z in range(-4,5):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = old.position; game.player.rotation = old.rotation; game.player.target = old.target; game.player.velocity = old.velocity; game.player.flying = old.flying
	game.gamemode = old.mode; game.touch = old.touch; game.inventory.slots = old.inventory; game.inventory.selected = old.selected
	Helper.freeze(game)
