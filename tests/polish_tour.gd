extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-polish-tour-worlds")
	call_deferred("run")
func shot(name: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-polish-shots/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-polish-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = false; game.world.radius = 2
	game.start_new("8675309","My Awesome World","creative")
	while game.state == "loading": await process_frame
	game.pause(); await shot("pause")
	var panel: Control = game.hud.layer.get_child(1)
	for child in panel.get_children():
		if child is Button: assert(Rect2(Vector2.ZERO,panel.size).encloses(child.get_rect()),"pause button outside panel")
	game.inventory.restore([])
	for id in [Nodes.TORCH,95,Nodes.GOLD,Nodes.LAPIS,Nodes.BOOK,Nodes.LAVA_BUCKET,Nodes.OBSIDIAN,Nodes.REDSTONE_TORCH,Pouches.SINGLE]: game.inventory.add_item(id,1)
	game.open_inventory(); game.hud.catalog_mode = false; game.hud._populate_recipes()
	await shot("recipe-grid")
	game.hud.recipe_search.text = "torch"; game.hud.recipe_search.text_changed.emit("torch")
	await shot("recipe-search")
	var cell: Control = game.hud.recipe_list.get_child(0)
	Input.warp_mouse(cell.get_global_rect().get_center())
	for frame in 100: await process_frame
	await shot("recipe-hover")
	game.hud.return_cursor(); game.pause(); game.hud._clear()
	var origin := Vector3i(8,55,8)
	for x in range(-7,8):
		for z in range(-7,8):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(4): game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	for x in range(-4,3):
		for z in range(-4,2): game.world.set_node(origin+Vector3i(x,0,z),Nodes.LAVA)
	for x in range(-5,6):
		for y in range(0,3): game.world.set_node(origin+Vector3i(x,y,-6),Nodes.STONE)
	for x in [-3,0,3]:
		game.world.set_node(origin+Vector3i(x,1,-5),Torches.placed(Vector3i.BACK))
	game.world.set_node(origin+Vector3i(4,0,0),Nodes.TORCH)
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(6,4,8)
	camera.look_at(Vector3(origin)+Vector3(0,0.5,-2)); camera.current = true
	game.player.position = Vector3(origin)+Vector3(6,2,6)
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	await shot("lava-and-torches")
	print("GPU CHECK: "+JSON.stringify(game.performance_snapshot()))
	game.hud.show_pause()
	root.size = Vector2i(960,600)
	for frame in 10: await process_frame
	game.hud.show_pause(); await shot("pause-small")
	game.state = "title"; game.hud.show_worlds(); await shot("worlds-delete-button")
	game.hud.show_delete_world({"id":game.active_world_id,"name":"My Awesome World"}); await shot("delete-confirmation")
	game.hud.show_worlds()
	game.queue_free()
	for frame in 4: await process_frame
	quit()
