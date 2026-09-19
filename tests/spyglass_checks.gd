extends RefCounted

static func mouse(down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

static func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

static func frame(game: Node3D) -> void: game.player._process(0.016)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.boats.reset(); game.survival.mount = null
	game.gamemode = "survival"; game.touch = false
	var player: VoxeyPlayer = game.player
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Spyglass.ID,"count":1,"wear":0,"data":{"custom_name":"Far sight"}}
	player.position = Vector3(8.5,1600,8.5); player.rotation = Vector3.ZERO; player.camera.rotation = Vector3.ZERO; player.health = 20
	for x in range(6,11):
		for z in range(2,11):
			game.world.set_node(Vector3i(x,1599,z),Nodes.STONE)
			for y in range(1600,1604): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.state = "playing"; game.hud.show_game()
	t.check(Nodes.exists(Spyglass.ID) and not Nodes.placeable(Spyglass.ID) and Nodes.max_stack(Spyglass.ID) == 1 and Nodes.durability(Spyglass.ID) == 0,"spyglass is a nonconsumable unstackable survival item")
	var inv := Inventory.new(); inv.add_item(7705,1); inv.add_item(Nodes.COPPER,2)
	var recipe: int = inv.recipe_index(Spyglass.ID)
	t.check(recipe >= 0 and inv.fill_grid(recipe,"table") and inv.take_grid_result("table").get("id",0) == Spyglass.ID,"one amethyst shard above two copper ingots crafts a spyglass")
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8); img.fill(Color.TRANSPARENT); Spyglass.draw(img)
	t.check(img.get_pixel(12,2).a > 0 and img.get_pixel(0,0).a == 0,"spyglass icon has a visible lens and transparent background")
	var mask: Image = PumpkinHelmet.texture().get_image()
	t.check(mask.get_pixel(16,25).a == 0 and mask.get_pixel(46,25).a == 0 and mask.get_pixel(32,48).a == 0 and mask.get_pixel(32,32).a > 0.9,"pumpkin overlay has both clear eye openings, a clear mouth and an opaque frame at its full64-pixel resolution")
	mouse(true); frame(game)
	t.check(player.scoping and is_equal_approx(player.camera.fov,8.0) and not player.hand.visible,"actual held right click gives source absolute8-degree scope and hides the held item")
	key(KEY_Z,true); frame(game); mouse(false); frame(game)
	t.check(player.scoping,"releasing right click retains scope while the zoom key remains held")
	key(KEY_Z,false); frame(game)
	t.check(not player.scoping and is_equal_approx(player.camera.fov,78.0) and player.hand.visible,"releasing both controls restores the normal view and held item")
	key(KEY_Z,true); frame(game)
	t.check(player.scoping,"actual zoom key activates the held spyglass without a block interaction")
	key(KEY_SHIFT,true); key(KEY_W,true); player._physics_process(0.05)
	t.check(is_equal_approx(player.camera.fov,8.0),"sprint FOV cannot override an active spyglass")
	key(KEY_SHIFT,false); key(KEY_W,false); key(KEY_Z,false); frame(game)
	# Node callbacks consume the initial click and block the scope for that hold.
	player.position = Vector3(8.5,1600,8.5); player.camera.position.y = 1.62
	var chest := Vector3i(8,1601,5); game.world.set_node(chest,Nodes.CHEST)
	mouse(true); frame(game)
	t.check(game.state == "inventory" and not player.scoping,"holding a spyglass still opens a targeted chest before considering zoom")
	mouse(false); game.state = "playing"; game.hud.show_game(); frame(game)
	key(KEY_CTRL,true); mouse(true); frame(game)
	t.check(game.playing() and player.scoping,"sneak bypasses the chest action and allows spying at its face")
	key(KEY_CTRL,false); mouse(false); frame(game)
	game.world.set_node(chest+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(chest,Nodes.LEVER); mouse(true); frame(game)
	var first: bool = bool(game.world.circuits.state(chest).get("on",false))
	for i in 30: frame(game)
	t.check(first and not player.scoping and bool(game.world.circuits.state(chest).get("on",false)) == first,"an interactive block suppresses scope and never repeats while the same click is held")
	game.world.set_node(chest,Nodes.AIR); frame(game)
	t.check(not player.scoping,"looking away after a consumed click does not start zoom until a fresh use")
	mouse(false); frame(game); mouse(true); frame(game)
	t.check(player.scoping,"a fresh use on air restores scope after an interactive block consumed the prior click")
	game.inventory.selected = 1; frame(game)
	t.check(not player.scoping and player.hand.visible and is_equal_approx(player.camera.fov,78.0),"changing hotbar slots immediately cancels scope")
	mouse(false); frame(game); game.inventory.selected = 0; key(KEY_Z,true); frame(game); game.pause(); frame(game)
	t.check(not player.scoping and player.hand.visible,"opening a menu cancels scope even while the zoom key is held")
	game.state = "playing"; frame(game); player.health = 0; frame(game)
	t.check(not player.scoping,"death cancels scope")
	player.health = 20; key(KEY_Z,false); mouse(false); frame(game)
	t.check(game.inventory.slots[0].id == Spyglass.ID and game.inventory.slots[0].count == 1 and game.inventory.slots[0].wear == 0 and game.inventory.slots[0].data.custom_name == "Far sight","all scope and interaction paths preserve the spyglass count, wear and name")
	game.touch = true
	if not is_instance_valid(game.controls):
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	game.controls.use_held = true; frame(game)
	t.check(player.scoping,"touch Use hold activates the same spyglass behavior")
	game.controls.use_held = false; frame(game)
	t.check(not player.scoping,"releasing touch Use restores the view")
	game.pause(); Spyglass.reset(player)
