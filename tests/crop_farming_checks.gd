extends RefCounted

# Every prior fixture is below Y2000; this plot must have real unshadowed sky.
const PLOT_Y = 2100

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

static func fresh(world: VoxelWorld, p: Vector3i, id: int) -> void:
	world.set_node(p,Nodes.AIR); world.set_node(p,id)

static func roof(world: VoxelWorld, present: bool) -> void:
	for x in range(1,16):
		for z in range(1,16): world.set_node(Vector3i(x,PLOT_Y+6,z),Nodes.STONE if present else Nodes.AIR)
	for y in range(PLOT_Y-1,PLOT_Y+6):
		for edge in range(1,16):
			for p in [Vector3i(1,y,edge),Vector3i(15,y,edge),Vector3i(edge,y,1),Vector3i(edge,y,15)]: world.set_node(p,Nodes.STONE if present else (Farmland.WET if y == PLOT_Y-1 else Nodes.AIR))

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); PotionEffects.clear(game.player); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1; game.day_time = 0.3
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	var world: VoxelWorld = game.world
	for x in range(1,16):
		for z in range(1,16):
			for y in range(PLOT_Y-2,PLOT_Y+7): world.set_node(Vector3i(x,y,z),Nodes.STONE if y == PLOT_Y-2 else (Farmland.WET if y == PLOT_Y-1 else Nodes.AIR))
	var p := Vector3i(8,PLOT_Y,8)
	t.check(Pasture.light(world,p,14) == 14,"source crop plot has full sky above earlier ordered fixtures")
	game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	for f in 4:
		var seed_id: int = CropFarming.SEEDS[f]; var ids: Array = CropFarming.STAGES[f]
		t.check(ids.size() == (4 if f == 3 else 8) and CropFarming.INTERVALS[f] == [25.0,25.0,19.75,68.0][f] and CropFarming.CHANCES[f] == [20,20,20,3][f],"source stages and interval/chance for "+CropFarming.NAMES[f])
		world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Nodes.DIRT); held(game,seed_id,4); game.player.hunger = 10
		click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
		t.check(world.node_at(p) == Nodes.AIR and game.inventory.count_item(seed_id) == 4,"actual "+CropFarming.NAMES[f]+" use refuses untilled dirt")
		world.set_node(p+Vector3i.DOWN,Farmland.WET)
		click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
		t.check(world.node_at(p) == ids[0] and game.inventory.count_item(seed_id) == 3 and game.player.hunger == 10 and game.player.eating.is_empty(),"actual hungry use plants "+CropFarming.NAMES[f]+" once without eating the seed")
		world.set_node(p,Nodes.AIR); game.gamemode = "creative"
		click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
		t.check(world.node_at(p) == ids[0] and game.inventory.count_item(seed_id) == 3,"creative planting preserves "+CropFarming.NAMES[f]+" seed")
		game.gamemode = "survival"
		for id in ids:
			world.set_node(p,id)
			var selected: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
			var art: Array = BlockMesher._empty(); CropFarming.mesh(art,Vector3.ZERO,id)
			t.check(Nodes.exists(id) and not Nodes.solid(id) and selected.get("pos",Vector3i.ZERO) == p and absf(selected.get("point",Vector3.ZERO).y-(p.y+CropFarming.boxes(id)[0].size.y)) < 0.001 and not art[0].is_empty(),"actual registry, raycast and original mesh support "+Nodes.title(id))
			if not CropFarming.mature(id):
				t.check(CropFarming.harvest(id,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Fortune":3,"Silk Touch":1}}}) == [[seed_id,1]],"immature "+Nodes.title(id)+" returns one seed regardless of Fortune or Silk Touch")
		fresh(world,p,ids[0]); held(game,Nodes.BONE_MEAL,10); seed(13812+f)
		click(game,Vector3(p)+Vector3(0.5,0.06,0.5))
		var after: int = CropFarming.stage(world.node_at(p))
		t.check(game.inventory.count_item(Nodes.BONE_MEAL) == 9 and (after in [1,3] if f == 3 else after >= 4 and after <= 7),"actual bone meal uses source stage increment and consumes exactly once for "+CropFarming.NAMES[f])
		fresh(world,p,ids[-1]); var before: int = game.inventory.count_item(Nodes.BONE_MEAL)
		click(game,Vector3(p)+Vector3(0.5,0.25,0.5))
		t.check(world.node_at(p) == ids[-1] and (game.inventory.count_item(Nodes.BONE_MEAL) in [before,before-1] if f == 3 else game.inventory.count_item(Nodes.BONE_MEAL) == before),"mature "+CropFarming.NAMES[f]+" follows its source bone meal callback")
		CropFarming.reset(world); fresh(world,p,ids[0]); CropFarming.runtime(world).rng.seed = 9021+f
		for i in 500:
			game.day_time += CropFarming.INTERVALS[f]/1200.0; CropFarming.update(world,CropFarming.INTERVALS[f])
			if CropFarming.mature(world.node_at(p)): break
		t.check(world.node_at(p) == ids[-1] and not world.growth.has(p),"source scheduled "+CropFarming.NAMES[f]+" matures independently of the retired simplified growth timer")
		world.set_node(p,Nodes.AIR)
	t.check(CropFarming.stage(551) == 1 and CropFarming.stage(552) == 3 and CropFarming.stage(553) == 5 and CropFarming.mature(554) and CropFarming.stage(556) == 3 and CropFarming.mature(558) and CropFarming.stage(Nodes.WHEAT) == 1 and CropFarming.mature(Nodes.RIPE_WHEAT),"legacy save IDs retain their visual source ages and mature identities")
	await probabilities(t,game,p)
	# Source current-light and elapsed-time behavior, including dry soil's throttle.
	var rng := RandomNumberGenerator.new(); rng.seed = 9512
	var dry_growth: int = 0
	for i in 1000:
		fresh(world,p,Nodes.WHEAT)
		if CropFarming.grow(world,p,1,false,true,rng): dry_growth += 1
	t.check(dry_growth >= 65 and dry_growth <= 135,"dry soil applies source one-in-ten early growth throttle over seeded1000 attempts")
	fresh(world,p,Nodes.WHEAT)
	t.check(CropFarming.grow(world,p) and CropFarming.stage(world.node_at(p)) == 3 and not CropFarming.metadata(world,p).has("last_time"),"fresh hydrated growth advances1+ceil(.1) stages and source set_node resets stage metadata")
	fresh(world,p,Nodes.WHEAT); CropFarming.metadata(world,p).last_time = CropFarming.now(world)-1500
	t.check(CropFarming.grow(world,p) and CropFarming.stage(world.node_at(p)) == 5,"saved elapsed time advances1+ceil(1500/500) wheat stages")
	roof(world,true); world.set_node(p+Vector3i.RIGHT*5,Nodes.GLOWSTONE); fresh(world,p,Nodes.WHEAT)
	t.check(Pasture.light(world,p,14) == 9 and not CropFarming.grow(world,p),"natural crop growth rejects source light9")
	world.set_node(p+Vector3i.RIGHT*5,Nodes.AIR); world.set_node(p+Vector3i.RIGHT*4,Nodes.GLOWSTONE); fresh(world,p,Nodes.WHEAT)
	t.check(Pasture.light(world,p,14) == 10 and CropFarming.grow(world,p),"natural crop growth permits source light10")
	world.set_node(p+Vector3i.RIGHT*4,Nodes.AIR); fresh(world,p,Nodes.WHEAT)
	t.check(Pasture.light(world,p,14) == 0 and not CropFarming.grow(world,p) and CropFarming.bone_meal(world,p,rng).grew,"fresh dark crops wait for light while source bone meal bypasses current light")
	fresh(world,p,Nodes.WHEAT); var meta: Dictionary = CropFarming.metadata(world,p); meta.last_time = CropFarming.now(world)-1500; meta.light_count = 10; meta.light_total = 0
	t.check(not CropFarming.grow(world,p) and world.node_at(p) == Nodes.WHEAT,"zero historical light blocks long-unloaded catch-up growth")
	fresh(world,p,Nodes.WHEAT); meta = CropFarming.metadata(world,p); meta.last_time = CropFarming.now(world)-1500; meta.light_count = 10; meta.light_total = 140
	t.check(CropFarming.grow(world,p) and CropFarming.stage(world.node_at(p)) == 5,"saved bright history permits source catch-up despite currently dark light")
	roof(world,false)
	await environment_checks(t,game,p)
	await recipes_and_food(t,game,p)
	await persistence(t,game,p)

static func probabilities(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4077
	var ordinary: Array = [{},{},{},{}]; var enchanted: Array = [{},{},{},{}]; var poison: int = 0; var poison_fortune: int = 0
	for i in 10000:
		for f in 4:
			var id: int = CropFarming.STAGES[f][-1]; var drops_: Array = CropFarming.harvest(id,{},rng)
			var amount: int = drops_[1][1] if f == 3 else drops_[0][1]
			ordinary[f][amount] = int(ordinary[f].get(amount,0))+1
			if f == 2 and drops_.size() == 2: poison += 1
			drops_ = CropFarming.harvest(id,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Fortune":3}}},rng)
			amount = drops_[0][1]; enchanted[f][amount] = int(enchanted[f].get(amount,0))+1
			if f == 2 and drops_.size() > 1: poison_fortune += 1
			if f in [0,3] and drops_[-1] != [Nodes.GRAIN if f == 0 else VillageContent.BEETROOT,1]: poison_fortune += 100000
	t.check(ordinary[0].size() == 3 and ordinary[0][1] in range(3700,4300) and ordinary[0][2] in range(4700,5300) and ordinary[0][3] in range(800,1200),"wheat ordinary drops match independent1/2 and1/5 extra seeds plus guaranteed grain")
	t.check(ordinary[1].size() == 4 and ordinary[1][1] in range(1800,2200) and ordinary[1][2] in range(1800,2200) and ordinary[1][3] in range(3700,4300) and ordinary[1][4] in range(1800,2200),"carrot ordinary drops use sequential source rarity5,2,2 rather than a uniform distribution")
	t.check(ordinary[2].size() == 4 and ordinary[2][1] in range(1000,1500) and ordinary[2][2] in range(3400,4100) and ordinary[2][3] in range(3400,4100) and ordinary[2][4] in range(1000,1500) and poison in range(140,260),"potatoes roll three independent extra halves and a separate2percent poisonous potato")
	t.check(ordinary[3].size() == 4 and ordinary[3][1] in range(3800,4500) and ordinary[3][2] in range(1800,2400) and ordinary[3][3] in range(1800,2400) and ordinary[3][4] in range(1400,1900),"beetroot source sequential seed rarities6,4,3 always leave at least one seed")
	for f in 4:
		var cap: int = 7 if f == 0 else 5; var ratio: float = float(enchanted[f][cap])/enchanted[f][cap-1]
		t.check(enchanted[f].size() == [7,4,4,5][f] and ratio > (1.7 if f == 3 else 2.6) and ratio < (2.3 if f == 3 else 3.4),"FortuneIII "+CropFarming.NAMES[f]+" rolls a uniform expanded source range before capping")
	t.check(poison_fortune == 0,"source Fortune replaces ordinary potato table and preserves guaranteed wheat/beet produce")
	var rolls: Array = [{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Silk Touch":1}}},{"id":VillageContent.ENCHANTED_BOOK,"data":{"enchantments":{"Fortune":3}}}]
	for slot in rolls:
		for f in 4:
			rng.seed = 157+f; var source_drop: Array = CropFarming.harvest(CropFarming.STAGES[f][-1],{},rng); rng.seed = 157+f
			t.check(CropFarming.harvest(CropFarming.STAGES[f][-1],slot,rng) == source_drop,"Silk Touch and merely holding an enchanted book preserve ordinary "+CropFarming.NAMES[f]+" drops")
	var grew: int = 0; var consumed: int = 0; var mature_consumed: int = 0
	for i in 1000:
		fresh(game.world,p,VillageContent.BEETROOTS_0); var result: Dictionary = CropFarming.bone_meal(game.world,p,rng)
		if result.grew: grew += 1
		if result.consume: consumed += 1
		fresh(game.world,p,VillageContent.BEETROOTS_3); result = CropFarming.bone_meal(game.world,p,rng)
		if result.consume: mature_consumed += 1
	t.check(grew in range(700,801) and consumed == 1000 and mature_consumed in range(200,301),"beetroot source75percent growth callback consumes its25percent nil result, including mature nil attempts")

static func environment_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for f in 4:
		var young: int = CropFarming.STAGES[f][0]; var grown: int = CropFarming.STAGES[f][-1]; var seed_id: int = CropFarming.SEEDS[f]
		world.set_node(p+Vector3i.DOWN,Nodes.STONE); fresh(world,p,young)
		t.check(world.node_at(p) == young,"existing "+CropFarming.NAMES[f]+" retains source attached-node support on ordinary solid terrain")
		var before: int = drops(game,seed_id); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
		t.check(world.node_at(p) == Nodes.AIR and drops(game,seed_id) == before+1 and not CropFarming.runtime(world).cells.has(p),"removing support uproots "+CropFarming.NAMES[f]+" exactly once and removes runtime tracking")
		world.set_node(p+Vector3i.DOWN,Farmland.WET); fresh(world,p,grown); held(game,Nodes.TOOLS+16,1,{"enchantments":{"Fortune":3}})
		before = drops(game,seed_id); game.break_node(p,grown,Nodes.TOOLS+16)
		t.check(world.node_at(p) == Nodes.AIR and drops(game,seed_id)-before in range(1,8),"actual enchanted mining dispatches source "+CropFarming.NAMES[f]+" harvest")
		fresh(world,p,young); before = drops(game,seed_id); world.set_node(p+Vector3i.RIGHT,Nodes.WATER); world.fluids.settle(p,Nodes.WATER)
		t.check(Fluids.water(world.node_at(p)) and drops(game,seed_id) == before+1,"actual water flow washes away "+CropFarming.NAMES[f]+" with its source seed drop")
		world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p,Nodes.AIR); fresh(world,p,young); before = drops(game,seed_id); world.set_node(p+Vector3i.RIGHT,Nodes.LAVA); world.fluids.settle(p,Nodes.LAVA)
		t.check(Fluids.lava(world.node_at(p)) and drops(game,seed_id) == before,"actual lava destroys "+CropFarming.NAMES[f]+" without drops")
		world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p,Nodes.AIR)
	# Source wheat alone is unsticky; other crops get dug on adhesive side contact.
	var base: Vector3i = p-Vector3i.RIGHT*3; var crop: Vector3i = base+Vector3i.RIGHT+Vector3i.BACK
	for f in 4:
		world.set_node(base,Nodes.PISTON); world.circuits.configure(base,Vector3i.RIGHT)
		# Keep the adhesive test separate from its movable floor; otherwise the
		# restored direct-push soil drags an entire field on the next iteration.
		world.set_node(base+Vector3i.RIGHT+Vector3i.DOWN,Nodes.AIR)
		world.set_node(crop+Vector3i.DOWN,Nodes.STONE)
		world.set_node(base+Vector3i.RIGHT,Beehives.HONEY_BLOCK); world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR)
		fresh(world,crop,CropFarming.STAGES[f][0]); var before: int = drops(game,CropFarming.SEEDS[f]); game.gamemode = "creative"
		var moved: bool = world.circuits.piston(base,true)
		t.check(moved and (world.node_at(crop) == CropFarming.STAGES[f][0] if f == 0 else world.node_at(crop) == Nodes.AIR and drops(game,CropFarming.SEEDS[f]) == before+1),"real adhesive piston follows source "+CropFarming.NAMES[f]+" unsticky/dig groups and drops in creative automation")
		world.circuits.piston(base,false); world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR); world.set_node(crop,Nodes.AIR)
		world.set_node(base+Vector3i.RIGHT+Vector3i.DOWN,Farmland.WET)
		world.set_node(base+Vector3i.RIGHT,CropFarming.STAGES[f][0]); before = drops(game,CropFarming.SEEDS[f])
		t.check(world.node_at(base+Vector3i.RIGHT) == CropFarming.STAGES[f][0],"direct piston fixture restores soil moved by the preceding adhesive push")
		var pushed: bool = world.circuits.piston(base,true); t.check(pushed and drops(game,CropFarming.SEEDS[f]) == before+1 and world.node_at(base+Vector3i.RIGHT) == Nodes.PISTON_HEAD,"direct piston contact harvests "+CropFarming.NAMES[f]+" once")
		world.circuits.piston(base,false); world.set_node(base,Nodes.AIR)
	game.gamemode = "survival"
	CropFarming.reset(world)
	for x in range(3,13): fresh(world,Vector3i(x,PLOT_Y,3),Nodes.WHEAT); CropFarming.queue_growth(world,Vector3i(x,PLOT_Y,3))
	CropFarming.update(world,0)
	t.check(CropFarming.runtime(world).jobs.size() == 2,"growth scheduler processes at most eight queued crop jobs per update")
	for x in range(3,13): world.set_node(Vector3i(x,PLOT_Y,3),Nodes.AIR)
	fresh(world,p,Nodes.WHEAT); CropFarming.queue_growth(world,p); fresh(world,p,Nodes.WHEAT); CropFarming.update(world,0)
	t.check(world.node_at(p) == Nodes.WHEAT,"removed and replanted crop cannot inherit a stale queued growth action")
	# Reconcile a source worker snapshot that contained a crop before an edit
	# removed its support; direct raw write reproduces worker application ordering.
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	world.blocks[VoxelWorld.block_coord(p)].data[VoxelWorld.local_index(p)] = Nodes.WHEAT
	CropFarming.registered(world,p,true); var before: int = drops(game,Nodes.SEEDS)
	CropFarming.column_loaded(world,Vector2i(0,0))
	t.check(world.node_at(p) == Nodes.AIR and drops(game,Nodes.SEEDS) == before+1,"column edit reconciliation removes worker crops whose edited support disappeared")
	world.set_node(p+Vector3i.DOWN,Farmland.WET)

static func recipes_and_food(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var found: bool = false; var rng := RandomNumberGenerator.new(); rng.seed = 9771
	for i in 1000:
		var stack: Dictionary = Dungeons.weighted(rng,Dungeons.SUPPLIES)
		if stack.get("id",0) == VillageContent.BEETROOT_SEEDS: found = int(stack.count) in range(2,5)
	t.check(found,"source beetroot seeds remain obtainable from actual weighted dungeon supplies")
	var recipes: Array = [
		[[Nodes.GRAIN,Nodes.GRAIN,Nodes.GRAIN,0,0,0,0,0,0],Nodes.BREAD,1],
		[[VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,0,Nodes.BOWL,0],VillageContent.BEETROOT_SOUP,1],
		[[Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,VillageContent.CARROT,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET,Nodes.GOLD_NUGGET],VillageContent.GOLDEN_CARROT,1],
		[[VillageContent.BEETROOT,0,0,0,0,0,0,0,0],VillageContent.DYE_RED,1],
	]
	for row in recipes:
		for i in 9: game.inventory.grid[i] = {"id":row[0][i],"count":1 if row[0][i] else 0,"wear":0}
		var result: Dictionary = game.inventory.take_grid_result("table")
		t.check(result.get("id",0) == row[1] and result.get("count",0) == row[2],"actual crafting preserves source "+Nodes.title(row[1])+" acquisition")
	for i in 9: game.inventory.grid[i] = {"id":VillageContent.BEETROOT if i in range(0,6) else (Nodes.BOWL if i == 6 else 0),"count":1,"wear":0}
	t.check(game.inventory.take_grid_result("table").get("id",0) == 0,"source beetroot soup requires the bowl below the center, not a shapeless shortcut")
	game.inventory.grid_to_inventory(); held(game,VillageContent.BEETROOT_SOUP,1); game.player.hunger = 10; game.player.saturation = 0
	Eating.start(game.player); Eating.update(game.player,Eating.DURATION+0.01,true)
	t.check(game.inventory.count_item(Nodes.BOWL) == 1 and game.inventory.count_item(VillageContent.BEETROOT_SOUP) == 0 and game.player.hunger == 16 and absf(game.player.saturation-7.2) < 0.001,"actual beetroot soup eating restores source food/saturation and returns one bowl")
	var poison: int = CropFarming.POISONOUS_POTATO
	t.check(Nodes.exists(poison) and Nodes.food(poison) == 2 and Hunger.food_saturation(poison) == 1.2 and Nodes.max_stack(poison) == 64 and Composters.chance(poison) == 0 and not CropFarming.is_seed(poison),"poisonous potato has source nutrition and no compost/plant shortcuts")
	var icon: Image = ItemArt.texture(poison).get_image()
	t.check(icon != null and icon.get_width() > 0,"poisonous potato has original inventory art")
	PotionEffects.clear(game.player); Eating.food_effects(game.player,poison,0.6)
	t.check(PotionEffects.level(game.player,"poison") == 1 and absf(game.player.game.survival.effects.poison-5) < 0.001,"source inclusive60percent food roll applies PoisonI for five seconds")
	PotionEffects.clear(game.player); Eating.food_effects(game.player,poison,0.6001)
	t.check(PotionEffects.level(game.player,"poison") == 0,"a roll above60percent does not poison")
	held(game,poison,2); game.player.hunger = 10; game.player.saturation = 0; seed(772)
	Eating.start(game.player); Eating.update(game.player,Eating.DURATION+0.01,true)
	t.check(game.inventory.count_item(poison) == 1 and game.player.hunger == 12 and absf(game.player.saturation-1.2) < 0.001,"actual hold-eating consumes poisonous potato with source nutrition")
	PotionEffects.clear(game.player); game.world.set_node(p,Nodes.AIR); held(game,poison,2)
	click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
	t.check(game.world.node_at(p) == Nodes.AIR,"poisonous potato cannot plant a healthy crop")

static func persistence(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	roof(world,true); fresh(world,p,8032)
	var meta: Dictionary = CropFarming.metadata(world,p); meta.last_time = CropFarming.now(world)-1000; meta.light_count = 4; meta.light_total = 0
	held(game,CropFarming.POISONOUS_POTATO,17); game.player.position = Vector3(8.5,PLOT_Y,12.5)
	game.save_game("user://crop-farming-check.json"); var saved: Dictionary = game.read_save("user://crop-farming-check.json")
	game.set_process(true); world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world
	game.pause(); game.set_process(false); world.set_process(false); world.active = false; game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.state != "loading" and world.node_at(p) == 8032 and CropFarming.stage(world.node_at(p)) == 6 and CropFarming.metadata(world,p).get("light_total",-1) == 0 and game.inventory.count_item(CropFarming.POISONOUS_POTATO) == 17,"actual save/load preserves new intermediate stage, dark growth history and poisonous potatoes")
	CropFarming.unload(world,Vector2i(0,0))
	t.check(not CropFarming.runtime(world).cells.has(p) and CropFarming.runtime(world).jobs.all(func(job):return job.pos != p) and world.node_at(p) == 8032,"column unload removes active jobs without deleting saved crop state")
	CropFarming.registered(world,p,true); CropFarming.registered(world,p,true)
	t.check(CropFarming.runtime(world).jobs.filter(func(job):return job.pos == p).size() == 1,"repeated load registration queues only one catch-up job per crop")
	game.state = "playing"
	for i in 100:
		if not CropFarming.runtime(world).pending.has(p): break
		CropFarming.update(world,0)
	t.check(world.node_at(p) == 8032 and CropFarming.metadata(world,p).get("light_count",0) >= 5,"source load catch-up reads saved darkness instead of granting free maturity")
	CropFarming.reset(world)
	t.check(not world.has_meta("crop_farming"),"dimension/reset clears all crop runtime indices")
	# Remove this fixture from the restored world too. Later suites use sky and
	# rain exposure below this elevation, so even its solid floor would shade them.
	for x in range(1,16):
		for z in range(1,16):
			for y in range(PLOT_Y+6,PLOT_Y-3,-1): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.state = "playing"; game.player.set_process(false); game.player.set_physics_process(false)
