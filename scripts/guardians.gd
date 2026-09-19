class_name Guardians
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/{guardian,guardian_elder}.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# The guardian is the ocean's ranged threat. Its defining feature is that it does
# not touch its target: it **charges a laser for four seconds** (three for the
# elder) while tracking the player, and then deals magic damage plus a physical
# punch, which is the source's `attack_null`.
#
#   * `_default_laser_delay` 4.0 for a guardian, 3.0 for an elder.
#   * Damage 6 for a guardian and 8 for an elder; magic damage is the source's
#     `magic_damage` of 1.0 (3.0 on hard difficulty).
#   * A guardian will not attack a target closer than **3 blocks** — it paces and
#     breaks off instead, which the source's `get_active_target` enforces with a
#     squared distance of 9.
#   * `swims = true`: guardians are aquatic and never drown.
#
# Their drops are what closes three separate gaps in this project:
#
# | Drop | Chance | Gap it closes |
# |---|---|---|
# | Prismarine shard ×0–2 | always | the conduit's frame material |
# | Prismarine crystals | 1-in-4 | conduit crafting |
# | Wet sponge | always, elder only | the sponge's survival route |
# | Raw fish ×1 | 1-in-4 | |
# | Cod, salmon, pufferfish | 1-in-160 each | |
#
# The source's `chance` field is a **denominator**, so `chance = 1` is always and
# `chance = 4` is one in four. Voxey's drop tuples carry no chance field, so the
# rolls are applied here rather than in the shared creature table.

const ELDER = "guardian_elder"
const NORMAL = "guardian"
# Source `attack_null`: these are the values that matter to the exchange.
const LASER_DELAY = 4.0
const ELDER_LASER_DELAY = 3.0
const MIN_ATTACK_DISTANCE = 3.0
const MAGIC_DAMAGE = 1.0

static func is_guardian(kind: String) -> bool: return kind == NORMAL or kind == ELDER
static func is_elder(kind: String) -> bool: return kind == ELDER

# The laser's charge time for a kind, which is the source's own default.
static func laser_delay(kind: String) -> float:
	return ELDER_LASER_DELAY if is_elder(kind) else LASER_DELAY

# `get_active_target`: a guardian ignores anything within three blocks.
static func will_attack(distance: float) -> bool:
	return distance > MIN_ATTACK_DISTANCE

# The source's drop table for a guardian, as [item, chance-denominator, min, max].
# A denominator of 1 always drops; the min may still be 0, which is how the
# shard's 0-2 range produces "no shard" some of the time.
const DROPS = [[VillageContent.PRISMARINE_SHARD,1,0,2],
	[VillageContent.PRISMARINE_CRYSTALS,4,1,2],
	[VillageContent.RAW_COD,4,1,1],
	[VillageContent.RAW_COD,160,1,1],
	[VillageContent.RAW_SALMON,160,1,1],
	[VillageContent.RAW_COD,160,1,1],
	[VillageContent.PUFFERFISH,160,1,1]]
# The elder's own additions, which are the sponge's only source.
const ELDER_DROPS = [[Sponges.WET,1,1,1]]

static func drop_table(kind: String) -> Array:
	return DROPS+ELDER_DROPS if is_elder(kind) else DROPS

# Roll a guardian's drops, applying the source's per-entry chance denominator.
static func roll_drops(kind: String, rng: RandomNumberGenerator, looting: int = 0) -> Array:
	var result: Array = []
	for entry in drop_table(kind):
		var item: int = int(entry[0])
		var denominator: int = int(entry[1])
		var low: int = int(entry[2])
		var high: int = int(entry[3])
		var chance: float = 1.0/float(denominator)
		# Source `common` looting adds a flat roll on top of a successful hit.
		var common: bool = denominator <= 4
		var hit: bool = rng.randf() < chance
		if not hit and common: continue
		var amount: int = 0
		if hit: amount = rng.randi_range(low,high)
		if common and looting > 0: amount += int(floor(rng.randi_range(0,looting)+0.5))
		if amount > 0: result.append([item,amount])
	return result
