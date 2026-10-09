extends RefCounted

# Focused regression for the pillager patrol and its raid captain
# (Mineclonia `ENTITIES/mobs_mc/pillager.lua`, GPL-3.0-or-later).
#
# The patrol is the only survival source of the ominous bottle, and the bottle is the
# only survival source of `bad_omen`, which is what starts a raid. These checks pin the
# source's gate arithmetic, the band size, the offset range, the mushroom refusal, the
# captain flag, and the drop that closes the loop.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var old_difficulty: int = game.difficulty
	var old_dimension: String = game.dimension
	var old_position: Vector3 = game.player.position

	# --- the per-attempt gate (`pillager.lua:338-352`) ----------------------
	# `days < 5 or not is_daytime() or pr:next(1,5) ~= 1` — all three.
	t.check(not PillagerPatrols.should_attempt(4,1.0,1),"a patrol does not attempt before day five")
	t.check(PillagerPatrols.should_attempt(5,1.0,1),"a patrol may attempt on day five")
	t.check(not PillagerPatrols.should_attempt(5,0.2,1),"a patrol never attempts at night")
	t.check(not PillagerPatrols.should_attempt(5,0.5,2),"a patrol attempt needs its one-in-five roll")
	t.check(not PillagerPatrols.should_attempt(5,1.0,5),"only the one-in-five roll lays a patrol")
	for roll in range(1,6):
		t.check(PillagerPatrols.should_attempt(40,1.0,roll) == (roll == 1),"roll %d %s"%[roll,"lays" if roll == 1 else "does not lay"])

	# --- the band size (`get_regional_difficulty`, `math.ceil`) -------------
	t.check(PillagerPatrols.band_size(1) == 2,"the default difficulty lays a two-strong band")
	t.check(PillagerPatrols.band_size(0) == 1,"peaceful lays a single-member band")
	t.check(PillagerPatrols.band_size(3) == 4,"hard lays a four-strong band")
	t.check(PillagerPatrols.band_size(9) == 6,"the band size is capped")

	# --- the offset draw (`pillager.lua:374-376`) ---------------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var offset_ok: bool = true
	for i in 300:
		var v: Vector3 = PillagerPatrols.offset(rng)
		if absf(v.x) < 24.0 or absf(v.x) > 48.0 or absf(v.z) < 24.0 or absf(v.z) > 48.0: offset_ok = false
	t.check(offset_ok,"the patrol offset stays between 24 and 48 on both axes")

	# --- the mushroom refusal ------------------------------------------------
	t.check(not PillagerPatrols.biome_allowed("MushroomIslands"),"a patrol never lays on the mushroom islands")
	t.check(PillagerPatrols.biome_allowed("Plains"),"a patrol may lay on the plains")

	# --- laying a band -------------------------------------------------------
	game.difficulty = 1
	var before: int = game.creatures.get_child_count()
	var at: Vector3 = game.player.position + Vector3(30,0,30)
	var x: int = floori(at.x); var z: int = floori(at.z)
	var land: Vector3 = Vector3(float(x)+0.5,float(game.world.generator.terrain_height(x,z))+1.02,float(z)+0.5)
	var members: Array = PillagerPatrols.spawn_patrol(game,land,1,rng,func(pos: Vector3) -> Object: return game.spawn_creature("pillager",pos))
	t.check(members.size() == 2,"the band is laid at its difficulty's size")
	t.check(game.creatures.get_child_count() == before+members.size(),"every band member is added to the entity group")
	if members.size() == 2:
		t.check(PillagerPatrols.is_captain(members[0]),"the first member of the band is its raid captain")
		t.check(not PillagerPatrols.is_captain(members[1]),"the rest of the band are ordinary pillagers")
		var patrol_ok: bool = true
		for member in members:
			if not PillagerPatrols.is_patrol_member(member): patrol_ok = false
		t.check(patrol_ok,"every band member carries the patrol flag")

	# --- the captain's ominous bottle (`pillager.lua:133-143`) --------------
	var bottle: int = PotionCatalog.find("ominous","drink","normal")
	t.check(bottle > 0 and PotionCatalog.ITEMS[bottle].potion == "ominous","the ominous bottle exists as a drink")
	t.check(PotionCatalog.is_bottle(bottle),"the ominous bottle is a drinkable bottle")

	if members.size() == 2:
		var captain: Object = members[0]
		var drops_before: int = game.drops.get_child_count()
		captain.health = 0.0
		captain.die()
		var dropped: bool = false
		for drop in game.drops.get_children():
			if drop.item_id == bottle and drop.get_index() >= drops_before-1: dropped = true
		t.check(dropped,"a patrol captain drops the ominous bottle")
		# A raid member is not a captain and would not drop it.
		t.check(not captain.get_meta("raid",false),"a patrol captain is not a raid member")

	# --- the raid path the bottle feeds -------------------------------------
	# Drinking the bottle applies `bad_omen`; `AlchemyWorld.update` consumes a live
	# `bad_omen` beside a village into a raid, which is what makes the drop worth
	# anything. This drives that whole chain.
	game.survival.effects.erase("bad_omen")
	PotionEffects.apply_item(game.player,bottle)
	t.check(PotionEffects.level(game.player,"bad_omen") > 0,"drinking the ominous bottle applies bad_omen")
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
	game.world.adventure_state.erase("raid")
	game.player.position = Vector3(village.center)+Vector3(1,1,1)
	AlchemyWorld.update(game,1.0/60.0)
	t.check(not game.world.adventure_state.get("raid",{}).is_empty(),"a live bad_omen beside a village starts a raid")
	t.check(PotionEffects.level(game.player,"bad_omen") == 0,"triggering the raid consumes the bad_omen")

	game.difficulty = old_difficulty
	game.dimension = old_dimension
	game.player.position = old_position
