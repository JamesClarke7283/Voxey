extends RefCounted

static func run(t: SceneTree, game: Node) -> void:
	for entry in [[Nodes.SEEDS,30],[Nodes.VINE,50],[Nodes.APPLE,65],[Nodes.BREAD,85],[Nodes.PUMPKIN_PIE,100],[Nodes.STONE,0]]:
		t.check(Composters.chance(entry[0]) == entry[1],"compostability of %s matches source"%Nodes.title(entry[0]))
	var state: Dictionary = {"kind":"composter","slots":[]}
	t.check(Composters.add(state,Nodes.SEEDS,31) and Composters.level(state) == 0,"failed compost roll consumes a valid ingredient without adding a layer")
	t.check(not Composters.add(state,Nodes.STONE,1),"inorganic items are not consumed")
	t.check(Composters.add(state,Nodes.SEEDS,30) and Composters.level(state) == 1,"compost probability includes its upper boundary")
	for i in 6: Composters.add(state,Nodes.PUMPKIN_PIE,100)
	t.check(Composters.level(state) == 7 and not Composters.add(state,Nodes.APPLE) and not Composters.harvest(state),"full compost blocks insertion and harvest until mature")
	Composters.step(state,0.6)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(state))
	Composters.step(restored,0.39)
	t.check(Composters.level(restored) == 7,"saved composter retains its remaining maturation time")
	Composters.step(restored,0.02)
	t.check(Composters.level(restored) == 8 and Composters.harvest(restored) and not Composters.harvest(restored),"maturation produces exactly one harvest then resets")
	var inv := Inventory.new()
	inv.add_item(BuildingShapes.slab_for(Nodes.PLANKS),7)
	t.check(inv.craft(inv.recipe_index(VillageContent.COMPOSTER),"table") and inv.count_item(VillageContent.COMPOSTER) == 1,"seven wooden slabs craft a composter")
	var p := Vector3i(12,72,12)
	game.world.set_node(p,VillageContent.COMPOSTER)
	var station: Dictionary = game.world.get_station(p,"composter")
	station.compost = 3
	t.check(game.world.circuits.container_signal(p) == 3,"comparator reads current compost level")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.COMPARATOR)
	game.world.circuits.configure(p+Vector3i.RIGHT,Vector3i.RIGHT)
	game.world.circuits.step(0.1)
	t.check(game.world.circuits.state(p+Vector3i.RIGHT).get("out",0) == 3,"live comparator propagates compost signal through the circuit")
	game.world.set_node(p+Vector3i.UP,Nodes.HOPPER)
	game.world.circuits.configure(p+Vector3i.UP,Vector3i.DOWN)
	var upper: Array = game.world.get_station(p+Vector3i.UP,"chest").slots
	upper[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	upper[1] = {"id":Nodes.PUMPKIN_PIE,"count":4,"wear":0}
	for i in 4: game.world.circuits.hopper(p+Vector3i.UP)
	t.check(Composters.level(station) == 7 and upper[0].count == 1 and upper[1].count == 0,"top hopper skips inorganic slots and feeds one eligible item per transfer")
	Composters.step(station,1)
	game.world.set_node(p+Vector3i.DOWN,Nodes.HOPPER)
	game.world.circuits.configure(p+Vector3i.DOWN,Vector3i.DOWN)
	var lower: Array = game.world.get_station(p+Vector3i.DOWN,"chest").slots
	for i in lower.size(): lower[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	game.world.circuits.hopper(p+Vector3i.DOWN)
	t.check(Composters.level(station) == 8,"full output hopper leaves ready bone meal in the composter")
	lower[0] = {"id":0,"count":0,"wear":0}
	game.world.circuits.hopper(p+Vector3i.DOWN)
	t.check(lower[0].id == Nodes.BONE_MEAL and lower[0].count == 1 and Composters.level(station) == 0,"bottom hopper extracts a single bone meal and empties composter")
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.add_item(Nodes.PUMPKIN_PIE,1)
	game.gamemode = "survival"
	Composters.interact(game,p)
	t.check(game.inventory.held().id == 0 and Composters.level(station) == 1,"player insertion consumes one held item")
	station.compost = 8
	var count_before: int = game.drops.get_child_count()
	Composters.interact(game,p)
	t.check(game.drops.get_child_count() == count_before+1 and Composters.level(station) == 0,"manual harvest creates the source bone meal pickup")
	station.compost = 5
	game.break_node(p,VillageContent.COMPOSTER,81)
	t.check(not game.world.stations.has(VoxelWorld.station_key(p)),"breaking a composter discards its compost state")
