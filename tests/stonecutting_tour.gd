extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-stonecutting-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Stonecutting workshop","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); game.hud.toast_time = 0; game.set_process(false); game.player.set_physics_process(false)
	game.environment.environment.fog_enabled = false; game.environment.environment.ambient_light_energy = 0.4
	game.environment.environment.ambient_light_sky_contribution = 0.0; game.environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR; game.sunlight.light_energy = 0.55
	var p := Vector3i(8,58,8)
	for x in range(-6,7):
		for z in range(-6,7):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(p+Vector3i(x,y,z),0)
	for i in 6: game.world.set_node(p+Vector3i((i%3)*2,0,(i/3)*3),Stonecutting.placed([0,4,8,12,16,20][i]))
	var camera := Camera3D.new(); game.add_child(camera); camera.position = Vector3(p)+Vector3(5,4,7)
	camera.look_at(Vector3(p)+Vector3(1.5,0.4,1.5)); camera.current = true
	game.player.position = Vector3(p)+Vector3(5,2,5); game.world.target = game.player.position; game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("/tmp/voxey-stonecutting-workshop.png")
	var state: Dictionary = game.world.get_station(p,"stonecutter")
	state.slots[0] = {"id":Nodes.COPPER_NODE,"count":3,"wear":0,"data":{"copper_waxed":true}}
	game.open_inventory("stonecutter",p); game.hud._select_cut("mcl_copper:block_grate_preserved"); game.hud._fill_cut()
	await shot("/tmp/voxey-stonecutting-copper.png")
	root.size = Vector2i(800,600); game.hud.show_inventory("stonecutter",state)
	await shot("/tmp/voxey-stonecutting-compact.png")
	state.slots[0] = {"id":PaleOak.RESIN_BRICK,"count":6,"wear":0}; Stonecutting.refresh(state); game.hud.refresh_slots()
	await shot("/tmp/voxey-stonecutting-unavailable.png")
	game.queue_free()
	for i in 4: await process_frame
	print("STONECUTTING TOUR: geometry, copper, compact and unavailable views captured")
	quit()
