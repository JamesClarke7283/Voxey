class_name CropFarming
extends RefCounted

# Local Mineclonia mcl_farming/{wheat,carrots,potatoes,beetroot,shared_functions}.lua.
# Existing node IDs retain their old visual growth stage and mature identity.
const POISONOUS_POTATO = 8070
const STAGES = [
	[22,8010,8011,8012,8013,8014,8015,29],
	[551,8020,552,8021,553,8022,8023,554],
	[555,8030,556,8031,557,8032,8033,558],
	[559,560,561,562],
]
const SEEDS = [Nodes.SEEDS,VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT_SEEDS]
const INTERVALS = [25.0,25.0,19.75,68.0]
const CHANCES = [20,20,20,3]
const NAMES = ["Wheat","Carrot","Potato","Beetroot"]
const DATA = {
	22:{"name":"Wheat plant (stage 1)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":1},
	8010:{"name":"Wheat plant (stage 2)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":2},
	8011:{"name":"Wheat plant (stage 3)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":3},
	8012:{"name":"Wheat plant (stage 4)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":4},
	8013:{"name":"Wheat plant (stage 5)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":5},
	8014:{"name":"Wheat plant (stage 6)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":6},
	8015:{"name":"Wheat plant (stage 7)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":7},
	29:{"name":"Wheat plant (stage 8)","color":"d1b94f","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"wheat","stage":8},
	551:{"name":"Carrot plant (stage 1)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":1},
	8020:{"name":"Carrot plant (stage 2)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":2},
	552:{"name":"Carrot plant (stage 3)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":3},
	8021:{"name":"Carrot plant (stage 4)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":4},
	553:{"name":"Carrot plant (stage 5)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":5},
	8022:{"name":"Carrot plant (stage 6)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":6},
	8023:{"name":"Carrot plant (stage 7)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":7},
	554:{"name":"Carrot plant (stage 8)","color":"ed9449","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"carrot","stage":8},
	555:{"name":"Potato plant (stage 1)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":1},
	8030:{"name":"Potato plant (stage 2)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":2},
	556:{"name":"Potato plant (stage 3)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":3},
	8031:{"name":"Potato plant (stage 4)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":4},
	557:{"name":"Potato plant (stage 5)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":5},
	8032:{"name":"Potato plant (stage 6)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":6},
	8033:{"name":"Potato plant (stage 7)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":7},
	558:{"name":"Potato plant (stage 8)","color":"b99860","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"potato","stage":8},
	559:{"name":"Beetroot plant (stage 1)","color":"a5445a","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"beetroot","stage":1},
	560:{"name":"Beetroot plant (stage 2)","color":"a5445a","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"beetroot","stage":2},
	561:{"name":"Beetroot plant (stage 3)","color":"a5445a","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"beetroot","stage":3},
	562:{"name":"Beetroot plant (stage 4)","color":"a5445a","block":true,"shape":"crop","hidden":true,"tool":-1,"hardness":0.0,"crop":"beetroot","stage":4},
	8070:{"name":"Poisonous potato","color":"a39754","food":2,"stack":64},
}
const INFO = {
	22:[0,1],
	8010:[0,2],
	8011:[0,3],
	8012:[0,4],
	8013:[0,5],
	8014:[0,6],
	8015:[0,7],
	29:[0,8],
	551:[1,1],
	8020:[1,2],
	552:[1,3],
	8021:[1,4],
	553:[1,5],
	8022:[1,6],
	8023:[1,7],
	554:[1,8],
	555:[2,1],
	8030:[2,2],
	556:[2,3],
	8031:[2,4],
	557:[2,5],
	8032:[2,6],
	8033:[2,7],
	558:[2,8],
	559:[3,1],
	560:[3,2],
	561:[3,3],
	562:[3,4],
}
const BLOCKS = [22, 8010, 8011, 8012, 8013, 8014, 8015, 29, 551, 8020, 552, 8021, 553, 8022, 8023, 554, 555, 8030, 556, 8031, 557, 8032, 8033, 558, 559, 560, 561, 562]

static func is_crop(id: int) -> bool: return INFO.has(id)
static func family(id: int) -> int: return int(INFO[id][0]) if is_crop(id) else SEEDS.find(id)
static func stage(id: int) -> int: return int(INFO[id][1]) if is_crop(id) else 0
static func mature(id: int) -> bool: return is_crop(id) and stage(id) == STAGES[family(id)].size()
static func seed_item(id: int) -> int: return SEEDS[family(id)] if family(id) >= 0 else 0
static func first(id: int) -> int: return STAGES[family(id)][0] if family(id) >= 0 else 0
static func is_seed(id: int) -> bool: return id in SEEDS
static func unsticky(id: int) -> bool: return is_crop(id) and family(id) == 0
static func random(rng: RandomNumberGenerator, low: int, high: int) -> int: return rng.randi_range(low,high) if rng != null else randi_range(low,high)

static func harvest(id: int, slot: Dictionary = {}, rng: RandomNumberGenerator = null) -> Array:
	if not is_crop(id): return []
	if not mature(id): return [[seed_item(id),1]]
	var f: int = family(id)
	var fortune: int = Inventory.enchantment(slot,"Fortune") if int(slot.get("id",0)) != 0 and int(slot.get("id",0)) != VillageContent.ENCHANTED_BOOK else 0
	if fortune > 0:
		var bounds: Array = [[1,6,7],[2,4,5],[2,4,5],[1,3,5]][f]
		var amount: int = mini(bounds[2],random(rng,bounds[0],bounds[1]+fortune))
		var drops: Array = [[seed_item(id),amount]]
		if f in [0,3]: drops.append([Nodes.GRAIN if f == 0 else VillageContent.BEETROOT,1])
		return drops
	match f:
		0:
			var amount: int = 1+(1 if random(rng,1,2) == 1 else 0)+(1 if random(rng,1,5) == 1 else 0)
			return [[Nodes.SEEDS,amount],[Nodes.GRAIN,1]]
		1:
			for row in [[4,5],[3,2],[2,2]]:
				if random(rng,1,row[1]) == 1: return [[VillageContent.CARROT,row[0]]]
			return [[VillageContent.CARROT,1]]
		2:
			var amount: int = 1
			for i in 3:
				if random(rng,1,2) == 1: amount += 1
			var drops: Array = [[VillageContent.POTATO,amount]]
			if random(rng,1,50) == 1: drops.append([POISONOUS_POTATO,1])
			return drops
		3:
			var amount: int = 1
			for row in [[4,6],[3,4],[2,3]]:
				if random(rng,1,row[1]) == 1: amount = row[0]; break
			return [[VillageContent.BEETROOT,1],[VillageContent.BEETROOT_SEEDS,amount]]
	return []

static func environmental_break(world: VoxelWorld, p: Vector3i, lava: bool = false) -> bool:
	var id: int = world.node_at(p)
	if not is_crop(id): return false
	var drops: Array = [] if lava else harvest(id)
	if not world.set_node(p,Nodes.AIR): return false
	for entry in drops: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	return true

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	return environmental_break(world,p)

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("crop_farming"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+803109
		world.set_meta("crop_farming",{"cells":{},"columns":{},"clocks":[0.0,0.0,0.0,0.0],"jobs":[],"pending":{},"serial":0,"rng":rng})
	return world.get_meta("crop_farming")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("crop_farming"): world.remove_meta("crop_farming")

static func queue_growth(world: VoxelWorld, p: Vector3i) -> void:
	var state: Dictionary = runtime(world)
	if state.pending.has(p): return
	state.serial += 1; state.pending[p] = state.serial
	state.jobs.append({"pos":p,"serial":state.serial})

static func registered(world: VoxelWorld, p: Vector3i, on_load: bool = false) -> void:
	var id: int = world.node_at(p)
	if not is_crop(id) or not world.loaded_at(Vector3(p)): return
	var state: Dictionary = runtime(world); var first_load: bool = not state.cells.has(p)
	state.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true
	if on_load and first_load and not mature(id): queue_growth(world,p)

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("crop_farming"): return
	var state: Dictionary = runtime(world); state.cells.erase(p); state.pending.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("crop_farming"): return
	var state: Dictionary = runtime(world)
	for p in state.columns.get(column,{}).keys(): forget(world,p)
	state.jobs = state.jobs.filter(func(job): return Vector2i(floori(job.pos.x/16.0),floori(job.pos.z/16.0)) != column)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("crop_farming"): return
	# Snapshot keys: unsupported crops remove themselves from these indices.
	# A column includes every Y level, so the support below a crop loads with it.
	for p in runtime(world).columns.get(column,{}).keys(): refresh(world,p)

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	return world.loaded_at(Vector3(p+Vector3i.DOWN)) and Nodes.solid(world.node_at(p+Vector3i.DOWN))

static func refresh(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	if is_crop(world.node_at(p)) and world.loaded_at(Vector3(p+Vector3i.DOWN)) and not supported(world,p): environmental_break(world,p)

static func changed(world: VoxelWorld, p: Vector3i, old: int, id: int) -> void:
	if is_crop(old) and not is_crop(id): forget(world,p)
	if is_crop(id): registered(world,p)
	refresh(world,p); refresh(world,p+Vector3i.UP)

static func metadata(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	if not world.block_states[key].get("crop_farming",null) is Dictionary: world.block_states[key].crop_farming = {}
	return world.block_states[key].crop_farming

static func now(world: VoxelWorld) -> float: return float(world.get_parent().day_time)*1200.0

static func grow(world: VoxelWorld, p: Vector3i, stages: int = 1, ignore_light: bool = false, low_speed: bool = false, rng: RandomNumberGenerator = null) -> bool:
	var id: int = world.node_at(p)
	if not is_crop(id) or mature(id) or not supported(world,p): return false
	var f: int = family(id); var meta: Dictionary = metadata(world,p)
	var light: int = Pasture.light(world,p,14)
	var count: int = int(meta.get("light_count",0)); var total: float = float(meta.get("light_total",0))
	if count > 99: count = 51; total = ceilf(total/2.0)
	else: count += 1
	total += light; meta.light_count = count; meta.light_total = total
	var mean: float = ceilf(total/count)
	var period: float = INTERVALS[f]*CHANCES[f]
	var current: float = now(world); var last: float = float(meta.get("last_time",0))
	if last < 1: last = current-period/10.0
	elif is_equal_approx(last,current): current += period
	var intervals: float = maxf(0,current-last)/period; meta.last_time = current
	if low_speed:
		if intervals < 1.01 and random(rng,0,9) > 0: return false
		intervals /= 10.0
	if not ignore_light and light < 10 and intervals < 1.5: return false
	if intervals >= 1.5:
		if mean < 0.1: return false
		if mean < 10: intervals *= mean/10.0
	var next: int = mini(STAGES[f].size(),stage(id)+stages+ceili(intervals))
	return next > stage(id) and world.set_node(p,STAGES[f][next-1])

static func bone_meal(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> Dictionary:
	var id: int = world.node_at(p)
	if not is_crop(id): return {"consume":false,"grew":false}
	# Source beetroot returns nil on its 25% no-growth roll. mcl_bone_meal
	# consumes whenever the callback returns anything other than false.
	if family(id) == 3 and random(rng,1,100) > 75: return {"consume":true,"grew":false}
	var grew: bool = grow(world,p,1 if family(id) == 3 else random(rng,2,5),true,false,rng)
	return {"consume":grew,"grew":grew}

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("crop_farming"): return
	var state: Dictionary = runtime(world); var rng: RandomNumberGenerator = state.rng
	for f in 4:
		state.clocks[f] += maxf(0,delta)
		if state.clocks[f] < INTERVALS[f]: continue
		state.clocks[f] = fmod(state.clocks[f],INTERVALS[f])
		for p in state.cells:
			var id: int = int(state.cells[p])
			if family(id) == f and not mature(id) and random(rng,1,CHANCES[f]) == 1: queue_growth(world,p)
	for i in mini(8,state.jobs.size()):
		var job: Dictionary = state.jobs.pop_front()
		if state.pending.get(job.pos,-1) != job.serial: continue
		state.pending.erase(job.pos)
		if not state.cells.has(job.pos) or not world.loaded_at(Vector3(job.pos)): continue
		grow(world,job.pos,1,false,not Farmland.hydrated(world.node_at(job.pos+Vector3i.DOWN)),rng)

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var held: int = int(game.inventory.held().id); var p: Vector3i = target.pos; var id: int = game.world.node_at(p)
	if held == Nodes.BONE_MEAL and is_crop(id):
		var result: Dictionary = bone_meal(game.world,p)
		if result.consume:
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8); game.sound("place"); game.player.swing = 1
		return true
	if not is_seed(held): return false
	var at: Vector3i = SnowCover.placement(game.world,target).pos
	if game.world.node_at(at) != Nodes.AIR or not Farmland.is_soil(game.world.node_at(at+Vector3i.DOWN)): return false
	if game.world.set_node(at,first(held)):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.player.eating.clear(); game.sound("place"); game.player.swing = 1
		game.api.emit_node_placed(at,first(held))
	return true

static func on_eat(player: VoxeyPlayer, id: int, roll: float = -1.0) -> void:
	if id == POISONOUS_POTATO and (randf() if roll < 0 else roll) <= 0.6: PotionEffects.apply(player,"poison",5,1)

static func recipes(inv: Inventory) -> void:
	inv._recipe("Beetroot soup",VillageContent.BEETROOT_SOUP,1,[VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,VillageContent.BEETROOT,0,Nodes.BOWL,0],3,"table")
	inv._recipe("Red dye from beetroot",VillageContent.DYE_RED,1,[VillageContent.BEETROOT],1)

static func boxes(id: int) -> Array:
	if not is_crop(id): return []
	var f: int = family(id); var s: int = stage(id); var width: float = 14.0/16.0; var h: float
	match f:
		0:
			h = float([5,8,10,12,13,14,15,16][s-1])/16.0
			if s == 8: width = 1.0 # Mature wheat has the source default selection cube.
		1: h = float(2 if s < 3 else (4 if s < 5 else (6 if s < 8 else 8)))/16.0
		2:
			h = float(3 if s < 3 else (4 if s < 5 else (6 if s < 8 else 8)))/16.0
			width = (10.0 if s < 3 else 12.0)/16.0
		3: h = float([2,5,6,8][s-1])/16.0; width = float([10,12,14,16][s-1])/16.0
	return [AABB(Vector3((1-width)/2,0,(1-width)/2),Vector3(width,h,width))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	if not is_crop(id): return
	var h: float = boxes(id)[0].size.y; var f: int = family(id); var tile: int = Nodes.tile(id,0)
	for offset in [Vector3(0.25,0,0.25),Vector3(0.75,0,0.25),Vector3(0.25,0,0.75),Vector3(0.75,0,0.75)]:
		BlockMesher._art_box(out,at+offset+Vector3.UP*h*0.5,Vector3(0.04,h,0.04),tile,tile)
		if f == 0:
			if stage(id) >= 4:
				for y in 3: BlockMesher._art_box(out,at+offset+Vector3(0.025 if y%2 else -0.025,h*(0.64+y*0.11),0),Vector3(0.10,0.07,0.07),tile,tile)
		else:
			for turn in 2: BlockMesher._art_box(out,at+offset+Vector3.UP*h*0.65,Vector3(0.29,0.035,0.08) if turn == 0 else Vector3(0.08,0.035,0.29),tile,tile)
			if mature(id): BlockMesher._art_box(out,at+offset+Vector3.UP*0.04,Vector3(0.13,0.08,0.13),Nodes.tile(Nodes.PUMPKIN if f == 1 else (Nodes.DIRT if f == 2 else VillageContent.WOOL_RED),0),tile)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_crop(id): return Color("829348") if (x+y*3)%7 < 2 else noise
	var color := Color("509b30")
	if family(id) == 0: color = color.lerp(Color("d8bb4d"),clampf(float(stage(id)-2)/6.0,0,1))
	return color.lightened(0.08) if (x+y)%4 == 0 else color

static func draw(img: Image, id: int) -> void:
	if id != POISONOUS_POTATO: return
	ItemArt._polygon(img,[[4,3],[10,2],[14,6],[13,11],[8,14],[3,11],[2,7]],Color("aa9153"))
	for at in [Vector2i(4,5),Vector2i(9,4),Vector2i(10,9),Vector2i(5,10)]: img.fill_rect(Rect2i(at,Vector2i(2,2)),Color("71873d"))
