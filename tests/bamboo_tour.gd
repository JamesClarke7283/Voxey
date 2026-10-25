extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-bamboo-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Bamboo materials preview","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.85; game.environment.environment.ambient_light_energy = 0.7
	var origin := Vector3i(8,152,8)
	game.world.target = Vector3(origin); game.player.position = Vector3(origin)
	for x in range(-8,9):
		for z in range(-3,7): game.world.set_node(origin+Vector3i(x,-1,z),BambooWood.PLANKS)
	var blocks: Array = [BambooWood.BLOCK,BambooWood.STRIPPED,BambooWood.PLANKS,BambooWood.MOSAIC,BuildingShapes.stair_for(BambooWood.MOSAIC),BuildingShapes.slab_for(BambooWood.MOSAIC)]
	for i in blocks.size(): game.world.set_node(origin+Vector3i(i-7,0,-1),blocks[i])
	game.world.set_node(origin+Vector3i(0,0,-1),Doors.state_id(BambooWood.DOOR,0,false,false,false))
	game.world.set_node(origin+Vector3i(0,1,-1),Doors.state_id(BambooWood.DOOR,0,false,false,true))
	for x in range(2,7): game.world.set_node(origin+Vector3i(x,2,-1),BambooWood.PLANKS)
	var p: Vector3i = origin+Vector3i(3,1,-1)
	game.world.set_node(p,BambooWood.HANGING)
	var state: Dictionary = Signs.station(game.world,p); state.text = "BAMBOO"; state.written = true
	p = origin+Vector3i(6,0,-1); game.world.set_node(p,BambooWood.SIGN+4)
	state = Signs.station(game.world,p); state.text = "Workshop"; state.written = true
	for x in range(2,5): game.world.set_node(origin+Vector3i(x,0,-1),BambooWood.FENCE)
	game.world.set_node(origin+Vector3i(7,0,-1),BambooWood.TRAPDOOR)
	for x in range(-6,7):
		for z in range(2,6): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.WATER)
	for i in 2:
		var raft: BoatEntity = game.boats.spawn(BambooWood.RAFT if i == 0 else BambooWood.CHEST_RAFT,Vector3(origin)+Vector3(-3+i*6,-0.15,3.5))
		if raft != null: raft.set_physics_process(false); raft.rotation.y = 0.3 if i == 0 else -0.3
	game.survival.refresh_displays()
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true; camera.fov = 62
	camera.position = Vector3(origin)+Vector3(0,7.5,13); camera.look_at(Vector3(origin)+Vector3(0,0.5,1))
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10:
		game.hud.toast_time = 0; game.hud.queue_redraw(); RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-bamboo-preview.png")
	print("BAMBOO PREVIEW: /tmp/voxey-bamboo-preview.png")
	camera.position = Vector3(origin)+Vector3(4,2.8,3.5); camera.look_at(Vector3(origin)+Vector3(3.7,1.0,-1))
	for i in 4: RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-bamboo-signs-preview.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
