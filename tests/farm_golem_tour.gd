extends SceneTree

var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-farm-golem-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	game.hud.toast_time = 0; game.hud.queue_redraw()
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-farm-golem-shots/"+label+".png")
	print("FARM GOLEM SHOT: "+label)

func label_at(text: String, at: Vector3) -> void:
	var label := Label3D.new(); label.text = text; label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.pixel_size = 0.008
	label.font_size = 28; label.outline_size = 7; game.add_child(label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-farm-golem-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Farmland, crops and golems tour","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Farm tour world failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.6; game.environment.environment.ambient_light_energy = 0.35
	game.environment.environment.fog_enabled = false; game.daylight = 1
	var origin := Vector3i(8,2300,8)
	game.player.position = Vector3(origin)+Vector3(0,0,15); game.world.target = Vector3(origin)
	for x in range(-11,12):
		for z in range(-8,13): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.BRICKS)
	for row in 4:
		for i in CropFarming.STAGES[row].size():
			var p: Vector3i = origin+Vector3i(i*2-8,0,row*3-5)
			game.world.set_node(p,Farmland.WET if i%2 == 0 else Farmland.DRY)
			game.world.set_node(p+Vector3i.UP,CropFarming.STAGES[row][i])
		label_at(CropFarming.NAMES[row],Vector3(origin)+Vector3(-10,1.8,row*3-5))
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(8,11,18); camera.look_at(Vector3(origin)+Vector3(-1,0.5,0))
	await shot("crop-stages-and-wet-dry-soil")
	# A close view makes the actual lowered surface and mature root crops visible.
	camera.position = Vector3(origin)+Vector3(8,3.5,-0.5); camera.look_at(Vector3(origin)+Vector3(5,0.8,-2))
	await shot("farmland-surface-and-roots")
	for child in game.get_children():
		if child is Label3D: child.queue_free()
	for x in range(-11,12):
		for z in range(-8,13):
			game.world.set_node(origin+Vector3i(x,1,z),Nodes.AIR)
			game.world.set_node(origin+Vector3i(x,0,z),Nodes.AIR)
	# Construct both golems through the same placement callback used in survival.
	var iron_head: Vector3i = origin+Vector3i(-4,2,0)
	for at in [iron_head+Vector3i.DOWN,iron_head+Vector3i.DOWN*2,iron_head+Vector3i.DOWN+Vector3i.LEFT,iron_head+Vector3i.DOWN+Vector3i.RIGHT]: game.world.set_node(at,Nodes.IRON_BLOCK)
	game.world.set_node(iron_head,FruitCrops.head_id(false,2))
	var snow_head: Vector3i = origin+Vector3i(1,2,0)
	for at in [snow_head+Vector3i.DOWN,snow_head+Vector3i.DOWN*2]: game.world.set_node(at,Nodes.SNOW_BLOCK)
	game.world.set_node(snow_head,FruitCrops.head_id(false,2))
	camera.position = Vector3(origin)+Vector3(8,6,13); camera.look_at(Vector3(origin)+Vector3(0,1,0))
	await shot("golem-building-patterns")
	var iron: Creature = Golems.placed(game,iron_head,game.player_id)
	var snow: Creature = Golems.placed(game,snow_head,game.player_id)
	if iron == null or snow == null: push_error("Golem tour construction failed"); game.queue_free(); quit(1); return
	for mob in [iron,snow]: mob.set_physics_process(false); mob.model.rotation.y = PI
	var bare: SnowGolem = Golems.spawn(game,"snow_golem",Vector3(origin)+Vector3(5.5,0,0.5))
	bare.set_physics_process(false); bare.model.rotation.y = PI
	game.inventory.slots[game.inventory.selected] = {"id":Nodes.SHEARS,"count":1,"wear":0}
	Golems.use(game,bare)
	label_at("Iron golem",iron.position+Vector3.UP*3.2)
	label_at("Snow golem",snow.position+Vector3.UP*2.5)
	label_at("Sheared snow golem",bare.position+Vector3.UP*2.5)
	camera.position = Vector3(origin)+Vector3(8,5,12); camera.look_at(Vector3(origin)+Vector3(0,1.1,0))
	await shot("constructed-and-sheared-golems")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(110,60)
	var grid := GridContainer.new(); grid.columns = 10; panel.add_child(grid)
	for id in [Nodes.FARMLAND,Farmland.WET,Nodes.SEEDS,Nodes.GRAIN,VillageContent.CARROT,VillageContent.POTATO,CropFarming.POISONOUS_POTATO,VillageContent.BEETROOT,VillageContent.BEETROOT_SEEDS,VillageContent.BEETROOT_SOUP]:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(88,88); icon.item_id = id; icon.count = 1; grid.add_child(icon)
	await shot("farming-inventory-icons")
	game.queue_free(); canvas.queue_free()
	for i in 4: await process_frame
	quit()
