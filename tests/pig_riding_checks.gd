extends RefCounted

# Pig riding (mobs_mc/pig.lua + mcl_mobs/mount.lua, GPL-3.0-or-later): the two
# steering items, the saddle and its mount rule, and the source's driven step with
# its `hog_boost` window.
const STICK = PigRiding.CARROT_ON_A_STICK
const FUNGUS = PigRiding.WARPED_FUNGUS_ON_A_STICK

# A floating grass platform, far above the terrain so the fixture leaves the
# generated world untouched. Returns the cells so the caller can clear them.
static func platform(world: VoxelWorld, y: int) -> Array:
	var cells: Array = []
	for x in range(3,20):
		for z in range(3,20):
			cells.append(Vector3i(x,y,z))
			world.set_node(Vector3i(x,y,z),Nodes.GRASS)
	return cells

# A pig held in the standstill a live test wants, as `farming_checks` does it. A
# `RuralAnimal` is built directly rather than through `spawn_creature` so this
# module is exercised without the parent's `game.gd` wiring (see PARENT WIRING 3).
static func pig(game: Node3D, pos: Vector3) -> RuralAnimal:
	var animal := RuralAnimal.new()
	animal.game = game; animal.kind = "pig"; animal.position = pos
	game.creatures.add_child(animal)
	animal.set_physics_process(false); animal.think = 100; animal.direction = Vector3.ZERO; animal.ambient = 100
	# The mob is placed and then never stepped, so its cached global transform would
	# otherwise stay at the origin and `center()` would report the wrong point.
	animal.force_update_transform()
	animal.model.force_update_transform()
	return animal

static func hold(game: Node3D, id: int, wear: int = 0) -> void:
	game.inventory.slots[0] = {"id":id,"count":1,"wear":wear}
	game.inventory.selected = 0

# The live right-click the `farming_checks` suite uses: a press and a release at the
# centre of the viewport, flushed into one player step.
static func use_right_click(game: Node3D) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
		event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
		Input.parse_input_event(event); Input.flush_buffered_events()
		game.player._process(0.016)

static func run(suite: Object, game: Node3D) -> void:
	# A preceding group may have called `load_world_data`, which **replaces** the
	# world node (`game._replace_world`); a reference captured once would then be a
	# freed object and every write through it would go nowhere. Re-read it here.
	var world: VoxelWorld = game.world
	var saved_position: Vector3 = game.player.position
	var saved_state: String = game.state
	# `_recipe` compares ids and cannot express a group, so the two recipes are
	# exact rows: the source's shaped fishing-rod-plus-head, one of whose two
	# mirrored variants `matching_recipe` already accepts on its own.
	var entries: Array = PigRiding.recipe_entries()
	var rows: Dictionary = {}
	for entry in entries: rows[int(entry[1])] = entry[3]
	for entry in entries:
		suite.check(entry[0] == Nodes.title(int(entry[1])),"the recipe is labelled with the item's own title: "+str(entry[0]))
	suite.check(rows.get(STICK,[]) == [VillageContent.FISHING_ROD,0,0,VillageContent.CARROT],"the carrot stick is a fishing rod plus a carrot")
	suite.check(rows.get(FUNGUS,[]) == [VillageContent.FISHING_ROD,0,0,CrimsonPlants.WARPED_FUNGUS],"the fungus stick is a fishing rod plus the warped fungus")
	var probe := Inventory.new()
	var registered: bool = probe.recipe_index(STICK) >= 0 and probe.recipe_index(FUNGUS) >= 0
	suite.check(registered,"both sticks are registered with the parent's recipe table")
	if registered:
		probe.add_item(VillageContent.FISHING_ROD,1); probe.add_item(VillageContent.CARROT,1)
		suite.check(probe.can_craft(probe.recipes[probe.recipe_index(STICK)],"hand"),"one fishing rod and one carrot craft the carrot stick")

	# Both ids exist, unstackable, with the source's 26 uses.
	suite.check(Nodes.exists(STICK) and Nodes.exists(FUNGUS),"both sticks exist as items")
	suite.check(int(PigRiding.DATA[STICK].stack) == 1 and int(PigRiding.DATA[FUNGUS].stack) == 1,"both sticks carry the source's stack_max of one")
	suite.check(Nodes.max_stack(STICK) == 1 and Nodes.max_stack(FUNGUS) == 1,"the registry reports one per stack for both sticks")
	suite.check(PigRiding.durability(STICK) == 26 and PigRiding.durability(FUNGUS) == 26,"durability is the source's 26 uses for both sticks")
	suite.check(PigRiding.durability(Nodes.APPLE) == 0,"an apple has no uses")
	suite.check(Nodes.durability(STICK) == PigRiding.durability(STICK) and Nodes.durability(FUNGUS) == PigRiding.durability(FUNGUS),"the shared durability agrees with the module for both sticks")
	suite.check(PigRiding.is_steering_item(STICK) and PigRiding.is_steering_item(FUNGUS) and not PigRiding.is_steering_item(Nodes.APPLE),"only the two sticks are steering items")
	suite.check(Nodes.title(STICK) == "Carrot on a stick" and Nodes.title(FUNGUS) == "Warped fungus on a stick","both ids carry sensible titles")
	suite.check(VillageContent.DATA.get(STICK,{}).get("family","") == "tool_steering" and VillageContent.DATA.get(FUNGUS,{}).get("family","") == "tool_steering","both rows are tagged as steering tools")

	# The pig, on its own platform.
	# A preceding group may have called `load_world_data`, which **replaces** the
	# world node (`game._replace_world`) — so a reference captured at the top of this
	# function can be freed, and every write through it would go nowhere. Re-read it,
	# then stream this fixture's own column, because a reloaded world starts with no
	# columns and an unloaded cell reads as bedrock.
	world = game.world
	if not world.loaded_at(Vector3(11.5,461.0,9.5)):
		world.active = true
		world.target = Vector3(11.5,461.0,9.5)
		world.radius = 2
		# Column generation happens on the worker pool, so the loop has to hand the
		# engine real frames between pumps or the tasks never complete.
		for i in 400:
			world._process(0.05)
			if world.loaded_at(Vector3(11.5,461.0,9.5)): break
			await suite.process_frame
		world.active = false
	var cells: Array = platform(world,460)
	game.state = "playing"
	game.gamemode = "survival"
	game.inventory.restore([])
	# Every high-altitude fixture in this suite puts the player's stance back before
	# aiming: a preceding group may have left a rotation, a camera pitch or a crouch
	# camera height behind, and `Node3D.global_position` reads a cached global
	# transform that only refreshes when the node is stepped — which these checks
	# disable. Without this the camera's global transform and the aim both pointed at
	# whatever an earlier group had left, so the pig was never the raycast target.
	game.player.position = Vector3(11.5,461.01,11.5)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.force_update_transform()
	game.player.camera.force_update_transform()
	var animal: RuralAnimal = pig(game,Vector3(11.5,461.01,9.5))
	suite.check(PigRiding.is_pig(animal) and not PigRiding.saddled(animal),"a spawned pig starts unsaddled")
	suite.check(not PigRiding.can_mount(animal,STICK),"an unsaddled pig cannot be mounted even with the stick")
	hold(game,STICK)
	suite.check(PigRiding.equip_saddle(animal),"a saddle equips on a pig")
	suite.check(PigRiding.saddled(animal) and not PigRiding.equip_saddle(animal),"the saddle is remembered and cannot be doubled")
	suite.check(PigRiding.can_mount(animal,STICK),"a saddled pig can be mounted")
	suite.check(not PigRiding.can_mount(animal,Nodes.SHEARS),"shears strip the saddle rather than mounting it")

	# Ride it, hold the stick, and steer.
	game.survival.mount = animal
	suite.check(PigRiding.mounted(game) == animal and PigRiding.ridden(animal),"the rider is the module's mounted pig")
	suite.check(PigRiding.can_drive(animal),"the pig is driven while its rider wields the stick")
	hold(game,FUNGUS)
	suite.check(not PigRiding.can_drive(animal),"the warped fungus on a stick carries controls_strider and does not drive a pig")
	hold(game,Nodes.APPLE)
	suite.check(not PigRiding.can_drive(animal),"without a steering item the pig is not driven, as should_drive is false")
	hold(game,STICK)
	var start: Vector3 = animal.position
	PigRiding.steer(game,animal,0.05,Vector3.BACK)
	suite.check(animal.position.distance_to(start) > 0.005 and animal.position.z > start.z,"steering with a direction walks the pig that way")
	# `hog_boost`: the same step measured with the window open at its midpoint and
	# with it closed.
	animal.position = start
	suite.check(not PigRiding.boost_active(animal),"no boost window is open before the first click")
	suite.check(PigRiding.hog_boost(animal) and not PigRiding.hog_boost(animal),"the first click opens a window and a second starts nothing")
	var total: float = float(animal.get_meta(PigRiding.BOOST_TOTAL))
	suite.check(total >= 7.05 and total <= 49.05,"the window lasts the source's (random(841)+140)/20 seconds")
	PigRiding.advance_boost(animal,total/2.0)
	suite.check(absf(PigRiding.boost_factor(animal)-2.5) < 0.005,"the boost peaks at 2.5 times the driven speed at the window's midpoint")
	PigRiding.steer(game,animal,0.05,Vector3.BACK)
	var boosted: float = animal.position.distance_to(start)
	animal.position = start
	animal.remove_meta(PigRiding.BOOST_ELAPSED); animal.remove_meta(PigRiding.BOOST_TOTAL)
	suite.check(absf(PigRiding.boost_factor(animal)-1.0) < 0.0001,"a closed window applies no multiplier")
	PigRiding.steer(game,animal,0.05,Vector3.BACK)
	var plain: float = animal.position.distance_to(start)
	suite.check(boosted > plain and plain > 0.0,"the boosted step carries the pig further than the same step without it")
	# The advance runs only while the pig is driven, which is where `drive` runs it.
	animal.remove_meta(PigRiding.BOOST_ELAPSED); animal.remove_meta(PigRiding.BOOST_TOTAL)
	suite.check(PigRiding.hog_boost(animal),"a window reopens once the last one has closed")
	var reopened: float = float(animal.get_meta(PigRiding.BOOST_TOTAL))
	# `mount.lua:232 if self._drive_boost_elapsed > self._drive_boost_total`, so the
	# window ends on the step that carries the clock past its length, not on the one
	# that lands exactly on it.
	PigRiding.advance_boost(animal,reopened-0.01)
	suite.check(PigRiding.boost_active(animal),"a window is still open just before its length")
	PigRiding.advance_boost(animal,0.02)
	suite.check(not PigRiding.boost_active(animal),"the window closes when its clock runs past its length")

	# The stick wears one use per click and the 26th breaks it.
	hold(game,STICK)
	var uses: int = 0
	for i in 26:
		if PigRiding.use_stick(game): uses += 1
	suite.check(uses == 26,"26 clicks are accepted")
	suite.check(game.inventory.held().id == VillageContent.FISHING_ROD and int(game.inventory.held().wear) == 0,"the 26th use breaks the stick and leaves the source's fishing rod")
	suite.check(not PigRiding.use_stick(game),"a broken stick is refused")
	hold(game,STICK,26)
	suite.check(not PigRiding.use_stick(game),"a stick already at its twenty-sixth use is refused")
	hold(game,STICK,25)
	suite.check(PigRiding.use_stick(game) and game.inventory.held().id == VillageContent.FISHING_ROD,"the twenty-sixth use breaks a stick worn twenty-five times")
	# A window open at the last click is not restarted by it.
	hold(game,STICK)
	PigRiding.hog_boost(animal)
	var before: float = float(animal.get_meta(PigRiding.BOOST_TOTAL))
	PigRiding.use_stick(game)
	suite.check(float(animal.get_meta(PigRiding.BOOST_TOTAL)) == before,"a click during an open window leaves the window alone")

	# Dismount, and strip the saddle the way shears do.
	hold(game,Nodes.SHEARS)
	game.survival.mount = null
	suite.check(PigRiding.mounted(game) == null and not PigRiding.can_drive(animal),"a dismounted pig is no longer driven")
	suite.check(not PigRiding.equip_saddle(animal),"a pig already wearing a saddle cannot take a second")
	suite.check(PigRiding.unsaddle(animal) and not PigRiding.saddled(animal),"shears take the saddle back off")
	var plate: Variant = animal.get_meta(PigRiding.SADDLE_PLATE,null)
	suite.check(plate is MeshInstance3D and not plate.visible,"the saddle plate is hidden once the saddle is off")
	suite.check(PigRiding.equip_saddle(animal) and plate.visible,"saddling again brings the same plate back")
	suite.check(PigRiding.unsaddle(animal),"the saddle comes off a second time")
	suite.check(not PigRiding.can_mount(animal,Nodes.SADDLE),"an unsaddled pig cannot be mounted with a saddle in hand")
	# A baby is past every branch of `pig:on_rightclick` (pig.lua:171).
	var baby: RuralAnimal = pig(game,Vector3(13.5,461.01,9.5))
	baby.growth_remaining = 100
	suite.check(not PigRiding.equip_saddle(baby) and not PigRiding.can_mount(baby,STICK),"a baby pig can be neither saddled nor mounted")

	# The parent's own click path and ride step, which are what actually mount and
	# move the pig. The earlier pigs are freed first so the click cannot find one of
	# them instead — `target_mob` picks the nearest body in the view cone.
	animal.queue_free(); baby.queue_free()
	var click_pig: RuralAnimal = pig(game,Vector3(11.5,461.01,9.5))
	click_pig.set_process(false)
	suite.check(PigRiding.equip_saddle(click_pig),"the click test's pig takes a saddle")
	hold(game,STICK)
	game.player.target = {}
	game.player.camera.look_at(click_pig.center())
	game.player.camera.force_update_transform()
	game.player.use_cooldown = 0
	use_right_click(game)
	suite.check(game.survival.mount == click_pig,"right-clicking a saddled pig with the stick mounts it")
	var click_start: Vector3 = click_pig.position
	# The step walks along the driver's gaze, which is the pig's own direction.
	game.player.camera.look_at(click_start+Vector3(0,0,-3))
	game.survival.ride_step(0.05,Vector3.BACK)
	suite.check(click_pig.position.z < click_start.z-0.005,"the parent's ride step walks the mounted pig along the rider's gaze while the stick is held")
	hold(game,STICK)
	var still: Vector3 = click_pig.position
	var speed: float = PigRiding.drive_speed(click_pig)
	PigRiding.steer(game,click_pig,0.05,Vector3(0,0,-1))
	var walked: float = click_pig.position.distance_to(still)
	# `speed * min(delta, MAX_PHYSICS_DTIME)` and nothing else: the pig walks the
	# source's `movement_speed * drive_bonus` and the frame is clamped as the source
	# clamps it.
	var expect: float = speed*minf(0.05,PigRiding.MAX_PHYSICS_DTIME)
	suite.check(absf(walked-expect) < 0.0005,"the driven step is the source's 0.225 of the pig's walking speed, clamped to its own physics step")
	hold(game,Nodes.APPLE)
	var parked: Vector3 = click_pig.position
	game.survival.ride_step(0.05,Vector3.BACK)
	suite.check(click_pig.position.distance_to(parked) < 0.001,"should_drive is false without a steering item, so the ride step leaves the pig standing")
	game.survival.mount = null

	# A pig restored from a save goes through the shared animal path
	# (village_survival.gd:652-660), which sets `saddled` but draws the **horse's**
	# plate at the horse's own height. The module therefore has to add its own plate
	# to an already-flagged pig rather than refusing it; PARENT WIRING item 5 routes
	# that caller through here so the horse plate is never drawn on a pig at all.
	var loaded: RuralAnimal = pig(game,Vector3(15.5,461.01,9.5))
	loaded.equip_saddle()
	suite.check(loaded.saddled and not loaded.has_meta(PigRiding.SADDLE_PLATE),"the shared animal path flags a pig saddled without a plate of this module's making")
	suite.check(not PigRiding.equip_saddle(loaded) and loaded.has_meta(PigRiding.SADDLE_PLATE),"the module gives an already-flagged pig its own saddle plate")
	loaded.queue_free()

	# Clean up: the mobs, the world's sky, the rider's hand and the player.
	game.survival.mount = null
	click_pig.queue_free()
	hold(game,0)
	game.inventory.restore([])
	for cell in cells: world.set_node(cell,Nodes.AIR)
	game.player.position = saved_position
	game.state = saved_state
