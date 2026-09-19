class_name Illagers
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/villager_vindicator.lua and villager_evoker.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# The woodland mansion needed two illagers Voxey did not have, and one of them
# closes a real gap:
#
#   * A **vindicator** — a melee illager with an iron axe, dropping emeralds.
#   * An **evoker** — a spellcaster whose drop is the **totem of undying**.
#
# The evoker is the important one. Voxey has the totem and its whole lethal-damage
# interception, but the totem was **unobtainable in survival**: there was no drop,
# no recipe and no structure anywhere that produced one. The source's evoker drops
# a totem at `chance = 1`, which is always, so the evoker is the only route — and
# this batch adds it.
#
# The vindicator's `chance = 1` emerald with a minimum of zero produces "no
# emerald" some of the time, which the shared drop tuple can express directly.

const VINDICATOR = "vindicator"
const EVOKER = "evoker"
# Source `hp_min = 24` for both.
const HEALTH = 24.0
# The evoker's totem is a guaranteed drop, which is the whole point of it.
const TOTEM_ALWAYS = true

static func is_illager(kind: String) -> bool:
	return kind == VINDICATOR or kind == EVOKER

static func is_evoker(kind: String) -> bool: return kind == EVOKER

# The source's drop table for an evoker, as [item, chance-denominator, min, max].
# A denominator of one always drops, so the totem is guaranteed.
static func drop_table(kind: String) -> Array:
	if kind == VINDICATOR:
		# The source's emerald, at one in one with a minimum of zero: the shared
		# tuple expresses the zero minimum directly.
		return [[VillageContent.EMERALD,1,0,1]]
	if kind == EVOKER:
		return [[VillageContent.TOTEM,1,1,1]]
	return []

# Roll an illager's drops, applying the source's per-entry chance denominator.
static func roll_drops(kind: String, rng: RandomNumberGenerator, looting: int = 0) -> Array:
	var result: Array = []
	for entry in drop_table(kind):
		var denominator: int = maxi(1,int(entry[1]))
		if looting > 0: denominator = maxi(1,denominator-looting)
		if rng.randi_range(1,denominator) != 1: continue
		var count: int = rng.randi_range(int(entry[2]),int(entry[3]))
		if count > 0: result.append([int(entry[0]),count])
	return result
