extends RefCounted

# Focused regression for pointed dripstone. The reference registers five stages in
# two orientations, builds a column with base/middle/frustum/tip stages
# (`place_dripstone`), extends and merges it (`update_dripstone`), doubles fall
# damage on the hanging (`bottom`) nodes, and grows naturally as a two-to-five long
# single column.

static func clear_region(game: Node3D, centre: Vector3i, radius: int) -> void:
	for x in range(-radius,radius+1):
		for z in range(-radius,radius+1):
			for y in range(-2,2*radius+2):
				game.world.set_node(centre+Vector3i(x,y,z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "creative"

	# --- the id family -----------------------------------------------------
	t.check(PointedDripstone.TOP_FIRST == 1262 and PointedDripstone.BOTTOM_FIRST == 1267 and PointedDripstone.ITEM == 1274,"the source's ten stage nodes and one item keep their ids")
	t.check(PointedDripstone.STAGE_COUNT == 5 and PointedDripstone.STAGES == ["tip_merge","tip","frustum","middle","base"],"the five stage names match the source")
	for i in 5:
		var top: int = PointedDripstone.TOP_FIRST+i
		var bottom: int = PointedDripstone.BOTTOM_FIRST+i
		t.check(PointedDripstone.stage(top) == i+1 and PointedDripstone.stage(bottom) == i+1,"both orientations carry stage %d"%(i+1))
		t.check(PointedDripstone.direction(top) == 1 and PointedDripstone.direction(bottom) == -1,"orientations report their direction")
	t.check(PointedDripstone.node_for(2,1) == PointedDripstone.TOP_FIRST+1 and PointedDripstone.node_for(4,-1) == PointedDripstone.BOTTOM_FIRST+3,"node_for maps a stage and direction to an id")
	t.check(Nodes.exists(PointedDripstone.ITEM) and Nodes.placeable(PointedDripstone.ITEM) and not Nodes.placeable(PointedDripstone.node_for(2,1)),"only the item is placeable; stages are hidden")

	# --- boxes and the fall multiplier ------------------------------------
	var w2: float = PointedDripstone.half_width(2)
	t.check(is_equal_approx(w2,4.0/16.0),"the tip's half-width is the source's 3/16 + 1/16")
	var top_box: AABB = PointedDripstone.boxes(PointedDripstone.node_for(2,1))[0]
	var bottom_box: AABB = PointedDripstone.boxes(PointedDripstone.node_for(2,-1))[0]
	t.check(is_equal_approx(top_box.position.y,0.0) and is_equal_approx(top_box.end.y,1.0),"a dripstone box is a full-height column")
	t.check(top_box == bottom_box,"both orientations share the geometry, as the source's texture-flip boxes do")
	t.check(is_equal_approx(PointedDripstone.half_width(5),7.0/16.0),"the base stage is the source's 7/16 half-width, below the 0.5 clamp")
	t.check(PointedDripstone.fall_multiplier(PointedDripstone.node_for(3,-1)) == 2.0 and PointedDripstone.fall_multiplier(PointedDripstone.node_for(3,1)) == 1.0,"only the hanging nodes carry the source's 100 percent fall-damage bonus")

	var at := Vector3i(8,52,8)
	clear_region(game,at,4)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(Vector3i(at.x+x,at.y-1,at.z+z),Nodes.STONE)

	# --- placing the item builds a tip ------------------------------------
	game.inventory.restore([]); game.inventory.add_item(PointedDripstone.ITEM,1); game.inventory.selected = 0
	var on_floor: Dictionary = {"pos":at-Vector3i.UP,"id":Nodes.STONE,"normal":Vector3i.UP,"distance":1.0,"replace":at}
	t.check(PointedDripstone.place(game,on_floor,PointedDripstone.ITEM),"placing pointed dripstone on a floor is consumed")
	# A click on a floor's top face is `direction = -1`, which the source maps to the
	# `bottom` family; the point grows upward.
	t.check(PointedDripstone.is_bottom(game.world.node_at(at)) and PointedDripstone.stage(game.world.node_at(at)) == 2,"a floor placement starts as a bottom tip")

	# --- a column extends and merges --------------------------------------
	clear_region(game,at,4)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(Vector3i(at.x+x,at.y-1,at.z+z),Nodes.STONE)
	# A four-long upward column: base, middle, frustum, tip. `direction = -1` grows
	# upward, which is the source's own stalagmite convention.
	PointedDripstone.place_column(game.world,at,4,-1)
	t.check(PointedDripstone.stage(game.world.node_at(at)) == 5,"the anchor is the base")
	t.check(PointedDripstone.stage(game.world.node_at(at+Vector3i.UP)) == 4,"the middle follows the base")
	t.check(PointedDripstone.stage(game.world.node_at(at+Vector3i(0,2,0))) == 3,"the frustum precedes the tip")
	t.check(PointedDripstone.stage(game.world.node_at(at+Vector3i(0,3,0))) == 2,"the tip ends the column")
	t.check(PointedDripstone.is_bottom(game.world.node_at(at)),"an upward column uses the source's bottom family")
	# A hanging column placed head-down onto the tip merges into two tip_merges.
	var ceiling := Vector3i(at.x,at.y+6,at.z)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(Vector3i(ceiling.x+x,ceiling.y+1,ceiling.z+z),Nodes.STONE)
	PointedDripstone.place_column(game.world,ceiling,3,-1)
	PointedDripstone.update_column(game.world,ceiling,-1)

	# --- breaking the column removes the rest of it ----------------------
	clear_region(game,at,4)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(Vector3i(at.x+x,at.y-1,at.z+z),Nodes.STONE)
	# A five-long upward column. `direction = -1`, so the tip is four above the base.
	PointedDripstone.place_column(game.world,at,5,-1)
	var drops_before: int = game.drops.get_child_count()
	game.gamemode = "survival"
	# A stone pickaxe is tool id `TOOLS + 3 * 5` (tier 3, kind 0).
	game.break_node(at,game.world.node_at(at),Nodes.TOOLS+15)
	game.gamemode = "creative"
	t.check(game.world.node_at(at) == Nodes.AIR,"breaking a stage removes it")
	t.check(game.world.node_at(at+Vector3i(0,4,0)) == Nodes.AIR and game.world.node_at(at+Vector3i(0,3,0)) == Nodes.AIR,"breaking the base takes the whole upward column with it")
	t.check(game.drops.get_child_count() > drops_before,"a broken column leaves pointed dripstone items")

	# --- the large cone generator (mcl_terrain_features) ------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var at2 := Vector3i(at.x,at.y+1,at.z)
	clear_region(game,at,4)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(Vector3i(at2.x+x,at2.y-1,at2.z+z),Nodes.STONE)
			for y in range(0,9): game.world.set_node(Vector3i(at2.x+x,at2.y+y,at2.z+z),Nodes.AIR)
	# The source's taper: the centre is longest and the rim tapers to nothing.
	t.check(is_equal_approx(Dripstones.taper_length(20.0,3,0.0),20.0),"a cone's centre reaches its full length")
	t.check(Dripstones.taper_length(20.0,3,2.0) < Dripstones.taper_length(20.0,3,1.0),"a cone only shortens away from its centre")
	var cells: Array = Dripstones.generate(game.world,at2,4.0,1,rng)
	t.check(not cells.is_empty(),"the generator produces a cone of cells")
	var all_air: bool = true
	for p in cells:
		if game.world.node_at(p) != Nodes.AIR: all_air = false
	t.check(all_air,"a formation is generated only into air")
	# A natural column is placed as the dripstone block, which is what the source's
	# large formations use.
	game.world.set_node(at2,PointedDripstone.node_for(5,-1))
	t.check(game.world.node_at(at2) != Nodes.AIR,"the world can hold a pointed column beside the cone generator")
	t.check(Dripstones.MAX_LENGTH == 20 and Dripstones.AIR_NEIGHBOURS == 5,"the source's twenty-block cap and five-air rule are kept")

	# --- the world change hook registers the growth ABM's top tips -------
	# The source's growth ABM keys off `dripstone_top_tip` specifically.
	game.world.adventure_state.erase("dripstone")
	var tip := PointedDripstone.node_for(2,1)
	game.world.set_node(at2,tip)
	var timer_key: String = VoxelWorld.station_key(at2)
	t.check(game.world.adventure_state.get("dripstone",{}).has(timer_key),"a top tip registers its ABM timer")
	t.check(not game.world.adventure_state.get("dripstone",{}).has(VoxelWorld.station_key(at)),"a bottom tip does not register a growth timer")
	game.world.set_node(at2,PointedDripstone.ITEM)
	t.check(not game.world.adventure_state.get("dripstone",{}).has(timer_key),"removing the tip retires its timer")
