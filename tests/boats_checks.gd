extends RefCounted

static func equip(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}

static func drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func point_at(game: Node3D, pos: Vector3) -> void:
	game.player.camera.look_at(pos)
	game.player.target = game.world.raycast(game.player.camera.global_position,-game.player.camera.global_basis.z,6)

static func press(key: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = key; event.keycode = key; event.pressed = down; Input.parse_input_event(event); Input.flush_buffered_events()

static func freeze(game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	for boat in game.boats.active.values(): boat.set_physics_process(false)

static func run(t: SceneTree, game: Node3D) -> void:
	for i in 5:
		var id: int = Boats.CHEST_FIRST+i
		var inv := Inventory.new()
		var recipe: Dictionary = inv.recipes[inv.recipe_index(id)]
		t.check(Nodes.exists(id) and Nodes.max_stack(id) == 1 and Nodes.fuel_time(id) == 60 and Nodes.fuel_time(VillageContent.BOAT_OAK+i) == 60,"boat variant %d is registered, unstackable and source60s fuel"%i)
		t.check(recipe.pattern == [Nodes.CHEST,VillageContent.BOAT_OAK+i] and recipe.width == 1 and recipe.station == "hand","chest boat variant %d uses source vertical chest + matching boat recipe"%i)
		inv.grid[1] = {"id":Nodes.CHEST,"count":1,"wear":0}; inv.grid[4] = {"id":VillageContent.BOAT_OAK+i,"count":1,"wear":0}
		var output: Dictionary = inv.take_grid_result("hand")
		t.check(output.get("id") == id and inv.grid[1].count == 0 and inv.grid[4].count == 0,"natural 2x2 hand crafting consumes a chest and matching boat %d"%i)
		inv.restore([]); inv.add_item(Nodes.CHEST,1); inv.add_item(VillageContent.BOAT_OAK+i,1)
		t.check(inv.fill_grid(inv.recipe_index(id),"hand") and inv.take_grid_result("hand").id == id,"recipe guide also crafts chest boat variant %d"%i)
	freeze(game); game.boats.reset(); game.boats.records().clear(); game.leads.clear()
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var p := Vector3i(8,470,8)
	for x in range(-7,8):
		for z in range(-7,8):
			game.world.set_node(p+Vector3i(x,-2,z),Nodes.STONE)
			for y in range(-1,1): game.world.set_node(p+Vector3i(x,y,z),Nodes.WATER)
			for y in range(1,6): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.gamemode = "survival"; game.player.position = Vector3(p)+Vector3(0.5,1.01,3)
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	equip(game,VillageContent.BOAT_OAK)
	game.player.target = {"pos":p,"id":Nodes.WATER,"normal":Vector3i.UP,"distance":3}
	game.player.use()
	t.check(game.boats.active.size() == 1 and game.inventory.held().count == 0 and not game.boats.ridden(),"real use places an independent boat and consumes it without auto-mounting")
	var boat: BoatEntity = game.boats.active.values()[0]; boat.set_physics_process(false)
	var key: String = boat.key
	t.check(boat.position.is_equal_approx(Vector3(p)+Vector3(0.5,0.85,0.5)) and boat.health == 4,"boat spawns at the source waterline with four health")
	point_at(game,boat.position+Vector3.UP*0.2); game.player.use()
	t.check(game.boats.riding == boat,"real right click enters the targeted boat")
	game.state = "playing"; press(KEY_W,true)
	var start: Vector3 = boat.position
	for i in 30: game.player._physics_process(1.0/60.0); boat.step(1.0/60.0)
	press(KEY_W,false)
	t.check(boat.position.z < start.z-0.15 and game.player.position.distance_to(boat.position+boat.basis*Vector3(0,0.15,-0.1)) < 0.001 and absf(boat.position.y-start.y) < 0.001,"real player movement rows the boat and follows its floating seat")
	var yaw: float = boat.rotation.y
	game.boats.drive(0.1,Vector3.RIGHT); boat.step(0.1)
	t.check(boat.rotation.y < yaw,"right input steers the hull instead of strafing it")
	var before: int = drops(game,VillageContent.BOAT_OAK)
	press(KEY_CTRL,true); game.player._physics_process(0.05); press(KEY_CTRL,false)
	t.check(not game.boats.ridden() and game.boats.active.size() == 1 and drops(game,VillageContent.BOAT_OAK) == before,"Ctrl dismount leaves the same boat entity without producing an item")
	boat.speed = 0; boat.position = start; game.player.position = start+Vector3(0,0.4,3)
	point_at(game,boat.position+Vector3.UP*0.2); game.player.use()
	t.check(game.boats.riding == boat and boat.key == key,"the same abandoned boat can be re-entered")
	game.boats.dismount(); freeze(game)
	boat.hit(1.25); boat.step(0.49)
	t.check(is_equal_approx(boat.health,2.75),"boat damage persists until the source half-second regeneration tick")
	boat.step(0.02); t.check(is_equal_approx(boat.health,3.75),"boat regenerates one health after half a second")
	boat.step(0.5); t.check(boat.health == 4,"boat regeneration caps at four health")
	# Source submerged boats sink slowly rather than floating through full columns.
	boat.position = Vector3(p)+Vector3(0.5,-0.2,0.5); boat.vertical = 0; boat.step(0.5)
	t.check(boat.position.y < p.y-0.2 and boat.vertical >= -0.2,"fully submerged boat sinks slowly with source0.2 terminal descent")
	boat.position = start; boat.vertical = 0
	# Swept hull collision must catch a bank and a tall fence above the water cell.
	game.world.set_node(p+Vector3i(0,1,-2),Nodes.STONE)
	boat.speed = 8; boat.rotation.y = 0; boat.step(0.5)
	t.check(boat.position.z >= p.z-0.5 and boat.speed == 0,"fast hull collision cannot tunnel into a bank at a long frame")
	game.world.set_node(p+Vector3i(0,1,-2),Nodes.AIR)
	boat.position = start; boat.speed = 0
	game.boats.destroy(boat); await t.process_frame
	# Failed or duplicate placement consumes nothing.
	equip(game,VillageContent.BOAT_OAK,1)
	game.world.set_node(p+Vector3i.UP,Nodes.STONE)
	var failed: BoatEntity = game.boats.place(game.inventory.held(),{"pos":p,"id":Nodes.WATER,"normal":Vector3i.UP})
	t.check(failed == null and game.inventory.held().count == 1,"blocked placement leaves its boat item untouched")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	boat = game.boats.spawn(Boats.CHEST_FIRST,start,0,{"custom_name":"Cargo ferry"}); boat.set_physics_process(false)
	var duplicate: BoatEntity = game.boats.place(game.inventory.held(),{"pos":p,"id":Nodes.WATER,"normal":Vector3i.UP})
	t.check(duplicate == null and game.inventory.held().count == 1,"overlapping boat placement cannot consume or duplicate inventory")
	boat.saved.slots[0] = {"id":Nodes.DIAMOND,"count":7,"wear":0}
	boat.saved.slots[1] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":{"title":"Log","text":"Across the river","custom_name":"Captain's log"}}
	boat.saved.slots[2] = {"id":PortableStorage.SHULKER_PURPLE,"count":1,"wear":0,"data":{"contents":[{"id":Nodes.GOLD,"count":3,"wear":0}]}}
	game.boats.open_chest(boat)
	t.check(game.state == "inventory" and game.hud.station == "chest" and game.hud.station_data.kind == "boat" and game.hud.station_data.slots.size() == 27 and game.hud.station_data.label == "Cargo ferry","chest boat opens a named27slot cargo inventory")
	game.hud.cursor = {"id":Nodes.APPLE,"count":4,"wear":0}; game.hud._slot_click(3,true,false)
	t.check(boat.saved.slots[3].id == Nodes.APPLE and boat.saved.slots[3].count == 4 and game.hud.cursor.id == 0,"actual cargo UI writes into the boat's persistent slot array")
	freeze(game)
	var cargo_key: String = boat.key
	game.player.position = start+Vector3(0,0.4,3)
	t.check(game.save_game("user://boats.json"),"boat and cargo save to disk")
	var saved: Dictionary = game.read_save("user://boats.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	freeze(game); boat = game.boats.active[cargo_key]
	t.check(game.boats.active.size() == 1 and boat.item_id == Boats.CHEST_FIRST and boat.saved.item_data.custom_name == "Cargo ferry","real reload restores exactly one boat of the same type and name")
	t.check(boat.saved.slots[0].count == 7 and boat.saved.slots[1].data.text == "Across the river" and boat.saved.slots[2].data.contents[0].count == 3 and boat.saved.slots[3].count == 4,"real reload preserves ordinary, named-book and filled-shulker cargo")
	var diamond_drops: int = drops(game,Nodes.DIAMOND); var hull_drops: int = drops(game,Boats.CHEST_FIRST)
	boat.hit(100,true); boat.hit(100,true)
	t.check(not game.boats.records().has(cargo_key) and drops(game,Nodes.DIAMOND) == diamond_drops+7 and drops(game,Boats.CHEST_FIRST) == hull_drops+1,"breaking a chest boat drops its separate cargo and hull exactly once")
	await t.process_frame
	await passenger_checks(t,game,p)
	await edge_checks(t,game,p)
	await city_guard_checks(t,game)
	await automation_checks(t,game,p)
	await dimension_checks(t,game,p)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists("user://boats.json"+suffix): DirAccess.remove_absolute("user://boats.json"+suffix)

static func passenger_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	freeze(game); game.boats.reset(); game.boats.records().clear()
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var start: Vector3 = Vector3(p)+Vector3(0.5,0.85,0.5)
	game.player.position = start+Vector3(0,0.4,3)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_BIRCH,start); boat.set_physics_process(false)
	var sheep: Creature = game.spawn_creature("sheep",start+Vector3(0.8,0.1,0)); sheep.set_physics_process(false)
	Farming.set_color(sheep,"cyan"); sheep.custom_name = "Mariner"; sheep.growth_remaining = 25; Farming.resize(sheep)
	boat.step(0.25)
	t.check(boat.passenger == sheep and Boats.is_passenger(sheep) and not sheep.is_physics_processing(),"empty ordinary boat automatically seats a nearby source-eligible mob")
	equip(game,VillageContent.LEAD)
	t.check(not game.leads.attach(sheep) and not game.leads.attached(sheep) and game.inventory.count_item(VillageContent.LEAD) == 1,"a seated passenger cannot gain a conflicting lead owner or consume a lead")
	t.check(game.boats.board(boat),"player can share an ordinary boat with its mob passenger")
	var horse: RuralAnimal = game.spawn_creature("horse",boat.position+Vector3(2.5,0,0)); horse.set_physics_process(false); horse.equip_saddle()
	equip(game,0,0); point_at(game,horse.center()); game.player.use()
	t.check(game.survival.mount == null and game.boats.riding == boat,"real use cannot mount a horse while already riding a boat")
	game.boats.dismount(); game.survival.mount = horse
	t.check(not game.boats.board(boat) and game.survival.mount == horse and not game.boats.ridden(),"boarding a boat also rejects an existing horse mount")
	game.survival.mount = null; horse.queue_free(); game.boats.board(boat)
	var age: float = sheep.growth_remaining
	boat.control = Vector3.FORWARD; boat.step(0.2)
	t.check(sheep.position.distance_to(boat.position+boat.basis*Vector3(0,0.15,0.45)) < 0.001 and sheep.growth_remaining < age,"passenger follows the rear seat while its farm growth still advances")
	game.boats.dismount(); boat.speed = 0
	var farm_key: String = sheep.farm_id; var boat_key: String = boat.key
	var pos: Vector3 = boat.position
	game.player.position += Vector3(120,0,0); game.boats.update(0.5)
	await t.process_frame
	t.check(not game.boats.active.has(boat_key) and game.boats.records()[boat_key].passenger.farm_id == farm_key and Farming.active(game,farm_key) == null,"distant boat hibernates its dyed named passenger under one saved identity")
	# Exercise a competing independent farm restore before the boat wakes.
	game.player.position = pos+Vector3(0,0.4,3); Farming.update_world(game)
	var first: Creature = Farming.active(game,farm_key)
	game.boats.update(0.5); boat = game.boats.active[boat_key]; boat.set_physics_process(false)
	var count: int = 0
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.farm_id == farm_key: count += 1
	t.check(first != null and boat.passenger == first and count == 1 and first.sheep_color == "cyan" and first.custom_name == "Mariner","returning boat reuses independently restored farm identity without duplicate passengers")
	game.boats.board(boat)
	t.check(game.save_game("user://boats.json"),"occupied ordinary boat saves its player and mob seats")
	var saved: Dictionary = game.read_save("user://boats.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	freeze(game); boat = game.boats.active[boat_key]; sheep = boat.passenger
	t.check(game.boats.riding == boat and sheep != null and sheep.farm_id == farm_key and sheep.custom_name == "Mariner","real reload remounts the player and restores its same mob passenger")
	game.boats.dismount(); boat.release_mob(); game.boats.destroy(boat)
	await t.process_frame
	t.check(not Boats.is_passenger(sheep) and sheep.health > 0 and Farming.active(game,farm_key) == sheep,"breaking or releasing a boat preserves its living passenger")
	for kind in ["horse","iron_golem","spider","ghast","end_crystal","ender_dragon"]:
		var mob: Creature = game.spawn_creature(kind,start+Vector3(3,0,0)); mob.set_physics_process(false)
		t.check(not Boats.can_ride(mob),"source excluded passenger cannot auto-board: "+kind); mob.queue_free()
	var slime: ExpeditionCreature = game.spawn_creature("slime",start+Vector3(3,0,0)); slime.set_physics_process(false)
	slime.set_slime_size(2); var large_rejected: bool = not Boats.can_ride(slime)
	slime.set_slime_size(1); t.check(large_rejected and Boats.can_ride(slime),"source only tiny slimes fit boats"); slime.queue_free()
	sheep.position = start+Vector3(4,0,0)
	boat = game.boats.spawn(Boats.CHEST_FIRST,start); boat.set_physics_process(false)
	var turtle: Creature = game.spawn_creature("turtle",start+Vector3(0.5,0,0)); turtle.set_physics_process(false)
	boat.step(0.25)
	t.check(boat.passenger == turtle and not game.boats.board(boat),"a mob occupies the chest boat's sole seat, preventing a second rider")
	AlchemyWorld.snapshot(game)
	var duplicate_turtle: bool = false
	for entry in game.world.adventure_state.alchemy_creatures:
		if entry.kind == "turtle" and VillageLife.vec(entry.position).distance_to(turtle.position) < 0.01: duplicate_turtle = true
	t.check(not duplicate_turtle,"generic alchemy snapshot excludes the boat-owned passenger")
	boat_key = boat.key; game.boats.snapshot()
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(game.boats.records()))
	game.boats.hibernate(boat); await t.process_frame
	game.world.adventure_state.boats = serialized; game.boats.restore(); boat = game.boats.active[boat_key]; boat.set_physics_process(false)
	t.check(boat.passenger is AlchemyCreature and boat.passenger.kind == "turtle","generic passenger survives JSON serialization and streaming restoration")
	var released: Creature = boat.passenger; boat.hit(100)
	t.check(released != null and not released.is_queued_for_deletion() and not Boats.is_passenger(released),"breaking a chest boat releases its sole mob passenger alive")
	await t.process_frame
	# Mounted boats stay behind on same-dimension teleport.
	boat = game.boats.spawn(VillageContent.BOAT_OAK,start); boat.set_physics_process(false); game.boats.board(boat)
	var original: Vector3 = boat.position; game.teleport(start+Vector3(4,0,2))
	t.check(not game.boats.ridden() and boat.position == original,"teleport dismounts without dragging or converting the old boat")
	game.boats.destroy(boat); await t.process_frame

static func dimension_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	freeze(game)
	var pos: Vector3 = Vector3(p)+Vector3(0.5,0.85,0.5)
	var boat: BoatEntity = game.boats.spawn(Boats.CHEST_FIRST+4,pos); boat.set_physics_process(false)
	boat.saved.slots[0] = {"id":Nodes.IRON,"count":11,"wear":0}
	var key: String = boat.key
	game.player.position = pos+Vector3(0,0.4,3); game.boats.board(boat)
	game.set_process(true); game.travel_dimension("nether")
	while game.state == "loading": await t.process_frame
	freeze(game)
	t.check(not game.boats.ridden() and not game.boats.records().has(key) and game.dimension_states.overworld.adventure.boats[key].slots[0].count == 11,"dimension travel leaves the occupied chest boat and cargo in its original dimension")
	game.set_process(true); game.travel_dimension("overworld")
	game.pending_save.position = [pos.x,pos.y+1,pos.z+3]; game.pending_save.arrival_portal = false; game.world.target = pos
	while game.state == "loading": await t.process_frame
	freeze(game)
	t.check(game.boats.active.has(key) and game.boats.active[key].saved.slots[0].count == 11 and not game.boats.ridden(),"returning to the dimension restores the same boat and cargo without unsolicited boarding")
	boat = game.boats.active[key]; game.boats.board(boat)
	game.player.health = 0; game.state = "playing"; game.die()
	t.check(not game.boats.ridden() and game.boats.records().has(key) and boat.saved.slots[0].count == 11,"player death detaches the rider without destroying or transferring chest-boat cargo")
	game.player.health = 20; freeze(game)

static func edge_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	freeze(game); game.boats.reset(); game.boats.records().clear()
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var pos: Vector3 = Vector3(p)+Vector3(0.5,0.85,0.5)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,pos); boat.set_physics_process(false)
	game.player.position = pos+Vector3(0,0.4,3); equip(game,0,0)
	point_at(game,boat.position+Vector3.UP*0.2)
	t.check(game.boats.target() == boat,"hull targeting reaches an unobstructed boat")
	game.player.target = {"distance":0.5}
	t.check(game.boats.target() == null,"a nearer solid block prevents interacting through it with a boat")
	point_at(game,boat.position+Vector3.UP*0.2)
	var obstruction: Creature = game.spawn_creature("cow",pos+Vector3(0,0.1,1.8)); obstruction.set_physics_process(false)
	t.check(game.boats.target() == null,"a nearer creature prevents striking the boat behind its body")
	obstruction.queue_free(); await t.process_frame
	point_at(game,boat.position+Vector3.UP*0.2)
	var hull_count: int = drops(game,VillageContent.BOAT_OAK)
	t.check(game.boats.punch_target() and boat.health == 1.5,"actual targeted empty-hand punch applies the source125% boat damage multiplier")
	t.check(game.boats.punch_target() and drops(game,VillageContent.BOAT_OAK) == hull_count+1,"a second targeted punch breaks the damaged hull into one boat item")
	await t.process_frame
	# Fire is environmental, so even creative mode does not erase hull/cargo.
	boat = game.boats.spawn(Boats.CHEST_FIRST,pos); boat.set_physics_process(false)
	boat.saved.slots[0] = {"id":Nodes.IRON,"count":5,"wear":0}
	var hulls: int = drops(game,Boats.CHEST_FIRST); var iron: int = drops(game,Nodes.IRON)
	game.gamemode = "creative"; equip(game,Boats.CHEST_FIRST)
	boat.hit(100,true); boat.hit(100,true)
	t.check(drops(game,Nodes.IRON) == iron+5 and drops(game,Boats.CHEST_FIRST) == hulls and game.inventory.count_item(Boats.CHEST_FIRST) == 1,"creative break drops real cargo without duplicating an already-held hull")
	await t.process_frame
	boat = game.boats.spawn(Boats.CHEST_FIRST,pos); boat.set_physics_process(false); equip(game,0,0)
	boat.hit(100,true)
	t.check(game.inventory.count_item(Boats.CHEST_FIRST) == 1,"creative break supplies one missing hull item")
	await t.process_frame
	game.gamemode = "survival"
	boat = game.boats.spawn(VillageContent.BOAT_OAK,pos); boat.set_physics_process(false)
	hull_count = drops(game,VillageContent.BOAT_OAK)
	var neighbors: Dictionary = {}
	for side in Fluids.SIDES:
		neighbors[side] = game.world.node_at(p+side); game.world.set_node(p+side,Nodes.AIR)
	game.world.set_node(p,Nodes.LAVA); boat.step(0.05)
	t.check(boat.removed and drops(game,VillageContent.BOAT_OAK) == hull_count+1,"lava contact destroys the hull and drops it once")
	game.world.set_node(p,Nodes.WATER)
	for side in neighbors: game.world.set_node(p+side,neighbors[side])
	await t.process_frame
	# Source ice permits speeds greater than ordinary water; terrain still stops it.
	game.world.set_node(p,Nodes.ICE)
	boat = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p)+Vector3(0.5,1.01,0.5)); boat.set_physics_process(false)
	boat.speed = 25; boat.step(0.01)
	t.check(boat.speed > 24 and boat.position.y >= p.y+1,"ice preserves fast travel beyond the normal eight-block water cap")
	game.boats.destroy(boat); await t.process_frame; game.world.set_node(p,Nodes.WATER)
	boat = game.boats.spawn(VillageContent.BOAT_OAK,pos); boat.set_physics_process(false)
	boat.speed = 25; boat.step(0.01)
	t.check(boat.speed <= 8.001,"ordinary water enforces the source per-axis terminal velocity")
	boat.position = pos; boat.speed = 5
	game.world.set_node(p+Vector3i(0,1,-1),VillageContent.LILY_PAD)
	var lilies: int = drops(game,VillageContent.LILY_PAD)
	boat.step(0.1)
	t.check(game.world.node_at(p+Vector3i(0,1,-1)) == Nodes.AIR and drops(game,VillageContent.LILY_PAD) == lilies+1,"boat movement uproots a crossed lily pad exactly once")
	game.boats.destroy(boat); await t.process_frame
	# Shared population identities must be reused, including offscreen sleepers.
	for kind in ["villager","piglin","shulker"]:
		boat = game.boats.spawn(VillageContent.BOAT_OAK,pos); boat.set_physics_process(false)
		var mob: Creature = game.spawn_creature(kind,pos); mob.set_physics_process(false); mob.custom_name = "Ferry "+kind
		if mob is ExpeditionCreature: mob.crystal_key = "boat-city-guard"
		boat.attach_mob(mob)
		var key: String = boat.key
		var person_key: String = mob.person_key if mob is VillageMob else ""
		var resident_key: String = mob.resident_key if mob is NetherResident else ""
		game.boats.hibernate(boat); await t.process_frame
		if kind == "shulker": t.check(game.boats.passenger_keys().has("boat-city-guard"),"sleeping boat exposes its end-city guard identity to population deduplication")
		if kind == "villager":
			game.villages.timer = 0; game.villages.update(0.5)
		elif kind == "piglin": NetherResident.resolve(game,resident_key)
		game.boats.update(0.5); boat = game.boats.active[key]; boat.set_physics_process(false)
		mob = boat.passenger
		var count: int = 0
		for live in game.creatures.get_children():
			if not live.is_queued_for_deletion() and live.custom_name == "Ferry "+kind: count += 1
		t.check(mob != null and mob.custom_name == "Ferry "+kind and count == 1 and (not mob is VillageMob or mob.person_key == person_key) and (not mob is NetherResident or mob.resident_key == resident_key),"boat wakes a unique passenger with its existing specialized identity: "+kind)
		if kind == "villager":
			game.player.position += Vector3(120,0,0); game.villages.timer = 0; game.villages.update(0.5)
			t.check(not mob.is_queued_for_deletion() and boat.passenger == mob,"independent VillageLife unload cannot erase a seated passenger before boat hibernation")
			game.player.position = pos+Vector3(0,0.4,3)
		game.boats.destroy(boat); mob.queue_free(); await t.process_frame
	t.check(Boats.clean_record({"id":Nodes.STONE,"position":[1,2,3]}).is_empty() and Boats.clean_record({"id":VillageContent.BOAT_OAK,"position":[1,"bad",3]}).is_empty(),"malformed loaded boat type and coordinates are rejected")
	var clean: Dictionary = Boats.clean_record({"id":Boats.CHEST_FIRST,"position":[1,2,3],"slots":[{"id":Nodes.DIAMOND,"count":999,"wear":-1},"bad"],"speed":999,"health":99})
	t.check(clean.slots.size() == 27 and clean.slots[0].count == 64 and clean.slots[0].wear == 0 and clean.slots[1].id == 0 and clean.health == 4 and clean.speed == 81,"loaded chest cargo and physical state use bounded sanitation")

static func automation_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	freeze(game)
	var dispenser: Vector3i = p+Vector3i(0,1,3)
	var destination: Vector3i = dispenser+Vector3i.FORWARD
	game.world.set_node(dispenser,Nodes.DISPENSER); game.world.circuits.configure(dispenser,Vector3i.FORWARD)
	var slots: Array = game.world.circuits.container(dispenser)
	slots[0] = {"id":Boats.CHEST_FIRST+2,"count":1,"wear":0,"data":{"custom_name":"Automatic ferry"}}
	game.world.circuits.dispense(dispenser,true)
	t.check(game.boats.active.size() == 1 and slots[0].id == 0,"actual dispenser consumes one boat and launches it over adjacent water")
	if game.boats.active.is_empty(): return
	var boat: BoatEntity = game.boats.active.values()[0]; boat.set_physics_process(false)
	t.check(boat.item_id == Boats.CHEST_FIRST+2 and boat.saved.item_data.custom_name == "Automatic ferry" and is_equal_approx(boat.position.y,p.y+0.85),"dispenser preserves the exact chest boat variant, name and waterline")
	var previous: int = drops(game,VillageContent.BOAT_OAK)
	slots[0] = {"id":VillageContent.BOAT_OAK,"count":1,"wear":0}
	game.world.circuits.dispense(dispenser,true)
	t.check(game.boats.active.size() == 1 and slots[0].id == 0 and drops(game,VillageContent.BOAT_OAK) == previous+1,"blocked dispenser spawn ejects one recoverable item without losing or duplicating it")
	game.boats.destroy(boat); await t.process_frame
	game.world.set_node(destination+Vector3i.DOWN,Nodes.STONE)
	previous = drops(game,VillageContent.BOAT_BIRCH)
	slots[0] = {"id":VillageContent.BOAT_BIRCH,"count":1,"wear":0}
	game.world.circuits.dispense(dispenser,true)
	t.check(game.boats.active.is_empty() and slots[0].id == 0 and drops(game,VillageContent.BOAT_BIRCH) == previous+1,"dry dispenser outlet ejects the boat as an item")
	game.world.set_node(destination+Vector3i.DOWN,Nodes.WATER)
	previous = drops(game,VillageContent.BOAT_BIRCH)
	slots[0] = {"id":VillageContent.BOAT_BIRCH,"count":1,"wear":0}
	game.world.circuits.dispense(dispenser,false)
	t.check(game.boats.active.is_empty() and drops(game,VillageContent.BOAT_BIRCH) == previous+1,"dropper mode still ejects a boat item rather than launching it")
	game.world.set_node(dispenser,Nodes.AIR)
	boat = game.boats.spawn(Boats.CHEST_FIRST,Vector3(p)+Vector3(0.5,0.85,0.5)); boat.set_physics_process(false)
	boat.saved.slots[0] = {"id":Nodes.DIAMOND,"count":9,"wear":0}
	var key: String = boat.key; var hulls: int = drops(game,Boats.CHEST_FIRST); var diamonds: int = drops(game,Nodes.DIAMOND)
	game.gamemode = "creative"; game.player.position += Vector3(10,0,0)
	game.explode(boat.position,0.75)
	t.check(boat.removed and not game.boats.records().has(key) and drops(game,Nodes.DIAMOND) == diamonds+9 and drops(game,Boats.CHEST_FIRST) == hulls+1,"actual explosion destroys a chest boat while dropping its full cargo and hull once")
	game.gamemode = "survival"; await t.process_frame

static func city_guard_checks(t: SceneTree, game: Node3D) -> void:
	var previous: Vector3 = game.player.position
	var column := Vector2i(18,0); var block := Vector3i(18,2,0)
	var guard_key: String = "291,43,0"
	game.world.columns[column] = true; game.world._create_air_block(block)
	game.player.position = Vector3(288.5,43.01,0.5)
	game.adventure.city_guards()
	var guards: Array = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == guard_key and not mob.is_queued_for_deletion())
	t.check(guards.size() == 1,"real city population creates an unnamed guard for boat transport")
	if guards.size() != 1: game.player.position = previous; return
	var guard: Creature = guards[0]; guard.set_physics_process(false)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,guard.position); boat.set_physics_process(false)
	var boat_key: String = boat.key
	boat.attach_mob(guard); game.boats.hibernate(boat)
	await t.process_frame
	game.adventure.city_guards()
	guards = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == guard_key and not mob.is_queued_for_deletion())
	t.check(guards.is_empty() and game.boats.records()[boat_key].passenger.crystal_key == guard_key,"city population does not replace an unnamed guard sleeping in a boat")
	game.boats.update(0.5); boat = game.boats.active[boat_key]; boat.set_physics_process(false)
	game.adventure.city_guards()
	guards = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == guard_key and not mob.is_queued_for_deletion())
	t.check(guards.size() == 1 and boat.passenger == guards[0],"returning to a guard's boat restores exactly one original city passenger")
	game.boats.destroy(boat)
	for mob in guards: mob.free()
	game.world._unload(column); game.player.position = previous
	await t.process_frame
