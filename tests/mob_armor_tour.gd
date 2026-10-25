extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-mob-armor-visual-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Mob armor","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Armor visual world did not load"); quit(1); return
	print("ARMOR TOUR: world loaded")
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1600,9); game.player.hand.hide(); game.player.camera.look_at(Vector3(8,1601.2,4.8))
	for i in 3:
		var at := Vector3(6.4+i*1.6,1600,4.8)
		var mob: Creature = game.spawn_creature("zombie" if i == 1 else "skeleton",at); mob.set_physics_process(false)
		mob.model.rotation.y = PI; mob.mob_armor = MobArmor.empty_slots()
		for piece in 4: mob.mob_armor[piece] = {"id":MobArmor.material_item([2,3,5][i],piece),"count":1,"wear":0}
		if i == 1: mob.mob_armor[0] = {"id":FruitCrops.CARVED,"count":1,"wear":0}
		if mob.bow_model != null: mob.bow_model.hide()
		MobArmor.refresh(mob)
		var label := Label3D.new(); label.text = ["COPPER","PUMPKIN + GOLD","IRON"][i]
		label.font_size = 32; label.pixel_size = 0.003; label.position = at+Vector3(0,-0.25,0); game.add_child(label)
	for i in 6: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/voxey-mob-armor.png")
	print("ARMOR TOUR: saved preview")
	game.queue_free(); for i in 4: await process_frame
	quit()
