extends SceneTree
# Rendered streaming benchmark for issue #1: a survival world with every system
# running and an uncapped frame rate, the player carried at sprint speed through
# fresh terrain. Reports the load time, the frame time distribution, stalled
# frames and how much of the view distance had loaded by the end.
# Arguments after --: seconds (20), view distance (4), speed in blocks/s (5.6).
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-survival-stream-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seconds: float = float(args[0]) if args.size() > 0 else 20.0
	var radius: int = int(args[1]) if args.size() > 1 else 4
	var speed: float = float(args[2]) if args.size() > 2 else 5.6
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.world.radius = radius
	var load_start: int = Time.get_ticks_usec()
	game.start_new("8675309","Streaming benchmark","survival")
	while game.state == "loading": await process_frame
	var load_ms: float = (Time.get_ticks_usec()-load_start)/1000.0
	game.player.set_physics_process(false)
	game.player.position.y = 48
	game.player.rotation.y = -PI/2
	game.player.camera.rotation.x = -0.25
	var times := PackedFloat32Array()
	var over33: int = 0; var over50: int = 0; var over100: int = 0
	var started: int = Time.get_ticks_usec(); var previous: int = started
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now-previous)/1000.0
		previous = now; times.append(elapsed)
		if elapsed > 33.3: over33 += 1
		if elapsed > 50.0: over50 += 1
		if elapsed > 100.0: over100 += 1
		game.player.position.x += elapsed*0.001*speed
		game.player.health = 20; game.player.hunger = 20
	var sorted: PackedFloat32Array = times.duplicate(); sorted.sort()
	var total: float = 0.0
	for t in times: total += t
	var center := Vector2i(floori(game.player.position.x/16.0),floori(game.player.position.z/16.0))
	var wanted: int = 0; var have: int = 0
	for z in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			wanted += 1
			if game.world.columns.has(center+Vector2i(x,z)): have += 1
	var report: Dictionary = {"load_ms":load_ms,"frames":times.size(),"avg_fps":times.size()/(total/1000.0),"median":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"p99":sorted[int(sorted.size()*0.99)],"max":sorted[sorted.size()-1],"over33":over33,"over50":over50,"over100":over100,"loaded_fraction":float(have)/wanted,"creatures":game.creatures.get_child_count(),"edits":game.world.edits.size(),"distance":game.player.position.x,"radius":radius,"gpu":RenderingServer.get_video_adapter_name(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"map_blocks":game.world.blocks.size()}
	print("SURVIVAL STREAMING BENCHMARK: "+JSON.stringify(report))
	game.queue_free()
	for i in 4: await process_frame
	quit()
