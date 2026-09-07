extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var atlas: Texture2D = Art.make_atlas()
	for dimension in ["overworld","nether"]:
		var world := VoxelWorld.new(); world.configure(8675309,atlas,dimension); root.add_child(world); world.set_process(false)
		var gen := TerrainGenerator.new(8675309,dimension)
		var generate_ms: Array = []; var apply_ms: Array = []; var snapshot_ms: Array = []
		for coord in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
			var start: int = Time.get_ticks_usec()
			var result: Dictionary = gen.generate_column(coord,{})
			generate_ms.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec(); world._apply_column(result)
			apply_ms.append((Time.get_ticks_usec()-start)/1000.0)
			start = Time.get_ticks_usec(); world._snapshot(Vector3i(coord.x,0,coord.y))
			snapshot_ms.append((Time.get_ticks_usec()-start)/1000.0)
		print(JSON.stringify({"dimension":dimension,"generation_ms":generate_ms,"main_thread_apply_ms":apply_ms,"remesh_snapshot_ms":snapshot_ms,"blocks":world.blocks.size()}))
		world.queue_free(); await process_frame
	quit()
