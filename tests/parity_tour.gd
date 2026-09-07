extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-parity-tour-worlds")
	call_deferred("run")
func shot(name: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-parity-shots/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-parity-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true
	game.hud.show_title(); await shot("offline-title")
	game.world.radius = 2; game.start_new("8675309","Nether progression","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.inventory.restore([])
	for id in [Netherite.ANCIENT_DEBRIS,Netherite.SCRAP,Netherite.INGOT,Netherite.TEMPLATE,Netherite.BLOCK,Netherite.TOOLS,Netherite.TOOLS+1,Netherite.TOOLS+2,Netherite.TOOLS+3,Netherite.TOOLS+4,Netherite.ARMOR,Netherite.ARMOR+1,Netherite.ARMOR+2,Netherite.ARMOR+3,Bastions.GILDED,Bastions.CRYING_OBSIDIAN,Bastions.LODESTONE,Bastions.GOLD_TOOLS+1,PiglinBarter.FIRE_CHARGE,Nodes.COMPASS]: game.inventory.add_item(id,1)
	game.open_inventory(); await shot("netherite-inventory")
	game.hud.return_cursor(); game.pause()
	var site: Dictionary = Bastions.nearest(TerrainGenerator.new(game.world.seed_value,"nether"),Vector3.ZERO)
	var p: Vector3 = Vector3(site.center)+Vector3(0.5,1.01,7.5)
	game.player_homes[game.player_id] = {"dimension":"nether","position":[p.x,p.y,p.z],"yaw":0,"pitch":0}; game.teleport_home()
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); Bastions.populate(game)
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(site.center)+Vector3(0,10,13); camera.look_at(Vector3(site.center)+Vector3(0,10,0)); camera.current = true
	await shot("bastion")
	camera.position = Vector3(site.center)+Vector3(-2,16.4,-1.5); camera.look_at(Vector3(site.center)+Vector3(-4.5,16,-4.5))
	await shot("piglin-brute")
	game.queue_free()
	for frame in 4: await process_frame
	quit()
