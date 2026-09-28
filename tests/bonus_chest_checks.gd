extends RefCounted

# Focused regression for the bonus chest (`mcl_bonus_chest`), the chest a new
# survival world is given beside its spawn point.
#
# The source is three small pieces and the checks follow them one at a time: the
# weighted loot table (init.lua:12-93), the site search with the chest-plus-four-
# torches placement (init.lua:130-149), and the new-survival-world offer
# (init.lua:151-161). The loot's weight and the amount ranges are re-stated here
# from the source table itself rather than read back out of the module, so the
# checks fail if the ported numbers drift.

# Every id the source's table can produce, with the amount range its entry
# carries (init.lua:12-93). An entry given without `amount_min`/`amount_max`
# yields a single item, which is why both tool groups are 1..1.
static func source_ranges() -> Dictionary:
	return {
		Nodes.TOOLS:[1,1], Nodes.TOOLS+1:[1,1], Nodes.TOOLS+5:[1,1], Nodes.TOOLS+6:[1,1],
		Nodes.APPLE:[1,3], Nodes.BREAD:[1,2], VillageContent.RAW_SALMON:[1,2],
		Nodes.STICK:[1,12], Nodes.PLANKS:[1,12], Nodes.BROWN_MUSHROOM:[1,12],
		WoodTypes.SAPLINGS[0]:[1,4], WoodTypes.SAPLINGS[1]:[1,4], WoodTypes.SAPLINGS[2]:[1,4],
		WoodTypes.SAPLINGS[5]:[1,4], WoodTypes.SAPLINGS[4]:[1,4], WoodTypes.SAPLINGS[3]:[1,4],
		WoodTypes.LOGS[4]:[1,3], WoodTypes.LOGS[5]:[1,3], WoodTypes.LOGS[2]:[1,3],
		WoodTypes.LOGS[3]:[1,3], WoodTypes.LOGS[0]:[1,3], WoodTypes.LOGS[1]:[1,3],
		VillageContent.POTATO:[1,2], VillageContent.CARROT:[1,2],
		FruitCrops.PUMPKIN_SEEDS:[1,2], FruitCrops.MELON_SEEDS:[1,2], VillageContent.BEETROOT_SEEDS:[1,2],
		VillageContent.COCOA_BEANS:[1,2], Nodes.CACTUS:[1,2],
	}

# The id/count pairs of a slot list, sorted, so two rolls compare regardless of
# the slot each stack landed in.
static func pairs(slots: Array) -> Array:
	var out: Array = []
	for slot in slots:
		if int(slot.id) != 0: out.append([int(slot.id),int(slot.count)])
	out.sort_custom(func(a,b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return out

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_mode: String = game.gamemode
	game.gamemode = "survival"

	# --- the loot table ------------------------------------------------------
	suite.check(BonusChest.GROUPS.size() == 14,"the source's table has fourteen loot groups")
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var chest: Array = BonusChest.roll(rng)
	suite.check(chest.size() == 14,"a chest rolls one stack from each of the source's fourteen groups — never none and never two")
	var bounds: Dictionary = source_ranges()
	var valid: bool = true
	for item in chest:
		var id: int = int(item.id)
		if not Nodes.exists(id) or not bounds.has(id): valid = false; continue
		if int(item.count) < bounds[id][0] or int(item.count) > bounds[id][1]: valid = false
		if typeof(item.count) != TYPE_INT or typeof(item.id) != TYPE_INT or typeof(item.get("wear",-1)) != TYPE_INT: valid = false
		if not item.get("data",null) is Dictionary: valid = false
	suite.check(valid,"every rolled item exists as a real Voxey item and its count stays inside the source's range")
	# The chest's contents are a function of its position and the world seed
	# (init.lua:131), so the same seed must roll the same chest.
	var again := RandomNumberGenerator.new(); again.seed = 4242
	suite.check(JSON.stringify(BonusChest.roll(again)) == JSON.stringify(chest),"the same seed rolls an identical chest")
	var other := RandomNumberGenerator.new(); other.seed = 4243
	suite.check(JSON.stringify(BonusChest.roll(other)) != JSON.stringify(chest),"a different seed rolls a different chest")

	# The two tool groups keep their own entries: every chest carries exactly one
	# stack of each, and the source's 3:1 wood-to-stone weighting survives.
	var axes: int = 0; var picks: int = 0; var wood_axes: int = 0; var wood_picks: int = 0
	var stacks: int = 0; var max_stacks: int = 0
	var sample := RandomNumberGenerator.new(); sample.seed = 99
	for i in 400:
		var items: Array = BonusChest.roll(sample)
		stacks += items.size(); max_stacks = maxi(max_stacks,items.size())
		for item in items:
			match int(item.id):
				BonusChest.AXE_WOOD: axes += 1; wood_axes += 1
				BonusChest.AXE_STONE: axes += 1
				BonusChest.PICK_WOOD: picks += 1; wood_picks += 1
				BonusChest.PICK_STONE: picks += 1
	suite.check(axes == 400 and picks == 400 and max_stacks == 14 and stacks == 400*14,"the axe and pickaxe groups each fill exactly one slot of every chest")
	suite.check(float(wood_axes)/float(400-wood_axes) > 2.0 and float(wood_axes)/float(400-wood_axes) < 5.0 and float(wood_picks)/float(400-wood_picks) > 2.0 and float(wood_picks)/float(400-wood_picks) < 5.0,"the wooden tools carry the source's three-to-one weight over the stone ones")

	# --- placement -----------------------------------------------------------
	# A three-by-three stone shelf in the sky, with a wide volume above it cleared,
	# so the chest site is unambiguous. One neighbour is deliberately occupied, as
	# the source only places a torch where the neighbour is `buildable_to`.
	var p := Vector3i(8,70,8)
	var volume: Array = []
	for x in range(p.x-4,p.x+5):
		for z in range(p.z-4,p.z+5):
			for y in range(p.y-3,p.y+4): volume.append(Vector3i(x,y,z))
	for at in volume: world.set_node(at,Nodes.AIR)
	for x in range(p.x-1,p.x+2):
		for z in range(p.z-1,p.z+2): world.set_node(Vector3i(x,p.y-1,z),Nodes.STONE)
	var blocked: Vector3i = p+Vector3i.LEFT
	world.set_node(blocked,Nodes.STONE)
	suite.check(BonusChest.place(game,p),"a chest is placed in a clear cell above a solid support")
	suite.check(world.node_at(p) == Nodes.CHEST,"the chest node stands in that cell")

	var station: Dictionary = world.get_station(p,"chest")
	var expected: Array = BonusChest.roll(BonusChest.rng_at(world,p))
	suite.check(station.get("kind","") == "chest" and station.slots.size() == 27,"the chest opens a twenty-seven slot station")
	suite.check(pairs(station.slots) == pairs(expected),"the station holds exactly the loot its own position and the world seed roll")
	suite.check(pairs(station.slots).size() == 14,"the placed chest holds all fourteen stacks")

	var torches: Array = []
	for side in BonusChest.SIDES:
		if world.node_at(p+side) == Nodes.TORCH: torches.append(p+side)
	suite.check(torches.size() == 3 and world.node_at(blocked) == Nodes.STONE,"the four neighbours take a torch each except the occupied one, which is left alone")
	var supported: bool = true
	for t in torches: supported = supported and Nodes.solid(world.node_at(t+Vector3i.DOWN))
	suite.check(supported,"every placed torch stands on a solid neighbour")
	suite.check(not BonusChest.place(game,p) and world.node_at(p) == Nodes.CHEST,"placing over the chest is refused and nothing is overwritten")
	suite.check(not BonusChest.place(game,blocked) and world.node_at(blocked) == Nodes.STONE,"a cell that is not air is never overwritten")

	# --- the new-world offer -------------------------------------------------
	suite.check(BonusChest.should_offer("survival") and not BonusChest.should_offer("creative"),"only a survival world is offered a bonus chest")
	var saved_state: Dictionary = world.adventure_state.duplicate(true)
	for at in volume: world.set_node(at,Nodes.AIR)
	world.stations.erase(VoxelWorld.station_key(p))
	world.adventure_state.erase(BonusChest.DEPLOYED)
	for x in range(p.x-1,p.x+2):
		for z in range(p.z-1,p.z+2): world.set_node(Vector3i(x,p.y-1,z),Nodes.STONE)
	game.gamemode = "creative"
	suite.check(not BonusChest.offer(game,Vector3(p)),"a creative world is not offered a chest")
	game.gamemode = "survival"
	suite.check(BonusChest.offer(game,Vector3(p)),"a new survival world is offered a chest")
	var placed: Array = []
	for x in range(p.x-6,p.x+7):
		for z in range(p.z-6,p.z+7):
			for y in range(p.y-4,p.y+4):
				if world.node_at(Vector3i(x,y,z)) == Nodes.CHEST: placed.append(Vector3i(x,y,z))
	suite.check(placed.size() == 1,"the offer puts exactly one chest within the source's search box")
	if placed.size() == 1:
		suite.check(pairs(world.get_station(placed[0],"chest").slots).size() == 14,"the offered chest is filled from the same table")
	suite.check(not BonusChest.offer(game,Vector3(p)),"the deployed flag stops a second chest in the same world")

	# --- restore -------------------------------------------------------------
	for x in range(p.x-6,p.x+7):
		for z in range(p.z-6,p.z+7):
			for y in range(p.y-4,p.y+4): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for at in placed: world.stations.erase(VoxelWorld.station_key(at))
	world.adventure_state = saved_state
	game.gamemode = old_mode
