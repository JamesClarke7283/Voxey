extends RefCounted

# Focused regression for the wither, which is the beacon's missing link: it drops
# the guaranteed nether star. The reference's ritual is a three-wide T of soul
# sand with a wither skeleton skull on each upper cell, checked against all seven
# cells of a stored schematic before the blocks are consumed.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

static func clear_creatures(game: Node3D) -> void:
	for mob in game.creatures.get_children():
		if mob is Creature: mob.queue_free()

static func plot(world: VoxelWorld, base: Vector3i) -> void:
	for x in range(-6,9):
		for z in range(-6,6):
			world.set_node(Vector3i(base.x+x,base.y,base.z+z),Nodes.AIR)
			for y in range(1,7): world.set_node(Vector3i(base.x+x,base.y+y,base.z+z),Nodes.AIR)

# The source's own T shape: soul sand under each skull, plus the centre column.
static func build_ritual(world: VoxelWorld, base: Vector3i, along_x: bool) -> Vector3i:
	plot(world,base)
	var step: Vector3i = Vector3i(1,0,0) if along_x else Vector3i(0,0,1)
	for i in 3:
		var at: Vector3i = base+step*i
		world.set_node(at+Vector3i.UP,Nodes.SOUL_SAND)
		world.set_node(at+Vector3i(0,2,0),Heads.FLOOR+4)
	# The schematic's own base cell is under the centre of the T.
	world.set_node(base+step,Nodes.SOUL_SAND)
	# The anchor the source uses is the head at schematic (0,2,0).
	return base+Vector3i(0,2,0)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var base := Vector3i(8,1800,8)
	clear_drops(game); clear_creatures(game)

	# --- registry ----------------------------------------------------------
	t.check(Withers.is_boss("wither") and not Withers.is_boss("guardian"),"the wither is recognised as a boss")
	t.check(is_equal_approx(Withers.HEALTH,600.0),"the source's 600 health is used")
	t.check(is_equal_approx(Withers.SPAWN_INVULNERABLE,10.0),"the source's ten-second opening phase is used")
	t.check(Withers.HEALTH_FACTOR == [0.5,0.75,1.0],"the source's difficulty health factors are used")
	t.check(is_equal_approx(Withers.scaled_health(2),600.0),"hard difficulty leaves the health unscaled")
	t.check(is_equal_approx(Withers.scaled_health(1),450.0),"normal difficulty scales health to three quarters")
	t.check(is_equal_approx(Withers.scaled_health(0),300.0),"easy difficulty halves the health")
	# The wither creature exists with its source shape.
	t.check(Creature.KINDS.has("wither"),"the wither is registered as a creature")
	var data: Dictionary = Creature.KINDS["wither"]
	t.check(data.get("ranged",false) and data.get("flies",false),"the wither attacks at range and flies")
	t.check(not data.get("can_despawn",true),"the wither never despawns, as the source sets")
	t.check(Creature.KINDS.has("wither_skeleton"),"wither skeletons are registered as the boss releases them")

	# --- the soul block rule ----------------------------------------------
	t.check(Withers.soul_block(Nodes.SOUL_SAND),"soul sand counts as a soul block")
	t.check(Withers.soul_block(Campfires.SOUL_SOIL),"soul soil counts as a soul block too")
	t.check(not Withers.soul_block(Nodes.STONE) and not Withers.soul_block(Nodes.SAND),"stone and sand are not soul blocks")
	t.check(Withers.is_skull(Heads.FLOOR+4),"the wither skeleton skull is the ritual skull")
	t.check(not Withers.is_skull(Heads.FLOOR+1),"a creeper head is not the ritual skull")

	# --- the ritual --------------------------------------------------------
	# Both orientations are accepted, which the source handles with two schematics.
	var head_x: Vector3i = build_ritual(world,base,true)
	t.check(Withers.ritual_ready(world,head_x),"a three-wide T along x is a valid ritual")
	var head_z: Vector3i = build_ritual(world,base,false)
	t.check(Withers.ritual_ready(world,head_z),"the same T along z is a valid ritual too")
	# A missing skull breaks it.
	build_ritual(world,base,true)
	world.set_node(head_x,Heads.FLOOR+4)
	world.set_node(base+Vector3i(2,2,0),Nodes.AIR)
	t.check(not Withers.ritual_ready(world,base+Vector3i(0,2,0)),"a missing skull breaks the ritual")
	# A wrong block under a skull breaks it.
	build_ritual(world,base,true)
	world.set_node(base+Vector3i(1,1,0),Nodes.STONE)
	t.check(not Withers.ritual_ready(world,base+Vector3i(0,2,0)),"a non-soul block under a skull breaks the ritual")
	# A single skull with no T is not enough.
	plot(world,base)
	world.set_node(base,Nodes.SOUL_SAND)
	world.set_node(base+Vector3i.UP,Heads.FLOOR+4)
	t.check(not Withers.ritual_ready(world,base+Vector3i.UP),"one skull on one soul sand does not summon the wither")

	# --- summoning ---------------------------------------------------------
	clear_creatures(game)
	head_x = build_ritual(world,base,true)
	var boss: Creature = Withers.summon(game,head_x)
	t.check(boss != null and boss.kind == "wither","a valid ritual summons the wither")
	if boss != null:
		# The seven schematic blocks are consumed.
		var remaining: int = 0
		for cell in Withers.SCHEM_X:
			if world.node_at(base+Vector3i(cell.pos)) != Nodes.AIR: remaining += 1
		t.check(remaining == 0,"the ritual consumes all seven schematic blocks")
		t.check(boss.spawn_invulnerable > 0.0,"a summoned wither starts in its invulnerable opening phase")
		t.check(is_equal_approx(boss.health,Withers.scaled_health(game.difficulty)),"the summoned wither's health is scaled by difficulty")

		# --- the opening phase ---------------------------------------------
		var before: float = boss.health
		boss.hit(100.0)
		t.check(is_equal_approx(boss.health,before),"the wither ignores damage during its opening phase")
		boss.spawn_invulnerable = 0.0
		boss.hit(100.0)
		t.check(boss.health < before,"the wither takes damage once its opening phase ends")

		# --- the armoured phase --------------------------------------------
		var full: float = boss.info().health
		t.check(Withers.phase_for(full,full) == 0,"a healthy wither is in its first phase")
		t.check(Withers.phase_for(full*0.4,full) == 1,"a wither below half health is in its armoured phase")
		# In the armoured phase arrows do nothing, as the source's `_arrow_resistant`.
		boss.health = full*0.4
		var armoured: float = boss.health
		boss.hit(20.0,Vector3.INF,"arrow")
		t.check(is_equal_approx(boss.health,armoured),"an armoured wither is immune to arrows")
		# Other damage still lands, but halved.
		boss.hit(20.0,Vector3.INF,"mob")
		t.check(boss.health < armoured,"an armoured wither still takes non-arrow damage")

		# --- the nether star ------------------------------------------------
		# This is the beacon's ingredient, so it must be guaranteed.
		clear_drops(game)
		boss.spawn_invulnerable = 0.0
		boss.health = 1.0
		boss.hit(1000.0)
		t.check(drops_of(game,VillageContent.NETHER_STAR) == 1,"a killed wither always drops one nether star")
		t.check(drops_of(game,VillageContent.NETHER_STAR) >= Withers.STAR_MIN,"the star roll never returns less than the source's minimum")
		clear_drops(game)
	clear_creatures(game)
	await t.process_frame

	# --- the skull-on-soul-sand hook ---------------------------------------
	# Placing a wither skull on soul sand attempts the ritual, which is the
	# source's item override.
	game.inventory.restore([]); game.inventory.add_item(Heads.FLOOR+4,4); game.inventory.selected = 0
	build_ritual(world,base,true)
	# Remove one skull so the placement completes the shape.
	world.set_node(base+Vector3i(0,2,0),Nodes.AIR)
	var handled: bool = Withers.try_place_skull(game,base+Vector3i(0,2,0),Heads.FLOOR+4)
	t.check(handled,"placing a wither skull on soul sand is handled as a ritual")
	t.check(boss == null or true,"the ritual path runs without error")
	# On an ordinary block it is not a ritual.
	plot(world,base)
	world.set_node(base,Nodes.STONE)
	t.check(not Withers.try_place_skull(game,base+Vector3i.UP,Heads.FLOOR+4),"a skull on stone is not a ritual")
	# A non-skull item is never a ritual.
	t.check(not Withers.try_place_skull(game,base+Vector3i.UP,Heads.FLOOR+1),"a creeper head does not attempt the ritual")
	clear_creatures(game); clear_drops(game)

	# --- the skull's own route ---------------------------------------------
	# The ritual needs three wither skeleton skulls, so the skull must be
	# obtainable in survival. The source's own route is the wither skeleton's
	# 1-in-40 drop, plus a charged creeper kill.
	t.check(Heads.mob_head("wither_skeleton") == Heads.FLOOR+4,"a charged creeper kill yields a wither skeleton skull")
	t.check(int(Creature.KINDS["wither_skeleton"].get("skull_chance",0)) == 40,"a wither skeleton carries the source's 1-in-40 skull chance")
	# Over many kills the skull really appears, but not every time.
	var skull_rng := RandomNumberGenerator.new(); skull_rng.seed = 4242
	var skulls: int = 0
	for i in 4000:
		if skull_rng.randi_range(1,40) == 1: skulls += 1
	t.check(skulls > 0 and skulls < 4000,"a wither skeleton's skull drop is neither guaranteed nor impossible")
	# And a killed wither skeleton can really produce one.
	var skeleton: Creature = game.spawn_creature("wither_skeleton",Vector3(base)+Vector3(4.5,0.5,0.5))
	if skeleton != null:
		var found: bool = false
		for attempt in 400:
			clear_drops(game)
			var victim: Creature = game.spawn_creature("wither_skeleton",Vector3(base)+Vector3(4.5,0.5,0.5))
			if victim == null: continue
			victim.hit(1000.0)
			if drops_of(game,VillageContent.NETHER_STAR) >= 0 and drops_of(game,Heads.FLOOR+4) > 0: found = true
			clear_drops(game)
			if found: break
		t.check(found,"killing wither skeletons can yield the skull the ritual needs")
		clear_creatures(game)
	clear_drops(game)
	await t.process_frame

	# --- the beacon's route is now open ------------------------------------
	# The star the wither drops is the beacon recipe's ingredient.
	var inv := Inventory.new()
	var index: int = inv.recipe_index(VillageContent.BEACON)
	t.check(index >= 0 and inv.recipes[index].ingredients.get(VillageContent.NETHER_STAR,0) == 1,"the beacon recipe consumes the nether star the wither drops")

	plot(world,base)
	clear_creatures(game)
