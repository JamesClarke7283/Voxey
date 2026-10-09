class_name PillagerPatrols
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/pillager.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# Two things lived only in the source's pillager file:
#
#   * The **patrol spawner** — the source's own module globalstep lays a pillager
#     patrol on the surface near a player roughly every ten minutes, refusing to
#     do it within a village, refusing the mushroom islands, and picking the band
#     size from the regional difficulty. The first of the band is its **raid
#     captain**. Voxey spawned pillagers only through the general hostile table,
#     so patrols never existed.
#
#   * The **captain's ominous bottle** — `pillager:drop_custom` adds
#     `mcl_potions:ominous` when the pillager is a patrol captain *and* is not part
#     of an active raid. That bottle is otherwise unobtainable in Voxey: potions are
#     brewed, and no brewing recipe produces it. Drinking it applies `bad_omen`,
#     which `AlchemyWorld.update` already consumes to start a raid, so the bottle is
#     what makes the whole raid path reachable in survival.
#
# The source's own cadence: `next_spawn_attempt = (12000 + random(1200)) / 20`
# seconds, i.e. 600 to 660 seconds. It then requires day five, daytime, and one roll
# in five.

# `(12000 + pr:next(0,1200)) / 20`.
const ATTEMPT_MIN = 600.0
const ATTEMPT_SPAN = 60.0
# `days < 5` in the source's own guard.
const MIN_DAY = 5
# `pr:next(1,5) ~= 1` — one attempt in five.
const CHANCE_ONE_IN = 5
# `nodepos.x = nodepos.x + (pr:next(24,48) * s1)`, and the same on z.
const OFFSET_MIN = 24
const OFFSET_SPAN = 24
# `mcl_villages.get_poi_heat(nodepos) >= 4` — too close to a village.
const VILLAGE_CLEARANCE = 55.0
# The band is laid on the surface, and each member is nudged by `random(0,4)`.
const NUDGE = 4

# The patrol flags, stored on the member rather than on the kind: a raid pillager is
# never a patrol captain, and `drop_custom` must tell the two apart.
const CAPTAIN_META = "patrol_captain"
const PATROL_META = "patrol"

# `get_regional_difficulty` at the default setting. The source derives it from world
# time, the moon phase, the chunk's inhabited time and the difficulty setting; Voxey
# tracks difficulty, and `ceil(regional)` at the default regional value of two is
# two, which this returns.
static func band_size(difficulty: int) -> int:
	return clampi(difficulty + 1,1,6)

static func is_captain(mob: Object) -> bool:
	if mob == null or not is_instance_valid(mob): return false
	return bool(mob.get_meta(CAPTAIN_META,false))

static func is_patrol_member(mob: Object) -> bool:
	if mob == null or not is_instance_valid(mob): return false
	return bool(mob.get_meta(PATROL_META,false))

# The source's per-attempt gate: day five or later, daytime, and one roll in five.
static func should_attempt(day: int, daylight: float, roll: int) -> bool:
	if day < MIN_DAY: return false
	if daylight < 0.5: return false
	return roll == 1

# `if not biome or is_mushroom_islands(biome)`.
static func biome_allowed(biome: String) -> bool:
	return biome != "MushroomIslands"

# The source's offset draw: both axes independently signed, each between 24 and 48.
static func offset(rng: RandomNumberGenerator) -> Vector3:
	var sx: int = -1 if rng.randi_range(1,2) == 1 else 1
	var sz: int = -1 if rng.randi_range(1,2) == 1 else 1
	return Vector3((OFFSET_MIN + rng.randi_range(0,OFFSET_SPAN))*sx,0,(OFFSET_MIN + rng.randi_range(0,OFFSET_SPAN))*sz)

# `mobs_mc.find_surface_position` then the `random(0,4)` nudge on all three axes.
static func surface_cell(game: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var x: int = floori(at.x); var z: int = floori(at.z)
	var y: int = game.world.generator.terrain_height(x,z)
	return Vector3(float(x)+0.5,float(y)+1.02,float(z)+0.5)+Vector3(rng.randi_range(-NUDGE,NUDGE),rng.randi_range(-NUDGE,NUDGE),rng.randi_range(-NUDGE,NUDGE))

# Lay one patrol band at `at`. Returns the members spawned, the first of which is
# the captain. The caller supplies `spawn` so the band's composition stays in the
# game layer.
static func spawn_patrol(game: Node3D, at: Vector3, difficulty: int, rng: RandomNumberGenerator, spawn: Callable) -> Array:
	var members: Array = []
	if not biome_allowed(game.world.generator.biome(floori(at.x),floori(at.z))): return members
	var cursor: Vector3 = at
	for i in band_size(difficulty):
		var cell: Vector3 = surface_cell(game,cursor,rng)
		var member: Object = spawn.call(cell)
		# The source fails the whole patrol when its leader cannot be spawned.
		if member == null:
			if i == 0: return []
			continue
		if i == 0: member.set_meta(CAPTAIN_META,true)
		member.set_meta(PATROL_META,true)
		members.append(member)
		cursor += Vector3(rng.randi_range(0,NUDGE)-rng.randi_range(0,NUDGE),rng.randi_range(0,NUDGE)-rng.randi_range(0,NUDGE),rng.randi_range(0,NUDGE)-rng.randi_range(0,NUDGE))
	return members

# The source's own globalstep, called per frame from the game's fixed tick.
static func update(game: Node3D, delta: float) -> void:
	if game.dimension != "overworld": return
	game.patrol_attempt -= delta
	if game.patrol_attempt > 0.0: return
	var rng := RandomNumberGenerator.new()
	game.patrol_attempt = ATTEMPT_MIN + rng.randf()*ATTEMPT_SPAN
	if not should_attempt(game.day_number(),game.daylight,rng.randi_range(1,CHANCE_ONE_IN)): return
	var at: Vector3 = game.player.position + offset(rng)
	# `mcl_villages.get_poi_heat(nodepos) >= 4`: too close to a village.
	if Vector3(VillageGenerator.nearest(game.world.generator,at).center).distance_to(at) < VILLAGE_CLEARANCE: return
	spawn_patrol(game,at,game.difficulty,rng,func(pos: Vector3) -> Object: return game.spawn_creature("pillager",pos))
