extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game.gamemode = "survival"
	var home: Vector3 = game.player.position
	var totals: Dictionary = {"trail_ruins_common":[26,37],"trail_ruins_rare":[8,8],"desert_temple":[8,8],"ocean_ruins_cold":[10,15],"ocean_ruins_warm":[9,14]}
	for name in totals:
		var entries: Array = Archaeology.table_for(Archaeology.SUSPICIOUS_GRAVEL,name)
		t.check(entries.size() == totals[name][0] and Archaeology.total_weight(Archaeology.SUSPICIOUS_GRAVEL,name) == totals[name][1],"source entry count and total weight: "+name)
		t.check(entries.all(func(e):return e.id > 0 and Nodes.exists(e.id)),"every source archaeology reward resolves: "+name)
	t.check(Archaeology.table_for(Archaeology.SUSPICIOUS_GRAVEL,"").is_empty(),"untyped suspicious gravel has no invented loot")
	var rng := RandomNumberGenerator.new(); rng.seed = 9173
	var rare: Dictionary = {}; var candles: Dictionary = {}
	for i in 1600:
		var drop: Array = Archaeology.loot(Archaeology.SUSPICIOUS_GRAVEL,rng,"trail_ruins_rare")
		rare[drop[0][0]] = true
		drop = Archaeology.loot(Archaeology.SUSPICIOUS_GRAVEL,rng,"trail_ruins_common")
		if Candles.is_candle(drop[0][0]): candles[drop[0][0]] = true
	t.check(rare.size() == 8 and rare.has(ArmorTrims.FIRST+12),"rare gravel reaches all seven sherds and Wayfinder")
	t.check(candles.size() == 4 and candles.keys().all(func(id):return Candles.color_index(id) in [6,12,8,15]),"common gravel randomizes its one candle entry across the four source colors")
	t.check(Archaeology.UNROUTED_SHERDS.is_empty() and Archaeology.routed(9930),"trail, trial and desert-well routes cover every sherd")
	await materials(t,game)
	var world: VoxelWorld = game.world
	var origin: Vector3i = TrailRuins.nearest(world.generator,game.player.position)
	t.check(origin != Vector3i.ZERO and TrailRuins.eligible(world.generator,origin),"locate finds a naturally eligible trail ruin")
	if origin == Vector3i.ZERO: return
	var site: Dictionary = TrailRuins.assemble(world.generator,origin)
	var p := Vector3i.ZERO
	for at in site.states:
		if site.states[at].structure == "trail_ruins_rare": p = at; break
	t.check(p != Vector3i.ZERO,"a natural ruin contains rare suspicious gravel")
	if p == Vector3i.ZERO: return
	var coord := Vector2i(p.x >> 4,p.z >> 4)
	var result: Dictionary = world.generator.generate_column(coord,world.edits)
	world._apply_column(result)
	var key: String = VoxelWorld.station_key(p)
	t.check(world.node_at(p) == Archaeology.SUSPICIOUS_GRAVEL and world.block_states.get(key,{}).get("structure") == "trail_ruins_rare","generated column installs rare gravel and its correct loot type")
	var seed_value: int = world.block_states.get(key,{}).get("archaeology_seed",0)
	t.check(seed_value == int(site.states[p].archaeology_seed),"worker output retains the processor's loot seed")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Archaeology.BRUSH,"count":1,"wear":0}; game.inventory.selected = 0
	game.player.position = Vector3(p)+Vector3(0.5,2,2.5)
	t.check(Archaeology.brush(game,{"pos":p,"id":Archaeology.SUSPICIOUS_GRAVEL,"normal":Vector3i.UP}),"a survival brush begins excavating generated gravel")
	var reward: int = int(Archaeology.progress(world,p).loot_id)
	t.check(rare.has(reward),"natural rare gravel produces a source rare reward")
	Archaeology.update(world,5.1)
	# Updates are bounded one-second ticks; reaching the hide timeout resets the
	# visible stage, while the source seed fixes the next reveal's reward.
	for i in 5: Archaeology.update(world,1.0)
	t.check(Archaeology.strokes(world,p) == 0,"an unattended brush reveal hides after five seconds")
	Archaeology.brush(game,{"pos":p,"id":Archaeology.SUSPICIOUS_GRAVEL,"normal":Vector3i.UP})
	t.check(Archaeology.progress(world,p).loot_id == reward,"restarting a reveal cannot reroll its seeded reward")
	var cut: Vector3i = p+Vector3i.DOWN
	world.set_node(cut,DryTerrain.COARSE_DIRT)
	t.check(game.save_game("user://trail_ruins.json"),"an excavation and its active brush progress save to disk")
	game.set_process(true); game.load_world_data(game.read_save("user://trail_ruins.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(world.node_at(p) == Archaeology.SUSPICIOUS_GRAVEL and world.block_states.get(key,{}).get("archaeology_seed") == seed_value and Archaeology.progress(world,p).loot_id == reward,"reload preserves the exact gravel reward and reveal")
	t.check(world.node_at(cut) == DryTerrain.COARSE_DIRT,"saved player edits override source template blocks on reload")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Archaeology.BRUSH,"count":1,"wear":0}; game.inventory.selected = 0
	for i in 256:
		Archaeology.brush(game,{"pos":p,"id":Archaeology.SUSPICIOUS_GRAVEL,"normal":Vector3i.UP})
		if world.node_at(p) != Archaeology.SUSPICIOUS_GRAVEL: break
	t.check(world.node_at(p) == Nodes.GRAVEL and game.inventory.held().wear == 1,"completing the natural excavation converts gravel and wears the brush once")
	var dropped: int = 0
	for item in game.drops.get_children():
		if item is ItemDrop and item.item_id == reward: dropped += item.amount
	t.check(dropped == 1,"the saved reward is delivered exactly once")
	world._apply_column(world.generator.generate_column(coord,world.edits))
	t.check(world.node_at(p) == Nodes.GRAVEL,"regenerating a column does not recreate excavated suspicious gravel")
	for path in ["user://trail_ruins.json","user://trail_ruins.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	# Other lifecycle groups use the original test plot. Stream it back after
	# this test's real distant-world reload so they receive the same fixture.
	game.player.position = home; world.target = home; world.set_process(true)
	deadline = Time.get_ticks_msec()+90000
	while not world.area_ready(home) and Time.get_ticks_msec() < deadline: await t.process_frame
	world.set_process(false)
	t.check(world.area_ready(home),"returning from a distant ruin restores the original loaded area")

static func materials(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	inv.grid[0] = {"id":Nodes.DIRT,"count":1,"wear":0}; inv.grid[1] = {"id":Nodes.GRAVEL,"count":1,"wear":0}
	inv.grid[3] = {"id":Nodes.GRAVEL,"count":1,"wear":0}; inv.grid[4] = {"id":Nodes.DIRT,"count":1,"wear":0}
	var made: Dictionary = inv.take_grid_result("hand")
	t.check(made.get("id") == DryTerrain.COARSE_DIRT and made.count == 4,"two dirt and two gravel craft four coarse dirt")
	t.check(Nodes.hardness(DryTerrain.COARSE_DIRT) == 0.5 and Nodes.drop(DryTerrain.COARSE_DIRT) == DryTerrain.COARSE_DIRT,"coarse dirt retains its source hardness and drop")
	t.check(WoodTypes.soil(DryTerrain.COARSE_DIRT) and Bamboo.soil(DryTerrain.COARSE_DIRT) and FlowersExtra.soil_ok(FlowersExtra.ALLIUM,DryTerrain.COARSE_DIRT),"coarse dirt supports source trees, bamboo and flowers")
	var p := Vector3i(8,850,8); var world: VoxelWorld = game.world
	world.set_node(p,DryTerrain.COARSE_DIRT); world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.TOOLS+4,"count":1,"wear":0}; game.inventory.selected = 0
	t.check(DryTerrain.use(game,{"pos":p,"id":DryTerrain.COARSE_DIRT,"normal":Vector3i.UP}) and world.node_at(p) == Nodes.DIRT,"a first hoe use turns coarse dirt into dirt")
	t.check(Farmland.use(game,{"pos":p,"id":Nodes.DIRT,"normal":Vector3i.UP}) and world.node_at(p) == Farmland.DRY,"a second hoe use turns that dirt into farmland")
	var rng := RandomNumberGenerator.new(); rng.seed = 9167
	var outcomes: Dictionary = {}
	for i in 300:
		var result: Array = DryTerrain.harvest({"id":0},rng); outcomes[0 if result.is_empty() else result[0][1]] = true
	t.check(outcomes.has(0) and outcomes.has(1) and outcomes.has(2) and Nodes.drop(DryTerrain.DEAD_BUSH) == 0,"ordinary dead-bush harvests yield zero, one or two sticks without a generic fallback")
	t.check(DryTerrain.harvest({"id":Nodes.SHEARS}) == [[DryTerrain.DEAD_BUSH,1]] and Decor.accepts(DryTerrain.DEAD_BUSH),"shears recover a dead bush for planting and pots")
	t.check(Nodes.fuel_time(DryTerrain.DEAD_BUSH) == 5 and Fire.flammable(DryTerrain.DEAD_BUSH),"dead bushes burn with the source five-second fuel value")
	world.set_node(p,DryTerrain.COARSE_DIRT); world.set_node(p+Vector3i.UP,DryTerrain.DEAD_BUSH)
	t.check(world.raycast(Vector3(p)+Vector3(0.5,1.3,2),Vector3.FORWARD,2).get("id") == DryTerrain.DEAD_BUSH and world.raycast(Vector3(p)+Vector3(0.5,1.8,2),Vector3.FORWARD,2).is_empty(),"dead-bush targeting uses the source low selection box")
	t.check(PistonPush.diggable(DryTerrain.DEAD_BUSH) and PistonPush.unsticky(DryTerrain.DEAD_BUSH),"pistons break a dead bush instead of transporting it")
	var before: int = game.drops.get_child_count()
	world.set_node(p,Nodes.AIR)
	var only_sticks: bool = true
	for i in range(before,game.drops.get_child_count()):
		if game.drops.get_child(i).item_id != Nodes.STICK: only_sticks = false
	t.check(world.node_at(p+Vector3i.UP) == Nodes.AIR and only_sticks,"an unsupported dead bush drops only its source stick roll")
