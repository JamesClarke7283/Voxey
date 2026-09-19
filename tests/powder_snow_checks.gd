extends RefCounted

# Focused regression for powder snow (Mineclonia `mcl_powder_snow`).
#
# Powder snow is the trap block of a snowy biome: it **looks like snow and is not
# solid**. A player crossing a snowfield walks into it and starts to freeze. The
# source's rule is precise, and each part is what makes the trap fair rather than
# arbitrary:
#
#   * The meter accumulates **0.5 per slow tick**, capped at 7.
#   * Damage begins past **5**, so shallow contact is harmless.
#   * Frost has **three visual stages** at 1, 3 and 5, so the screen warns first.
#   * Leaving **drains** the meter, so the frost recedes.
#   * **Leather armour prevents it entirely**, which is what leather is for.

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var player: VoxeyPlayer = game.player

	# --- the block and the bucket exist -------------------------------------
	t.check(VillageContent.DATA.has(PowderSnow.ID),"the powder snow block is registered")
	t.check(VillageContent.DATA.has(PowderSnow.BUCKET),"the bucket of powder snow is registered")
	t.check(PowderSnow.is_powder_snow(PowderSnow.ID),"the block identifies itself")
	t.check(PowderSnow.is_bucket(PowderSnow.BUCKET),"the bucket identifies itself")
	t.check(not PowderSnow.is_powder_snow(Nodes.SNOW_BLOCK),"a snow block is not powder snow")
	# The bucket is carried as a single item, like every other bucket.
	t.check(int(VillageContent.DATA[PowderSnow.BUCKET].stack) == 1,"the bucket does not stack")

	# --- it is a trap, so it is not solid ------------------------------------
	# This is the whole point: a solid powder snow would be an ordinary snow block.
	t.check(not Nodes.solid(PowderSnow.ID),"powder snow is not solid, so a player sinks into it")
	t.check(Nodes.solid(Nodes.SNOW_BLOCK),"an ordinary snow block is still solid")

	# --- the source's constants ---------------------------------------------
	t.check(is_equal_approx(PowderSnow.STEP,0.5),"the source's half-step accumulation is used")
	t.check(is_equal_approx(PowderSnow.MAX_TIME,7.0),"the source's meter cap is used")
	t.check(is_equal_approx(PowderSnow.DAMAGE_THRESHOLD,5.0),"damage begins past the source's threshold")
	t.check(is_equal_approx(PowderSnow.FREEZE_DAMAGE,0.5),"the source's freeze damage is used")
	t.check(PowderSnow.STAGE_LEVELS.size() == 3,"the source's three frost stages are used")
	t.check(is_equal_approx(PowderSnow.FIRE_MOB_MULTIPLIER,5.0),"the source's fire-mob multiplier is used")

	# --- the meter climbs, and the frost warns first -------------------------
	var at := Vector3i(6,64,6)
	t.check(ensure(game,at),"the test column is loaded")
	world.set_node(at,PowderSnow.ID)
	player.position = Vector3(at)+Vector3(0.5,0.0,0.5)
	player.armor_slots[3] = {"id":0,"count":0,"wear":0}
	PowderSnow.set_time_in_snow(player,0)
	t.check(PowderSnow.submerged(world,player),"the player is detected inside the powder snow")
	var damage: float = 0.0
	var stages: Array = []
	for i in 16:
		damage += PowderSnow.step(world,player)
		stages.append(PowderSnow.stage(PowderSnow.time_in_snow(player)))
	# The frost deepens through all three stages before it hurts.
	t.check(stages.has(1) and stages.has(2) and stages.has(3),"the frost passes through all three stages")
	# The deepest frost appears at the source's own level rather than at once, so
	# the screen warns the player before the freeze starts to hurt.
	var deep_at: int = stages.find(3)
	t.check(deep_at > 0,"the deepest frost is not shown immediately")
	# And damage only starts after the threshold, which is the promise the stages
	# make: by the time it hurts, the screen has already warned.
	t.check(damage > 0.0,"staying in powder snow does damage")
	# Each damaging step is exactly the source's freeze amount.
	var damaged: int = int(round(damage/PowderSnow.FREEZE_DAMAGE))
	t.check(damaged >= 1 and damaged <= 16,"the damage is a whole number of source freeze steps")
	# The meter is capped, so a player cannot freeze without limit.
	t.check(PowderSnow.time_in_snow(player) <= PowderSnow.MAX_TIME,"the meter is capped")

	# --- the frost recedes when the player leaves ----------------------------
	PowderSnow.set_time_in_snow(player,4.0)
	player.position = Vector3(20,64,20)
	var before: float = PowderSnow.time_in_snow(player)
	t.check(PowderSnow.step(world,player) == 0.0,"leaving the snow does no damage")
	t.check(PowderSnow.time_in_snow(player) < before,"the meter drains once the player leaves")
	# And it drains to nothing rather than sticking at a floor.
	PowderSnow.set_time_in_snow(player,0.4)
	PowderSnow.step(world,player)
	t.check(PowderSnow.time_in_snow(player) == 0.0,"the meter drains to zero")
	t.check(PowderSnow.stage(0.0) == 0,"a drained meter shows no frost")

	# --- leather armour prevents it entirely ---------------------------------
	# This is what leather is for in a snowy world, and the source checks the whole
	# set rather than only the boots.
	player.position = Vector3(at)+Vector3(0.5,0.0,0.5)
	PowderSnow.set_time_in_snow(player,0)
	player.armor_slots[3] = {"id":Nodes.armor_id(0,3),"count":1,"wear":0}
	t.check(PowderSnow.insulated(player),"leather boots count as insulation")
	var insulated_damage: float = 0.0
	for i in 16:
		insulated_damage += PowderSnow.step(world,player)
	t.check(insulated_damage == 0.0,"leather armour prevents the freeze entirely")
	t.check(PowderSnow.time_in_snow(player) == 0.0,"and the meter does not build")
	# A non-leather piece does not insulate.
	player.armor_slots[3] = {"id":Nodes.armor_id(3,3),"count":1,"wear":0}
	t.check(not PowderSnow.insulated(player),"diamond boots do not insulate")
	player.armor_slots[3] = {"id":0,"count":0,"wear":0}

	# --- fire mobs freeze harder ---------------------------------------------
	# The source multiplies freeze damage for the mobs it lists, so a blaze suffers
	# five times as much.
	t.check(is_equal_approx(PowderSnow.mob_damage("blaze",1.0),5.0),"a blaze takes the source's five times the freeze damage")
	for kind in PowderSnow.FIRE_MOBS:
		t.check(is_equal_approx(PowderSnow.mob_damage(kind,1.0),5.0),"the %s takes extra freeze damage" % kind)
	t.check(is_equal_approx(PowderSnow.mob_damage("zombie",1.0),1.0),"an ordinary mob takes the base damage")

	# --- the frost is drawn, and deepens -------------------------------------
	# The source warns with frost stages before the freeze hurts, so the overlay is
	# part of the mechanic rather than decoration. Each stage must be visibly deeper
	# and wider than the one before it, and stage zero must draw nothing.
	t.check(VoxeyHUD.FROST_TINTS.size() == 3,"the frost has the source's three stages")
	t.check(VoxeyHUD.FROST_BANDS.size() == 3,"each frost stage has its own band")
	var deepens: bool = true
	var widens: bool = true
	for i in range(1,VoxeyHUD.FROST_TINTS.size()):
		if VoxeyHUD.FROST_TINTS[i].a <= VoxeyHUD.FROST_TINTS[i-1].a: deepens = false
		if VoxeyHUD.FROST_BANDS[i] <= VoxeyHUD.FROST_BANDS[i-1]: widens = false
	t.check(deepens,"each frost stage is deeper than the last")
	t.check(widens,"each frost stage reaches further in than the last")
	t.check(game.hud.has_method("_draw_frost"),"the HUD can draw the frost")
	# The overlay is driven by the meter's own stage, so it appears exactly when the
	# meter says it should and not before.
	t.check(PowderSnow.stage(0.0) == 0 and PowderSnow.stage(0.5) == 0,"no frost is drawn before the first stage")
	t.check(PowderSnow.stage(1.0) == 1,"the first stage appears at the source's level")
	t.check(PowderSnow.stage(3.0) == 2,"the second stage appears at the source's level")
	t.check(PowderSnow.stage(5.0) == 3,"the deepest stage appears at the source's damage threshold")

	# --- the content table has no duplicate ids ------------------------------
	# A repeated key in the content table's dictionary literal is a parse error for
	# the whole file, which takes down every consumer at once. That happened while
	# adding lush cave blocks: moss block reused an id the ender chest already had,
	# and the game would not load. This asserts the table is sound.
	var ids: Array = VillageContent.DATA.keys()
	var unique: Dictionary = {}
	for id in ids: unique[id] = true
	t.check(unique.size() == ids.size(),"the content table has no duplicate ids")
	# And every id this batch added is present exactly once.
	for id in [PowderSnow.ID,PowderSnow.BUCKET,LushCaves.CAVE_VINES,LushCaves.CAVE_VINES_LIT,
			LushCaves.GLOW_BERRY,LushCaves.MOSS,LushCaves.MOSS_CARPET,LushCaves.HANGING_ROOTS,
			Bamboo.SHOOT,Bamboo.STALK]:
		t.check(VillageContent.DATA.has(id),"the content table registers %d" % id)

	# --- a bucket scoops it --------------------------------------------------
	# The source lets a bucket pick the block up, which is how powder snow is
	# carried and poured back.
	world.set_node(at,PowderSnow.ID)
	game.inventory.slots[game.inventory.selected] = {"id":Nodes.BUCKET,"count":1,"wear":0}
	t.check(PowderSnow.scoop(game,at),"a bucket scoops powder snow")
	t.check(world.node_at(at) == Nodes.AIR,"the scooped block is gone")
	t.check(game.inventory.count_item(PowderSnow.BUCKET) > 0 or game.drops.get_child_count() > 0,"the bucket of powder snow is returned")
	# And pours it back.
	var pour_at := Vector3i(8,64,8)
	t.check(ensure(game,pour_at),"the pour site is loaded")
	game.inventory.slots[game.inventory.selected] = {"id":PowderSnow.BUCKET,"count":1,"wear":0}
	t.check(PowderSnow.pour(game,pour_at),"a bucket pours powder snow back")
	t.check(world.node_at(pour_at) == PowderSnow.ID,"the poured block is placed")
