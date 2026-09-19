extends RefCounted

# Paintings (mcl_paintings): the source's 26 motives, biggest-fit wall placement,
# tie-break, occupancy, punch-to-drop and persistence.
static func run(suite: Object, game: Node3D) -> void:
	# The motive set is the source's own, from 1x1 to 4x4.
	suite.check(Paintings.MOTIVES.size() == 26,"the source's twenty-six paintings are registered")
	var sizes_ok: bool = true
	var has_four: bool = false
	for m in Paintings.MOTIVES:
		if int(m.w) < 1 or int(m.h) < 1 or int(m.w) > 4 or int(m.h) > 4: sizes_ok = false
		if int(m.w) == 4 and int(m.h) == 4: has_four = true
	suite.check(sizes_ok and has_four,"every motive is within the source's 1x1 to 4x4 bounds")
	suite.check(Paintings.motive(0).title == "Ancient Octopus" and Paintings.motive(25).title == "Volendam Costume","the motive order and titles are the source's")

	# A flat wall of stone in a cleared region. Every cell this check touches is
	# snapshotted first and restored at the end, so a later check that scans the
	# terrain (for example the wild bamboo groves) sees it unchanged.
	var base: Vector3i = Vector3i(-4,game.world.generator.terrain_height(-4,-4)+3,-4)
	var saved: Dictionary = {}
	for x in range(-10,4):
		for z in range(-10,4):
			for y in range(base.y-2,base.y+7):
				var cell := Vector3i(x,y,z)
				saved[cell] = game.world.node_at(cell)
	for x in range(-10,4):
		for z in range(-10,4):
			for y in range(base.y-2,base.y+7): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for x in range(-10,4):
		for y in range(base.y-2,base.y+7): game.world.set_node(Vector3i(x,y,base.z),Nodes.STONE)

	var facing: int = Paintings.FACINGS.find(Vector3i.BACK)
	suite.check(facing >= 0,"the wall facing resolves to a source wallmounted index")

	# Biggest-fit: with a free 4x4 field the largest motive (area 16) is chosen.
	var anchor: Vector3i = base+Vector3i(0,0,1)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var pick: int = Paintings.biggest_fit(game.world,anchor,facing,rng)
	suite.check(pick >= 0 and int(Paintings.motive(pick).w)*int(Paintings.motive(pick).h) == 16,"a free field takes the largest motive the source allows")
	# One row of headroom limits the height to 1, so only 2x1 or smaller fits.
	for x in range(anchor.x,anchor.x+4): game.world.set_node(Vector3i(x,anchor.y+1,anchor.z),Nodes.STONE)
	rng.seed = 7
	var limited: int = Paintings.biggest_fit(game.world,anchor,facing,rng)
	suite.check(limited >= 0 and int(Paintings.motive(limited).h) == 1,"a one-block gap limits the fit to a single-row motive")
	for x in range(anchor.x,anchor.x+4): game.world.set_node(Vector3i(x,anchor.y+1,anchor.z),Nodes.AIR)

	# Occupancy: a hung painting claims every cell of its footprint.
	game.world.adventure_state.erase("paintings")
	var big: int = 0
	for i in Paintings.MOTIVES.size():
		if int(Paintings.MOTIVES[i].w) == 4 and int(Paintings.MOTIVES[i].h) == 4: big = i; break
	Paintings.hang(game,anchor,facing,big)
	var boxes: Array = Paintings.cells(anchor,facing,4,4)
	var claimed: int = 0
	for cell in boxes:
		if Paintings.anchor_for(game.world,cell).get("anchor",Vector3i.ZERO) == anchor: claimed += 1
	suite.check(claimed == 16,"every cell of a hung painting is claimed, so nothing overlaps it")
	# A second painting will not overlap the first.
	rng.seed = 3
	var second: int = Paintings.biggest_fit(game.world,anchor,facing,rng)
	suite.check(second < 0,"a fully occupied field admits no second painting at the same anchor")
	suite.check(Paintings.remove(game,str(Paintings.key_of(anchor))) != {},"a hung painting can be removed by its anchor")

	# Punch-to-drop returns the item in survival, with its motive recorded.
	game.gamemode = "survival"
	Paintings.hang(game,anchor,facing,big)
	var before: int = game.drops.get_child_count()
	var entry: Dictionary = Paintings.remove(game,str(Paintings.key_of(anchor)),true)
	suite.check(not entry.is_empty() and game.drops.get_child_count() == before+1,"punching a painting returns its item")

	# Persistence: the record survives in the world's adventure state.
	game.world.adventure_state.erase("paintings")
	Paintings.hang(game,anchor,facing,big)
	suite.check(Paintings.records(game.world).has(Paintings.key_of(anchor)),"a hung painting is stored in the world's adventure state")
	suite.check(not Paintings.records(game.world).is_empty() and int(Paintings.records(game.world)[Paintings.key_of(anchor)].motive) == big,"the stored record keeps the motive")

	# Each motive has its own texture, sized to its blocks.
	var textures_ok: bool = true
	for i in Paintings.MOTIVES.size():
		var tex: ImageTexture = Paintings.texture(i)
		if tex == null: textures_ok = false; continue
		var img: Image = tex.get_image()
		if img.get_width() != int(Paintings.MOTIVES[i].w)*16 or img.get_height() != int(Paintings.MOTIVES[i].h)*16: textures_ok = false
	suite.check(textures_ok,"every motive renders its own texture at sixteen pixels per block")
	# Restore every cell the wall replaced, so later terrain scans are unaffected.
	for cell in saved: game.world.set_node(cell,int(saved[cell]))
	game.world.adventure_state.erase("paintings")
