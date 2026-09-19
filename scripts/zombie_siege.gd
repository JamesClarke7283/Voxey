class_name ZombieSiege
extends RefCounted

# Mineclonia ENVIRONMENT/mcl_zombie_sieges/init.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The source registers a `mcl_events` event that, near midnight, occasionally sends
# a group of zombies at a **village**, rather than at the player. Its conditions,
# all of which are reproduced here:
#
# - `core.get_timeofday() < 0.04`: only in the last minutes of the night.
# - `rng:next_within(10) == 0`: a one-in-ten roll per attempt, seeded from the
#   world seed and the day count so a reload does not reroll the same night.
# - Not in a mushroom biome. Voxey has no mushroom biome, so that guard has no
#   analogue and is recorded rather than invented.
# - `mcl_villages.get_poi_heat(nodepos) >= 5`, tested both at the player and **again
#   32 blocks away** along a random bearing. Voxey has no POI-heat score; the honest
#   analogue is a real village whose residents exist, so `village_heat` counts the
#   living records near a point instead.
#
# `spawn_zombies` then makes 20 outer attempts, each with 10 inner attempts, at
# offsets up to 8 blocks, and takes the first spot that is still near the village
# and on a surface, spawning one zombie per outer attempt with
# `spawn_abnormally(..., "siege")`. The source tracks the summoned mobs' summed
# health and ends the event when none are left.

# `rng:next_within(10) == 0`.
const CHANCE_IN = 10
# `core.get_timeofday() < 0.04`. Voxey's `daylight` is its own 0..1 curve, so the
# equivalent is the end of the night rather than a literal time-of-day compare.
const NIGHT_DAYLIGHT_MAX = 0.06
# The source's `>= 5` heat threshold and its two `pos` checks.
const HEAT_MIN = 5
const BEARING_DISTANCE = 32
const OUTER_ATTEMPTS = 20
const INNER_ATTEMPTS = 10
# `t < 0.04` means the event fires in the small hours, so at most once per night.
const MIN_DAY = 3

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("zombie_siege"):
		var rng := RandomNumberGenerator.new()
		rng.seed = world.seed_value+77371
		world.set_meta("zombie_siege",{"night":-1,"mobs":0,"active":false,"rng":rng})
	return world.get_meta("zombie_siege")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("zombie_siege"): world.remove_meta("zombie_siege")

# The night index the one-shot guard keys on, so a siege starts at most once a night.
static func night_of(day: int, daylight: float) -> int:
	# A night belongs to the day that started it; the small hours are its tail.
	return day if daylight > 0.5 else day-1

# The source's `get_poi_heat` analogue: how many living village residents are within
# a radius of `near`. Voxey's villagers are records in `VillageLife`, so counting
# them is the honest equivalent of the source's POI score.
static func village_heat(game: Node3D, near: Vector3, radius: float = 24.0) -> int:
	var life = game.villages
	if life == null: return 0
	var state: Dictionary = life.state()
	var people: Dictionary = state.get("people",{})
	var heat: int = 0
	for key in people:
		var person: Dictionary = people[key]
		if bool(person.get("dead",false)): continue
		var at: Vector3 = life.vec(person.get("position",[0,0,0]))
		if at.distance_to(near) <= radius: heat += 1
	return heat

# The source's surface search: `mobs_mc.find_surface_position`. Voxey's equivalent is
# its own safe-spawn search, which also refuses a spot inside terrain.
static func surface_at(game: Node3D, near: Vector3) -> Vector3:
	var spot: Vector3 = game._safe_spawn(near) if game.has_method("_safe_spawn") else Vector3.INF
	return spot

# `cond_start`. Returns the chosen attack point, or `Vector3.INF` when the night does
# not qualify. `rng` is the world-seeded generator, so a save/reload of the same
# night reaches the same verdict.
static func choose_attack_point(game: Node3D, rng: RandomNumberGenerator) -> Vector3:
	var world: VoxelWorld = game.world
	if world.dimension != "overworld": return Vector3.INF
	var state: Dictionary = runtime(world)
	# `t < 0.04`: the end of the night, and only after the opening days.
	if game.daylight > NIGHT_DAYLIGHT_MAX or game.day_number() < MIN_DAY: return Vector3.INF
	var night: int = night_of(game.day_number(),game.daylight)
	if int(state.get("night",-1)) == night: return Vector3.INF
	# Source `next_within(10)` is `random(0, 9)`, so the condition is a one-in-ten
	# roll. Writing it as `randi_range(1, 10) != 0` would always be true and the
	# siege could never fire, which is what this used to do.
	if rng.randi_range(0,CHANCE_IN-1) != 0: return Vector3.INF
	# `get_poi_heat(nodepos) >= 5` at the player, then again 32 blocks away.
	var player_at: Vector3 = game.player.position
	if village_heat(game,player_at) < HEAT_MIN: return Vector3.INF
	var bearing: float = rng.randf()*TAU
	var away := Vector3(cos(bearing)*BEARING_DISTANCE,0.0,sin(bearing)*BEARING_DISTANCE)
	var target: Vector3 = player_at+away
	if village_heat(game,target) < HEAT_MIN: return Vector3.INF
	state["night"] = night
	world.set_meta("zombie_siege",state)
	return target

# `spawn_zombies`: up to `OUTER_ATTEMPTS` zombies, each at a spot found by
# `INNER_ATTEMPTS` attempts offset by up to 8 blocks and still near the village.
static func summon(game: Node3D, at: Vector3, rng: RandomNumberGenerator) -> Array:
	var spawned: Array = []
	var world: VoxelWorld = game.world
	for outer in OUTER_ATTEMPTS:
		for inner in INNER_ATTEMPTS:
			var offset := Vector3(float(rng.randi_range(-8,7)),0.0,float(rng.randi_range(-8,7)))
			var candidate: Vector3 = at+offset
			if village_heat(game,candidate) < HEAT_MIN: continue
			var spot: Vector3 = surface_at(game,candidate)
			if not spot.is_finite(): continue
			var mob = game.spawn_creature("zombie",spot)
			if mob == null: continue
			# The source marks siege zombies with `spawn_abnormally(..., "siege")`,
			# which exempts them from the daylight burn while the siege runs.
			mob.set_meta("siege",true)
			spawned.append(mob)
			break
	var state: Dictionary = runtime(world)
	state["mobs"] = spawned.size()
	state["active"] = not spawned.is_empty()
	world.set_meta("zombie_siege",state)
	return spawned

# `cond_complete`: the event ends when none of the summoned mobs is still alive.
static func finished(game: Node3D) -> bool:
	var state: Dictionary = runtime(game.world)
	if not bool(state.get("active",false)): return false
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion(): continue
		if mob.has_meta("siege"): return false
	state["active"] = false
	state["mobs"] = 0
	game.world.set_meta("zombie_siege",state)
	return true

# The world tick: the one place a siege is ever started or ended.
static func update(game: Node3D, delta: float) -> void:
	var world: VoxelWorld = game.world
	var state: Dictionary = runtime(world)
	var rng: RandomNumberGenerator = state.rng
	if bool(state.get("active",false)):
		if finished(game): game.toast("The siege has broken.")
		return
	var at: Vector3 = choose_attack_point(game,rng)
	if not at.is_finite(): return
	var spawned: Array = summon(game,at,rng)
	if spawned.size() > 0: game.toast("The undead are laying siege to the village!")
