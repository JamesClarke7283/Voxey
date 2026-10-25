extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-well-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Desert well preview","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.7; game.environment.environment.ambient_light_energy = 0.65
	game.environment.environment.fog_enabled = false; game.clouds.visible = false
	game.environment.environment.background_mode = Environment.BG_COLOR
	game.environment.environment.background_color = Color("b7cbb7")
	var origin := Vector3i(8,150,8)
	var well: Dictionary = DesertWells.plan(game.world.generator,Vector3i(0,31,0),71,func(p): return Nodes.SAND if p.y <= 30 else Nodes.AIR,Vector2i(2,2))
	if well.is_empty(): push_error("Preview well was rejected"); game.queue_free(); quit(1); return
	for x in range(-5,6):
		for z in range(-5,6):
			for y in range(-2,1): game.world.set_node(origin+Vector3i(x,y,z),Nodes.SAND)
	for p in well.voxels: game.world.set_node(p+origin-Vector3i(0,30,0),well.voxels[p])
	game.world.target = Vector3(origin); game.player.position = Vector3(origin)
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true; camera.fov = 54
	camera.position = Vector3(origin)+Vector3(7,7,11); camera.look_at(Vector3(origin)+Vector3(0,1,0))
	await finish_meshes(game)
	root.get_texture().get_image().save_png("/tmp/voxey-desert-well.png")
	for x in range(-2,3):
		for z in range(2,6):
			for y in range(-2,1): game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	camera.position = Vector3(origin)+Vector3(3,1.8,8); camera.look_at(Vector3(origin)+Vector3(0,-0.5,0))
	await finish_meshes(game)
	root.get_texture().get_image().save_png("/tmp/voxey-desert-well-excavation.png")
	print("DESERT WELL PREVIEWS: /tmp/voxey-desert-well.png and /tmp/voxey-desert-well-excavation.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()

func finish_meshes(game: Node3D) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 8:
		game.hud.toast_time = 0; game.hud.queue_redraw(); RenderingServer.force_draw(false); await process_frame
