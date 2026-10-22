extends SceneTree

var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-steam-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.hud.toast_time = 0
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-steam-shots/"+label+".png")
	print("STEAM SHOT: "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-steam-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Steam workshop tour","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 1.0; game.environment.environment.ambient_light_energy = 0.8
	var p := Vector3i(8,152,8)
	game.player.position = Vector3(p)+Vector3(0,0,12); game.world.target = Vector3(p)
	for x in range(-7,12):
		for z in range(-5,10): game.world.set_node(p+Vector3i(x,-1,z),Nodes.BRICKS)
	for entry in [[0,SteamMachines.GENERATOR],[1,SteamMachines.BELLOWS],[2,SteamMachines.PIPE],[3,SteamMachines.PIPE],[4,SteamMachines.GRINDER]]:
		game.world.set_node(p+Vector3i(entry[0],0,0),entry[1])
	game.world.circuits.configure(p+Vector3i(1,0,0),Vector3i.RIGHT)
	game.world.set_node(p+Vector3i(1,0,1),Nodes.REDSTONE_BLOCK)
	game.world.set_node(p+Vector3i(3,0,-1),SteamMachines.PIPE)
	game.world.set_node(p+Vector3i(3,0,-2),SteamMachines.FURNACE)
	SteamMachines.station(game.world,p).slots[0] = {"id":Nodes.COAL,"count":16,"wear":0}
	SteamMachines.station(game.world,p+Vector3i(4,0,0)).slots[0] = {"id":RawOres.RAW_IRON,"count":8,"wear":0}
	for i in 40: game.world.circuits.update(0.1)
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(p)+Vector3(8,6,9); camera.look_at(Vector3(p)+Vector3(1.5,0,-0.5))
	await shot("workshop")
	game.open_inventory("steam",p+Vector3i(4,0,0))
	await shot("grinder-interface")
	game.hud._clear(); game.world.active = false
	var base: Vector3i = p+Vector3i(-3,1,5)
	for x in 6:
		for z in 3:
			game.world.set_node(base+Vector3i(x,0,z),SteamMachines.FRAME)
			if z == 2: game.world.set_node(base+Vector3i(x,1,z),Nodes.PLANKS)
	for entry in [[0,SteamMachines.GENERATOR],[1,SteamMachines.BELLOWS],[2,SteamMachines.PIPE],[3,SteamMachines.PIPE],[4,SteamMachines.ENGINE]]:
		game.world.set_node(base+Vector3i(entry[0],1,1),entry[1])
	game.world.circuits.configure(base+Vector3i(1,1,1),Vector3i.RIGHT)
	game.world.circuits.configure(base+Vector3i(4,1,1),Vector3i.RIGHT)
	game.world.set_node(base+Vector3i(1,1,0),Nodes.REDSTONE_BLOCK)
	game.world.set_node(base+Vector3i(4,1,0),Nodes.REDSTONE_BLOCK)
	game.world.set_node(base+Vector3i(5,1,1),Nodes.CHEST)
	camera.position = Vector3(base)+Vector3(10,5,10); camera.look_at(Vector3(base)+Vector3(2,0.7,1))
	await shot("frame-vehicle")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(55,55)
	var column := VBoxContainer.new(); panel.add_child(column)
	var title := Label.new(); title.text = "STEAM & FLINTLOCKS"; title.add_theme_font_size_override("font_size",28); column.add_child(title)
	var grid := GridContainer.new(); grid.columns = 7; column.add_child(grid)
	for id in [AntiqueArms.MUSKET,AntiqueArms.PISTOL,AntiqueArms.BLUNDERBUSS,AntiqueArms.BAYONET,AntiqueArms.SHOT,SteamMachines.IRON_POWDER,SteamMachines.GOLD_POWDER]+SteamMachines.BLOCKS:
		var box := VBoxContainer.new(); grid.add_child(box)
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(135,100); icon.item_id = id; icon.count = 1; box.add_child(icon)
		var label := Label.new(); label.text = Nodes.title(id).replace(" ","\n"); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(label)
	await shot("items")
	game.queue_free(); canvas.queue_free()
	for i in 4: await process_frame
	quit()
