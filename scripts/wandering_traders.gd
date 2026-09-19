class_name WanderingTraders
extends RefCounted

# Mineclonia mods/ENTITIES/mobs_mc/wandering_trader.lua (GPL-3.0-or-later).
# Original GDScript using the source as a behaviour reference; all art is
# original procedural code built from `_box`/`_joint`.
#
# The source's trader is a villager that belongs to no village: it is spawned by
# a globalstep far away, walks a fixed sixteen-block beat for twenty minutes, and
# is gone. Two llamas come with it and share its life to the second. What it sells
# is rolled fresh for every trader — two purchasing offers, two special offers and
# five ordinary ones (wandering_trader.lua:144-160).
#
# This module owns the trade pool, the spawner's timing, the lifetime, the escort,
# and the two mobs. It touches no shared file: the parent merges the two `KINDS`
# entries, routes `spawn_creature`, and calls `update`/`restore` once each.
#
# --- what the source does, in its own numbers --------------------------------
#
#   * `get_wandering_trades` (144) draws 2 + 2 + 5, removing each pick from a copy
#     of its table, so no category can repeat an offer. The draw is reproduced.
#   * `E(f,t)` is an emerald cost of `f`..`t` (default `f`), and every row's fifth
#     field — the source's `price_multiplier` — is `0`, so demand never moves a
#     trader's price. `multiplier` is therefore 0.0 throughout.
#   * A row's `trade[3]` is `max_uses` and `trade[4]` is `xp`; both default to 12
#     and 1 when absent (villager.lua:195-203). Rows that pass neither are noted.
#   * The spawner (513-541) resets a 60-second counter, moves
#     `trader_spawn_delay` down by 60 and `trader_spawn_chance` up by 25 (clamped
#     to 25..75) every tick, and only when the delay reaches -1200 — the twentieth
#     tick, so twenty minutes — does it roll `1..100 < chance`. A successful spawn
#     resets the chance to 25; so does the "no player in the overworld" early
#     return, which is why `try_spawn` reports true with no overworld player.
#   * `_life_timer = 1200` is set at spawn (line 483) and counted down in
#     `ai_step`, then `safe_remove`. Each llama copies the trader's remaining
#     timer every step (line 640), so the three leave together.
#   * At night the trader drinks an invisibility potion and stays invisible until
#     day, when it drinks milk and clears every effect (206-243).
#
# --- what Voxey has no equivalent for (reported, never invented) -------------
#
#   `mcl_core:podzol`, `mcl_core:redsand` and `mcl_pale_oak:hanging_moss` have no
#   Voxey item at all — `bamboo.gd:88`, `huge_mushrooms.gd:140` and
#   `shipwrecks.gd:142` all say Voxey has no podzol, and `seagrass.gd:25` says it
#   has no red sand. Those three rows are **left out** of the pool rather than
#   mapped to a look-alike, so the special table has seven rows and the ordinary
#   table thirty-two. The draw is still 2 + 2 + 5.
#
#   `mcl_dripstone:pointed_dripstone` is mapped to `DRIPSTONE_BLOCK`, the same
#   material in the only form Voxey has (`dripstones.gd:46` places exactly that
#   node). `mcl_buckets:bucket_tropical_fish` and `bucket_pufferfish` are mapped to
#   the bare `TROPICAL_FISH`/`PUFFERFISH` items, because Voxey's only fish bucket
#   is `COD_BUCKET` and inventing two ids for it is worse than selling the fish.
#   Both substitutions are flagged on their rows.

const EMERALD := VillageContent.EMERALD

# --- the source's own numbers ------------------------------------------------

# `spawn_wandering_trader` sets `entity._life_timer = 1200` (wandering_trader.lua:483).
const LIFE_TIMER := 1200.0
# The source restricts the trader to `entity:restrict_to(base_position, 16)` (485).
const RESTRICT_RADIUS := 16.0
# The spawn offsets are `pr:next(-48, 48)` around the base position (471).
const WANDER_RADIUS := 48
# The spawner's own clock, delay floor, and the chance it climbs between (513-533).
const SPAWN_TICK := 60.0
const SPAWN_DELAY_LIMIT := -1200
const SPAWN_CHANCE_MIN := 25
const SPAWN_CHANCE_MAX := 75
const SPAWN_CHANCE_STEP := 25
# `spawn_wandering_trader` bails on `pr:next(1, 10) ~= 1` (wandering_trader.lua:461).
const SPAWN_ROLL := 10
# Two llamas, each from up to ten offsets of `pr:next(-4, 4)` (418-441).
const ESCORT_COUNT := 2
const ESCORT_RADIUS := 4
const ESCORT_TRIES := 10
# `trader_llama_follow_owner` gives up past twenty blocks and stops within six
# (wandering_trader.lua:604-620).
const LLAMA_SEEK_RADIUS := 20.0
const LLAMA_STOP_DISTANCE := 6.0
# The source's `gopath(owner_pos, 1.4, nil, 3.0)`.
const LLAMA_FOLLOW_BOOST := 1.4
# `_using_wielditem > 1.0` — the drink the trader takes before the effect lands.
const DRINK_SECONDS := 1.0
# The source gives invisibility for `math.huge` (221). Voxey serialises its world
# state through `JSON.stringify`, which cannot round-trip a non-finite float, so
# the stand-in is finite and far longer than the trader's own 1200 seconds.
const INVISIBILITY_SECONDS := 1.0e9
# The potion the source's special table sells: `PotionCatalog.find("invisibility")`,
# the drink form at its normal variant.
const INVISIBILITY_POTION := 2144
# Day is `mcl_util.is_daytime()` in the source; Voxey's own night test is used.
const NIGHT_BEGINS := 0.72
const NIGHT_ENDS := 0.2

# The trader's record key prefix and the world state it lives in. The record is
# deliberately *not* in `village_life.people`: `VillageLife.update` resurrects
# anything in that table as a plain villager and hibernates it past ninety-five
# blocks, neither of which a trader may do.
const KEY_PREFIX := "trader:"
const STATE_KEY := "wandering_traders"

# --- the trade tables --------------------------------------------------------
#
# `village_trades.gd`'s shape verbatim, so `hud.show_trading`, `VillageLife.costs`
# and `VillageLife.transaction` display and settle these offers unchanged.
# `random` is a template-only key naming which of the source's four random pickers
# the row's `give` id comes from; `enchanted` is the existing template-only key.

const RANDOM_TREE := "tree"
const RANDOM_SAPLING := "sapling"
const RANDOM_FLOWER := "flower"
const RANDOM_DYE := "dye"

# `trades_purchasing_table` (wandering_trader.lua:84-91): the player hands over the
# item and takes emeralds. Stock 1 and no xp, as every row declares.
const PURCHASING := [
	{"tier":1,"cost":[[VillageContent.WATER_BOTTLE,1,1]],"give":[EMERALD,1,1],"stock":1,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[Nodes.WATER_BUCKET,1,1]],"give":[EMERALD,2,2],"stock":1,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[Nodes.MILK_BUCKET,1,1]],"give":[EMERALD,2,2],"stock":1,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[VillageContent.FERMENTED_SPIDER_EYE,1,1]],"give":[EMERALD,3,3],"stock":1,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[VillageContent.BAKED_POTATO,1,1]],"give":[EMERALD,1,1],"stock":1,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[Nodes.HAY_BALE,1,1]],"give":[EMERALD,1,1],"stock":1,"xp":0,"multiplier":0.0},
]

# `trades_special_table` (93-102). Seven of the source's eight rows: `podzol` has
# no Voxey item and is left out.
const SPECIAL := [
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[DenseMaterials.PACKED_ICE,1,1],"stock":6,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,6,6]],"give":[DenseMaterials.BLUE_ICE,1,1],"stock":6,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.GUNPOWDER,4,4],"stock":2,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[0,8,8],"random":RANDOM_TREE,"stock":6,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,5,5]],"give":[Nodes.ICE,1,1],"stock":6,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,6,6]],"give":[INVISIBILITY_POTION,1,1],"stock":1,"xp":0,"multiplier":0.0},
	# The one row that declares neither uses nor xp, so it takes the source's own
	# defaults: 12 uses and 1 xp (villager.lua:195-203). The cost is the source's
	# `E(6, 20)`, the only ranged emerald price in either table.
	{"tier":1,"cost":[[EMERALD,6,20]],"give":[Nodes.TOOLS+10,1,1],"stock":12,"xp":1,"multiplier":0.0,"enchanted":true},
]

# `trades_ordinary_table` (104-139). Thirty-two of the source's thirty-four rows:
# `redsand` and `hanging_moss` have no Voxey item and are left out.
const ORDINARY := [
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[FlowersExtra.FERN,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.SUGAR_CANE,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.PUMPKIN,1,1],"stock":4,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[0,1,1],"random":RANDOM_FLOWER,"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.SEEDS,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[VillageContent.BEETROOT_SEEDS,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[FruitCrops.PUMPKIN_SEEDS,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[FruitCrops.MELON_SEEDS,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[0,1,1],"random":RANDOM_DYE,"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.VINE,3,3],"stock":4,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[VillageContent.LILY_PAD,3,3],"stock":2,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.SAND,3,3],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[LushCaveExtra.DRIPLEAF_SMALL,2,2],"stock":5,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.BROWN_MUSHROOM,3,3],"stock":4,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[Nodes.RED_MUSHROOM,3,3],"stock":4,"xp":0,"multiplier":0.0},
	# Substitution: Voxey's dripstone exists only as the block (`dripstones.gd:46`).
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[VillageContent.DRIPSTONE_BLOCK,2,5],"stock":5,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[LushCaveExtra.ROOTED_DIRT,2,2],"stock":5,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,1,1]],"give":[LushCaves.MOSS,2,2],"stock":5,"xp":0,"multiplier":0.0},
	# The dead brain coral block a one-pickle colony drops (sea_pickle.lua:173):
	# `Corals.living_id(1, Corals.DEAD_BLOCK)` = 1330 + 1*6 + 1.
	{"tier":1,"cost":[[EMERALD,2,2]],"give":[1337,1,1],"stock":5,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,2,2]],"give":[Nodes.GLOWSTONE,1,5],"stock":5,"xp":0,"multiplier":0.0},
	# Substitutions: Voxey's only fish bucket is the cod bucket (788), so the fish
	# themselves are sold rather than inventing two bucket ids.
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[VillageContent.TROPICAL_FISH,1,1],"stock":4,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[VillageContent.PUFFERFISH,1,1],"stock":4,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[VillageContent.KELP,1,1],"stock":12,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[Nodes.CACTUS,1,1],"stock":8,"xp":0,"multiplier":0.0},
	# `mcl_ocean:*_coral_block` is `Corals.living_id(species, Corals.BLOCK)`, i.e.
	# 1330 + s*6 + 0 for s in brain, tube, bubble, fire, horn.
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[1336,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[1330,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[1342,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[1348,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,3,3]],"give":[1354,1,1],"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,4,4]],"give":[Nodes.SLIME_BALL,1,1],"stock":5,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,5,5]],"give":[0,8,8],"random":RANDOM_SAPLING,"stock":8,"xp":0,"multiplier":0.0},
	{"tier":1,"cost":[[EMERALD,5,5]],"give":[VillageContent.NAUTILUS_SHELL,1,1],"stock":5,"xp":0,"multiplier":0.0},
]

# The source's four random pickers.
#
#   * `get_random_flower` (76) draws from `mcl_flowers.registered_simple_flowers`.
#     Voxey's thirteen simple flowers are `FoodFeatures.FLOWERS` (poppy, dandelion,
#     oxeye daisy) plus `FlowersExtra.FLOWERS` — `flowers_extra.gd:8-12` says the
#     source registers thirteen and Voxey already had the first three. The lily
#     pad is a ground flower and is traded as its own row, as in the source.
#   * `get_random_tree` (63) returns `mcl_trees:tree_<wood>`, which is the wood's
#     **log** node (`mcl_trees/api.lua:399` registers it under that name), so the
#     Voxey pool is `WoodTypes.LOGS`.
#   * `get_random_sapling` (68) returns the wood's sapling, `WoodTypes.SAPLINGS`.
#     The source's `is_trading_wood` filter drops woods with an unobtainable
#     sapling; all six Voxey saplings are obtainable, so no filter is needed.
#   * `get_random_dye` (50) draws any of `mcl_dyes.colors`, which Voxey spans with
#     one contiguous run: `DYE_WHITE`..`DYE_BROWN` (821..836).
const FLOWERS := [
	FoodFeatures.POPPY,FoodFeatures.DANDELION,FoodFeatures.OXEYE_DAISY,
	FlowersExtra.TULIP_ORANGE,FlowersExtra.TULIP_PINK,FlowersExtra.TULIP_RED,FlowersExtra.TULIP_WHITE,
	FlowersExtra.ALLIUM,FlowersExtra.AZURE_BLUET,FlowersExtra.BLUE_ORCHID,FlowersExtra.WITHER_ROSE,
	FlowersExtra.LILY_OF_THE_VALLEY,FlowersExtra.CORNFLOWER,
]

# --- the mobs ----------------------------------------------------------------

# Merge into `Creature.KINDS`. `villager_base` gives 20 health and a
# `{-0.25,0,-0.25,0.25,1.90,0.25}` box; Voxey's own villager uses 0.28/1.95 and
# the trader shares that body, so it matches the villager. `movement_speed = 14.0`
# against `villager_base`'s 10.0 is 1.4 times a villager, and Voxey walks a
# villager at 1.15, so 1.6. No `can_despawn`: the source's default is false and
# the trader leaves on its own timer.
const TRADER_KIND := {
	"hostile":false,"health":20.0,"speed":1.6,"width":0.28,"height":1.95,"damage":0,
	"drops":[],"voice":"","pitch":1.0,"xp":0,
}

# Merge into `Creature.KINDS`. The source's llama is `hp_min = 15`/`hp_max = 30`
# rolled by `generate_hp_max` (15 + 0..8 + 0..9); Voxey's table holds one float, so
# the floor is used. `collisionbox = {-0.45,0,-0.45,0.45,1.87,0.45}` gives half
# the width, as Voxey measures it. `movement_speed = 3.5` against the villager's
# 10.0 is 0.35 of a villager, i.e. 0.4 at Voxey's 1.15 walk, rounded to 0.45. Its
# drops are the source's `leather 0..2`. The voice is empty because Voxey
# synthesises its sounds and has no llama sample; an unknown name would be silent
# anyway, and `Creature` voices the villager the same way.
const LLAMA_KIND := {
	"hostile":false,"health":15.0,"speed":0.45,"width":0.45,"height":1.87,"damage":0,
	"drops":[[Nodes.LEATHER,0,2]],"voice":"","pitch":1.0,"xp":1,
}

# --- the record --------------------------------------------------------------

static func data_of(game: Node3D) -> Dictionary:
	if not game.world.adventure_state.get(STATE_KEY) is Dictionary:
		game.world.adventure_state[STATE_KEY] = fresh_data()
	var data: Dictionary = game.world.adventure_state[STATE_KEY]
	if not data.get("spawner") is Dictionary: data["spawner"] = fresh_spawner()
	if not data.get("traders") is Dictionary: data["traders"] = {}
	if not data.has("next"): data["next"] = 0
	return data

static func fresh_data() -> Dictionary:
	return {"spawner":fresh_spawner(),"next":0,"traders":{}}

# The source's counters live in mod storage as `trader_spawn_delay` (starting at
# zero) and `trader_spawn_chance` (starting at 25), and its local tick starts at 60.
static func fresh_spawner() -> Dictionary:
	return {"tick":SPAWN_TICK,"delay":0,"chance":SPAWN_CHANCE_MIN}

# The record a trader's offers are settled against. It carries the same fields
# `VillageLife.make_record` writes, because the trading UI and `transaction` read
# them directly. `level` is 1 and every offer is tier 1: the source's trader has no
# tiers at all (`show_trade_progress_bar` returns false, `tier_progress` returns 0),
# so nothing is ever locked. `restocks` is 0 because a trader has no workplace, so
# `VillageLife.restock` is never called for one — matching the source, whose trader
# has no restock path either.
static func make_record(key: String, position: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var cell := Vector3i(position.floor())
	return {
		"key":key,"profession":"wandering_trader","xp":0,"level":1,"offers":make_offers(rng),
		"position":[position.x,position.y,position.z],
		"job":[cell.x,cell.y,cell.z],"bed":[cell.x,cell.y,cell.z],"center":[cell.x,cell.y,cell.z],
		"health":20.0,"dead":false,"reputation":0,"reputations":{},
		# A trader has no workplace, so `VillageLife.work` and its `restock` are never
		# reached for one; the restock fields are carried for shape only.
		"restocks":0,"restock_time":-1.0,"restock_day":0,
		"food":0,"age":0.0,"breed_time":0.0,"custom_name":"",
		"life_timer":LIFE_TIMER,"trader_id":0,
	}

# The one-line hook `VillageLife.record` needs, so the HUD and `trade` can find a
# trader the same way they find a villager.
static func stored(game: Node3D, key: String) -> Dictionary:
	return data_of(game).traders.get(key,{})

# --- the trade pool ----------------------------------------------------------

# The source's `get_wandering_trades` (144-160): two purchasing rows, two special
# rows and five ordinary ones, each removed from a copy of its table so a category
# cannot repeat itself. Purchasing and special are drawn in the same loop there and
# are interleaved here to match the order the player sees.
static func make_offers(rng: RandomNumberGenerator) -> Array:
	var purchasing: Array = PURCHASING.duplicate(true)
	var special: Array = SPECIAL.duplicate(true)
	var ordinary: Array = ORDINARY.duplicate(true)
	var offers: Array = []
	for _round in 2:
		offers.append(offer(purchasing.pop_at(rng.randi_range(0,purchasing.size()-1)),rng))
		offers.append(offer(special.pop_at(rng.randi_range(0,special.size()-1)),rng))
	for _round in 5:
		offers.append(offer(ordinary.pop_at(rng.randi_range(0,ordinary.size()-1)),rng))
	return offers

# Turn one template into the runtime offer `VillageLife.make_record` produces, so
# `hud.show_trading`, `VillageLife.costs` and `VillageLife.transaction` need no
# change to settle a trader's offer.
static func offer(template: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var entry: Dictionary = template.duplicate(true)
	var costs: Array = []
	for cost in entry.cost: costs.append([int(cost[0]),rng.randi_range(int(cost[1]),int(cost[2]))])
	entry["cost"] = costs
	entry["give"] = [give_id(entry,rng),rng.randi_range(int(entry.give[1]),int(entry.give[2]))]
	entry["uses"] = 0
	entry["demand"] = 0
	entry["data"] = {}
	if entry.get("enchanted",false):
		var id: int = int(entry.give[0])
		if id == VillageContent.ENCHANTED_BOOK: entry["data"] = Enchantments.random_book(rng)
		else:
			var choices: Array = Enchantments.choices(id)
			if not choices.is_empty():
				var enchant: String = choices[rng.randi_range(0,choices.size()-1)]
				entry["data"] = {"enchantments":{enchant:rng.randi_range(1,Enchantments.DATA[enchant].max)}}
	return entry

# Resolve a row's offered id, drawing one from the source's picker when the row
# carries a `random` key.
static func give_id(entry: Dictionary, rng: RandomNumberGenerator) -> int:
	match str(entry.get("random","")):
		RANDOM_TREE: return WoodTypes.LOGS[rng.randi_range(0,WoodTypes.LOGS.size()-1)]
		RANDOM_SAPLING: return WoodTypes.SAPLINGS[rng.randi_range(0,WoodTypes.SAPLINGS.size()-1)]
		RANDOM_FLOWER: return FLOWERS[rng.randi_range(0,FLOWERS.size()-1)]
		RANDOM_DYE: return rng.randi_range(VillageContent.DYE_WHITE,VillageContent.DYE_BROWN)
	return int(entry.give[0])

# --- the spawner -------------------------------------------------------------

# The source's globalstep, minus the parts that belong to the caller. `state` is
# `data_of(game).spawner`; the counters live there, exactly as the source keeps
# them in mod storage, so they survive a save for free.
#
# Returns true on the tick that placed a trader, which the parent needs only if it
# wants to announce one.
static func spawn_tick(state: Dictionary, delta: float, game: Node3D) -> bool:
	if not spawn_counters(state,delta): return false
	if randi_range(1,100) >= int(state.get("chance",SPAWN_CHANCE_MIN)): return false
	if not try_spawn(game): return false
	state["chance"] = SPAWN_CHANCE_MIN
	return true

# The clock, the delay and the chance, which are all the source's step does before
# it rolls. Split out so the timing can be checked without a world.
#
# The source resets a 60-second counter, then moves the delay down by 60 and the
# chance up by 25 — clamped to 25..75, and the clamped value is what gets stored —
# every tick; only when the delay has reached -1200 (its twentieth tick, so twenty
# minutes) does it zero the delay and roll.
static func spawn_counters(state: Dictionary, delta: float) -> bool:
	state["tick"] = float(state.get("tick",SPAWN_TICK))-delta
	# A one-second call must not step the counter twice: comparing `>= 0` also
	# consumed the reset tick itself, halving the rate to two minutes per step.
	if float(state["tick"]) > 0.0: return false
	state["tick"] = SPAWN_TICK
	state["delay"] = int(state.get("delay",0))-int(SPAWN_TICK)
	state["chance"] = clampi(int(state.get("chance",SPAWN_CHANCE_MIN))+SPAWN_CHANCE_STEP,SPAWN_CHANCE_MIN,SPAWN_CHANCE_MAX)
	if int(state["delay"]) > SPAWN_DELAY_LIMIT: return false
	state["delay"] = 0
	return true

# The source's own per-frame hook: `core.register_globalstep`. One call per frame
# from `Game._process` is all this needs.
static func update(game: Node3D, delta: float) -> void:
	spawn_tick(data_of(game).spawner,delta,game)

# `mobs_mc.spawn_wandering_trader` (445-502). Returns true when the attempt is
# spent: `false`, the source says, only when the one-in-ten roll fails or all ten
# placements do — while "no player in the overworld" returns true, which resets the
# spawn chance as if a trader had been placed. That quirk is preserved: Voxey has a
# single player, so the check is the dimension.
static func try_spawn(game: Node3D) -> bool:
	if game.dimension != "overworld": return true
	if randi_range(1,SPAWN_ROLL) != 1: return false
	var base: Vector3i = Vector3i(game.player.position.floor())
	# The source looks for a bell POI within 48 blocks and spawns beside it, else
	# beside the player. Voxey's bell is part of the village structure, so the
	# world is asked whether one is really there.
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
	var bell: Vector3i = Vector3i(village.center)+Vector3i(4,1,0)
	if Vector3(bell).distance_to(game.player.position) <= WANDER_RADIUS and game.world.loaded_at(Vector3(bell)) and game.world.node_at(bell) == VillageContent.BELL:
		base = bell
	for offset in trader_offsets():
		var surface: Vector3 = game._safe_spawn(Vector3(base+Vector3i(offset.x,0,offset.y)))
		# `find_surface_position` keeps the column it is given; Voxey's finder
		# searches up to twelve blocks around it and falls back to the world spawn,
		# so anything further than that is rejected and the next offset is tried.
		if is_inf(surface.x) or absf(surface.x-float(offset.x+base.x)) > 16.0 or absf(surface.z-float(offset.y+base.z)) > 16.0: continue
		if spawn(game,surface) != null: return true
	return false

# The source's ten `pr:next(-48, 48)` offsets.
static func trader_offsets() -> Array:
	var offsets: Array = []
	for _try in 10: offsets.append(Vector2i(randi_range(-WANDER_RADIUS,WANDER_RADIUS),randi_range(-WANDER_RADIUS,WANDER_RADIUS)))
	return offsets

# The source's ten `pr:next(-4, 4)` offsets, per llama.
static func llama_offsets() -> Array:
	var offsets: Array = []
	for _try in ESCORT_TRIES: offsets.append(Vector2i(randi_range(-ESCORT_RADIUS,ESCORT_RADIUS),randi_range(-ESCORT_RADIUS,ESCORT_RADIUS)))
	return offsets

static func spawn(game: Node3D, position: Vector3) -> TraderMob:
	var data: Dictionary = data_of(game)
	data["next"] = int(data["next"])+1
	var key: String = KEY_PREFIX+str(int(data["next"]))
	# The source rolls its trader's offers from one process-wide `PcgRandom`; Voxey
	# seeds a villager's offers from the world seed and its own key, so a trader's
	# pool is fixed for that trader rather than for the session.
	var rng := RandomNumberGenerator.new()
	rng.seed = (str(game.world.generator.world_seed)+key).hash()
	var record: Dictionary = make_record(key,position,rng)
	record["trader_id"] = int(data["next"])
	data["traders"][key] = record
	var trader := TraderMob.new()
	trader.game = game
	trader.kind = "wandering_trader"
	trader.position = position
	trader.person_key = key
	trader.anchor = position
	game.creatures.add_child(trader)
	trader.bind(record)
	escort(game,trader)
	return trader

# `spawn_llamas`/`spawn_one_llama` (418-441): two llamas, each attempted at up to
# ten offsets within four blocks, sharing the trader's identity and life timer.
static func escort(game: Node3D, trader: TraderMob) -> void:
	trader.escort = []
	for _llama in ESCORT_COUNT:
		for offset in llama_offsets():
			var surface: Vector3 = game._safe_spawn(trader.position+Vector3(offset.x,0,offset.y))
			if is_inf(surface.x) or surface.distance_to(trader.position) > 12.0: continue
			var llama := LlamaMob.new()
			llama.game = game
			llama.kind = "trader_llama"
			llama.position = surface
			llama.trader_id = trader.trader_id
			llama.owner_node = trader
			llama.life_timer = trader.life_timer
			game.creatures.add_child(llama)
			trader.escort.append(llama)
			break

# `objects_inside_radius(self_pos, 16)` looking for this trader's llamas
# (wandering_trader.lua:236-258). The source runs it every half second while it
# has fewer than two, which is what `TraderMob._physics_process` calls.
static func adopt(game: Node3D, trader: TraderMob) -> void:
	var live: Array = []
	for other in trader.escort:
		if is_instance_valid(other) and not other.is_queued_for_deletion(): live.append(other)
	trader.escort = live
	if trader.escort.size() >= ESCORT_COUNT: return
	for mob in game.creatures.get_children():
		if not mob is LlamaMob: continue
		var llama: LlamaMob = mob
		if llama.is_queued_for_deletion() or llama.trader_id != trader.trader_id or llama.owner_node != null: continue
		if trader.position.distance_to(llama.position) > RESTRICT_RADIUS: continue
		llama.owner_node = trader
		trader.escort.append(llama)
		if trader.escort.size() >= ESCORT_COUNT: return

# `trader_llama:ai_step` (636-649): a llama that is neither tamed nor ridden
# copies its owner's remaining life every step, and once it has no owner it spends
# its own copy down. So the escort leaves when the trader does, and lives out one
# remaining life if the trader is killed first.
static func llama_timer(owner_timer: float, timer: float, delta: float, linked: bool, ridden: bool) -> float:
	if ridden: return timer
	if linked and owner_timer > 0.0: return owner_timer
	return timer-delta

# --- save and load -----------------------------------------------------------

# The trader's record rides in `world.adventure_state` — written by
# `TraderMob.store_record` and carried into the save by `dimension_snapshot`'s
# `adventure` field — and the spawner's counters ride with it. Only the mob has to
# be rebuilt, which is what this does. Escorts are not restored: the source
# persists neither (`get_staticdata_table` nils `_llamas`), so a trader that comes
# back adopts whatever llamas are still standing and otherwise walks alone, exactly
# as the source's reload path leaves it.
static func restore(game: Node3D) -> void:
	var data: Dictionary = data_of(game)
	for key in data.traders.keys():
		var record: Dictionary = data.traders[key]
		if record.get("dead",false) or float(record.get("health",0.0)) <= 0.0: continue
		if not record.get("position") is Array or record.position.size() != 3: continue
		var position: Vector3 = VillageLife.vec(record.position)
		if position.distance_to(game.player.position) > 95.0 or not game.world.loaded_at(position): continue
		var live: bool = false
		for mob in game.creatures.get_children():
			if not mob is TraderMob: continue
			var trader: TraderMob = mob
			if not trader.is_queued_for_deletion() and trader.person_key == key: live = true; break
		if live: continue
		var trader := TraderMob.new()
		trader.game = game
		trader.kind = "wandering_trader"
		trader.position = position
		trader.person_key = key
		game.creatures.add_child(trader)
		trader.bind(record)

# --- the trader llama --------------------------------------------------------

# A llama is a horse with a longer neck and taller ears and no mane, plus the
# trader's carpet. `RuralAnimal` is the host because it is where Voxey already
# routes its quadruped land animals (`game.gd:787`) and every branch it adds is
# gated on `kind == "horse"` or `kind == "rabbit"`, so a `trader_llama` passes
# through it untouched — `die`'s saddle and armour drops are dead code because
# nothing ever sets them, and its `hit` multiplier is 1.0 while `horse_armor` is
# false. Riding, taming and the wolf it would spit at are left out: Voxey has no
# wolf kind at all (`Creature.KINDS`) and no projectile for llama spit.
class LlamaMob extends RuralAnimal:
	var trader_id: int = 0
	var owner_node: Node3D = null
	# Zero means "no timer", which is how a llama that was not spawned as an escort
	# lives on, matching the source's `_life_timer` being set only at spawn.
	var life_timer: float = 0.0
	var following: bool = false

	func _build_model() -> void:
		var coat := Color("a97f57")
		var dark := Color("8a6644")
		_box(Vector3(0,1.0,0.1),Vector3(0.62,0.6,1.05),coat,"fur")
		_box(Vector3(0,1.42,-0.34),Vector3(0.3,0.72,0.34),dark,"fur")
		head = _joint(Vector3(0,1.8,-0.44),"Head")
		_box(Vector3(0,-0.06,-0.13),Vector3(0.34,0.4,0.5),coat,"fur",head)
		_box(Vector3(0,-0.14,-0.36),Vector3(0.3,0.24,0.2),Color("cbb08a"),"fur",head)
		for side in [-1,1]:
			_box(Vector3(side*0.1,0.26,0.02),Vector3(0.08,0.3,0.1),dark,"fur",head)
			_box(Vector3(side*0.14,0.06,-0.2),Vector3(0.045,0.06,0.03),Color("2b2a26"),"",head)
			for z in [-0.36,0.44]:
				var leg := _joint(Vector3(side*0.22,0.8,z),"Hip")
				_box(Vector3(0,-0.34,0),Vector3(0.16,0.68,0.19),dark,"fur",leg)
				_box(Vector3(0,-0.74,-0.015),Vector3(0.18,0.14,0.22),Color("3a3833"),"",leg)
				legs.append(leg)
		_box(Vector3(0,0.82,0.72),Vector3(0.14,0.66,0.13),dark,"fur")
		# The trader's carpet and the chest it would carry, which the source's
		# `llama_decor_wandering_trader` texture layer draws.
		_box(Vector3(0,1.34,0.06),Vector3(0.66,0.12,0.72),Color("3d5fa8"),"cloth")
		_box(Vector3(0,1.05,-0.12),Vector3(0.5,0.42,0.5),Color( "6d4f34"),"cloth")

	func _physics_process(delta: float) -> void:
		if not game.playing(): return
		if life_timer > 0.0:
			# The source's `not self.tamed and not self.driver`: a llama that has
			# been taken keeps its own timer, and one that has not copies its owner's.
			var ridden: bool = saddled or game.survival.mount == self
			life_timer = WanderingTraders.llama_timer(owner_life(),life_timer,delta,linked(),ridden)
			if life_timer <= 0.0:
				game.puff(center(),Color("c9b28a"),12)
				queue_free()
				return
		if not linked(): following = false
		elif is_instance_valid(owner_node) and not owner_node.is_queued_for_deletion():
			var gap: float = position.distance_to(owner_node.position)
			if gap <= WanderingTraders.LLAMA_STOP_DISTANCE: following = false
			elif gap <= WanderingTraders.LLAMA_SEEK_RADIUS: following = true
		if following and is_instance_valid(owner_node) and not owner_node.is_queued_for_deletion():
			# `gopath(owner_pos, 1.4, nil, 3.0)`: the steer is scaled by the source's
			# own follow factor, since `Creature` multiplies a normalized direction
			# by the kind's speed.
			direction = ((owner_node.position-position)*Vector3(1,0,1)).normalized()*WanderingTraders.LLAMA_FOLLOW_BOOST
			# `Creature`'s shared wander roll replaces `direction` when its think
			# clock expires. Holding the clock positive is how this mob's own steer
			# wins, and it decays normally once the llama stops following.
			think = maxf(think,1.0)
		super._physics_process(delta)

	# The source's `_get_owner` returns the trader while it is valid, and nothing
	# once it is gone.
	func linked() -> bool:
		return is_instance_valid(owner_node) and not owner_node.is_queued_for_deletion()

	func owner_life() -> float:
		if not linked(): return 0.0
		return float(owner_node.get("life_timer"))

# --- the wandering trader ----------------------------------------------------

# The source's `wandering_trader`, a villager with no village: it walks a beat
# within sixteen blocks of where it appeared, halts while it is being traded with
# (which Voxey does for it: `Creature._physics_process` returns early whenever
# `game.playing()` is false, and trading sets the state away from "playing"), and
# leaves on its own timer.
class TraderMob extends VillageMob:
	var anchor := Vector3.INF
	var trader_id: int = 0
	var life_timer: float = 0.0
	var drink: float = 0.0
	var adopt_clock: float = 0.0
	var wander := Vector3.INF
	var wander_clock: float = 0.0
	var escort: Array = []

	func bind(person: Dictionary) -> void:
		super.bind(person)
		trader_id = int(person.get("trader_id",trader_id))
		if person.get("center") is Array and person.center.size() == 3: anchor = VillageLife.vec(person.center)
		life_timer = float(person.get("life_timer",WanderingTraders.LIFE_TIMER))

	# The record is written straight into this module's own store, because
	# `VillageMob.store_record` reads `VillageLife.record`, and a trader is
	# deliberately not in `village_life.people`. The parent adds the fallback that
	# lets `VillageLife.record` see it too, which is what makes the trading UI work.
	func store_record() -> void:
		var record: Dictionary = WanderingTraders.stored(game,person_key)
		if record.is_empty(): return
		record["position"] = [position.x,position.y,position.z]
		record["health"] = health
		record["life_timer"] = life_timer
		record["trader_id"] = trader_id
		record["custom_name"] = custom_name

	# The source's `wandering_trader` drops nothing and has no death behaviour
	# beyond leaving. `VillageMob.die` would try to infect or bury it, so the
	# record is simply retired and the mob is removed.
	func die() -> void:
		if is_queued_for_deletion(): return
		PotionEffects.died(self)
		game.MOD_HOOK_CREATURE_KILLED(self)
		retire()
		game.puff(center(),Color("b6c6e8"),14)
		queue_free()

	# Mark the record gone so a later load does not resurrect a trader that has
	# already left. A trader that is still alive keeps its record with its remaining
	# `life_timer`, which is what the source's own static data does: it nils only
	# `_llamas` (`get_staticdata_table`), so a reloaded trader walks on with the
	# time it had left.
	func retire() -> void:
		var record: Dictionary = WanderingTraders.stored(game,person_key)
		if record.is_empty(): return
		record["dead"] = true
		record["health"] = 0.0

	# The villager body in the trader's own palette: a blue robe and hood with a
	# gold trim, which is what the source's `wandering_trader` textures say and what
	# its `#1E90FF` egg colour is drawn from.
	func _build_model() -> void:
		var robe := Color("3d5fa8")
		var hood := Color("2c4478")
		var trim := Color("c9a227")
		_box(Vector3(0,0.98,0),Vector3(0.52,0.9,0.36),robe,"cloth")
		_box(Vector3(0,1.08,-0.193),Vector3(0.37,0.52,0.04),robe.lightened(0.18),"cloth")
		_box(Vector3(0,0.7,-0.208),Vector3(0.5,0.08,0.035),trim,"cloth")
		head = _joint(Vector3(0,1.49,0),"Head")
		_box(Vector3(0,0.19,0),Vector3(0.46,0.53,0.44),Color("bd9873"),"skin",head)
		_box(Vector3(0,0.09,-0.28),Vector3(0.13,0.25,0.2),Color("ab805c"),"skin",head)
		_box(Vector3(0,0.32,-0.236),Vector3(0.39,0.045,0.025),Color("4e4133"),"",head)
		# The hood, which is what tells a trader from a villager at a glance.
		_box(Vector3(0,0.38,0.05),Vector3(0.5,0.36,0.44),hood,"cloth",head)
		_box(Vector3(0,0.5,0),Vector3(0.56,0.1,0.5),hood,"cloth",head)
		for side in [-1,1]:
			_box(Vector3(side*0.12,0.25,-0.23),Vector3(0.11,0.07,0.02),Color("e5dec7"),"",head)
			_box(Vector3(side*0.1,0.25,-0.245),Vector3(0.046,0.065,0.015),Color("467258"),"",head)
			var leg := _joint(Vector3(side*0.14,0.55,0),"Hip")
			_box(Vector3(0,-0.24,0),Vector3(0.2,0.46,0.25),robe.darkened(0.25),"cloth",leg)
			_box(Vector3(0,-0.5,-0.045),Vector3(0.22,0.1,0.33),Color("514636"),"",leg)
			legs.append(leg)
			_box(Vector3(side*0.28,1.16,-0.05),Vector3(0.17,0.36,0.25),robe,"cloth")
		_box(Vector3(0,1.04,-0.27),Vector3(0.61,0.2,0.21),robe.darkened(0.12),"cloth")
		_box(Vector3(0,1.04,-0.387),Vector3(0.17,0.16,0.025),Color("b98f69"),"skin")

	func _physics_process(delta: float) -> void:
		if not game.playing(): return
		if game.leads.sleep_if_unloaded(self) or not game.world.loaded_at(position): return
		if WanderingTraders.stored(game,person_key).is_empty(): return
		life += delta
		path_timer -= delta
		hurt_flash = maxf(0,hurt_flash-delta)
		life_timer -= delta
		if life_timer <= 0.0:
			# `self:safe_remove ()` — the source leaves the llamas behind, and each
			# then spends its own remaining life.
			retire()
			game.puff(center(),Color("b6c6e8"),14)
			queue_free()
			return
		disguise(delta)
		adopt_clock -= delta
		if adopt_clock <= 0.0:
			adopt_clock = 0.5
			WanderingTraders.adopt(game,self)
			# `VillageLife.update` writes a villager's record every half second, but
			# it only walks `state().people`, which a trader is not in. The position
			# has to stay current regardless: `VillageLife.trade` refuses an offer
			# made more than six blocks away, and it measures against this field.
			store_record()
		wander_clock -= delta
		if wander == Vector3.INF or wander_clock <= 0.0 or position.distance_to(wander) < 2.0:
			wander_clock = 8.0
			path_timer = 0.0
			wander = wander_target()
		var goal: Vector3 = wander
		var speed: float = info().speed
		if scared > 0.0:
			# The source's `runaway = true` with `runaway_bonus_near`/`_far` of 0.5:
			# a struck trader runs at half again its pace, away from what hit it.
			goal = position+((position-game.player.position)*Vector3(1,0,1)).normalized()*8.0
			speed = info().speed*1.5
		if path_timer <= 0.0 or destination.distance_to(goal) > 2.0:
			path_timer = 1.5
			destination = goal
			route = path_to(goal)
		var toward: Vector3 = ((route[0] if not route.is_empty() else goal)-position)*Vector3(1,0,1)
		if toward.length() < 0.3 and not route.is_empty(): route.pop_front()
		var moving: bool = toward.length() > 0.3
		velocity.x = toward.normalized().x*speed if moving else 0.0
		velocity.z = toward.normalized().z*speed if moving else 0.0
		velocity.y = maxf(-20,velocity.y-20*delta)
		for axis in [0,2,1]:
			var next: Vector3 = position
			next[axis] += velocity[axis]*delta
			if not game.world.intersects(next,width,height): position = next
			elif axis == 1: velocity.y = 0.0
			elif not game.world.intersects(position+Vector3.UP*1.05,width,height): velocity.y = 6.0
		direction = toward if moving else Vector3.ZERO
		animate(delta,moving)
		# The two tint lines `Creature`'s own step draws, which this override
		# replaces: without them a struck trader never flashes.
		if hurt_flash > 0.0: _tint(Color("d8402f"),0.55)
		elif tinted: _tint(Color.WHITE,0.0)
		# The shared environment rules — powder snow, water, sunlight — live in one
		# place precisely so an overriding mob can still run them.
		if not weather_step(delta): return
		if moving: model.rotation.y = lerp_angle(model.rotation.y,atan2(-toward.x,-toward.z),delta*5)
		else:
			var look: Vector3 = game.player.position-position
			if look.length() < 5.0: model.rotation.y = lerp_angle(model.rotation.y,atan2(-look.x,-look.z),delta*3)

	# A point inside the source's sixteen-block restriction, which is where
	# `restrict_to(base_position, 16)` and `_wander_to` keep it.
	func wander_target() -> Vector3:
		var angle: float = randf()*TAU
		var radius: float = randf()*WanderingTraders.RESTRICT_RADIUS
		return anchor+Vector3(cos(angle)*radius,0,sin(angle)*radius)

	# `wandering_trader:ai_step` (206-243): at night the trader drinks an
	# invisibility potion and stays unseen until day, when it drinks milk and every
	# effect on it is cleared. Voxey has no wielded-item system, so the drink is a
	# one-second state rather than a held `mcl_potions:invisibility` stack — the
	# source's own `_using_wielditem > 1.0` delay, with the drink invisible.
	func disguise(delta: float) -> void:
		var phase: float = fposmod(game.day_time,1.0)
		var night: bool = phase > WanderingTraders.NIGHT_BEGINS or phase < WanderingTraders.NIGHT_ENDS
		if night == (PotionEffects.level(self,"invisibility") > 0):
			drink = 0.0
			return
		drink += delta
		if drink < WanderingTraders.DRINK_SECONDS: return
		drink = 0.0
		if night: PotionEffects.apply(self,"invisibility",WanderingTraders.INVISIBILITY_SECONDS)
		else: PotionEffects.clear(self)
