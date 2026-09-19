extends SceneTree
var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-mechanism-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.hud.toast_time = 0; game.hud.queue_redraw()
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-mechanism-shots/"+label+".png")
	print("MECHANISM SHOT: "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-mechanism-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Music and mechanisms tour","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Mechanism tour world failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.45; game.environment.environment.ambient_light_energy = 0.25; game.daylight = 1
	var origin := Vector3i(8,152,8)
	game.player.position = Vector3(origin)+Vector3(0,0,12); game.world.target = Vector3(origin)
	for x in range(-11,12):
		for z in range(-5,10): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.BRICKS)
	for i in RedstoneInputs.BUTTON_ITEMS.size():
		var support: Vector3i = origin+Vector3i(i*2-8,1,0)
		game.world.set_node(support,Nodes.STONE)
		var p: Vector3i = support+Vector3i.BACK
		game.world.set_node(p,RedstoneInputs.oriented(RedstoneInputs.BUTTON_ITEMS[i],Vector3i.BACK))
		if i%2: RedstoneInputs.press(game.world,p)
	for i in RedstoneInputs.PLATE_ITEMS.size():
		var p: Vector3i = origin+Vector3i(i*2-9,0,3)
		game.world.set_node(p,RedstoneInputs.PLATE_ITEMS[i])
		if i%2:
			game.world.circuits.state(p)["input_pressed"] = true
			game.world.circuits.refresh(p)
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(10,7,14); camera.look_at(Vector3(origin)+Vector3(0,0.7,1.5))
	await shot("buttons-and-pressure-plates")
	var materials: Array = [Nodes.PLANKS,Nodes.STONE,Nodes.SAND,Nodes.GLASS,Nodes.GOLD_BLOCK,Nodes.WOOL,Nodes.IRON_BLOCK,Nodes.HAY_BALE]
	for i in materials.size():
		var p: Vector3i = origin+Vector3i(i*2-8,0,6)
		game.world.set_node(p,materials[i]); game.world.set_node(p+Vector3i.UP,NoteBlocks.ID)
		NoteBlocks.state(game.world,p+Vector3i.UP)["note"] = i*3
	var jukebox: Vector3i = origin+Vector3i(9,0,6)
	game.world.set_node(jukebox,Jukeboxes.ID)
	Jukeboxes.station(game.world,jukebox).slots[0] = {"id":Jukeboxes.CHIRP,"count":1,"wear":0}
	camera.position = Vector3(origin)+Vector3(10,6,15); camera.look_at(Vector3(origin)+Vector3(0,0.8,6))
	await shot("note-block-instruments-and-jukebox")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(50,50)
	var grid := GridContainer.new(); grid.columns = 10; panel.add_child(grid)
	var items: Array = RedstoneInputs.items()+[NoteBlocks.ID,Jukeboxes.ID]+Jukeboxes.RECORDS.keys()
	for id in items:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(72,72); icon.item_id = id; icon.count = 1; grid.add_child(icon)
	await shot("mechanism-inventory-icons")
	canvas.queue_free(); await process_frame
	for i in 6:
		var p: Vector3i = origin+Vector3i(i*2-5,0,8)
		game.world.set_node(p,[7400,7401,7402,7403,7404,Dungeons.SPAWNER][i])
	camera.position = Vector3(origin)+Vector3(5,4,14); camera.look_at(Vector3(origin)+Vector3(0,0.6,8))
	await shot("ice-bone-and-spawner")
	game.hud.show_guide()
	for i in 3: await process_frame
	for scroll in game.hud.layer.find_children("*","ScrollContainer",true,false): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await shot("music-credits")
	game.queue_free()
	for i in 4: await process_frame
	quit()
