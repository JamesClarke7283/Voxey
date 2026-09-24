extends SceneTree
# Rendered benchmark for crowds of mobs: 32 are spawned within 14 blocks of the
# player (hostile ones at night, or farm animals) on top of the world's own
# spawns, and frame times are measured with an uncapped frame rate.
# Arguments after --: hostile|passive (hostile), seconds (12).
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-mob-crowd-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "hostile"
	var seconds: float = float(args[1]) if args.size() > 1 else 12.0
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.world.radius = 3
	game.start_new("8675309","Mob crowd benchmark","survival")
	while game.state == "loading": await process_frame
	for i in 60: await process_frame
	var center: Vector3 = game.player.position
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var kinds: Array = ["zombie","skeleton","spider","creeper"] if scenario == "hostile" else ["cow","sheep","pig","chicken"]
	if scenario == "hostile": game.day_time = 0.75
	for i in 32:
		var p: Vector3 = center+Vector3(rng.randf_range(-14,14),0,rng.randf_range(-14,14))
		var ground: int = game.world.generator.terrain_height(int(p.x),int(p.z))
		game.spawn_creature(kinds[i%kinds.size()],Vector3(p.x,ground+1.05,p.z))
	game.player.set_physics_process(false)
	game.player.position.y += 30 # Out of reach, so the crowd keeps running.
	var times := PackedFloat32Array()
	var started: int = Time.get_ticks_usec(); var previous: int = started
	while Time.get_ticks_usec()-started < seconds*1000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now-previous)/1000.0); previous = now
		game.player.health = 20
	var sorted: PackedFloat32Array = times.duplicate(); sorted.sort()
	var total: float = 0.0
	for t in times: total += t
	print("MOB CROWD BENCHMARK %s: " % scenario+JSON.stringify({"avg_fps":times.size()/(total/1000.0),"median":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*0.95)],"max":sorted[sorted.size()-1],"creatures":game.creatures.get_child_count(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"gpu":RenderingServer.get_video_adapter_name()}))
	game.queue_free()
	for i in 4: await process_frame
	quit()
