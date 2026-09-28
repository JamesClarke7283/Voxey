extends RefCounted

# The wind charge: `ENTITIES/mcl_charges/init.lua` and `wind_charge.lua`. A thrown
# burst that moves everything in range without breaking blocks.

static func run(suite: Object, game: Node3D) -> void:
	var saved_position: Vector3 = game.player.position
	var base := Vector3i(8,2400,8)
	for x in range(-9,10):
		for z in range(-9,10):
			for y in range(base.y-1,base.y+9): game.world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.AIR)
			game.world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)

	# --- the item -------------------------------------------------------------
	suite.check(Nodes.exists(WindCharge.ID),"the wind charge is registered")
	suite.check(Nodes.title(WindCharge.ID) == "Wind charge","and carries the source's own name")
	suite.check(Nodes.max_stack(WindCharge.ID) == 64,"charges stack to the source's 64")
	suite.check(WindCharge.exists(WindCharge.ID) and not WindCharge.exists(Nodes.EGG),"only the wind charge answers the module's own test")

	# --- the recipe -----------------------------------------------------------
	# `mcl_mobitems`: a breeze rod has `_mcl_crafting_output = {single = {output =
	# "mcl_charges:wind_charge 4"}}`, a single ingredient making four.
	var inv := Inventory.new()
	var index: int = inv.recipe_index(WindCharge.ID)
	suite.check(index >= 0,"the wind charge has a registered recipe")
	if index >= 0:
		var recipe: Dictionary = inv.recipes[index]
		suite.check(recipe.ingredients == {VillageContent.BREEZE_ROD:1},"one breeze rod is the only ingredient")
		suite.check(int(recipe.count) == 4,"and it yields the source's four charges")
		suite.check(recipe.station == "table","at a crafting table")
		var crafted := Inventory.new()
		crafted.add_item(VillageContent.BREEZE_ROD,1)
		var craft_index: int = crafted.recipe_index(WindCharge.ID)
		suite.check(craft_index >= 0 and crafted.craft(craft_index,"table") and crafted.count_item(WindCharge.ID) == 4,"a real breeze rod crafts four charges")
		suite.check(crafted.count_item(VillageContent.BREEZE_ROD) == 0,"consuming the rod")

	# --- the throw ------------------------------------------------------------
	# `mcl_charges` throws at 30 with **zero** acceleration, where `mcl_throwing` uses
	# 22 with gravity, and removes a charge that hits nothing after three seconds.
	suite.check(Throwables.supports(WindCharge.ID),"the wind charge is throwable")
	suite.check(Throwables.speed_for(WindCharge.ID) == 30.0,"it flies at the source's 30 nodes per second, not the 22 an egg uses")
	suite.check(Throwables.gravity_for(WindCharge.ID) == 0.0 and Throwables.drag_for(WindCharge.ID) == 0.0,"and flies flat, with no gravity or drag")
	suite.check(Throwables.lifetime_for(WindCharge.ID) == 3.0,"a charge that hits nothing is removed after three seconds")
	suite.check(Throwables.speed_for(Nodes.EGG) == Throwables.SPEED and Throwables.gravity_for(Nodes.EGG) == Throwables.GRAVITY,"while an egg keeps the throwing module's own speed and gravity")
	var shot: ThrownItem = Throwables.launch(game,WindCharge.ID,Vector3(base)+Vector3(0.5,2.0,0.5),Vector3(1,0,0))
	suite.check(shot != null and shot.velocity.is_equal_approx(Vector3(30.0,0.0,0.0)),"a launched charge carries its own velocity")
	suite.check(shot != null and shot.acceleration.is_equal_approx(Vector3.ZERO),"and no acceleration, so it does not arc")
	if shot != null: shot.queue_free()

	# --- the burst ------------------------------------------------------------
	# `wind_burst`: a mob gets `normalize(dir) * radius*3 + old velocity + jitter`,
	# clamped to 250.
	var origin := Vector3(base)+Vector3(0.5,1.0,0.5)
	var mob: Creature = game.spawn_creature("zombie",Vector3(base)+Vector3(2.5,1.0,0.5))
	suite.check(mob != null,"a mob is placed inside the burst radius")
	if mob != null:
		mob.set_physics_process(false); mob.velocity = Vector3.ZERO
		WindCharge.burst(game,origin)
		suite.check(mob.velocity.length() > 1.0,"the burst pushes a mob away")
		suite.check(mob.velocity.x > 0.0,"in the direction away from the burst")
		# The jitter is only half a block per axis, so the push dominates.
		suite.check(mob.velocity.x > absf(mob.velocity.z)*4.0 and mob.velocity.x > absf(mob.velocity.y)*4.0,"and along the axis the mob lies on, not sideways")
		var far: Creature = game.spawn_creature("zombie",Vector3(base)+Vector3(9.5,1.0,0.5))
		if far != null:
			far.set_physics_process(false); far.velocity = Vector3.ZERO
			WindCharge.burst(game,origin)
			suite.check(far.velocity.length() < 1.0,"a mob outside the radius is untouched")
			far.queue_free()
		mob.velocity = Vector3.ZERO
		# The velocity form is bounded: `if vector.length(vel) > 250 then` clamp.
		var wild: Vector3 = WindCharge.burst_velocity(origin,origin+Vector3(0.001,0,0),Vector3(400.0,0.0,0.0),12.0)
		# `normalize()` then `* 250` lands within a float step of the bound, so the
		# assertion allows it rather than pinning an exact bit pattern.
		suite.check(wild.length() <= 250.001 and wild.length() > 249.0,"the burst velocity is clamped at the source's 250")
		suite.check(WindCharge.burst_velocity(origin,origin,Vector3(7.0,0,0),12.0) == Vector3(7.0,0,0),"a burst exactly on the object leaves its velocity alone, as the source's own early return does")
	# The player is pushed with the distance-scaled form, which is why point-blank
	# bursts are the strongest.
	# The source's own `vector.equals(pos1, pos2)` early return means a burst exactly
	# at the player's feet produces nothing, so the point-blank case is half a block
	# away rather than coincident.
	game.player.position = origin+Vector3(0.5,0.0,0.0)
	game.player.velocity = Vector3.ZERO
	WindCharge.burst(game,origin)
	var close: float = game.player.velocity.length()
	game.player.position = origin+Vector3(3.0,0.0,0.0)
	game.player.velocity = Vector3.ZERO
	WindCharge.burst(game,origin)
	var distant: float = game.player.velocity.length()
	suite.check(close > 0.0 and distant > 0.0,"a player inside the radius is pushed")
	suite.check(close > distant,"and a point-blank burst pushes harder than a distant one")
	game.player.position = origin+Vector3(6.0,0.0,0.0)
	game.player.velocity = Vector3.ZERO
	WindCharge.burst(game,origin)
	suite.check(game.player.velocity.length() < 0.001,"and a player outside the radius is untouched")

	# --- the blocks that answer specially -------------------------------------
	# `hit_node`: a bell rings, a chorus flower is broken — a living one outright, a
	# dead one replaced by a living one — and a decorated pot yields four bricks.
	var cell := Vector3i(base.x,base.y,base.z)
	game.world.set_node(cell,EndMud.CHORUS_FLOWER)
	WindCharge.hits_node(game,Vector3(cell)+Vector3.ONE*0.5,cell)
	suite.check(game.world.node_at(cell) == Nodes.AIR,"a living chorus flower is destroyed")
	game.world.set_node(cell,EndMud.CHORUS_FLOWER_DEAD)
	WindCharge.hits_node(game,Vector3(cell)+Vector3.ONE*0.5,cell)
	suite.check(game.world.node_at(cell) == EndMud.CHORUS_FLOWER,"a dead one is replaced by a living flower rather than destroyed")
	game.world.set_node(cell,Decor.POT)
	WindCharge.hits_node(game,Vector3(cell)+Vector3.ONE*0.5,cell)
	suite.check(game.world.node_at(cell) == Nodes.AIR,"a decorated pot is destroyed")
	var bricks: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == Nodes.BRICKS: bricks += int(drop.amount)
	suite.check(bricks == 4,"and yields the source's four bricks")
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
	# An ordinary block is left standing: the charge breaks nothing.
	game.world.set_node(cell,Nodes.STONE)
	WindCharge.hits_node(game,Vector3(cell)+Vector3.ONE*0.5,cell)
	suite.check(game.world.node_at(cell) == Nodes.STONE,"an ordinary block is untouched, since the charge breaks nothing")
	game.world.set_node(cell,VillageContent.BELL)
	WindCharge.hits_node(game,Vector3(cell)+Vector3.ONE*0.5,cell)
	suite.check(game.world.node_at(cell) == VillageContent.BELL,"and a bell rings without being destroyed")

	# --- the burst damage -----------------------------------------------------
	# `get_arrow_damage_func(6, "fireball")` for a mob and `(0, ...)` for a player:
	# a charge hurts a mob but never a player.
	if mob != null:
		var before: float = mob.health
		mob.hit(WindCharge.MOB_DAMAGE,mob.position-Vector3.RIGHT)
		suite.check(mob.health < before,"the charge's own six damage hurts a mob")
		mob.queue_free()
	var player_health: float = game.player.health
	game.player.velocity = Vector3.ZERO
	WindCharge.burst(game,game.player.position)
	suite.check(game.player.health == player_health,"a burst does not damage the player, since the source's player damage is zero")

	# --- cleanup --------------------------------------------------------------
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
	for other in game.creatures.get_children():
		if other is Creature and not other.is_queued_for_deletion(): other.queue_free()
	game.world.set_node(cell,Nodes.AIR)
	game.player.position = saved_position
	game.inventory.restore([])
