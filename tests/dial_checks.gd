extends RefCounted

# Focused regression for the clock and compass dials. Both are ordinary items in
# the reference whose only distinctive behaviour is that their icon moves: the
# clock's 64-frame sun/moon disc tracks the time of day, the compass's 32-frame
# needle points at the world spawn, and both spin instead when the dimension is
# one where they do not work.

static func icon_pixels(texture: Texture2D) -> int:
	if texture == null: return 0
	var img: Image = texture.get_image()
	var total: int = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x,y).a > 0.0: total += 1
	return total

# A stable fingerprint of a texture, so two different frames can be compared.
static func fingerprint(texture: Texture2D) -> int:
	if texture == null: return 0
	var img: Image = texture.get_image()
	var value: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x,y)
			if c.a <= 0.0: continue
			value = (value*31+int(c.r*255)+int(c.g*255)*3+int(c.b*255)*7+x*11+y*13) & 0x7fffffff
	return value

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	ItemArt.dial_game = game

	# --- the clock's frame tracks the time of day --------------------------
	t.check(Dials.CLOCK_FRAMES == 64 and Dials.COMPASS_FRAMES == 32,"the source's 64 clock frames and 32 compass frames are used")
	# Midnight is the moon end of the table, noon the sun end.
	t.check(Dials.clock_frame(0.5) == 32,"noon resolves to the middle of the source's frame table")
	t.check(Dials.clock_frame(0.0) == 0,"midnight resolves to frame zero")
	# The frame is a full day wrapped, and never leaves the table.
	var in_range: bool = true
	for step in 40:
		var todo: float = float(step)/40.0
		var frame: int = Dials.clock_frame(todo)
		if frame < 0 or frame >= Dials.CLOCK_FRAMES: in_range = false
	t.check(in_range,"every time of day maps inside the frame table")
	t.check(Dials.clock_frame(1.0) == Dials.clock_frame(0.0),"a full day wraps back to the same frame")

	# --- the dial icons actually move --------------------------------------
	game.day_time = 0.25
	var morning: Texture2D = ItemArt.texture(Nodes.CLOCK)
	var morning_fp: int = fingerprint(morning)
	game.day_time = 0.75
	var evening: Texture2D = ItemArt.texture(Nodes.CLOCK)
	var evening_fp: int = fingerprint(evening)
	t.check(icon_pixels(morning) > 0,"the clock draws a non-empty icon")
	t.check(morning_fp != evening_fp,"the clock's icon changes with the time of day")
	t.check(morning != evening,"a new time of day builds a new clock texture")
	# Returning to the same time restores that frame's pixels.
	game.day_time = 0.25
	t.check(fingerprint(ItemArt.texture(Nodes.CLOCK)) == morning_fp,"returning to the same time restores that dial frame")
	# An unchanged frame is not rebuilt, which the frame cache records.
	t.check(int(ItemArt.dial_frames.get(Nodes.CLOCK,-1)) == Dials.clock_frame(0.25),"the dial cache remembers the frame it last drew")

	# --- the compass points at the spawn -----------------------------------
	game.dimension = "overworld"
	t.check(Dials.works(game),"a dial works in the overworld")
	# Standing on the spawn leaves the bearing undefined but stable.
	game.player.position = game.spawn_point
	t.check(Dials.compass_frame(game) == 0,"a compass at the spawn reports a stable bearing")
	# Walking east of the spawn swings the needle to a different frame.
	game.player.position = game.spawn_point+Vector3(64,0,0)
	var east: int = Dials.compass_frame(game)
	game.player.position = game.spawn_point+Vector3(-64,0,0)
	var west: int = Dials.compass_frame(game)
	t.check(east != west,"the compass needle swings as the player moves around the spawn")
	t.check(east >= 0 and east < Dials.COMPASS_FRAMES and west >= 0 and west < Dials.COMPASS_FRAMES,"the compass bearing stays inside its frame table")

	# --- dimension gating --------------------------------------------------
	# A dial does not work in the Nether or the End; the source's
	# `mcl_worlds.compass_works` is the gate and the clock aliases it.
	game.dimension = "nether"
	t.check(not Dials.works(game),"a dial does not work in the Nether")
	game.dimension = "end"
	t.check(not Dials.works(game),"a dial does not work in the End")
	# In a dimension where it does not work the dial spins, so successive ticks
	# change the frame rather than holding one.
	Dials.spinning = 0; Dials.spin_timer = 0.0
	var frames: Dictionary = {}
	for i in 5:
		frames[Dials.frame(game,Nodes.COMPASS)] = true
		Dials.tick(0.1)
	t.check(frames.size() > 1,"a compass that cannot read the world spins through its frames")
	game.dimension = "overworld"
	# The spin advances once per source tick, not once per call.
	Dials.spinning = 0; Dials.spin_timer = 0.0
	Dials.tick(0.05)
	t.check(Dials.spinning == 0,"a half-tick does not advance the spin")
	Dials.tick(0.06)
	t.check(Dials.spinning == 1,"the spin advances once its 0.1 second tick elapses")
	Dials.tick(0.35)
	t.check(Dials.spinning == 4,"a longer delta advances the spin once per elapsed tick")

	# --- the compass icon is drawn for both states -------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Dials.draw_compass(art,0,true)
	var pointing: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: pointing += 1
	t.check(pointing > 0,"a pointing compass draws a non-empty icon")
	var spinning_art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Dials.draw_compass(spinning_art,0,false)
	var differs: bool = false
	for y in 16:
		for x in 16:
			if not art.get_pixel(x,y).is_equal_approx(spinning_art.get_pixel(x,y)): differs = true
	t.check(differs,"a spinning compass is drawn differently from a working one")
	var clock_art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Dials.draw_clock(clock_art,20,false)
	var clock_pixels: int = 0
	for y in 16:
		for x in 16:
			if clock_art.get_pixel(x,y).a > 0.0: clock_pixels += 1
	t.check(clock_pixels > 0,"a clock dial draws a non-empty icon")

	# --- the items themselves stay ordinary -------------------------------
	t.check(Nodes.title(Nodes.CLOCK) == "Clock" and Nodes.title(Nodes.COMPASS) == "Compass","the two dial items are registered with their own names")
	var inv := Inventory.new()
	t.check(inv.recipe_index(Nodes.CLOCK) >= 0,"the clock has its source crafting recipe")
	if inv.recipe_index(Nodes.CLOCK) >= 0:
		var recipe: Dictionary = inv.recipes[inv.recipe_index(Nodes.CLOCK)]
		t.check(recipe.ingredients.get(Nodes.GOLD,0) == 4 and recipe.ingredients.get(Nodes.REDSTONE_WIRE,0) == 1,"the clock takes four gold and one redstone, as the source recipe does")
	t.check(inv.recipe_index(Nodes.COMPASS) >= 0,"the compass has its source crafting recipe")
