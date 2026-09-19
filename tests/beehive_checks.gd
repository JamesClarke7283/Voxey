extends RefCounted
const Helper = preload("res://tests/boats_checks.gd")

static func healthy(game: Node3D) -> void:
	game.player.health = 20; game.player.damage_cooldown = 0; game.player.armor_slots = [{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0}]
	game.survival.effects.clear()

static func point(game: Node3D, p: Vector3i) -> void:
	game.player.target = {"id":game.world.node_at(p),"pos":p,"normal":Vector3i.UP,"distance":3.0}

static func finish_scan(world: VoxelWorld) -> int:
	var maximum: int = 0
	for i in 12:
		Beehives.update(world,0.001)
		maximum = maxi(maximum,int(Beehives.runtime(world).samples))
	return maximum

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	for id in [Beehives.HIVE,Beehives.NEST,Beehives.COMB_BLOCK,Beehives.HONEY_BLOCK]:
		t.check(Nodes.exists(id) and Nodes.placeable(id) and Nodes.solid(id),"honey survival material is registered and physically solid: "+Nodes.title(id))
	t.check(Nodes.max_stack(Beehives.BOTTLE) == 16 and Nodes.food(Beehives.BOTTLE) == 6 and Nodes.hardness(Beehives.HONEY_BLOCK) == 0 and Nodes.hardness(Beehives.HIVE) == 0.6 and Nodes.hardness(Beehives.NEST) == 0.3,"honey bottle and hive material retain source stack, food and hardness values")
	for base in [Beehives.HIVE,Beehives.NEST]:
		for amount in 6:
			for face in 4:
				var id: int = base+amount*4+face
				t.check(Beehives.level(id) == amount and Beehives.facing(id) == face and Beehives.item(id) == base+amount*4 and Nodes.pick_item(id) == base,"every saved hive state decodes honey, placement and creative pick: %d"%id)
			t.check(Nodes.placeable(base+amount*4) and (Nodes.all_ids().has(base+amount*4) == (amount == 0)),"silk-retained honey item is placeable while hidden from creative variants: %d"%(base+amount*4))
	t.check(Beehives.immovable(Beehives.HIVE) and Beehives.immovable(Beehives.HIVE+16) and not Beehives.immovable(Beehives.HIVE+20) and not Beehives.immovable(Beehives.NEST),"actual source immovable group excludes full crafted hives and all nests")
	t.check(Beehives.sticks(Beehives.HONEY_BLOCK,Nodes.STONE) and Beehives.sticks(Beehives.HONEY_BLOCK,Beehives.HONEY_BLOCK) and not Beehives.sticks(Beehives.HONEY_BLOCK,VillageContent.SLIME_BLOCK) and not Beehives.sticks(VillageContent.SLIME_BLOCK,Beehives.HONEY_BLOCK),"honey and slime adhere in all directions except to each other")
	t.check(Beehives.fall_multiplier(Beehives.HONEY_BLOCK) == 0.2 and Beehives.fall_multiplier(Beehives.COMB_BLOCK) == 1,"only honey blocks reduce fall damage by source80percent")
	t.check(Nodes.preferred_tool(Beehives.HIVE) == 1 and Nodes.preferred_tool(Beehives.NEST) == 1 and Nodes.harvestable(Beehives.HIVE,0) and Nodes.harvestable(Beehives.NEST,0),"hives and nests are hand-breakable with source axe preference")
	t.check(NoteBlocks.group(Beehives.HIVE) == "wood" and NoteBlocks.group(Beehives.NEST) == "" and Nodes.fuel_time(Beehives.HIVE) == 15 and Nodes.fuel_time(Beehives.HIVE+4) == 0,"source crafted-hive wood group and base-only fifteen-second fuel remain distinct from nest and honey variants")
	for direction in [[0.0,4],[PI/2,0],[PI,5],[-PI/2,1]]:
		t.check(Beehives.texture(Beehives.oriented(Beehives.HIVE+20,direction[0]),direction[1]) == 7663,"full hive entry face points toward the placing player: "+str(direction[0]))
	var bottle_icon: Image = ItemArt.texture(Beehives.BOTTLE).get_image()
	var center: Color = bottle_icon.get_pixel(8,10)
	t.check(center.r > 0.8 and center.g > 0.5 and center.b < 0.3,"actual honey-bottle item texture has golden contents distinct from water")
	var hive_recipe: int = inv.recipe_index(Beehives.HIVE)
	inv.restore([]); inv.add_item(WoodTypes.planks_id(2),6); inv.add_item(Beehives.COMB,3)
	t.check(hive_recipe >= 0 and inv.fill_grid(hive_recipe,"table") and inv.take_grid_result("table").get("id",0) == Beehives.HIVE,"real recipe guide crafts a hive from six non-oak planks and three comb")
	for row in [[Beehives.COMB_BLOCK,Beehives.COMB,4],[Beehives.HONEY_BLOCK,Beehives.BOTTLE,4]]:
		inv = Inventory.new(); inv.add_item(row[1],row[2]); var index: int = inv.recipe_index(row[0])
		t.check(index >= 0 and inv.fill_grid(index,"hand") and inv.craft_grid_to_inventory("hand") and inv.count_item(row[0]) == 1 and inv.count_item(row[1]) == 0,"real hand crafting makes honey material without losing inputs: "+Nodes.title(row[0]))
		if row[0] == Beehives.HONEY_BLOCK:
			inv.grid_to_inventory()
			t.check(inv.count_item(VillageContent.GLASS_BOTTLE) == 4,"honey compression returns all four glass containers")
	inv = Inventory.new(); inv.grid[0] = {"id":Beehives.BOTTLE,"count":2,"wear":0}
	var sugar: Dictionary = inv.take_grid_result("hand")
	t.check(sugar.get("id",0) == Nodes.SUGAR and sugar.get("count",0) == 3 and inv.grid[0].id == Beehives.BOTTLE and inv.grid[0].count == 1 and inv.count_item(VillageContent.GLASS_BOTTLE) == 1,"one honey bottle crafts three sugar and returns glass without replacing the remaining stack")
	inv = Inventory.new(); inv.add_item(Beehives.HONEY_BLOCK,1); inv.add_item(VillageContent.GLASS_BOTTLE,4)
	var bottled: int = inv.recipe_index(Beehives.BOTTLE)
	t.check(inv.fill_grid(bottled,"table") and inv.craft_grid_to_inventory("table") and inv.count_item(Beehives.BOTTLE) == 4 and inv.count_item(VillageContent.GLASS_BOTTLE) == 0,"source asymmetric reverse recipe consumes four empty bottles and one honey block")
	inv = Inventory.new()
	for i in inv.slots.size(): inv.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	inv.grid[0] = {"id":Beehives.BOTTLE,"count":2,"wear":0}
	var before_grid: Array = inv.grid.duplicate(true); var before_slots: Array = inv.slots.duplicate(true)
	t.check(inv.take_grid_result("hand").is_empty() and inv.grid == before_grid and inv.slots == before_slots,"full inventory rejects a crafting container return atomically")
	var actual_inventory: Inventory = game.inventory; var actual_cursor: Dictionary = game.hud.cursor
	var actual_station: String = game.hud.station; var actual_shift: bool = game.hud.shift_mode
	game.inventory = inv; game.hud.station = "hand"; game.hud.shift_mode = false
	for cursor_state in [{"id":0,"count":0,"wear":0},{"id":Nodes.SUGAR,"count":3,"wear":0}]:
		game.hud.cursor = cursor_state.duplicate(true)
		game.hud._take_output()
		t.check(game.hud.cursor == cursor_state and inv.grid == before_grid and inv.slots == before_slots,"actual output click preserves a valid cursor and all ingredients when glass-container return is blocked: "+str(cursor_state.id))
	game.inventory = actual_inventory; game.hud.cursor = actual_cursor; game.hud.station = actual_station; game.hud.shift_mode = actual_shift
	var old: Dictionary = {"position":game.player.position,"rotation":game.player.rotation,"target":game.player.target,"mode":game.gamemode,"touch":game.touch,"inventory":game.inventory.slots.duplicate(true),"selected":game.inventory.selected,"health":game.player.health,"armor":game.player.armor_slots.duplicate(true),"day":game.day_time,"effects":game.survival.effects.duplicate(true),"hunger":game.player.hunger,"saturation":game.player.saturation,"velocity":game.player.velocity,"cooldown":game.player.damage_cooldown,"weather":game.world.adventure_state.get("weather",null)}
	Helper.freeze(game); game.state = "playing"; game.gamemode = "survival"; game.touch = false
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var world: VoxelWorld = game.world; var p := Vector3i(8,1180,8)
	game.player.position = Vector3(p)+Vector3(0.5,0,3); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	for x in range(-5,6):
		for z in range(-5,6):
			for y in range(-6,7): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	for pair in [[Beehives.HIVE,0.0],[Beehives.NEST+20,PI/2]]:
		world.set_node(p,Nodes.AIR); Helper.equip(game,pair[0],2); game.player.rotation.y = pair[1]
		game.player.target = {"id":Nodes.STONE,"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"distance":3.0}; game.player.use()
		t.check(world.node_at(p) == Beehives.oriented(pair[0],pair[1]) and game.inventory.held().count == 1 and world.stations.has(VoxelWorld.station_key(p)),"real placement preserves retained honey and initializes the saved production timer")
	game.player.rotation.y = 0
	world.set_node(p,Beehives.NEST+23); Helper.equip(game,VillageContent.GLASS_BOTTLE,2); healthy(game); point(game,p); game.player.use()
	t.check(world.node_at(p) == Beehives.NEST+3 and game.inventory.count_item(Beehives.BOTTLE) == 1 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 1 and game.player.health == 10,"unprotected real bottle harvest produces honey, consumes one glass and deals source ten damage")
	world.set_node(p,Beehives.HIVE+21); Helper.equip(game,Nodes.SHEARS); healthy(game); point(game,p)
	var comb_before: int = Helper.drops(game,Beehives.COMB); game.player.use()
	t.check(Helper.drops(game,Beehives.COMB) == comb_before+3 and game.inventory.held().wear == 1 and game.player.health == 10 and world.node_at(p) == Beehives.HIVE+1,"real shearing ejects three comb, uses one durability and preserves direction")
	for flame in [Campfires.LIT,Campfires.SOUL_LIT]:
		world.set_node(p+Vector3i.DOWN*5,flame); world.set_node(p+Vector3i.DOWN*3,Nodes.STONE)
		world.set_node(p,Beehives.HIVE+20); Helper.equip(game,VillageContent.GLASS_BOTTLE); healthy(game); point(game,p); game.player.use()
		t.check(game.player.health == 20 and game.inventory.count_item(Beehives.BOTTLE) == 1,"source lit campfire protects harvest through an obstruction at five cells: "+Nodes.title(flame))
	world.set_node(p+Vector3i.DOWN*5,Campfires.UNLIT)
	t.check(not Beehives.protected_by_smoke(world,p),"unlit campfire provides no smoke protection")
	world.set_node(p+Vector3i.DOWN*5,Nodes.AIR); world.set_node(p+Vector3i.DOWN*6,Campfires.LIT)
	t.check(not Beehives.protected_by_smoke(world,p),"campfire one cell beyond the source search range provides no protection")
	world.set_node(p+Vector3i.DOWN*6,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Campfires.LIT)
	Helper.equip(game,VillageContent.GLASS_BOTTLE,2)
	for i in range(1,game.inventory.slots.size()): game.inventory.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	world.set_node(p,Beehives.NEST+20); healthy(game); point(game,p); var honey_drops: int = Helper.drops(game,Beehives.BOTTLE); game.player.use()
	t.check(game.inventory.held().count == 1 and Helper.drops(game,Beehives.BOTTLE) == honey_drops+1 and Beehives.level(world.node_at(p)) == 0,"full inventory harvest delivers overflow as a real honey bottle rather than deleting honey")
	game.gamemode = "creative"; Helper.equip(game,Nodes.SHEARS); world.set_node(p,Beehives.HIVE+20); point(game,p); comb_before = Helper.drops(game,Beehives.COMB); game.player.use()
	t.check(game.inventory.held().wear == 0 and Helper.drops(game,Beehives.COMB) == comb_before+3 and Beehives.level(world.node_at(p)) == 0,"creative shearing resets honey and preserves tool durability")
	Helper.equip(game,VillageContent.GLASS_BOTTLE); world.set_node(p,Beehives.HIVE+20); point(game,p); game.player.use()
	t.check(game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 1 and game.inventory.count_item(Beehives.BOTTLE) == 1,"creative bottle harvest gives honey without consuming its glass")
	game.gamemode = "survival"; Helper.equip(game,Nodes.SHEARS); world.set_node(p,Beehives.NEST+16); point(game,p)
	comb_before = Helper.drops(game,Beehives.COMB)
	t.check(not Beehives.use(game,game.player.target) and Helper.drops(game,Beehives.COMB) == comb_before,"immature honey levels cannot be sheared")
	world.set_node(p,Beehives.NEST+20); point(game,p); Helper.press(KEY_CTRL,true)
	t.check(not Beehives.use(game,game.player.target),"sneaking bypasses hive harvesting so adjacent placement remains available")
	Helper.press(KEY_CTRL,false)
	for base in [Beehives.HIVE,Beehives.NEST]:
		for silk in [false,true]:
			var id: int = base+15; world.set_node(p,id); Helper.equip(game,Nodes.TOOLS+2,1,{"enchantments":{"Silk Touch":1}} if silk else {}); healthy(game)
			var expected: int = base+12 if silk else Beehives.HIVE
			var drops_before: int = Helper.drops(game,expected); game.break_node(p,id,Nodes.TOOLS+2)
			t.check(game.player.health == (20 if silk else 10) and Helper.drops(game,expected) == drops_before+(1 if silk or base == Beehives.HIVE else 0) and world.node_at(p) == Nodes.AIR,"source digging preserves honey only with Silk Touch and campfires do not prevent dig damage: %d/%s"%[base,str(silk)])
	for base in [Beehives.HIVE,Beehives.NEST]:
		world.set_node(p,base+20); Helper.equip(game,VillageContent.ENCHANTED_BOOK,1,{"enchantments":{"Silk Touch":1}}); healthy(game)
		var drops_before: int = Helper.drops(game,base+20); game.break_node(p,base+20,VillageContent.ENCHANTED_BOOK)
		t.check((Helper.drops(game,base+20) == drops_before+1) == (base == Beehives.HIVE) and game.player.health == (20 if base == Beehives.HIVE else 10),"source nest excludes enchanted books while crafted hive retains its original permissive check")
	game.gamemode = "creative"; Helper.equip(game,0,0)
	for i in 2: world.set_node(p,Beehives.NEST+20); game.break_node(p,Beehives.NEST+20,0)
	t.check(game.inventory.count_item(Beehives.NEST) == 1 and game.inventory.count_item(Beehives.NEST+20) == 0,"creative digging grants at most one empty canonical nest")
	game.gamemode = "survival"; healthy(game); Helper.equip(game,Nodes.TOOLS+2,1,{"enchantments":{"Silk Touch":1}})
	world.set_node(p,Beehives.NEST+20); var blasted: int = Helper.drops(game,Beehives.NEST+20); Beehives.break_node(game,p,Beehives.NEST+20,0,true)
	t.check(Helper.drops(game,Beehives.NEST+20) == blasted and game.player.health == 20,"explosion destruction invokes neither player retaliation nor Silk Touch drops")
	for id in [Beehives.COMB_BLOCK,Beehives.HONEY_BLOCK]:
		world.set_node(p,id); Helper.equip(game,0,0); var before: int = Helper.drops(game,id); game.break_node(p,id,0)
		t.check(Nodes.harvestable(id,0) and Helper.drops(game,id) == before+1,"actual bare-hand breaking recovers honey building material: "+Nodes.title(id))
	for id in [Nodes.STONE,Beehives.HONEY_BLOCK]:
		world.set_node(p+Vector3i.DOWN,id); game.player.position = Vector3(p)+Vector3(0.5,0.5,0.5); healthy(game); game.player.velocity = Vector3(0,-20,0)
		game.player._move(Vector3(0,-1,0),false)
		t.check(is_equal_approx(game.player.health,18.4 if id == Beehives.HONEY_BLOCK else 12),"real collision landing applies honey fall reduction: "+Nodes.title(id))
	game.player.position = Vector3(p)+Vector3(0.5,0,3); world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	await production_checks(t,game,p)
	await tree_checks(t,game,p)
	await automation_checks(t,game,p)
	await piston_checks(t,game,p+Vector3i.UP*3)
	await eating_checks(t,game,p)
	world = game.world; world.set_node(p,Beehives.NEST+18); Beehives.station(world,p).remaining = 37.25
	var pending_pos: Vector3i = p+Vector3i.UP*6
	world.set_node(pending_pos,Beehives.HIVE); Beehives.station(world,pending_pos).remaining = 0; Beehives.update(world,0.001)
	t.check(Beehives.runtime(world).pending.has(pending_pos) and Beehives.station(world,pending_pos).remaining == 0,"pending bounded flower search leaves a resumable zero countdown for saving")
	Helper.equip(game,Beehives.HIVE+20,3)
	t.check(game.save_game("user://beehives.json"),"hive timer, honey state and full hive items save through the actual game")
	var saved: Dictionary = game.read_save("user://beehives.json"); game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	Helper.freeze(game); world = game.world
	t.check(world.node_at(p) == Beehives.NEST+18 and Beehives.station(world,p).remaining <= 37.25 and Beehives.station(world,p).remaining > 35 and game.inventory.held().id == Beehives.HIVE+20 and game.inventory.held().count == 3,"real JSON reload retains honey, orientation, production countdown and Silk Touch item identities: "+str([world.node_at(p),Beehives.station(world,p).remaining,game.inventory.held()]))
	t.check(Beehives.runtime(world).cells.has(p),"edited hive is registered again when its saved column loads")
	game.state = "playing"; finish_scan(world)
	t.check(Beehives.runtime(world).cells.has(pending_pos) and Beehives.station(world,pending_pos).remaining > 74 and Beehives.level(world.node_at(pending_pos)) == 0,"real reload resumes and completes a pending flower search without granting false honey")
	for x in range(-5,6):
		for z in range(-5,6):
			for y in range(-6,7): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = old.position; game.player.rotation = old.rotation; game.player.target = old.target; game.player.health = old.health; game.player.armor_slots = old.armor; game.player.hunger = old.hunger; game.player.saturation = old.saturation; game.player.velocity = old.velocity; game.player.damage_cooldown = old.cooldown
	game.gamemode = old.mode; game.touch = old.touch; game.day_time = old.day; game.survival.effects = old.effects; game.inventory.slots = old.inventory; game.inventory.selected = old.selected
	if old.weather == null: world.adventure_state.erase("weather")
	else: world.adventure_state.weather = old.weather
	Helper.freeze(game)

static func production_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for entry in [[0.25,"clear",false],[0.2501,"clear",true],[0.7499,"clear",true],[0.75,"clear",false],[0.5,"rain",false],[0.5,"thunder",true]]:
		t.check(Beehives.eligible(entry[0],entry[1]) == entry[2],"source honey production time/weather boundary: %s/%s"%[str(entry[0]),entry[1]])
	world.set_node(p,Beehives.HIVE+2); game.day_time = 0.5; game.world.adventure_state.weather = "clear"
	Beehives.station(world,p).remaining = 1; Beehives.update(world,0.99)
	t.check(Beehives.level(world.node_at(p)) == 0 and Beehives.station(world,p).remaining > 0,"production waits for its complete saved75second interval")
	Beehives.update(world,0.02); var max_samples: int = finish_scan(world)
	t.check(Beehives.level(world.node_at(p)) == 0 and max_samples <= Beehives.SCAN_BUDGET,"no flowers produces no honey and bounds absent-flower search per frame")
	var flower_pos: Vector3i = p+Vector3i(5,0,5); world.set_node(flower_pos+Vector3i.DOWN,Nodes.GRASS); world.set_node(flower_pos,FoodFeatures.POPPY)
	Beehives.station(world,p).remaining = 0; Beehives.update(world,0.001); finish_scan(world)
	t.check(Beehives.level(world.node_at(p)) in [1,2] and Beehives.facing(world.node_at(p)) == 2,"a flower at the source five-cell boundary enables honey while preserving facing")
	world.set_node(flower_pos,Nodes.AIR); world.set_node(p,Beehives.NEST+3)
	Beehives.advance(world,p,99); t.check(Beehives.level(world.node_at(p)) == 1,"ordinary source roll advances honey by one")
	Beehives.advance(world,p,100); t.check(Beehives.level(world.node_at(p)) == 3,"source one-percent roll advances honey by two")
	Beehives.advance(world,p,100); Beehives.advance(world,p,100)
	t.check(Beehives.level(world.node_at(p)) == 5 and Beehives.signal_strength(world,p) == 5,"honey and comparator strength cap at five")
	world.set_node(p,Beehives.HIVE); Beehives.station(world,p).remaining = 17
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0)); Beehives.unload(world,column); Beehives.update(world,1000)
	t.check(not Beehives.runtime(world).cells.has(p) and Beehives.station(world,p).remaining == 17,"unloaded hives pause without granting offline honey")
	Beehives.registered(world,p); Beehives.update(world,1)
	t.check(Beehives.station(world,p).remaining == 16,"registration resumes an existing countdown without resetting it")
	world.stations[VoxelWorld.station_key(p)].remaining = "bad"
	t.check(Beehives.station(world,p).remaining == 75,"malformed saved timer is normalized safely")
	var apiary: Array = []
	for x in range(-3,4):
		var q: Vector3i = p+Vector3i(x,4,0); world.set_node(q,Beehives.HIVE); Beehives.station(world,q).remaining = 0; apiary.append(q)
	var start: int = Time.get_ticks_usec(); Beehives.update(world,0.001); var elapsed: float = (Time.get_ticks_usec()-start)/1000.0
	t.check(Beehives.runtime(world).samples == Beehives.SCAN_BUDGET and Beehives.runtime(world).jobs.size() >= 6,"simultaneously due apiary bounds flower sampling across all hives instead of per hive")
	print("HIVE SCAN: ",Beehives.runtime(world).samples," cells across seven due hives in ",elapsed," ms")
	for q in apiary: world.set_node(q,Nodes.AIR)
	world.set_node(p,Nodes.AIR)
	t.check(not world.stations.has(VoxelWorld.station_key(p)) and not Beehives.runtime(world).cells.has(p),"removing a hive clears both saved and live production state")

static func tree_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; var seed_value: int = -1
	for trial in 1000:
		var rng := RandomNumberGenerator.new(); rng.seed = trial
		if rng.randi_range(1,20) == 1: seed_value = trial; break
	var flower_pos: Vector3i = p+Vector3i(2,0,2)
	world.set_node(flower_pos+Vector3i.DOWN,Nodes.GRASS); world.set_node(flower_pos,FoodFeatures.DANDELION)
	for direction in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD]:
		world.set_node(p+direction+Vector3i.UP*2,WoodTypes.leaves_id(0)); world.set_node(p+direction+Vector3i.UP,Nodes.AIR)
	t.check(Beehives.after_tree_grow(world,p,0,seed_value),"source five-percent oak growth roll creates a nest under adjacent leaves with a nearby flower")
	var count: int = 0
	for direction in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD]:
		var at: Vector3i = p+direction+Vector3i.UP
		if Beehives.is_nest(world.node_at(at)): count += 1
		world.set_node(at,Nodes.STONE)
	t.check(count == 1 and not Beehives.after_tree_grow(world,p,0,seed_value),"sapling callback chooses one source direction and never overwrites an occupied nest cell")
	for direction in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD]: world.set_node(p+direction+Vector3i.UP,Nodes.AIR)
	t.check(not Beehives.after_tree_grow(world,p,1,seed_value) and not Beehives.after_tree_grow(world,p,3,seed_value),"spruce and jungle growth do not invent unsupported source nests")
	world.set_node(flower_pos,Nodes.AIR)
	t.check(not Beehives.after_tree_grow(world,p,2,seed_value),"birch requires a same-height flower before its five-percent roll")
	var candidate: Dictionary = {}; var chosen: int = -1
	for x in 4000:
		var plan: Dictionary = {"origin":Vector3i(x,40,0),"species":0,"blocks":{}}
		for direction in Beehives.SIDES: plan.blocks[direction+Vector3i.UP*3] = WoodTypes.leaves_id(0)
		Beehives.decorate_tree(world.generator,plan)
		for id in plan.blocks.values():
			if Beehives.is_nest(id): candidate = plan; chosen = x; break
		if chosen >= 0: break
	t.check(chosen >= 0,"deterministic source-probability natural trees provide a survival nest acquisition route")
	if chosen >= 0:
		var repeated: Dictionary = {"origin":Vector3i(chosen,40,0),"species":0,"blocks":{}}
		for direction in Beehives.SIDES: repeated.blocks[direction+Vector3i.UP*3] = WoodTypes.leaves_id(0)
		Beehives.decorate_tree(world.generator,repeated)
		t.check(repeated == candidate,"worker-safe natural nest decoration is stable across adjacent columns and reloads")
	var generator := TerrainGenerator.new(8675309)
	var natural_pos := Vector3i(-134,40,-483)
	var natural_tree: Dictionary = WoodTypes.natural_tree(generator,-133,-483)
	t.check(natural_tree.get("blocks",{}).get(natural_pos-Vector3i(-133,37,-483),0) == Beehives.NEST+3,"actual source tree pipeline decorates a reproducible birch nest in survival terrain")
	var column := Vector2i(floori(natural_pos.x/16.0),floori(natural_pos.z/16.0))
	var generated: Dictionary = generator.generate_column(column,{})
	t.check(generated.special.get(natural_pos,0) == Beehives.NEST+3,"normal terrain worker includes natural nest in the main-thread lifecycle index")
	var mapped: Dictionary = generator.generate_column(column,{},true)
	var matching: bool = generated.blocks.size() == mapped.blocks.size()
	for i in generated.blocks.size():
		if i >= mapped.blocks.size() or generated.blocks[i].y != mapped.blocks[i].y or generated.blocks[i].data != mapped.blocks[i].data: matching = false
	t.check(matching,"background map terrain and normal worker produce identical natural hive voxels")
	var edited: Dictionary = generator.generate_column(column,{natural_pos:Nodes.AIR},true)
	for entry in edited.blocks:
		if entry.y == floori(natural_pos.y/16.0):
			var index: int = posmod(natural_pos.x,16)+posmod(natural_pos.z,16)*16+posmod(natural_pos.y,16)*256
			t.check(entry.data[index] == Nodes.AIR,"player removal edits override the deterministic natural nest on regeneration")
	for direction in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD]: world.set_node(p+direction+Vector3i.UP*2,Nodes.AIR)
	var grown_plan: Dictionary = {}; var grown_seed: int = -1; var nest_offset := Vector3i.ZERO
	for trial in 1000:
		var rng := RandomNumberGenerator.new(); rng.seed = trial
		if rng.randi_range(1,20) != 1: continue
		var direction: Vector3i = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD][rng.randi_range(0,2)]
		var candidate_plan: Dictionary = WoodTypes.tree_plan(0,trial,false)
		for y in range(1,8):
			var offset: Vector3i = direction+Vector3i.UP*y
			if candidate_plan.blocks.get(offset,Nodes.AIR) == Nodes.AIR and WoodTypes.is_leaves(int(candidate_plan.blocks.get(offset+Vector3i.UP,Nodes.AIR))):
				grown_seed = trial; grown_plan = candidate_plan; nest_offset = offset; break
		if grown_seed >= 0: break
	world.set_node(p+Vector3i.DOWN,Nodes.DIRT); world.set_node(p,Nodes.SAPLING); world.set_node(flower_pos,FoodFeatures.POPPY)
	t.check(grown_seed >= 0 and WoodTypes.grow(world,p,grown_seed) and world.node_at(p+nest_offset) == Beehives.NEST,"real oak growth dispatch creates a flower-gated nest through the source tree lifecycle")
	for offset in grown_plan.get("blocks",{}): world.set_node(p+offset,Nodes.AIR)
	world.set_node(p+nest_offset,Nodes.AIR); world.set_node(flower_pos,Nodes.AIR)

static func automation_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; var circuit: RedstoneCircuit = world.circuits; var dispenser: Vector3i = p+Vector3i.LEFT
	world.set_node(dispenser,Nodes.DISPENSER); circuit.configure(dispenser,Vector3i.RIGHT)
	var slots: Array = circuit.container(dispenser)
	# The source dispenses from a random slot; seed the generator so these cases
	# exercise the stack they set up.
	circuit.dispenser_rng.seed = 20
	for slot in slots: slot.id = 0; slot.count = 0; slot.wear = 0
	slots[0] = {"id":VillageContent.GLASS_BOTTLE,"count":2,"wear":0}; world.set_node(p,Beehives.NEST+20); healthy(game); circuit.dispense(dispenser,true)
	var honey: int = 0
	for slot in slots:
		if slot.id == Beehives.BOTTLE: honey += slot.count
	t.check(honey == 1 and slots[0].count == 1 and Beehives.level(world.node_at(p)) == 0 and game.player.health == 20,"real dispenser bottles a full nest into its inventory without retaliation")
	for i in slots.size(): slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	circuit.dispenser_rng.seed = 20
	slots[0] = {"id":VillageContent.GLASS_BOTTLE,"count":2,"wear":0}; world.set_node(p,Beehives.HIVE+20)
	var before: int = Helper.drops(game,Beehives.BOTTLE); circuit.dispense(dispenser,true)
	t.check(Helper.drops(game,Beehives.BOTTLE) == before+1 and slots[0].count == 1,"full dispenser ejects honey beyond the harvested hive without losing it")
	circuit.dispenser_rng.seed = 20
	slots[0] = {"id":Nodes.SHEARS,"count":1,"wear":Nodes.durability(Nodes.SHEARS)-1,"data":{"enchantments":{"Unbreaking":3}}}; world.set_node(p,Beehives.HIVE+20)
	before = Helper.drops(game,Beehives.COMB); circuit.dispense(dispenser,true)
	t.check(Helper.drops(game,Beehives.COMB) == before+3 and slots[0].id == 0,"source dispenser shears eject three comb and use fixed durability even with Unbreaking")
	for tool in [Nodes.SHEARS,VillageContent.GLASS_BOTTLE]:
		slots[0] = {"id":tool,"count":1,"wear":0}; world.set_node(p,Beehives.NEST+16); before = Helper.drops(game,tool); circuit.dispense(dispenser,true)
		t.check(slots[0].id == tool and slots[0].count == 1 and slots[0].wear == 0 and Helper.drops(game,tool) == before,"immature nest leaves dispenser tool/input inside unchanged: "+Nodes.title(tool))
	world.set_node(dispenser,Nodes.AIR)
	var comparator: Vector3i = p+Vector3i.RIGHT
	world.set_node(comparator+Vector3i.DOWN,Nodes.STONE); world.set_node(comparator,Nodes.COMPARATOR); circuit.configure(comparator,Vector3i.RIGHT)
	for amount in 6:
		world.set_node(p,Beehives.HIVE+amount*4); circuit.step(0.1)
		t.check(circuit.container_signal(p) == amount and circuit.state(comparator).out == amount,"real comparator reads source honey level directly: "+str(amount))
	world.set_node(comparator,Nodes.AIR); world.set_node(comparator+Vector3i.DOWN,Nodes.AIR)
	t.check(game.achievements.is_unlocked("bee_our_guest") and game.achievements.is_unlocked("total_beelocation"),"real protected bottle harvest and nonfull Silk Touch nest unlock both source achievements")

static func clear_piston(world: VoxelWorld, p: Vector3i) -> void:
	for x in range(0,16):
		for z in range(-2,3):
			for y in range(-1,3): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)

static func piston_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; var circuit: RedstoneCircuit = world.circuits; var d := Vector3i.RIGHT
	clear_piston(world,p)
	world.set_node(p,Nodes.STICKY_PISTON); circuit.configure(p,d)
	world.set_node(p+d,Beehives.HONEY_BLOCK); world.set_node(p+d+Vector3i.FORWARD,Nodes.STONE)
	world.set_node(p+d+Vector3i.BACK,Beehives.HIVE)
	world.set_node(p+d+Vector3i.UP,Beehives.HIVE+23); Beehives.station(world,p+d+Vector3i.UP).remaining = 23.25
	t.check(circuit.piston(p,true) and world.node_at(p+d*2) == Beehives.HONEY_BLOCK and world.node_at(p+d*2+Vector3i.FORWARD) == Nodes.STONE and world.node_at(p+d+Vector3i.BACK) == Beehives.HIVE,"piston pushes honey and movable side attachment while ignoring an immovable hive to its side")
	t.check(world.node_at(p+d*2+Vector3i.UP) == Beehives.HIVE+23 and Beehives.station(world,p+d*2+Vector3i.UP).remaining == 23.25,"adhesive movement preserves full-hive level, facing and production countdown")
	circuit.ticks += 5
	t.check(circuit.piston(p,false) and world.node_at(p+d) == Beehives.HONEY_BLOCK and world.node_at(p+d+Vector3i.FORWARD) == Nodes.STONE and world.node_at(p+d+Vector3i.UP) == Beehives.HIVE+23,"sticky retraction pulls honey and its side attachments back as a group")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	world.set_node(p+d,Beehives.HONEY_BLOCK); world.set_node(p+d+Vector3i.FORWARD,VillageContent.SLIME_BLOCK)
	t.check(circuit.piston(p,true) and world.node_at(p+d*2) == Beehives.HONEY_BLOCK and world.node_at(p+d+Vector3i.FORWARD) == VillageContent.SLIME_BLOCK,"actual honey push does not drag neighboring slime")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	world.set_node(p+d,VillageContent.SLIME_BLOCK); world.set_node(p+d+Vector3i.FORWARD,Beehives.HONEY_BLOCK)
	t.check(circuit.piston(p,true) and world.node_at(p+d*2) == VillageContent.SLIME_BLOCK and world.node_at(p+d+Vector3i.FORWARD) == Beehives.HONEY_BLOCK,"actual slime push reciprocally leaves neighboring honey behind")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	world.set_node(p+d,Beehives.HONEY_BLOCK); world.set_node(p+d*2,VillageContent.SLIME_BLOCK)
	t.check(circuit.piston(p,true) and world.node_at(p+d*2) == Beehives.HONEY_BLOCK and world.node_at(p+d*3) == VillageContent.SLIME_BLOCK,"opposite sticky materials still push one another when directly in front")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	world.set_node(p+d,Beehives.HONEY_BLOCK); world.set_node(p+d+Vector3i.FORWARD,Nodes.STONE); world.set_node(p+d*2+Vector3i.FORWARD,Nodes.OBSIDIAN)
	t.check(not circuit.piston(p,true) and world.node_at(p+d) == Beehives.HONEY_BLOCK and world.node_at(p+d+Vector3i.FORWARD) == Nodes.STONE,"immovable block in front of a side attachment rejects the whole adhesive push without partial movement")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	for x in range(1,13): world.set_node(p+d*x,Beehives.HONEY_BLOCK if x == 1 else Nodes.STONE)
	t.check(circuit.piston(p,true) and world.node_at(p+d*13) == Nodes.STONE,"source twelve-block piston push succeeds at the limit")
	clear_piston(world,p); world.set_node(p,Nodes.PISTON); circuit.configure(p,d)
	for x in range(1,14): world.set_node(p+d*x,Beehives.HONEY_BLOCK if x == 1 else Nodes.STONE)
	t.check(not circuit.piston(p,true) and world.node_at(p+d) == Beehives.HONEY_BLOCK and world.node_at(p+d*14) == Nodes.AIR,"source thirteenth pushed block rejects movement atomically")
	clear_piston(world,p)

static func eating_checks(t: SceneTree, game: Node3D, _p: Vector3i) -> void:
	Helper.equip(game,Beehives.BOTTLE,2); healthy(game); game.player.hunger = 12; game.player.saturation = 0; game.player.eating.clear()
	Eating.start(game.player); Eating.update(game.player,1.62,true)
	t.check(game.player.hunger == 18 and is_equal_approx(game.player.saturation,1.2) and game.inventory.count_item(Beehives.BOTTLE) == 1 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 1,"actual timed drinking restores six hunger and1.2saturation and returns glass")
	game.player.hunger = 20; game.player.eating.clear(); PotionEffects.apply(game.player,"poison",30)
	Eating.start(game.player); Eating.update(game.player,1.62,true)
	t.check(game.inventory.count_item(Beehives.BOTTLE) == 0 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 2 and PotionEffects.level(game.player,"poison") > 0,"source honey can be drunk at full hunger and does not invent a poison cure")
