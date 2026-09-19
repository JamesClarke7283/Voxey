class_name FruitCrops
extends RefCounted

# Mineclonia mcl_farming pumpkin.lua, melon.lua and shared_functions.lua.
const PUMPKIN_SEEDS = 7500
const MELON_SEEDS = 7501
const PUMPKIN_STEM = 7510
const MELON_STEM = 7530
const CARVED = 45 # Existing Voxey carved-pumpkin item; keep old inventories.
const JACK = 7560
const DIRECTIONS = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]
const CONNECT_ORDER = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const FACES = [Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT]
const DATA = {
	7500:{"name":"Pumpkin seeds","family":"seed","color":"dfc489"},
	7501:{"name":"Melon seeds","family":"seed","color":"a88459"},
	45:{"name":"Carved pumpkin","block":true,"shape":"pumpkin_head","color":"d9942f","hardness":1.0,"tool":1,"armor":"helmet","armor_points":0,"armor_material":0,"durability":0,"stack":64},
	7510:{"name":"Pumpkin stem (stage 1)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7511:{"name":"Pumpkin stem (stage 2)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7512:{"name":"Pumpkin stem (stage 3)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7513:{"name":"Pumpkin stem (stage 4)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7514:{"name":"Pumpkin stem (stage 5)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7515:{"name":"Pumpkin stem (stage 6)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7516:{"name":"Pumpkin stem (stage 7)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7517:{"name":"Pumpkin stem (stage 8)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7518:{"name":"Pumpkin stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7519:{"name":"Pumpkin stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7520:{"name":"Pumpkin stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7521:{"name":"Pumpkin stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7530:{"name":"Melon stem (stage 1)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7531:{"name":"Melon stem (stage 2)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7532:{"name":"Melon stem (stage 3)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7533:{"name":"Melon stem (stage 4)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7534:{"name":"Melon stem (stage 5)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7535:{"name":"Melon stem (stage 6)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7536:{"name":"Melon stem (stage 7)","block":true,"shape":"plant","color":"619d32","hardness":0.0,"hidden":true},
	7537:{"name":"Melon stem (stage 8)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7538:{"name":"Melon stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7539:{"name":"Melon stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7540:{"name":"Melon stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7541:{"name":"Melon stem (attached)","block":true,"shape":"plant","color":"d2a144","hardness":0.0,"hidden":true},
	7551:{"name":"Carved pumpkin","block":true,"shape":"pumpkin_head","color":"d9942f","hardness":1.0,"tool":1,"hidden":true},
	7552:{"name":"Carved pumpkin","block":true,"shape":"pumpkin_head","color":"d9942f","hardness":1.0,"tool":1,"hidden":true},
	7553:{"name":"Carved pumpkin","block":true,"shape":"pumpkin_head","color":"d9942f","hardness":1.0,"tool":1,"hidden":true},
	7560:{"name":"Jack o'lantern","block":true,"shape":"pumpkin_head","color":"e09b35","hardness":1.0,"tool":1,"hidden":false},
	7561:{"name":"Jack o'lantern","block":true,"shape":"pumpkin_head","color":"e09b35","hardness":1.0,"tool":1,"hidden":true},
	7562:{"name":"Jack o'lantern","block":true,"shape":"pumpkin_head","color":"e09b35","hardness":1.0,"tool":1,"hidden":true},
	7563:{"name":"Jack o'lantern","block":true,"shape":"pumpkin_head","color":"e09b35","hardness":1.0,"tool":1,"hidden":true},
}
const BLOCKS = [45, 7510, 7511, 7512, 7513, 7514, 7515, 7516, 7517, 7518, 7519, 7520, 7521, 7530, 7531, 7532, 7533, 7534, 7535, 7536, 7537, 7538, 7539, 7540, 7541, 7551, 7552, 7553, 7560, 7561, 7562, 7563]

static func is_seed(id: int) -> bool: return id in [PUMPKIN_SEEDS,MELON_SEEDS]
static func is_stem(id: int) -> bool: return id >= PUMPKIN_STEM and id < PUMPKIN_STEM+12 or id >= MELON_STEM and id < MELON_STEM+12
static func melon(id: int) -> bool: return id == MELON_SEEDS or id == Nodes.MELON or id >= MELON_STEM and id < MELON_STEM+12
static func base(id: int) -> int: return MELON_STEM if melon(id) else PUMPKIN_STEM
static func seed_item(id: int) -> int: return MELON_SEEDS if melon(id) else PUMPKIN_SEEDS
static func fruit(id: int) -> int: return Nodes.MELON if melon(id) else Nodes.PUMPKIN
static func stage(id: int) -> int: return mini(8,id-base(id)+1) if is_stem(id) else 0
static func attached(id: int) -> bool: return is_stem(id) and id-base(id) >= 8
static func direction(id: int) -> Vector3i: return DIRECTIONS[id-base(id)-8] if attached(id) else Vector3i.ZERO
static func is_pumpkin_head(id: int) -> bool: return id == CARVED or id >= 7551 and id < 7554 or id >= JACK and id < JACK+4
static func lit(id: int) -> bool: return id >= JACK and id < JACK+4
static func turn(id: int) -> int: return id-JACK if lit(id) else (0 if id == CARVED else id-7550)
static func head_id(light: bool, index: int) -> int: return JACK+posmod(index,4) if light else (CARVED if posmod(index,4) == 0 else 7550+posmod(index,4))
static func canonical(id: int) -> int: return (JACK if lit(id) else CARVED) if is_pumpkin_head(id) else id
static func harvestable(id: int) -> bool: return is_stem(id) or id in [Nodes.PUMPKIN,Nodes.MELON] or is_pumpkin_head(id)
static func random(rng: RandomNumberGenerator, low: int, high: int) -> int: return rng.randi_range(low,high) if rng != null else randi_range(low,high)

static func recipes(inv: Inventory) -> void:
	inv._recipe("Pumpkin seeds",PUMPKIN_SEEDS,4,[Nodes.PUMPKIN],1)
	inv._recipe("Melon seeds",MELON_SEEDS,1,[Nodes.MELON_SLICE],1)
	inv._recipe("Melon",Nodes.MELON,1,[Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE,Nodes.MELON_SLICE],3,"table")
	inv._recipe("Jack o'lantern",JACK,1,[CARVED,Nodes.TORCH],1)

static func harvest(id: int, slot: Dictionary = {}, rng: RandomNumberGenerator = null) -> Array:
	if is_stem(id):
		# Source sequential rarity table, including its intentional approximate
		# seed probabilities. No guaranteed seed or stage-based bonus.
		for row in [[1,6],[2,31],[3,125]]:
			if random(rng,1,row[1]) == 1: return [[seed_item(id),row[0]]]
		return []
	if id == Nodes.MELON:
		if int(slot.get("id",0)) != 0 and Inventory.enchantment(slot,"Silk Touch") > 0: return [[Nodes.MELON,1]]
		var fortune: int = Inventory.enchantment(slot,"Fortune") if int(slot.get("id",0)) != 0 else 0
		if fortune > 0: return [[Nodes.MELON_SLICE,mini(9,random(rng,3,7+fortune))]]
		for row in [[7,14],[6,10],[5,5],[4,2]]:
			if random(rng,1,row[1]) == 1: return [[Nodes.MELON_SLICE,row[0]]]
		return [[Nodes.MELON_SLICE,3]]
	return [[canonical(id),1]] if harvestable(id) else []

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id not in [Nodes.PUMPKIN,Nodes.MELON] and not is_pumpkin_head(id): return false
	var drops: Array = harvest(id)
	if not world.set_node(p,Nodes.AIR): return false
	for entry in drops: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	return true

static func now(world: VoxelWorld) -> float:
	var game: Node = world.get_parent()
	return float(game.day_time)*1200.0 if game != null else 0.0

static func metadata(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	if not world.block_states[key].get("fruit_crop",null) is Dictionary: world.block_states[key].fruit_crop = {}
	return world.block_states[key].fruit_crop

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("fruit_crops"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+75291
		world.set_meta("fruit_crops",{"cells":{},"columns":{},"clocks":[0.0,0.0,0.0],"jobs":[],"pending":{},"serial":0,"rng":rng})
	return world.get_meta("fruit_crops")

static func register_job(world: VoxelWorld, p: Vector3i, kind: String) -> void:
	var state: Dictionary = runtime(world)
	if state.pending.has(p): return
	state.serial += 1
	state.pending[p] = state.serial; state.jobs.append({"pos":p,"kind":kind,"serial":state.serial})

static func registered(world: VoxelWorld, p: Vector3i, on_load: bool = false) -> void:
	var id: int = world.node_at(p)
	if not is_stem(id) or not world.loaded_at(Vector3(p)): return
	var state: Dictionary = runtime(world); var first: bool = not state.cells.has(p)
	state.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true
	if on_load and first and stage(id) < 8: register_job(world,p,"age")

static func remove(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("fruit_crops"): return
	var state: Dictionary = runtime(world); state.cells.erase(p); state.pending.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("fruit_crops"): return
	var state: Dictionary = runtime(world)
	for p in state.columns.get(column,{}).keys(): remove(world,p)
	state.jobs = state.jobs.filter(func(job): return Vector2i(floori(job.pos.x/16.0),floori(job.pos.z/16.0)) != column)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("fruit_crops"): world.remove_meta("fruit_crops")

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	return world.loaded_at(Vector3(p+Vector3i.DOWN)) and Nodes.solid(world.node_at(p+Vector3i.DOWN))

static func refresh(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	var id: int = world.node_at(p)
	if not is_stem(id) or not world.loaded_at(Vector3(p)): return
	if not world.loaded_at(Vector3(p+Vector3i.DOWN)): return
	if not supported(world,p):
		var drops: Array = harvest(id)
		if world.set_node(p,Nodes.AIR):
			for entry in drops: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
		return
	if stage(id) < 8: return
	if attached(id):
		var neighbor: Vector3i = p+direction(id)
		if not world.loaded_at(Vector3(neighbor)) or world.node_at(neighbor) == fruit(id): return
	for offset in CONNECT_ORDER:
		if world.node_at(p+offset) == fruit(id):
			var connected: int = base(id)+8+DIRECTIONS.find(offset)
			if connected != id: world.set_node(p,connected)
			return
	if attached(id): world.set_node(p,base(id)+7)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if is_stem(old_id) and not is_stem(id): remove(world,p)
	if is_stem(id): registered(world,p)
	refresh(world,p); refresh(world,p+Vector3i.UP)
	if id in [Nodes.PUMPKIN,Nodes.MELON] or old_id in [Nodes.PUMPKIN,Nodes.MELON] or is_pumpkin_head(old_id):
		for offset in CONNECT_ORDER: refresh(world,p+offset)

# Source growth speed depends on the hydrated soil node, not a fresh water scan.
static func hydrated(world: VoxelWorld, p: Vector3i) -> bool:
	return Farmland.hydrated(world.node_at(p+Vector3i.DOWN))

static func grow(world: VoxelWorld, p: Vector3i, stages: int = 1, ignore_light: bool = false, low_speed: bool = false, rng: RandomNumberGenerator = null) -> bool:
	var id: int = world.node_at(p)
	if not is_stem(id) or stage(id) >= 8 or not supported(world,p): return false
	var meta: Dictionary = metadata(world,p)
	var light: int = Pasture.light(world,p,14)
	var count: int = int(meta.get("light_count",0)); var total: float = float(meta.get("light_total",0))
	if count > 99: count = 51; total = ceilf(total/2.0)
	else: count += 1
	total += light; meta.light_count = count; meta.light_total = total
	var average: float = ceilf(total/count)
	var current: float = now(world); var last: float = float(meta.get("last_time",0))
	if last < 1: last = current-15.0
	elif is_equal_approx(last,current): current += 150.0
	var intervals: float = maxf(0,current-last)/150.0; meta.last_time = current
	if low_speed:
		if intervals < 1.01 and random(rng,0,9) > 0: return false
		intervals /= 10.0
	if not ignore_light and light < 10 and intervals < 1.5: return false
	if intervals >= 1.5:
		if average < 0.1: return false
		if average < 10: intervals *= average/10.0
	var next: int = mini(8,stage(id)+stages+ceili(intervals))
	if next <= stage(id): return false
	return world.set_node(p,base(id)+next-1)

static func grow_fruit(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	refresh(world,p)
	var id: int = world.node_at(p)
	if not is_stem(id) or stage(id) != 8 or attached(id) or Pasture.light(world,p,11) <= 10: return false
	var choices: Array = []
	for offset in CONNECT_ORDER:
		var at: Vector3i = p+offset
		if world.loaded_at(Vector3(at)) and world.node_at(at) == Nodes.AIR and (Farmland.is_soil(world.node_at(at+Vector3i.DOWN)) or world.node_at(at+Vector3i.DOWN) in [Nodes.DIRT,Nodes.GRASS,VillageContent.SWAMP_GRASS]): choices.append(at)
	if choices.is_empty(): return false
	var at: Vector3i = choices[random(rng,0,choices.size()-1)]
	if not world.set_node(at,fruit(id)): return false
	if Farmland.is_soil(world.node_at(at+Vector3i.DOWN)): world.set_node(at+Vector3i.DOWN,Nodes.DIRT)
	resolve_actors(world,at)
	return true

# Luanti resolves bodies when a fruit appears. Recover Voxey's manually moved
# actors with the same bounded, swept collision correction used by trapdoors.
static func resolve_actors(world: VoxelWorld, p: Vector3i) -> void:
	var game: Node = world.get_parent()
	if game == null or not game.has_method("playing"): return
	var body := AABB(Vector3(p),Vector3.ONE)
	var riding: bool = game.boats != null and is_instance_valid(game.boats.riding)
	var mounted: bool = game.survival != null and is_instance_valid(game.survival.mount)
	if is_instance_valid(game.player) and not riding and not mounted: Trapdoors.resolve_actor(world,p,body,game.player,0.29,1.8)
	if is_instance_valid(game.creatures):
		for actor in game.creatures.get_children():
			if not actor is Creature or actor.is_queued_for_deletion() or Boats.is_passenger(actor): continue
			if Trapdoors.resolve_actor(world,p,body,actor,actor.width,actor.height) and mounted and actor == game.survival.mount: game.player.position = actor.position+Vector3.UP*1.1
	if game.boats != null:
		for boat in game.boats.active.values():
			if not is_instance_valid(boat) or boat.removed or boat.is_queued_for_deletion(): continue
			if Trapdoors.resolve_actor(world,p,body,boat,0.5,0.55): boat.seat_occupants(); boat.store_record()

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("fruit_crops"): return
	var state: Dictionary = runtime(world); var rng: RandomNumberGenerator = state.rng
	for index in 3:
		var interval: float = 25.0 if index == 2 else 30.0
		state.clocks[index] += maxf(0,delta)
		if state.clocks[index] < interval: continue
		state.clocks[index] = fmod(state.clocks[index],interval)
		for p in state.cells:
			var id: int = int(state.cells[p])
			if index == 0 and stage(id) < 8 and random(rng,1,5) == 1: register_job(world,p,"age")
			elif index == (2 if melon(id) else 1) and stage(id) == 8 and not attached(id) and random(rng,1,15) == 1: register_job(world,p,"fruit")
	for i in mini(8,state.jobs.size()):
		var job: Dictionary = state.jobs.pop_front()
		if state.pending.get(job.pos,-1) != job.serial: continue
		state.pending.erase(job.pos)
		if not state.cells.has(job.pos) or not world.loaded_at(Vector3(job.pos)): continue
		if job.kind == "fruit": grow_fruit(world,job.pos,rng)
		else: grow(world,job.pos,1,false,not hydrated(world,job.pos),rng)

static func use(game: Node3D, target: Dictionary) -> bool:
	var held: int = int(game.inventory.held().id)
	if target.is_empty(): return false
	var p: Vector3i = target.pos; var id: int = game.world.node_at(p)
	if held == Nodes.SHEARS and id == Nodes.PUMPKIN:
		if target.normal.y != 0: return true
		if game.world.set_node(p,head_id(false,FACES.find(target.normal))):
			game.spawn_drop(Vector3(p)+Vector3.ONE*0.5+Vector3(target.normal)*0.7,PUMPKIN_SEEDS,4)
			if game.gamemode != "creative": game.inventory.damage_tool()
			game.sound("dig"); game.player.swing = 1
		return true
	if held == Nodes.BONE_MEAL and is_stem(id):
		if grow(game.world,p,randi_range(2,5),true):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8); game.player.swing = 1
		return true
	if is_seed(held):
		var placement: Dictionary = SnowCover.placement(game.world,target)
		var at: Vector3i = placement.pos
		if game.world.node_at(at) == Nodes.AIR and Farmland.is_soil(game.world.node_at(at+Vector3i.DOWN)) and game.world.set_node(at,base(held)):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place"); game.player.swing = 1
		return true
	if is_pumpkin_head(held):
		var at: Vector3i = SnowCover.placement(game.world,target).pos
		if not SnowCover.replaceable(game.world.node_at(at)): return true
		var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
		if body.intersects(AABB(Vector3(at),Vector3.ONE)): return true
		var look: Vector3 = -game.player.camera.global_basis.z
		var face: Vector3i = Vector3i.LEFT if look.x > 0 else Vector3i.RIGHT
		if absf(look.z) >= absf(look.x): face = Vector3i.FORWARD if look.z > 0 else Vector3i.BACK
		if game.world.set_node(at,head_id(lit(held),FACES.find(face))):
			if game.gamemode != "creative": game.inventory.consume_selected()
			Golems.placed(game,at,game.player_id)
			game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,canonical(held))
		return true
	return false

static func boxes(id: int) -> Array:
	if not is_stem(id): return [AABB(Vector3.ZERO,Vector3.ONE)]
	if not attached(id): return [AABB(Vector3(0.35,0,0.35),Vector3(0.3,stage(id)/8.0,0.3))]
	var d: Vector3i = direction(id)
	return [AABB(Vector3(0.4 if d.x >= 0 else 0,0,0.4 if d.z >= 0 else 0),Vector3(0.6 if d.x != 0 else 0.2,0.7,0.6 if d.z != 0 else 0.2))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	if is_stem(id):
		var height: float = stage(id)/8.0
		if attached(id):
			BlockMesher._art_box(out,at+Vector3(0.5,0.25,0.5),Vector3(0.065,0.5,0.065),tile,tile)
			var d: Vector3 = Vector3(direction(id))
			BlockMesher._art_box(out,at+Vector3(0.5,0.50,0.5)+d*0.22,Vector3(0.50 if d.x != 0 else 0.065,0.06,0.50 if d.z != 0 else 0.065),tile,tile)
		else:
			BlockMesher._art_box(out,at+Vector3(0.5,height*0.5,0.5),Vector3(0.055,height,0.055),tile,tile)
			for side in [-1,1]: BlockMesher._art_box(out,at+Vector3(0.5+side*0.085,height*0.62,0.5),Vector3(0.15,0.05,0.07),tile,tile)
		return
	if not is_pumpkin_head(id): return
	# Original carved face built with inset dark/glowing geometric apertures.
	BlockMesher._art_box(out,at+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(Nodes.PUMPKIN,0),Nodes.tile(Nodes.PUMPKIN,2))
	var face: Vector3 = Vector3(FACES[turn(id)]); var across := Vector3(-face.z,0,face.x)
	var eye_tile: int = Nodes.tile(Nodes.GLOWSTONE if lit(id) else VillageContent.WOOL_BLACK,0)
	for side in [-1,1]:
		BlockMesher._art_box(out,at+Vector3(0.5,0.65,0.5)+face*0.502+across*side*0.19,Vector3(0.18,0.16,0.008) if face.z != 0 else Vector3(0.008,0.16,0.18),eye_tile,eye_tile)
	BlockMesher._art_box(out,at+Vector3(0.5,0.31,0.5)+face*0.503,Vector3(0.55,0.13,0.008) if face.z != 0 else Vector3(0.008,0.13,0.55),eye_tile,eye_tile)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_stem(id): return Color("2e9d2e").lerp(Color("ffa800"),float(stage(id)-1)/7.0).lightened(0.06 if x%3 == 0 else 0)
	return noise.darkened(0.12) if x%4 == 0 else noise

static func draw(img: Image, id: int) -> void:
	var color := Color("c8b884") if id == PUMPKIN_SEEDS else Color("776045")
	for point in [Vector2i(4,5),Vector2i(10,4),Vector2i(7,10),Vector2i(12,11)]:
		img.fill_rect(Rect2i(point,Vector2i(2,4)),color)
		img.set_pixelv(point+Vector2i(0,1),color.lightened(0.3))
