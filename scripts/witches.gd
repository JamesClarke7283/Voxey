class_name Witches
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/witch.lua and the cat half of ocelot.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# The witch hut needed two creatures Voxey did not have:
#
#   * A **witch** — the source's ranged attacker that throws potions. She is the
#     hut's resident, and her drop table is the brewing chain's supply: redstone
#     (4 to 8, always), glowstone dust, gunpowder, glass bottles, spider eyes and
#     sugar. A witch is therefore one of the few reliable sources of **redstone**
#     above ground.
#   * A **cat** — the hut spawns one **all-black** cat beside her, which the
#     source sets explicitly by overriding the texture.
#
# The witch's `chance` field is a denominator, so `chance = 8` is one in eight —
# the same convention the guardian and aquatic drops use. The shared creature drop
# table cannot express a denominator, so her rolls live here.

const KIND = "witch"
const CAT = "cat"

# Source `hp_min = 26`.
const HEALTH = 26.0
# Source `ranged_interval_min/max = 3.0`.
const THROW_INTERVAL = 3.0
# Source `reach = 2`, and she throws from further out than she melees.
const THROW_RANGE = 10.0
# The source's potion damage, which is what a thrown potion does on a hit.
const POTION_DAMAGE = 6.0
# A cat's own health.
const CAT_HEALTH = 10.0
# The source overrides the hut cat's texture to all black.
const CAT_COLOUR = "1e1a1a"

static func is_witch(kind: String) -> bool: return kind == KIND
static func is_cat(kind: String) -> bool: return kind == CAT

# The source's drop table, as [item, chance-denominator, min, max]. A denominator
# of 1 always drops, so redstone always does.
static func drop_table() -> Array:
	return [[Nodes.REDSTONE_WIRE,1,4,8],[VillageContent.GLASS_BOTTLE,8,0,2],
		[VillageContent.GLOWSTONE_DUST,8,0,2],[Nodes.GUNPOWDER,8,0,2],
		[VillageContent.SPIDER_EYE,8,0,2],[Nodes.SUGAR,8,0,2],[Nodes.STICK,4,0,2]]

# Roll a witch's drops, applying the source's per-entry chance denominator.
static func roll_drops(rng: RandomNumberGenerator, looting: int = 0) -> Array:
	var result: Array = []
	for entry in drop_table():
		var denominator: int = maxi(1,int(entry[1]))
		if looting > 0: denominator = maxi(1,denominator-looting)
		if rng.randi_range(1,denominator) != 1: continue
		var count: int = rng.randi_range(int(entry[2]),int(entry[3]))
		if count > 0: result.append([int(entry[0]),count])
	return result
