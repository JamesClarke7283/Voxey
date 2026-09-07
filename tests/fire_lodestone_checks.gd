extends RefCounted
static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause(); game.gamemode = "survival"; game.player.health = 20
	var p: Vector3i = Vector3i(game.player.position.floor())+Vector3i(0,3,3)
	for x in range(-2,3):
		for z in range(-2,3):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(3): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.NETHERRACK)
	suite.check(Fire.ignite(game.world,p) and game.world.node_at(p) == Fire.ETERNAL,"netherrack supports eternal fire")
	for i in 30: Fire.update(game.world)
	suite.check(game.world.node_at(p) == Fire.ETERNAL,"eternal fire persists without nearby fuel")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.WATER); Fire.update(game.world)
	suite.check(game.world.node_at(p) == Nodes.AIR,"adjacent water extinguishes eternal fire")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":PiglinBarter.FIRE_CHARGE,"count":2,"wear":0}
	var target: Dictionary = {"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE}
	suite.check(Fire.use(game,target) and game.world.node_at(p) == Fire.FLAME and game.inventory.held().count == 1,"using a fire charge ignites air and consumes one charge")
	Fire.use(game,target)
	suite.check(game.inventory.held().count == 1,"failed ignition leaves its fire charge intact")
	game.world.set_node(p,Nodes.AIR)
	game.inventory.slots[0] = {"id":Nodes.FLINT_AND_STEEL,"count":1,"wear":64}
	Fire.use(game,target)
	suite.check(game.inventory.held().id == 0 and game.world.node_at(p) == Fire.FLAME,"flint and steel wears out on its sixty-fifth successful ignition")
	game.break_node(p,Fire.FLAME,0)
	suite.check(game.world.node_at(p) == Nodes.AIR,"punching fire extinguishes it safely")
	var lava: Vector3i = p+Vector3i(1,0,1)
	game.world.set_node(lava,Nodes.LAVA)
	suite.check(not game.world.hazards.has(lava),"isolated lava does not add per-tick fire simulation work")
	game.world.set_node(lava+Vector3i.RIGHT,Nodes.PLANKS)
	suite.check(game.world.hazards.has(lava),"placing fuel beside lava activates its ignition checks")
	game.world.set_node(lava+Vector3i.RIGHT,Nodes.STONE)
	suite.check(not game.world.hazards.has(lava),"removing nearby fuel stops unnecessary lava ignition checks")
	game.world.set_node(p,Bastions.LODESTONE)
	game.inventory.slots[0] = {"id":Nodes.COMPASS,"count":2,"wear":0}
	suite.check(Lodestones.bind(game,p) and game.inventory.held().count == 1,"binding one compass keeps the remaining unbound stack")
	var bound: Dictionary = {}
	for slot in game.inventory.slots:
		if slot.id == Nodes.COMPASS and slot.get("data",{}).has("lodestone"): bound = slot
	suite.check(not bound.is_empty() and bound.data.lodestone.dimension == "nether" and bound.data.lodestone.position == [p.x,p.y,p.z],"bound compass stores its lodestone position and dimension")
	suite.check(Inventory.clean_slot(bound) == bound and "Lodestone lies" in Lodestones.describe(game,bound),"lodestone compass metadata survives normalization and gives a bearing")
	game.world.set_node(p,Nodes.AIR)
	suite.check("lodestone is gone" in Lodestones.describe(game,bound),"destroying a loaded lodestone breaks its compass tracking")
	var off_dimension: Dictionary = bound.duplicate(true); off_dimension.data.lodestone.dimension = "overworld"
	suite.check("spins in this dimension" in Lodestones.describe(game,off_dimension),"lodestone compasses do not point across dimensions")
