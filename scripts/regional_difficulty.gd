class_name RegionalDifficulty
extends RefCounted

# `mcl_worlds`' local difficulty (CORE/mcl_worlds/init.lua:184-280). The source
# keeps a per-chunk "inhabited time" — seconds a player has spent in each 16×16
# column of a dimension — and folds it together with the world's age and the moon
# into one number that scales mob buffs: a husk's hunger bite lasts longer, a
# skeleton is likelier to wear armour, in a region the player has lived in for a
# long time on an old world under a full moon.
#
# Voxey's `game.difficulty` is 0 easy, 1 normal, 2 hard (see `Withers` and
# `SpiderClimb`); the source's `mcl_vars.difficulty` is 1 easy, 2 normal, 3 hard,
# with 0 peaceful. `source_level` is the one place that translates.
#
# Inhabited time is saved with the world under `"inhabited"`, keyed
# `"<dimension>_<chunk x>,<chunk z>"` exactly as the source's mod-storage keys are,
# so a reload keeps a region's history.

# The source's own constants.
const CHUNK = 16
const MAX_INHABITED = 360000.0 # `math.min (inhabited_time / 360000, 1.0)`
const DAY_TICKS = 24000
const EARLY_TICKS = 72000 # three days
const LATE_TICKS = 1512000 # 63 days
const DAYTIME_SPAN = 5760000.0
const LATE_FACTOR = 0.25

static func source_level(difficulty: int) -> int:
	return clampi(difficulty,0,2)+1

static func chunk_key(dimension: String, pos: Vector3) -> String:
	# `round_trunc` rounds to the nearest node first, then floors the chunk.
	var x: int = floori(floorf(pos.x+0.5)/CHUNK)
	var z: int = floori(floorf(pos.z+0.5)/CHUNK)
	return "%s_%d,%d" % [dimension,x,z]

static func store(game: Node3D) -> Dictionary:
	if not game.has_meta("inhabited_time"): game.set_meta("inhabited_time",{})
	return game.get_meta("inhabited_time")

static func inhabited_time(game: Node3D, pos: Vector3) -> float:
	return float(store(game).get(chunk_key(game.dimension,pos),0.0))

# `tick_chunk_inhabited_time`, run by the player's own globalstep.
static func tick(game: Node3D, delta: float) -> void:
	if game == null or game.player == null: return
	var table: Dictionary = store(game)
	var key: String = chunk_key(game.dimension,game.player.position)
	table[key] = float(table.get(key,0.0))+delta

# `get_regional_difficulty`, with the world's clock supplied by the caller so the
# formula is testable without a running game. `days` is `core.get_day_count ()`,
# `time_of_day` the fraction of the current day and `moon` the moon's brightness.
static func compute(level: int, inhabited: float, days: int, time_of_day: float, moon: float) -> float:
	if level == 0: return 0.0
	var total: float = float(days*DAY_TICKS)
	var daytime_factor: float
	if total > LATE_TICKS: daytime_factor = LATE_FACTOR
	elif total < EARLY_TICKS: daytime_factor = 0.0
	else:
		total += time_of_day*DAY_TICKS
		daytime_factor = (total-EARLY_TICKS)/DAYTIME_SPAN
	var chunk_factor: float = minf(inhabited/MAX_INHABITED,1.0)
	if level < 3: chunk_factor *= 0.75
	if moon/4.0 > daytime_factor: chunk_factor += daytime_factor
	else: chunk_factor += moon/4.0
	if level == 1: chunk_factor *= 0.5
	var value: float = 0.75+daytime_factor+chunk_factor
	if level == 1: return value
	if level == 2: return value*2.0
	return value*3.0

static func regional(game: Node3D, pos: Vector3) -> float:
	var days: int = floori(game.day_time)
	return compute(source_level(game.difficulty),inhabited_time(game,pos),days,game.day_time-days,Weather.moon_brightness(game.world))

# `get_special_difficulty`: the multiplier the source's mob buffs read.
static func special_from(regional_value: float) -> float:
	if regional_value < 2.0: return 0.0
	return 1.0 if regional_value > 4.0 else (regional_value-2.0)/2.0

static func special(game: Node3D, pos: Vector3) -> float:
	return special_from(regional(game,pos))

static func snapshot(game: Node3D) -> Dictionary:
	return store(game).duplicate()

# Old saves carry no table, which the source reads as zero for every chunk.
static func restore(game: Node3D, data: Variant) -> void:
	var table: Dictionary = {}
	if data is Dictionary:
		for key in data:
			var value: Variant = data[key]
			if (value is float or value is int) and float(value) > 0.0: table[str(key)] = float(value)
	game.set_meta("inhabited_time",table)
