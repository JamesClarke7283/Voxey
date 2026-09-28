class_name WitchPotions
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/witch.lua — the `witch_potion_items` table (lines
# 151-195), `witch_equip_potion`/`witch_consume_potion` (136-149) and the drinking
# branch of `witch:ai_step` (291-315) — GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# A witch is not a caster. Everything she does to herself she does by **drinking**,
# and the source gives her four potions in a fixed priority order, each guarded by
# the condition it answers:
#
#   1. **Water Breathing** while her head is in a drowning block and the effect is
#      not already running — `chance = 15`.
#   2. **Fire Resistance** while she is alight and not already resistant —
#      `chance = 15`.
#   3. **Healing** whenever she is below her maximum health — `chance = 5`.
#   4. **Swiftness** while she is chasing something further than eleven blocks —
#      `chance = 50`. Eleven is outside her own ten-block throwing radius, so this
#      is the potion that carries her into range.
#
# The source's frame is a three-stage cycle and all three stages matter:
#
#   * `ai_step` rolls **every minecraft tick**, i.e. every 0.05 s
#     (`self._witch_potion_check < 0.05`, lines 303-306). Each entry draws its own
#     `math.random(1,100)` and the condition is `item.chance >= random`, so a healing
#     potion is equipped on roughly one tick in twenty rather than after a fixed
#     delay.
#   * The first entry that passes both its roll and its test is **equipped** and the
#     loop breaks (lines 308-313), so list order decides a tie: a witch that is both
#     drowning and alight drinks water breathing, never fire resistance.
#   * She then **holds** the potion. `_using_wielditem` climbs and the potion is
#     consumed only once it passes 1.5 s (lines 291-300), which applies its effects
#     and plays a drinking sound (141-149). While she holds one the roll above is
#     skipped entirely, so 1.5 s is the floor between two drinks.
#
# Voxey has no wield-item model, so equipping and drinking are one event here: the
# roll gate is `CHECK_INTERVAL` and the held window is the per-witch recovery timer.
# That reproduces the observable cadence exactly — at most one potion per 1.5 s on a
# 0.05 s roll cadence — while keeping `step` a single hook. The source's equip
# penalty (a 0.75 `movement_speed` factor while a potion is in hand, line 137) has no
# hook here: a witch's speed in Voxey is `Creature.KINDS` scaled by
# `PotionEffects.speed`, neither of which this module owns.
#
# The potion level is the source's own. `witch_consume_potion` drinks with
# `mcl_potions.consume_potion(self.object, potion, 0, 0)` (line 145) — potency and
# "plus" both zero — which `level_from_details` (mcl_potions/functions.lua:2110)
# resolves to the entry's plain level 1. Durations are therefore the source's default
# `mcl_potions.DURATION` (mcl_potions/init.lua:16) of 180 s, and healing is its instant
# `4 * level` (mcl_potions/potions.lua:357-369, functions.lua:2228).
#
# PARENT WIRING (not yet applied; every line below belongs to a file this module must
# not edit):
#
# 1. `scripts/creature.gd`, `_physics_process`, beside the existing per-mob step hook
#    `ZombieVillagers.update(game,self,delta)` (line 855), which is where a witch's
#    own step belongs:
#        if Witches.is_witch(kind): WitchPotions.step(game,self,delta)
#    That point in the shared step is already past the `loaded_at` and distance
#    returns, so the module itself does not re-check whether the witch is in a loaded
#    column.

# Source `self._witch_potion_check < 0.05` (witch.lua:303-306): the roll cadence is
# one minecraft tick.
const CHECK_INTERVAL = 0.05
# Source `self._using_wielditem > 1.5` (witch.lua:296): the potion is drunk 1.5 s
# after it is equipped, and no new potion can be equipped until then.
const DRINK_TIME = 1.5
# Source `local head_y = cbox[2] + (cbox[5] - cbox[2]) * 0.75` (mcl_mobs/api.lua:634),
# which is the cell `witch_potion_items` reads as `self.head_in`.
const HEAD_FRACTION = 0.75
# Source `if pos and dist > 11 then return true end` (witch.lua:187).
const SWIFTNESS_RANGE = 11.0
# `Creature._physics_process` (creature.gd:727) counts a mob as chasing inside
# twenty-four blocks, and keeps chasing for four seconds after it loses sight. Both
# are read here so "she has an attack target" means exactly what it means to the
# creature that would be doing the chasing.
const CHASE_RANGE = 24.0
const CHASE_GRACE = 4.0
# `mcl_potions.consume_potion(self.object, potion, 0, 0)` (witch.lua:145) drinks the
# level-1 potion: `level_from_details` with potency 0 returns the entry's own level.
const POTION_LEVEL = 1
# Source `mcl_potions.healing_func(object, 4 * level, user)` (potions.lua:367), capped
# at the mob's own maximum by `heal_mob` (mcl_mobs/combat.lua:502-508).
const HEAL_PER_LEVEL = 4.0

# The effect names as Voxey's `PotionEffects` registers them; the source's potion
# names are `mcl_potions:water_breathing` and friends.
const WATER_BREATHING = "water_breathing"
const FIRE_RESISTANCE = "fire_resistance"
const HEALING = "healing"
const SWIFTNESS = "swiftness"
# The effect the source tests as `mcl_burning.is_burning(self.object)` (witch.lua:164).
const BURNING = "burning"

# Source `witch_potion_items` (witch.lua:151-195), kept in the order the source tests
# them, because that order is the priority. `chance` is out of a hundred and each
# entry's own condition is the matching function in the conditions section above.
const POTIONS: Array = [
	{"effect":WATER_BREATHING,"chance":15},  # test at witch.lua:154-158
	{"effect":FIRE_RESISTANCE,"chance":15},  # test at witch.lua:162-167
	{"effect":HEALING,"chance":5},           # test at witch.lua:172-174
	{"effect":SWIFTNESS,"chance":50},        # test at witch.lua:179-191
]

# The source's effect particle colours (mcl_potions/functions.lua:322 for water
# breathing, :843 for fire resistance, :524 for swiftness), and its registry default
# (functions.lua:149-150) for anything without one. Healing is absent because the
# source's healing potion gives no effect at all — its `custom_effect` only adds health.
const PARTICLE: Dictionary = {WATER_BREATHING:"98dac0",FIRE_RESISTANCE:"ff9900",
	SWIFTNESS:"33ebff"}
const PARTICLE_DEFAULT = "3000ee"

# The per-witch state, on the creature's own metadata. The source keeps it on her
# luaentity — `_witch_potion_check` and `_using_wielditem` are entity fields
# (witch.lua:109,303) — so it lives exactly as long as the mob node does, and it
# survives pausing, damage, effect changes and being parked out of a loaded column.
# It is deliberately **not** written to the save file, matching the source whose entity
# state is dropped when the entity unloads; a witch restored from a save therefore
# starts ready.
const READY_KEY = "witch_potion_ready"
const CHECK_KEY = "witch_potion_check"

# Only the witch drinks: the rules are attached to that one entity in the source.
static func eligible(kind: String) -> bool: return Witches.is_witch(kind)

# --- the conditions ----------------------------------------------------------

# Source test 1 (witch.lua:154-158): the head is in a node whose `drowning` is above
# zero. Water is the only such node in the source — lava carries `damage_per_second`
# instead (mcl_core/nodes_liquid.lua:38,131-133) — so a witch standing in lava is not
# drowning and does not drink for it.
static func needs_water_breathing(witch: Creature) -> bool:
	if PotionEffects.level(witch,WATER_BREATHING) > 0: return false
	var head: Vector3i = Vector3i((witch.position+Vector3.UP*witch.height*HEAD_FRACTION).floor())
	return Fluids.water(witch.game.world.node_at(head))

# Source test 2 (witch.lua:162-167): alight, and not already resistant. Voxey's
# `burning` effect is its port of `mcl_burning`'s burn timer.
static func needs_fire_resistance(witch: Creature) -> bool:
	return PotionEffects.level(witch,BURNING) > 0 and PotionEffects.level(witch,FIRE_RESISTANCE) == 0

# Source test 3 (witch.lua:172-174): `self.health < hp_max`, i.e. any damage at all.
static func needs_healing(witch: Creature) -> bool:
	return witch.health < witch.info().health

# Source test 4 (witch.lua:179-191): she has an attack target, is not already swift,
# and that target is further than eleven blocks away. "Has an attack target" is the
# source's `self.attack` being set, which mcl_mobs fills only for a mob that is
# actively hunting — so this reproduces the same gates `Creature._physics_process`
# itself uses to decide a mob is chasing: hostile and awake to the player, inside its
# twenty-four-block chase range, and in sight.
static func needs_swiftness(witch: Creature) -> bool:
	if PotionEffects.level(witch,SWIFTNESS) > 0: return false
	if not witch.aggressive(): return false
	if witch.position.distance_to(witch.game.player.position) >= CHASE_RANGE: return false
	if not witch._sees_player() and witch.life-witch.last_seen >= CHASE_GRACE: return false
	return witch.position.distance_to(witch.game.player.position) > SWIFTNESS_RANGE

static func applies(witch: Creature, effect: String) -> bool:
	if effect == WATER_BREATHING: return needs_water_breathing(witch)
	if effect == FIRE_RESISTANCE: return needs_fire_resistance(witch)
	if effect == HEALING: return needs_healing(witch)
	if effect == SWIFTNESS: return needs_swiftness(witch)
	return false

# --- choosing ----------------------------------------------------------------

# The source's loop (witch.lua:308-313): each entry draws its own 1-in-100 roll and
# the first entry whose roll passes *and* whose condition holds is the one she equips.
# `rng` is for a caller that needs a reproducible draw; without one the global stream
# is used, as elsewhere in the codebase.
static func choose(witch: Creature, rng: RandomNumberGenerator = null) -> Dictionary:
	if witch == null or not is_instance_valid(witch) or not eligible(witch.kind): return {}
	for entry in POTIONS:
		# The source tests `item.chance >= random` *before* `item.test(self)`, so a
		# failed roll never evaluates the condition.
		var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
		if int(entry.chance) < roll: continue
		var effect: String = entry.effect
		if not applies(witch,effect): continue
		return {"effect":effect,"duration":duration(effect),"level":POTION_LEVEL,
			"heal":HEAL_PER_LEVEL*POTION_LEVEL if effect == HEALING else 0.0}
	return {}

# The potion's own duration. `duration_from_details` with potency zero returns the
# entry's `dur` (mcl_potions/functions.lua:2117-2130), and `register_potion` fills in
# `mcl_potions.DURATION` of 180 s where an entry omits one (mcl_potions/potions.lua:166,
# init.lua:16). Voxey already carries those numbers in `PotionCatalog.DEFINITIONS`, so
# they are read from there rather than repeated. Healing's is zero: it is instant.
static func duration(effect: String) -> float:
	return float(PotionCatalog.DEFINITIONS.get(effect,{}).get("duration",0.0))

# --- drinking ----------------------------------------------------------------

# The per-step hook. Returns whether she drank on this step. `mob` must be a witch; the
# caller skips unloaded cells, as `Creature._physics_process` does before it reaches the
# dispatch line. The optional `rng` exists so a test can reproduce a specific draw.
static func step(game: Node3D, mob: Creature, delta: float, rng: RandomNumberGenerator = null) -> bool:
	if mob == null or not is_instance_valid(mob) or not eligible(mob.kind): return false
	# A dead witch drinks nothing: the source's `target_valid` refuses an entity at or
	# below zero health (mcl_potions/functions.lua:2134), and `healing_func` repeats it
	# explicitly (:2229).
	if mob.health <= 0.0 or mob.is_queued_for_deletion(): return false
	# The held window. The source returns before it even accumulates the roll timer
	# while a potion is in hand (witch.lua:291-300), so the gap between two drinks is
	# the full 1.5 s plus the next roll tick.
	var ready: float = float(mob.get_meta(READY_KEY,0.0))-delta
	if ready > 0.0:
		mob.set_meta(READY_KEY,ready)
		return false
	mob.set_meta(READY_KEY,0.0)
	# The source rolls on the minecraft tick (witch.lua:303-306).
	var check: float = float(mob.get_meta(CHECK_KEY,0.0))+delta
	if check < CHECK_INTERVAL:
		mob.set_meta(CHECK_KEY,check)
		return false
	mob.set_meta(CHECK_KEY,0.0)
	var choice: Dictionary = choose(mob,rng)
	if choice.is_empty(): return false
	drink(game,mob,choice)
	mob.set_meta(READY_KEY,DRINK_TIME)
	return true

# Apply a chosen potion, which is the source's `witch_consume_potion` (witch.lua:141-149).
static func drink(game: Node3D, mob: Creature, choice: Dictionary) -> void:
	var effect: String = choice.effect
	if effect == HEALING:
		# The source's healing potion carries no duration: its `custom_effect` only
		# calls `healing_func(object, 4 * level)`, which adds to health and clamps at
		# the mob's own maximum (`heal_mob`, mcl_mobs/combat.lua:502-508). Voxey's
		# effect list has a "healing" entry with the same rule, but a witch's potion
		# leaves no timer to hold, so the health is added here directly.
		mob.health = minf(mob.info().health,mob.health+float(choice.heal))
	else:
		PotionEffects.apply(mob,effect,float(choice.duration),int(choice.level))
		# The source spawns the effect's own particles on the drinker
		# (mcl_potions/functions.lua:1623-1640), coloured per effect.
		game.puff(mob.center(),Color(PARTICLE.get(effect,PARTICLE_DEFAULT)),10,1.5)
	# The source plays a drinking sound as the potion goes down (witch.lua:148).
	# Voxey's synthesized samples have no drinking one; the eating sample is the same
	# short blip.
	game.sound_at("eat",mob.position,mob.info().pitch)
