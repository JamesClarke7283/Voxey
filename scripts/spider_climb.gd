class_name SpiderClimb
extends RefCounted

# Mineclonia mods/ENTITIES/mobs_mc/spider.lua and the climb half of
# mods/ENTITIES/mcl_mobs/physics.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# `spider.lua` gives a spider three things Voxey did not have:
#
#   * **Wall climbing.** `always_climb = true` (spider.lua:101) is read by the
#     shared physics at physics.lua:1176-1189: when the mob's horizontal move is
#     blocked (or it stands on something climbable) it holds its fall at 3.0
#     blocks/s, clamps lateral speed to 3.0, and raises `v.y` to 4.0 — so the
#     spider walks up the obstruction it is pressing into. The navigation half of
#     the same behaviour is `spider:navigation_step` (spider.lua:136-169), which
#     keeps the movement goal pointed at the remembered destination while the
#     obstruction lasts, and gives up only once the spider is within half its own
#     body width of that destination.
#   * **A spider jockey.** `spider:on_spawn` (spider.lua:194-205) rolls
#     `math.random(100) == 1` — one in a hundred — and mounts a skeleton on the
#     spider with `jock_to_existing`. A cave spider opts out (spider.lua:359-362).
#   * **The cave spider** (spider.lua:331-364): twelve health instead of sixteen,
#     a body exactly half the spider's width, a smaller and higher-pitched model
#     (`visual_size = {x=0.55, y=0.5}`, `base_pitch = 1.25`, `walk_speed = 40`),
#     and a venomous bite — `dealt_effect = {name = "poison", level = 1,
#     dur_easy = 0, dur = 7, dur_hard = 15}` (spider.lua:350-356), applied on a
#     landed hit by the shared combat code at combat.lua:883-900, where the
#     difficulty picks the duration and a zero duration applies nothing at all.
#
# Adaptations, each forced by Voxey having no mob mounts and no per-mob spawn hook:
#
#   * The source writes `v.y = 4.0` and lets the engine's collision resolve the
#     motion. `climb` performs that same lift itself at the same 4.0 blocks/s and
#     reports whether the spider is climbing; a step pinned under a ceiling keeps
#     the flag but is stopped by the world, exactly as the engine stops the
#     source's spider. The lateral clamp of the same block is applied verbatim.
#   * `jock_to_existing` makes the skeleton share the spider's position, movement
#     and target. With no generic mount, `spawn_jockey` reproduces the observable
#     result: a skeleton spawned at the spider's own position, carrying the same
#     victim (`prey_target`), the same provocation and the same chase clock, and
#     tagged through metadata on both mobs so the pairing survives.
#   * The source's spawn hook is `on_spawn`; Voxey's creatures have none this
#     module may edit, so `update` performs the one roll a spider is due, marked
#     with a `jockey_rolled` metadata flag so it happens exactly once per spider.
#   * Voxey's `difficulty` is the same three-tier setting the Wither's health
#     factors use (withers.gd `HEALTH_FACTOR`), so the source's easy/normal/hard
#     durations map onto it one for one: easy applies no poison at all, normal
#     seven seconds, hard fifteen.
#   * The source's poison immunity is a resistance check on the *victim*:
#     `string.find(entity.name, "spider")` (mcl_potions/functions.lua:212-223),
#     which matches both spider kinds and nothing else. Because Voxey's
#     `PotionEffects.apply` gate lists `["spider","silverfish"]` instead, the
#     source's own rule is applied here, where the bite is dealt, through
#     `is_poison_immune`. Nothing else changes: a splash potion of poison still
#     goes through the shared gate, which is its own concern.
#
# Cave spiders also do **not** spawn from the surface monster spawner: the
# source's cave-spider spawner declares `biomes = {}` (spider.lua:387-393), so
# the only route to one is the mineshaft spawner, which asks for
# `mobs_mc:cave_spider` by name (mcl_levelgen/mineshaft.lua:992).

const SPIDER = "spider"
const CAVE_SPIDER = "cave_spider"
const JOCKEY_KIND = "skeleton"

# Every kind the source gives `always_climb` to. A cave spider merges the spider
# table (spider.lua:331), so it inherits the flag.
const CLIMBERS = [SPIDER,CAVE_SPIDER]

# physics.lua:1183 `v.y = 4.0`.
const CLIMB_SPEED = 4.0
# physics.lua:1180-1181 `v.x = clamp (v.x, -3.0, 3.0)` and the same for z. The
# block's own `v.y = 4.0` replaces the vertical component outright, so the
# source's fall clamp at physics.lua:1177-1179 applies only to the climbable-node
# branch (a ladder), which is not this feature.
const LATERAL_CLAMP = 3.0

# The source's `collisionbox` half-widths, which `navigation_step` measures with
# `(collisionbox[4] - collisionbox[1]) / 2`: 0.7 for the spider (spider.lua:59)
# and 0.35 for the cave spider (spider.lua:339).
const SOURCE_HALF = {SPIDER:0.7,CAVE_SPIDER:0.35}

# How far ahead of itself the spider probes for the obstruction, as a fraction of
# its own body beyond the body's edge. The source measures the real moveresult of
# the move it has just attempted; Voxey asks the same question by extending the
# body slightly along its heading.
const PROBE_MARGIN = 0.1

# spider.lua:197 `math.random (100) == 1`.
const JOCKEY_CHANCE = 100
# spider.lua:351-352 `name = "poison", level = 1`; the duration ladder is
# `dur_easy`, `dur` and `dur_hard` from the same table.
const POISON_LEVEL = 1
const POISON_DURATION = [0.0,7.0,15.0]

static func is_climbing_kind(kind: String) -> bool: return CLIMBERS.has(kind)
static func is_spider_kind(kind: String) -> bool: return kind == SPIDER or kind == CAVE_SPIDER
static func is_cave_spider(kind: String) -> bool: return kind == CAVE_SPIDER

# The cave spider's behaviour flag, which is the only thing about its bite that
# its `KINDS` row has to carry.
static func is_poisonous_kind(kind: String) -> bool:
	return bool(Creature.KINDS.get(kind,{}).get("poisonous",false))

# `spider:navigation_step` (spider.lua:158-161), verbatim: the spider keeps
# pressing toward its destination while it is either still below it and further
# away than half its body width, or further away than a full body width.
static func climbing_obstruction(pos: Vector3, dest: Vector3, half_width: float) -> bool:
	var goal: Vector3 = dest-Vector3(0,0.5,0)
	var dx: float = pos.x-goal.x
	var dz: float = pos.z-goal.z
	var dist_xz: float = sqrt(dx*dx+dz*dz)
	return (pos.y <= goal.y and dist_xz > half_width/2.0) or dist_xz > half_width

# One step of the climb. Returns true while the spider is climbing this step —
# which includes a step pinned under a ceiling, because the source's own flag
# `climbing` is set unconditionally once the obstruction test passes and it is
# the engine's collision, not the mob, that stops the rise there. `target` is the
# place the spider is trying to reach; without one the mob's own heading is used,
# which is what the per-step hook passes.
#
# The vertical arrangement reproduces the source's rate exactly. The source
# assigns `v.y = 4.0` and lets the engine integrate it, with the shared gravity
# applied afterwards; this module is called after Voxey's gravity step instead,
# so it applies the lift itself — `CLIMB_SPEED * delta` — and zeroes the
# accumulator, leaving the next frame's gravity to subtract from the climb speed
# rather than from an accumulating fall. The net rise per frame is therefore
# `4.0 * delta - 22 * delta * delta`, which is precisely what the source's
# ordering produces. Leaving the accumulator alone instead lets it saturate at
# the -3.0 clamp, and the rise decays to a quarter of the source's rate.
static func climb(mob: Creature, delta: float, target: Vector3 = Vector3.INF) -> bool:
	if delta <= 0.0 or mob == null or not is_climbing_kind(mob.kind): return false
	var push: Vector3 = target-mob.position if is_finite(target.x) else mob.direction
	push.y = 0.0
	if push.length() < 0.05: return false
	push = push.normalized()
	# The navigation rule outranks the climb: once the spider is close enough to
	# the destination it stops climbing and halts, which is the source's
	# `_climbing_obstruction = false` followed by `halt_in_tracks`.
	if is_finite(target.x) and not climbing_obstruction(mob.position,target,SOURCE_HALF.get(mob.kind,SOURCE_HALF[SPIDER])): return false
	# `horiz_collision (moveresult)` (physics.lua:1176): the climb only begins
	# against an obstruction the spider is already pushing into, so an
	# unobstructed spider walking in the open never leaves the ground.
	if not mob.game.world.intersects(mob.position+push*(mob.width+PROBE_MARGIN),mob.width,mob.height): return false
	mob.velocity.y = 0.0
	mob.velocity.x = clampf(mob.velocity.x,-LATERAL_CLAMP,LATERAL_CLAMP)
	mob.velocity.z = clampf(mob.velocity.z,-LATERAL_CLAMP,LATERAL_CLAMP)
	var step: float = CLIMB_SPEED*delta
	# A ceiling cancels the source's `v.y = 4.0`; the spider holds its height
	# there rather than rising through it, and keeps holding while it presses on.
	if not mob.game.world.intersects(mob.position+Vector3.UP*step,mob.width,mob.height): mob.position += Vector3.UP*step
	return true

# spider.lua:197 — one roll in `JOCKEY_CHANCE`, on 1 as the source's low draw is.
static func jockey_roll(rng: RandomNumberGenerator) -> bool:
	return rng.randi_range(1,JOCKEY_CHANCE) == 1

# `cave_spider:on_spawn` (spider.lua:359-362) overrides the roll with an empty
# body, so only the ordinary spider is ever a jockey's mount.
static func jockey_allowed(kind: String) -> bool: return kind == SPIDER

# The source's `dealt_effect` duration ladder, by difficulty. Easy is the
# source's `dur_easy` of zero, which the combat code then declines to apply.
static func poison_duration(difficulty: int) -> float:
	return POISON_DURATION[clampi(difficulty,0,2)]

# `mcl_potions/functions.lua:222`: `string.find(entity.name, "spider")` is the
# source's whole resistance condition, and it matches both spider kinds because
# both are named for spiders. A silverfish is a different name and is not spared.
static func is_poison_immune(kind: String) -> bool:
	return kind.contains("spider")

# `combat.lua:883-900`: a landed melee hit from a mob carrying `dealt_effect`
# gives its victim that effect for the difficulty's duration.
static func poison_on_hit(mob: Creature, victim: Node3D) -> void:
	if mob == null or victim == null or not is_poisonous_kind(mob.kind): return
	if victim is Creature and is_poison_immune(victim.kind): return
	var duration: float = poison_duration(mob.game.difficulty)
	if duration <= 0.0: return
	PotionEffects.apply(victim,"poison",duration,POISON_LEVEL)

# The observable half of `jock_to_existing` (spider.lua:198-204): the skeleton
# shares the spider's position and target. Both mobs are tagged so the pairing is
# visible from either end, and the spider carries the rider's instance id.
static func spawn_jockey(game: Node3D, mob: Creature) -> Creature:
	var rider: Creature = game.spawn_creature(JOCKEY_KIND,mob.position)
	if rider == null: return null
	rider.set_meta("jockey",mob.get_instance_id())
	mob.set_meta("jockey",rider.get_instance_id())
	rider.prey_target = mob.prey_target
	rider.provoked = mob.provoked
	rider.last_seen = mob.last_seen
	return rider

# The one roll each spider is due, in place of the source's spawn hook. A cave
# spider is not a candidate at all — its `on_spawn` override is an empty body —
# and the `jockey_rolled` flag makes an ordinary spider's roll happen exactly
# once, so a spider that survives a frame is never rolled twice.
static func update(game: Node3D, delta: float) -> void:
	if game == null or not game.playing(): return
	var clock: float = float(game.world.get_meta("spider_jockey_clock",0.0))-delta
	game.world.set_meta("spider_jockey_clock",clock if clock > 0.0 else 0.4)
	if clock > 0.0: return
	for mob in game.creatures.get_children():
		if not mob is Creature or mob.is_queued_for_deletion() or mob.health <= 0: continue
		if not is_climbing_kind(mob.kind) or not jockey_allowed(mob.kind) or mob.has_meta("jockey_rolled"): continue
		if not game.world.loaded_at(mob.position): continue
		mob.set_meta("jockey_rolled",true)
		if jockey_roll(rng_for(game.world)): spawn_jockey(game,mob)

# The roll's own stream, seeded from the world so a save reloads onto the same
# sequence instead of a fresh one.
static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("spider_climb_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+20701
		world.set_meta("spider_climb_rng",rng)
	return world.get_meta("spider_climb_rng")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("spider_climb_rng"): world.remove_meta("spider_climb_rng")
	if world.has_meta("spider_jockey_clock"): world.remove_meta("spider_jockey_clock")

# ---------------------------------------------------------------------------
# PARENT WIRING — the exact lines Main adds. Nothing else is needed: the cave
# spider adds no block, item, recipe or station, so there is no registry append,
# dispatcher branch or metadata allow-list for this module.
#
# 1. scripts/creature.gd — the wall climb, inserted between the collision loop
#    and `animate`, i.e. immediately after the existing line 822
#    (`if not grounded and game.world.intersects(...): grounded = true`):
#
#        # A spider walks up the obstruction it is pressing into, which is the
#        # source's `always_climb` (spider.lua:101 read at physics.lua:1176-1189).
#        SpiderClimb.climb(self,delta)
#
#    The call takes no target on purpose: `mob.direction` is already the heading
#    the frame resolved, so a spider fleeing a blow climbs *away* from its
#    attacker and an idle one climbs whatever its wander pushed it into, which is
#    what the source's physics does. No edit is needed in the chase branch around
#    lines 727-760: a chasing melee mob already sets `direction = toward`, and
#    that heading is what the climb reads.
#
# 2. scripts/game.gd — the jockey roll, in `_process` beside the other per-step
#    modules, immediately after line 229 (`Golems.update(self,delta)`):
#
#        SpiderClimb.update(self,delta)
#
#    and in the world-teardown block that already resets the other modules
#    (`_clear_entities`, beside `rails.reset()`):
#
#        SpiderClimb.reset(world)
#
# 3. scripts/corridors.gd:66 — the mineshaft spawner asks for the cave spider by
#    name, which is what the source's mineshaft does
#    (mcl_levelgen/mineshaft.lua:992) and what this file already documents at
#    line 27:
#
#        const SPAWNER_MOB = "cave_spider"
#
# 4. scripts/dungeons.gd:9 — `Dungeons.station` (line 189) coerces any spawner
#    mob outside `MOBS` to a zombie, so the corridor's cave spider needs the name
#    in that list or it silently becomes a zombie:
#
#        const MOBS = ["zombie","zombie","spider","skeleton","cave_spider"]
#
#    The dungeon generation roll is unaffected: it indexes `MOBS` with its own
#    `randi_range(0,3)` (line 81), so the appended fourth slot is never drawn for
#    a dungeon spawner.
#
# 5. scripts/creature.gd — the cave spider's art branch, since the model must
#    exist before a corridor spawner can display it. Three edits:
#
#    line 331, `"spider":` becomes
#        "spider","cave_spider":
#
#    line 396, `elif kind == "spider":` becomes `elif kind in ["spider","cave_spider"]:`
#    and a following arm is added after that block:
#        elif kind == "cave_spider":
#            # The source's cave spider is the spider's body in its own teal skin
#            # at `visual_size = {x=0.55, y=0.5}` (spider.lua:333-343).
#            model.scale = Vector3(0.55,0.5,0.55)
#            for part in parts:
#                if not part.material_override.emission_enabled:
#                    part.material_override.albedo_texture = CreatureArt.texture("shell",Color("0c424e"))
#
#    line 548 and line 550, both `kind == "spider"` become `kind in ["spider","cave_spider"]`
#    so the eight legs keep the spider's own swing.
#
# 6. Nothing. The source's poison immunity — `string.find(entity.name, "spider")`
#    (mcl_potions/functions.lua:222) — is applied by this module's
#    `poison_on_hit` through `is_poison_immune`, so `potion_effects.gd:28` keeps
#    its existing spider list and this module does not touch a file the
#    witch-potion work may be holding.
# ---------------------------------------------------------------------------
