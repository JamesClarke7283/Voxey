extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game.gamemode = "survival"
	var home: Vector3 = game.player.position
	var loot: Array = Archaeology.table_for(Archaeology.SUSPICIOUS_SAND,"desert_well")
	t.check(loot.size() == 6 and Archaeology.total_weight(Archaeology.SUSPICIOUS_SAND,"desert_well") == 8,"well loot keeps the source's six entries and total weight eight")
	t.check(loot.filter(func(e):return e.id in [9915,9916] and e.weight == 2).size() == 2,"Arms Up and Brewer each retain source weight two")
	t.check(Archaeology.UNROUTED_SHERDS.is_empty() and Archaeology.SHERDS.all(func(id):return Archaeology.routed(id)),"all twenty-three pottery sherds now have source acquisition routes")
	var rng := RandomNumberGenerator.new(); rng.seed = 41731
	var seen: Dictionary = {}
	for i in 512:
		var drop: Array = Archaeology.loot(Archaeology.SUSPICIOUS_SAND,rng,"desert_well")
		seen[drop[0][0]] = true
	t.check(seen.size() == 6 and seen.has(VillageContent.SUSPICIOUS_STEW),"well draws can reach every source item including plain suspicious stew")
	var world: VoxelWorld = game.world
	var at: Vector3i = DesertWells.nearest(world.generator,home)
	t.check(at != Vector3i.ZERO,"the generated desert-well feature is discoverable")
	if at == Vector3i.ZERO: return
	var column := Vector2i(at.x >> 4,at.z >> 4)
	var well: Dictionary = DesertWells.generated(world.generator,column)
	for x in range(-1,2):
		for z in range(-1,2): world._apply_column(world.generator.generate_column(column+Vector2i(x,z),world.edits))
	var installed: bool = true
	for p in well.states:
		installed = installed and world.node_at(p) == Archaeology.SUSPICIOUS_SAND and world.block_states.get(VoxelWorld.station_key(p),{}).get("structure") == "desert_well"
	t.check(installed and well.states.size() == 2,"natural generation installs both buried sand blocks with well loot metadata")
	t.check(world.node_at(at) == Nodes.WATER and world.node_at(at+Vector3i(0,4,0)) == Nodes.SANDSTONE,"natural generation builds the pool and sandstone roof")
	var points: Array = well.states.keys(); var p: Vector3i = points[0]
	var key: String = VoxelWorld.station_key(p)
	var original_metadata: Dictionary = world.block_states[key].duplicate(true)
	world.block_states[key]["preserve_marker"] = 71
	DesertWells.install(world,{"coord":Vector2i(p.x >> 4,p.z >> 4),"wells":{"states":{p:well.states[p]}}})
	t.check(world.block_states[key].get("preserve_marker") == 71,"well installation never overwrites saved metadata")
	world.block_states.erase(key)
	DesertWells.install(world,{"coord":Vector2i(p.x >> 4,p.z >> 4),"wells":{"states":{p:well.states[p]}},"temples":{"suspicious":{p:"desert_temple"}}})
	t.check(not world.block_states.has(key),"later temple archaeology takes precedence over a well at the same cell")
	world.block_states[key] = original_metadata
	game.player.position = Vector3(at)+Vector3(3.5,2,3.5)
	# Expose both strata using the same ordinary block-break path as excavation.
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.TOOLS+2,"count":1,"wear":0}; game.inventory.selected = 0
	for sand in points:
		var above: Vector3i = sand+Vector3i.UP
		if world.node_at(above) == Nodes.SAND: game.break_node(above,Nodes.SAND,Nodes.TOOLS+2)
	var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,4,0.5),Vector3.DOWN,5)
	t.check(hit.get("pos",Vector3i.ZERO) == p,"the exposed well sand is reachable through normal block targeting")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Archaeology.BRUSH,"count":1,"wear":0}; game.inventory.selected = 0
	t.check(Archaeology.brush(game,{"pos":p,"id":Archaeology.SUSPICIOUS_SAND,"normal":Vector3i.UP}),"the brush starts a real well excavation")
	var reward: int = Archaeology.progress(world,p).loot_id
	var seed_value: int = world.block_states[key].archaeology_seed
	t.check(seen.has(reward),"the well uses its own source loot pool rather than a temple pool")
	t.check(game.save_game("user://desert_well.json"),"active well excavation saves to disk")
	game.set_process(true); game.load_world_data(game.read_save("user://desert_well.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world
	game.pause(); game.set_process(false); world.set_process(false); world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(world.block_states.get(key,{}).get("archaeology_seed") == seed_value and Archaeology.progress(world,p).get("loot_id") == reward,"reload retains the same well reward and seed")
	game.inventory.restore([]); game.inventory.slots[0] = {"id":Archaeology.BRUSH,"count":1,"wear":0}; game.inventory.selected = 0
	var before: int = count_drops(game,reward)
	for i in 256:
		Archaeology.brush(game,{"pos":p,"id":Archaeology.SUSPICIOUS_SAND,"normal":Vector3i.UP})
		if world.node_at(p) != Archaeology.SUSPICIOUS_SAND: break
	t.check(world.node_at(p) == Nodes.SAND and count_drops(game,reward) == before+1,"finishing well archaeology produces exactly one saved reward and plain sand")
	world._apply_column(world.generator.generate_column(Vector2i(p.x >> 4,p.z >> 4),world.edits))
	t.check(world.node_at(p) == Nodes.SAND,"regenerating the column cannot recreate excavated well loot")
	# A source-created stew carries no effect metadata. Eating still returns its
	# bowl and nutrition, including the ability to consume it when already full.
	PotionEffects.clear(game.player)
	game.inventory.restore([]); game.inventory.slots[0] = {"id":VillageContent.SUSPICIOUS_STEW,"count":1,"wear":0}; game.inventory.selected = 0
	game.player.hunger = 10; game.player.saturation = 0; game.state = "playing"
	Eating.start(game.player); Eating.update(game.player,2.0,true)
	t.check(game.inventory.count_item(Nodes.BOWL) == 1 and game.player.hunger == 16 and is_equal_approx(game.player.saturation,7.2),"plain well stew restores source nutrition and returns its bowl")
	game.player.hunger = 20
	t.check(game.survival.effects.is_empty() and Hunger.can_eat(game.player,VillageContent.SUSPICIOUS_STEW),"plain well stew invents no flower effect and is edible at full hunger")
	game.pause(); game.set_process(false)
	game.player.position = home; world.target = home; world.set_process(true)
	deadline = Time.get_ticks_msec()+90000
	while not world.area_ready(home) and Time.get_ticks_msec() < deadline: await t.process_frame
	world.set_process(false)
	t.check(world.area_ready(home),"return from the well restores the original loaded test area")
	for path in ["user://desert_well.json","user://desert_well.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

static func count_drops(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count
