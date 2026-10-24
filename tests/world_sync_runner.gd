extends SceneTree

const ORIGIN = Vector3i(8,100,8)
const HOST_BLOCK = ORIGIN+Vector3i(0,1,0)
const GUEST_BLOCK = ORIGIN+Vector3i(2,1,0)
const JOIN_BLOCK = ORIGIN+Vector3i(4,1,0)
const FAR_BLOCK = ORIGIN+Vector3i(160,1,0)
const FAR_MACHINE = FAR_BLOCK+Vector3i(2,0,0)
const ENTITY_START = Vector3(FAR_BLOCK)+Vector3(4.0,1.0,0.5)
const REJECTED_BLOCK = ORIGIN+Vector3i(22,1,0)
var game: Node3D
var mode: String = "host"
var port: int = 24684
var connect_port: int = 0
var failures: int = 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): mode = arg.get_slice("=",1)
		if arg.begins_with("--port="): port = int(arg.get_slice("=",1))
		if arg.begins_with("--connect-port="): connect_port = int(arg.get_slice("=",1))
	if connect_port == 0: connect_port = port
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-world-sync-"+mode+"-"+str(OS.get_process_id()))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: print("PASS  "+mode+": "+message)
	else: failures += 1; push_error("FAIL  "+mode+": "+message)

func path(marker: String) -> String:
	return "/tmp/voxey-world-sync-"+str(port)+"-"+marker

func mark(marker: String) -> void:
	var file := FileAccess.open(path(marker),FileAccess.WRITE)
	file.store_string("ready")

func wait_until(predicate: Callable, seconds: int = 20) -> bool:
	var deadline: int = Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec() < deadline: await process_frame
	return predicate.call()

func wait_mark(marker: String) -> bool:
	return await wait_until(func(): return FileAccess.file_exists(path(marker)),60)

# Inspect rendered terrain, not just its collision/voxel data. The isolated test
# cubes each own their top quad, including after chunk regeneration.
func has_top(p: Vector3i) -> bool:
	var coord: Vector3i = VoxelWorld.block_coord(p)
	if not game.world.blocks.has(coord): return false
	var local: Vector3 = Vector3(p-coord*16)
	for instance in game.world.blocks[coord].meshes:
		for surface in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in vertices.size():
				if normals[i].y > 0.9 and absf(vertices[i].y-local.y-1) < 0.01 and absf(vertices[i].x-local.x) < 0.01 and absf(vertices[i].z-local.z) < 0.01: return true
	return false

func block_is(p: Vector3i, id: int) -> bool:
	return game.world.node_at(p) == id and has_top(p) == (id != Nodes.AIR)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.network.appearance = CharacterSkin.clean({"name":mode})
	game.player.set_process(false); game.player.set_physics_process(false)
	if mode == "host": await run_host()
	else: await run_client()
	print("WORLD SYNC ",mode," TESTS: ",failures," failed")
	game.network.stop(); game.queue_free()
	for i in 4: await process_frame
	quit(1 if failures else 0)

func run_host() -> void:
	game.start_new("8675309","World sync","creative")
	check(await wait_until(func(): return game.state == "playing",90),"world loads")
	game.player.position = Vector3(ORIGIN)+Vector3(0.5,2,0.5)
	game.pause()
	for p in [HOST_BLOCK,GUEST_BLOCK,JOIN_BLOCK]: game.world.set_node(p,Nodes.STONE)
	game.world.record_edit(FAR_BLOCK,Nodes.STONE)
	check(game.network.host(port) == OK,"server starts")
	print("WORLD SYNC HOST READY")
	check(await wait_until(func(): return game.network.players.size() == 3,90),"both guests join")
	game.break_node(JOIN_BLOCK,Nodes.STONE,0)
	check(await wait_mark("guest-ready") and await wait_mark("observer-ready"),"both guests finish loading")
	game.break_node(HOST_BLOCK,Nodes.STONE,0)
	mark("host-mined")
	check(await wait_mark("guest-host-mined") and await wait_mark("observer-host-mined"),"both peers observe host mining")
	mark("guest-mine")
	check(await wait_mark("guest-mined"),"guest completes mining")
	check(await wait_until(func(): return block_is(GUEST_BLOCK,Nodes.AIR)),"guest mining updates host data and mesh")
	mark("check-guest-mine")
	check(await wait_mark("observer-guest-mined"),"other guest observes guest mining")
	mark("reject-placement")
	check(await wait_mark("guest-rejected"),"rejected placement is reconciled")
	mark("travel")
	check(await wait_mark("guest-far-ready"),"guest streams distant terrain")
	check(await wait_until(func(): return game.world.loaded_at(Vector3(FAR_BLOCK))),"host loads terrain around distant guest")
	# Hold generation to reproduce an action arriving before the host has the
	# guest's column. It must wait for terrain, never turn into a bedrock edit.
	game.world.set_process(false)
	game.world._unload(Vector2i(FAR_BLOCK.x >> 4,FAR_BLOCK.z >> 4))
	game.world.desired = Vector2i(999999,999999)
	mark("far-mine")
	check(await wait_until(func(): return not game.network.pending_actions.is_empty(),5),"mining waits for a streaming host column")
	game.world.set_process(true)
	check(await wait_mark("guest-far-mined"),"distant guest completes mining")
	check(await wait_until(func(): return game.world.edits.get(FAR_BLOCK,-1) == Nodes.AIR),"distant guest mining updates host")
	check(await wait_until(func(): return game.world.node_at(FAR_MACHINE) == SteamMachines.BELLOWS and game.world.circuits.direction(FAR_MACHINE) == Vector3i.UP),"machine placement retains its orientation while host terrain loads")
	mark("observer-travel")
	check(await wait_mark("observer-far-mined"),"unloaded edits survive observer travel")
	var mob: Creature = game.spawn_creature("pig",ENTITY_START)
	mob.set_physics_process(false)
	mark("entity-spawn")
	check(await wait_mark("guest-entity-spawn") and await wait_mark("observer-entity-spawn"),"both guests receive a new creature")
	mob.position += Vector3.RIGHT*2.0
	mark("entity-move")
	check(await wait_mark("guest-entity-move") and await wait_mark("observer-entity-move"),"both guests interpolate creature movement")
	mob.queue_free()
	mark("entity-remove")
	check(await wait_mark("guest-entity-remove") and await wait_mark("observer-entity-remove"),"creature removal reaches both guests")
	mark("done")
	await wait_mark("guest-done")
	await wait_mark("observer-done")

func run_client() -> void:
	check(game.network.join("127.0.0.1",connect_port) == OK,"connects")
	check(await wait_until(func(): return game.network.session_ready and game.state == "playing",90),"world loads")
	game.player.position = Vector3(ORIGIN)+Vector3(0.5,2,0.5)
	check(await wait_until(func(): return block_is(HOST_BLOCK,Nodes.STONE) and block_is(GUEST_BLOCK,Nodes.STONE)),"initial blocks are rendered")
	check(await wait_until(func(): return block_is(JOIN_BLOCK,Nodes.AIR)),"mining during join survives terrain generation")
	mark(mode+"-ready")
	await wait_mark("host-mined")
	check(await wait_until(func(): return block_is(HOST_BLOCK,Nodes.AIR)),"host mining updates data and visible mesh")
	game.network.apply_edits([[HOST_BLOCK,Nodes.STONE,0]])
	check(game.world.node_at(HOST_BLOCK) == Nodes.AIR,"an older block update cannot restore a mined block")
	game.network.applying = true
	game.world.apply_network_edit(HOST_BLOCK,Nodes.STONE)
	game.network.applying = false
	check(await wait_until(func(): return block_is(HOST_BLOCK,Nodes.AIR),10),"periodic reconciliation repairs a divergent block")
	var support: Vector3i = ORIGIN+Vector3i(2,5,2)
	game.network.applying = true
	game.world.apply_network_edit(support,Nodes.STONE)
	game.world.apply_network_edit(support+Vector3i.UP,Nodes.TORCH)
	var drops_before: int = game.drops.get_child_count()
	game.world.set_node(support,Nodes.AIR)
	check(game.world.node_at(support+Vector3i.UP) == Nodes.TORCH and game.drops.get_child_count() == drops_before,"replicated edits do not run support physics or duplicate item drops")
	game.world.apply_network_edit(support+Vector3i.UP,Nodes.AIR)
	game.network.applying = false
	mark(mode+"-host-mined")
	if mode == "guest":
		await wait_mark("guest-mine")
		game.break_node(GUEST_BLOCK,Nodes.STONE,0)
		check(await wait_until(func(): return game.network.pending_breaks.is_empty() and block_is(GUEST_BLOCK,Nodes.AIR)),"guest mining updates data and visible mesh")
		mark("guest-mined")
		await wait_mark("reject-placement")
		game.world.set_node(REJECTED_BLOCK,Nodes.GOLD_NODE)
		check(await wait_until(func(): return game.world.node_at(REJECTED_BLOCK) == Nodes.AIR,5),"host corrects rejected optimistic placement")
		mark("guest-rejected")
		await wait_mark("travel")
		game.player.position = Vector3(FAR_BLOCK)+Vector3(0.5,1,0.5)
		check(await wait_until(func(): return block_is(FAR_BLOCK,Nodes.STONE),60),"distant terrain includes initial host edits")
		mark("guest-far-ready")
		await wait_mark("far-mine")
		game.world.set_node(FAR_MACHINE,SteamMachines.BELLOWS)
		game.world.circuits.configure(FAR_MACHINE,Vector3i.UP)
		game.break_node(FAR_BLOCK,Nodes.STONE,0)
		check(await wait_until(func(): return game.network.pending_breaks.is_empty() and block_is(FAR_BLOCK,Nodes.AIR)),"mining works outside the host's view distance")
		mark("guest-far-mined")
	else:
		await wait_mark("check-guest-mine")
		check(await wait_until(func(): return block_is(GUEST_BLOCK,Nodes.AIR)),"another guest's mining updates data and visible mesh")
		mark("observer-guest-mined")
		await wait_mark("observer-travel")
		game.player.position = Vector3(FAR_BLOCK)+Vector3(0.5,1,0.5)
		check(await wait_until(func(): return game.world.loaded_at(Vector3(FAR_BLOCK)) and block_is(FAR_BLOCK,Nodes.AIR),60),"mined blocks stay removed after an unloaded chunk streams in")
		mark("observer-far-mined")
	await verify_entities()
	await wait_mark("done")
	game.player.position = Vector3(ORIGIN)+Vector3(0.5,2,0.5)
	check(await wait_until(func(): return game.world.loaded_at(Vector3(ORIGIN)) and block_is(HOST_BLOCK,Nodes.AIR) and block_is(GUEST_BLOCK,Nodes.AIR),60),"mined blocks stay removed after leaving and returning")
	mark(mode+"-done")

func verify_entities() -> void:
	await wait_mark("entity-spawn")
	var find_creature: Callable = func():
		for key in game.network.replicas:
			var entity: Node3D = game.network.replicas[key]
			if entity is Creature and entity.kind == "pig" and entity.position.distance_to(ENTITY_START) < 0.2: return key
		return 0
	check(await wait_until(func(): return find_creature.call() != 0),"new creatures are replicated")
	var key: int = find_creature.call()
	mark(mode+"-entity-spawn")
	await wait_mark("entity-move")
	check(await wait_until(func(): return game.network.replicas.has(key) and game.network.replicas[key].position.distance_to(ENTITY_START+Vector3.RIGHT*2.0) < 0.2),"remote creature movement converges to the server")
	check(game.network.replica_motion.has(key),"creatures use per-frame motion interpolation")
	mark(mode+"-entity-move")
	await wait_mark("entity-remove")
	check(await wait_until(func(): return not game.network.replicas.has(key)),"removed creatures disappear")
	game.network.entity_state([{"key":key,"kind":"pig","at":ENTITY_START,"yaw":0.0,"health":10.0}],game.network.received_entities-1)
	check(not game.network.replicas.has(key),"stale entity packets cannot resurrect removed creatures")
	mark(mode+"-entity-remove")
