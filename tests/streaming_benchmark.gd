extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-stream-benchmark-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 4
	game.start_new("8675309","Streaming benchmark","creative")
	while game.state == "loading": await process_frame
	game.player.set_physics_process(false)
	game.set_process_input(false)
	game.player.position.y = 45
	game.player.rotation.y = 0.3
	game.player.camera.rotation.x = -0.3
	# Optional longer runs include the 30-second pasture ABM while streaming.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seconds: float = clampf(float(args[0]),1,120) if not args.is_empty() else 12.0
	var times: Array = []
	var slow_frames: int = 0
	var stalled_frames: int = 0
	var started: int = Time.get_ticks_usec(); var previous: int = started
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		# Desktop compositors may occlude the test window. Force the same scene
		# to draw so a hidden window cannot produce a false GPU benchmark.
		if DisplayServer.get_name() != "headless": RenderingServer.force_draw(false)
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now-previous)/1000.0
		previous = now; times.append(elapsed)
		if elapsed > 1000.0/30.0: slow_frames += 1
		if elapsed > 100.0: stalled_frames += 1
		game.player.position.x += elapsed*0.006
	times.sort()
	var report: Dictionary = game.performance_snapshot()
	report["drops"] = game.drops.get_child_count()
	report["drop_types"] = {}
	for drop in game.drops.get_children():
		var title: String = Nodes.title(drop.item_id)
		report.drop_types[title] = int(report.drop_types.get(title,0))+1
	report["creatures"] = game.creatures.get_child_count()
	report["flow_pending"] = game.world.fluids.pending[0].size()+game.world.fluids.pending[1].size()
	report["flow_states"] = 0
	for id in game.world.edits.values():
		if Fluids.flowing(id): report.flow_states += 1
	report["samples"] = times.size()
	report["duration_seconds"] = seconds
	report["pasture_cells"] = Pasture.state(game.world).cells.size()
	report["snow_cells"] = SnowCover.state(game.world).cells.size()
	report["leaf_cells"] = WoodTypes.runtime(game.world).leaves.size()
	report["leaf_orphans"] = WoodTypes.runtime(game.world).orphans.size()
	report["leaf_pending"] = WoodTypes.runtime(game.world).queued.size()
	report["frame_cap"] = Engine.max_fps
	report["camera_rotation"] = [game.player.rotation.y,game.player.camera.rotation.x]
	report["frame_ms_median"] = times[times.size()/2]
	report["frame_ms_p95"] = times[int(times.size()*0.95)]
	report["frame_ms_max"] = times.back()
	report["frames_over_33_ms"] = slow_frames
	report["frames_over_100_ms"] = stalled_frames
	report["distance_blocks"] = game.player.position.x-8
	print("STREAMING BENCHMARK: "+JSON.stringify(report))
	if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_png("/tmp/voxey-streaming-final.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
