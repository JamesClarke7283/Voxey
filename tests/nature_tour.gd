extends SceneTree

var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-nature-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.hud.toast_time = 0; game.hud.queue_redraw()
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-nature-shots/"+label+".png")
	print("NATURE SHOT: "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-nature-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Crops, honey and crystals tour","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Nature tour world failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.45; game.environment.environment.ambient_light_energy = 0.25; game.environment.environment.fog_enabled = false; game.daylight = 1
	var origin := Vector3i(8,152,8)
	game.player.position = Vector3(origin)+Vector3(0,0,14); game.world.target = Vector3(origin)
	for x in range(-11,12):
		for z in range(-8,12): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.BRICKS)
	for row in 2:
		for i in 8:
			var p: Vector3i = origin+Vector3i(i*2-8,0,row*3)
			game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
			game.world.set_node(p,(FruitCrops.PUMPKIN_STEM if row == 0 else FruitCrops.MELON_STEM)+i)
	for row in 2:
		var p: Vector3i = origin+Vector3i(8,0,row*3)
		game.world.set_node(p+Vector3i.DOWN,Nodes.FARMLAND)
		game.world.set_node(p,(FruitCrops.PUMPKIN_STEM if row == 0 else FruitCrops.MELON_STEM)+7)
		game.world.set_node(p+Vector3i.RIGHT,Nodes.PUMPKIN if row == 0 else Nodes.MELON)
	for i in 4: game.world.set_node(origin+Vector3i(i*3-4,0,6),[Nodes.PUMPKIN,Nodes.MELON,FruitCrops.head_id(false,2),FruitCrops.head_id(true,2)][i])
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(10,7,15); camera.look_at(Vector3(origin)+Vector3(0,0.25,2.5))
	await shot("stems-fruit-and-pumpkins")
	for x in range(-10,11):
		for z in range(-4,9): game.world.set_node(origin+Vector3i(x,0,z),Nodes.AIR)
	for row in 2:
		for i in 6: game.world.set_node(origin+Vector3i(i*3-8,0,row*3),Beehives.HIVE+i*4+2 if row == 0 else Beehives.NEST+i*4+2)
	for i in 4:
		var p: Vector3i = origin+Vector3i(i*3-4,0,6)
		game.world.set_node(p,[Beehives.COMB_BLOCK,Beehives.HONEY_BLOCK,Amethyst.TINTED_GLASS,Nodes.GLASS][i])
		game.world.set_node(p+Vector3i.FORWARD,Nodes.PUMPKIN)
	camera.position = Vector3(origin)+Vector3(8,6,15); camera.look_at(Vector3(origin)+Vector3(0,0.7,3))
	await shot("honey-levels-and-transparent-blocks")
	for x in range(-10,11):
		for z in range(-4,9): game.world.set_node(origin+Vector3i(x,0,z),Nodes.AIR)
	for i in 4:
		var p: Vector3i = origin+Vector3i(i*3-4,0,1)
		game.world.set_node(p,Amethyst.BUDDING); game.world.set_node(p+Vector3i.UP,Amethyst.STAGES[i])
	for i in Amethyst.SUPPORTS.size():
		var p: Vector3i = origin+Vector3i(i*3-7,2,6)
		game.world.set_node(p,Amethyst.BUDDING)
		game.world.set_node(p-Amethyst.SUPPORTS[i],Amethyst.oriented(Amethyst.CLUSTER,-Amethyst.SUPPORTS[i]))
	camera.position = Vector3(origin)+Vector3(9,7,17); camera.look_at(Vector3(origin)+Vector3(0,1.7,3.5))
	await shot("amethyst-stages-and-six-faces")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(65,55)
	var grid := GridContainer.new(); grid.columns = 9; panel.add_child(grid)
	for id in [FruitCrops.PUMPKIN_SEEDS,FruitCrops.MELON_SEEDS,FruitCrops.CARVED,FruitCrops.JACK,Beehives.HIVE,Beehives.NEST,Beehives.COMB,Beehives.BOTTLE,Spyglass.ID]+Amethyst.BLOCKS+[Amethyst.SHARD,Beehives.COMB_BLOCK,Beehives.HONEY_BLOCK]:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(76,76); icon.item_id = id; icon.count = 1; grid.add_child(icon)
	await shot("nature-inventory-icons")
	canvas.queue_free(); await process_frame
	game.player.camera.current = true; game.player.camera.global_transform = camera.global_transform
	game.state = "playing"; game.hud.show_game()
	for id in [Amethyst.TINTED_GLASS,Beehives.HONEY_BLOCK]:
		game.inventory.slots[game.inventory.selected] = {"id":id,"count":1,"wear":0}
		game.inventory.changed.emit(); game.player._make_hand(id)
		var drop: ItemDrop = game.spawn_drop(game.player.camera.global_position-game.player.camera.global_basis.z*2-game.player.camera.global_basis.x*0.5,id)
		drop.set_physics_process(false)
		await shot("held-and-dropped-"+str(id))
		drop.queue_free(); await process_frame
	game.inventory.slots[game.inventory.selected] = {"id":0,"count":0,"wear":0}
	game.inventory.changed.emit(); game.player._make_hand(0)
	game.player.armor_slots[0] = {"id":FruitCrops.CARVED,"count":1,"wear":0}
	await shot("pumpkin-helmet-overlay")
	game.player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.inventory.slots[game.inventory.selected] = {"id":Spyglass.ID,"count":1,"wear":0}
	game.player.camera.global_position = Vector3(origin)+Vector3(0,4,50)
	game.player.camera.look_at(Vector3(origin)+Vector3(0,1,1))
	Spyglass.set_active(game.player,true)
	await shot("spyglass-aperture")
	Spyglass.reset(game.player); game.pause(); game.hud._clear(); camera.current = true
	# Render an actual generated geode with its front half removed for inspection.
	for x in range(-11,12):
		for z in range(-8,12):
			for y in range(-1,5): game.world.set_node(origin+Vector3i(x,y,z),Nodes.AIR)
	var geode: Dictionary = AmethystGeodes.candidate(game.world.generator,Vector2i(-8,6))
	if geode.is_empty(): push_error("Expected seed geode missing"); game.queue_free(); quit(1); return
	var offset: Vector3i = origin-geode.origin-Vector3i(5,0,5)
	for pass_index in 2:
		for p in geode.voxels:
			if p.z <= geode.origin.z+5 and int(Amethyst.is_crystal(geode.voxels[p])) == pass_index: game.world.set_node(p+offset,geode.voxels[p])
	camera.position = Vector3(origin)+Vector3(14,13,22); camera.look_at(Vector3(origin)+Vector3(0,4,0))
	await shot("natural-geode-cutaway")
	game.queue_free()
	for i in 4: await process_frame
	quit()
