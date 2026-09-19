extends RefCounted

# Focused regression for rails and minecarts: the engine shape table transcribed
# into GDScript, placement and support, powered propagation, detector and
# activator behaviour, the source cart physics, variants, and persistence.
# Fixtures use an isolated high plot so no check can disturb terrain.

static func plot(game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for x in range(-8,9):
		for z in range(-8,9):
			world.set_node(Vector3i(p.x+x,p.y-1,p.z+z),Nodes.STONE)
			for y in range(5): world.set_node(Vector3i(p.x+x,p.y+y,p.z+z),Nodes.AIR)

# Lay a straight line of plain rail along +X.
static func line(world: VoxelWorld, from: Vector3i, length: int) -> void:
	for i in length: world.set_node(from+Vector3i(i,0,0),Rails.RAIL_BASE)

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# Vertex count of the real chunk mesh for one column: this is the path rails
# actually render through, because they are not cube faces.
static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0

# One flat step, reporting the signed acceleration the source formula produced so
# fuel and rail modifiers compare directly.
static func accel_of(cart: MinecartEntity) -> float:
	cart.old_direction = Vector3.ZERO; cart.old_switch = 0
	cart.last_cell = Vector3i(0,2147483647,0)
	cart.velocity = Vector3(1,0,0)
	cart._move_step(0.05)
	return cart.acceleration.x

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(game,ground)
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,-6.5)
	game.rails.reset()
	clear_drops(game)
	await t.process_frame

	# --- registry ----------------------------------------------------------
	t.check(Rails.RAIL_IDS.size() == 7 and Rails.is_rail(Rails.RAIL_BASE) and Rails.is_rail(Rails.POWERED_ON),"the seven source rail nodes are registered")
	t.check(Rails.CART_IDS.size() == 5 and Rails.is_cart(Rails.CART) and Rails.is_cart(Rails.TNT_CART),"the five source cart items are registered")
	t.check(Nodes.max_stack(Rails.CART) == 1 and Nodes.max_stack(Rails.RAIL_BASE) == 64,"carts stack singly and rails stack to 64")
	t.check(is_equal_approx(Nodes.hardness(Rails.RAIL_BASE),0.7),"rail hardness matches the source 0.7")
	t.check(not Nodes.solid(Rails.RAIL_BASE) and Nodes.harvestable(Rails.RAIL_BASE,0),"rails are a non-solid plate and drop by hand")
	t.check(Nodes.drop(Rails.POWERED_ON) == Rails.POWERED and Nodes.pick_item(Rails.POWERED_ON) == Rails.POWERED,"a powered rail breaks into its unpowered item")
	t.check(Nodes.drop(Rails.DETECTOR_ON) == Rails.DETECTOR and Nodes.drop(Rails.ACTIVATOR_ON) == Rails.ACTIVATOR,"detector and activator rails break into their off items")
	t.check(Rails.same_family(Rails.POWERED,Rails.POWERED_ON) and not Rails.same_family(Rails.POWERED,Rails.DETECTOR),"each powered rail pair is one family and separate from the others")

	# --- the engine shape table --------------------------------------------
	# A lone rail has no neighbours.
	plot(game,ground)
	world.set_node(ground,Rails.RAIL_BASE)
	t.check(Rails.shape_code(world,ground) == 0 and Rails.resolved_shape(world,ground) == 0,"an isolated rail resolves to a straight shape")
	# A line along +X sets bits 2 and 3 of the engine's +Z,-Z,-X,+X code.
	line(world,ground-Vector3i(1,0,0),3)
	t.check(Rails.shape_code(world,ground) == 12 and Rails.resolved_shape(world,ground) == Rails.SHAPES[12][0],"a rail with neighbours on both X sides reports the engine code 12")
	t.check(Rails.resolved_shape(world,ground) == 0 and int(Rails.SHAPES[12][1]) == 90,"code 12 is the engine's straight-with-90-degrees entry")
	# A corner: neighbours at +X (bit 3) and +Z (bit 0).
	plot(game,ground)
	world.set_node(ground,Rails.RAIL_BASE)
	world.set_node(ground+Vector3i(1,0,0),Rails.RAIL_BASE)
	world.set_node(ground+Vector3i(0,0,1),Rails.RAIL_BASE)
	t.check(Rails.shape_code(world,ground) == 1+8 and Rails.resolved_shape(world,ground) == 1,"a corner resolves to a curved shape, as the engine table says")
	# A T junction: three neighbours.
	world.set_node(ground+Vector3i(-1,0,0),Rails.RAIL_BASE)
	t.check(Rails.shape_code(world,ground) == 1+4+8 and Rails.resolved_shape(world,ground) == 2,"three neighbours resolve to a junction")
	# A cross: all four.
	world.set_node(ground+Vector3i(0,0,-1),Rails.RAIL_BASE)
	t.check(Rails.shape_code(world,ground) == 15 and Rails.resolved_shape(world,ground) == 3,"all four neighbours resolve to a crossing")
	# Every one of the sixteen codes is covered by the transcribed engine table.
	t.check(Rails.SHAPES.size() == 16 and Rails.SHAPES[15][0] == Rails.CROSS and Rails.SHAPES[3][0] == Rails.STRAIGHT,"all sixteen neighbour codes map to the engine table")
	# Slope: a rail one block above a horizontal neighbour.
	plot(game,ground)
	world.set_node(ground,Rails.RAIL_BASE)
	world.set_node(ground+Vector3i(1,0,0),Nodes.STONE)
	world.set_node(ground+Vector3i(1,1,0),Rails.RAIL_BASE)
	var slope: Dictionary = Rails.slope(world,ground)
	t.check(slope.sloped and int(slope.angle) == Rails.SLOPE_ANGLES[3] and Vector3i(slope.dir) == Vector3i(1,0,0),"a rail above a +X neighbour is sloped with the engine's -90 angle")
	t.check(Rails.resolved_shape(world,ground) == Rails.STRAIGHT,"a sloped rail always meshes as straight, as the engine does")

	# --- placement and support ---------------------------------------------
	plot(game,ground)
	game.inventory.restore([]); game.inventory.add_item(Rails.RAIL_BASE,4); game.inventory.selected = 0
	var target: Dictionary = {"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)}
	Rails.try_place(game,target)
	t.check(world.node_at(ground) == Rails.RAIL_BASE and game.inventory.count_item(Rails.RAIL_BASE) == 3,"placing a rail consumes one item and stores the plain node")
	# A rail needs support below.
	t.check(not Rails.supported(world,ground+Vector3i(2,3,2),true) and not Rails.supported(world,ground+Vector3i(2,3,2)),"a rail with no support cannot be placed")
	# A rail may rest on the rail below it, which is what makes a slope legal.
	t.check(Rails.supported(world,ground+Vector3i(1,1,0),true) or Rails.supported(world,ground+Vector3i(0,1,0),true),"an upper rail can rest on the rail below")
	# Removing the support drops the rail.
	world.set_node(ground+Vector3i(1,0,0),Rails.RAIL_BASE)
	world.set_node(ground+Vector3i(1,-1,0),Nodes.AIR)
	Rails.support_changed(world,ground+Vector3i(1,-1,0))
	t.check(world.node_at(ground+Vector3i(1,0,0)) == Nodes.AIR and drops_of(game,Rails.RAIL_BASE) > 0,"a rail loses support, breaks and drops its item")
	clear_drops(game)

	# --- powered rails -----------------------------------------------------
	plot(game,ground)
	line(world,ground,4)
	world.set_node(ground+Vector3i(1,0,0),Rails.POWERED)
	world.set_node(ground+Vector3i(2,0,0),Rails.POWERED)
	world.set_node(ground+Vector3i(1,0,1),Nodes.REDSTONE_BLOCK)
	world.circuits.register(ground+Vector3i(1,0,1),Nodes.REDSTONE_BLOCK)
	world.circuits.step(0.1)
	t.check(world.circuits.input_power(ground+Vector3i(1,0,0)) > 0,"a neighbouring redstone block powers the rail cell")
	var power: int = Rails.rail_power(world,ground+Vector3i(1,0,0))
	t.check(power == Rails.RAIL_POWER,"a directly powered golden rail stores the source level 8")
	t.check(Rails.rail_power(world,ground+Vector3i(2,0,0)) == Rails.RAIL_POWER-1,"a golden rail one step from the source stores one less")
	var state: Dictionary = world.circuits.state(ground+Vector3i(1,0,0))
	Rails.tick(world,ground+Vector3i(1,0,0),world.node_at(ground+Vector3i(1,0,0)),state,0.1)
	t.check(world.node_at(ground+Vector3i(1,0,0)) == Rails.POWERED_ON,"a powered rail switches to its on state")
	t.check(Rails.output(Rails.POWERED_ON,state,Vector3i.UP) == Rails.RAIL_POWER,"a powered rail emits its stored level")
	t.check(Rails.output(Rails.DETECTOR_ON,state,Vector3i.DOWN) == 15 and Rails.output(Rails.DETECTOR_ON,state,Vector3i.UP) == 0,"an on detector rail strongly powers only the block below it")
	# A source-free rail is the brake variant and holds no power.
	t.check(Rails.rail_power(world,ground+Vector3i(3,0,0)) == 0,"a plain rail, and a golden rail out of reach, hold no power")
	# Removing the source turns it off again.
	world.set_node(ground+Vector3i(1,0,1),Nodes.AIR)
	world.circuits.register(ground+Vector3i(1,0,1),Nodes.AIR)
	world.circuits.step(0.1)
	state = world.circuits.state(ground+Vector3i(1,0,0))
	Rails.tick(world,ground+Vector3i(1,0,0),world.node_at(ground+Vector3i(1,0,0)),state,0.1)
	t.check(world.node_at(ground+Vector3i(1,0,0)) == Rails.POWERED and state.out == 0,"losing its source turns the powered rail off")

	# --- carts -------------------------------------------------------------
	plot(game,ground)
	line(world,ground,6)
	var cart: MinecartEntity = game.rails.spawn(Rails.CART,Vector3(ground))
	await t.process_frame
	t.check(cart != null and game.rails.active.size() == 1,"a cart can be spawned onto a rail")
	t.check(not cart.removed and cart.velocity.length() < 0.01,"a freshly placed cart is at rest")
	t.check(Vector3i(roundi(cart.position.x),roundi(cart.position.y),roundi(cart.position.z)) == ground and Rails.is_rail(world.node_at(ground)),"a cart spawned at a rail cell rounds onto that rail")
	# Punching applies the source's three-unit factor.
	cart.punch(Vector3(1,0,0),Rails.PUNCH_MAX)
	t.check(is_equal_approx(cart.velocity.x,Rails.PUNCH_MAX),"a punch applies the source's three-unit factor")
	# Friction slows it toward zero and the per-axis clamp holds.
	cart.velocity = Vector3(Rails.SPEED_MAX*2,0,0)
	cart.old_direction = Vector3.ZERO; cart.last_cell = Vector3i(0,2147483647,0)
	cart._move_step(0.05)
	t.check(absf(cart.velocity.x) <= Rails.SPEED_MAX+0.001,"the per-axis speed never exceeds the source ten")
	# A cart that leaves its rail rolls to a stop rather than being dropped.
	cart.position = Vector3(ground)+Vector3(3.5,4.0,0.5)
	cart.velocity = Vector3(4,0,0)
	cart.old_direction = Vector3.ZERO; cart.last_cell = Vector3i(0,2147483647,0)
	var before_drops: int = drops_of(game,Rails.CART)
	for i in 20: cart._move_step(0.05)
	t.check(not cart.removed and drops_of(game,Rails.CART) == before_drops,"a cart off its rail rolls to a stop and is never dropped, as the source comments say")
	clear_drops(game)
	game.rails.reset()
	await t.process_frame
	# A chest cart keeps cargo.
	plot(game,ground); line(world,ground,6)
	var chest: MinecartEntity = game.rails.spawn(Rails.CHEST_CART,Vector3(ground))
	await t.process_frame
	t.check(game.rails.cargo(chest).size() == Rails.CHEST_CART_SLOTS,"a chest cart exposes the source 27 cargo slots")
	t.check(int(game.rails.cargo(chest)[0].id) == 0,"cargo starts empty")
	# A hopper cart exposes five slots and collects a dropped item.
	var hopper: MinecartEntity = game.rails.spawn(Rails.HOPPER_CART,Vector3(ground)+Vector3(2,0,0))
	await t.process_frame
	t.check(game.rails.cargo(hopper).size() == Rails.HOPPER_CART_SLOTS,"a hopper cart exposes the source five slots")
	game.spawn_drop(hopper.position+Vector3.UP*0.6,Nodes.IRON,1)
	await t.process_frame
	game.rails._collect(hopper)
	var collected: int = 0
	for slot in game.rails.cargo(hopper):
		if int(slot.id) == Nodes.IRON: collected += int(slot.count)
	t.check(collected == 1,"a hopper cart collects a nearby dropped item into its own slots")
	clear_drops(game)
	# The furnace cart accepts coal and burns for the source 180 seconds.
	var furnace: MinecartEntity = game.rails.spawn(Rails.FURNACE_CART,Vector3(ground)+Vector3(3,0,0))
	await t.process_frame
	game.inventory.restore([]); game.inventory.add_item(Nodes.COAL,2); game.inventory.selected = 0
	var furnace_at: Vector3i = Vector3i(floori(furnace.position.x),floori(furnace.position.y),floori(furnace.position.z))
	t.check(game.rails.use(game,{"pos":furnace_at,"normal":Vector3i.UP,"id":Rails.RAIL_BASE,"distance":1.0,"point":furnace.position}),"using a furnace cart is handled")
	t.check(is_equal_approx(furnace.fuel,Rails.FUEL_SECONDS) and game.inventory.count_item(Nodes.COAL) == 1,"feeding a furnace cart adds the source 180 seconds and consumes one coal")
	# Fuel, then the two rail modifiers, measured against the plain rail value.
	game.rails.reset()
	await t.process_frame
	var reference: MinecartEntity = game.rails.spawn(Rails.CART,Vector3(ground))
	await t.process_frame
	t.check(world.node_at(ground) == Rails.RAIL_BASE,"the acceleration reference stands on a plain rail")
	var plain_accel: float = accel_of(reference)
	t.check(plain_accel < 0.0 and is_equal_approx(plain_accel,-Rails.FRICTION),"a plain rail decelerates by the source friction 0.4")
	reference.fuel = 100.0
	t.check(is_equal_approx(accel_of(reference)-plain_accel,Rails.FUEL_BOOST),"furnace fuel adds the source 0.6 to the acceleration")
	reference.fuel = 0.0
	world.set_node(ground,Rails.POWERED_ON)
	t.check(is_equal_approx(accel_of(reference)-plain_accel,Rails.POWERED_ACCELERATE+Rails.FRICTION),"a powered rail accelerates by the source +4 plus its replaced friction")
	world.set_node(ground,Rails.POWERED)
	t.check(is_equal_approx(accel_of(reference)-plain_accel,Rails.POWERED_BRAKE+Rails.FRICTION),"an unpowered golden rail brakes by the source -3 plus its replaced friction")
	# A TNT cart explodes on its fuse and drops nothing.
	plot(game,ground); line(world,ground,3)
	game.rails.reset()
	await t.process_frame
	var tnt: MinecartEntity = game.rails.spawn(Rails.TNT_CART,Vector3(ground))
	await t.process_frame
	t.check(tnt.kind == Rails.TNT_CART and tnt.fuse < 0.0,"a fresh TNT cart is not ignited")
	tnt.ignite(Rails.TNT_FUSE)
	t.check(tnt.fuse > 0.0,"igniting a TNT cart starts its fuse")
	clear_drops(game)
	tnt.step(Rails.TNT_FUSE+0.1)
	t.check(tnt.removed,"an exploded TNT cart is marked removed immediately")
	await t.process_frame
	t.check(not is_instance_valid(tnt) and drops_of(game,Rails.TNT_CART) == 0,"an exploded TNT cart is destroyed without dropping itself")
	clear_drops(game)
	game.rails.reset()

	# --- detector and activator --------------------------------------------
	plot(game,ground)
	line(world,ground,4)
	var dc: MinecartEntity = game.rails.spawn(Rails.CART,Vector3(ground)+Vector3(1,0,0))
	await t.process_frame
	# A detector rail switches on under a cart as it enters the cell. A cart
	# rounds with the source's floor(x+0.5), so 0.4 keeps it inside the cell.
	world.set_node(ground,Rails.DETECTOR)
	dc.position = Vector3(ground)+Vector3(0.4,0.0,0.4)
	dc.velocity = Vector3(1,0,0)
	dc.old_direction = Vector3.ZERO; dc.last_cell = Vector3i(0,2147483647,0)
	dc._move_step(0.05)
	t.check(game.rails.cart_on(ground),"the detector rail sees the cart standing on it")
	var det_state: Dictionary = world.circuits.state(ground)
	Rails.tick(world,ground,world.node_at(ground),det_state,0.1)
	t.check(world.node_at(ground) == Rails.DETECTOR_ON and det_state.out == 15,"a detector rail under a cart turns on and signals 15")
	# Moving the cart off turns it back off: the source swaps the rail it just
	# left, which is the cell remembered from the previous step.
	dc.position = Vector3(ground)+Vector3(2.4,0.0,0.4)
	dc.velocity = Vector3.ZERO
	dc.last_cell = ground; dc.old_direction = Vector3.ZERO
	dc._move_step(0.05)
	t.check(world.node_at(ground) == Rails.DETECTOR,"the detector rail turns off when the cart leaves it")
	# An activator rail ejects a plain cart's driver and ignites a TNT cart.
	plot(game,ground); line(world,ground,3)
	game.rails.reset()
	await t.process_frame
	var rider_cart: MinecartEntity = game.rails.spawn(Rails.CART,Vector3(ground)+Vector3(1,0,0))
	await t.process_frame
	game.rails.riding = rider_cart
	rider_cart.rider = true
	game.rails.activate_at(Vector3i(roundi(rider_cart.position.x),roundi(rider_cart.position.y),roundi(rider_cart.position.z)))
	t.check(not rider_cart.rider and not game.rails.ridden(),"an activator rail ejects a plain minecart's driver")
	var tnt_cart: MinecartEntity = game.rails.spawn(Rails.TNT_CART,Vector3(ground))
	await t.process_frame
	game.rails.activate_at(ground)
	t.check(tnt_cart.fuse > 0.0 and is_equal_approx(tnt_cart.fuse,Rails.ACTIVATOR_TNT_FUSE),"an activator rail ignites a TNT cart with the source two-second fuse")
	game.rails.reset()
	await t.process_frame

	# --- persistence -------------------------------------------------------
	plot(game,ground); line(world,ground,4)
	var saved_cart: MinecartEntity = game.rails.spawn(Rails.CHEST_CART,Vector3(ground)+Vector3(1,0,0))
	await t.process_frame
	var cart_key: String = saved_cart.key
	game.rails.cargo(saved_cart)[0] = {"id":Nodes.DIAMOND,"count":3,"wear":0}
	game.rails.cargo(saved_cart)[4] = {"id":Nodes.IRON,"count":7,"wear":0}
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,-2.5)
	t.check(game.save_game("user://rail_check.json"),"a world with a cart saves to disk")
	var saved: Dictionary = game.read_save("user://rail_check.json")
	game.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	world = game.world
	var restored: MinecartEntity = game.rails.active.get(cart_key)
	t.check(restored != null and restored.kind == Rails.CHEST_CART,"a placed cart survives a real save reload")
	if restored != null:
		var cargo: Array = game.rails.cargo(restored)
		t.check(cargo.size() == Rails.CHEST_CART_SLOTS and int(cargo[0].id) == Nodes.DIAMOND and int(cargo[0].count) == 3 and int(cargo[4].id) == Nodes.IRON,"a chest cart's cargo survives a real reload in its own slots")
	else:
		t.check(false,"the restored cart exists so its cargo can be checked")
	# A cart in an unloaded column keeps its record and leaves only the live index.
	var column := Vector2i(floori(restored.position.x/16.0),floori(restored.position.z/16.0))
	game.rails.unload(column)
	t.check(game.rails.active.is_empty() and game.rails.records().has(cart_key),"unloading a column drops the live cart but keeps its record")
	# Coming back into range wakes the same cart with its cargo intact.
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,-2.5)
	game.rails.wake_near()
	var woken: MinecartEntity = game.rails.active.get(cart_key)
	t.check(woken != null and int(game.rails.cargo(woken)[0].id) == Nodes.DIAMOND,"a cart wakes with its cargo when its column reloads")
	game.rails.reset()

	# --- art and recipes ---------------------------------------------------
	# Rails are not cubes and have no node visual: they live in the chunk mesh,
	# so the mesher itself must emit geometry for them.
	plot(game,ground)
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	var baseline: int = chunk_verts(world,coord)
	world.set_node(ground,Rails.RAIL_BASE)
	var straight: int = chunk_verts(world,coord)
	t.check(straight > baseline,"the chunk mesher emits geometry for a plain rail")
	# A crossing must carry more geometry than a straight piece.
	for dir in [Vector3i(1,0,0),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i(0,0,1)]: world.set_node(ground+dir,Rails.RAIL_BASE)
	var cross: int = chunk_verts(world,coord)
	t.check(cross > straight and Rails.shape_code(world,ground) == 15 and Rails.resolved_shape(world,ground) == Rails.CROSS,"a crossing meshes as more geometry than a straight rail")
	# A slope tilts the plate rather than adding a second axis.
	plot(game,ground)
	world.set_node(ground,Rails.RAIL_BASE)
	t.check(not Rails.slope(world,ground).sloped,"a flat rail is not sloped")
	world.set_node(ground+Vector3i(1,0,0),Nodes.STONE)
	world.set_node(ground+Vector3i(1,1,0),Rails.RAIL_BASE)
	t.check(Rails.slope(world,ground).sloped,"a rail above a supported neighbour is sloped")
	t.check(game.node_mesh(Rails.RAIL_BASE).get_surface_count() != 0 and game.node_mesh(Rails.POWERED_ON).get_surface_count() != 0,"rail icons build a non-empty node mesh")
	plot(game,ground)
	t.check(chunk_verts(world,coord) == baseline,"clearing the plot removes every rail from the chunk mesh")
	t.check(not Rails.icon_faces(Rails.RAIL_BASE).is_empty() and not Rails.icon_faces(Rails.CART).is_empty(),"rails and carts produce inventory icons")
	t.check(Rails.pixel(Rails.RAIL_BASE,2,8,Color.WHITE) != Rails.pixel(Rails.POWERED,2,8,Color.WHITE),"powered rails render a distinct metal texture")
	var inv := Inventory.new()
	t.check(inv.recipe_index(Rails.RAIL_BASE) >= 0 and inv.recipes[inv.recipe_index(Rails.RAIL_BASE)].count == 16,"sixteen rails per source recipe")
	t.check(inv.recipe_index(Rails.POWERED) >= 0 and inv.recipes[inv.recipe_index(Rails.POWERED)].count == 6,"six powered rails per source recipe")
	t.check(inv.recipe_index(Rails.CART) >= 0 and inv.recipes[inv.recipe_index(Rails.CART)].ingredients.get(Nodes.IRON,0) == 5,"a minecart takes five iron ingots")
	for cart_id in [Rails.CHEST_CART,Rails.FURNACE_CART,Rails.HOPPER_CART,Rails.TNT_CART]:
		t.check(inv.recipe_index(cart_id) >= 0 and inv.recipes[inv.recipe_index(cart_id)].ingredients.has(Rails.CART),"cart variant "+Nodes.title(cart_id)+" is built from a plain minecart")

	for x in range(-8,9):
		for z in range(-8,9):
			for y in range(5): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)
