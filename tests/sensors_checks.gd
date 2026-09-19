extends RefCounted

static func ticks(world: VoxelWorld, count: int) -> void:
	for index in count: world.circuits.step(0.1)

static func held(game: Node3D, id: int) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":1,"wear":0}

static func run(t: SceneTree, game: Node3D) -> void:
	var wood_inv := Inventory.new()
	for species in 6:
		var slabs: Array = [BuildingShapes.slab_for(WoodTypes.PLANKS[species]),BuildingShapes.slab_for(WoodTypes.PLANKS[(species+1)%6])+1,BuildingShapes.slab_for(WoodTypes.PLANKS[(species+2)%6])]
		var guide_index: int = wood_inv.recipe_index(RedstoneSensors.DAYLIGHT)
		wood_inv.restore([]); wood_inv.add_item(Nodes.GLASS,3); wood_inv.add_item(Nodes.QUARTZ,3); wood_inv.add_item(slabs[0],3)
		t.check(guide_index >= 0 and wood_inv.fill_grid(guide_index,"table") and wood_inv.take_grid_result("table").get("id",0) == RedstoneSensors.DAYLIGHT,"generic daylight recipe guide fills and crafts species "+str(species))
		var pattern: Array = [Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ,slabs[0],slabs[1],slabs[2]]
		for index in 9: wood_inv.grid[index] = {"id":pattern[index],"count":1,"wear":0}
		var crafted: Dictionary = wood_inv.take_grid_result("table")
		t.check(crafted.get("id",0) == RedstoneSensors.DAYLIGHT and wood_inv.grid.all(func(slot): return slot.id == 0),"daylight detector wood_slab group accepts mixed species and upper slabs: "+str(species))
	for wrong in [BuildingShapes.slab_for(WoodTypes.PLANKS[1])+2,BuildingShapes.stair_for(WoodTypes.PLANKS[1]),BuildingShapes.slab_for(Nodes.STONE)]:
		var pattern: Array = [Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.QUARTZ,Nodes.QUARTZ,Nodes.QUARTZ,wrong,wrong,wrong]
		for index in 9: wood_inv.grid[index] = {"id":pattern[index],"count":1,"wear":0}
		t.check(RedstoneSensors.special_recipe(wood_inv.grid).is_empty(),"daylight detector rejects double slabs, stairs and nonwood material: "+str(wrong))
	var world: VoxelWorld = game.world
	var circuit: RedstoneCircuit = world.circuits
	var old: Dictionary = {"daylight":game.daylight,"position":game.player.position,"target":game.player.target,"state":game.state,"mode":game.gamemode,"touch":game.touch,"achievements":game.achievements.to_save(),"experience":game.experience}
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var old_sneak: bool = game.controls.sneak_held
	game.touch = true; game.controls.sneak_held = false
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1.0
	game.player.position = Vector3(2,476,2)
	for x in range(1,15):
		for z in range(1,15):
			for y in range(467,474): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var p := Vector3i(6,470,6)
	world.set_node(p,RedstoneSensors.DAYLIGHT)
	t.check(circuit.tracked.has(p) and circuit.output(p,Vector3i.RIGHT) == 15,"an exposed daylight detector registers and immediately emits fifteen power")
	var conversion: bool = true
	for level in range(15):
		var expected: int = clampi(floori((level-2)*15.0/12.0+0.5),0,15)
		conversion = conversion and RedstoneSensors.signal_strength(level) == expected and RedstoneSensors.signal_strength(level,true) == 15-expected
	t.check(conversion,"normal and inverted levels use the source's rounded 2-to-14 natural-light conversion")
	for i in range(1,3): world.set_node(p+Vector3i.RIGHT*i,Nodes.REDSTONE_WIRE)
	world.set_node(p+Vector3i.RIGHT*3,Nodes.REDSTONE_LAMP); ticks(world,1)
	t.check(circuit.output(p+Vector3i.RIGHT,Vector3i.RIGHT) == 15 and circuit.output(p+Vector3i.RIGHT*2,Vector3i.RIGHT) == 14 and circuit.state(p+Vector3i.RIGHT*3).powered,"detector power drives attenuated dust and a real redstone lamp")
	game.daylight = 0.05; ticks(world,9)
	t.check(circuit.output(p,Vector3i.RIGHT) == 0 and not circuit.state(p+Vector3i.RIGHT*3).powered,"detectors resample darkness once per source second and turn the circuit off")
	held(game,Nodes.APPLE); game.player.target = {"id":RedstoneSensors.DAYLIGHT,"pos":p,"normal":Vector3i.UP,"distance":4.0}
	game.player.use()
	t.check(world.node_at(p) == RedstoneSensors.INVERTED and circuit.output(p,Vector3i.RIGHT) == 15 and game.player.eating.is_empty() and game.inventory.held().id == Nodes.APPLE,"right-clicking with food toggles inversion before eating and preserves inventory")
	game.player.target.id = RedstoneSensors.INVERTED; game.controls.sneak_held = true
	t.check(not RedstoneSensors.use(game,game.player.target) and world.node_at(p) == RedstoneSensors.INVERTED,"touch sneak bypasses detector toggling")
	game.controls.sneak_held = false
	var observer: Vector3i = p+Vector3i.BACK
	world.set_node(observer,Nodes.OBSERVER); circuit.configure(observer,Vector3i.BACK)
	circuit.state(observer).pulse = 0.0; game.daylight = 1
	RedstoneSensors.sample(world,p,RedstoneSensors.INVERTED,circuit.state(p))
	t.check(circuit.state(observer).pulse == 0.2 and circuit.output(p,Vector3i.UP) == 0,"detector level changes notify an observing block and invert daytime output")
	world.set_node(observer,Nodes.AIR)
	for i in range(1,4): world.set_node(p+Vector3i.RIGHT*i,Nodes.AIR)
	world.set_node(p,RedstoneSensors.DAYLIGHT)
	world.set_node(p+Vector3i.UP,Nodes.STONE)
	t.check(RedstoneSensors.natural_light(world,p) == 13,"a small opaque roof admits weaker indirect skylight around its edge")
	world.set_node(p+Vector3i.UP,Nodes.GLASS)
	t.check(RedstoneSensors.natural_light(world,p) == 14,"a glass roof transmits natural light without artificial-light input")
	world.set_node(p+Vector3i.UP,Nodes.LEAVES)
	t.check(RedstoneSensors.natural_light(world,p) == 13,"leaves attenuate natural light")
	for x in range(-2,3):
		for y in range(-2,3):
			for z in range(-2,3):
				if maxi(absi(x),maxi(absi(y),absi(z))) == 2: world.set_node(p+Vector3i(x,y,z),Nodes.STONE)
	world.set_node(p+Vector3i.UP,Nodes.TORCH)
	t.check(RedstoneSensors.natural_light(world,p) == 0,"an enclosed detector ignores nearby torch light")
	for x in range(-2,3):
		for y in range(-2,3):
			for z in range(-2,3):
				if Vector3i(x,y,z) != Vector3i.ZERO: world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	var old_dimension: String = world.dimension; world.dimension = "nether"
	t.check(RedstoneSensors.natural_light(world,p) == 0,"dimensions without skylight provide no natural-light power")
	world.dimension = old_dimension
	t.check(not circuit.movable(p) and Nodes.fuel_time(RedstoneSensors.DAYLIGHT) == 15 and Nodes.drop(RedstoneSensors.INVERTED) == RedstoneSensors.DAYLIGHT,"daylight detectors are piston-immovable, usable as source fuel, and drop their normal form")
	t.check(world.intersects(Vector3(p)+Vector3(0.5,0.3,0.5)) and not world.intersects(Vector3(p)+Vector3(0.5,0.376,0.5)),"detector collision uses the source's three-eighth-block height")
	var selection: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
	t.check(not selection.is_empty() and is_equal_approx(selection.point.y,p.y+0.375),"detector raycasts use the same shallow selection box")
	world.set_node(p,Nodes.AIR)
	var target := Vector3i(10,470,10)
	world.set_node(target,RedstoneSensors.TARGET)
	var all_faces: bool = true
	for side in RedstoneSensors.SIDES:
		all_faces = all_faces and RedstoneSensors.hit_strength(target,Vector3(target)+Vector3.ONE*0.5+Vector3(side)*0.5) == 15
	t.check(all_faces and RedstoneSensors.hit_strength(target,Vector3(target)+Vector3(0,0.8,0.5)) == 8 and RedstoneSensors.hit_strength(target,Vector3(target)+Vector3(-0.001,1,0.5)) == 2 and RedstoneSensors.hit_strength(target,Vector3(target)+Vector3(0,1,1)) == 1,"target strength measures radial accuracy on all six faces with the source error margin")
	world.set_node(target+Vector3i.RIGHT,Nodes.REDSTONE_WIRE)
	world.set_node(target+Vector3i.RIGHT*2,Nodes.REDSTONE_LAMP)
	RedstoneSensors.hit(world,target,Vector3(target)+Vector3(0,0.8,0.5)); ticks(world,4)
	t.check(circuit.output(target,Vector3i.RIGHT) == 8 and circuit.state(target+Vector3i.RIGHT*2).powered,"an off-center target hit supplies its measured power to dust and a lamp")
	var before: float = circuit.state(target).target_remaining
	t.check(not RedstoneSensors.hit(world,target,Vector3(target)+Vector3(0,0.5,0.5)) and is_equal_approx(circuit.state(target).target_remaining,before) and circuit.state(target).out == 8,"a hit on an active target does not replace or extend its source pulse")
	ticks(world,5)
	t.check(world.node_at(target) == RedstoneSensors.TARGET_ON,"target remains active before the one-second boundary")
	ticks(world,1)
	t.check(world.node_at(target) == RedstoneSensors.TARGET and circuit.output(target,Vector3i.RIGHT) == 0 and not circuit.state(target+Vector3i.RIGHT*2).powered,"target pulse ends at one second and switches its connected circuit off")
	world.set_node(target+Vector3i.RIGHT,Nodes.STONE)
	RedstoneSensors.hit(world,target); ticks(world,1)
	t.check(circuit.output(target+Vector3i.RIGHT,Vector3i.RIGHT) == 0 and not circuit.state(target+Vector3i.RIGHT*2).powered,"target's weak output does not strongly power an intervening solid block")
	world.set_node(target+Vector3i.RIGHT,Nodes.AIR); world.set_node(target+Vector3i.RIGHT*2,Nodes.AIR)
	world.set_node(target,RedstoneSensors.TARGET)
	var arrow: Arrow = game.spawn_arrow(Vector3(target)+Vector3(-1,0.5,0.5),Vector3(30,0.6,0))
	arrow.from_player = true; arrow.set_physics_process(false); arrow._physics_process(0.05)
	t.check(arrow.stuck and world.node_at(target) == RedstoneSensors.TARGET_ON and circuit.state(target).out == 15,"a real arrow collision activates the target from its actual face impact")
	arrow.queue_free(); world.set_node(target,RedstoneSensors.TARGET)
	var trident := TridentProjectile.new(); trident.game = game; trident.consumed = false
	trident.stack = {"id":VillageContent.TRIDENT,"count":1,"wear":0,"data":{"enchantments":{"Loyalty":1}}}
	trident.position = Vector3(target)+Vector3(-1,0.8,0.5); trident.velocity = Vector3(30,0.6,0)
	game.entities.add_child(trident); trident.set_physics_process(false); trident._physics_process(0.05)
	t.check(trident.returning and world.node_at(target) == RedstoneSensors.TARGET_ON and circuit.state(target).out == 8,"a real trident hit keeps precision scoring and its normal Loyalty return behavior")
	trident.queue_free(); world.set_node(target,RedstoneSensors.TARGET)
	var potion := PotionProjectile.new(); potion.game = game; potion.item_id = PotionCatalog.find("water","splash")
	potion.position = Vector3(target)+Vector3(-1,0.8,0.5); potion.velocity = Vector3(30,0.6,0)
	game.entities.add_child(potion); potion.set_physics_process(false); potion._physics_process(0.05)
	t.check(potion.is_queued_for_deletion() and world.node_at(target) == RedstoneSensors.TARGET_ON and circuit.state(target).out == 15,"a thrown potion activates full target power and retains its impact behavior")
	world.set_node(target,RedstoneSensors.TARGET)
	var flame := MagicProjectile.new(); flame.game = game; flame.kind = "blaze"
	flame.position = Vector3(target)+Vector3(-1,0.8,0.5); flame.velocity = Vector3(30,0,0)
	game.entities.add_child(flame); flame.set_physics_process(false); flame._physics_process(0.05)
	t.check(flame.impacted and circuit.state(target).out == 15,"blaze projectile impacts activate targets with the source's non-precision power")
	world.set_node(target,RedstoneSensors.TARGET)
	game.achievements.unlocked.erase("bullseye"); game.achievements.counters.erase("bullseye")
	game.player.position = Vector3(target)+Vector3(30.5,3,0.5)
	RedstoneSensors.hit(world,target,Vector3(target)+Vector3(0,0.5,0.5),game.player)
	t.check(game.achievements.is_unlocked("bullseye"),"a player bullseye from thirty horizontal blocks awards the source achievement")
	game.player.position = Vector3(2,476,2)
	ticks(world,4)
	world.set_node(p,RedstoneSensors.INVERTED)
	var save_path: String = "/tmp/voxey-sensors-save-%d.json"%OS.get_process_id()
	t.check(game.save_game(save_path),"a world with active target and detector state saves successfully")
	var saved: Dictionary = game.read_save(save_path)
	var detector_key: String = VoxelWorld.station_key(p)
	world.block_states[detector_key] = saved.block_states[detector_key]
	circuit.register(p,world.node_at(p))
	t.check(world.node_at(p) == RedstoneSensors.INVERTED and circuit.state(p).out == 0 and circuit.state(p).sensor_light == 14,"saved detector inversion persists and its restored state resamples current daylight")
	var key: String = VoxelWorld.station_key(target)
	world.block_states[key] = saved.block_states[key]
	circuit.register(target,world.node_at(target))
	t.check(typeof(circuit.state(target).out) == TYPE_INT and is_equal_approx(circuit.state(target).target_remaining,0.6),"saved target pulse power and remaining time normalize after JSON reload")
	var column := Vector2i(floori(target.x/16.0),floori(target.z/16.0)); var loaded: Variant = world.columns[column]
	circuit.unload(column); world.columns.erase(column); ticks(world,20)
	t.check(is_equal_approx(circuit.state(target).target_remaining,0.6),"an unloaded target pauses its persisted pulse")
	world.columns[column] = loaded; circuit.register(target,world.node_at(target)); ticks(world,6)
	t.check(world.node_at(target) == RedstoneSensors.TARGET and circuit.state(target).out == 0,"a reloaded target completes only its saved remaining pulse")
	RedstoneSensors.hit(world,target); world.set_node(target,Nodes.STONE)
	t.check(not world.block_states.has(key) and not circuit.tracked.has(target),"replacing a target removes its timer and redstone source state")
	world.set_node(target,RedstoneSensors.TARGET)
	t.check(circuit.movable(target) and Nodes.drop(RedstoneSensors.TARGET_ON) == RedstoneSensors.TARGET,"target blocks remain movable and always drop their inactive form")
	RedstoneSensors.hit(world,target); ticks(world,2)
	circuit._move(target,target+Vector3i.UP)
	t.check(world.node_at(target+Vector3i.UP) == RedstoneSensors.TARGET_ON and is_equal_approx(circuit.state(target+Vector3i.UP).target_remaining,0.8),"piston movement preserves an active target's remaining pulse")
	ticks(world,8); world.set_node(target+Vector3i.UP,Nodes.AIR)
	var inv := Inventory.new()
	var detector_recipe: Dictionary = inv.recipes[inv.recipe_index(RedstoneSensors.DAYLIGHT)]
	var target_recipe: Dictionary = inv.recipes[inv.recipe_index(RedstoneSensors.TARGET)]
	t.check(detector_recipe.ingredients == {Nodes.GLASS:3,Nodes.QUARTZ:3,BuildingShapes.slab_for(Nodes.PLANKS):3} and target_recipe.ingredients == {Nodes.REDSTONE_WIRE:4,Nodes.HAY_BALE:1},"detector and target survival recipes match the source ingredients")
	for i in 9: inv.grid[i] = {"id":detector_recipe.pattern[i],"count":1,"wear":0}
	t.check(inv.take_grid_result("table").get("id",0) == RedstoneSensors.DAYLIGHT and inv.grid.all(func(slot): return slot.id == 0),"the detector recipe actually crafts and consumes all nine ingredients")
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8); RedstoneSensors.draw(image,RedstoneSensors.TARGET)
	var model: Node3D = RedstoneArt.build(RedstoneSensors.DAYLIGHT)
	t.check(model.get_child_count() >= 11 and image.get_pixel(8,8).a > 0,"detectors and targets expose real held/world models and inventory art")
	model.free()
	# A wide roof is the most expensive indirect-light search. Report both the
	# first bounded query and 1,000 repeated cached queries without a flaky
	# machine-specific timing assertion.
	var covered := Vector3i(-8,470,-8)
	for x in range(-15,16):
		for z in range(-15,16): world.set_node(covered+Vector3i(x,20,z),Nodes.STONE)
	var started: int = Time.get_ticks_usec()
	var roof_light: int = RedstoneSensors.natural_light(world,covered)
	var cold: int = Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	for index in 1000: RedstoneSensors.natural_light(world,covered)
	var warm: int = Time.get_ticks_usec()-started
	print("SENSOR LIGHT BENCH: wide-roof cold=%d us, cached1000=%d us"%[cold,warm])
	t.check(roof_light == 0,"bounded natural-light propagation cannot reach sky around a roof more than fourteen blocks wide")
	for x in range(-15,16):
		for z in range(-15,16): world.set_node(covered+Vector3i(x,20,z),Nodes.AIR)
	var high_roof := Vector3i(covered.x,WorldBounds.OVERWORLD_MAX-1,covered.z)
	world.set_node(high_roof,Nodes.STONE)
	# The opacity index must read loaded mapblocks, not depend on an edit list.
	world.edits.erase(high_roof); world.sky_revision += 1
	started = Time.get_ticks_usec()
	var high_roof_light: int = RedstoneSensors.natural_light(world,covered)
	var high_cost: int = Time.get_ticks_usec()-started
	print("SENSOR HEIGHT BENCH: roofY=%d, query=%d us"%[high_roof.y,high_cost])
	t.check(high_roof_light == 13,"a naturally loaded roof near build height attenuates a ground sensor without scanning implicit-air gaps")
	world.set_node(high_roof,Nodes.GLASS)
	t.check(RedstoneSensors.natural_light(world,covered) == 14,"replacing the high opaque roof with glass invalidates skylight geometry")
	world.set_node(high_roof,Nodes.LEAVES)
	t.check(RedstoneSensors.natural_light(world,covered) == 13,"sparse high-altitude leaves retain light attenuation")
	world.set_node(high_roof,Nodes.AIR)
	for point in [p,target]: world.set_node(point,Nodes.AIR)
	game.daylight = old.daylight; game.player.position = old.position; game.player.target = old.target
	game.state = old.state; game.gamemode = old.mode; game.touch = old.touch; game.experience = old.experience
	game.achievements.from_save(old.achievements)
	game.controls.sneak_held = old_sneak
	if temporary_controls: game.controls.queue_free(); game.controls = null
