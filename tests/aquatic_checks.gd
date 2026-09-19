extends RefCounted

# Focused regression for the aquatic creatures (Mineclonia mobs_mc cod, salmon,
# pufferfish, tropical_fish, squid and glow_squid).
#
# Voxey had every fish *item* already — raw cod, raw salmon, pufferfish, tropical
# fish, ink sac — but no fish to catch, so the only route to any of them was the
# fishing table and the ink sac had no mob at all. These are the source's own
# creatures with its own sizes, health and drop chances.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"

	# --- the creatures exist ------------------------------------------------
	t.check(AquaticMobs.FISH.size() == 4,"the source's four fish are all registered")
	t.check(AquaticMobs.SQUIDS.size() == 2,"both squid variants are registered")
	for kind in ["cod","salmon","pufferfish","tropical_fish","squid","glow_squid"]:
		t.check(Creature.KINDS.has(kind),"the %s creature is registered" % kind)
		t.check(AquaticMobs.is_aquatic(kind),"the %s counts as aquatic" % kind)
		t.check(Creature.KINDS[kind].get("swims",false),"the %s swims rather than falling" % kind)

	# --- the source's sizes and health --------------------------------------
	# Fish have three health; squid have ten. The collision box follows suit.
	for kind in AquaticMobs.FISH:
		t.check(is_equal_approx(AquaticMobs.health(kind),3.0),"the %s has the source's three health" % kind)
	for kind in AquaticMobs.SQUIDS:
		t.check(is_equal_approx(AquaticMobs.health(kind),10.0),"the %s has the source's ten health" % kind)
	t.check(AquaticMobs.width("cod") < AquaticMobs.width("squid"),"a squid is larger than a cod")

	# --- every fish yields its own raw item --------------------------------
	# This is what makes them worth catching: each fish's drop is its own item.
	for kind in AquaticMobs.FISH:
		t.check(AquaticMobs.raw_item(kind) != 0,"the %s yields its own raw item" % kind)
	var raws: Dictionary = {}
	for kind in AquaticMobs.FISH: raws[AquaticMobs.raw_item(kind)] = true
	t.check(raws.size() == 4,"the four fish yield four distinct raw items")

	# --- the source's chance denominators -----------------------------------
	# `chance` is a denominator, so a fish drops its raw item always and bone
	# meal at one in twenty. The shared drop table cannot express that.
	var rng := RandomNumberGenerator.new(); rng.seed = 17
	var got: Dictionary = {}
	for i in 4000:
		for entry in AquaticMobs.roll_drops("cod",rng):
			got[int(entry[0])] = int(got.get(int(entry[0]),0))+int(entry[1])
	t.check(int(got.get(VillageContent.RAW_COD,0)) == 4000,"a cod always yields its raw cod, at the source's chance of one")
	var meal: int = int(got.get(Nodes.BONE_MEAL,0))
	t.check(meal > 0,"a cod can yield bone meal")
	# One in twenty of 4000 is 200; allow a wide band for the roll.
	t.check(meal > 120 and meal < 300,"the bone meal drop follows the source's one-in-twenty denominator")

	# A squid's glow ink sac is the rarer of its two drops.
	var squid_rng := RandomNumberGenerator.new(); squid_rng.seed = 23
	var squid: Dictionary = {}
	for i in 4000:
		for entry in AquaticMobs.roll_drops("squid",squid_rng):
			squid[int(entry[0])] = int(squid.get(int(entry[0]),0))+int(entry[1])
	t.check(int(squid.get(VillageContent.INK_SAC,0)) > 0,"a squid yields an ink sac")
	t.check(int(squid.get(VillageContent.GLOW_INK_SAC,0)) > 0,"a squid can yield a glow ink sac")
	t.check(int(squid.get(VillageContent.GLOW_INK_SAC,0)) < int(squid.get(VillageContent.INK_SAC,0)),"the glow ink sac is rarer than the ordinary one, as the source's denominator makes it")
	# A glow squid's guaranteed drop is the glow ink sac, never the ordinary one.
	# Count how many of the rolls dropped it, not how many items were summed.
	var glow_rng := RandomNumberGenerator.new(); glow_rng.seed = 29
	var glow_drops: int = 0
	var glow_ordinary: int = 0
	for i in 1000:
		for entry in AquaticMobs.roll_drops("glow_squid",glow_rng):
			if int(entry[0]) == VillageContent.GLOW_INK_SAC: glow_drops += 1
			if int(entry[0]) == VillageContent.INK_SAC: glow_ordinary += 1
	t.check(glow_drops == 1000,"a glow squid always yields glow ink sac")
	t.check(glow_ordinary == 0,"a glow squid never yields an ordinary ink sac")

	# Both ink sacs are real registered items.
	t.check(VillageContent.DATA.has(VillageContent.GLOW_INK_SAC),"the glow ink sac is a registered item")
	t.check(VillageContent.GLOW_INK_SAC != VillageContent.INK_SAC,"the two ink sacs are distinct items")

	# --- they spawn and are drawn -------------------------------------------
	# Every kind must build a real model and a real drop table, or the creature
	# would exist without being catchable.
	for kind in ["cod","salmon","pufferfish","tropical_fish","squid","glow_squid"]:
		var mob: Creature = game.spawn_creature(kind,game.player.position+Vector3(0,3,0))
		t.check(mob != null,"the %s can be spawned" % kind)
		if mob == null: continue
		t.check(mob.info().drops.is_empty(),"the %s rolls its drops by denominator, not from the shared table" % kind)
		t.check(mob.model.get_child_count() > 0,"the %s builds a visible model" % kind)
		mob.queue_free()

	# The spawn picker offers fish more often than squid, and never an unknown
	# kind that would fall back to a sheep.
	var seen: Dictionary = {}
	for i in 200: seen[AquaticMobs.pick(i)] = true
	t.check(seen.size() == 6,"the spawn picker covers all six creatures")
	var fish_seen: bool = true
	for kind in seen:
		if not AquaticMobs.is_aquatic(String(kind)): fish_seen = false
	t.check(fish_seen,"the spawn picker never yields a non-aquatic kind")

	# --- a fish really yields its item when killed --------------------------
	var victim: Creature = game.spawn_creature("cod",game.player.position+Vector3(0,3,0))
	if victim != null:
		var before: int = game.drops.get_child_count()
		victim.die()
		t.check(game.drops.get_child_count() > before,"a killed cod leaves a drop behind")
		victim.queue_free()
