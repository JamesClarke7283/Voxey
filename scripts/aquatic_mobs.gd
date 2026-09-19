class_name AquaticMobs
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/{cod,salmon,pufferfish,tropical_fish,squid+glow_squid}.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Voxey had every fish *item* — raw cod, raw salmon, pufferfish, tropical fish,
# ink sac — but no fish. The only route to any of them was the fishing table,
# so a player could never see a fish swim, and the ink sac had no mob at all.
#
# These are the source's own creatures, with its own sizes and drops:
#
# | Creature | Health | Drops |
# |---|---|---|
# | Cod | 3 | Raw cod, and bone meal at 1 in 20 |
# | Salmon | 3 | Raw salmon, and bone meal at 1 in 20 |
# | Pufferfish | 3 | Pufferfish, and bone meal at 1 in 20 |
# | Tropical fish | 3 | Tropical fish, and bone meal at 1 in 20 |
# | Squid | 10 | Ink sac at 1 in 1, or glow ink sac at 1 in 10 |
# | Glow squid | 10 | Glow ink sac at 1 in 1 |
#
# The source's `chance` field is a **denominator**, so `chance = 20` is one in
# twenty, exactly as the guardian drops are handled. The shared creature drop
# table cannot express a denominator, so these rolls live here.

# The source's own hit points: fish have three, squid have ten.
const HEALTH = 3.0
const SQUID_HEALTH = 10.0
# The source's `collisionbox` for a cod is 0.6 wide and 0.79 tall.
const FISH_WIDTH = 0.3
const FISH_HEIGHT = 0.79
# A squid is larger: 0.8 wide and 0.9 tall.
const SQUID_WIDTH = 0.4
const SQUID_HEIGHT = 0.9
# The source's `runaway_view_range = 8` for fish, so they flee a nearby player.
const FLEE_RANGE = 8.0
# The source's bone-meal denominator.
const BONE_MEAL_CHANCE = 20
# A glow squid's drop is the glow ink sac; a squid's is the ink sac.
const GLOW_INK_CHANCE = 10

const FISH = ["cod","salmon","pufferfish","tropical_fish"]
const SQUIDS = ["squid","glow_squid"]

# A weighted pick for spawning: fish are commoner than squid, as they are in the
# source's own spawn lists.
static func pick(roll: int) -> String:
	var pool: Array = ["cod","cod","cod","salmon","salmon","tropical_fish","pufferfish","squid","squid","glow_squid"]
	return pool[posmod(roll,pool.size())]

static func is_fish(kind: String) -> bool: return FISH.has(kind)
static func is_squid(kind: String) -> bool: return SQUIDS.has(kind)
static func is_aquatic(kind: String) -> bool: return is_fish(kind) or is_squid(kind)

# The item a fish yields, which is its own raw item.
static func raw_item(kind: String) -> int:
	match kind:
		"cod": return VillageContent.RAW_COD
		"salmon": return VillageContent.RAW_SALMON
		"pufferfish": return VillageContent.PUFFERFISH
		"tropical_fish": return VillageContent.TROPICAL_FISH
	return 0

# Each species' own body colour, which is its only visible difference.
static func colour(kind: String) -> Color:
	match kind:
		"cod": return Color("b8a88a")
		"salmon": return Color("a35a4e")
		"pufferfish": return Color("d9b04a")
		"tropical_fish": return Color("d97a3a")
	return Color("9aa8b0")

# The creature's health, which the source sets per definition.
static func health(kind: String) -> float:
	return SQUID_HEALTH if is_squid(kind) else HEALTH

static func width(kind: String) -> float:
	return SQUID_WIDTH if is_squid(kind) else FISH_WIDTH

static func height(kind: String) -> float:
	return SQUID_HEIGHT if is_squid(kind) else FISH_HEIGHT

# The source's drop table, as [item, chance-denominator, min, max]. A denominator
# of 1 always drops.
static func drop_table(kind: String) -> Array:
	if is_fish(kind):
		return [[raw_item(kind),1,1,1],[Nodes.BONE_MEAL,BONE_MEAL_CHANCE,1,1]]
	if kind == "squid":
		# The source rolls the glow ink sac at 1 in 10 beside the ordinary sac.
		return [[VillageContent.INK_SAC,1,1,3],[VillageContent.GLOW_INK_SAC,GLOW_INK_CHANCE,1,1]]
	if kind == "glow_squid":
		return [[VillageContent.GLOW_INK_SAC,1,1,3]]
	return []

# Roll a creature's drops, applying the source's per-entry chance denominator.
static func roll_drops(kind: String, rng: RandomNumberGenerator, looting: int = 0) -> Array:
	var result: Array = []
	for entry in drop_table(kind):
		var denominator: int = maxi(1,int(entry[1]))
		# Looting raises the effective chance the way the source's own drop code
		# does, by dividing the denominator.
		if looting > 0: denominator = maxi(1,denominator-looting)
		if rng.randi_range(1,denominator) != 1: continue
		var count: int = rng.randi_range(int(entry[2]),int(entry[3]))
		if count > 0: result.append([int(entry[0]),count])
	return result
