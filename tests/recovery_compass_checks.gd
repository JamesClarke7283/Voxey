extends RefCounted

# The recovery compass: `mcl_compass`'s `recovery_compass` item, its recipe and the
# dial that points at the player's last death.

static func run(suite: Object, game: Node3D) -> void:
	var saved_position: Vector3 = game.player.position
	var saved_recovery: Variant = game.world.adventure_state.get("last_recovery",null)
	# `Dials.works` reads the **game's** dimension, not the world's, so that is what
	# the dimension checks must drive.
	var saved_dimension: String = game.dimension

	# --- the item --------------------------------------------------------------
	suite.check(Nodes.exists(RecoveryCompass.ID),"the recovery compass is registered")
	suite.check(Nodes.title(RecoveryCompass.ID) == "Recovery compass","and carries the source's own name")
	suite.check(Nodes.max_stack(RecoveryCompass.ID) == 1,"a compass is unstackable, as the source's `stack_max` says")
	suite.check(RecoveryCompass.is_recovery_compass(RecoveryCompass.ID) and not RecoveryCompass.is_recovery_compass(Nodes.COMPASS) and not RecoveryCompass.is_recovery_compass(Nodes.CLOCK),"only the recovery compass answers, not the plain compass or the clock")
	# The source's id must not collide with the modding API's reserved band.
	suite.check(RecoveryCompass.ID != Nodes.MOD_ITEM_BASE and RecoveryCompass.ID > 255,"the id sits in the content band, clear of the mod item base")

	# --- the recipe ------------------------------------------------------------
	# `mcl_compass`'s recipe: eight echo shards around an ordinary compass.
	var inv := Inventory.new()
	var index: int = inv.recipe_index(RecoveryCompass.ID)
	suite.check(index >= 0,"the recovery compass has a registered recipe")
	if index >= 0:
		var recipe: Dictionary = inv.recipes[index]
		suite.check(recipe.ingredients == {Sculk.ECHO_SHARD:8,Nodes.COMPASS:1},"it takes eight echo shards and one compass, as the source's 3x3 says")
		suite.check(recipe.station == "table","and it needs a crafting table")
		var crafted := Inventory.new()
		crafted.add_item(Sculk.ECHO_SHARD,8); crafted.add_item(Nodes.COMPASS,1)
		var craft_index: int = crafted.recipe_index(RecoveryCompass.ID)
		suite.check(craft_index >= 0 and crafted.craft(craft_index,"table") and crafted.count_item(RecoveryCompass.ID) == 1,"eight shards and a compass produce one recovery compass")
		suite.check(crafted.count_item(Sculk.ECHO_SHARD) == 0 and crafted.count_item(Nodes.COMPASS) == 0,"and consume every ingredient")

	# --- the dial --------------------------------------------------------------
	# With no death recorded the source leaves the needle spinning, which is the
	# visible "nothing to point at" signal. `Dials.spinning` is what drives it.
	game.world.adventure_state.erase("last_recovery")
	suite.check(not RecoveryCompass.pointing(game),"with no recorded death the needle does not point")
	var first: int = RecoveryCompass.frame(game)
	Dials.spinning += 1
	suite.check(RecoveryCompass.frame(game) != first or Dials.COMPASS_FRAMES == 1,"the un-pointed needle advances with the spin clock")
	Dials.spinning = 0

	# A recorded death makes it point, and the frame is the bearing to that cell.
	game.world.adventure_state["last_recovery"] = {"position":[100,64,100],"owner":"player"}
	suite.check(RecoveryCompass.pointing(game),"a recorded death makes the needle point")
	suite.check(Dials.recovering(game),"and the module sees a death position to recover")
	var here: Vector3 = game.player.position
	suite.check(RecoveryCompass.frame(game) == Dials.recovery_frame(game),"the frame is the bearing to the death position")
	# The bearing is the shared compass maths, so it must agree with the plain
	# compass pointed at the same target.
	suite.check(Dials.bearing(game,Vector3(100,64,100)) == RecoveryCompass.frame(game),"the bearing matches the shared `get_compass_angle` maths")
	# Frame 0 is south in the source's first image, so a target straight **north**
	# reads the half-turn frame and one straight east a quarter turn. Both come from
	# the shared bearing maths, which is what the plain compass uses.
	game.player.position = Vector3(100,64,80)
	suite.check(RecoveryCompass.frame(game) == Dials.COMPASS_FRAMES/2,"a target straight north reads the half turn, since frame 0 is south")
	game.player.position = Vector3(80,64,100)
	suite.check(RecoveryCompass.frame(game) == Dials.COMPASS_FRAMES/4,"a target straight east reads a quarter turn")
	game.player.position = here
	# Standing on the target leaves the needle still rather than spinning.
	game.player.position = Vector3(100,64,100)
	suite.check(RecoveryCompass.frame(game) == 0,"standing on the death position reads frame 0 rather than spinning")

	# A malformed record is refused rather than trusted.
	for bad in [{"position":[1,2]},{"position":["a","b","c"]},{"position":[1,2,3.0/0.0]},{},"nonsense"]:
		game.world.adventure_state["last_recovery"] = bad
		suite.check(not RecoveryCompass.pointing(game),"a malformed recovery record does not make the needle point")
	suite.check(Dials.recovery_position(game).is_empty(),"and the accessor reports nothing for them")

	# --- the dimensions --------------------------------------------------------
	# `mcl_worlds.compass_works`: a compass does not work outside the Overworld.
	game.world.adventure_state["last_recovery"] = {"position":[100,64,100],"owner":"player"}
	for dimension in ["nether","end"]:
		game.dimension = dimension
		suite.check(not Dials.works(game) and not RecoveryCompass.pointing(game),"the needle does not point in the "+dimension)
	game.dimension = saved_dimension

	# --- the art ---------------------------------------------------------------
	# The dial renders through the same compass renderer, and the icon must exist for
	# every frame it can show.
	var rendered: bool = true
	for frame in Dials.COMPASS_FRAMES:
		var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
		Dials.draw_compass(img,frame,true)
		var painted: int = 0
		for y in 16:
			for x in 16:
				if img.get_pixel(x,y).a > 0.0: painted += 1
		if painted == 0: rendered = false
	suite.check(rendered,"every compass frame draws a non-empty needle, so no frame is a blank icon")
	suite.check(ItemArt.texture(RecoveryCompass.ID) != null,"the item has a rendered icon")

	# --- cleanup ---------------------------------------------------------------
	game.player.position = saved_position
	game.dimension = saved_dimension
	if saved_recovery == null: game.world.adventure_state.erase("last_recovery")
	else: game.world.adventure_state["last_recovery"] = saved_recovery
	game.inventory.restore([])
