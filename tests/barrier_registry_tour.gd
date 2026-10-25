extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-barrier-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Registered walls and fences","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); game.hud.toast_time = 0; game.set_process(false); game.player.set_physics_process(false)
	game.environment.environment.fog_enabled = false; game.environment.environment.ambient_light_energy = 0.4
	game.environment.environment.ambient_light_sky_contribution = 0.0; game.environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR; game.sunlight.light_energy = 0.55
	var p := Vector3i(8,58,8)
	for x in range(-9,10):
		for z in range(-8,9):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 6: game.world.set_node(p+Vector3i(x,y,z),0)
	var walls: Array = [5100,BarrierCatalog.wall_for(ShapeMaterials.RED_SANDSTONE),BarrierCatalog.wall_for(PaleOak.RESIN_BRICK_BLOCK)]
	for i in walls.size():
		for x in range(-2,3): game.world.set_node(p+Vector3i(i*6-6+x,0,-4),walls[i])
		game.world.set_node(p+Vector3i(i*6-6,1,-4),Nodes.GLASS)
		game.world.set_node(p+Vector3i(i*6-7,1,-4),Nodes.GLASS)
		game.world.set_node(p+Vector3i(i*6-4,0,-3),walls[i])
	for i in 3:
		var fence: int = [WoodTypes.FENCE_BASES[0],WoodTypes.FENCE_BASES[1],WoodTypes.FENCE_BASES[3]][i]
		for x in range(-2,3): game.world.set_node(p+Vector3i(i*6-6+x,0,1),fence)
		game.world.set_node(p+Vector3i(i*6-6,0,1),fence+1)
		game.world.set_node(p+Vector3i(i*6-6,0,2),fence+5)
	var camera := Camera3D.new(); game.add_child(camera); camera.position = Vector3(p)+Vector3(12,11,16)
	camera.look_at(Vector3(p)+Vector3(0,0.6,-1)); camera.current = true
	game.player.position = Vector3(p)+Vector3(8,2,5); game.world.target = game.player.position; game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("/tmp/voxey-barrier-materials.png")
	game.inventory.restore([]); game.inventory.add_item(PaleOak.RESIN_BRICK,6); game.open_inventory("table")
	game.hud.catalog_mode = false; game.hud.recipe_search.text = "wall"; game.hud._populate_recipes()
	game.hud._select_recipe(game.inventory.recipe_index(walls[2])); game.hud._fill_grid()
	await shot("/tmp/voxey-barrier-recipes.png")
	game.queue_free()
	for i in 4: await process_frame
	print("BARRIER TOUR: wall states, restored wood fences and source recipe captured")
	quit()
