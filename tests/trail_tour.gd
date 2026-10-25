extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-trail-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Trail ruin template preview","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.7; game.environment.environment.ambient_light_energy = 0.65
	game.environment.environment.fog_enabled = false
	game.environment.environment.background_mode = Environment.BG_COLOR
	game.environment.environment.background_color = Color("9eaca3")
	game.clouds.visible = false
	var gen: TerrainGenerator = game.world.generator
	var site: Dictionary = TrailRuins.assemble(gen,TrailRuins.candidate(gen,Vector2i(-3,3)))
	var bounds: AABB = site.pieces[0].box
	for piece in site.pieces: bounds = bounds.merge(piece.box)
	var stage := Vector3i(8,150,8)
	var move: Vector3i = stage-Vector3i(bounds.get_center().floor())
	for p in site.voxels:
		if site.voxels[p] != Nodes.AIR: game.world.set_node(p+move,site.voxels[p])
	game.world.target = Vector3(stage); game.player.position = Vector3(stage)
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true; camera.fov = 54
	var distance: float = maxf(bounds.size.x,bounds.size.z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = distance
	camera.position = Vector3(stage)+Vector3(distance*0.65,distance*0.85,distance*0.9)
	camera.look_at(Vector3(stage)+Vector3(0,1,0))
	deadline = Time.get_ticks_msec()+45000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10:
		game.hud.toast_time = 0; game.hud.queue_redraw(); RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-trail-preview.png")
	print("TRAIL PREVIEW: /tmp/voxey-trail-preview.png; pieces=",site.pieces.size()," seeded gravel=",site.states.size())
	game.queue_free()
	for i in 4: await process_frame
	quit()
