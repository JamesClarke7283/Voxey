extends RefCounted

# A village's own iron golem: `villager.lua`'s `summon_golem`,
# `maybe_summon_golem`, `desires_golem` and the two request thresholds.

static func clear_village(game: Node3D) -> void:
	for mob in game.creatures.get_children():
		if mob is VillageMob and not mob.is_queued_for_deletion(): mob.queue_free()

# A flat two-layer stone pad centred on `center`, with the golem's clearance above it
# and the search's whole box hollow. `floor_id` is what the surface layer is made of,
# which is what the water test varies.
static func pad(game: Node3D, center: Vector3i, floor_id: int = -1) -> void:
	for x in range(-9,10):
		for z in range(-9,10):
			for y in range(center.y-SEARCH_HALF,center.y+SEARCH_HALF+1):
				game.world.set_node(Vector3i(center.x+x,y,center.z+z),Nodes.AIR)
			game.world.set_node(Vector3i(center.x+x,center.y-1,center.z+z),Nodes.STONE)
			var surface: int = Nodes.STONE if floor_id < 0 else floor_id
			game.world.set_node(Vector3i(center.x+x,center.y,center.z+z),surface)

# `find_nodes_in_area_under_air(pos ± (8,5,8))`: eleven nodes tall.
const SEARCH_HALF = 5

static func villager(game: Node3D, key: String, at: Vector3, slept_at: float) -> VillageMob:
	var person: Dictionary = game.villages.make_record(key,"farmer",at,Vector3i(at),Vector3i(at),Vector3i(at))
	person["slept_at"] = slept_at
	game.villages.state().people[key] = person
	var mob: VillageMob = VillageMob.new()
	mob.game = game; mob.kind = "villager"; mob.person_key = key
	mob.position = at
	game.creatures.add_child(mob); mob.set_physics_process(false)
	return mob

static func golems(game: Node3D) -> int:
	var count: int = 0
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob is Creature and mob.kind == "iron_golem": count += 1
	return count

static func run(suite: Object, game: Node3D) -> void:
	var saved_position: Vector3 = game.player.position
	clear_village(game)
	game.world.adventure_state.erase("village_life")

	# --- the desire rule ------------------------------------------------------
	# `desires_golem` is `slept_recently_enough_for_golem and not seen_golem_lately`,
	# with windows of 1200 and 30 game seconds.
	suite.check(not VillageGolems.desires(1000.0,0.0,0.0),"a villager that has never slept does not want a golem")
	suite.check(VillageGolems.desires(1000.0,900.0,0.0),"one that slept inside the 1200-second window does")
	suite.check(not VillageGolems.desires(3000.0,900.0,0.0),"and one whose last sleep is older than the window does not")
	suite.check(not VillageGolems.desires(1000.0,900.0,990.0),"seeing a golem inside the 30-second cooldown suppresses the request")
	suite.check(VillageGolems.desires(1000.0,900.0,960.0),"and the request returns once that cooldown has passed")
	suite.check(VillageGolems.SLEEP_WINDOW == 1200.0 and VillageGolems.GOLEM_COOLDOWN == 30.0,"the two windows are the source's own 1200 and 30")
	suite.check(VillageGolems.PANIC_REQUESTERS == 3 and VillageGolems.CALM_REQUESTERS == 5,"a panicking villager needs three villagers in range and a calm one five")
	# The count is of villagers **including the asker**, as the source's sensor
	# returns an area sweep rather than "neighbours besides me".
	suite.check(VillageGolems.REQUEST_BOX == Vector3i(10,10,10),"and the sweep is the source's own ten-block box")

	# --- the placement search -------------------------------------------------
	# An 17x11x17 box for a solid or water cell with a solid block beneath and the
	# golem's own 2x3x2 clearance above. The pad's surface sits at `base.y`.
	var base := Vector3i(8,2400,8)
	var target: Vector3 = Vector3(base)+Vector3(0.5,1.0,0.5)
	pad(game,base)
	var spot: Vector3 = VillageGolems.find_spot(game.world,target)
	suite.check(spot.is_finite(),"the search finds a spot on a clear stone floor")
	suite.check(spot.y == float(base.y)+1.0,"the golem stands on the surface, one node above the solid cell")
	suite.check(absf(spot.x-float(base.x)-0.5) <= 9.0 and absf(spot.z-float(base.z)-0.5) <= 9.0,"and inside the source's 17x17 footprint")
	suite.check(int(spot.x) == spot.x-0.5 and int(spot.z) == spot.z-0.5,"the golem is centred in its cell, as the source's half-block offsets do")
	# A cell with a solid block beneath but the clearance blocked is refused. The
	# source's air test reaches three nodes above whatever cell it is checking, and
	# the search box is eleven nodes tall, so the fill must clear that whole span
	# before nothing qualifies — otherwise a stone cell at the box's top edge has
	# open sky above it and is a perfectly good spot.
	for x in range(-9,10):
		for z in range(-9,10):
			for y in range(base.y+1,base.y+SEARCH_HALF+4): game.world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.STONE)
	suite.check(not VillageGolems.find_spot(game.world,target).is_finite(),"with every clearance cell blocked the search finds nothing")
	# A water surface places the golem one node lower, as the source's own offset does.
	# Making the whole surface water keeps the shuffled pick deterministic.
	pad(game,base,Nodes.WATER)
	var wet: Vector3 = VillageGolems.find_spot(game.world,target)
	suite.check(wet.is_finite(),"a water surface is still a valid floor")
	suite.check(wet.y == float(base.y),"and places the golem one node lower than a dry surface")
	# A cell with nothing solid beneath is refused.
	pad(game,base)
	for x in range(-9,10):
		for z in range(-9,10): game.world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.AIR)
	suite.check(not VillageGolems.find_spot(game.world,target).is_finite(),"a floorless column offers no spot")

	# --- the request itself ---------------------------------------------------
	# A full village: residents that have slept, no golem seen, and enough neighbours
	# inside ten blocks.
	clear_village(game)
	game.world.adventure_state.erase("village_life")
	pad(game,base)
	var state: Dictionary = game.villages.state()
	var clock: float = game.day_number()*1200.0+game.day_time*1200.0
	state.people.clear()
	var made: Array = []
	for i in 6: made.append(villager(game,"village/"+str(i),Vector3(base)+Vector3(0.5+i,1.0,0.5),clock))
	suite.check(state.people.size() == 6,"the test village has six residents that have slept")
	# A calm villager needs five neighbours, so six residents are enough.
	var summoned: bool = VillageGolems.maybe_summon(game,made[0],false)
	suite.check(summoned and golems(game) == 1,"six villagers that have slept summon one iron golem")
	# The cooldown is village-wide: every requester was stamped, so a second attempt
	# inside 30 seconds is refused.
	suite.check(not VillageGolems.maybe_summon(game,made[0],false),"a second request inside the golem cooldown is refused")
	suite.check(float(state.people["village/0"].get("saw_golem_at",0.0)) == clock,"and every requester was stamped with the time")
	# With the cooldown expired the request works again.
	for key in state.people:
		state.people[key]["saw_golem_at"] = clock-60.0
		state.people[key]["slept_at"] = clock
	suite.check(VillageGolems.maybe_summon(game,made[1],false) and golems(game) == 2,"the request returns once the cooldown has expired")
	# Fewer requesters than the threshold refuses: two villagers cannot, three can
	# while panicking.
	clear_village(game)
	pad(game,base)
	state.people.clear()
	var few: Array = []
	for i in 2: few.append(villager(game,"village/"+str(i),Vector3(base)+Vector3(0.5+i,1.0,0.5),clock))
	suite.check(not VillageGolems.maybe_summon(game,few[0],false),"two villagers cannot summon a golem, since a calm request counts five including the asker")
	suite.check(not VillageGolems.maybe_summon(game,few[0],true),"and neither can a panicking one, which counts three")
	few.append(villager(game,"village/2",Vector3(base)+Vector3(3.5,1.0,0.5),clock))
	suite.check(VillageGolems.maybe_summon(game,few[0],true) and golems(game) == 1,"but three panicking villagers can")
	clear_village(game)
	# A villager that has not slept is refused outright, whatever the crowd.
	pad(game,base)
	state.people.clear()
	for i in 6: state.people.erase("village/"+str(i))
	var rested: Array = []
	for i in 6: rested.append(villager(game,"village/"+str(i),Vector3(base)+Vector3(0.5+i,1.0,0.5),clock))
	for i in 6: state.people["village/"+str(i)]["slept_at"] = 0.0
	suite.check(not VillageGolems.maybe_summon(game,rested[0],false),"a village that has not slept does not summon, however many neighbours stand by")
	# One resident asleep is not enough either, which is what the count is.
	state.people["village/3"]["slept_at"] = clock
	suite.check(not VillageGolems.maybe_summon(game,rested[0],true),"one rested villager among six is still below the panicking threshold of three")
	state.people["village/4"]["slept_at"] = clock
	suite.check(not VillageGolems.maybe_summon(game,rested[0],true),"two rested villagers are still below it")
	state.people["village/5"]["slept_at"] = clock
	suite.check(VillageGolems.maybe_summon(game,rested[3],true),"and three rested villagers meet it")

	# --- the panic test -------------------------------------------------------
	pad(game,base)
	var monster: Creature = game.spawn_creature("zombie",Vector3(base)+Vector3(0.5,1.0,0.5))
	if monster != null:
		monster.set_physics_process(false)
		suite.check(VillageGolems.hostile_near(game,Vector3(base)+Vector3(0.5,1.0,0.5)),"a zombie beside the village makes it panic")
		monster.position = Vector3(base)+Vector3(60.0,1.0,0.5)
		suite.check(not VillageGolems.hostile_near(game,Vector3(base)+Vector3(0.5,1.0,0.5)),"and one far away does not")
		monster.queue_free()

	# --- the five-second timer ------------------------------------------------
	# `check_timer("golem_summon", 5.0)`: the request is not made every frame but once
	# every five seconds.
	clear_village(game)
	pad(game,base)
	state.people.clear()
	var timed: Array = []
	for i in 6: timed.append(villager(game,"village/"+str(i),Vector3(base)+Vector3(0.5+i,1.0,0.5),clock))
	for i in 4: suite.check(not VillageGolems.step(game,timed[0],false,1.0),"the request waits out the source's five-second interval")
	suite.check(VillageGolems.step(game,timed[0],false,1.0) and golems(game) == 1,"and fires once the interval has elapsed")

	# --- gossip --------------------------------------------------------------
	# `villager.lua`:2565-2573 — a trade makes the villager share what it knows with
	# the villagers around it, and fires the ordinary golem request at the same
	# moment. `copy_gossips` shrinks the value by `transfer_decay` as the story
	# travels, and the receiver keeps whichever value is stronger.
	clear_village(game)
	pad(game,base)
	state.people.clear()
	game.player_id = "player"
	var speaker: Dictionary = game.villages.make_record("village/0","farmer",Vector3(base)+Vector3(0.5,1.0,0.5),base,base,base)
	speaker["reputations"] = {"player":25}
	state.people["village/0"] = speaker
	var near: Dictionary = game.villages.make_record("village/1","farmer",Vector3(base)+Vector3(3.5,1.0,0.5),base,base,base)
	state.people["village/1"] = near
	# A villager far outside the ten-block sweep hears nothing.
	var far: Dictionary = game.villages.make_record("village/2","farmer",Vector3(base)+Vector3(40.5,1.0,0.5),base,base,base)
	state.people["village/2"] = far
	VillageGolems.gossip(game,speaker,Vector3(base)+Vector3(1.0,1.0,0.5))
	suite.check(int(near.get("reputations",{}).get("player",0)) == 5,"a listener ten blocks away hears the story shrunk by the source's transfer decay of 20")
	suite.check(int(far.get("reputations",{}).get("player",0)) == 0,"and a villager outside the sweep hears nothing")
	# The receiver keeps whichever is stronger, so good news cannot overwrite a worse
	# opinion, and a hearsay value never crosses from dislike to like.
	near["reputations"] = {"player":-30}
	VillageGolems.gossip(game,speaker,Vector3(base)+Vector3(1.0,1.0,0.5))
	# A positive story raises the villager's *positive* bucket, which the source sums
	# against the negative one — so the net improves by the decayed value while the
	# grudge itself remains.
	suite.check(int(near["reputations"]["player"]) == -25,"a positive story improves a hostile villager's standing by the decayed value without cancelling the grudge")
	var angry: Dictionary = game.villages.make_record("village/3","farmer",Vector3(base)+Vector3(4.5,1.0,0.5),base,base,base)
	angry["reputations"] = {"player":-25}
	state.people["village/3"] = angry
	near["reputations"] = {"player":0}
	VillageGolems.gossip(game,angry,Vector3(base)+Vector3(1.0,1.0,0.5))
	suite.check(int(near["reputations"]["player"]) == -5,"bad news travels the same way, decayed by the same amount")
	suite.check(int(near["reputations"]["player"]) < 0,"and hearsay never flips the sign of the player's standing")

	# --- the sleep stamp ------------------------------------------------------
	# Passing a night stamps every resident, which is what unblocks the request.
	clear_village(game)
	state.people.clear()
	var person: Dictionary = game.villages.make_record("village/0","farmer",Vector3(base)+Vector3(0.5,1.0,0.5),base,base,base)
	state.people["village/0"] = person
	suite.check(float(person.get("slept_at",0.0)) == 0.0,"a fresh resident has never slept")
	VillageGolems.mark_slept(game,"")
	suite.check(float(state.people["village/0"].get("slept_at",0.0)) > 0.0,"passing a night stamps every resident as having slept")

	# --- cleanup --------------------------------------------------------------
	clear_village(game)
	game.world.adventure_state.erase("village_life")
	game.player.position = saved_position
	game.inventory.restore([])
