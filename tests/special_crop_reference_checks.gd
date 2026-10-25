extends SceneTree

const NAMES = {
	"mcl_cocoas:cocoa_1":CocoaCrops.STAGE_1,
	"mcl_cocoas:cocoa_2":CocoaCrops.STAGE_2,
	"mcl_cocoas:cocoa_3":CocoaCrops.STAGE_3,
	"mcl_farming:sweet_berry_bush_0":SweetBerryCrops.STAGES[0],
	"mcl_farming:sweet_berry_bush_1":SweetBerryCrops.STAGES[1],
	"mcl_farming:sweet_berry_bush_2":SweetBerryCrops.STAGES[2],
	"mcl_farming:sweet_berry_bush_3":SweetBerryCrops.STAGES[3],
	"mcl_nether:nether_wart_0":NetherWartCrops.STAGES[0],
	"mcl_nether:nether_wart_1":NetherWartCrops.STAGES[1],
	"mcl_nether:nether_wart_2":NetherWartCrops.STAGES[2],
	"mcl_nether:nether_wart":NetherWartCrops.STAGES[3],
}
const P = Vector3i(8,2600,8)
var passed: int = 0
var failed: int = 0

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-special-crop-source-"+str(OS.get_process_id()))
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func particle_count(game: Node3D) -> int:
	return game.get_children().filter(func(child): return child is CPUParticles3D).size()

func drop_total(game: Node3D) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): total += drop.amount
	return total

func held(game: Node3D, id: int, count: int) -> void:
	game.inventory.restore([])
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}
	game.player.target = {"pos":P,"id":game.world.node_at(P),"normal":Vector3i.UP,"distance":1.0}
	game.player.eating = {"probe":true}
	game.player.crouching = false

func setup(game: Node3D, name: String) -> void:
	var world: VoxelWorld = game.world
	world.set_node(P,Nodes.AIR)
	world.set_node(P+Vector3i.BACK,Nodes.AIR)
	world.set_node(P+Vector3i.DOWN,Nodes.AIR)
	if name.begins_with("mcl_cocoas:"): world.set_node(P+Vector3i.BACK,CocoaCrops.JUNGLE_LOG)
	elif name.begins_with("mcl_farming:"): world.set_node(P+Vector3i.DOWN,Nodes.GRASS)
	else: world.set_node(P+Vector3i.DOWN,Nodes.SOUL_SAND)
	world.set_node(P,NAMES[name])
	if name.begins_with("mcl_cocoas:"): CocoaCrops.set_facedir(world,P,0)

func roll_seed(low: int, high: int, wanted: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in 10000:
		rng.seed = candidate
		if rng.randi_range(low,high) == wanted: return candidate
	return 0

func run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/special_crop_reference.json"))
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Special crop source checks","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.daylight = 1.0; game.day_time = 0.3
	for x in range(4,13):
		for z in range(4,13):
			for y in range(P.y-2,P.y+7): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	check(CocoaCrops.INTERVAL == ref.timers["Cocoa pod growth"].interval and CocoaCrops.CHANCE == ref.timers["Cocoa pod growth"].chance,"Source cocoa ABM interval and chance")
	check(NetherWartCrops.INTERVAL == ref.timers["Nether wart growth"].interval and NetherWartCrops.CHANCE == ref.timers["Nether wart growth"].chance,"Source wart ABM interval and chance")
	check(SweetBerryCrops.INTERVAL == ref.timers["Farming plant growth (plant_sweet_berry_bush)"].interval and SweetBerryCrops.CHANCE == ref.timers["Farming plant growth (plant_sweet_berry_bush)"].chance,"Source berry ABM interval and chance")
	for row in ref.bone:
		setup(game,row.name)
		held(game,Nodes.BONE_MEAL,4)
		var particles: int = particle_count(game); var drops: int = drop_total(game)
		var used: bool = game.survival.use()
		var actual: Array = [used,game.world.node_at(P),game.inventory.count_item(Nodes.BONE_MEAL),particle_count(game)-particles,drop_total(game)-drops,game.player.eating.is_empty()]
		check(game.world.node_at(P) == NAMES[row.after] and game.inventory.count_item(Nodes.BONE_MEAL) == int(row.count) and particle_count(game)-particles == int(row.particles) and drop_total(game) == drops and game.player.eating.is_empty() == (int(row.prevented) > 0),"Source bone-meal dispatch: "+str(row)+" actual="+str(actual))
	for row in ref.harvest:
		setup(game,row.name)
		var item: int = SweetBerryCrops.BERRY if not row.has("item") else Nodes.BONE_MEAL
		held(game,item,2)
		SweetBerryCrops.runtime(game.world).rng.seed = roll_seed(1,2,1)
		var drops: int = drop_total(game)
		var handled: bool = SweetBerryCrops.use(game,game.player.target)
		var added: int = 0 if not row.has("added") or row.added == null else row.added.size()
		var actual_harvest: Array = [handled,game.world.node_at(P),game.inventory.held().count,drop_total(game)-drops]
		check(handled == row.handled and game.world.node_at(P) == NAMES[row.after] and game.inventory.held().count == int(row.count) and drop_total(game)-drops == added,"Source berry right-click: "+str(row)+" actual="+str(actual_harvest))
	for row in ref.growth:
		setup(game,row.name)
		if row.has("soil"):
			game.world.set_node(P+Vector3i.DOWN,Nodes.DIRT)
			game.world.blocks[VoxelWorld.block_coord(P)].data[VoxelWorld.local_index(P)] = NAMES[row.name]
		var label: String = row.label
		if label == "Cocoa pod growth":
			CocoaCrops.set_facedir(game.world,P,int(row.param2))
			CocoaCrops.grow(game.world,P)
			check(game.world.node_at(P) == NAMES[row.after] and CocoaCrops.facedir(game.world,P) == int(row.param2),"Source cocoa growth: "+str(row))
		elif label == "Nether wart growth":
			NetherWartCrops.grow(game.world,P)
			check(game.world.node_at(P) == NAMES[row.after],"Source wart growth: "+str(row))
		else:
			SweetBerryCrops.runtime(game.world).rng.seed = roll_seed(0,9,0)
			SweetBerryCrops.grow(game.world,P,1,false,true,SweetBerryCrops.runtime(game.world).rng)
			check(game.world.node_at(P) == NAMES[row.after] and SweetBerryCrops.metadata(game.world,P).is_empty(),"Source berry growth: "+str(row))
	print("SPECIAL CROP SOURCE: %d bone, %d harvest, %d growth; %d passed, %d failed"%[ref.bone.size(),ref.harvest.size(),ref.growth.size(),passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)
