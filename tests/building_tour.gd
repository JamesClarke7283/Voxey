extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-building-tour-worlds")
	call_deferred("run")
func shot(name: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-building-shots/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-building-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Stairs and slabs","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear()
	var origin := Vector3i(8,55,8)
	for x in range(-8,9):
		for z in range(-8,9):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
			for y in 5: game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	var materials: Array = [Nodes.PLANKS,Nodes.RED_BRICKS,VillageContent.QUARTZ_BLOCK,Bastions.BRICKS]
	for i in 4:
		var p: Vector3i = origin+Vector3i(i*3-5,0,-2)
		var stair: int = BuildingShapes.stair_for(materials[i])
		game.world.set_node(p,stair+2)
		game.world.set_node(p+Vector3i.FORWARD+Vector3i.UP,stair+2)
		game.world.set_node(p+Vector3i.FORWARD*2+Vector3i.UP*2,BuildingShapes.slab_for(materials[i]))
		game.world.set_node(p+Vector3i.BACK*4,BuildingShapes.slab_for(materials[i]))
		game.world.set_node(p+Vector3i.BACK*5,BuildingShapes.slab_for(materials[i])+1)
	for p in [Vector3i(-3,0,0),Vector3i(2,0,0)]:
		game.world.set_node(origin+p,BuildingShapes.stair_for(Nodes.RED_BRICKS))
		game.world.set_node(origin+p+Vector3i.BACK,BuildingShapes.stair_for(Nodes.RED_BRICKS)+(1 if p.x < 0 else 3))
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(10,9,12)
	camera.look_at(Vector3(origin)+Vector3(0,0.7,0)); camera.current = true
	game.player.position = Vector3(origin)+Vector3(6,2,6)
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	await shot("shapes")
	game.open_inventory(); game.hud.catalog_mode = false
	game.hud.recipe_search.text = "stairs"; game.hud.recipe_search.text_changed.emit("stairs")
	await shot("stairs-inventory")
	var cell: Control = game.hud.recipe_list.get_child(0)
	Input.warp_mouse(cell.get_global_rect().get_center())
	for frame in 100: await process_frame
	await shot("stairs-hover")
	game.hud.recipe_search.text = "slab"; game.hud.recipe_search.text_changed.emit("slab")
	await shot("slabs-inventory")
	game.pause(); game.hud._clear()
	for x in range(-8,9):
		for z in range(-8,9):
			for y in 5: game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	for i in Masonry.BLOCKS.size():
		game.world.set_node(origin+Vector3i(i%4*3-4,0,i/4*4-2),Masonry.BLOCKS[i])
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	camera.position = Vector3(origin)+Vector3(8,7,10); camera.look_at(Vector3(origin)+Vector3(0.5,0.5,0))
	await shot("masonry")
	game.survival.show_station(origin,VillageContent.STONECUTTER)
	await shot("stonecutter")
	game.queue_free()
	for frame in 4: await process_frame
	quit()
