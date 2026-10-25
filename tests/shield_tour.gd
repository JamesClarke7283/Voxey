extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-shield-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Decorated shields","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var sample: Dictionary = Shields.decorate([load("res://tests/shield_decor_checks.gd").guard(),load("res://tests/shield_decor_checks.gd").flag()])
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.add_item(VillageContent.SHIELD,1,84,load("res://tests/shield_decor_checks.gd").guard().data)
	game.inventory.add_item(Banners.FIRST+6,3,0,load("res://tests/shield_decor_checks.gd").flag().data)
	game.inventory.fill_grid(load("res://tests/shield_decor_checks.gd").guide_index(game.inventory,6),"hand")
	game.hud.recipe_index = load("res://tests/shield_decor_checks.gd").guide_index(game.inventory,6)
	game.open_inventory("hand"); await shot("/tmp/voxey-shield-crafting.png")
	game.hud.return_cursor(); game.inventory.restore([]); game.resume(); game.player.hand.hide()
	game.player.position = Vector3(8,1000,8); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	var colors: Array = [6,9,12,-1]
	for i in 4:
		var item: Dictionary = sample.duplicate(true)
		item.data.shield_color = maxi(0,colors[i])
		if i == 1: item.data.layers = [{"pattern":"diagonal_right","color":0},{"pattern":"border","color":4}]
		if i == 2: item.data.layers = [{"pattern":"globe","color":4}]
		var model: MeshInstance3D = Shields.model(item)
		model.position = Vector3(8+(i-1.5)*1.1,1001.5,4); model.scale = Vector3.ONE*1.2
		if i == 3: model.rotation.y = PI
		game.add_child(model)
		var label := Label3D.new(); label.text = ["RED / GOLD","BLUE / WHITE","GLOBE","WOODEN BACK"][i]
		label.font_size = 40; label.pixel_size = 0.003; label.position = model.position+Vector3(0,-0.7,0); game.add_child(label)
	await shot("/tmp/voxey-shield-models.png")
	game.player.offhand_slot = sample; game.survival.shield_raised = true; game.survival.shield_disabled = 0
	game.player._update_shield_view(); await shot("/tmp/voxey-shield-blocking.png")
	game.queue_free(); for i in 4: await process_frame
	quit()
