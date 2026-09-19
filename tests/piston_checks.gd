extends RefCounted

static func clear(game: Node3D) -> void:
	game.world.circuits.moving = true
	for x in range(-2,16):
		for z in range(-3,4):
			for y in range(800,808): game.world.set_node(Vector3i(x,y,z),Nodes.DIRT if y == 800 else Nodes.AIR)
	PistonPush.finish(game.world.circuits)
	game.player.position = Vector3(8.5,801,10.5); game.player.velocity = Vector3.ZERO

static func base(game: Node3D, p: Vector3i, sticky: bool = false, d: Vector3i = Vector3i.RIGHT) -> void:
	game.world.set_node(p,Nodes.STICKY_PISTON if sticky else Nodes.PISTON); game.world.circuits.configure(p,d)

static func drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.world.active = false
	game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var world: VoxelWorld = game.world; var circuit: RedstoneCircuit = world.circuits
	var p := Vector3i(0,802,0)
	clear(game); base(game,p)
	for i in range(1,13): world.set_node(p+Vector3i.RIGHT*i,Nodes.STONE)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*13) == Nodes.STONE,"frontier pushes the source maximum twelve ordinary blocks")
	t.check(circuit.piston(p,false) and world.node_at(p+Vector3i.RIGHT) == Nodes.AIR and world.node_at(p+Vector3i.RIGHT*2) == Nodes.STONE,"regular frontier piston retracts without pulling")
	world.set_node(p+Vector3i.RIGHT,Nodes.STONE)
	t.check(not circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*14) == Nodes.AIR and world.node_at(p+Vector3i.RIGHT) == Nodes.STONE,"thirteenth movable block aborts the entire push without edits")
	clear(game); base(game,p)
	for i in range(1,13): world.set_node(p+Vector3i.RIGHT*i,Nodes.STONE)
	world.set_node(p+Vector3i.RIGHT*13,Nodes.MELON); var before: int = drops(game,Nodes.MELON_SLICE)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*13) == Nodes.STONE and drops(game,Nodes.MELON_SLICE)-before in range(3,8),"fragile source fruit is destroyed beyond a full twelve-block line without counting against the limit")
	for sticky_material in [Beehives.HONEY_BLOCK,VillageContent.SLIME_BLOCK]:
		clear(game); base(game,p,true)
		world.set_node(p+Vector3i.RIGHT,sticky_material); world.set_node(p+Vector3i.RIGHT+Vector3i.BACK,Nodes.STONE)
		t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*2+Vector3i.BACK) == Nodes.STONE and world.node_at(p+Vector3i.RIGHT+Vector3i.BACK) == Nodes.AIR,"adhesive frontier pushes side-attached stone with "+Nodes.title(sticky_material))
		circuit.ticks += 5 # a later retraction, past the one-tick detach window
		t.check(circuit.piston(p,false) and world.node_at(p+Vector3i.RIGHT) == sticky_material and world.node_at(p+Vector3i.RIGHT+Vector3i.BACK) == Nodes.STONE,"sticky retraction pulls the whole connected "+Nodes.title(sticky_material)+" assembly")
		clear(game); base(game,p)
		world.set_node(p+Vector3i.RIGHT,sticky_material); world.set_node(p+Vector3i.RIGHT+Vector3i.BACK,Nodes.OBSIDIAN)
		t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT+Vector3i.BACK) == Nodes.OBSIDIAN,"immovable side neighbor is ignored by "+Nodes.title(sticky_material)+" adhesion")
		clear(game); base(game,p)
		world.set_node(p+Vector3i.RIGHT,sticky_material); world.set_node(p+Vector3i.RIGHT+Vector3i.BACK,Nodes.STONE); world.set_node(p+Vector3i.RIGHT*2+Vector3i.BACK,Nodes.OBSIDIAN)
		t.check(not circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT) == sticky_material and world.node_at(p+Vector3i.RIGHT+Vector3i.BACK) == Nodes.STONE,"a side branch's forward obstruction atomically blocks the entire "+Nodes.title(sticky_material)+" assembly")
	clear(game); base(game,p)
	world.set_node(p+Vector3i.RIGHT,Beehives.HONEY_BLOCK); world.set_node(p+Vector3i.RIGHT+Vector3i.BACK,VillageContent.SLIME_BLOCK)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT+Vector3i.BACK) == VillageContent.SLIME_BLOCK and world.node_at(p+Vector3i.RIGHT*2+Vector3i.BACK) == Nodes.AIR,"honey does not adhere to neighboring slime")
	clear(game); base(game,p)
	world.set_node(p+Vector3i.RIGHT,VillageContent.SLIME_BLOCK); world.set_node(p+Vector3i.RIGHT*2,Beehives.HONEY_BLOCK)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*3) == Beehives.HONEY_BLOCK,"honey/slime mutual exclusion does not remove ordinary forward obstruction pushing")
	for id in [Nodes.PUMPKIN,FruitCrops.CARVED,FruitCrops.JACK]:
		clear(game); base(game,p,true); world.set_node(p+Vector3i.RIGHT,id); before = drops(game,id)
		t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*2) == Nodes.AIR and drops(game,id) == before+1,"real piston destroys "+Nodes.title(id)+" once with its source item drop")
		world.set_node(p+Vector3i.RIGHT*2,id)
		circuit.ticks += 5 # a later retraction, past the one-tick detach window
		t.check(circuit.piston(p,false) and world.node_at(p+Vector3i.RIGHT*2) == id and world.node_at(p+Vector3i.RIGHT) == Nodes.AIR,"sticky piston leaves unsticky "+Nodes.title(id)+" behind")
	clear(game); p.y = 801; base(game,p)
	var stem: Vector3i = p+Vector3i.RIGHT; world.set_node(stem,FruitCrops.MELON_STEM+4)
	FruitCrops.metadata(world,stem).last_time = 234; FruitCrops.metadata(world,stem).light_count = 5; before = drops(game,FruitCrops.MELON_SEEDS)
	t.check(circuit.piston(p,true) and world.node_at(stem+Vector3i.RIGHT) == FruitCrops.MELON_STEM+4 and FruitCrops.metadata(world,stem+Vector3i.RIGHT).last_time == 234 and drops(game,FruitCrops.MELON_SEEDS) == before,"source movable non-solid stem retains growth metadata and is not incorrectly piston-dug")
	clear(game); base(game,p)
	world.set_node(p+Vector3i.RIGHT,Signs.STANDING); var sign: Dictionary = Signs.station(world,p+Vector3i.RIGHT); sign.text = "Moving words"; sign.glow = true
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT*2) == Signs.STANDING and Signs.station(world,p+Vector3i.RIGHT*2).text == "Moving words" and Signs.station(world,p+Vector3i.RIGHT*2).glow,"frontier preserves moved sign text, glow and surviving support")
	# Support is checked after the full arrangement, including the new head.
	clear(game); p.y = 802; base(game,p)
	world.set_node(p+Vector3i.RIGHT,Nodes.STONE); world.set_node(p+Vector3i.RIGHT+Vector3i.UP,FruitCrops.PUMPKIN_STEM)
	before = drops(game,FruitCrops.PUMPKIN_SEEDS)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT+Vector3i.UP) == FruitCrops.PUMPKIN_STEM and drops(game,FruitCrops.PUMPKIN_SEEDS) == before,"stem above replaced support survives the complete piston transaction without transient drops")
	circuit.piston(p,false)
	t.check(world.node_at(p+Vector3i.RIGHT+Vector3i.UP) == Nodes.AIR,"retracting the only final stem support resumes source support invalidation")
	clear(game); base(game,p)
	world.set_node(p+Vector3i.RIGHT,Nodes.STONE); world.set_node(p+Vector3i.RIGHT+Vector3i.UP,Nodes.TORCH)
	before = drops(game,Nodes.TORCH)
	t.check(circuit.piston(p,true) and world.node_at(p+Vector3i.RIGHT+Vector3i.UP) == Nodes.TORCH and drops(game,Nodes.TORCH) == before,"unrelated torch attachment survives final replacement support")
	circuit.piston(p,false)
	t.check(world.node_at(p+Vector3i.RIGHT+Vector3i.UP) == Nodes.AIR and drops(game,Nodes.TORCH) == before+1,"unrelated torch is dropped exactly once when final support really disappears")
	# Actors are predicted against the whole future arrangement before edits.
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,Nodes.STONE)
	game.player.position = Vector3(p+Vector3i.RIGHT*2)+Vector3(0.5,0.01,0.5)
	t.check(circuit.piston(p,true) and is_equal_approx(game.player.position.x,3.5) and not world.intersects(game.player.position),"piston moves an intersecting player once into a collision-free final location")
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,Nodes.STONE); world.set_node(p+Vector3i.RIGHT*3+Vector3i.UP,Nodes.STONE)
	game.player.position = Vector3(p+Vector3i.RIGHT*2)+Vector3(0.5,0.01,0.5)
	t.check(not circuit.piston(p,true) and is_equal_approx(game.player.position.x,2.5) and world.node_at(p+Vector3i.RIGHT) == Nodes.STONE,"a player's obstructed headroom prevents the push atomically without tunneling or crushing")
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,Beehives.HONEY_BLOCK)
	game.player.position = Vector3(p+Vector3i.RIGHT)+Vector3(0.5,1,0.5)
	t.check(circuit.piston(p,true) and is_equal_approx(game.player.position.x,2.5) and game.player.velocity == Vector3.ZERO,"a player standing on honey is carried once without slime launch velocity")
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,VillageContent.SLIME_BLOCK)
	game.player.position = Vector3(p+Vector3i.RIGHT*2)+Vector3(0.5,0.01,0.5)
	t.check(circuit.piston(p,true) and game.player.velocity.x == 10,"slime pushes and applies source horizontal player launch velocity")
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,VillageContent.SLIME_BLOCK)
	var tnt := PrimedTnt.new(); tnt.game = game; tnt.position = Vector3(p+Vector3i.RIGHT*2); game.entities.add_child(tnt); tnt.set_physics_process(false)
	t.check(circuit.piston(p,true) and tnt.position == Vector3(p+Vector3i.RIGHT*3) and tnt.velocity.x == 6,"primed TNT moves using its voxel-origin collision box and source other-entity slime velocity")
	tnt.queue_free(); await t.process_frame
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,VillageContent.SLIME_BLOCK)
	var arrow: Arrow = game.spawn_arrow(Vector3(p+Vector3i.RIGHT*2)+Vector3.ONE*0.5,Vector3.ZERO); arrow.set_physics_process(false)
	t.check(circuit.piston(p,true) and arrow.position == Vector3(p+Vector3i.RIGHT*3)+Vector3.ONE*0.5 and arrow.velocity.x == 6,"loose projectile entities move with the source fallback slime launch velocity")
	arrow.queue_free(); await t.process_frame
	clear(game); base(game,p); world.set_node(p+Vector3i.RIGHT,Nodes.STONE)
	var loose: ItemDrop = game.spawn_drop(Vector3(p+Vector3i.RIGHT)+Vector3.ONE*0.5,Nodes.DIRT); loose.set_physics_process(false)
	var old_loose_position: Vector3 = loose.position
	t.check(circuit.piston(p,true) and loose.position == old_loose_position,"blocked loose items follow source skip behavior and cannot jam an otherwise valid piston push")
	loose.queue_free(); await t.process_frame
	await review_checks(t,game,p)

	t.check(not circuit.moving and not world.has_meta("piston_support"),"completed pushes and pulls leave no deferred support work or transaction flag")
	clear(game)

# Repros from independent review: carrier occupants, neighbor-dependent
# geometry, movable station contents, unsupported attachments and fresh drops.
static func review_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; var circuit: RedstoneCircuit = world.circuits; var d := Vector3i.RIGHT
	clear(game); base(game,p); world.set_node(p+d,Nodes.STONE); world.set_node(p+d*3+Vector3i.UP,Nodes.STONE)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p+d*2)+Vector3(0.5,0.01,0.5)); boat.set_physics_process(false)
	game.boats.board(boat)
	t.check(not world.intersects(game.player.position) and not circuit.piston(p,true) and not world.intersects(game.player.position),"occupied boat headroom prevents a piston from pushing its rider into a ceiling above the hull")
	game.boats.dismount(false); game.boats.records().erase(boat.key); game.boats.reset(); await t.process_frame
	clear(game); base(game,p); world.set_node(p+d,Nodes.STONE); world.set_node(p+d*3+Vector3i.UP,Nodes.STONE)
	boat = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p+d*2)+Vector3(0.5,0.01,0.5)); boat.set_physics_process(false)
	var passenger: Creature = game.spawn_creature("sheep",Vector3(p)+Vector3(0.5,0,5)); passenger.set_physics_process(false); boat.attach_mob(passenger)
	t.check(not world.intersects(passenger.position,passenger.width,passenger.height) and not circuit.piston(p,true) and not world.intersects(passenger.position,passenger.width,passenger.height),"boat mob passenger bounds also prevent piston headroom trapping")
	game.boats.records().erase(boat.key); game.boats.reset(); passenger.queue_free(); await t.process_frame
	clear(game); base(game,p); world.set_node(p+d,Nodes.STONE)
	world.set_node(p+d*3+Vector3i.UP*2,BuildingShapes.slab_for(Nodes.STONE)+1)
	var horse: Creature = game.spawn_creature("horse",Vector3(p+d*2)+Vector3(0.5,0.01,0.5)); horse.set_physics_process(false)
	game.survival.mount = horse; game.player.position = horse.position+Vector3.UP*1.1
	t.check(not world.intersects(game.player.position) and not circuit.piston(p,true) and not world.intersects(game.player.position),"mounted player headroom is validated above the horse's shorter body")
	game.survival.mount = null; horse.queue_free(); await t.process_frame
	clear(game); base(game,p); world.set_node(p+d,Barriers.FIRST); world.set_node(p+d*2+Vector3i.BACK,Nodes.STONE)
	game.player.position = Vector3(p+d*2)+Vector3(0.5,1.1,1.05)
	var started_clear: bool = not world.intersects(game.player.position); var moved: bool = circuit.piston(p,true)
	t.check(started_clear and not world.intersects(game.player.position) and world.node_at(p+d*2 if moved else p+d) == Barriers.FIRST,"predicted fence geometry includes newly connected arms without embedding a nearby player")
	clear(game); base(game,p); world.set_node(p+d,Nodes.STONE); world.set_node(p+d*2+Vector3i.BACK,Barriers.FIRST)
	game.player.position = Vector3(p+d*2)+Vector3(0.5,1.1,0.95)
	started_clear = not world.intersects(game.player.position); moved = circuit.piston(p,true)
	t.check(started_clear and not world.intersects(game.player.position) and world.node_at(p+d*2+Vector3i.BACK) == Barriers.FIRST,"stationary fence gaining an arm is also included in final actor collision prediction")
	clear(game); base(game,p); world.set_node(p+d,Beehives.HONEY_BLOCK)
	world.set_node(p+d+Vector3i.BACK+Vector3i.DOWN,Nodes.STONE); world.set_node(p+d+Vector3i.BACK,Nodes.TORCH)
	t.check(circuit.piston(p,true) and world.node_at(p+d+Vector3i.BACK) == Nodes.TORCH and world.node_at(p+d*2+Vector3i.BACK) == Nodes.AIR,"source unsticky torch remains on its stationary support beside moving honey")
	clear(game); base(game,p); world.set_node(p+d+Vector3i.DOWN,Nodes.STONE); world.set_node(p+d,Nodes.TORCH)
	var before: int = drops(game,Nodes.TORCH)
	t.check(circuit.piston(p,true) and world.node_at(p+d*2) == Nodes.AIR and drops(game,Nodes.TORCH) == before+1,"direct piston contact destroys a source dig-by-piston torch exactly once")
	clear(game); base(game,p); world.set_node(p+d,VillageContent.LECTERN)
	var book: Dictionary = {"title":"Keepsake","author":"Fixture","text":"Unique retained text","custom_name":"Reader's copy"}
	world.get_station(p+d,"lectern").book = book.duplicate(true)
	t.check(circuit.piston(p,true) and world.stations.get(VoxelWorld.station_key(p+d*2),{}).get("book",{}) == book and not world.stations.has(VoxelWorld.station_key(p+d)),"movable lectern transports its saved book once and removes the stale original station")
	before = drops(game,Nodes.WRITTEN_BOOK); game.break_node(p+d*2,VillageContent.LECTERN,0)
	var exact_book: bool = false
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == Nodes.WRITTEN_BOOK and drop.data == book: exact_book = true
	t.check(drops(game,Nodes.WRITTEN_BOOK) == before+1 and exact_book,"breaking the moved lectern returns its original authored book metadata")
	clear(game); base(game,p); world.set_node(p+d,VillageContent.BANNER_WHITE)
	world.get_station(p+d,"banner").globe = true
	t.check(not circuit.piston(p,true) and world.node_at(p+d) == VillageContent.BANNER_WHITE and world.get_station(p+d,"banner").globe,"source immovable banner blocks the piston and retains its saved pattern")
	clear(game); base(game,p); world.set_node(p+d,VillageContent.ITEM_FRAME)
	var map_item: Dictionary = game.maps.create(Vector3(p)); map_item.data.custom_name = "Piston chart"
	world.get_station(p+d,"frame").slots[0] = map_item.duplicate(true)
	var frames_before: int = drops(game,VillageContent.ITEM_FRAME); var maps_before: int = drops(game,VillageContent.FILLED_MAP)
	t.check(circuit.piston(p,true) and drops(game,VillageContent.ITEM_FRAME) == frames_before+1 and drops(game,VillageContent.FILLED_MAP) == maps_before+1 and not world.stations.has(VoxelWorld.station_key(p+d)),"source piston destruction drops an item frame and its contents exactly once without a ghost station")
	var exact_map: bool = false
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == VillageContent.FILLED_MAP and drop.data == map_item.data: exact_map = true
	t.check(exact_map,"piston-dropped framed map preserves snapshot identity, region, dimension and custom name")
	# This hopper must consume only this harvest, not the book, frame and torch
	# deliberately dropped by the preceding independent fixtures.
	for drop in game.drops.get_children(): drop.queue_free()
	await t.process_frame
	clear(game); base(game,p); world.set_node(p+d,Nodes.MELON)
	var hopper: Vector3i = p+d*2+Vector3i.DOWN; world.set_node(hopper,Nodes.HOPPER); circuit.configure(hopper,Vector3i.DOWN)
	var old_drops: Array = game.drops.get_children(); var produced: int = 0; var unobstructed: bool = true
	t.check(circuit.piston(p,true),"piston can destroy source fruit while preparing a newly spawned-drop handoff")
	for drop in game.drops.get_children():
		if drop in old_drops or drop.is_queued_for_deletion() or drop.item_id != Nodes.MELON_SLICE: continue
		produced += drop.amount; unobstructed = unobstructed and not world.intersects(drop.position,0.1,0.2)
	t.check(produced in range(3,8) and unobstructed,"new fragile fruit drops are moved out of the committed piston head instead of remaining embedded")
	for i in produced: circuit.hopper(hopper)
	var captured: int = 0
	for slot in circuit.container(hopper):
		if slot.id == Nodes.MELON_SLICE: captured += slot.count
	t.check(captured == produced,"forward hopper collects every newborn piston-harvested slice without player assistance")
