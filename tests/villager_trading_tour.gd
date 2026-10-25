extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-trading-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func capture(path: String) -> void:
	for i in 8: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Villager progression","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.35
	game.player.position = Vector3(10,2100,6); game.player.hand.hide(); game.player.camera.look_at(Vector3(10,2101,10))
	for x in range(4,17):
		for z in range(4,16): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	var mob: VillageMob = game.spawn_creature("villager",Vector3(10,2100,10)); mob.set_physics_process(false)
	var p: Dictionary = game.villages.make_record(mob.person_key,"cleric",mob.position,Vector3i(10,2100,10),Vector3i(10,2100,10),Vector3i(10,2100,10)); mob.bind(p)
	game.inventory.restore([]); game.inventory.add_item(Nodes.ROTTEN_FLESH,64); game.inventory.add_item(VillageContent.EMERALD,64)
	game.world.target = game.player.position; game.world.set_process(true)
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.villages.open(mob); await capture("/tmp/voxey-trading-novice.png")
	game.villages.trade(p.key,0); game._process(2.01)
	await capture("/tmp/voxey-trading-apprentice.png")
	var trader = WanderingTraders.spawn(game,Vector3(12,2100,10)); trader.set_physics_process(false)
	game.villages.open(trader); await capture("/tmp/voxey-trading-wandering.png")
	print("VILLAGER TRADING TOUR: captured real Novice trade and delayed Apprentice unlock"); game.queue_free()
	for i in 4: await process_frame
	quit()
