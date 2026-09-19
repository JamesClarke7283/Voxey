extends RefCounted

# Focused regression for ice spikes (Mineclonia's ice-spike decorations in
# `mcl_structures` and `mcl_biomes`).
#
# An ice spike is a cone of packed ice rising from snowy ground, and a spike field
# is what makes a frozen plain a landmark rather than a flat white expanse. The
# source registers two sizes and places them over the `IcePlainsSpikes` biome.
# Voxey's cold biome is `Frostpine highlands`, which had no decoration at all.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the two sizes ------------------------------------------------------
	t.check(IceSpikes.KINDS.size() == 2,"the source's two spike sizes are registered")
	t.check(IceSpikes.KINDS.has(IceSpikes.SMALL),"the small spike exists")
	t.check(IceSpikes.KINDS.has(IceSpikes.LARGE),"the large spike exists")
	t.check(DenseMaterials.PACKED_ICE != 0,"packed ice exists, which a spike is built from")
	# The source places on snow, so the snowy surface it needs must exist.
	t.check(Nodes.SNOW != 0 and Nodes.SNOW_BLOCK != 0,"the snow surfaces a spike stands on exist")

	# --- the two sizes differ, and a large spike is larger -------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var small_heights: Array = []
	var large_heights: Array = []
	for i in 200:
		small_heights.append(IceSpikes.height(IceSpikes.SMALL,rng))
		large_heights.append(IceSpikes.height(IceSpikes.LARGE,rng))
	t.check(small_heights.min() > 0 and small_heights.max() <= 6,"a small spike is a stub")
	t.check(large_heights.min() >= 8,"a large spike towers")
	t.check(large_heights.min() > small_heights.max(),"the two sizes do not overlap")
	t.check(IceSpikes.radius(IceSpikes.LARGE) > IceSpikes.radius(IceSpikes.SMALL),"a large spike has a wider base")

	# --- the taper, which is what makes it a cone ---------------------------
	# The base is full width and the tip is a single block, so a spike comes to a
	# point rather than being a pillar.
	var total: int = 10
	t.check(IceSpikes.radius_at(IceSpikes.LARGE,0,total) == IceSpikes.radius(IceSpikes.LARGE),"a spike's base is its full width")
	t.check(IceSpikes.radius_at(IceSpikes.LARGE,total,total) == 1,"a spike's tip is a single block")
	# The width must only shrink as it rises, or there would be no point.
	var previous: int = IceSpikes.radius_at(IceSpikes.LARGE,0,total)
	var monotonic: bool = true
	for level in range(1,total+1):
		var here: int = IceSpikes.radius_at(IceSpikes.LARGE,level,total)
		if here > previous: monotonic = false
		previous = here
	t.check(monotonic,"a spike only narrows as it rises")

	# --- the shape it actually builds ---------------------------------------
	# Every cell of a spike is packed ice, the base is wider than the top, and the
	# whole thing is a single connected cone.
	var shape: Array = IceSpikes.cells_at(Vector3i(0,40,0),IceSpikes.LARGE,rng)
	t.check(shape.size() > 0,"a spike builds cells")
	var base_cells: int = 0
	var top_cells: int = 0
	var highest: int = 40
	for p in shape:
		if p.y == 40: base_cells += 1
		if p.y > highest: highest = p.y
	for p in shape:
		if p.y == highest: top_cells += 1
	t.check(base_cells > top_cells,"a spike's base is wider than its top")
	t.check(top_cells == 1,"a spike ends in a single block")
	# The spike occupies a contiguous column of heights, so there is no gap in it.
	var levels: Dictionary = {}
	for p in shape: levels[p.y] = true
	var contiguous: bool = true
	for y in range(40,highest+1):
		if not levels.has(y): contiguous = false
	t.check(contiguous,"a spike is contiguous from base to tip")

	# --- it really generates on snowy ground ---------------------------------
	# This is the gap being closed: the cold biome had no decoration. Generation is
	# sampled across many columns, because one column may simply have no site.
	var spikes: int = 0
	var cold: int = 0
	for cx in range(-12,13):
		for cz in range(-12,13):
			if gen.biome(cx*16+8,cz*16+8) != "Frostpine highlands": continue
			cold += 1
			var column: Dictionary = gen.generate_column(Vector2i(cx,cz),{})
			for block in column.blocks:
				for value in block.data:
					if value == DenseMaterials.PACKED_ICE: spikes += 1
	t.check(cold > 0,"the cold biome exists to place spikes in")
	t.check(spikes > 0,"ice spikes generate in the cold biome")
	# They must be plentiful, since the source decorates the whole spike biome.
	t.check(spikes > cold,"the frozen plains carry more than one spike block per column")

	# --- and only in the cold biome ------------------------------------------
	# A spike in a warm biome would be out of place, and the source restricts them
	# to the spike plains. Sampling a warm region must find none.
	var warm_spikes: int = 0
	var warm: int = 0
	for cx in range(30,40):
		for cz in range(30,40):
			var here: String = gen.biome(cx*16+8,cz*16+8)
			if here == "Frostpine highlands" or here == "Sunwash desert": continue
			warm += 1
			var column: Dictionary = gen.generate_column(Vector2i(cx,cz),{})
			for block in column.blocks:
				for value in block.data:
					if value == DenseMaterials.PACKED_ICE: warm_spikes += 1
	if warm > 0:
		t.check(warm_spikes == 0,"no spikes grow outside the spike biome")
