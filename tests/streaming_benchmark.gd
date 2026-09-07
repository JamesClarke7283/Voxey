extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-stream-benchmark-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 4
	game.start_new("8675309","Streaming benchmark","creative")
	while game.state == "loading": await process_frame
	game.player.set_physics_process(false)
	game.player.position.y = 45
	game.player.camera.rotation.x = -0.3
	var times: Array = []
	var started: int = Time.get_ticks_usec(); var previous: int = started
	while Time.get_ticks_usec()-started < 12000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var elapsed: float = (now-previous)/1000.0
		previous = now; times.append(elapsed)
		game.player.position.x += elapsed*0.006
	times.sort()
	var report: Dictionary = game.performance_snapshot()
	report["samples"] = times.size()
	report["frame_ms_median"] = times[times.size()/2]
	report["frame_ms_p95"] = times[int(times.size()*0.95)]
	report["frame_ms_max"] = times.back()
	report["distance_blocks"] = game.player.position.x-8
	print("STREAMING BENCHMARK: "+JSON.stringify(report))
	game.queue_free()
	for i in 4: await process_frame
	quit()
