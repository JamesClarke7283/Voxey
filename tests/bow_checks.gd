extends RefCounted

static func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

static func key(down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = KEY_Z; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

static func equip(game: Node3D, data: Dictionary = {}, ammo: int = Nodes.ARROW_ITEM) -> void:
	BowUse.cancel(game.player)
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Nodes.BOW,"count":1,"wear":0,"data":data.duplicate(true)}
	if ammo: game.inventory.slots[2] = {"id":ammo,"count":3,"wear":0}
	game.player.target = {}; game.player.health = 20; game.resume()
	game.player.use_cooldown = 0

static func run(t: SceneTree, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true); var old_selected: int = game.inventory.selected
	var old_mode: String = game.gamemode; var old_offhand: Dictionary = game.player.offhand_slot.duplicate(true)
	var old_position: Vector3 = game.player.position; var old_health: float = game.player.health
	var old_flying: bool = game.player.flying
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	if not is_instance_valid(game.controls):
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	game.gamemode = "survival"; game.player.position = Vector3(8,1700,8)
	game.player.offhand_slot = Bookshelves.empty()
	equip(game,{"custom_name":"Reed","enchantments":{"Unbreaking":2,"Power":5,"Punch":2,"Flame":1}})
	var entities_before: int = game.entities.get_child_count()
	game.player.use()
	t.check(BowUse.current_stage(game.player) == 0 and game.entities.get_child_count() == entities_before and game.inventory.slots[2].count == 3,"right-click draws a bow without spawning or spending an arrow")
	var start: int = game.player.bow_draw.start
	for elapsed in [0,199999,200000,499999,500000,2000000]:
		BowUse.update(game.player,true,false,start+elapsed)
		t.check(BowUse.current_stage(game.player) == BowUse.stage(elapsed),"bow pull stage follows source microsecond boundary %d"%elapsed)
		t.check(game.hud.hotbar[0].bow_stage == BowUse.stage(elapsed),"hotbar displays bow pull stage %d"%elapsed)
	var shot: Arrow = BowUse.release(game.player,start+500000,[0.5,0.5,0.5,0.5,0.5,0.5])
	t.check(shot != null and shot.from_player and shot.shooter_id == game.player.get_instance_id() and shot.critical and is_equal_approx(shot.velocity.length(),60),"full draw releases a critical source-speed arrow with shooter provenance")
	t.check(shot.position.is_equal_approx(game.player.camera.global_position-Vector3.UP*0.1) and shot.velocity.normalized().is_equal_approx(-game.player.camera.global_basis.z),"release uses eye position minus 0.1 and look direction without an upward bias")
	t.check(game.inventory.slots[2].count == 2 and Durability.normalized(game.inventory.held()) == 56 and game.inventory.held().data.custom_name == "Reed","shooting consumes one arrow and exact Unbreaking bow wear, preserving name and enchantments")
	t.check(shot.damage == 5 and shot.punch == 2 and shot.flame and shot.recoverable,"Power, Punch, Flame and pickup are passed to the actual arrow")
	t.check(BowUse.current_stage(game.player) == -1 and game.hud.hotbar[0].bow_stage == -1,"release clears hand and inventory pull visuals")
	shot.free()
	for elapsed in [0,125000,250000,499999,500000,2000000]:
		equip(game); BowUse.begin(game.player,100)
		shot = BowUse.release(game.player,100+elapsed,[0.5,0.5,0.5,0.5,0.5,0.5])
		t.check(is_equal_approx(shot.velocity.length(),minf(60,elapsed*60.0/500000)) and shot.critical == (elapsed >= 500000),"actual release has source charge speed and critical status at %d us"%elapsed)
		t.check(game.inventory.slots[2].count == 2 and Durability.normalized(game.inventory.held()) == 170,"every successful release including zero charge consumes ammunition and wear")
		shot.free()
	for creative in [false,true]:
		for infinity in [0,1]:
			for ammo in [0,Nodes.ARROW_ITEM,VillageContent.POISON_ARROW]:
				equip(game,{"enchantments":{"Infinity":infinity}},ammo); game.gamemode = "creative" if creative else "survival"
				var begun: bool = BowUse.begin(game.player,100)
				t.check(begun == (creative or ammo != 0),"bow drawing requires inventory ammunition even with Infinity, except creative")
				if not begun: continue
				shot = BowUse.release(game.player,500100)
				t.check(shot.item_id == (ammo if ammo else Nodes.ARROW_ITEM) and shot.recoverable == (infinity == 0),"regular, tipped and creative shots use source ammunition and pickup rules")
				if ammo: t.check(game.inventory.slots[2].count == (3 if creative or infinity > 0 and ammo == Nodes.ARROW_ITEM else 2),"Infinity preserves only ordinary arrows and creative consumes no ammo")
				t.check(Durability.normalized(game.inventory.held()) == (0 if creative else 170),"creative shooting skips bow wear")
				shot.free()
	game.gamemode = "survival"
	# First matching main-inventory slot wins; offhand ammunition is excluded.
	equip(game,{},0); game.player.offhand_slot = {"id":Nodes.ARROW_ITEM,"count":4,"wear":0}
	t.check(not BowUse.begin(game.player,100),"offhand arrows do not count toward the source main-inventory scan")
	game.inventory.slots[1] = {"id":VillageContent.POISON_ARROW,"count":2,"wear":0}
	game.inventory.slots[2] = {"id":Nodes.ARROW_ITEM,"count":2,"wear":0}
	BowUse.begin(game.player,100); shot = BowUse.release(game.player,500100)
	t.check(shot.item_id == VillageContent.POISON_ARROW and game.inventory.slots[1].count == 1 and game.inventory.slots[2].count == 2,"bow consumes the first matching inventory slot, retaining later arrows")
	shot.free()
	for kind in ["slot","replace","empty","menu","death","drop"]:
		equip(game); BowUse.begin(game.player,100)
		var held: Dictionary = game.inventory.held()
		match kind:
			"slot": game.inventory.selected = 1
			"replace": game.inventory.slots[0] = held.duplicate(true)
			"empty": held.count = 0
			"menu": game.open_inventory()
			"death": game.player.health = 0
			"drop": game.drop_stack(held)
		BowUse.update(game.player,false,false,500100)
		t.check(game.player.bow_draw.is_empty() and game.inventory.slots[2].count == 3,"%s cancels drawing without firing or spending ammunition"%kind)
	# Losing ammunition after beginning must not damage the bow on release.
	equip(game); BowUse.begin(game.player,100); game.inventory.slots[2] = Bookshelves.empty()
	t.check(BowUse.release(game.player,500100) == null and Durability.normalized(game.inventory.held()) == 0,"lost ammunition aborts release without bow wear")
	equip(game); BowUse.begin(game.player,100); game.pause()
	t.check(game.player.bow_draw.is_empty(),"pausing clears a pull immediately even with player processing disabled")
	equip(game)
	t.check(BowUse.update(game.player,false,true,100),"Z starts drawing directly")
	BowUse.update(game.player,false,true,500100); entities_before = game.entities.get_child_count()
	BowUse.update(game.player,false,false,500100)
	t.check(game.entities.get_child_count() == entities_before+1 and game.player.bow_draw.is_empty(),"releasing Z creates exactly one arrow")
	game.entities.get_children().back().free()
	equip(game); game.touch = false
	mouse(true); game.player._process(0.016)
	entities_before = game.entities.get_child_count()
	for i in 10: game.player._process(0.016)
	t.check(not game.player.bow_draw.is_empty() and game.inventory.slots[2].count == 3 and game.entities.get_child_count() == entities_before,"held desktop RMB keeps drawing without repeating shots")
	key(true); game.player._process(0.016); mouse(false); game.player._process(0.016)
	t.check(game.player.bow_draw.is_empty() and game.entities.get_child_count() == entities_before+1,"releasing RMB fires even while Z remains held, as in the source")
	key(false); game.player._process(0.016); game.entities.get_children().back().free()
	key(true); game.player._process(0.016); key(false); game.player._process(0.016)
	t.check(game.player.bow_draw.is_empty() and game.inventory.slots[2].count == 1,"desktop Z starts and releases its own shot")
	game.entities.get_children().back().free()
	mouse(true); game.player._process(0.016)
	t.check(not game.player.bow_draw.is_empty(),"a new click immediately starts another pull without the ordinary use cooldown")
	mouse(false); game.player._process(0.016); game.entities.get_children().back().free(); game.touch = true
	# The actual movement/FOV path must apply and remove the pull factors.
	equip(game); game.gamemode = "creative"; game.player.flying = true
	game.boats.reset(); game.survival.mount = null; game.controls.stick = Vector2(0,-1)
	BowUse.begin(game.player,100)
	for i in 12: game.player._physics_process(0.1)
	t.check(is_equal_approx(game.player.velocity.length(),12*BowUse.SPEED_FACTOR) and absf(game.player.camera.fov-78*BowUse.FOV_FACTOR) < 0.001,"drawing applies source movement and FOV factors through actual player physics")
	BowUse.cancel(game.player)
	for i in 12: game.player._physics_process(0.1)
	t.check(is_equal_approx(game.player.velocity.length(),12) and absf(game.player.camera.fov-78) < 0.001,"cancelling restores ordinary movement and FOV")
	game.controls.stick = Vector2.ZERO; game.player.flying = old_flying; game.gamemode = "survival"
	# Exercise the touch dispatch rather than calling the bow entry point.
	equip(game); game.controls.use_pressed = true; game.controls.use_held = true
	entities_before = game.entities.get_child_count(); game.player._process(0.016)
	t.check(not game.player.bow_draw.is_empty() and game.entities.get_child_count() == entities_before,"touch Use enters the same held-bow state through the actual player dispatcher")
	game.controls.use_held = false; game.player._process(0.016)
	t.check(game.player.bow_draw.is_empty() and game.entities.get_child_count() == entities_before+1,"releasing touch Use fires once through the actual player dispatcher")
	game.entities.get_children().back().free()
	# Existing interactables take priority on initial right-click.
	equip(game); var chest := Vector3i(8,1700,5); game.world.set_node(chest,Nodes.CHEST)
	game.player.target = {"id":Nodes.CHEST,"pos":chest,"normal":Vector3i.BACK,"distance":3.0}
	game.player.use()
	t.check(game.state == "inventory" and game.player.bow_draw.is_empty(),"aiming at a chest opens it instead of drawing the bow")
	game.world.set_node(chest,Nodes.AIR)
	# Distinct, cached meshes must reflect all three draw sprites.
	for i in 3:
		t.check(ItemArt.mesh(Nodes.BOW,i).get_surface_count() == 1 and ItemArt.texture(Nodes.BOW,i) == ItemArt.texture(Nodes.BOW,i),"bow draw stage %d has a cached visible mesh and texture"%i)
	t.check(ItemArt.texture(Nodes.BOW,0).get_image().get_data() != ItemArt.texture(Nodes.BOW,2).get_image().get_data(),"full draw changes the rendered string and arrow silhouette")
	game.pause(); game.inventory.slots = old_slots; game.inventory.selected = old_selected; game.player.offhand_slot = old_offhand
	game.gamemode = old_mode; game.player.position = old_position; game.player.health = old_health; game.player.flying = old_flying; game.player.target = {}
