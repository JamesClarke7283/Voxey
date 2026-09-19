extends RefCounted

# Earlier ordered suites retain buildings up to Y1404. Natural-growth checks
# need an open sky above those structures, not just a clear local planting box.
const PLOT_Y = 1500

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func mouse(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)

static func click(game: Node3D, at: Vector3) -> void:
	game.player.camera.look_at(at); game.player.use_cooldown = 0; game.player.use_latched = false
	mouse(game,true); mouse(game,false)

static func drops(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count

static func clear_neighbors(game: Node3D, p: Vector3i) -> void:
	for d in FruitCrops.CONNECT_ORDER:
		game.world.set_node(p+d,Nodes.AIR); game.world.set_node(p+d+Vector3i.DOWN,Nodes.DIRT)

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); PotionEffects.clear(game.player); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1; game.day_time = 0.30
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	for x in range(1,16):
		for z in range(1,16):
			for y in range(PLOT_Y-1,PLOT_Y+7): game.world.set_node(Vector3i(x,y,z),Nodes.DIRT if y == PLOT_Y-1 else Nodes.AIR)
	var p := Vector3i(8,PLOT_Y,8)
	t.check(Pasture.light(game.world,p,14) == 14,"fruit natural-growth plot has full skylight above retained earlier test structures")
	game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	for id in [FruitCrops.PUMPKIN_SEEDS,FruitCrops.MELON_SEEDS]:
		t.check(Nodes.exists(id) and Nodes.max_stack(id) == 64 and Composters.chance(id) == 30 and Farming.FOODS.chicken.has(id),"source "+Nodes.title(id)+" stacks64, composts30 and feeds/tempts chickens")
	for row in [[Nodes.PUMPKIN,FruitCrops.PUMPKIN_SEEDS,4],[Nodes.MELON_SLICE,FruitCrops.MELON_SEEDS,1]]:
		for i in 9: game.inventory.grid[i] = {"id":row[0] if i == 0 else 0,"count":1 if i == 0 else 0,"wear":0}
		var result: Dictionary = game.inventory.take_grid_result("hand")
		t.check(int(result.get("id",0)) == row[1] and int(result.get("count",0)) == row[2],"actual single-item recipe converts "+Nodes.title(row[0])+" to its source seeds")
		var index: int = game.inventory.recipe_index(row[1]); held(game,row[0])
		t.check(index >= 0 and game.inventory.craft(index,"hand") and game.inventory.count_item(row[1]) == row[2],"recipe-book crafting also makes source "+Nodes.title(row[1]))
	for i in 9: game.inventory.grid[i] = {"id":Nodes.MELON_SLICE,"count":1,"wear":0}
	t.check(game.inventory.take_grid_result("table").get("id",0) == Nodes.MELON,"nine melon slices reconstruct a whole melon through the real3x3 recipe")
	for i in 9: game.inventory.grid[i] = {"id":0,"count":0,"wear":0}
	game.inventory.grid[0] = {"id":FruitCrops.CARVED,"count":1,"wear":0}; game.inventory.grid[3] = {"id":Nodes.TORCH,"count":1,"wear":0}
	t.check(game.inventory.take_grid_result("hand").get("id",0) == FruitCrops.JACK,"carved pumpkin above a torch crafts a jack o'lantern")
	game.inventory.grid_to_inventory()
	for seed_item in [FruitCrops.PUMPKIN_SEEDS,FruitCrops.MELON_SEEDS]:
		game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.DOWN,Nodes.DIRT); held(game,seed_item,3)
		click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
		t.check(game.world.node_at(p) == Nodes.AIR and game.inventory.count_item(seed_item) == 3,"actual use refuses to plant "+Nodes.title(seed_item)+" on untilled dirt")
		game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
		click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
		t.check(game.world.node_at(p) == FruitCrops.base(seed_item) and game.inventory.count_item(seed_item) == 2,"actual use plants first-stage "+Nodes.title(seed_item)+" and consumes one seed")
		game.world.set_node(p,Nodes.AIR); game.gamemode = "creative"; click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
		t.check(game.world.node_at(p) == FruitCrops.base(seed_item) and game.inventory.count_item(seed_item) == 2,"creative planting preserves "+Nodes.title(seed_item))
		game.gamemode = "survival"
		var base: int = FruitCrops.base(seed_item)
		for stage in range(1,9):
			game.world.set_node(p,base+stage-1)
			var hit: Dictionary = game.world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
			var mesh: Array = BlockMesher._empty(); FruitCrops.mesh(mesh,Vector3.ZERO,base+stage-1)
			t.check(not hit.is_empty() and hit.pos == p and absf(hit.point.y-(p.y+stage/8.0)) < 0.001 and not Nodes.solid(base+stage-1) and not mesh[0].is_empty(),"source "+Nodes.title(seed_item)+" stage"+str(stage)+" has correct selectable height, no body collision and original art")
		clear_neighbors(game,p)
		for d in FruitCrops.DIRECTIONS:
			game.world.set_node(p,base+7); game.world.set_node(p+d,FruitCrops.fruit(base))
			t.check(FruitCrops.attached(game.world.node_at(p)) and FruitCrops.direction(game.world.node_at(p)) == d,"mature "+Nodes.title(seed_item)+" immediately attaches toward "+str(d))
			game.world.set_node(p+d,Nodes.AIR)
			t.check(game.world.node_at(p) == base+7,"removing attached fruit frees "+Nodes.title(seed_item)+" for another crop")
		game.world.set_node(p+Vector3i.LEFT,FruitCrops.fruit(base)); game.world.set_node(p+Vector3i.RIGHT,FruitCrops.fruit(base)); game.world.set_node(p+Vector3i.LEFT,Nodes.AIR)
		t.check(FruitCrops.direction(game.world.node_at(p)) == Vector3i.RIGHT,"detached "+Nodes.title(seed_item)+" reconnects to another existing fruit")
		clear_neighbors(game,p)
		game.world.set_node(p,base); held(game,Nodes.BONE_MEAL,10); seed(3382)
		click(game,Vector3(p)+Vector3(0.5,0.06,0.5))
		var after: int = FruitCrops.stage(game.world.node_at(p))
		t.check(after >= 4 and after <= 7 and game.inventory.count_item(Nodes.BONE_MEAL) == 9,"actual bone meal follows source2..5 plus interval rounding on "+Nodes.title(seed_item))
		game.world.set_node(p,base+7); click(game,Vector3(p)+Vector3(0.5,0.5,0.5))
		t.check(game.inventory.count_item(Nodes.BONE_MEAL) == 9 and not FruitCrops.attached(game.world.node_at(p)),"mature "+Nodes.title(seed_item)+" rejects bone meal without consuming it or creating fruit")
		for d in FruitCrops.CONNECT_ORDER: game.world.set_node(p+d,Nodes.STONE)
		t.check(not FruitCrops.grow_fruit(game.world,p),"a mature "+Nodes.title(seed_item)+" cannot grow into occupied neighbors")
		var target: Vector3i = p+Vector3i.RIGHT
		game.player.position = Vector3(target)+Vector3(0.5,0.01,0.5)
		game.world.set_node(target,Nodes.AIR); game.world.set_node(target+Vector3i.DOWN,Nodes.FARMLAND)
		t.check(FruitCrops.grow_fruit(game.world,p) and game.world.node_at(target) == FruitCrops.fruit(base) and game.world.node_at(target+Vector3i.DOWN) == Nodes.DIRT and game.world.node_at(p+Vector3i.DOWN) == Nodes.FARMLAND,"source fruit growth uses the only eligible neighbor and dirtifies that destination farmland only")
		t.check(not game.world.intersects(game.player.position,0.29,1.8) and game.player.position.y >= p.y,"growing fruit safely displaces an intersecting player without pushing through surrounding walls")
		game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5)
		t.check(not FruitCrops.grow_fruit(game.world,p),"attached "+Nodes.title(seed_item)+" cannot produce a second simultaneous fruit")
		clear_neighbors(game,p); game.world.set_node(p,Nodes.AIR)
	# Both source seeds occur in real dungeon supply rolls with original weights.
	var found_seeds: Dictionary = {}; var valid_seed_amounts: bool = true; var loot_rng := RandomNumberGenerator.new(); loot_rng.seed = 917
	for i in 600:
		var stack: Dictionary = Dungeons.weighted(loot_rng,Dungeons.SUPPLIES)
		if FruitCrops.is_seed(int(stack.get("id",0))):
			found_seeds[stack.id] = true
			valid_seed_amounts = valid_seed_amounts and stack.count >= 2 and stack.count <= 4
	t.check(valid_seed_amounts and found_seeds.has(FruitCrops.PUMPKIN_SEEDS) and found_seeds.has(FruitCrops.MELON_SEEDS),"both fruit seeds are obtainable from source-weighted dungeon supplies")
	# Real scheduled growth matures and fruits a hydrated crop without bone meal.
	game.world.set_node(p+Vector3i.DOWN,Farmland.WET); game.world.set_node(p+Vector3i(3,0,3),Nodes.WATER)
	FruitCrops.runtime(game.world).rng.seed = 5629
	game.world.set_node(p,FruitCrops.PUMPKIN_STEM)
	for i in 500:
		game.day_time += 30.0/1200.0; FruitCrops.update(game.world,30)
		if FruitCrops.attached(game.world.node_at(p)): break
	t.check(FruitCrops.attached(game.world.node_at(p)) and game.world.node_at(p+FruitCrops.direction(game.world.node_at(p))) == Nodes.PUMPKIN,"source30-second scheduled growth produces an actual harvestable fruit without bone meal")
	game.world.set_node(p+Vector3i(3,0,3),Nodes.AIR); clear_neighbors(game,p); game.world.set_node(p,Nodes.AIR)
	FruitCrops.reset(game.world); game.world.set_node(p,FruitCrops.PUMPKIN_STEM); FruitCrops.register_job(game.world,p,"age")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p,FruitCrops.PUMPKIN_STEM)
	FruitCrops.update(game.world,0)
	t.check(FruitCrops.stage(game.world.node_at(p)) == 1,"removed/replanted stems cannot inherit an old queued growth action")
	# Current source hydration and the first-call growth interval behavior.
	var hydration_weather: Variant = game.world.adventure_state.get("weather")
	game.world.adventure_state.weather = "clear" # Isolate soil drying from earlier weather fixtures.
	game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
	var wet: Vector3i = p+Vector3i(4,0,4); game.world.set_node(wet,Nodes.WATER)
	Farmland.advance(game.world,p+Vector3i.DOWN)
	t.check(FruitCrops.hydrated(game.world,p),"water at the outer corner and upper level of the source9x2x9 footprint hydrates soil for a stem")
	game.world.set_node(wet,Nodes.AIR); game.world.set_node(wet+Vector3i.UP,Nodes.WATER)
	Farmland.advance(game.world,p+Vector3i.DOWN)
	t.check(not FruitCrops.hydrated(game.world,p),"soil dries when the only water is above the source hydration footprint")
	game.world.set_node(wet+Vector3i.UP,Nodes.AIR)
	if hydration_weather == null: game.world.adventure_state.erase("weather")
	else: game.world.adventure_state.weather = hydration_weather
	var rng := RandomNumberGenerator.new(); rng.seed = 81
	var dry_growth: int = 0
	for i in 200:
		game.world.set_node(p,Nodes.AIR); game.world.set_node(p,FruitCrops.PUMPKIN_STEM)
		if FruitCrops.grow(game.world,p,1,false,true,rng): dry_growth += 1
	t.check(dry_growth >= 8 and dry_growth <= 35,"dry farmland applies the source one-in-ten early growth throttle")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p,FruitCrops.MELON_STEM)
	t.check(FruitCrops.grow(game.world,p) and FruitCrops.stage(game.world.node_at(p)) == 3,"fresh hydrated growth advances source1+ceil(.1) stages")
	game.world.set_node(p,FruitCrops.MELON_STEM); FruitCrops.metadata(game.world,p).last_time = FruitCrops.now(game.world)-450
	t.check(FruitCrops.grow(game.world,p) and FruitCrops.stage(game.world.node_at(p)) == 5,"saved elapsed time advances source1+ceil(450/150) stages on catch-up")
	# Enclose the plot so artificial light thresholds are measured precisely.
	for x in range(1,16):
		for z in range(1,16): game.world.set_node(Vector3i(x,PLOT_Y+6,z),Nodes.STONE)
	for y in range(PLOT_Y,PLOT_Y+6):
		for offset in range(1,16):
			for cell in [Vector3i(1,y,offset),Vector3i(15,y,offset),Vector3i(offset,y,1),Vector3i(offset,y,15)]: game.world.set_node(cell,Nodes.STONE)
	game.world.set_node(p,FruitCrops.MELON_STEM); game.world.set_node(p+Vector3i.RIGHT*4,Nodes.GLOWSTONE)
	t.check(Pasture.light(game.world,p) == 10 and FruitCrops.grow(game.world,p),"stem growth permits source light10")
	game.world.set_node(p,FruitCrops.MELON_STEM+7)
	t.check(not FruitCrops.grow_fruit(game.world,p),"fruit growth requires greater than10 light")
	game.world.set_node(p+Vector3i.RIGHT*4,Nodes.AIR); game.world.set_node(p+Vector3i.RIGHT*3,Nodes.GLOWSTONE)
	t.check(Pasture.light(game.world,p) == 11 and FruitCrops.grow_fruit(game.world,p),"fruit growth succeeds at source light11")
	clear_neighbors(game,p); game.world.set_node(p+Vector3i.RIGHT*3,Nodes.AIR); game.world.set_node(p,FruitCrops.PUMPKIN_STEM)
	t.check(not FruitCrops.grow(game.world,p) and FruitCrops.grow(game.world,p,2,true),"fresh dark stems cannot grow naturally but can use source bone meal")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	t.check(FruitCrops.is_stem(game.world.node_at(p)),"existing stems retain source attached-node support on any walkable solid block")
	game.world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(game.world.node_at(p) == Nodes.AIR and not FruitCrops.runtime(game.world).cells.has(p),"removing supporting terrain destroys the stem and removes active growth tracking")
	game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
	# Distribution tests intentionally exercise the source sequential rarity table.
	var quantities: Dictionary = {}; var seed_amounts: Dictionary = {0:0,1:0,2:0,3:0}; var fortune: Dictionary = {}
	for i in 10000:
		var amount: int = FruitCrops.harvest(Nodes.MELON,{},rng)[0][1]; quantities[amount] = int(quantities.get(amount,0))+1
		var seed_drop: Array = FruitCrops.harvest(FruitCrops.PUMPKIN_STEM+7,{},rng); seed_amounts[0 if seed_drop.is_empty() else seed_drop[0][1]] += 1
		amount = FruitCrops.harvest(Nodes.MELON,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Fortune":3}}},rng)[0][1]; fortune[amount] = int(fortune.get(amount,0))+1
	t.check(quantities.size() == 5 and quantities.has(3) and quantities.has(7) and quantities[3] > quantities[7]*3,"ordinary melon harvesting follows source biased3..7-slice drops")
	t.check(seed_amounts[0] > 7700 and seed_amounts[0] < 8300 and seed_amounts[3] > 30 and seed_amounts[3] < 110,"all stem stages use source rare0..3 seed drops instead of a guaranteed seed")
	t.check(fortune.size() == 7 and fortune.has(3) and fortune.has(9) and float(fortune[9])/fortune[8] > 1.6 and float(fortune[9])/fortune[8] < 2.5,"FortuneIII rolls uniform3..10 then caps at9 slices exactly as source")
	t.check(FruitCrops.harvest(Nodes.MELON,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Silk Touch":1}}}) == [[Nodes.MELON,1]],"Silk Touch preserves the whole source melon")
	for tool_data in [{},{"enchantments":{"Silk Touch":1}},{"enchantments":{"Fortune":3}}]:
		game.world.set_node(p,Nodes.MELON); held(game,Nodes.TOOLS+16,1,tool_data)
		var before: int = drops(game,Nodes.MELON_SLICE); var whole: int = drops(game,Nodes.MELON)
		game.break_node(p,Nodes.MELON,Nodes.TOOLS+16)
		t.check((drops(game,Nodes.MELON) == whole+1 if tool_data.get("enchantments",{}).has("Silk Touch") else drops(game,Nodes.MELON_SLICE)-before in range(3,10)),"actual melon mining dispatches source drops and enchantments "+str(tool_data))
	held(game,0,0); var mined_seeds: int = drops(game,FruitCrops.PUMPKIN_SEEDS); seed(428)
	for i in 100:
		game.world.set_node(p,FruitCrops.PUMPKIN_STEM+7); game.break_node(p,FruitCrops.PUMPKIN_STEM+7,0)
	t.check(drops(game,FruitCrops.PUMPKIN_SEEDS)-mined_seeds < 65,"actual stem mining preserves empty source outcomes instead of falling back to one guaranteed seed")
	var washed: int = drops(game,FruitCrops.PUMPKIN_SEEDS); seed(649)
	game.world.set_node(p+Vector3i.RIGHT,Nodes.WATER)
	for i in 100:
		game.world.set_node(p,FruitCrops.PUMPKIN_STEM); game.world.fluids.settle(p,Nodes.WATER)
	t.check(Fluids.water(game.world.node_at(p)) and drops(game,FruitCrops.PUMPKIN_SEEDS)-washed < 65,"real water flow uproots stems using rare source seed drops instead of guaranteed seeds")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR); game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.LEFT,Nodes.LAVA)
	washed = drops(game,FruitCrops.PUMPKIN_SEEDS)
	for i in 20:
		game.world.set_node(p,FruitCrops.PUMPKIN_STEM); game.world.fluids.settle(p,Nodes.LAVA)
	t.check(Fluids.lava(game.world.node_at(p)) and drops(game,FruitCrops.PUMPKIN_SEEDS) == washed,"real lava flow destroys stems without dropping seeds")
	game.world.set_node(p+Vector3i.LEFT,Nodes.AIR); game.world.set_node(p,Nodes.AIR)
	# Carving acts only on horizontal faces, returns four seeds and wears shears.
	game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5); game.world.set_node(p,Nodes.PUMPKIN); held(game,Nodes.SHEARS)
	var seeds_before: int = drops(game,FruitCrops.PUMPKIN_SEEDS)
	click(game,Vector3(p)+Vector3(0.5,0.5,0.99))
	t.check(FruitCrops.is_pumpkin_head(game.world.node_at(p)) and FruitCrops.FACES[FruitCrops.turn(game.world.node_at(p))] == Vector3i.BACK and drops(game,FruitCrops.PUMPKIN_SEEDS) == seeds_before+4 and game.inventory.held().wear == 1,"actual side shearing carves the clicked face, drops four seeds and wears shears once")
	click(game,Vector3(p)+Vector3(0.5,0.5,0.99))
	t.check(drops(game,FruitCrops.PUMPKIN_SEEDS) == seeds_before+4 and game.inventory.held().wear == 1,"already-carved pumpkins cannot duplicate seeds or tool wear")
	game.world.set_node(p,Nodes.PUMPKIN); game.player.position = Vector3(8.5,PLOT_Y+2,8.5)
	click(game,Vector3(p)+Vector3(0.5,0.99,0.5))
	t.check(game.world.node_at(p) == Nodes.PUMPKIN and game.inventory.held().wear == 1,"using shears on a pumpkin top does not carve it")
	game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5); game.gamemode = "creative"
	click(game,Vector3(p)+Vector3(0.5,0.5,0.99))
	t.check(drops(game,FruitCrops.PUMPKIN_SEEDS) == seeds_before+8 and game.inventory.held().wear == 1,"creative carving still drops four source seeds without shears wear")
	game.gamemode = "survival"; game.world.set_node(p,Nodes.AIR); held(game,FruitCrops.JACK,2)
	click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
	t.check(FruitCrops.lit(game.world.node_at(p)) and game.inventory.count_item(FruitCrops.JACK) == 1 and Pasture.emission(game.world,p) == 14,"actual use places an oriented source jack o'lantern emitting14 light")
	var jack_id: int = game.world.node_at(p); var light: int = Pasture.block_light(game.world,p+Vector3i.RIGHT,1)
	t.check(light == 13 and FruitCrops.canonical(jack_id) == FruitCrops.JACK,"placed jack o'lantern light propagates through the real artificial-light index")
	# Environmental piston harvest ignores the player's held enchantments/mode.
	game.gamemode = "creative"; held(game,Nodes.TOOLS+16,1,{"enchantments":{"Silk Touch":1}})
	var piston_cell := Vector3i(11,PLOT_Y,8); game.world.set_node(piston_cell,Nodes.MELON)
	var slices_before: int = drops(game,Nodes.MELON_SLICE); var melon_before: int = drops(game,Nodes.MELON)
	t.check(FruitCrops.piston_break(game.world,piston_cell) and drops(game,Nodes.MELON_SLICE)-slices_before in range(3,8) and drops(game,Nodes.MELON) == melon_before,"piston melon harvest uses unenchanted source drops even with creative player's held Silk Touch")
	t.check(not FruitCrops.piston_break(game.world,piston_cell),"repeated piston removal cannot duplicate fruit loot")
	game.gamemode = "survival"
	var carved_cell := Vector3i(8,PLOT_Y,10); game.world.set_node(carved_cell,Nodes.AIR); held(game,FruitCrops.CARVED,2)
	click(game,Vector3(carved_cell)+Vector3(0.5,-0.01,0.5))
	t.check(FruitCrops.canonical(game.world.node_at(carved_cell)) == FruitCrops.CARVED and game.inventory.count_item(FruitCrops.CARVED) == 1 and not PumpkinHelmet.worn(game.player),"ordinary actual block use places carved pumpkin instead of automatically wearing it")
	game.world.set_node(carved_cell,Nodes.AIR)
	# A helmet occupies one slot, contributes no defense and cannot wear out.
	game.player.armor_slots = [{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0}]
	held(game,FruitCrops.CARVED,64); game.hud.cursor = {"id":0,"count":0,"wear":0}; game.hud.shift_mode = true
	game.hud._slot_click(0,false,false); game.hud.shift_mode = false
	t.check(PumpkinHelmet.worn(game.player) and game.player.armor_slots[0].count == 1 and game.inventory.count_item(FruitCrops.CARVED) == 63 and game.player.armor_points() == 0 and Nodes.durability(FruitCrops.CARVED) == 0,"real inventory Shift-click equips only one pumpkin from64 with zero defense and infinite durability")
	game.player.health = 20; game.player.damage_cooldown = 0; game.player.hurt(1,false,Vector3.INF,"contact")
	t.check(game.player.armor_slots[0].wear == 0 and game.player.health == 19,"pumpkin helmet does not absorb damage or gain wear")
	var old_helmet: int = Nodes.armor_id(1,0)
	game.player.armor_slots[0] = {"id":old_helmet,"count":1,"wear":7,"data":{"custom_name":"Old helmet"}}
	game.hud.cursor = {"id":FruitCrops.CARVED,"count":64,"wear":0}; game.hud._slot_click(0,false,false,false,true)
	t.check(PumpkinHelmet.worn(game.player) and game.player.armor_slots[0].count == 1 and game.hud.cursor.count == 63 and game.inventory.count_item(old_helmet) == 1 and game.inventory.slots.any(func(slot): return slot.id == old_helmet and slot.wear == 7 and slot.get("data",{}).get("custom_name","") == "Old helmet"),"actual occupied armor-slot swap preserves remaining pumpkins and the old helmet's metadata")
	game.hud.return_cursor()

	var enderman: Creature = game.spawn_creature("enderman",Vector3(8.5,PLOT_Y+0.01,10.5))
	enderman.set_physics_process(false); game.player.position = Vector3(8.5,PLOT_Y+0.01,13.5); game.player.camera.look_at(enderman.center())
	enderman._physics_process(0.001)
	t.check(not enderman.provoked,"actual Enderman gaze update ignores a player wearing carved pumpkin")
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}; enderman._physics_process(0.001)
	t.check(enderman.provoked,"same unprotected gaze provokes the Enderman")
	game.player.armor_slots[0] = {"id":FruitCrops.CARVED,"count":1,"wear":0}; enderman.provoked = false; enderman.hit(1,game.player.position)
	t.check(enderman.provoked,"pumpkin protection does not prevent retaliation after actual damage")
	enderman.queue_free(); await t.process_frame
	# Save/load fixtures, including stem catch-up metadata and orientation.
	var stem := Vector3i(5,PLOT_Y,5); game.world.set_node(stem+Vector3i.DOWN,Nodes.FARMLAND); game.world.set_node(stem,FruitCrops.PUMPKIN_STEM)
	FruitCrops.metadata(game.world,stem).last_time = FruitCrops.now(game.world)-300
	FruitCrops.metadata(game.world,stem).light_count = 3; FruitCrops.metadata(game.world,stem).light_total = 0
	var saved_meta: Dictionary = FruitCrops.metadata(game.world,stem).duplicate(true)
	game.save_game("user://fruit-crop-check.json"); var saved: Dictionary = game.read_save("user://fruit-crop-check.json")
	game.set_process(true); game.world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(PumpkinHelmet.worn(game.player) and game.player.armor_slots[0].count == 1,"actual save/load restores worn carved pumpkin without turning it into a full stack")
	t.check(game.world.node_at(p) == jack_id and game.world.node_at(stem) == FruitCrops.PUMPKIN_STEM and FruitCrops.metadata(game.world,stem).get("last_time",0) >= saved_meta.last_time,"actual save/load preserves oriented lantern and saved dark-stem growth metadata")
	FruitCrops.unload(game.world,Vector2i(0,0))
	t.check(not FruitCrops.runtime(game.world).cells.has(stem) and FruitCrops.runtime(game.world).jobs.all(func(job): return job.pos != stem),"unloading a column removes its stem simulation jobs without deleting saved crop state")
	FruitCrops.registered(game.world,stem,true); FruitCrops.registered(game.world,stem,true)
	t.check(FruitCrops.runtime(game.world).jobs.filter(func(job):return job.pos == stem).size() == 1,"repeated load registration queues only one source catch-up action per stem")
	FruitCrops.reset(game.world)
	t.check(not game.world.has_meta("fruit_crops"),"world/dimension reset clears all runtime crop indexes")
	game.state = "playing"; game.player.set_process(false); game.player.set_physics_process(false)
