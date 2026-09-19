extends RefCounted

# Focused regression for beacons. The reference counts four square pyramid layers
# beneath the beacon, each of radius equal to its offset, and stops at the first
# layer that is not entirely mineral blocks. Power sets both the available effects
# and the range, which is `(power + 1) * 10`.

static func build_pyramid(world: VoxelWorld, p: Vector3i, levels: int, block: int) -> void:
	# Four layers of increasing radius, as `check_pyramid` walks them.
	for offset in range(1,levels+1):
		for x in range(p.x-offset,p.x+offset+1):
			for z in range(p.z-offset,p.z+offset+1):
				world.set_node(Vector3i(x,p.y-offset,z),block)

static func clear_pyramid(world: VoxelWorld, p: Vector3i) -> void:
	for offset in range(1,5):
		for x in range(p.x-offset,p.x+offset+1):
			for z in range(p.z-offset,p.z+offset+1):
				world.set_node(Vector3i(x,p.y-offset,z),Nodes.AIR)

static func plot(world: VoxelWorld, ground: Vector3i) -> void:
	for x in range(-8,9):
		for z in range(-8,9):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),Nodes.STONE)
			for y in range(8): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var base := Vector3i(8,1800,8)
	plot(world,base)
	var beacon := base+Vector3i(0,4,0)
	Beacons.reset(world)

	# --- registry ----------------------------------------------------------
	t.check(Beacons.is_beacon(VillageContent.BEACON) and not Beacons.is_beacon(Nodes.IRON_BLOCK),"the beacon block is registered")
	t.check(Beacons.POWER_MAX == 4,"the source's four pyramid levels are used")
	t.check(Nodes.exists(VillageContent.NETHER_STAR),"the nether star exists for the beacon recipe")
	# The four source mineral blocks are beacon blocks, and stone is not.
	for block in [Nodes.IRON_BLOCK,Nodes.GOLD_BLOCK,Nodes.DIAMOND_BLOCK,VillageContent.EMERALD_BLOCK]:
		t.check(Beacons.pyramid_block(block),"a beacon pyramid accepts block %d"%block)
	t.check(not Beacons.pyramid_block(Nodes.STONE) and not Beacons.pyramid_block(Nodes.COBBLE),"stone and cobble are not beacon blocks")

	# --- pyramid power -----------------------------------------------------
	plot(world,base)
	t.check(Beacons.power(world,beacon) == 0,"a beacon with no pyramid has no power")
	build_pyramid(world,beacon,1,Nodes.IRON_BLOCK)
	t.check(Beacons.power(world,beacon) == 1,"one pyramid layer gives power one")
	build_pyramid(world,beacon,2,Nodes.IRON_BLOCK)
	t.check(Beacons.power(world,beacon) == 2,"two layers give power two")
	build_pyramid(world,beacon,3,Nodes.GOLD_BLOCK)
	t.check(Beacons.power(world,beacon) == 3,"three layers give power three")
	build_pyramid(world,beacon,4,Nodes.DIAMOND_BLOCK)
	t.check(Beacons.power(world,beacon) == 4,"four complete layers give the maximum power of four")
	# A single wrong block caps the power at the layer below it.
	plot(world,base); build_pyramid(world,beacon,3,Nodes.IRON_BLOCK)
	world.set_node(beacon-Vector3i(0,3,0),Nodes.STONE)
	t.check(Beacons.power(world,beacon) == 2,"one wrong block in the third layer caps power at two")
	# A gap in the first layer removes power entirely.
	plot(world,base); build_pyramid(world,beacon,2,Nodes.IRON_BLOCK)
	world.set_node(beacon-Vector3i(1,1,0),Nodes.AIR)
	t.check(Beacons.power(world,beacon) == 0,"a gap in the first layer leaves no power")

	# --- effects and range -------------------------------------------------
	t.check(Beacons.effect_range(1) == 20.0 and Beacons.effect_range(4) == 50.0,"range follows the source's (power+1)*10")
	t.check(Beacons.effect_range(0) == 10.0,"power zero has the source's minimum range")
	# Power gates the available effects.
	var at_one: Array = Beacons.available(1)
	t.check(at_one.has("swiftness") and at_one.has("haste"),"swiftness and haste need only power one")
	t.check(not at_one.has("resistance") and not at_one.has("strength") and not at_one.has("regeneration"),"higher effects are not available at power one")
	var at_two: Array = Beacons.available(2)
	t.check(at_two.has("resistance") and at_two.has("leaping") and not at_two.has("strength"),"resistance and leaping need power two")
	var at_four: Array = Beacons.available(4)
	t.check(at_four.size() == 6 and at_four.has("strength") and at_four.has("regeneration"),"all six effects are available at the maximum power")
	t.check(Beacons.available(0).is_empty(),"no effects are available without a pyramid")

	# --- effects reach the player ------------------------------------------
	plot(world,base); build_pyramid(world,beacon,4,Nodes.IRON_BLOCK)
	world.set_node(beacon,VillageContent.BEACON)
	Beacons.registered(world,beacon,VillageContent.BEACON)
	world.stations[world.station_key(beacon)]["effect"] = "swiftness"
	PotionEffects.clear(game.player)
	game.player.position = Vector3(beacon)+Vector3(0.5,0.5,0.5)
	for i in 3: Beacons.update(world,1.0)
	t.check(PotionEffects.level(game.player,"swiftness") > 0,"a beacon grants its effect to a player in range")
	t.check(PotionEffects.level(game.player,"regeneration") > 0,"a maximum-power beacon also grants the source's second effect")
	# Out of range there is no effect.
	PotionEffects.clear(game.player)
	game.player.position = Vector3(beacon)+Vector3(0,0.5,200)
	for i in 3: Beacons.update(world,1.0)
	t.check(PotionEffects.level(game.player,"swiftness") == 0,"a player beyond the beacon's range gets no effect")
	# A beacon with no pyramid grants nothing.
	PotionEffects.clear(game.player)
	plot(world,base); world.set_node(beacon,VillageContent.BEACON)
	Beacons.registered(world,beacon,VillageContent.BEACON)
	game.player.position = Vector3(beacon)+Vector3(0.5,0.5,0.5)
	for i in 3: Beacons.update(world,1.0)
	t.check(PotionEffects.level(game.player,"swiftness") == 0,"a beacon with no pyramid grants no effect")
	PotionEffects.clear(game.player)

	# --- the beam ----------------------------------------------------------
	plot(world,base)
	world.set_node(beacon,VillageContent.BEACON)
	t.check(Beacons.beam_length(world,beacon) > 0,"a beacon with open sky above has a beam")
	world.set_node(beacon+Vector3i(0,3,0),Nodes.STONE)
	t.check(Beacons.beam_length(world,beacon) < 3,"a solid block stops the beam")
	world.set_node(beacon+Vector3i(0,3,0),Nodes.AIR)
	t.check(Beacons.beam_color(world,beacon) == Color("ffffff"),"a beacon with no glass above has a white beam")

	# --- interaction -------------------------------------------------------
	plot(world,base); build_pyramid(world,beacon,2,Nodes.IRON_BLOCK)
	world.set_node(beacon,VillageContent.BEACON)
	Beacons.registered(world,beacon,VillageContent.BEACON)
	t.check(Beacons.use(game,{"pos":beacon,"normal":Vector3i.UP,"id":VillageContent.BEACON,"distance":1.0,"point":Vector3(beacon)}),"using a beacon is handled")
	var chosen: String = str(world.stations[world.station_key(beacon)].get("effect",""))
	t.check(Beacons.available(2).has(chosen),"using a beacon selects one of its available effects")
	# A beacon with no pyramid refuses and says why.
	plot(world,base)
	world.set_node(beacon,VillageContent.BEACON)
	t.check(Beacons.use(game,{"pos":beacon,"normal":Vector3i.UP,"id":VillageContent.BEACON,"distance":1.0,"point":Vector3(beacon)}),"using a beacon with no pyramid is handled")

	# --- recipe, art and mesh ----------------------------------------------
	var inv := Inventory.new()
	var index: int = inv.recipe_index(VillageContent.BEACON)
	t.check(index >= 0,"the beacon has its source recipe")
	if index >= 0:
		var recipe: Dictionary = inv.recipes[index]
		t.check(recipe.ingredients.get(VillageContent.NETHER_STAR,0) == 1,"the beacon recipe needs one nether star")
		t.check(recipe.ingredients.get(Nodes.GLASS,0) == 5 and recipe.ingredients.get(Nodes.OBSIDIAN,0) == 3,"the beacon recipe uses the source's five glass and three obsidian")
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Beacons.draw(art,VillageContent.BEACON)
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"the beacon draws a non-empty icon")
	t.check(Pasture.emission(world,beacon) == 15,"the beacon lights at the source maximum")
	plot(world,base)
	var coord := Vector3i(beacon.x/16,beacon.y/16,beacon.z/16)
	var before: int = chunk_verts(world,coord)
	world.set_node(beacon,VillageContent.BEACON)
	t.check(chunk_verts(world,coord) > before,"the chunk mesher emits geometry for a beacon")

	Beacons.reset(world)
	for x in range(-8,9):
		for z in range(-8,9):
			for y in range(8): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)

static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0
