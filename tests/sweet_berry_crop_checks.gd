extends RefCounted

const PLOT_Y = 2250

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false
	game.player.crouching = false

static func target(game: Node3D, p: Vector3i, normal: Vector3i = Vector3i.UP) -> void:
	game.player.target = {"pos":p,"normal":normal,"id":game.world.node_at(p),"distance":1.0,"point":Vector3(p)+Vector3.ONE*0.5}

static func fresh(world: VoxelWorld, p: Vector3i, id: int) -> void:
	world.set_node(p,Nodes.AIR); world.set_node(p,id)

static func drops(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))
static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1; game.day_time = 0.3
	game.player.set_process(false); game.player.set_physics_process(false)
	game.world.active = false; game.world.set_process(false)
	var world: VoxelWorld = game.world; var p := Vector3i(8,PLOT_Y,8)
	t.check(ensure(game,p),"berry plot column is loaded")
	for x in range(5,12):
		for z in range(5,12):
			for y in range(PLOT_Y-2,PLOT_Y+5): world.set_node(Vector3i(x,y,z),Nodes.GRASS if y == PLOT_Y-1 else Nodes.AIR)
	planting(t,game,p)
	harvesting(t,game,p)
	bone_meal_dispatch(t,game,p)
	growth(t,game,p)
	environment(t,game,p)
	geometry_and_acquisition(t,game,p)
	await persistence(t,game,p)
	world = game.world
	for x in range(5,12):
		for z in range(5,12):
			for y in range(PLOT_Y-2,PLOT_Y+5): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.state = "playing"

static func planting(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	t.check(SweetBerryCrops.STAGES == [567,568,569,570] and SweetBerryCrops.BERRY == 775,"existing bush and berry save IDs remain unchanged")
	for host in [Nodes.GRASS,Nodes.DIRT,DryTerrain.COARSE_DIRT,Farmland.DRY,Farmland.WET,LushCaves.MOSS]:
		world.set_node(p+Vector3i.DOWN,host); fresh(world,p,Nodes.AIR); held(game,SweetBerryCrops.BERRY,3)
		game.player.hunger = 10; target(game,p+Vector3i.DOWN)
		game.survival.use()
		t.check(world.node_at(p) == 567 and game.inventory.count_item(775) == 2 and game.player.hunger == 10 and game.player.eating.is_empty(),"actual top-face use plants on "+Nodes.title(host)+" without eating")
	world.set_node(p+Vector3i.DOWN,Nodes.GRASS); fresh(world,p,Nodes.AIR); held(game,775,2); game.gamemode = "creative"; target(game,p+Vector3i.DOWN); game.survival.use()
	t.check(world.node_at(p) == 567 and game.inventory.count_item(775) == 2,"creative planting does not consume berries")
	game.gamemode = "survival"
	for host in [Nodes.STONE,VillageContent.SWAMP_GRASS,VillageContent.PATH]:
		world.set_node(p+Vector3i.DOWN,host); fresh(world,p,Nodes.AIR); held(game,775,3); target(game,p+Vector3i.DOWN); game.survival.use()
		t.check(world.node_at(p) == Nodes.AIR and game.inventory.count_item(775) == 3,"source planting rejects non-host "+Nodes.title(host))
	world.set_node(p+Vector3i.DOWN,Nodes.GRASS)
	for normal in [Vector3i.RIGHT,Vector3i.DOWN]:
		fresh(world,p,Nodes.AIR); held(game,775,3); target(game,p+Vector3i.DOWN,normal); game.survival.use()
		t.check(world.node_at(p) == Nodes.AIR,"side/bottom faces cannot plant sweet berries")
	fresh(world,p,Nodes.STONE); held(game,775,3); target(game,p+Vector3i.DOWN); game.survival.use()
	t.check(world.node_at(p) == Nodes.STONE and game.inventory.count_item(775) == 3,"planting requires literal air, not a replaceable fallback")

static func harvesting(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Nodes.GRASS)
	for s in 4:
		t.check(SweetBerryCrops.harvest(567+s).is_empty() if s < 2 else SweetBerryCrops.harvest(567+s)[0][0] == 775,"source break table for stage %d"%s)
	var rng := RandomNumberGenerator.new(); rng.seed = 5831
	var counts: Array = [{},{}]
	for i in 2000:
		for s in [2,3]:
			var amount: int = SweetBerryCrops.harvest(567+s,rng)[0][1]; var table: Dictionary = counts[s-2]
			table[amount] = int(table.get(amount,0))+1
	t.check(counts[0].size() == 2 and int(counts[0].get(1,0)) in range(900,1101) and int(counts[0].get(2,0)) in range(900,1101),"stage-two break drops one or two berries with equal source probability")
	t.check(counts[1].size() == 2 and int(counts[1].get(2,0)) in range(900,1101) and int(counts[1].get(3,0)) in range(900,1101),"stage-three break drops two or three berries with equal source probability")
	for s in [2,3]:
		fresh(world,p,567+s); var meta: Dictionary = SweetBerryCrops.metadata(world,p)
		meta.last_time = 1234.0; meta.light_count = 7; meta.light_total = 91
		held(game,Nodes.TORCH,9); var before: int = drops(game,775); target(game,p); game.survival.use()
		var expected: Array = [s-1,s]
		t.check(world.node_at(p) == 568 and drops(game,775)-before in expected and game.inventory.count_item(Nodes.TORCH) == 9,"right click harvests stage %d and resets to stage one without consuming the held stack"%s)
		t.check(SweetBerryCrops.metadata(world,p).get("last_time",0) == 1234.0 and SweetBerryCrops.metadata(world,p).get("light_count",0) == 7,"right-click swap preserves source growth metadata")
	# The real break route must not pass through the legacy crop table or Fortune.
	fresh(world,p,569); held(game,Nodes.TOOLS+16,1,{"enchantments":{"Fortune":3,"Silk Touch":1}}); var before: int = drops(game,775)
	game.break_node(p,569,Nodes.TOOLS+16)
	t.check(world.node_at(p) == Nodes.AIR and drops(game,775)-before in [1,2],"actual enchanted mining uses the untouched sweet-berry drop table")
	for s in [0,1]:
		fresh(world,p,567+s); before = drops(game,775); game.break_node(p,567+s,0)
		t.check(drops(game,775) == before,"breaking pre-fruit stage %d drops nothing"%s)
	fresh(world,p,570); game.gamemode = "creative"; before = drops(game,775); game.break_node(p,570,0)
	t.check(drops(game,775) == before,"creative breaking does not duplicate berries")
	game.gamemode = "survival"

static func bone_meal_dispatch(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Farmland.WET)
	for s in [0,1]:
		fresh(world,p,567+s); held(game,Nodes.BONE_MEAL,4); var before: int = drops(game,775); target(game,p); game.survival.use()
		t.check(world.node_at(p) == 567+s+2 and game.inventory.count_item(Nodes.BONE_MEAL) == 3 and drops(game,775) == before,"actual bone meal grows pre-fruit stage %d by two fresh stages and consumes once"%s)
	for s in [2,3]:
		fresh(world,p,567+s); held(game,Nodes.BONE_MEAL,4); var before: int = drops(game,775); target(game,p); game.survival.use()
		t.check(world.node_at(p) == 567+s and game.inventory.count_item(Nodes.BONE_MEAL) == 4 and drops(game,775) == before,"fruit-stage on_rightclick intercepts bone meal without growth, consumption or harvest")
	# Reaching the callback while sneaking follows its missing Lua return: the
	# dispatcher consumes even when the mature plant cannot grow.
	fresh(world,p,569); held(game,Nodes.BONE_MEAL,4); game.player.crouching = true; target(game,p); game.survival.use()
	t.check(world.node_at(p) == 570 and game.inventory.count_item(Nodes.BONE_MEAL) == 3,"sneaking reaches the stage-two bone-meal callback")
	fresh(world,p,570); held(game,Nodes.BONE_MEAL,4); game.player.crouching = true; target(game,p); game.survival.use()
	t.check(world.node_at(p) == 570 and game.inventory.count_item(Nodes.BONE_MEAL) == 3,"mature callback consumes because its source return is nil")
	game.player.crouching = false

static func growth(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Farmland.WET)
	t.check(SweetBerryCrops.INTERVAL == 68.0 and SweetBerryCrops.CHANCE == 3 and SweetBerryCrops.PERIOD == 204.0,"source 68-second one-in-three growth registration")
	fresh(world,p,567)
	t.check(SweetBerryCrops.grow(world,p) and world.node_at(p) == 569,"fresh shared arithmetic advances stage zero to stage two")
	fresh(world,p,568)
	t.check(SweetBerryCrops.grow(world,p) and world.node_at(p) == 570,"fresh shared arithmetic advances stage one to mature")
	world.set_node(p+Vector3i.DOWN,Nodes.GRASS); var rng := RandomNumberGenerator.new(); rng.seed = 6813; var grew: int = 0
	for i in 1000:
		fresh(world,p,567)
		if SweetBerryCrops.grow(world,p,1,false,true,rng): grew += 1
	t.check(grew in range(65,136),"grass uses the same dry-support one-in-ten early-growth throttle as other non-wet hosts")
	fresh(world,p,567); SweetBerryCrops.grow(world,p,1,false,true,rng)
	t.check(SweetBerryCrops.metadata(world,p).has("last_time"),"a rejected dry roll still writes source time/light history")
	game.day_time = 1.0 # Keep the saved two-period timestamps positive; last<1 means fresh history.
	fresh(world,p,567); SweetBerryCrops.metadata(world,p).last_time = SweetBerryCrops.now(world)-408
	t.check(SweetBerryCrops.grow(world,p) and world.node_at(p) == 570,"saved elapsed time participates in loaded catch-up arithmetic")
	game.daylight = 0.0; world.dimension = "nether"
	fresh(world,p,567); var meta: Dictionary = SweetBerryCrops.metadata(world,p)
	meta.last_time = SweetBerryCrops.now(world)-408; meta.light_count = 10; meta.light_total = 0
	t.check(not SweetBerryCrops.grow(world,p) and world.node_at(p) == 567,"zero historical light blocks long catch-up")
	game.daylight = 1.0; world.dimension = "overworld"
	fresh(world,p,567); meta = SweetBerryCrops.metadata(world,p)
	meta.last_time = SweetBerryCrops.now(world)-408; meta.light_count = 10; meta.light_total = 140
	t.check(SweetBerryCrops.grow(world,p) and world.node_at(p) == 570,"bright saved history permits catch-up")
	fresh(world,p,567); SweetBerryCrops.metadata(world,p).last_time = SweetBerryCrops.now(world)+306
	t.check(SweetBerryCrops.grow(world,p) and world.node_at(p) == 567 and SweetBerryCrops.metadata(world,p).is_empty(),"successful same-stage source placement clears old growth history")
	world.set_node(p+Vector3i.DOWN,Farmland.WET); SweetBerryCrops.reset(world); fresh(world,p,567); SweetBerryCrops.runtime(world).rng.seed = 775
	for i in 500:
		game.day_time += 68.0/1200.0; SweetBerryCrops.update(world,68.0)
		if world.node_at(p) == 570: break
	t.check(world.node_at(p) == 570 and not world.growth.has(p),"scheduled source growth matures without the retired simplified crop timer")
	SweetBerryCrops.registered(world,p,true); SweetBerryCrops.registered(world,p,true)
	t.check(SweetBerryCrops.runtime(world).jobs.filter(func(job): return job.pos == p).size() <= 1,"loaded registration never duplicates a catch-up job")

static func environment(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Nodes.STONE); fresh(world,p,569)
	var before: int = drops(game,775); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and drops(game,775)-before in [1,2],"attached-node support loss drops the exact stage-two harvest")
	world.set_node(p+Vector3i.DOWN,Nodes.GRASS); fresh(world,p,568); before = drops(game,775); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and drops(game,775) == before,"support loss drops nothing from a pre-fruit bush")
	world.set_node(p+Vector3i.DOWN,Nodes.GRASS); fresh(world,p,570); world.set_node(p+Vector3i.RIGHT,Nodes.WATER); before = drops(game,775); world.fluids.settle(p,Nodes.WATER)
	t.check(Fluids.water(world.node_at(p)) and drops(game,775)-before in [2,3],"real water flow washes away a bush with ordinary drops")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR); fresh(world,p,570); world.set_node(p+Vector3i.RIGHT,Nodes.LAVA); before = drops(game,775); world.fluids.settle(p,Nodes.LAVA)
	t.check(Fluids.lava(world.node_at(p)) and drops(game,775) == before,"real lava flow destroys a bush without drops")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	var base: Vector3i = p-Vector3i.RIGHT*3; var bush: Vector3i = base+Vector3i.RIGHT
	world.set_node(base,Nodes.PISTON); world.circuits.configure(base,Vector3i.RIGHT)
	world.set_node(bush+Vector3i.DOWN,Nodes.GRASS); world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR); fresh(world,bush,569)
	game.gamemode = "creative"; before = drops(game,775)
	var moved: bool = world.circuits.piston(base,true)
	t.check(moved and world.node_at(bush) == Nodes.PISTON_HEAD and drops(game,775)-before in [1,2],"direct piston contact digs the bush and drops berries in creative automation")
	world.circuits.piston(base,false); world.set_node(base,Nodes.AIR); world.set_node(bush,Nodes.AIR); game.gamemode = "survival"
	SweetBerryCrops.reset(world)

static func geometry_and_acquisition(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Nodes.GRASS)
	for s in 4:
		world.set_node(p,567+s); var box: AABB = SweetBerryCrops.boxes(567+s)[0]
		var selected: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
		var art: Array = BlockMesher._empty(); SweetBerryCrops.mesh(art,Vector3.ZERO,567+s)
		t.check(box.position.is_equal_approx(Vector3(0.125,0,0.125)) and box.size.is_equal_approx(Vector3(0.75,0.20+s*0.25,0.75)) and selected.get("pos",Vector3i.ZERO) == p and absf(selected.get("point",Vector3.ZERO).y-(p.y+box.size.y)) < 0.001 and not art[0].is_empty(),"source selection box, raycast and original crossed mesh for stage %d"%s)
		t.check(SweetBerryCrops.compost_chance(567+s) == 30,"bush stage %d has source compostability 30"%s)
	t.check(SweetBerryCrops.compost_chance(775) == 30 and Composters.chance(775) == 30 and Nodes.food(775) == 2 and is_equal_approx(Hunger.food_saturation(775),0.4),"berry food, saturation and compost hooks retain source values")
	var icon: Image = ItemArt.texture(775).get_image()
	t.check(icon != null and icon.get_width() == 16,"sweet berries have original inventory art")
	# Existing terrain_generator places stage 3; a harvested item plants stage 0,
	# closing the natural survival acquisition loop without creative-only content.
	fresh(world,p,570); held(game,Nodes.TORCH,1); var before: int = drops(game,775); target(game,p); game.survival.use()
	t.check(world.node_at(p) == 568 and drops(game,775)-before in [2,3],"naturally generated mature stage yields the survival planting item")

static func persistence(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Farmland.WET); fresh(world,p,570)
	var meta: Dictionary = SweetBerryCrops.metadata(world,p); meta.last_time = SweetBerryCrops.now(world)-408; meta.light_count = 4; meta.light_total = 0
	held(game,775,17); game.save_game("user://sweet-berry-crop-check.json"); var saved: Dictionary = game.read_save("user://sweet-berry-crop-check.json")
	game.set_process(true); world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world; game.pause(); game.set_process(false); world.set_process(false); world.active = false
	t.check(ensure(game,p),"berry plot column is loaded after reload")
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.state != "loading" and world.node_at(p) == 570 and SweetBerryCrops.metadata(world,p).get("light_total",-1) == 0 and game.inventory.count_item(775) == 17,"actual save/load preserves mature berry stage, growth history and berry stacks")
	fresh(world,p,568)
	meta = SweetBerryCrops.metadata(world,p); meta.last_time = SweetBerryCrops.now(world)-408; meta.light_count = 4; meta.light_total = 0
	SweetBerryCrops.unload(world,Vector2i(0,0))
	SweetBerryCrops.registered(world,p,true); SweetBerryCrops.registered(world,p,true)
	t.check(SweetBerryCrops.runtime(world).jobs.filter(func(job): return job.pos == p).size() == 1,"loaded column queues one source catch-up attempt")
	SweetBerryCrops.unload(world,Vector2i(0,0))
	t.check(not SweetBerryCrops.runtime(world).cells.has(p) and SweetBerryCrops.runtime(world).jobs.all(func(job): return job.pos != p) and SweetBerryCrops.metadata(world,p).get("light_total",-1) == 0,"column unload drops active work but retains persistent state")
	SweetBerryCrops.reset(world)
	t.check(not world.has_meta("sweet_berry_crops"),"dimension reset clears sweet-berry runtime indexes")
