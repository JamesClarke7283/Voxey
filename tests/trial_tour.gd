extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-trial-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Trial chambers preview","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.7; game.environment.environment.ambient_light_energy = 0.65
	var origin := Vector3i(8,152,8)
	game.world.target = Vector3(origin)
	for x in range(-7,9):
		for z in range(-3,5): game.world.set_node(origin+Vector3i(x,-1,z),Masonry.TUFF_BRICKS)
	var blocks: Array = [Trials.SPAWNER,Trials.OMINOUS_ACTIVE,Trials.VAULT_ON,Trials.OMINOUS_VAULT_ON]
	for i in blocks.size():
		var p: Vector3i = origin+Vector3i(i*3-5,0,0)
		game.world.set_node(p,blocks[i])
		var tile: int = Nodes.tile(blocks[i],0)
		print("TRIAL ART ",blocks[i]," color=",Nodes.color(blocks[i])," tile=",tile," pixel=",Art.atlas_texture.get_image().get_pixel((tile%8)*16+5,(tile/8)*16+5))
		var s: Dictionary = Trials.station(game.world,p)
		if Trials.is_vault(blocks[i]): s.preview = Trials.KEY if i == 2 else VillageContent.HEAVY_CORE
		Trials.refresh_display(game.world,p,s,0.3)
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(0,2.5,8); camera.look_at(Vector3(origin)+Vector3(0,0.5,0.5))
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10:
		game.hud.toast_time = 0; game.hud.queue_redraw()
		RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-trials-preview.png")
	print("TRIAL PREVIEW: /tmp/voxey-trials-preview.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
