extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-copper-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(path: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Copper workshop","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.inventory.restore([]); game.inventory.selected = 0
	for i in 5: game.inventory.slots[i] = {"id":CopperTools.IDS[i],"count":1,"wear":0}
	game.inventory.slots[5] = {"id":Nodes.COPPER,"count":16,"wear":0}
	game.inventory.slots[6] = {"id":Nodes.STICK,"count":16,"wear":0}
	game.inventory.slots[7] = {"id":Harvesting.item_id("mcl_copper:copper_nugget"),"count":9,"wear":0}
	var recipe: int = game.inventory.recipe_index(CopperTools.FIRST)
	game.inventory.fill_grid(recipe,"table"); game.hud.recipe_index = recipe
	game.open_inventory("table"); game.hud.catalog_mode = false; game.hud._populate_recipes()
	await shot("/tmp/voxey-copper-crafting.png")
	root.size = Vector2i(800,600); game.hud.show_inventory("table"); game.hud.recipe_index = recipe; game.hud._populate_recipes()
	await shot("/tmp/voxey-copper-crafting-small.png")
	print("COPPER TOUR: /tmp/voxey-copper-crafting.png and /tmp/voxey-copper-crafting-small.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
