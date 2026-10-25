extends RefCounted
static func kind(world: VoxelWorld, p: Vector3i) -> String:
	return str(BarrierCatalog.info(world.node_at(p)).get("state",""))
static func run(t: SceneTree, game: Node3D) -> void:
	var w: VoxelWorld = game.world; var p := Vector3i(15,58,8)
	game.pause(); game.set_process(false); w.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(p)+Vector3(5,0,5)
	for x in range(-3,4):
		for z in range(-3,4):
			w.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(4): w.set_node(p+Vector3i(x,y,z),0)
	w.set_node(p+Vector3i.LEFT,Nodes.STONE); w.set_node(p+Vector3i.RIGHT,Nodes.STONE); w.set_node(p,5100)
	t.check(kind(w,p) == "short_flat","Straight source wall drops its center post")
	t.check(not w.intersects(Vector3(p)+Vector3(0.05,1.26,0.5),0.01,0.1) and w.intersects(Vector3(p)+Vector3(0.05,1.20,0.5),0.01,0.1),"Short flat wall collision spans its length and ends at source height 1.25")
	w.set_node(p+Vector3i.UP,Nodes.STONE)
	t.check(kind(w,p) == "tall_flat","Full block overhead raises the wall without adding a center post")
	t.check(Barriers.world_boxes(w,p,true).all(func(box):return is_equal_approx(box.end.y,1.0)),"Tall flat wall uses the source's one-block collision height")
	w.set_node(p+Vector3i.UP,Barriers.FIRST)
	t.check(kind(w,p) == "short_flat","A fence overhead does not force a source wall post")
	w.set_node(p+Vector3i.UP,0); w.set_node(p+Vector3i.RIGHT,VillageContent.GLASS_PANE)
	t.check(kind(w,p) == "short_flat" and Barriers.mask(w.node_at(p),Barriers.neighbors(w,p)) == 5,"Glass panes participate in source wall connections")
	w.set_node(p+Vector3i.RIGHT,0)
	t.check(kind(w,p) == "short_pillar","Breaking a neighbor restores the wall post")
	t.check(w.intersects(Vector3(p)+Vector3(0.8,1.2,0.5),0.01,0.1) and not w.intersects(Vector3(p)+Vector3(0.8,1.26,0.5),0.01,0.1),"Pillar collision uses the source's 0.75 width and 1.25 height")
	var red: int = BarrierCatalog.wall_for(ShapeMaterials.RED_SANDSTONE)
	var resin: int = BarrierCatalog.wall_for(PaleOak.RESIN_BRICK_BLOCK)
	t.check(red > 0 and resin > 0 and Nodes.placeable(red) and Nodes.placeable(resin),"Red sandstone and resin-brick walls are obtainable items")
	var inv := Inventory.new()
	for id in [red,resin]:
		inv.restore([]); inv.add_item(PaleOak.RESIN_BRICK if id == resin else Barriers.material(id),6)
		t.check(inv.craft(inv.recipe_index(id),"table") and inv.count_item(id) == 6,"Six source ingredients craft six "+Nodes.title(id))
	for base in [Nodes.MOSSY_BRICKS,Masonry.MOSSY_BRICKS]:
		var cutter: Dictionary = {"slots":[{"id":base,"count":1,"wear":0},Stonecutting.empty()]}
		Stonecutting.select(cutter,"mcl_walls:stonebrickmossy_short_pillar")
		t.check(Stonecutting.take(cutter,1).id == 5105,"Stonecutter accepts equivalent source mossy stone brick IDs")
	t.check(Stonecutting.choices({"id":PaleOak.RESIN_BRICK,"count":1}).is_empty(),"Resin wall ingredients are excluded by the source's stonecuttable group filter")
	game.resume(); game.set_process(false); game.player.set_physics_process(false)
	for base in WoodTypes.FENCE_BASES:
		game.inventory.restore([]); game.inventory.add_item(base,2); game.inventory.selected = 0
		w.set_node(p+Vector3i.UP,0); w.set_node(p,0); game.gamemode = "survival"
		Barriers.try_place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE})
		t.check(w.node_at(p) == base and Barriers.is_fence(w.node_at(p)) and not Doors.is_door(base) and game.inventory.count_item(base) == 1,"Named wood fence places without a copper collision: "+Nodes.title(base))
	for i in 4:
		w.set_node(p,0)
		game.player.position = Vector3(p)+Vector3.ONE*0.5+Vector3(Barriers.SIDES[i])*4
		game.player.camera.look_at(game.player.camera.global_position+Vector3(Barriers.SIDES[i]))
		game.inventory.restore([]); game.inventory.add_item(5001,1)
		Barriers.try_place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE})
		t.check(Barriers.facing(w.node_at(p)) == (i+1)%4,"Gate placement uses the player's position for facing "+str(i))
	game.player.position = Vector3(p)+Vector3(5,0,5)
	w.set_node(p,5001)
	WindCharge.hits_node(game,Vector3(p),p)
	t.check(Barriers.open(w.node_at(p)) and int(w.circuits.state(p).get("gate_state",-1)) == 1,"A wind charge opens the gate and changes its saved source state")
	WindCharge.hits_node(game,Vector3(p),p)
	t.check(not Barriers.open(w.node_at(p)) and int(w.circuits.state(p).get("gate_state",-1)) == 0,"A second wind charge closes the gate")
	w.set_node(p,red); w.set_node(p+Vector3i.RIGHT,Nodes.STONE); w.set_node(p+Vector3i.LEFT,Nodes.STONE); w.set_node(p+Vector3i.UP,Nodes.STONE)
	var saved: int = w.node_at(p)
	t.check(kind(w,p) == "tall_flat" and saved != red,"Wall state occupies a persistent variant ID across a mapblock boundary")
	var gate: Vector3i = p+Vector3i.BACK*2
	w.set_node(gate,5001); Barriers.set_open(w,gate,true)
	t.check(game.save_game("user://barrier-registry-check.json"),"Barrier registry save writes")
	game.set_process(true); game.load_world_data(game.read_save("user://barrier-registry-check.json"))
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	t.check(game.world.node_at(p) == saved and kind(game.world,p) == "tall_flat","New wall material and height survive a real save/reload")
	t.check(Barriers.open(game.world.node_at(gate)) and int(game.world.circuits.state(gate).get("gate_state",-1)) == 1,"Gate geometry and source state survive save/reload")
