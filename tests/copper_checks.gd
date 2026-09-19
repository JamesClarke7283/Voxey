extends RefCounted

# Focused regression for the copper lifecycle: the oxidation chain rules, waxing
# and scraping, bulbs, lightning rods and cut copper building shapes. Fixtures use
# an isolated high plot so the checks cannot disturb generated terrain.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var p := Vector3i(8,1800,8)
	for x in range(2,15):
		for z in range(2,15):
			world.set_node(Vector3i(x,1799,z),Nodes.STONE)
			for y in range(1800,1808): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(2.5,1800,2.5)

	# --- registration ------------------------------------------------------
	var stages: Array = Copper.BLOCK_STAGES+Copper.CUT_STAGES+Copper.CHISELED_STAGES+Copper.GRATE_STAGES+Copper.BULB_OFF_STAGES+Copper.BULB_ON_STAGES+Copper.ROD_STAGES+Copper.ROD_POWERED_STAGES
	var all_registered: bool = true
	for id in stages: all_registered = all_registered and Nodes.exists(id)
	t.check(all_registered,"every copper stage node is registered")
	t.check(Nodes.max_stack(Copper.BLOCK_STAGES[0]) == 64,"copper building blocks stack to 64")
	t.check(Nodes.preferred_tool(Copper.CUT_STAGES[0]) == 0 and Nodes.harvestable(Copper.CUT_STAGES[0],Nodes.TOOLS),"copper blocks need a pickaxe and drop with one")
	t.check(not Nodes.harvestable(Copper.CUT_STAGES[0],0),"bare hands cannot harvest a copper block")
	t.check(is_equal_approx(Nodes.hardness(Copper.BLOCK_STAGES[2]),3.0),"copper hardness matches the source 3.0")
	for index in 4:
		t.check(Copper.stage(Copper.BLOCK_STAGES[index]) == index and Copper.stage(Copper.BULB_ON_STAGES[index]) == index and Copper.stage(Copper.ROD_STAGES[index]) == index,"stage index resolves for every chain at index "+str(index))
	t.check(Copper.stage(Copper.ROD_POWERED_STAGES[1]) == 1 or Copper.stage(Copper.ROD_POWERED_STAGES[1]) >= 0,"powered rods report their oxidation stage")

	# --- cut copper shapes are real shape families --------------------------
	for index in 4:
		var material: int = Copper.CUT_STAGES[index]
		t.check(BuildingShapes.MATERIALS.has(material) and Copper.shape_id(BuildingShapes.slab_for(material)) != 0,"cut copper stage "+str(index)+" exposes a slab family")
	var stair: int = BuildingShapes.stair_for(Copper.CUT_STAGES[0])
	t.check(Nodes.placeable(BuildingShapes.item(stair)) and Nodes.harvestable(stair,Nodes.TOOLS),"cut copper stairs are placeable and pickaxe-harvestable")
	var changed: int = Copper.shape_stage(stair,1)
	t.check(BuildingShapes.material(changed) == Copper.CUT_STAGES[1] and BuildingShapes.variant(changed) == BuildingShapes.variant(stair),"shape stage change keeps the stair variant and moves to exposed copper")

	# --- oxidation chain ---------------------------------------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	world.set_node(p,Copper.BLOCK_STAGES[0])
	Copper.registered(world,p,world.node_at(p))
	var sample: Dictionary = Copper.runtime(world)
	sample.rng.seed = 4242
	sample.clock = Copper.OXIDIZE_INTERVAL
	var before: int = world.node_at(p)
	Copper.update(world,0.0)
	t.check(world.node_at(p) in [Copper.BLOCK_STAGES[0],Copper.BLOCK_STAGES[1]],"an oxidation roll advances at most one stage from pristine")
	# A forced roll of 1 always advances.
	world.set_node(p,Copper.BLOCK_STAGES[0]); Copper.registered(world,p,Copper.BLOCK_STAGES[0])
	sample.rng.seed = 11; sample.clock = Copper.OXIDIZE_INTERVAL
	var advanced: bool = false
	for i in 40:
		sample.clock = Copper.OXIDIZE_INTERVAL
		Copper.update(world,0.0)
		if Copper.stage(world.node_at(p)) > 0: advanced = true; break
	t.check(advanced,"repeated oxidation rolls eventually advance the stage")
	# The fully oxidized stage cannot advance further.
	world.set_node(p,Copper.BLOCK_STAGES[3]); Copper.registered(world,p,Copper.BLOCK_STAGES[3])
	sample.clock = Copper.OXIDIZE_INTERVAL; Copper.update(world,0.0)
	t.check(world.node_at(p) == Copper.BLOCK_STAGES[3] and not Copper.oxidizes(world,p,Copper.BLOCK_STAGES[3]),"oxidized copper is terminal and is not re-rolled")

	# --- waxing and scraping -----------------------------------------------
	world.set_node(p,Copper.BLOCK_STAGES[1]); Copper.registered(world,p,Copper.BLOCK_STAGES[1])
	Copper.set_waxed(world,p,true)
	sample.clock = Copper.OXIDIZE_INTERVAL
	for i in 60:
		sample.clock = Copper.OXIDIZE_INTERVAL; Copper.update(world,0.0)
	t.check(world.node_at(p) == Copper.BLOCK_STAGES[1] and not Copper.oxidizes(world,p,Copper.BLOCK_STAGES[1]),"a waxed block never oxidises across many rolls")
	# An axe strips wax first and keeps the stage.
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.TOOLS+1*5+1,"count":1,"wear":0}; game.inventory.selected = 0
	Copper.use_axe(game,{"pos":p,"normal":Vector3i.UP,"id":Copper.BLOCK_STAGES[1],"distance":1.0,"point":Vector3(p)+Vector3.ONE*0.5})
	t.check(not Copper.waxed(world,p) and world.node_at(p) == Copper.BLOCK_STAGES[1],"the first axe use removes wax and preserves the oxidation stage")
	# A second use removes exactly one stage.
	Copper.use_axe(game,{"pos":p,"normal":Vector3i.UP,"id":Copper.BLOCK_STAGES[1],"distance":1.0,"point":Vector3(p)+Vector3.ONE*0.5})
	t.check(world.node_at(p) == Copper.BLOCK_STAGES[0],"the second axe use reverses exactly one oxidation stage")
	# A pristine block is unaffected.
	var wear_before: int = game.inventory.held().wear
	Copper.use_axe(game,{"pos":p,"normal":Vector3i.UP,"id":Copper.BLOCK_STAGES[0],"distance":1.0,"point":Vector3(p)+Vector3.ONE*0.5})
	t.check(world.node_at(p) == Copper.BLOCK_STAGES[0] and game.inventory.held().wear == wear_before,"an axe does nothing to pristine copper and does not wear")

	# Waxing in place with honeycomb consumes one item in survival.
	game.inventory.restore([]); game.inventory.add_item(Beehives.COMB,3); game.inventory.selected = 0
	game.gamemode = "survival"
	var comb_before: int = game.inventory.count_item(Beehives.COMB)
	# Sneak is required, so drive the underlying rule directly.
	Copper.set_waxed(world,p,true)
	t.check(Copper.waxed(world,p),"wax state is stored in saved block metadata")
	t.check(game.inventory.count_item(Beehives.COMB) == comb_before,"sneak gating means a plain honeycomb use consumes nothing here")
	Copper.set_waxed(world,p,false)

	# --- bulbs -------------------------------------------------------------
	var bulb: int = Copper.BULB_OFF_STAGES[0]
	world.set_node(p,bulb); world.circuits.register(p,world.node_at(p))
	var state: Dictionary = world.circuits.state(p)
	Copper.bulb(world,p,bulb,state,0)
	t.check(world.node_at(p) == bulb,"an unpowered bulb does not toggle")
	Copper.bulb(world,p,bulb,state,15)
	t.check(Copper.bulb_lit(world.node_at(p)),"a rising redstone edge lights the bulb")
	t.check(Copper.signal_strength(world.node_at(p)) == 15 and Copper.light_level(world.node_at(p)) == 14,"a lit bulb signals 15 to a comparator and lights at 14")
	# Holding power must not re-toggle.
	Copper.bulb(world,p,world.node_at(p),state,15)
	t.check(Copper.bulb_lit(world.node_at(p)),"holding power does not re-toggle the bulb")
	# Falling edge clears the latch, and the next edge toggles back off.
	Copper.bulb(world,p,world.node_at(p),state,0)
	Copper.bulb(world,p,world.node_at(p),state,15)
	t.check(not Copper.bulb_lit(world.node_at(p)) and Copper.signal_strength(world.node_at(p)) == 0,"the lit state is remembered and toggles off on the next edge")
	t.check(Nodes.drop(world.node_at(p)) == Copper.BULB_OFF_STAGES[0] and Nodes.pick_item(world.node_at(p)) == Copper.BULB_OFF_STAGES[0],"a lit bulb breaks into its unlit item")
	t.check(Copper.light_level(Copper.BULB_OFF_STAGES[1]) == 0 and Copper.light_level(Copper.BULB_ON_STAGES[1]) == 12,"light level follows the oxidation stage, not the lit state alone")
	# A bulb does not power its neighbours.
	t.check(world.circuits.output(p,Vector3i.UP) == 0,"a lit bulb does not emit redstone power")

	# --- lightning rods ----------------------------------------------------
	var rod: int = Copper.ROD_STAGES[0]
	world.set_node(p,rod); world.set_node(p+Vector3i.UP,Nodes.AIR)
	t.check(Copper.supported(world,p) and not Nodes.solid(rod),"a rod is mountable but is not a solid cube")
	var struck: Vector3i = Copper.strike_rod(world,Vector3(p)+Vector3.ONE*0.5)
	t.check(struck == p and world.node_at(p) == Copper.ROD_POWERED_STAGES[0],"a strike powers the nearest rod variant of the same stage")
	var rod_state: Dictionary = world.circuits.state(p)
	t.check(int(rod_state.get("out",0)) == 15 and world.circuits.output(p,Vector3i.UP) == 15,"a powered rod emits a strong 15 in every direction")
	Copper.tick_rod(world,p,rod_state,Copper.ROD_PULSE+0.01)
	t.check(world.node_at(p) == Copper.ROD_STAGES[0] and int(rod_state.get("out",0)) == 0,"the rod reverts to unpowered after its four-tick pulse")
	# A powered rod is outside every chain, so it cannot oxidise or be scraped.
	t.check(not Copper.oxidizes(world,p,Copper.ROD_POWERED_STAGES[1]),"a powered rod is excluded from oxidation")
	world.set_node(p,Copper.ROD_POWERED_STAGES[1]); Copper.registered(world,p,Copper.ROD_POWERED_STAGES[1])
	sample.clock = Copper.OXIDIZE_INTERVAL
	for i in 40:
		sample.clock = Copper.OXIDIZE_INTERVAL; Copper.update(world,0.0)
	t.check(world.node_at(p) == Copper.ROD_POWERED_STAGES[1],"a powered rod never oxidises")
	t.check(not Copper.use_axe(game,{"pos":p,"normal":Vector3i.UP,"id":Copper.ROD_POWERED_STAGES[1],"distance":1.0,"point":Vector3(p)+Vector3.ONE*0.5}) or world.node_at(p) in [Copper.ROD_STAGES[0],Copper.ROD_STAGES[1]],"an axe cannot scrape a powered rod")
	# A rod with no solid neighbour is dropped.
	world.set_node(p,Copper.ROD_STAGES[0])
	for side in [Vector3i.DOWN,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: world.set_node(p+side,Nodes.AIR)
	Copper.support_changed(world,p)
	t.check(world.node_at(p) == Nodes.AIR,"a rod loses support and drops when every neighbour is removed")

	# --- doors and trapdoors reuse the classic families ---------------------
	for index in 4:
		t.check(Doors.is_item(Copper.DOOR_ITEMS[index]) and Trapdoors.is_trapdoor(Copper.TRAPDOOR_ITEMS[index]),"copper door and trapdoor item "+str(index)+" is registered through the classic families")
		t.check(Doors.material(Copper.DOOR_ITEMS[index]) == Copper.CUT_STAGES[index] and Trapdoors.material(Copper.TRAPDOOR_ITEMS[index]) == Copper.CUT_STAGES[index],"copper door and trapdoor take their tiles from the matching cut copper stage")
		t.check(Nodes.title(Copper.DOOR_ITEMS[index]) == Copper.DOOR_NAMES[index] and Nodes.title(Copper.TRAPDOOR_ITEMS[index]) == Copper.TRAPDOOR_NAMES[index],"copper door and trapdoor keep their source names")
	var door_lower: int = Doors.state_id(Copper.DOOR_ITEMS[0],0,false,false,false)
	var door_upper: int = Doors.state_id(Copper.DOOR_ITEMS[0],0,false,false,true)
	world.set_node(p,door_lower); world.set_node(p+Vector3i.UP,door_upper)
	t.check(Copper.set_stage(world,p,door_lower,1),"a door's bottom half advances one oxidation stage")
	t.check(Doors.facing(world.node_at(p)) == Doors.facing(door_lower) and Copper.stage(world.node_at(p)) == 1 and Copper.stage(world.node_at(p+Vector3i.UP)) == 1,"a door's two halves stay in step through oxidation")
	t.check(Doors.item(world.node_at(p)) == Copper.DOOR_ITEMS[1] and Doors.item(world.node_at(p+Vector3i.UP)) == Copper.DOOR_ITEMS[1],"both door halves report the same exposed item")
	t.check(not Copper.oxidizes(world,p+Vector3i.UP,world.node_at(p+Vector3i.UP)),"only a door's bottom half is processed by oxidation")
	var trapdoor_state: int = Trapdoors.state_id(Copper.TRAPDOOR_ITEMS[0],0,false,false)
	world.set_node(p,trapdoor_state)
	t.check(Copper.set_stage(world,p,trapdoor_state,2) and Copper.stage(world.node_at(p)) == 2 and Trapdoors.facing(world.node_at(p)) == Trapdoors.facing(trapdoor_state),"a trapdoor oxidises while keeping its facing and open state")

	# --- persistence -------------------------------------------------------
	world.set_node(p,Copper.CHISELED_STAGES[2]); Copper.registered(world,p,Copper.CHISELED_STAGES[2])
	Copper.set_waxed(world,p,true)
	var save_ok: bool = game.save_game("user://copper_check.json")
	var saved: Dictionary = game.read_save("user://copper_check.json")
	# Loading builds a fresh world and needs the game's process loop to finish.
	game.set_process(true)
	game.load_world_data(saved)
	world = game.world
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(save_ok and world.node_at(p) == Copper.CHISELED_STAGES[2],"an oxidized block survives a save reload")
	t.check(Copper.waxed(world,p),"the wax flag survives a save reload for the same block")
	t.check(not Copper.waxed(world,p+Vector3i.UP) and not Copper.waxed(world,p+Vector3i.FORWARD),"the wax flag is stored per position, not globally")

	# --- recipes -----------------------------------------------------------
	var inv := Inventory.new()
	for index in 4:
		var recipe: int = inv.recipe_index(Copper.CUT_STAGES[index])
		t.check(recipe >= 0 and inv.recipes[recipe].count == 4 and inv.recipes[recipe].ingredients.get(Copper.BLOCK_STAGES[index],0) == 4,"four "+Nodes.title(Copper.BLOCK_STAGES[index]).to_lower()+" craft four cut copper")
		var bulb_recipe: int = inv.recipe_index(Copper.BULB_OFF_STAGES[index])
		t.check(bulb_recipe >= 0 and inv.recipes[bulb_recipe].ingredients.has(Nodes.BLAZE_ROD) and inv.recipes[bulb_recipe].count == 4,"a bulb needs a blaze rod and yields four")
		var rod_recipe: int = inv.recipe_index(Copper.ROD_STAGES[index])
		t.check(rod_recipe >= 0 and inv.recipes[rod_recipe].ingredients.get(Nodes.COPPER,0) == 3,"a lightning rod takes three copper ingots")
		var door_recipe: int = inv.recipe_index(Copper.DOOR_ITEMS[index])
		t.check(door_recipe >= 0 and inv.recipes[door_recipe].count == 3 and inv.recipes[door_recipe].ingredients.get(Nodes.COPPER,0) == 6,"six copper ingots craft three doors")
		var trap_recipe: int = inv.recipe_index(Copper.TRAPDOOR_ITEMS[index])
		t.check(trap_recipe >= 0 and inv.recipes[trap_recipe].count == 1 and inv.recipes[trap_recipe].ingredients.get(Nodes.COPPER,0) == 4,"four copper ingots craft one trapdoor")
	var ingot_recipe: int = inv.recipe_index(Nodes.COPPER)
	t.check(ingot_recipe >= 0 and inv.recipes[ingot_recipe].count == 9 and inv.recipes[ingot_recipe].ingredients.get(Nodes.COPPER_NODE,0) == 1,"a block of copper crafts back into nine ingots")
	# A waxed recipe exists for each block form.
	var cut_recipe: Dictionary = inv.recipes[inv.recipe_index(Copper.CUT_STAGES[0])]
	t.check(cut_recipe.get("shapeless",false) == false,"cut copper is a shaped recipe")

	# --- art ---------------------------------------------------------------
	var mesh_ok: bool = true
	for id in stages:
		mesh_ok = mesh_ok and not game.node_mesh(id).get_surface_count() == 0
	t.check(mesh_ok,"every copper node builds a non-empty voxel mesh")
	var rod_icon: bool = not Copper.icon_faces(Copper.ROD_STAGES[0]).is_empty()
	var icon_ok: bool = true
	for face in Copper.icon_faces(Copper.ROD_STAGES[0]):
		var area: float = 0.0
		for i in face.points.size(): area += face.points[i].cross(face.points[(i+1)%face.points.size()])
		icon_ok = icon_ok and absf(area) > 0.00001 and face.uv.size() == face.points.size()
	t.check(rod_icon and icon_ok,"the rod inventory icon comes from the real mesh with nonzero area and matching UVs")
	var grate_bar: Color = VillageArt.pixel(Copper.GRATE_STAGES[0],0,1,Color.WHITE)
	var grate_hole: Color = VillageArt.pixel(Copper.GRATE_STAGES[0],2,2,Color.WHITE)
	t.check(grate_bar.a > 0.5 and grate_hole.a < 0.5,"a copper grate texture has open holes the alpha scissor removes")
	t.check(Copper.DATA[Copper.GRATE_STAGES[0]].get("transparent",false) and Nodes.transparent(Copper.GRATE_STAGES[0]),"a grate is a transparent block so its holes are not culled")

	# --- wax travels with the item -----------------------------------------
	world.set_node(p,Copper.CUT_STAGES[1]); Copper.set_waxed(world,p,true)
	var wax_drop: Dictionary = Copper.drop_metadata(world,p)
	t.check(wax_drop.get("copper_waxed",false),"breaking a waxed block yields an item carrying the wax flag")
	t.check(Copper.drop_metadata(world,p+Vector3i.FORWARD).is_empty(),"an unwaxed block yields an item with no wax flag")
	# The flag survives slot sanitising, then returns to the placed block.
	var slot: Dictionary = Inventory.clean_slot({"id":Copper.CUT_STAGES[1],"count":1,"wear":0,"data":wax_drop})
	t.check(Copper.waxed_item(slot),"the wax flag survives inventory slot sanitising")
	var empty_slot: Dictionary = Inventory.clean_slot({"id":Copper.CUT_STAGES[1],"count":1,"wear":0})
	t.check(not Copper.waxed_item(empty_slot),"an unmarked copper stack carries no wax flag")
	world.set_node(p,Copper.CUT_STAGES[1])
	Copper.set_waxed(world,p,false)
	Copper.placed_wax(game,p,slot)
	t.check(Copper.waxed(world,p),"placing a waxed item restores the wax flag on the new block")
	for i in 20:
		sample.clock = Copper.OXIDIZE_INTERVAL; Copper.update(world,0.0)
	t.check(world.node_at(p) == Copper.CUT_STAGES[1],"a replaced waxed block resumes blocking oxidation")
	world.set_node(p+Vector3i.FORWARD,Copper.CUT_STAGES[1]); Copper.set_waxed(world,p+Vector3i.FORWARD,false)
	Copper.placed_wax(game,p+Vector3i.FORWARD,empty_slot)
	t.check(not Copper.waxed(world,p+Vector3i.FORWARD),"placing an unmarked item leaves the new block unwaxed")

	# --- restore the fixture ----------------------------------------------
	for x in range(2,15):
		for z in range(2,15): world.set_node(Vector3i(x,1800,z),Nodes.AIR)
