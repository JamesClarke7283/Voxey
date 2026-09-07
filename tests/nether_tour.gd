extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-visual-worlds")
	call_deferred("run")
func shot(filename: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/"+filename+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false
	game.touch = true
	game.world.radius = 2
	game.start_new("8675309","Nether visual check","creative")
	while game.state == "loading": await process_frame
	game.pause()
	game.player.position = Vector3(8.5,44,13.5)
	var p := Vector3i(8,44,8)
	for x in range(-5,6):
		for z in range(-5,6):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.PLANKS)
			for y in range(0,5): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(p,Nodes.ENCHANTING_TABLE)
	for x in range(-2,3):
		for z in range(-2,3):
			if maxi(absi(x),absi(z)) == 2 and z != 2:
				for y in 2: game.world.set_node(p+Vector3i(x,y,z),Nodes.BOOKSHELF)
	game.inventory.slots[0] = {"id":95,"count":1,"wear":0}
	game.inventory.slots[1] = {"id":Nodes.LAPIS,"count":16,"wear":0}
	game.inventory.slots[2] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"title":"Beyond the portal","text":"Day 12\n\nI found lava deep below the meadow. Water turned it into obsidian.\n\nThe portal led to a red cavern with a sea of lava, quartz in the walls, and glowing fungi.\n\nRemember: bring food, a pickaxe, and plenty of building blocks."}}
	game.experience = 1200
	game.open_enchanting(p)
	await shot("12_enchanting")
	game.inventory.selected = 2; game.open_book()
	await shot("13_writable_book")
	game.resume(); game.player.rotation.y = 0; game.player.camera.rotation.x = -0.3
	game.touch = false; game.state = "paused"; game.hud.show_game(); game.hud.toast_time = 0
	await shot("14_enchanting_room")
	game.touch = true
	game.travel_dimension("nether")
	while game.state == "loading": await process_frame
	game.gamemode = "creative"
	game.player.position += Vector3(0,4,5)
	game.player.rotation.y = 0.3; game.player.camera.rotation.x = -0.2
	game.touch = false; game.state = "paused"; game.hud.show_game(); game.hud.toast_time = 0
	game._update_day()
	await shot("15_nether")
	game.queue_free()
	for i in 4: await process_frame
	quit()
