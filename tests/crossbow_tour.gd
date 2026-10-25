extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-crossbow-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Crossbow stages","survival")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1400,8); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"loaded_arrow":Nodes.ARROW_ITEM,"crossbow_loaded":true}}
	game.inventory.add_item(Nodes.ARROW_ITEM,32); game.player._make_hand(VillageContent.CROSSBOW); game.hud.refresh_slots()
	for i in 5:
		var stage: int = i-1
		var model := MeshInstance3D.new(); model.mesh = ItemArt.mesh(VillageContent.CROSSBOW,stage); model.material_override = ItemArt.material(VillageContent.CROSSBOW,stage)
		model.position = Vector3(8+(i-2)*1.02,1401.6,3.8); model.scale = Vector3.ONE*0.8; game.add_child(model)
		var label := Label3D.new(); label.text = ["REST","DRAW","HALF","FULL","LOADED"][i]
		label.font_size = 35; label.pixel_size = 0.003; label.position = model.position+Vector3(0,-0.57,0); game.add_child(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-crossbow-stages.png")
	game.queue_free(); for i in 4: await process_frame
	quit()
