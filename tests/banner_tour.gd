extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-banner-visual-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Banner visual checks","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,44,8)
	for x in range(-5,6):
		for z in range(-5,6):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.PLANKS)
			for y in range(0,5): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(8.5,44,13.5); game.player.rotation.y = 0; game.player.camera.rotation.x = -0.2
	game.inventory.restore([])
	game.inventory.slots[0] = load("res://tests/banner_checks.gd").patterned(4)
	game.inventory.slots[1] = {"id":Banners.FIRST+9,"count":3,"wear":0}
	game.inventory.slots[2] = {"id":VillageContent.DYE_WHITE,"count":16,"wear":0}
	game.inventory.slots[3] = {"id":VillageContent.DYE_YELLOW,"count":16,"wear":0}
	game.inventory.slots[4] = {"id":VillageContent.PATTERN_FIRST+2,"count":3,"wear":0}
	game.inventory.selected = 0
	Banners.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0)
	Banners.show_loom(game,p)
	await shot("/tmp/voxey-banner-loom.png")
	root.size = Vector2i(800,600); game.survival.set_meta("loom_pattern","diagonal_up_right"); Banners.show_loom(game,p)
	await shot("/tmp/voxey-banner-loom-small.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
