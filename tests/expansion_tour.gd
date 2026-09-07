extends SceneTree
var game: Node3D
var camera: Camera3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-expansion-tour-worlds")
	call_deferred("run")
func shot(filename: String) -> void:
	for i in 50: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/"+filename+".png")
func frame(at: Vector3, focus: Vector3) -> void:
	camera.position = at; camera.look_at(focus)
	camera.make_current()
	game.touch = false; game.state = "paused"; game.hud.show_game(); game.hud.toast_time = 0
	game.player.hand.visible = false
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.touch = true; game.audio_enabled = false; game.world.radius = 2
	game.start_new("8675309","Redstone and the End","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false
	camera = Camera3D.new(); camera.far = 250; camera.fov = 65; game.add_child(camera)
	for x in range(0,21):
		for z in range(0,17):
			game.world.set_node(Vector3i(x,48,z),Nodes.POLISHED_DEEPSLATE)
			for y in range(49,55): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(12,52,12)
	var circuit: RedstoneCircuit = game.world.circuits
	for lane in 3:
		var p := Vector3i(3,49,3+lane*4)
		game.world.set_node(p,Nodes.LEVER); circuit.interact(p)
		for x in range(1,8): game.world.set_node(p+Vector3i.RIGHT*x,Nodes.REDSTONE_WIRE)
		var rep := p+Vector3i.RIGHT*4
		game.world.set_node(rep,Nodes.REPEATER if lane != 2 else Nodes.COMPARATOR); circuit.configure(rep,Vector3i.RIGHT)
		game.world.set_node(p+Vector3i.RIGHT*8,[Nodes.REDSTONE_LAMP,Nodes.STICKY_PISTON,Nodes.DISPENSER][lane]); circuit.configure(p+Vector3i.RIGHT*8,Vector3i.RIGHT)
		if lane == 1: game.world.set_node(p+Vector3i.RIGHT*9,Nodes.GLASS)
	for i in 8: circuit.step()
	game.world.set_node(Vector3i(15,49,4),Nodes.HOPPER); circuit.configure(Vector3i(15,49,4),Vector3i.DOWN)
	game.world.set_node(Vector3i(15,49,8),Nodes.OBSERVER)
	game.world.set_node(Vector3i(15,49,12),Nodes.REDSTONE_TORCH)
	circuit.step()
	frame(Vector3(20,58,22),Vector3(9,49,7)); await shot("20_redstone")
	var stronghold: Vector3i = WorldStructures.nearest_stronghold(game.world.seed_value,game.player.position)
	game.touch = true; game.teleport(Vector3(stronghold)+Vector3(5.5,2,8.5))
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false
	for p in WorldStructures.frame_positions(stronghold+Vector3i(0,3,0)): WorldStructures.fill_eye(game.world,p)
	for offset in [Vector3i(6,1,7),Vector3i(-6,1,7),Vector3i(6,1,-7)]:
		game.world.set_node(stronghold+offset,Nodes.TORCH); game.add_torch(stronghold+offset)
	frame(Vector3(stronghold)+Vector3(6.5,7,8.5),Vector3(stronghold)+Vector3(0,3,0)); await shot("24_stronghold")
	game.touch = true; game.travel_dimension("nether")
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false
	game.teleport(Vector3(60,38,85))
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false
	for i in 250: await process_frame
	var ghast: Creature = game.spawn_creature("ghast",Vector3(60,30,60)); ghast.set_physics_process(false); ghast.model.rotation.y = atan2(-5,-7)
	var blaze: Creature = game.spawn_creature("blaze",Vector3(56,29.1,62)); blaze.set_physics_process(false)
	frame(Vector3(65,34,67),Vector3(60,32,60)); await shot("21_fortress_ghast")
	game.touch = true; game.travel_dimension("end")
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false; game.world.radius = 4
	game.player.position = Vector3(0,54,0); game.world.target = game.player.position
	for i in 2000:
		if game.world.columns.size() >= 81 and game.world.jobs.is_empty(): break
		await process_frame
	game.adventure.ensure_end()
	for mob in game.creatures.get_children():
		mob.set_physics_process(false)
		if mob.kind == "ender_dragon": mob.position = Vector3(6,63,12); mob.life = 2; mob._dragon(0.1)
	frame(Vector3(72,87,94),Vector3(0,48,0)); await shot("22_end_encounter")
	var enderman: Creature = game.spawn_creature("enderman",Vector3(9,46,7)); enderman.set_physics_process(false); enderman.model.rotation.y = PI
	frame(Vector3(16,49,20),Vector3(9,47,7)); await shot("23_enderman")
	game.touch = true; game.teleport(Vector3(288.5,43.01,0.5))
	while game.state == "loading": await process_frame
	game.pause(); game.world.active = false; game.adventure.city_guards()
	for mob in game.creatures.get_children(): mob.set_physics_process(false)
	frame(Vector3(305,64,22),Vector3(288,52,0)); await shot("25_end_city")
	game.queue_free()
	for i in 4: await process_frame
	quit()
