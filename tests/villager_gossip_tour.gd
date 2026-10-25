extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-gossip-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func capture(path: String) -> void:
	for i in 6: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Villager gossip prices","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.35
	game.player.position = Vector3(10,2100,6); game.player.hand.hide(); game.player.camera.look_at(Vector3(10,2101,10))
	for x in range(4,17):
		for z in range(4,16): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	var a: VillageMob = game.spawn_creature("villager",Vector3(10,2100,10)); a.set_physics_process(false)
	var person: Dictionary = game.villages.record(a.person_key); person.profession = "farmer"; a.profession = "farmer"
	person.offers = [
		{"tier":1,"cost":[[Nodes.GRAIN,20]],"give":[VillageContent.EMERALD,1],"uses":0,"stock":16,"xp":2,"data":{},"demand":0,"multiplier":0.05},
		{"tier":1,"cost":[[VillageContent.EMERALD,8]],"give":[Nodes.BREAD,6],"uses":0,"stock":16,"xp":1,"data":{},"demand":0,"multiplier":0.2},
		{"tier":2,"cost":[[VillageContent.EMERALD,20]],"give":[VillageContent.GOLDEN_CARROT,3],"uses":0,"stock":12,"xp":5,"data":{},"demand":0,"multiplier":0.2}]
	person.level = 2; person.xp = 10
	game.inventory.restore([]); game.inventory.add_item(VillageContent.EMERALD,64); game.inventory.add_item(Nodes.GRAIN,64)
	game.world.target = game.player.position; game.world.set_process(true)
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.villages.open(a); await capture("/tmp/voxey-gossip-prices-before.png")
	VillagerGossip.record(person,"player","major_positive",20); VillagerGossip.record(person,"player","minor_positive",25)
	game.villages.open(a); await capture("/tmp/voxey-gossip-prices-after.png")
	print("VILLAGER GOSSIP TOUR: captured base and cure-discounted trade panels"); game.queue_free()
	for i in 4: await process_frame
	quit()
