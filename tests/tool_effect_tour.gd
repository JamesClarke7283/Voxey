extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-tool-effect-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = false; game.world.radius = 2
	game.start_new("8675309","Haste beacon preview","survival")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.85; game.environment.environment.ambient_light_energy = 0.7
	var p := Vector3i(8,152,8)
	game.world.target = Vector3(p)
	for d in range(1,5):
		for x in range(-d,d+1):
			for z in range(-d,d+1): game.world.set_node(p+Vector3i(x,-d,z),Nodes.IRON_BLOCK)
	game.world.set_node(p,Beacons.ID); Beacons.registered(game.world,p,Beacons.ID)
	Beacons.station(game.world,p).effect = "haste"
	game.inventory.restore([]); game.inventory.selected = 0; game.inventory.slots[0] = {"id":95,"count":1,"wear":0}
	game.player.position = Vector3(p)+Vector3(0.5,1,12)
	game.player.rotation.y = 0; game.player.camera.rotation.x = -0.3
	game.player.crouching = true; Beacons.use(game,{"pos":p}); game.player.crouching = false
	Beacons.update(game.world,1)
	game.hud.show_game(); game.hud.toast_time = 20
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10: game.hud.queue_redraw(); RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-haste-beacon.png")
	print("HASTE PREVIEW: /tmp/voxey-haste-beacon.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
