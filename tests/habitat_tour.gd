extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-habitat-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(label: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/voxey-habitat-shots/"+label+".png")
	print("HABITAT SHOT: "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-habitat-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Pasture and mechanisms tour","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Habitat visual world failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.sunlight.light_energy = 0.55; game.environment.environment.ambient_light_energy = 0.35; game.daylight = 1.0
	var origin := Vector3i(8,152,8)
	game.player.position = Vector3(origin)+Vector3(0,0,7)
	for x in range(-8,9):
		for z in range(-6,8): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.GRASS)
	for x in range(-4,4):
		for z in [-3,3]: game.world.set_node(origin+Vector3i(x,0,z),5000 if x != 0 else 5001)
	for z in range(-2,3):
		for x in [-4,3]: game.world.set_node(origin+Vector3i(x,0,z),5000)
	Barriers.set_open(game.world,origin+Vector3i(0,0,3),true)
	for i in 3:
		var sheep: Creature = game.spawn_creature("sheep",Vector3(origin)+Vector3(-2+i*1.7,0,-0.5)); sheep.set_physics_process(false)
		Farming.set_color(sheep,["cyan","magenta","blue"][i]); sheep.rotation.y = 0.4+i*0.6
		if i == 1: sheep.growth_remaining = 1200; Farming.resize(sheep)
		if i == 0:
			sheep.custom_name = "Clover"; NameTags.refresh(sheep); game.leads.attach(sheep,false); game.leads.anchor_at(origin+Vector3i(-4,0,0))
		if i == 2: sheep.shear(); game.world.set_node(Vector3i(sheep.position.floor())+Vector3i.DOWN,Nodes.DIRT)
	game.leads.update(0.01)
	for i in 3:
		var p: Vector3i = origin+Vector3i(-6,0,i*2-1)
		game.world.set_node(p,VillageContent.CAULDRON)
		if i > 0: Cauldrons.set_contents(Cauldrons.station(game.world,p),3,"water" if i == 1 else "lava")
	for i in 5:
		game.world.set_node(origin+Vector3i(5,0,i-3),[5100,5101,5102,5111,5117][i])
	game.world.set_node(origin+Vector3i(5,1,-1),Nodes.TORCH)
	var detector: Vector3i = origin+Vector3i(-1,0,-5)
	game.world.set_node(detector,RedstoneSensors.DAYLIGHT)
	game.world.set_node(detector+Vector3i.RIGHT,Nodes.REDSTONE_WIRE)
	game.world.set_node(detector+Vector3i.RIGHT*2,Nodes.REDSTONE_LAMP)
	var target: Vector3i = origin+Vector3i(5,0,4)
	game.world.set_node(target,RedstoneSensors.TARGET)
	game.world.set_node(target+Vector3i.RIGHT,Nodes.REDSTONE_WIRE)
	game.world.set_node(target+Vector3i.RIGHT*2,Nodes.REDSTONE_LAMP)
	RedstoneSensors.hit(game.world,target,Vector3(target)+Vector3(0.5,0.5,1))
	for i in 3: game.world.circuits.step(0.01)
	game.survival.refresh_displays()
	game.hud.toast_time = 0; game.hud.queue_redraw()
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(13,11,16); camera.look_at(Vector3(origin)+Vector3(0,0.4,0)); camera.current = true
	deadline = Time.get_ticks_msec()+20000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("pasture-and-mechanisms")
	camera.position = Vector3(origin)+Vector3(5,4,8); camera.look_at(Vector3(origin)+Vector3(-0.5,0.55,0.2)); await shot("fences-and-dyed-sheep")
	camera.position = Vector3(origin)+Vector3(10,3,8); camera.look_at(Vector3(origin)+Vector3(5.5,0.65,3)); await shot("walls-and-target")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(80,50)
	var row := HBoxContainer.new(); panel.add_child(row)
	for id in [5000,5001,5016,5017,5100,5117,RedstoneSensors.DAYLIGHT,RedstoneSensors.TARGET,VillageContent.CAULDRON]:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(72,72); icon.item_id = id; icon.count = 1; row.add_child(icon)
	await shot("inventory-icons")
	game.queue_free(); canvas.queue_free()
	for i in 4: await process_frame
	quit()
