extends SceneTree
# Headless measurements for the stalls reported in issue #1: worker time per
# generated column, main-thread time to apply a column near many player edits,
# and main-thread time of an autosave in a large world.
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-lag-benchmark-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var report: Dictionary = {"cpus":OS.get_processor_count(),"generation_slots":VoxelWorld.generation_slots}
	var atlas: Texture2D = Art.make_atlas()
	# Worker cost of one column. The generator is reused, as pooled jobs reuse it.
	for dimension in ["overworld","nether"]:
		var gen := TerrainGenerator.new(8675309,dimension)
		var times: Array = []
		for coord in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE,Vector2i(5,-3),Vector2i(-7,2)]:
			var start: int = Time.get_ticks_usec()
			gen.generate_column(coord,{})
			times.append((Time.get_ticks_usec()-start)/1000.0)
		report[dimension+"_generation_ms"] = times
	# Main-thread cost of applying a column that contains player edits.
	for count in [0,1000,4000]:
		var world := VoxelWorld.new(); world.configure(8675309,atlas,"overworld"); root.add_child(world); world.set_process(false)
		var rng := RandomNumberGenerator.new(); rng.seed = 5
		var palette: Array = [Nodes.STONE,Nodes.PLANKS,Nodes.GLASS,Nodes.AIR,Nodes.COBBLE,Nodes.TORCH]
		while world.edits.size() < count:
			world.edits[Vector3i(rng.randi_range(0,15),rng.randi_range(20,50),rng.randi_range(0,15))] = palette[rng.randi_range(0,palette.size()-1)]
		var local: Dictionary = {}
		for p in world.edits_near(Vector2i.ZERO): local[p] = world.edits[p]
		var result: Dictionary = TerrainGenerator.new(8675309,"overworld").generate_column(Vector2i.ZERO,local)
		# A streaming job records the edits it generated with, as here.
		result["edit_snapshot"] = local
		var start: int = Time.get_ticks_usec()
		world._apply_column(result)
		report["apply_ms_with_%d_edits" % count] = (Time.get_ticks_usec()-start)/1000.0
		world.queue_free(); await process_frame
	# Main-thread cost of the autosave compared with a synchronous save.
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Lag benchmark","survival")
	while game.state == "loading": await process_frame
	var save_rng := RandomNumberGenerator.new(); save_rng.seed = 3
	while game.world.edits.size() < 40000:
		game.world.edits[Vector3i(save_rng.randi_range(-2000,2000),save_rng.randi_range(-60,60),save_rng.randi_range(-2000,2000))] = Nodes.STONE
	var began: int = Time.get_ticks_usec()
	game.save_game("",true)
	report["autosave_main_thread_ms_40000_edits"] = (Time.get_ticks_usec()-began)/1000.0
	game.finish_background_save()
	began = Time.get_ticks_usec()
	game.save_game()
	report["synchronous_save_ms_40000_edits"] = (Time.get_ticks_usec()-began)/1000.0
	print("LAG BENCHMARK: "+JSON.stringify(report))
	game.queue_free()
	for i in 4: await process_frame
	quit()
