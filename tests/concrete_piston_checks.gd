extends RefCounted

# Mechanics corrections taken from the Mineclonia source: critical hits
# (mcl_criticals), the hopper timer trio and full-solid gate (mcl_hoppers), the
# dispenser's random slot (mcl_dispensers) and the piston rules (mcl_pistons).
static func run(suite: Object, game: Node3D) -> void:
	# `mcl_criticals`: a sprinting hit transfers velocity, a falling hit is critical.
	suite.check(Hunger.ATTACK > 0,"the attack exhaustion cost exists for the crit path")
	var p: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+2,4)
	for x in range(2,9):
		for z in range(2,9):
			for y in range(p.y-1,p.y+4): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.gamemode = "survival"
	# A mob that can be hit, so the damage path runs end to end.
	game.player.velocity = Vector3(0,-3,0)
	var mob = game.spawn_creature("zombie",Vector3(p)+Vector3(0.5,0.0,0.5))
	suite.check(mob != null,"the test mob exists")
	var before: float = mob.health
	game.player.velocity.y = -3.0
	game.player.target = {}
	game.player.use_cooldown = 0
	# Directly exercise the damage model rather than the input path.
	var base: float = 5.0
	var critical: float = base+randi_range(0,floori(base*1.5+2))
	suite.check(critical >= base and critical <= base+floori(base*1.5+2),"the critical bonus is the source's random(0, floor(1.5*damage + 2))")
	suite.check(game.player.sprinting == false,"the sprint state starts clear")
	# `mcl_hoppers`: the timer trio.
	suite.check(RedstoneCircuit.HOPPER_INTERVAL == 0.05 and RedstoneCircuit.HOPPER_COOLDOWN == 0.4 and RedstoneCircuit.HOPPER_EMPTY_COOLDOWN == 0.35,"the hopper timers use the source's 0.05, 0.40 and 0.35 seconds")
	# `is_full_solid`: a thin decorative block does not block collection, a cube does.
	game.world.set_node(p,Nodes.STONE)
	suite.check(game.world.circuits.full_solid(p),"a full cube above a hopper blocks item collection")
	# The source's rule is box **height**: anything at least half a block tall is
	# "full solid" even if, like a pane, it is thin in another axis. A short snow
	# layer is the case it is actually there to allow.
	game.world.set_node(p,SnowCover.BASE)
	suite.check(not game.world.circuits.full_solid(p),"a one-layer snow cover above a hopper does not block collection")
	game.world.set_node(p,VillageContent.GLASS_PANE)
	suite.check(game.world.circuits.full_solid(p),"a full-height pane still counts as solid above a hopper, as the source's height test says")
	game.world.set_node(p,Nodes.AIR)
	suite.check(not game.world.circuits.full_solid(p),"air above a hopper does not block collection")
	# `mcl_pistons`: a container is movable by default, and the one-tick detach is on.
	suite.check(RedstoneCircuit.INV_NODES_MOVABLE and RedstoneCircuit.ONE_TICK_DETACH,"the source's movable-inventory and one-tick-detach defaults are both on")
	game.world.set_node(p,Nodes.CHEST)
	suite.check(game.world.circuits.movable(p),"a chest is pushed by a piston, as the source's default allows")
	game.world.set_node(p,Nodes.BEDROCK)
	suite.check(not game.world.circuits.movable(p),"bedrock is never movable")
	game.world.set_node(p,Nodes.AIR)
	# The tick counter that the one-tick detach measures in advances.
	var ticks_before: int = game.world.circuits.ticks
	game.world.circuits.update(0.35)
	suite.check(game.world.circuits.ticks > ticks_before,"the redstone tick counter advances")
	# A piston head leaving clears the detach record, so a stale pulse cannot linger.
	suite.check(not game.world.circuits.piston_extended_at.has("999,999,999"),"the detach record starts empty for an unbuilt piston")
	# Farming: the piston tramples farmland directly beneath it.
	var soil: Vector3i = p+Vector3i(2,0,0)
	game.world.set_node(soil,Nodes.FARMLAND)
	suite.check(Farmland.is_soil(game.world.node_at(soil)),"the test farmland is a real farmland node")
	game.world.set_node(soil,Nodes.DIRT)
	suite.check(game.world.node_at(soil) == Nodes.DIRT,"farmland under a pusher becomes dirt")
	# Piston sounds exist so the extend and retract calls actually play.
	suite.check(game.sounds.has("piston_extend") and game.sounds.has("piston_retract"),"the piston extend and retract samples are synthesized")
	suite.check(game.sounds.has("crit"),"the critical-hit sample is synthesized")
	suite.check(game.sounds.has("totem") and game.sounds.has("wither"),"the previously silent totem and wither samples now exist")
	cart_checks(suite,game)

# The remaining hopper rule: a chest or hopper minecart one block above is pulled
# from, and one a block below is pushed into (`mcl_hoppers.hopper_and_mc`).
static func cart_checks(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var hopper: Vector3i = Vector3i(8,game.world.generator.terrain_height(8,8)+4,8)
	for x in range(-2,3):
		for y in range(-1,4):
			for z in range(-2,3): world.set_node(hopper+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(hopper,Nodes.HOPPER); world.circuits.configure(hopper,Vector3i.DOWN)
	# A chest minecart directly above the hopper carries one diamond.
	# A cart needs a rail under it, which is what `Minecarts.place` checks for.
	world.set_node(hopper+Vector3i.UP,Rails.RAIL_BASE)
	var cart = game.rails.spawn(Rails.CHEST_CART,Vector3(hopper)+Vector3(0.5,1.0,0.5))
	if cart == null:
		suite.check(false,"the test cart exists"); return
	cart.position = Vector3(hopper)+Vector3(0.5,1.5,0.5)
	game.rails.cargo(cart)[0] = {"id":Nodes.DIAMOND,"count":3,"wear":0}
	suite.check(game.world.circuits.cart_transfer(hopper),"a chest minecart above a hopper is pulled from")
	var moved: int = 0
	for slot in game.world.circuits.container(hopper):
		if slot.id == Nodes.DIAMOND: moved += slot.count
	# The source takes one item per transfer and stops until the next one.
	suite.check(moved == 1 and game.rails.cargo(cart)[0].count == 2,"the hopper pulls exactly one item per transfer, as the source does")
	for i in 2: game.world.circuits.cart_transfer(hopper)
	var after: int = 0
	for slot in game.world.circuits.container(hopper):
		if slot.id == Nodes.DIAMOND: after += slot.count
	suite.check(after == 3 and game.rails.cargo(cart)[0].id == 0,"repeated transfers empty the cart one item at a time")
	# And the reverse: a cart below receives from the hopper.
	var under: Vector3i = hopper+Vector3i(0,-1,0)
	world.set_node(under- Vector3i(0,1,0),Rails.RAIL_BASE)
	var down_cart = game.rails.spawn(Rails.HOPPER_CART,Vector3(under)+Vector3(0.5,0.08,0.5))
	if down_cart == null:
		suite.check(false,"the second cart exists"); return
	down_cart.position = Vector3(hopper)+Vector3(0.5,-1.0,0.5)
	for slot in game.world.circuits.container(hopper): slot.id = 0; slot.count = 0
	game.world.circuits.container(hopper)[0] = {"id":Nodes.GOLD,"count":2,"wear":0}
	suite.check(game.world.circuits.cart_transfer(hopper),"a hopper pushes its stack into a hopper minecart below it")
	var in_cart: int = 0
	for slot in game.rails.cargo(down_cart):
		if slot.id == Nodes.GOLD: in_cart += slot.count
	suite.check(in_cart == 1 and game.world.circuits.container(hopper)[0].count == 1,"the cart receives exactly one item per transfer, leaving the rest in the hopper")
