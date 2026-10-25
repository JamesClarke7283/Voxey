extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-anvil-visual-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(path: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Anvil visual check","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,44,8)
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE); game.world.set_node(p,VillageContent.ANVIL)
	game.inventory.restore([])
	game.inventory.slots[0] = {"id":95,"count":1,"wear":650,"data":{"pwp":2,"custom_name":"Deep digger","enchantments":{"Efficiency":3,"Unbreaking":2}}}
	game.inventory.slots[1] = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"wear":0,"data":{"pwp":1,"enchantments":{"Efficiency":3,"Fortune":3}}}
	game.experience = 1451
	AnvilWorkbench.show(game,p,0,1)
	await shot("/tmp/voxey-anvil-full.png")
	root.size = Vector2i(800,600); game.experience = 0
	AnvilWorkbench.show(game,p,0,1)
	await shot("/tmp/voxey-anvil-small.png")
	game.queue_free()
	for i in 4: await process_frame
	quit()
