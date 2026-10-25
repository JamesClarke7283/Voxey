extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-furnace-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Furnace workshop","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,55,8)
	game.world.set_node(p,VillageContent.BLAST_FURNACE)
	var station: Dictionary = game.world.get_station(p,"furnace")
	station.slots = [{"id":MobArmor.COPPER_HELMET,"count":1,"wear":85},{"id":Nodes.COAL,"count":4,"wear":0},{"id":RawOres.COPPER_NUGGET,"count":2,"wear":0}]
	FurnaceRules.step(station,2.0)
	game.inventory.restore([{ "id":Masonry.SMOOTH_STONE,"count":3,"wear":0},{"id":Nodes.IRON,"count":5,"wear":0},{"id":Masonry.SMOOTH_SANDSTONE,"count":16,"wear":0},{"id":Nodes.LAVA_BUCKET,"count":1,"wear":0}])
	game.open_inventory("furnace",p); game.hud.catalog_mode = false; game.hud.recipe_search.text = "copper"; game.hud._populate_recipes(); game.hud._select_furnace_item(MobArmor.COPPER_HELMET)
	await shot("/tmp/voxey-furnace-recipes.png")
	root.size = Vector2i(800,600); game.hud.show_inventory("furnace",station); game.hud.recipe_search.text = "copper"; game.hud._populate_recipes(); game.hud._select_furnace_item(MobArmor.COPPER_HELMET)
	await shot("/tmp/voxey-furnace-recipes-small.png")
	game.hud._furnace_tab(true); game.hud.recipe_search.text = "lava"; game.hud._populate_recipes(); game.hud._select_furnace_item(Nodes.LAVA_BUCKET)
	await shot("/tmp/voxey-furnace-fuels.png")
	print("FURNACE TOUR: full/compact recipes and fuel views captured")
	game.queue_free()
	for i in 4: await process_frame
	quit()
