extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-enchanting-visual-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Enchanting visual check","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,44,8)
	for x in range(-5,6):
		for z in range(-5,6):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.PLANKS)
			for y in range(0,5): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(p,Nodes.ENCHANTING_TABLE)
	for shelf in Enchanting.source.bookshelf_positions:
		if shelf[2] != 2: game.world.set_node(p+Vector3i(shelf[0],shelf[1],shelf[2]),Nodes.BOOKSHELF)
	game.player.position = Vector3(8.5,44,13.5); game.player.rotation.y = 0; game.player.camera.rotation.x = -0.3
	game.inventory.restore([])
	game.inventory.slots[0] = {"id":95,"count":1,"wear":0}
	game.inventory.slots[1] = {"id":Nodes.LAPIS,"count":16,"wear":0}
	game.inventory.slots[2] = {"id":Nodes.BOOK,"count":8,"wear":0}
	game.experience = 1451
	for seed_value in range(1,256):
		game.enchanting_state[game.player_id] = {"seed":seed_value,"serial":0,"cache":{}}
		if Enchanting.offers(game,game.inventory.slots[0],15).all(func(row):return not row.is_empty()): break
	game.open_enchanting(p)
	await shot("/tmp/voxey-enchanting-full.png")
	root.size = Vector2i(800,600); game.experience = 0
	game.hud.show_enchanting(p,2)
	await shot("/tmp/voxey-enchanting-small.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
