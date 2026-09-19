extends RefCounted

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}

static func ticks(world: VoxelWorld, count: int) -> void:
	for i in count: world.circuits.step(0.1)

static func reset(world: VoxelWorld, p: Vector3i, id: int) -> void:
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Nodes.STONE); world.set_node(p,id)

static func drop_count(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count

static func clear_actors(game: Node3D) -> void:
	game.boats.reset(); game.boats.records().clear(); game.survival.mount = null
	for container in [game.creatures,game.drops,game.entities]:
		for child in container.get_children(): child.queue_free()
	game.player.position = Vector3(2.5,1400.01,2.5)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game.gamemode = "survival"
	clear_actors(game); await t.process_frame
	var world: VoxelWorld = game.world; var circuit: RedstoneCircuit = world.circuits
	var p := Vector3i(8,1400,8)
	for x in range(1,16):
		for z in range(1,16):
			world.set_node(Vector3i(x,1399,z),Nodes.STONE)
			for y in range(1400,1405): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var inv := Inventory.new()
	t.check(RedstoneInputs.item(Nodes.BUTTON) == 215 and RedstoneInputs.item(Nodes.PRESSURE_PLATE) == 216,"legacy stone button and pressure plate item IDs remain unchanged")
	t.check(RedstoneInputs.items().size() == 18 and RedstoneInputs.blocks().size() == 58,"eight button and ten plate materials expose only their canonical inventory items")
	for id in RedstoneInputs.items():
		var recipe_index: int = inv.recipe_index(id); var recipe: Dictionary = inv.recipes[recipe_index]
		var ingredient: int = Nodes.GOLD if id == 6978 else (Nodes.IRON if id == 6979 else RedstoneInputs.material(id))
		t.check(Nodes.exists(id) and Nodes.placeable(id) and not Nodes.solid(id) and Nodes.transparent(id) and Nodes.hardness(id) == 0.5,Nodes.title(id)+" is registered with source passable geometry and hardness")
		t.check(recipe.pattern == ([ingredient] if RedstoneInputs.is_button(id) else [ingredient,ingredient]) and recipe.station == "hand",Nodes.title(id)+" has its exact source material recipe")
		for index in 9: inv.grid[index] = {"id":0,"count":0,"wear":0}
		for index in (range(1) if RedstoneInputs.is_button(id) else range(2)): inv.grid[index+3] = {"id":ingredient,"count":1,"wear":0}
		t.check(inv.take_grid_result("hand").get("id",0) == id,Nodes.title(id)+" crafts in a naturally positioned hand grid")
		inv.restore([]); inv.add_item(ingredient,1 if RedstoneInputs.is_button(id) else 2)
		t.check(inv.fill_grid(recipe_index,"hand") and inv.take_grid_result("hand").get("id",0) == id,Nodes.title(id)+" also crafts through the recipe guide")
		t.check(Nodes.fuel_time(id) == RedstoneInputs.fuel_time(id) and not RedstoneInputs.icon_faces(id).is_empty(),Nodes.title(id)+" has source fuel and a shaped inventory icon")
	for index in 9: inv.grid[index] = {"id":0,"count":0,"wear":0}
	inv.grid[0] = {"id":Nodes.PLANKS,"count":1,"wear":0}; inv.grid[1] = {"id":WoodTypes.PLANKS[1],"count":1,"wear":0}
	t.check(inv.take_grid_result("hand").get("id",0) == 0,"pressure plates require matching species and reject mixed wood in the actual crafting grid")
	# All materials can attach in all six source directions; use the actual player path.
	for button in RedstoneInputs.BUTTON_ITEMS:
		for direction in RedstoneInputs.SUPPORTS:
			world.set_node(p,Nodes.AIR); world.set_node(p+direction,Nodes.STONE)
			held(game,button); game.player.target = {"pos":p+direction,"id":Nodes.STONE,"normal":-direction,"distance":3}
			game.player.use()
			var id: int = world.node_at(p)
			t.check(RedstoneInputs.is_button(id) and RedstoneInputs.item(id) == button and RedstoneInputs.support(id) == direction and game.inventory.held().count == 0,Nodes.title(button)+" actual placement attaches to "+str(direction))
			var box: AABB = RedstoneInputs.boxes(id)[0]
			var origin: Vector3 = Vector3(p)+box.get_center()-Vector3(direction)*0.7
			var hit: Dictionary = world.raycast(origin,Vector3(direction),1.5)
			t.check(not hit.is_empty() and hit.pos == p and world.collision_boxes(p).is_empty(),"button ray selection matches its small shape while actors pass through "+str(id))
			var before: int = drop_count(game,button)
			world.set_node(p+direction,Nodes.AIR)
			t.check(world.node_at(p) == Nodes.AIR and drop_count(game,button) == before+1,"removing button support drops exactly one canonical item "+str(id))
			world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	clear_actors(game); await t.process_frame
	# Transparent or partial supports are rejected, but source full slab faces work.
	for bad in [Nodes.GLASS,WoodTypes.LEAVES[0],5000]:
		world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,bad); held(game,6908)
		game.player.target = {"pos":p+Vector3i.DOWN,"id":bad,"normal":Vector3i.UP,"distance":3}; game.player.use()
		t.check(world.node_at(p) == Nodes.AIR and game.inventory.held().count == 1,"button rejects transparent or incomplete support "+str(bad))
	var slab: int = BuildingShapes.slab_for(Nodes.STONE)
	world.set_node(p+Vector3i.DOWN,slab); held(game,6908); game.player.target.id = slab; game.player.use()
	t.check(world.node_at(p) == Nodes.AIR and game.inventory.held().count == 1,"button cannot float above a bottom slab's missing upper half")
	world.set_node(p+Vector3i.DOWN,slab+1); game.player.target.id = slab+1; game.player.use()
	t.check(RedstoneInputs.item(world.node_at(p)) == 6908,"source full top face of an upper slab supports a button")
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Nodes.GLASS); held(game,6971); game.player.target.id = Nodes.GLASS; game.player.use()
	t.check(world.node_at(p) == 6971,"pressure plates use source walkable support and may rest on glass")
	reset(world,p,6908); world.set_node(p+Vector3i.DOWN,Nodes.GLASS)
	t.check(world.node_at(p) == 6908,"an existing button retains attachment after its support changes to another walkable node")
	# Buttons do not extend an already-active pulse; exact release durations differ.
	for button in [Nodes.BUTTON,6908,6956]:
		reset(world,p,button); game.player.target = {"pos":p,"id":button,"normal":Vector3i.UP,"distance":3}; held(game,Nodes.AIR)
		game.player.use(); ticks(world,4); var saved: Dictionary = circuit.state(p); var remaining: float = saved.remaining
		game.player.use()
		t.check(saved.out == 15 and is_equal_approx(saved.remaining,remaining),Nodes.title(button)+" pressing an active button does not extend its pulse")
		ticks(world,(15 if RedstoneInputs.wooden(button) else 10)-5)
		t.check(saved.out == 15,Nodes.title(button)+" stays powered until the final source tick")
		ticks(world,1)
		t.check(saved.out == 0 and saved.remaining == 0,Nodes.title(button)+" releases at its exact source duration")
	# Weak output goes to every button neighbor, strong output only into the support.
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.RIGHT,Nodes.STONE); world.set_node(p+Vector3i.UP,Nodes.STONE)
	var wall_button: int = RedstoneInputs.oriented(6908,Vector3i.LEFT)
	world.set_node(p,wall_button); RedstoneInputs.press(world,p); ticks(world,1)
	t.check(circuit.output(p,Vector3i.UP) == 15 and circuit.strong.get(p+Vector3i.RIGHT,0) == 15 and circuit.strong.get(p+Vector3i.UP,0) == 0,"real circuit strongly powers only a button's attachment while weakly powering neighbors")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p+Vector3i.UP,Nodes.AIR)
	# Detection distinguishes collision contact, object kind and source radius.
	for id in [Nodes.PRESSURE_PLATE,6971,6977,6978,6979]:
		clear_actors(game); await t.process_frame; reset(world,p,id)
		var drop: ItemDrop = game.spawn_drop(Vector3(p)+Vector3(0.5,0.01,0.5),Nodes.DIAMOND,64); drop.set_physics_process(false)
		ticks(world,1)
		var expected: int = 0 if id in [Nodes.PRESSURE_PLATE,6977,6979] else (1 if id == 6978 else 15)
		t.check(circuit.state(p).out == expected,Nodes.title(id)+" senses a64-item stack as one eligible entity")
		drop.queue_free(); game.player.position = Vector3(p)+Vector3(0.5,0.02,0.5); reset(world,p,id); ticks(world,1)
		t.check(circuit.state(p).out == (0 if id == 6979 else (1 if id == 6978 else 15)),Nodes.title(id)+" senses standing player contact")
		game.player.position = Vector3(p)+Vector3(0.5,0.2,0.5); reset(world,p,id); ticks(world,1)
		t.check(circuit.state(p).out == 0 and not circuit.state(p).input_pressed,Nodes.title(id)+" does not activate merely because a player is above its contact plane")
	clear_actors(game); await t.process_frame; reset(world,p,6979)
	var weights: Array = []
	for i in 11:
		var drop: ItemDrop = game.spawn_drop(Vector3(p)+Vector3(0.5,0.01,0.5),Nodes.STONE,64); drop.set_physics_process(false); weights.append(drop)
	ticks(world,1)
	t.check(circuit.state(p).out == 1 and circuit.state(p).input_pressed,"eleven separate stacks produce heavy plate power one, matching verified Luanti truncation")
	for i in range(1,11): weights[i].queue_free()
	ticks(world,1)
	t.check(circuit.state(p).out == 0 and circuit.state(p).input_pressed and RedstoneInputs.boxes(6979,circuit.state(p))[0].size.y == 1.0/32,"one remaining stack visibly depresses a heavy plate while its integer signal is zero")
	t.check(RedstoneInputs.count_power(6979,9) == 0 and RedstoneInputs.count_power(6979,10) == 1 and RedstoneInputs.count_power(6979,149) == 14 and RedstoneInputs.count_power(6979,150) == 15 and RedstoneInputs.count_power(6978,19) == 15,"weighted source thresholds and maximum power are exact")
	clear_actors(game); await t.process_frame; reset(world,p,Nodes.PRESSURE_PLATE)
	var mob := Creature.new(); mob.game = game; mob.kind = "cow"; game.creatures.add_child(mob); mob.set_physics_process(false); mob.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	ticks(world,1)
	t.check(circuit.state(p).out == 15,"stone plates activate for a real mob")
	mob.set_meta("boat_key","attached-test"); reset(world,p,Nodes.PRESSURE_PLATE); ticks(world,1)
	t.check(circuit.state(p).out == 0,"attached passengers are excluded from plate entity counts")
	mob.remove_meta("boat_key"); mob.position += Vector3.UP*0.2; ticks(world,1)
	t.check(circuit.state(p).out == 0,"mob collision feet must contact the plate")
	mob.position = Vector3(p)+Vector3(0.5,0.01,0.5); ticks(world,1); mob.queue_free(); ticks(world,9)
	t.check(circuit.state(p).out == 15,"pressure plate output persists for its one-second source release delay")
	ticks(world,1); t.check(circuit.state(p).out == 0,"pressure plate releases after the final delayed tick")
	game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5); ticks(world,1)
	t.check(circuit.output(p,Vector3i.UP) == 0 and circuit.output(p,Vector3i.RIGHT) == 15 and circuit.strong.get(p+Vector3i.DOWN,0) == 15,"plate emits no upward weak signal and strongly powers only its supporting block")
	clear_actors(game); await t.process_frame
	# Source any-object plates count physical entities, excluding their attached riders.
	var boat := BoatEntity.new(); boat.game = game; boat.service = game.boats; game.entities.add_child(boat); boat.set_physics_process(false); boat.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	var potion := PotionProjectile.new(); potion.game = game; potion.item_id = PotionCatalog.ITEMS.keys()[0]; game.entities.add_child(potion); potion.set_physics_process(false); potion.position = Vector3(p)+Vector3(0.5,0.1,0.5)
	var primed := PrimedTnt.new(); primed.game = game; game.entities.add_child(primed); primed.set_physics_process(false); primed.position = Vector3(p)
	var stuck_arrow: Arrow = game.spawn_arrow(Vector3(p)+Vector3(0.5,0.1,0.5),Vector3.ZERO); stuck_arrow.stuck = true; stuck_arrow.set_physics_process(false)
	var snowball := ThrownItem.new(); snowball.game = game; snowball.item_id = Nodes.SNOWBALL; game.entities.add_child(snowball); snowball.set_physics_process(false); snowball.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	game.player.position = boat.position; game.boats.riding = boat
	reset(world,p,6978); ticks(world,1)
	t.check(circuit.state(p).out == 4,"gold plate counts boat, thrown potion, primed TNT and arrow, excluding its mounted rider and nonphysical snowball")
	reset(world,p,6971); ticks(world,1); t.check(circuit.state(p).out == 15,"wood plate accepts the same source physical objects")
	reset(world,p,Nodes.PRESSURE_PLATE); ticks(world,1); t.check(circuit.state(p).out == 0,"stone plate rejects nonliving objects and attached players")
	potion.cloud = true; reset(world,p,6978); ticks(world,1); t.check(circuit.state(p).out == 3,"lingering potion cloud stops contributing physical weight")
	game.boats.riding = null; clear_actors(game); await t.process_frame
	# Actual flying projectiles lodge in the backing block, not the passable button.
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.FORWARD,Nodes.STONE)
	wall_button = RedstoneInputs.oriented(6908,Vector3i.BACK); world.set_node(p,wall_button)
	game.state = "playing"; var arrow: Arrow = game.spawn_arrow(Vector3(p)+Vector3(0.5,0.5,0.6),Vector3(0,0,-15)); arrow.set_physics_process(false)
	for i in 10: arrow._physics_process(0.01)
	t.check(arrow.stuck and circuit.state(p).out == 15,"a real arrow striking a wood button's backing block activates the button")
	arrow.queue_free(); reset(world,p,Nodes.BUTTON); world.set_node(p,Nodes.AIR)
	var stone_wall: int = RedstoneInputs.oriented(Nodes.BUTTON,Vector3i.BACK); world.set_node(p,stone_wall)
	arrow = game.spawn_arrow(Vector3(p)+Vector3(0.5,0.5,0.6),Vector3(0,0,-15)); arrow.set_physics_process(false)
	for i in 10: arrow._physics_process(0.01)
	t.check(arrow.stuck and circuit.state(p).out == 0,"the declared stone material rule rejects arrow activation")
	arrow.queue_free(); world.set_node(p,Nodes.AIR); world.set_node(p,wall_button)
	var trident := TridentProjectile.new(); trident.game = game; trident.stack = {"id":VillageContent.TRIDENT,"count":1,"wear":0}; trident.consumed = false; game.entities.add_child(trident); trident.set_physics_process(false)
	trident.position = Vector3(p)+Vector3(0.5,0.5,0.6); trident.velocity = Vector3(0,0,-15)
	for i in 10:
		if trident.is_queued_for_deletion(): break
		trident._physics_process(0.01)
	t.check(circuit.state(p).out == 15,"a real thrown trident uses the source button hit callback")
	game.pause(); game.world.active = false; world.set_node(p,Nodes.AIR); world.set_node(p,wall_button)
	t.check(not RedstoneInputs.projectile_hit(world,Vector3(p)+Vector3(0.5,0.5,-1.6),Vector3(0,0,2)) and circuit.state(p).out == 0,"hitting the back of a supporting block cannot activate its far-side button")
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.FORWARD,Nodes.AIR)
	# Flow destroys source buttons once; pressure plates block replacement.
	reset(world,p,6908); world.set_node(p+Vector3i.UP,Nodes.WATER)
	var washed_before: int = drop_count(game,6908); world.fluids.settle(p,Nodes.WATER)
	t.check(Fluids.water(world.node_at(p)) and drop_count(game,6908) == washed_before+1,"water washes away a wood button and drops exactly one canonical item")
	world.set_node(p+Vector3i.UP,Nodes.AIR); reset(world,p,6971); world.set_node(p+Vector3i.UP,Nodes.WATER); world.fluids.settle(p,Nodes.WATER)
	t.check(world.node_at(p) == 6971,"source pressure plates resist fluid replacement")
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Nodes.AIR)
	# Pistons destroy attachments with one item instead of moving or duplicating them.
	for id in [6908,6978]:
		world.set_node(p,Nodes.PISTON); circuit.configure(p,Vector3i.RIGHT)
		world.set_node(p+Vector3i.RIGHT+Vector3i.DOWN,Nodes.STONE); world.set_node(p+Vector3i.RIGHT,id)
		var before: int = drop_count(game,id)
		t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT) == Nodes.PISTON_HEAD and drop_count(game,id) == before+1,"piston destroys "+Nodes.title(id)+" and drops one canonical item")
		circuit.piston(p,false); world.set_node(p,Nodes.AIR)
	# Legacy orientations and active durations survive the actual save/load path.
	var legacy := Vector3i(11,1400,8); world.set_node(legacy+Vector3i.LEFT,Nodes.STONE); world.set_node(legacy,Nodes.BUTTON)
	world.block_states[VoxelWorld.station_key(legacy)] = {"support":[-1,0,0],"remaining":0.6,"out":15}
	var active := Vector3i(8,1400,11); reset(world,active,6948); RedstoneInputs.press(world,active); ticks(world,3)
	var remaining: float = circuit.state(active).remaining
	var legacy_remaining: float = circuit.state(legacy).remaining
	var weighted := Vector3i(11,1400,11); reset(world,weighted,6979)
	var weight: ItemDrop = game.spawn_drop(Vector3(weighted)+Vector3(0.5,0.01,0.5),Nodes.STONE,64); weight.set_physics_process(false)
	RedstoneInputs.tick(world,weighted,6979,circuit.state(weighted),0.1)
	t.check(game.save_game("user://input_device_check.json"),"active controls and legacy button metadata save successfully")
	var saved_game: Dictionary = game.read_save("user://input_device_check.json"); game.set_process(true); game.load_world_data(saved_game)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false); world = game.world; circuit = world.circuits
	var migrated_id: int = RedstoneInputs.oriented(Nodes.BUTTON,Vector3i.RIGHT)
	t.check(world.node_at(legacy) == migrated_id and world.edits.get(legacy,0) == migrated_id and circuit.tracked.get(legacy,0) == migrated_id and RedstoneInputs.support(world.node_at(legacy)) == Vector3i.LEFT and is_equal_approx(circuit.state(legacy).remaining,legacy_remaining),"reload migrates a legacy wall button with matching block, edit, simulation state and remaining pulse")
	t.check(is_equal_approx(circuit.state(active).remaining,remaining) and circuit.state(active).out == 15,"reload preserves a partially elapsed wood-button pulse")
	t.check(circuit.state(weighted).out == 0 and circuit.state(weighted).input_pressed and is_equal_approx(circuit.state(weighted).remaining,1.0),"reload preserves a physically depressed heavy plate whose integer output is zero")
	world._unload(Vector2i(0,0)); t.check(not circuit.tracked.has(active),"unloaded controls leave the active redstone simulation index")
	world._apply_column(world.generator.generate_column(Vector2i(0,0),world.edits.duplicate()))
	t.check(circuit.tracked.has(active) and is_equal_approx(circuit.state(active).remaining,remaining),"streaming reload restores the same saved pulse without ticking unloaded time")
	# A neighbor's unloaded support is unknown, not air; verify only after it returns.
	var edge := Vector3i(15,1400,8); var backing: Vector3i = edge+Vector3i.RIGHT
	world.set_node(backing,Nodes.STONE); world.set_node(edge,RedstoneInputs.oriented(6908,Vector3i.LEFT))
	world._unload(Vector2i(1,0)); RedstoneInputs.support_changed(world,edge)
	t.check(RedstoneInputs.is_button(world.node_at(edge)),"unloading a neighboring support column does not destroy an attached button")
	var new_edge: Vector3i = edge+Vector3i.BACK
	held(game,6908); game.player.target = {"pos":new_edge+Vector3i.RIGHT,"id":Nodes.BEDROCK,"normal":Vector3i.LEFT,"distance":3}; game.player.use()
	t.check(world.node_at(new_edge) == Nodes.AIR and game.inventory.held().count == 1,"new buttons cannot attach to the artificial boundary of an unloaded support column")
	world.edits[backing] = Nodes.AIR
	var edge_drops: int = drop_count(game,6908)
	world._apply_column(world.generator.generate_column(Vector2i(1,0),world.edits.duplicate()))
	t.check(world.node_at(edge) == Nodes.AIR and drop_count(game,6908) == edge_drops+1,"support-column reload validates a neighboring saved button and drops it exactly once if support is gone")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://input_device_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
