extends SceneTree

var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-lifecycle-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	for i in 10: await process_frame
	# Explicitly draw when the desktop compositor has occluded the test window.
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/voxey-lifecycle-shots/"+label+".png")
	print("LIFECYCLE SHOT: "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-lifecycle-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Survival lifecycle tour","creative")
	print("LIFECYCLE TOUR: world loading")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Lifecycle visual world did not load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false)
	game.sunlight.light_energy = 0.55; game.environment.environment.ambient_light_energy = 0.35
	print("LIFECYCLE TOUR: world loaded")
	game.player.set_process(false); game.player.set_physics_process(false)
	var origin := Vector3i(8,146,8)
	for x in range(-8,9):
		for z in range(-6,9): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.GRASS)
	for i in 4:
		var p: Vector3i = origin+Vector3i(i*2-3,0,1)
		game.world.set_node(p,[Campfires.LIT,Campfires.SOUL_LIT,Campfires.UNLIT,Campfires.SOUL_UNLIT][i])
		if i < 2:
			var station: Dictionary = Campfires.station(game.world,p)
			for food in [VillageContent.RAW_BEEF,VillageContent.POTATO,VillageContent.RAW_COD,VillageContent.RAW_CHICKEN]: Campfires.add(station,{"id":food,"count":1,"wear":0})
			for j in 3:
				var smoke := CampfireSmoke.new(); smoke.game = game; smoke.dimension = game.dimension
				smoke.position = Vector3(p)+Vector3(0.45+j*0.1,1.0+j*1.0,0.5); game.entities.add_child(smoke); smoke.set_process(false)
	for i in 4:
		var mob: Creature = game.spawn_creature("sheep" if i < 2 else "cow",Vector3(origin)+Vector3(i*1.8-3,0,-2))
		mob.set_physics_process(false)
		if i%2 == 1: mob.growth_remaining = 1200; Farming.resize(mob)
		if i == 2: mob.custom_name = "Daisy"; NameTags.refresh(mob)
	for x in range(-5,0):
		for z in range(4,8):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
			game.world.set_node(origin+Vector3i(x,0,z),Nodes.WATER)
	game.player.position = Vector3(origin)+Vector3(-1,1,7)
	game.inventory = Inventory.new(); game.inventory.add_item(VillageContent.FISHING_ROD)
	game.survival.fish({"pos":origin+Vector3i(-3,0,5),"id":Nodes.WATER})
	game.survival.refresh_displays()
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(10,8,13); camera.look_at(Vector3(origin)+Vector3(0,0.7,0.5)); camera.current = true
	deadline = Time.get_ticks_msec()+20000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("campfires-and-animals")
	camera.position = Vector3(origin)+Vector3(5,4,6); camera.look_at(Vector3(origin)+Vector3(0,0.4,0))
	await shot("cooking-and-babies")
	game.inventory = Inventory.new(); game.inventory.add_item(NameTags.ITEM,3,0,{"custom_name":"Daisy"}); game.inventory.add_item(Fishing.NAUTILUS_SHELL)
	game.inventory.add_item(VillageContent.CROSSBOW,1,6,{"custom_name":"Scout","enchantments":{"Quick Charge":2}})
	game.survival.show_station(origin,VillageContent.ANVIL)
	await shot("anvil-naming")
	game.queue_free()
	for i in 4: await process_frame
	quit()
