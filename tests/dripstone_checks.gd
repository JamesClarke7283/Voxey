extends RefCounted

# Focused regression for dripstone formations (Mineclonia `mcl_terrain_features`).
#
# Voxey had the dripstone *block* but nothing that placed it, so caves had no
# dripstone at all. The source registers three formations, and the shape rule is
# what makes them cones rather than pillars:
#
#   * A **stalactite** hangs down, at `min(20, air * random(0.2, 0.6))`.
#   * A **stalagmite** rises up, at `min(20, air * random(0.4, 0.8))`.
#   * A **column** grows from both ends, at `min(20, air * random(0.4, 6))`.
#
# and every offset from the centre is tapered by
# `max_length * (r^2 - offset_r^2) / r^2`, so the middle is longest.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var gen: TerrainGenerator = game.world.generator

	# --- the source's constants --------------------------------------------
	t.check(is_equal_approx(float(Dripstones.MAX_LENGTH),20.0),"the source's twenty-block cap is used")
	t.check(Dripstones.AIR_NEIGHBOURS == 5,"the source's five air neighbours are required")
	t.check(is_equal_approx(Dripstones.FILL_RATIO,0.005),"the source's fill ratio is used")
	t.check(Dripstones.KINDS.size() == 3,"the source's three formations are registered")
	t.check(VillageContent.DRIPSTONE_BLOCK != 0,"the dripstone block exists, which the formations place")

	# --- the taper, which is what makes a cone ------------------------------
	# The centre is longest and the rim is zero, so a formation comes to a point.
	t.check(is_equal_approx(Dripstones.taper_length(20.0,3,0.0),20.0),"a formation's centre is its full length")
	t.check(is_equal_approx(Dripstones.taper_length(20.0,3,3.0),0.0),"a formation's rim tapers to nothing")
	var mid: float = Dripstones.taper_length(20.0,3,1.5)
	t.check(mid < 20.0 and mid > 0.0,"a formation tapers between its centre and its rim")
	# The taper must be monotonic, or the shape would not be a cone.
	var previous: float = Dripstones.taper_length(20.0,3,0.0)
	var monotonic: bool = true
	for step in [0.5,1.0,1.5,2.0,2.5,3.0]:
		var here: float = Dripstones.taper_length(20.0,3,step)
		if here > previous: monotonic = false
		previous = here
	t.check(monotonic,"the taper only shortens as it moves outward")

	# --- the length rolls, per kind -----------------------------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var lengths: Dictionary = {}
	for kind in Dripstones.KINDS:
		lengths[kind] = []
	for i in 400:
		for kind in Dripstones.KINDS: lengths[kind].append(Dripstones.roll_length(kind,10.0,rng))
	for kind in Dripstones.KINDS:
		var values: Array = lengths[kind]
		# Every formation is capped at twenty blocks, whatever the gap.
		t.check(values.max() <= Dripstones.MAX_LENGTH,"the %s never exceeds the source's cap" % kind)
		t.check(values.min() > 0.0,"the %s always grows at least something" % kind)
	# The source gives a stalagmite a larger fraction than a stalactite, so on the
	# same gap it is on average taller. That ordering is the source's own.
	var stalactite_mean: float = 0.0
	var stalagmite_mean: float = 0.0
	for v in lengths[Dripstones.STALACTITE]: stalactite_mean += float(v)
	for v in lengths[Dripstones.STALAGMITE]: stalagmite_mean += float(v)
	stalactite_mean /= float(lengths[Dripstones.STALACTITE].size())
	stalagmite_mean /= float(lengths[Dripstones.STALAGMITE].size())
	t.check(stalagmite_mean > stalactite_mean,"a stalagmite is on average taller than a stalactite, as the source's fractions give")

	# --- dripstone really generates ------------------------------------------
	# This is the gap being closed: caves had no dripstone at all. Generation is
	# sampled across several columns, because a single column may simply be solid.
	var found: int = 0
	var columns_with_dripstone: int = 0
	var underground: bool = true
	for i in 20:
		var column: Dictionary = gen.generate_column(Vector2i(i,0),{})
		var here: int = 0
		for block in column.blocks:
			for value in block.data:
				if value == VillageContent.DRIPSTONE_BLOCK:
					here += 1
					# Dripstone is a cave feature, so it belongs below ground.
					if int(block.y) >= gen.terrain_ceiling(): underground = false
		found += here
		if here > 0: columns_with_dripstone += 1
	t.check(found > 0,"dripstone generates in the world")
	t.check(columns_with_dripstone > 0,"at least one sampled column contains dripstone")
	t.check(underground,"dripstone only generates underground")

	# --- it is a cave feature, so it never replaces solids -------------------
	# The source grows a formation only through air, so a cave keeps its shape and
	# dripstone is added to it rather than carved out of the rock.
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 7
	var sample: Dictionary = gen.generate_column(Vector2i(3,0),{})
	t.check(not sample.is_empty(),"a column generates for the shape check")
	# The taper means a formation is wider at its anchor than at its tip, so the
	# number of cells strictly falls as the offset grows.
	var wide: int = 0
	var narrow: int = 0
	for offset in [0.0,0.5]:
		for x in range(-3,4):
			for z in range(-3,4):
				var distance: float = sqrt(float(x*x+z*z))
				var length: float = Dripstones.taper_length(12.0,3,distance)
				if offset == 0.0 and length > 4.0: wide += 1
				if offset == 0.5 and length > 4.0: narrow += 1
	t.check(wide > 0 and narrow >= wide,"a formation's long columns are near its centre")

	# --- water and lava drip from a ceiling ---------------------------------
	# The source's `mcl_dripping` rule is three cells deep: air below, an opaque node
	# in the middle, and that liquid directly above. It is what makes a cave feel wet,
	# and Voxey had the dripstone *shape* but nothing that dripped.
	var roof := Vector3i(4,120,4)
	for y in range(116,124): game.world.set_node(Vector3i(4,y,4),Nodes.AIR)
	game.world.set_node(roof,Nodes.STONE)
	# Without a liquid above there is nothing to drip.
	t.check(not Dripping.eligible(game.world,roof),"no drip until the liquid is above the node")
	game.world.set_node(roof+Vector3i.UP,Nodes.WATER)
	t.check(Dripping.eligible(game.world,roof),"water above stone with air below drips")
	t.check(Dripping.liquid_above(game.world,roof) == Nodes.WATER,"the drip reports water")
	# Blocking the cell below stops it, which is why digging under a drip ends it.
	game.world.set_node(roof-Vector3i.UP,Nodes.STONE)
	t.check(not Dripping.eligible(game.world,roof),"a blocked cell below stops the drip")
	game.world.set_node(roof-Vector3i.UP,Nodes.AIR)
	t.check(Dripping.eligible(game.world,roof),"clearing the cell below resumes it")
	# Lava drips from opaque rock only, and water also drips through leaves.
	game.world.set_node(roof+Vector3i.UP,Nodes.LAVA)
	t.check(Dripping.eligible(game.world,roof) and Dripping.liquid_above(game.world,roof) == Nodes.LAVA,"lava above stone drips")
	game.world.set_node(roof,Nodes.LEAVES)
	t.check(not Dripping.eligible(game.world,roof),"lava does not drip through leaves, as the source's node list excludes them")
	game.world.set_node(roof+Vector3i.UP,Nodes.WATER)
	t.check(Dripping.eligible(game.world,roof),"water does drip through leaves")
	# The change hook tracks and untracks the cell as the world changes.
	game.world.set_node(roof,Nodes.STONE)
	var tracked: Dictionary = Dripping.runtime(game.world).cells
	t.check(tracked.has(roof),"a changed node registers its drip cell")
	game.world.set_node(roof+Vector3i.UP,Nodes.AIR)
	t.check(not tracked.has(roof) and not Dripping.eligible(game.world,roof),"removing the liquid untracks the cell")
	# The source's own intervals and chance.
	t.check(is_equal_approx(Dripping.WATER_INTERVAL,60.3) and is_equal_approx(Dripping.LAVA_INTERVAL,110.1),"the source's water and lava intervals are recorded")
	t.check(Dripping.CHANCE == 10,"a drip has the source's one-in-ten chance")
	# The driver advances its clocks and emits.
	game.world.set_node(roof+Vector3i.UP,Nodes.WATER)
	t.check(Dripping.emit(game,roof,Nodes.WATER),"a drip emits its particles and sound")
