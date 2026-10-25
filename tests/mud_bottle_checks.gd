extends RefCounted

const P = Vector3i(8,2500,8)

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}

static func target(game: Node3D, p: Vector3i) -> void:
	game.player.target = {"pos":p,"id":game.world.node_at(p),"normal":Vector3i.BACK,"distance":1.0}

static func run(t: SceneTree, game: Node3D) -> void:
	game.state = "playing"; game.gamemode = "survival"; game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(ensure(game,P),"mud-bottle plot column is loaded")
	for host in [Nodes.DIRT,DryTerrain.COARSE_DIRT,LushCaveExtra.ROOTED_DIRT]:
		game.world.set_node(P,host); game.world.set_node(P+Vector3i.BACK,DryTerrain.COARSE_DIRT)
		held(game,VillageContent.WATER_BOTTLE); target(game,P); game.survival.use()
		t.check(game.world.node_at(P) == VillageContent.MUD and game.world.node_at(P+Vector3i.BACK) == DryTerrain.COARSE_DIRT,"direct conversion targets only the pointed host "+str(host))
		t.check(game.inventory.count_item(VillageContent.WATER_BOTTLE) == 0 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 1,"survival conversion exchanges water for one empty bottle "+str(host))
		game.inventory.restore([])
	game.gamemode = "creative"; game.world.set_node(P,LushCaveExtra.ROOTED_DIRT)
	held(game,VillageContent.WATER_BOTTLE); target(game,P); game.survival.use()
	t.check(game.world.node_at(P) == VillageContent.MUD and game.inventory.count_item(VillageContent.WATER_BOTTLE) == 1 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 0,"creative conversion preserves the water bottle and creates no glass bottle")
	game.gamemode = "survival"
	game.world.set_node(P+Vector3i.BACK,Nodes.STONE)
	t.check(not MudBottles.convert(game,P+Vector3i.BACK),"an adjacent cell is not converted by direct use")
	game.inventory.restore([])
	var dispenser: Vector3i = P-Vector3i.BACK
	game.world.set_node(dispenser,Nodes.DISPENSER); game.world.circuits.configure(dispenser,Vector3i.BACK)
	game.world.set_node(P,LushCaveExtra.ROOTED_DIRT); game.world.circuits.container(dispenser)[0] = {"id":VillageContent.WATER_BOTTLE,"count":2,"wear":0}
	game.world.circuits.dispense(dispenser,false)
	var actual_water: int = game.world.circuits.container(dispenser)[0].count
	var actual_glass: int = 0
	for slot in game.world.circuits.container(dispenser):
		if slot.id == VillageContent.GLASS_BOTTLE: actual_glass += slot.count
	var actual_node: int = game.world.node_at(P)
	t.check(actual_node == VillageContent.MUD and actual_water == 1 and actual_glass == 1 and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 0,"actual dispenser returns glass to its own inventory; node="+str(actual_node)+" water="+str(actual_water)+" glass="+str(actual_glass))
	for slot in game.world.circuits.container(dispenser): slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
	game.world.set_node(P,LushCaveExtra.ROOTED_DIRT); game.world.circuits.container(dispenser)[0] = {"id":VillageContent.WATER_BOTTLE,"count":1,"wear":0}
	game.world.circuits.dispense(dispenser,false)
	t.check(game.world.node_at(P) == VillageContent.MUD and game.world.circuits.container(dispenser)[0].id == VillageContent.GLASS_BOTTLE and game.world.circuits.container(dispenser)[0].count == 1,"a single water bottle becomes one glass bottle in the same dispenser slot")
	game.world.set_node(P,Nodes.STONE); game.world.circuits.container(dispenser)[0] = {"id":VillageContent.WATER_BOTTLE,"count":1,"wear":0}
	var result: Dictionary = Dispensers.dispense(game,dispenser,Vector3i.BACK,game.world.circuits.container(dispenser)[0])
	t.check(not result.applied and game.world.node_at(P) == Nodes.STONE and game.world.circuits.container(dispenser)[0].count == 1,"non-host dispenser conversion is refused without consuming the water bottle")
	for cell in [P,dispenser,P+Vector3i.BACK]: game.world.set_node(cell,Nodes.AIR)
