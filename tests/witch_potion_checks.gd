extends RefCounted

# Focused regression for the witch's self-buff potion drinking (Mineclonia
# `mobs_mc/witch.lua`: the `witch_potion_items` table, `witch_equip_potion` /
# `witch_consume_potion` and the drinking branch of `witch:ai_step`).
#
# Voxey already had the witch as a ranged attacker with her own drop table, but she
# never drank: the four potions she carries — water breathing, fire resistance,
# healing, swiftness — and the conditions that trigger them were missing, so a witch
# in water drowned and a burning witch burned exactly like any other mob. This is the
# source's own list, in its own priority order, with its own per-potion chances.
#
# The suite drives the real creature spawned into loaded terrain, with a fixed
# `RandomNumberGenerator` so each draw is reproducible.

# A spot above the terrain ceiling, where nothing but the cells this suite places
# can interfere.
const BASE = Vector3i(8,175,8)

# Draw sequences, searched against the source's own thresholds. Each seed's first
# `choose()` call consumes four 1-in-100 rolls, one per potion entry in table order
# (witch.lua:308-313), and the effect under test is the entry those rolls select:
#   seed 6   -> [ 7,79,25,32]  water breathing passes on its own 15
#   seed 8   -> [85,14,85,82]  fire resistance passes on its own 15
#   seed 58  -> [53,93, 3,32]  healing passes on its own 5
#   seed 1   -> [98,69,90,49]  swiftness passes on its own 50
#   seed 34  -> [ 1, 3,23,56]  water breathing *and* fire resistance both pass, so
#                              the result shows which the table order preferred
const WATER_SEED = 6
const FIRE_SEED = 8
const HEAL_SEED = 58
const SWIFT_SEED = 1
const BOTH_SEED = 34

static func rng_for(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

static func ground(world: VoxelWorld, p: Vector3i) -> void:
	for x in range(p.x-2,p.x+3):
		for z in range(p.z-2,p.z+3):
			for y in range(p.y,p.y+5): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for x in range(p.x-2,p.x+3):
		for z in range(p.z-2,p.z+3): world.set_node(Vector3i(x,p.y-1,z),Nodes.STONE)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var old_position: Vector3 = game.player.position
	var old_health: float = game.player.health
	game.player.position = Vector3(BASE)
	PotionEffects.clear(game.player)
	# The cells this suite builds are above the terrain ceiling, so they only exist
	# inside a loaded column. The player's own column is loaded already; this is the
	# same guarantee `witch_hut_checks` makes before it places anything.
	var column := Vector2i(floori(BASE.x/16.0),floori(BASE.z/16.0))
	if not world.columns.has(column):
		world._apply_column(world.generator.generate_column(column,world.edits))
	t.check(world.loaded_at(Vector3(BASE)),"the test column is loaded, so terrain can be placed in it")
	ground(world,BASE)

	# --- only the witch drinks ----------------------------------------------
	t.check(WitchPotions.eligible(Witches.KIND),"a witch is eligible to drink")
	t.check(not WitchPotions.eligible("cat"),"the cat is not: the rule belongs to the witch")
	t.check(not WitchPotions.eligible("pillager"),"nor is another ranged attacker")

	# --- the source's table -------------------------------------------------
	# Four potions, in the source's order, with the source's own chances out of a
	# hundred. Order is priority, so it is checked as written.
	var expected: Array = [["water_breathing",15],["fire_resistance",15],["healing",5],["swiftness",50]]
	var actual: Array = []
	for entry in WitchPotions.POTIONS: actual.append([entry.effect,int(entry.chance)])
	t.check(actual == expected,"the source's four potions are carried in its own priority order and chances")
	t.check(is_equal_approx(WitchPotions.CHECK_INTERVAL,0.05),"the roll cadence is the source's one minecraft tick")
	t.check(is_equal_approx(WitchPotions.DRINK_TIME,1.5),"a potion is held for the source's 1.5 seconds before it goes down")
	t.check(is_equal_approx(WitchPotions.SWIFTNESS_RANGE,11.0),"swiftness is taken beyond the source's eleven blocks")
	t.check(is_equal_approx(WitchPotions.HEAL_PER_LEVEL,4.0),"healing restores the source's four health")
	# Durations come from the source's default 180 seconds, which Voxey already
	# carries in its potion catalogue.
	for effect in ["water_breathing","fire_resistance","swiftness"]:
		t.check(is_equal_approx(WitchPotions.duration(effect),180.0),"the %s potion lasts the source's 180 seconds"%effect)
	t.check(is_equal_approx(WitchPotions.duration("healing"),0.0),"healing is instant, so it carries no duration")

	# --- a healthy witch on dry land wants nothing ---------------------------
	var witch: Creature = game.spawn_creature(Witches.KIND,Vector3(BASE))
	t.check(witch != null,"a witch spawns in loaded terrain")
	if witch == null:
		game.player.position = old_position; game.player.health = old_health
		return
	witch.position = Vector3(BASE)+Vector3(3,0,0)
	witch.health = witch.info().health
	PotionEffects.clear(witch)
	t.check(WitchPotions.choose(witch,rng_for(WATER_SEED)).is_empty(),"a healthy witch on dry land drinks nothing")
	t.check(WitchPotions.choose(witch,rng_for(BOTH_SEED)).is_empty(),"and nothing even on a lucky roll")

	# --- water breathing while her head is in water --------------------------
	# The source's test reads the head cell, and only water drowns: lava carries the
	# source's `damage_per_second` instead of its `drowning`.
	world.set_node(BASE,Nodes.WATER)
	world.set_node(BASE+Vector3i.UP,Nodes.WATER)
	witch.position = Vector3(BASE)
	t.check(WitchPotions.needs_water_breathing(witch),"a witch whose head is in water wants water breathing")
	var chose: Dictionary = WitchPotions.choose(witch,rng_for(WATER_SEED))
	t.check(String(chose.get("effect","")) == "water_breathing","the water breathing potion is chosen underwater")
	t.check(int(chose.get("level",0)) == 1,"the potion is drunk at the source's level one")
	t.check(is_equal_approx(float(chose.get("duration",0)),180.0),"with the source's duration")

	# --- fire resistance while burning --------------------------------------
	# On dry land, so only the burning condition applies.
	world.set_node(BASE,Nodes.AIR)
	world.set_node(BASE+Vector3i.UP,Nodes.AIR)
	PotionEffects.clear(witch)
	t.check(not WitchPotions.needs_water_breathing(witch),"back on dry land she no longer wants water breathing")
	PotionEffects.apply(witch,WitchPotions.BURNING,5.0)
	t.check(PotionEffects.level(witch,WitchPotions.BURNING) > 0,"the witch can be set alight")
	t.check(WitchPotions.needs_fire_resistance(witch),"a burning witch wants fire resistance")
	chose = WitchPotions.choose(witch,rng_for(FIRE_SEED))
	t.check(String(chose.get("effect","")) == "fire_resistance","the fire resistance potion is chosen while burning")

	# --- healing whenever she is hurt ---------------------------------------
	PotionEffects.clear(witch)
	witch.health = 10.0
	t.check(WitchPotions.needs_healing(witch),"a wounded witch wants healing")
	chose = WitchPotions.choose(witch,rng_for(HEAL_SEED))
	t.check(String(chose.get("effect","")) == "healing","the healing potion is chosen below full health")
	t.check(is_equal_approx(float(chose.get("heal",0)),4.0),"healing is the source's four health, applied instantly")

	# --- swiftness while chasing at range -----------------------------------
	witch.health = witch.info().health
	PotionEffects.clear(witch)
	t.check(witch.aggressive(),"the witch is hostile towards the player")
	t.check(not WitchPotions.needs_swiftness(witch),"she does not want swiftness with the player in reach")
	witch.position = Vector3(BASE)+Vector3(12,0,0)
	t.check(WitchPotions.needs_swiftness(witch),"she wants swiftness beyond the source's eleven blocks")
	chose = WitchPotions.choose(witch,rng_for(SWIFT_SEED))
	t.check(String(chose.get("effect","")) == "swiftness","the swiftness potion is chosen while chasing at range")
	t.check(is_equal_approx(float(chose.get("duration",0)),180.0),"swiftness lasts the source's 180 seconds")

	# --- list order decides a tie -------------------------------------------
	# Both water breathing and fire resistance apply. Which is drunk depends only on
	# which entry's own roll passed first, which is what the source's `break` means.
	world.set_node(BASE,Nodes.WATER)
	world.set_node(BASE+Vector3i.UP,Nodes.WATER)
	witch.position = Vector3(BASE)
	PotionEffects.clear(witch)
	PotionEffects.apply(witch,WitchPotions.BURNING,5.0)
	t.check(WitchPotions.needs_water_breathing(witch) and WitchPotions.needs_fire_resistance(witch),"drowning and alight at once, both conditions hold")
	chose = WitchPotions.choose(witch,rng_for(BOTH_SEED))
	t.check(String(chose.get("effect","")) == "water_breathing","the earlier entry in the table wins the tie")
	chose = WitchPotions.choose(witch,rng_for(FIRE_SEED))
	t.check(String(chose.get("effect","")) == "fire_resistance","and the later entry is still reachable when the earlier roll fails")

	# --- drinking through `step` ---------------------------------------------
	# The roll is gated on the source's tick, so four centisecond steps cannot drink
	# and the fifth can.
	witch.position = Vector3(BASE)
	PotionEffects.clear(witch)
	witch.health = witch.info().health
	witch.remove_meta(WitchPotions.READY_KEY)
	witch.remove_meta(WitchPotions.CHECK_KEY)
	t.check(not WitchPotions.step(game,witch,0.01,rng_for(WATER_SEED)),"a step shorter than the tick does not roll")
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.CHECK_KEY,0.0)),0.01),"but it is accumulated towards the next one")
	t.check(PotionEffects.level(witch,WitchPotions.WATER_BREATHING) == 0,"so no potion has been drunk yet")
	t.check(WitchPotions.step(game,witch,WitchPotions.CHECK_INTERVAL,rng_for(WATER_SEED)),"reaching the source's tick rolls and drinks")
	t.check(PotionEffects.level(witch,WitchPotions.WATER_BREATHING) == 1,"the water breathing effect really applies")
	t.check(is_equal_approx(float(witch.get_meta("effect_water_breathing",0.0)),180.0),"with the source's duration on the creature")

	# --- the cooldown --------------------------------------------------------
	# Healing is the potion used for the repeat, because it is the only one of the four
	# whose condition can be true twice in a row: its test is just "below maximum
	# health" (witch.lua:172-174), whereas each of the other three refuses while its
	# own effect is running. A drink is therefore observable in the health it restores.
	# Every step gets its own generator so the draws stay reproducible across calls.
	PotionEffects.clear(witch)
	world.set_node(BASE,Nodes.AIR)
	world.set_node(BASE+Vector3i.UP,Nodes.AIR)
	witch.position = Vector3(BASE)+Vector3(3,0,0)
	witch.health = 10.0
	witch.remove_meta(WitchPotions.READY_KEY)
	witch.remove_meta(WitchPotions.CHECK_KEY)
	t.check(WitchPotions.step(game,witch,0.5,rng_for(HEAL_SEED)),"the witch drinks healing on the first step")
	t.check(is_equal_approx(witch.health,14.0),"the potion restores its four health")
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.READY_KEY,0.0)),WitchPotions.DRINK_TIME),"the per-witch cooldown is set as the potion goes down")
	t.check(not WitchPotions.step(game,witch,0.5,rng_for(HEAL_SEED)),"half a second later she is still holding the potion")
	t.check(not WitchPotions.step(game,witch,0.5,rng_for(HEAL_SEED)),"and at a full second")
	t.check(is_equal_approx(witch.health,14.0),"so no health has been restored early")
	t.check(WitchPotions.step(game,witch,0.5,rng_for(HEAL_SEED)),"at the source's 1.5 seconds she drinks again")
	t.check(is_equal_approx(witch.health,18.0),"and the second potion restores another four health")

	# --- what the cooldown store survives ------------------------------------
	# The timer lives on the creature's own metadata, exactly as the source keeps
	# `_using_wielditem` and `_witch_potion_check` on the witch's luaentity. So it
	# rides through anything that leaves the node alive, and dies with the node.
	var ready: float = float(witch.get_meta(WitchPotions.READY_KEY,0.0))
	t.check(ready > 0.0,"the witch is on cooldown")
	PotionEffects.clear(witch)
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.READY_KEY,0.0)),ready),"clearing her effects leaves the cooldown untouched")
	witch.hit(1.0)
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.READY_KEY,0.0)),ready),"taking damage leaves the cooldown untouched")
	var away: Vector3 = Vector3(BASE)+Vector3(9000,0,0)
	witch.position = away
	t.check(not world.loaded_at(away),"the witch can be parked outside every loaded column")
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.READY_KEY,0.0)),ready),"leaving the loaded area leaves the cooldown untouched")
	witch.position = Vector3(BASE)+Vector3(12,0,0)
	# A second witch is not gated by the first one's timer: the store is per creature.
	var second: Creature = game.spawn_creature(Witches.KIND,Vector3(BASE)+Vector3(12,0,1))
	t.check(second != null and not second.has_meta(WitchPotions.READY_KEY),"a second witch starts with no cooldown of her own")
	PotionEffects.clear(second)
	second.health = second.info().health
	second.position = Vector3(BASE)+Vector3(12,0,0)
	t.check(WitchPotions.step(game,second,0.5,rng_for(SWIFT_SEED)),"and drinks immediately, whatever the first witch is doing")
	t.check(is_equal_approx(float(witch.get_meta(WitchPotions.READY_KEY,0.0)),ready),"which does not disturb the first witch's timer")
	second.queue_free()

	# It does not survive the node, which is the source's behaviour too: nothing
	# records a witch in the save, so a reloaded one is freshly ready.
	t.check(not Creature.ALCHEMY_KINDS.has(Witches.KIND),"a witch is not one of the kinds the save records")
	var fresh: Creature = game.spawn_creature(Witches.KIND,Vector3(BASE)+Vector3(0,0,1))
	t.check(fresh != null and not fresh.has_meta(WitchPotions.READY_KEY),"a newly spawned witch carries no cooldown from any other")

	# --- drinking really does its job ----------------------------------------
	# Fire resistance has to stop the burning damage, which is the reason she drinks it.
	PotionEffects.clear(witch)
	PotionEffects.apply(witch,WitchPotions.BURNING,5.0)
	witch.health = witch.info().health
	PotionEffects.update(witch,1.0)
	t.check(witch.health < witch.info().health,"an unprotected witch takes burning damage")
	var burning_health: float = witch.health
	PotionEffects.apply(witch,WitchPotions.FIRE_RESISTANCE,30.0)
	PotionEffects.update(witch,1.0)
	t.check(is_equal_approx(witch.health,burning_health),"fire resistance stops the burning damage")
	# And healing really restores health, clamped at the source's maximum.
	PotionEffects.clear(witch)
	witch.health = 10.0
	WitchPotions.drink(game,witch,{"effect":"healing","duration":0.0,"level":1,"heal":4.0})
	t.check(is_equal_approx(witch.health,14.0),"drinking a healing potion restores four health")
	WitchPotions.drink(game,witch,{"effect":"healing","duration":0.0,"level":1,"heal":4.0})
	t.check(PotionEffects.level(witch,"healing") == 0,"a healing potion leaves no timed effect behind")
	witch.health = witch.info().health
	WitchPotions.drink(game,witch,{"effect":"healing","duration":0.0,"level":1,"heal":4.0})
	t.check(is_equal_approx(witch.health,witch.info().health),"healing cannot push a witch past her own maximum")

	# --- a dead or wrong creature drinks nothing ----------------------------
	PotionEffects.clear(witch)
	witch.health = 0.0
	t.check(not WitchPotions.step(game,witch,1.0,rng_for(WATER_SEED)),"a dead witch drinks nothing")
	witch.health = witch.info().health
	t.check(not WitchPotions.step(game,second,1.0,rng_for(WATER_SEED)),"a freed witch is not stepped")

	# --- cleanup -------------------------------------------------------------
	witch.queue_free()
	fresh.queue_free()
	for x in range(BASE.x-2,BASE.x+3):
		for z in range(BASE.z-2,BASE.z+3):
			for y in range(BASE.y-1,BASE.y+5): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.player.position = old_position
	game.player.health = old_health
