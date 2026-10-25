extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-baby-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Baby undead and jockeys","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1900,10); game.player.hand.hide(); game.player.camera.look_at(Vector3(8,1900.9,4.8))
	for i in 4:
		var at := Vector3(5.3+i*1.8,1900,4.8)
		var mob: Creature = game.spawn_creature(["zombie","baby_zombie","baby_husk","baby_drowned"][i],at,"",{"jockey":false}); mob.set_physics_process(false)
		mob.mob_armor = MobArmor.empty_slots(); MobArmor.refresh(mob)
		MobWeapons.set_item(mob,{"id":Nodes.TOOLS+13,"count":1,"wear":0},2)
		mob.model.rotation.y = PI
		if i == 2:
			var bird: Creature = game.spawn_creature("chicken",at); bird.set_physics_process(false); bird.model.rotation.y = PI
			MobJockeys.attach(mob,bird)
		var label := Label3D.new(); label.text = ["ADULT ZOMBIE","BABY ZOMBIE","HUSK JOCKEY","BABY DROWNED"][i]
		label.font_size = 30; label.pixel_size = 0.003; label.position = at+Vector3(0,-0.25,0); game.add_child(label)
	for i in 6: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-baby-undead.png")
	print("BABY TOUR: saved preview"); game.queue_free()
	for i in 4: await process_frame
	quit()
