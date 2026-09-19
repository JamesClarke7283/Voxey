class_name Beehives
extends RefCounted

# Rules ported from local Mineclonia mcl_beehives/mcl_honey; artwork is original.
const HIVE = 7600
const NEST = 7624
const COMB = 7650
const BOTTLE = 7651
const COMB_BLOCK = 7652
const HONEY_BLOCK = 7653
const INTERVAL = 75.0
const SCAN_BUDGET = 128
const SIDES = [Vector3i.BACK,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.LEFT]
const BLOCKS = [7600,7601,7602,7603,7604,7605,7606,7607,7608,7609,7610,7611,7612,7613,7614,7615,7616,7617,7618,7619,7620,7621,7622,7623,7624,7625,7626,7627,7628,7629,7630,7631,7632,7633,7634,7635,7636,7637,7638,7639,7640,7641,7642,7643,7644,7645,7646,7647,7652,7653,7660,7661,7662,7663,7664,7665,7666,7667,7668]
const DATA = {
	7600:{"name":"Beehive","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","fuel":15,"source_node":"mcl_beehives:beehive"},
	7601:{"name":"Beehive","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","fuel":15,"hidden":true,"source_node":"mcl_beehives:beehive"},
	7602:{"name":"Beehive","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","fuel":15,"hidden":true,"source_node":"mcl_beehives:beehive"},
	7603:{"name":"Beehive","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","fuel":15,"hidden":true,"source_node":"mcl_beehives:beehive"},
	7604:{"name":"Beehive","description":"Honey: 1/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_1"},
	7605:{"name":"Beehive","description":"Honey: 1/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_1"},
	7606:{"name":"Beehive","description":"Honey: 1/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_1"},
	7607:{"name":"Beehive","description":"Honey: 1/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_1"},
	7608:{"name":"Beehive","description":"Honey: 2/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_2"},
	7609:{"name":"Beehive","description":"Honey: 2/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_2"},
	7610:{"name":"Beehive","description":"Honey: 2/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_2"},
	7611:{"name":"Beehive","description":"Honey: 2/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_2"},
	7612:{"name":"Beehive","description":"Honey: 3/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_3"},
	7613:{"name":"Beehive","description":"Honey: 3/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_3"},
	7614:{"name":"Beehive","description":"Honey: 3/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_3"},
	7615:{"name":"Beehive","description":"Honey: 3/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_3"},
	7616:{"name":"Beehive","description":"Honey: 4/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_4"},
	7617:{"name":"Beehive","description":"Honey: 4/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_4"},
	7618:{"name":"Beehive","description":"Honey: 4/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_4"},
	7619:{"name":"Beehive","description":"Honey: 4/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_4"},
	7620:{"name":"Beehive","description":"Honey: 5/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_5"},
	7621:{"name":"Beehive","description":"Honey: 5/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_5"},
	7622:{"name":"Beehive","description":"Honey: 5/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_5"},
	7623:{"name":"Beehive","description":"Honey: 5/5","block":true,"color":"b1874b","hardness":0.6,"tool":1,"drop":0,"flammable":false,"note_material":"wood","hidden":true,"source_node":"mcl_beehives:beehive_5"},
	7624:{"name":"Bee nest","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"fuel":15,"source_node":"mcl_beehives:bee_nest"},
	7625:{"name":"Bee nest","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"fuel":15,"hidden":true,"source_node":"mcl_beehives:bee_nest"},
	7626:{"name":"Bee nest","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"fuel":15,"hidden":true,"source_node":"mcl_beehives:bee_nest"},
	7627:{"name":"Bee nest","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"fuel":15,"hidden":true,"source_node":"mcl_beehives:bee_nest"},
	7628:{"name":"Bee nest","description":"Honey: 1/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_1"},
	7629:{"name":"Bee nest","description":"Honey: 1/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_1"},
	7630:{"name":"Bee nest","description":"Honey: 1/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_1"},
	7631:{"name":"Bee nest","description":"Honey: 1/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_1"},
	7632:{"name":"Bee nest","description":"Honey: 2/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_2"},
	7633:{"name":"Bee nest","description":"Honey: 2/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_2"},
	7634:{"name":"Bee nest","description":"Honey: 2/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_2"},
	7635:{"name":"Bee nest","description":"Honey: 2/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_2"},
	7636:{"name":"Bee nest","description":"Honey: 3/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_3"},
	7637:{"name":"Bee nest","description":"Honey: 3/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_3"},
	7638:{"name":"Bee nest","description":"Honey: 3/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_3"},
	7639:{"name":"Bee nest","description":"Honey: 3/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_3"},
	7640:{"name":"Bee nest","description":"Honey: 4/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_4"},
	7641:{"name":"Bee nest","description":"Honey: 4/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_4"},
	7642:{"name":"Bee nest","description":"Honey: 4/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_4"},
	7643:{"name":"Bee nest","description":"Honey: 4/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_4"},
	7644:{"name":"Bee nest","description":"Honey: 5/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_5"},
	7645:{"name":"Bee nest","description":"Honey: 5/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_5"},
	7646:{"name":"Bee nest","description":"Honey: 5/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_5"},
	7647:{"name":"Bee nest","description":"Honey: 5/5","block":true,"color":"c6964a","hardness":0.3,"tool":1,"drop":0,"flammable":false,"hidden":true,"source_node":"mcl_beehives:bee_nest_5"},
	7650:{"name":"Honeycomb","color":"e9a931","source_node":"mcl_honey:honeycomb"},
	7651:{"name":"Honey bottle","color":"e9aa2c","food":6,"stack":16,"source_node":"mcl_honey:honey_bottle"},
	7652:{"name":"Honeycomb block","block":true,"color":"dba333","hardness":0.6,"tool":-1,"drop":7652,"source_node":"mcl_honey:honeycomb_block"},
	7653:{"name":"Honey block","block":true,"color":"e7a226","hardness":0.0,"tool":-1,"drop":7653,"source_node":"mcl_honey:honey_block"},
	7660:{"name":"Hive texture","color":"c6964a","hidden":true},
	7661:{"name":"Hive texture","color":"c6964a","hidden":true},
	7662:{"name":"Hive texture","color":"c6964a","hidden":true},
	7663:{"name":"Hive texture","color":"c6964a","hidden":true},
	7664:{"name":"Hive texture","color":"c6964a","hidden":true},
	7665:{"name":"Hive texture","color":"c6964a","hidden":true},
	7666:{"name":"Hive texture","color":"c6964a","hidden":true},
	7667:{"name":"Hive texture","color":"c6964a","hidden":true},
	7668:{"name":"Hive texture","color":"c6964a","hidden":true},
}
static func is_hive(id: int) -> bool: return id >= HIVE and id < NEST+24
static func is_nest(id: int) -> bool: return id >= NEST and id < NEST+24
static func level(id: int) -> int: return (id-base_item(id))/4 if is_hive(id) else 0
static func facing(id: int) -> int: return posmod(id-HIVE,4)
static func base_item(id: int) -> int: return NEST if is_nest(id) else HIVE
static func item(id: int) -> int: return base_item(id)+level(id)*4 if is_hive(id) else id
static func state_id(id: int, amount: int) -> int: return base_item(id)+clampi(amount,0,5)*4+facing(id)
static func oriented(id: int, yaw: float) -> int: return item(id)+posmod(2-roundi(yaw/(PI/2)),4) if is_hive(id) else id
static func immovable(id: int) -> bool: return is_hive(id) and not is_nest(id) and level(id) < 5
static func signal_strength(world: VoxelWorld, p: Vector3i) -> int: return level(world.node_at(p))
static func replacement(id: int) -> int: return VillageContent.GLASS_BOTTLE if id == BOTTLE else 0
static func fall_multiplier(id: int) -> float: return 0.2 if id == HONEY_BLOCK else 1.0
static func sticky(id: int) -> bool: return id in [HONEY_BLOCK,VillageContent.SLIME_BLOCK]
static func sticks(id: int, neighbor_id: int) -> bool:
	return sticky(id) and not (id == HONEY_BLOCK and neighbor_id == VillageContent.SLIME_BLOCK or id == VillageContent.SLIME_BLOCK and neighbor_id == HONEY_BLOCK)
static func flower(id: int) -> bool: return id == Nodes.FLOWER or FoodFeatures.flower(id)

static func recipes(inv: Inventory) -> void:
	inv._recipe("Beehive",HIVE,1,[Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,COMB,COMB,COMB,Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS],3,"table")
	inv._recipe("Honeycomb block",COMB_BLOCK,1,[COMB,COMB,COMB,COMB],2)
	inv._recipe("Sugar from honey",Nodes.SUGAR,3,[BOTTLE],1)
	inv._recipe("Honey block",HONEY_BLOCK,1,[BOTTLE,BOTTLE,BOTTLE,BOTTLE],2)
	inv._recipe("Bottle honey block",BOTTLE,4,[VillageContent.GLASS_BOTTLE,VillageContent.GLASS_BOTTLE,HONEY_BLOCK,VillageContent.GLASS_BOTTLE,VillageContent.GLASS_BOTTLE,0],3,"table")

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("beehives"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+27601
		world.set_meta("beehives",{"cells":{},"columns":{},"jobs":[],"pending":{},"rng":rng,"samples":0})
	return world.get_meta("beehives")

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {"kind":"beehive","remaining":INTERVAL,"slots":[]}
	var data: Dictionary = world.stations[key]
	var remaining: Variant = data.get("remaining",INTERVAL)
	data.kind = "beehive"; data.slots = []
	data.remaining = clampf(float(remaining),0,INTERVAL) if (remaining is int or remaining is float) and is_finite(float(remaining)) else INTERVAL
	return data

static func registered(world: VoxelWorld, p: Vector3i) -> void:
	if not is_hive(world.node_at(p)) or not world.loaded_at(Vector3(p)): return
	var state: Dictionary = runtime(world)
	if state.cells.has(p): return
	state.cells[p] = true; station(world,p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true

static func remove_runtime(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("beehives"): return
	var state: Dictionary = runtime(world)
	state.cells.erase(p); state.pending.erase(p)
	state.jobs = state.jobs.filter(func(job): return job.pos != p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("beehives"): return
	for p in runtime(world).columns.get(column,{}).keys(): remove_runtime(world,p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("beehives"): world.remove_meta("beehives")

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if is_hive(old_id) and not is_hive(id):
		remove_runtime(world,p); world.stations.erase(VoxelWorld.station_key(p))
	if is_hive(id): registered(world,p)

static func move_state(world: VoxelWorld, p: Vector3i) -> Dictionary:
	return station(world,p).duplicate(true) if is_hive(world.node_at(p)) else {}

static func restore_moved(world: VoxelWorld, p: Vector3i, data: Dictionary) -> void:
	if data.is_empty() or not is_hive(world.node_at(p)): return
	world.stations[VoxelWorld.station_key(p)] = data.duplicate(true)
	station(world,p); registered(world,p)

static func eligible(time_of_day: float, weather: String) -> bool:
	return time_of_day > 0.25 and time_of_day < 0.75 and weather != "rain"

static func environment(world: VoxelWorld) -> bool:
	var game: Node = world.get_parent()
	return game != null and eligible(game.day_time,game.survival.weather())

static func advance(world: VoxelWorld, p: Vector3i, roll: int) -> bool:
	var id: int = world.node_at(p)
	if not world.loaded_at(Vector3(p)) or not is_hive(id) or level(id) == 5: return false
	return world.set_node(p,state_id(id,level(id)+(2 if roll == 100 else 1)))

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("beehives") or delta <= 0 or not is_finite(delta): return
	var game: Node = world.get_parent()
	if game == null or not game.playing(): return
	var state: Dictionary = runtime(world); var rng: RandomNumberGenerator = state.rng
	state.samples = 0
	for p in state.cells.keys():
		if not world.loaded_at(Vector3(p)) or not is_hive(world.node_at(p)): remove_runtime(world,p); continue
		if level(world.node_at(p)) == 5 or state.pending.has(p): continue
		var data: Dictionary = station(world,p)
		data.remaining = maxf(0,float(data.remaining)-delta)
		if data.remaining > 0: continue
		if environment(world): state.jobs.append({"pos":p,"cursor":0}); state.pending[p] = true
		else: data.remaining = INTERVAL
	# A large apiary never triggers an unbounded 11³ flower scan in one frame.
	# Saved timers restart pending scans, and unloaded hives do not advance.
	while state.samples < SCAN_BUDGET and not state.jobs.is_empty():
		var job: Dictionary = state.jobs[0]
		if not state.cells.has(job.pos) or not environment(world) or level(world.node_at(job.pos)) == 5:
			if state.cells.has(job.pos): station(world,job.pos).remaining = INTERVAL
			state.jobs.pop_front(); state.pending.erase(job.pos); continue
		var cursor: int = job.cursor
		var q: Vector3i = job.pos+Vector3i(cursor%11-5,cursor/121-5,cursor/11%11-5)
		job.cursor += 1; state.samples += 1
		var found: bool = world.loaded_at(Vector3(q)) and flower(world.node_at(q))
		if found: advance(world,job.pos,rng.randi_range(1,100))
		if found or job.cursor >= 1331:
			station(world,job.pos).remaining = INTERVAL
			state.jobs.pop_front(); state.pending.erase(job.pos)

static func protected_by_smoke(world: VoxelWorld, p: Vector3i) -> bool:
	for depth in range(1,6):
		var q: Vector3i = p+Vector3i.DOWN*depth
		if world.loaded_at(Vector3(q)) and Campfires.lit(world.node_at(q)): return true
	return false

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_hive(int(target.id)) or game.target_mob() != null or Signs.sneaking(game): return false
	var p: Vector3i = target.pos; var id: int = game.world.node_at(p)
	var held: Dictionary = game.inventory.held()
	if not is_hive(id) or level(id) != 5 or held.id not in [Nodes.SHEARS,VillageContent.GLASS_BOTTLE] or held.count <= 0: return false
	var bottle: bool = held.id == VillageContent.GLASS_BOTTLE
	var smoke: bool = protected_by_smoke(game.world,p)
	if not game.world.set_node(p,state_id(id,0)): return true
	# Deliver/consume before damage can kill the player and clear inventory.
	if bottle:
		if game.gamemode != "creative": game.inventory.consume_selected()
		var remaining: int = game.inventory.add_item(BOTTLE,1)
		if remaining: game.spawn_drop(game.player.position+Vector3(0,0.7,0),BOTTLE,remaining)
		if smoke: game.achievements.award("bee_our_guest")
	else:
		game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,COMB,3)
		if game.gamemode != "creative": game.inventory.damage_tool()
	game.player.swing = 1; game.sound("place")
	if not smoke: game.player.hurt(10,false,Vector3(p)+Vector3.ONE*0.5,"mob")
	return true

static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int, blast: bool = false) -> bool:
	if not is_hive(id): return false
	var silk: bool = Inventory.enchantment(game.inventory.held(),"Silk Touch") > 0
	if is_nest(id) and game.inventory.held().id == VillageContent.ENCHANTED_BOOK: silk = false
	if not game.world.set_node(p,Nodes.AIR): return true
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.DOWN,Vector3i.UP,Vector3i.FORWARD,Vector3i.BACK]: game.settle(p+direction)
	if not blast:
		if game.gamemode == "creative":
			if game.inventory.count_item(base_item(id)) == 0 and game.inventory.capacity(base_item(id)) > 0: game.inventory.add_item(base_item(id),1)
		else:
			if not silk: game.player.hurt(10,false,Vector3(p)+Vector3.ONE*0.5,"mob")
			if silk or not is_nest(id): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,item(id) if silk else HIVE,1)
			if silk and is_nest(id): game.achievements.award("total_beelocation")
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

static func dispense(circuit: RedstoneCircuit, p: Vector3i, target: Vector3i, direction: Vector3i, slot: Dictionary) -> bool:
	var id: int = circuit.world.node_at(target)
	if slot.id not in [VillageContent.GLASS_BOTTLE,Nodes.SHEARS] or not is_hive(id): return false
	if level(id) != 5: return true
	if not circuit.world.set_node(target,state_id(id,0)): return true
	var game: Node = circuit.world.get_parent()
	if slot.id == VillageContent.GLASS_BOTTLE:
		circuit.consume_one(slot)
		if not circuit.insert_one(circuit.container(p),{"id":BOTTLE,"count":1,"wear":0}): game.spawn_drop(Vector3(target+direction)+Vector3.ONE*0.5,BOTTLE,1)
	else:
		game.spawn_drop(Vector3(target+direction)+Vector3.ONE*0.5,COMB,3)
		slot.wear = int(slot.get("wear",0))+1
		if slot.wear >= Nodes.durability(Nodes.SHEARS): slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
	return true

static func after_tree_grow(world: VoxelWorld, origin: Vector3i, kind: int, seed_value: int = -1) -> bool:
	if kind not in [0,2]: return false
	var found: bool = false
	for x in range(-2,3):
		for z in range(-2,3):
			var q: Vector3i = origin+Vector3i(x,0,z)
			if world.loaded_at(Vector3(q)) and flower(world.node_at(q)): found = true
	if not found: return false
	var rng := RandomNumberGenerator.new(); rng.seed = randi() if seed_value < 0 else seed_value
	if rng.randi_range(1,20) != 1: return false
	var direction: Vector3i = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD][rng.randi_range(0,2)]
	for y in range(1,8):
		var p: Vector3i = origin+direction+Vector3i.UP*y
		if not world.loaded_at(Vector3(p+Vector3i.UP)): continue
		var above: int = world.node_at(p+Vector3i.UP)
		if world.node_at(p) == Nodes.AIR and (WoodTypes.is_leaves(above) or WoodTypes.is_log(above)): return world.set_node(p,NEST)
	return false

# Worker-safe adaptation of mcl_trees/lg_register.lua's forest probability and
# four-direction leaf-roof placement to Voxey's existing climate/tree plans.
static func decorate_tree(generator: TerrainGenerator, plan: Dictionary) -> void:
	if plan.is_empty() or int(plan.get("species",-1)) not in [0,2]: return
	var origin: Vector3i = plan.origin
	var rng := RandomNumberGenerator.new(); rng.seed = generator.hash_at(origin.x,27607,origin.z)
	if rng.randf() >= 0.002: return
	var face: int = rng.randi_range(0,3)
	var direction: Vector3i = SIDES[face]
	for y in range(1,8):
		var p: Vector3i = direction+Vector3i.UP*y
		if WoodTypes.is_leaves(int(plan.blocks.get(p+Vector3i.UP,Nodes.AIR))):
			plan.blocks[p] = NEST+[2,1,0,3][face]
			return

static func texture(id: int, face: int) -> int:
	if not is_hive(id): return id
	if face in [2,3]: return (7664 if face == 2 else 7665) if is_nest(id) else 7660
	if face == [5,0,4,1][facing(id)]: return (7668 if level(id) == 5 else 7667) if is_nest(id) else (7663 if level(id) == 5 else 7662)
	return 7666 if is_nest(id) else 7661

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_hive(id): return pixel(texture(id,4),x,y,noise)
	if id in [COMB_BLOCK,HONEY_BLOCK]:
		var cell: Vector2i = Vector2i(posmod(x+(3 if y/4%2 else 0),6),posmod(y,4))
		if id == COMB_BLOCK:
			return Color("a96c22") if cell.x in [0,5] or cell.y == 0 else Color("edb342").lightened(0.1 if cell.y == 1 else 0)
		var color: Color = noise.lerp(Color("eaaa30"),0.8)
		if x in [1,14] or y in [1,14]: color = Color("ffd673")
		color.a = 0.76
		return color
	var nest: bool = id >= 7664
	var base := Color("c9a35c") if nest else Color("ba925b")
	var color: Color = noise.lerp(base,0.85)
	if id == 7660:
		if x in [0,15] or y in [0,15]: return Color("725737")
		if y in [4,8,12]: return base.darkened(0.2)
	elif nest:
		if posmod(y+x/5,4) == 0: color = base.darkened(0.24)
		if id == 7665: color = color.darkened(0.2)
	else:
		if y in [0,5,10,15]: color = base.darkened(0.28)
		if x in [1,14]: color = Color("805e38")
	if id in [7662,7663,7667,7668] and y in [8,9] and x in range(4,12): color = Color("48311d")
	if id in [7663,7668] and x in range(3,13) and y >= 9 and y <= 11+posmod(x*7,5): color = Color("efa526").lightened(0.14 if x%3 == 0 else 0)
	return color

static func draw(img: Image, id: int) -> void:
	if id == BOTTLE:
		ItemArt._polygon(img,[[6,1],[10,1],[10,5],[13,8],[13,13],[11,15],[4,15],[2,13],[2,8],[6,5]],Color("b6a577"))
		img.fill_rect(Rect2i(6,1,4,3),Color("a47b44"))
		ItemArt._polygon(img,[[6,6],[9,6],[12,8],[12,13],[10,14],[5,14],[3,12],[3,8]],Color("e9a72d"))
		ItemArt._line(img,Vector2(4,8),Vector2(4,11),Color("ffe7b0"))
		ItemArt._line(img,Vector2(5,13),Vector2(10,13),Color("bd7920"))
	elif id == COMB:
		for origin in [Vector2i(3,3),Vector2i(8,6),Vector2i(3,9)]:
			ItemArt._polygon(img,[[origin.x,origin.y],[origin.x+4,origin.y],[origin.x+6,origin.y+3],[origin.x+4,origin.y+6],[origin.x,origin.y+6],[origin.x-2,origin.y+3]],Color("f1b638"))
			img.fill_rect(Rect2i(origin+Vector2i(1,2),Vector2i(3,2)),Color("b97724"))
