extends SceneTree

var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-special-crop-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	game.hud.toast_time = 0; game.hud.queue_redraw()
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-special-crop-shots/"+label+".png")
	print("SPECIAL CROP SHOT: "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-special-crop-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Special crop visual checks","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Special crop tour failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.65; game.environment.environment.ambient_light_energy = 0.4
	game.environment.environment.fog_enabled = false; game.daylight = 1
	var origin := Vector3i(8,2300,8)
	for x in range(-11,12):
		for z in range(-7,11): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.BRICKS)
	for stage in 3:
		var log_at: Vector3i = origin+Vector3i(stage*3-6,0,-3)
		var pod: Vector3i = log_at+Vector3i.RIGHT
		game.world.set_node(log_at,CocoaCrops.JUNGLE_LOG)
		game.world.set_node(pod,CocoaCrops.STAGES[stage])
		CocoaCrops.set_facedir(game.world,pod,1)
	for stage in 4:
		var wart: Vector3i = origin+Vector3i(stage*2-7,0,2)
		game.world.set_node(wart+Vector3i.DOWN,Nodes.SOUL_SAND)
		game.world.set_node(wart,NetherWartCrops.STAGES[stage])
		var berry: Vector3i = origin+Vector3i(stage*2,0,2)
		game.world.set_node(berry+Vector3i.DOWN,Nodes.GRASS)
		game.world.set_node(berry,SweetBerryCrops.STAGES[stage])
	var bush: Vector3i = origin+Vector3i(6,0,-2)
	game.world.set_node(bush+Vector3i.DOWN,LushCaveExtra.ROOTED_DIRT)
	var tree: Dictionary = AzaleaTrees.tree_plan(0)
	for offset in tree.blocks: game.world.set_node(bush+offset,int(tree.blocks[offset]))
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(10,8,16); camera.look_at(Vector3(origin)+Vector3(0,1,0))
	await shot("cocoa-wart-berry-and-azalea")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(170,65)
	var grid := GridContainer.new(); grid.columns = 5; panel.add_child(grid)
	for id in [CocoaCrops.BEANS,NetherWartCrops.ITEM,SweetBerryCrops.BERRY,LushCaveExtra.AZALEA,LushCaveExtra.ROOTED_DIRT]:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(100,100); icon.item_id = id; icon.count = 1; grid.add_child(icon)
	await shot("special-crop-inventory-icons")
	game.queue_free(); canvas.queue_free()
	for i in 4: await process_frame
	quit()
