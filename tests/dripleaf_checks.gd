extends RefCounted

# Focused live-world regression for Mineclonia dripleaf physics and attached lush
# ceiling plants. The isolated plot and explicit player records keep the checks
# deterministic and independent of other suites or frame ordering.
const Y = 2300
const BIG = LushCaveExtra.DRIPLEAF_BIG
const HALF = LushCaveExtra.DRIPLEAF_BIG_TIPPED_HALF
const FULL = LushCaveExtra.DRIPLEAF_BIG_TIPPED_FULL

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	world._apply_column(world.generator.generate_column(column,world.edits))
	return world.loaded_at(Vector3(p))

static func clear(world: VoxelWorld) -> void:
	for x in 16:
		for z in 16:
			for y in range(Y-4,Y+12): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	LushCaveExtra.reset(world)

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":{}}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func click(game: Node3D, support: Vector3i, normal: Vector3i) -> void:
	game.player.target = {"pos":support,"id":game.world.node_at(support),"normal":normal,"point":Vector3(support)+Vector3.ONE*0.5,"distance":2.0}
	game.player.use()

static func drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func feet(p: Vector3i, offset: Vector3 = Vector3.ZERO) -> Vector3:
	return Vector3(p)+Vector3(0.5,1.0,0.5)+offset

static func sample(key: Variant, position: Vector3) -> Dictionary:
	return {"key":key,"position":position}

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var p := Vector3i(8,Y,8)
	t.check(ensure(game,p),"dripleaf test column loads through the real world generator")
	clear(world)
	game.player.position = Vector3(2,Y+5,2)

	# IDs and the real collision dispatcher retain all three physical forms.
	t.check(BIG == 11479 and HALF == 11480 and FULL == 11481,"dripleaf content IDs remain stable")
	for id in [BIG,HALF]:
		world.set_node(p,id)
		var boxes: Array = world.collision_boxes(p)
		t.check(LushCaveExtra.walkable(id) and Nodes.solid(id),"upright/half dripleaf remains walkable for "+str(id))
		t.check(boxes.size() == 1 and boxes[0].position.is_equal_approx(Vector3(0,0.95,0)) and boxes[0].size.is_equal_approx(Vector3(1,0.05,1)),"world collision uses the source's exact top plate for "+str(id))
		t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.9,0.5),0.2,0.05),"actor passes below the thin plate rather than hitting a unit cube for "+str(id))
		t.check(world.intersects(Vector3(p)+Vector3(0.5,0.96,0.5),0.2,0.05),"actor intersection collides with the actual top plate for "+str(id))
	world.set_node(p,FULL)
	t.check(not LushCaveExtra.walkable(FULL) and not Nodes.solid(FULL) and world.collision_boxes(p).is_empty(),"full-tipped dripleaf is non-walkable and has no live collision")
	t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.9,0.5),0.2,0.05),"full-tipped collision lets the actor pass through the leaf cell")

	# Actual Player.use placement: a spore blossom needs its source ceiling type;
	# hanging roots additionally require an underside click and a walkable support.
	world.set_node(p+Vector3i.UP,Nodes.STONE)
	held(game,LushCaveExtra.SPORE_BLOSSOM); click(game,p+Vector3i.UP,Vector3i.DOWN)
	t.check(world.node_at(p) == LushCaveExtra.SPORE_BLOSSOM and game.inventory.held().count == 0,"player places a spore blossom below an opaque support")
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.UP,Nodes.GLASS)
	held(game,LushCaveExtra.SPORE_BLOSSOM); click(game,p+Vector3i.UP,Vector3i.DOWN)
	t.check(world.node_at(p) == Nodes.AIR and game.inventory.held().count == 1,"non-opaque glass rejects spore-blossom placement without consumption")
	var roots := p+Vector3i(3,0,0)
	world.set_node(roots+Vector3i.RIGHT,Nodes.STONE)
	held(game,LushCaves.HANGING_ROOTS); click(game,roots+Vector3i.RIGHT,Vector3i.LEFT)
	t.check(world.node_at(roots) == Nodes.AIR and game.inventory.held().count == 1,"hanging roots reject a side-face placement")
	world.set_node(roots+Vector3i.UP,Nodes.STONE)
	click(game,roots+Vector3i.UP,Vector3i.DOWN)
	t.check(world.node_at(roots) == LushCaves.HANGING_ROOTS and game.inventory.held().count == 0,"hanging roots place from a walkable block's underside")

	# Support changes run through VoxelWorld.set_node. Attached loss uses no shears,
	# so roots drop nothing while the spore blossom drops itself.
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.UP,Nodes.STONE); world.set_node(p,LushCaveExtra.SPORE_BLOSSOM)
	world.set_node(p+Vector3i.UP,Nodes.GLASS)
	t.check(world.node_at(p) == LushCaveExtra.SPORE_BLOSSOM,"post-placement attached support checks walkability rather than repeating the opacity gate")
	var before: int = drops(game,LushCaveExtra.SPORE_BLOSSOM)
	world.set_node(p+Vector3i.UP,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and drops(game,LushCaveExtra.SPORE_BLOSSOM) == before+1,"removing a spore blossom's support removes and drops it once")
	before = drops(game,LushCaves.HANGING_ROOTS); world.set_node(roots+Vector3i.UP,Nodes.AIR)
	t.check(world.node_at(roots) == Nodes.AIR and drops(game,LushCaves.HANGING_ROOTS) == before,"removing hanging-root support preserves its empty ordinary drop")

	# The complete 0.58-wide X/Z footprint can hold two leaves at once. Moving off
	# one cell abandons only that cell's hold.
	var left := p+Vector3i(0,2,0); var right := left+Vector3i.RIGHT
	world.set_node(left,BIG); world.set_node(right,BIG)
	LushCaveExtra.update(world,0.25,[sample(1,feet(left,Vector3(0.5,0,0)))])
	var holds: Dictionary = LushCaveExtra.runtime(world).holds
	t.check(holds.has(1) and holds[1].has(left) and holds[1].has(right),"one player's full collision span holds both adjacent leaves")
	LushCaveExtra.update(world,0.01,[sample(1,feet(left))])
	t.check(holds[1].has(left) and not holds[1].has(right),"leaving one leaf resets its abandoned hold without resetting the other")

	# Leaving and returning starts at zero; the upright transition is strictly past
	# 0.5 s, followed by independent 0.5 s and 3.0 s node timers.
	LushCaveExtra.reset(world)
	LushCaveExtra.update(world,0.4,[sample(1,feet(left))])
	LushCaveExtra.update(world,0.1,[])
	LushCaveExtra.update(world,0.2,[sample(1,feet(left))])
	t.check(world.node_at(left) == BIG,"an abandoned hold does not accumulate while the player is away")
	LushCaveExtra.update(world,0.3,[sample(1,feet(left))])
	t.check(world.node_at(left) == BIG,"exactly 0.5 s of a fresh hold has not passed the source threshold")
	LushCaveExtra.update(world,0.01,[sample(1,feet(left))])
	t.check(world.node_at(left) == HALF,"standing beyond 0.5 s produces the half-tipped stage")
	LushCaveExtra.update(world,0.49,[])
	t.check(world.node_at(left) == HALF,"half tip waits for its own 0.5 s node timer")
	LushCaveExtra.update(world,0.01,[])
	t.check(world.node_at(left) == FULL,"half tip advances to full tip after 0.5 s with no player required")
	LushCaveExtra.update(world,2.99,[])
	t.check(world.node_at(left) == FULL,"full tip remains down for the source 3.0 s")
	LushCaveExtra.update(world,0.01,[])
	t.check(world.node_at(left) == BIG and not LushCaveExtra.runtime(world).timers.has(left),"full tip returns upright and clears its completed timer")

	# Redstone power suppresses entry into current and therefore resets a hold.
	world.set_node(left,BIG)
	LushCaveExtra.update(world,0.3,[sample(1,feet(left))])
	world.set_node(left+Vector3i.RIGHT,Nodes.REDSTONE_BLOCK); world.circuits.step(0.1)
	t.check(world.circuits.input_power(left) > 0,"the real circuit powers the dripleaf cell")
	LushCaveExtra.update(world,0.6,[sample(1,feet(left))])
	t.check(world.node_at(left) == BIG and not LushCaveExtra.runtime(world).holds.has(1),"a powered leaf never tips and resets an existing partial hold")
	world.set_node(left+Vector3i.RIGHT,Nodes.AIR); world.circuits.step(0.1)
	LushCaveExtra.update(world,0.51,[sample(1,feet(left))])
	t.check(world.node_at(left) == HALF,"removing power allows a fresh hold to tip the leaf")

	# Two connected players own independent tables; a missing roster member is
	# forgotten, while the remaining player's elapsed hold continues.
	var other := left+Vector3i(4,0,0)
	world.set_node(left,BIG); world.set_node(other,BIG)
	var local_sample: Dictionary = sample("local",feet(left)); var remote_sample: Dictionary = sample(7,feet(other))
	LushCaveExtra.update(world,0.3,[local_sample,remote_sample])
	LushCaveExtra.update(world,0.1,[local_sample])
	holds = LushCaveExtra.runtime(world).holds
	t.check(holds.has("local") and not holds.has(7),"multiplayer update drops a disconnected player's holds and retains the local hold")
	LushCaveExtra.update(world,0.1001,[local_sample])
	t.check(world.node_at(left) == HALF and world.node_at(other) == BIG,"one remote player's leaf cannot consume another player's elapsed hold")
	world.set_node(left,BIG); LushCaveExtra.update(world,0.2,[local_sample])
	t.check(LushCaveExtra.runtime(world).holds.has("local"),"a fresh multiplayer hold exists before disconnect")
	LushCaveExtra.player_left(world,"local")
	t.check(not LushCaveExtra.runtime(world).holds.has("local"),"the network leave hook explicitly forgets a player")

	# Client replicas never run authoritative node transitions.
	world.set_node(left,BIG); world.network_replica = true
	LushCaveExtra.update(world,1.0,[local_sample]); world.network_replica = false
	t.check(world.node_at(left) == BIG and not LushCaveExtra.runtime(world).holds.has("local"),"network replicas do not simulate or mutate dripleaf holds")

	# Column unload drops transient clocks; loading saved tipped nodes restarts
	# their current-stage timer through real worker-column reconciliation.
	world.set_node(left,HALF)
	LushCaveExtra.update(world,0.2,[])
	world.set_node(other,BIG); LushCaveExtra.update(world,0.2,[remote_sample])
	world._unload(Vector2i.ZERO)
	t.check(not LushCaveExtra.runtime(world).timers.has(left) and not LushCaveExtra.runtime(world).holds.has(7),"column unload clears both stage timers and player holds in that column")
	world._apply_column(world.generator.generate_column(Vector2i.ZERO,world.edits.duplicate()))
	t.check(LushCaveExtra.runtime(world).timers.has(left),"column load registers the saved half-tipped node")
	LushCaveExtra.update(world,0.5,[])
	t.check(world.node_at(left) == FULL,"reloaded half tip resumes its real node-timer lifecycle")

	# Real Game.break_node starts the source's 0.05 s after_dig cascade. Recursion
	# visits both directions and pays the ordinary no-tool drops of each dug node.
	var base := p+Vector3i(0,6,0)
	world.set_node(base+Vector3i.DOWN,Nodes.DIRT)
	world.set_node(base,LushCaveExtra.DRIPLEAF_BIG_STEM)
	world.set_node(base+Vector3i.UP,BIG)
	world.set_node(base+Vector3i.UP*2,LushCaveExtra.DRIPLEAF_BIG_STEM)
	world.set_node(base+Vector3i.UP*3,LushCaveExtra.DRIPLEAF_SMALL_STEM)
	world.set_node(base+Vector3i.UP*4,LushCaveExtra.DRIPLEAF_SMALL)
	world.set_node(base+Vector3i.UP*5,HALF)
	held(game,Nodes.AIR,0); before = drops(game,BIG)
	game.break_node(base+Vector3i.UP,BIG,0)
	t.check(world.node_at(base) == LushCaveExtra.DRIPLEAF_BIG_STEM,"adjacent digging waits for the source 0.05 s callback")
	await t.create_timer(0.35).timeout
	var cascade_cleared: bool = true
	for height in 5: cascade_cleared = cascade_cleared and world.node_at(base+Vector3i.UP*height) == Nodes.AIR
	t.check(cascade_cleared,"adjacent digging recursively clears the connected source-group column")
	t.check(world.node_at(base+Vector3i.UP*5) == HALF,"tipped forms' replaced group table stops the source digging traversal")
	t.check(drops(game,BIG) == before+3,"the clicked big leaf and two big stems each yield one big leaf")

	clear(world)
