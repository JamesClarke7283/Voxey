class_name UndeadVariants
extends RefCounted

# The biome and conversion variants of the zombie and the skeleton:
# `mobs_mc:husk`, `mobs_mc:drowned` and `mobs_mc:stray`, plus the source's
# conversions between them and the drop tables the three families share.
#
# Source: ENTITIES/mobs_mc/zombie.lua (drops 14-56, conversion 575-592, husk
# 811-858, spawning 872-945), ENTITIES/mobs_mc/drowned.lua (definition 29-155,
# equipment 421-435, targeting 544-561, spawning 774-863) and
# ENTITIES/mobs_mc/skeleton+stray.lua (drops 64-85, conversion 175-195, stray
# 367-392, spawning 409-496); drop rolling from ENTITIES/mcl_mobs/physics.lua
# 17-80 and `dealt_effect` from ENTITIES/mcl_mobs/combat.lua 882-899.
#
# Recorded source quirks, ported as written:
# * The stray's slowness-arrow drop is dead. Its definition passes
#   `drops = table.insert (table.copy (skeleton.drops), {...})`, and
#   `table.insert` returns nothing, so the merged table keeps the skeleton's own
#   drops. A stray drops arrows and bones only; it *shoots* slowness arrows.
# * Skeletons and strays carry `_can_freeze = false`, so powder snow never
#   damages them — it only runs the skeleton's conversion clock.
#
# Recorded deviations:
# * The source's 5% baby zombie, husk and drowned are not spawned; Voxey has no
#   baby hostile body yet.
# * Spawning substitutes within Voxey's existing hostile pool rather than running
#   the source's weighted spawner list: in the desert an outdoor zombie becomes a
#   husk at the source's 80 / (80 + 19), and in the cold biome an outdoor skeleton
#   becomes a stray at 80 / (80 + 20). Underground cells keep the base mob, which
#   is what the source's outdoor test on the husk and stray spawners produces.

const HUSK = "husk"
const DROWNED = "drowned"
const STRAY = "stray"
const KINDS = [HUSK,DROWNED,STRAY]
const ZOMBIE_FAMILY = ["zombie",HUSK,DROWNED]
const SKELETON_FAMILY = ["skeleton",STRAY]

# The biomes the source's spawners name. Voxey's cold highlands carry all of the
# source's `cold_biomes`, and its desert is the source's `Desert`.
const DESERT_BIOME = "Sunwash desert"
const COLD_BIOME = "Frostpine highlands"
const HUSK_WEIGHT = 80
const DESERT_ZOMBIE_WEIGHT = 19
const STRAY_WEIGHT = 80
const COLD_SKELETON_WEIGHT = 20

# `zombie:step_conversion`: once the eyes have been under for 30 seconds the mob
# shakes, and at 45 it becomes its `_convert_to`. Past 30 seconds surfacing no
# longer resets the clock.
const SUBMERGED_SHAKE = 30.0
const SUBMERGED_CONVERT = 45.0
# `skeleton:conversion_step`: seven seconds in powder snow starts the shaking and
# twenty-two makes a stray. Leaving the snow resets it at any point.
const FREEZE_SHAKE = 7.0
const FREEZE_CONVERT = 22.0
# `_convert_to`. The drowned sets it to false, so it never converts further.
const CONVERT_TO = {"zombie":DROWNED,HUSK:"zombie"}

# `drops_common`: rotten flesh 0-2 with common looting, and iron, carrot and potato
# at 1 in 120 each with rare looting of 0.01/3 per level.
const COMMON_RARE = 120
const COMMON_RARE_LOOTING = 0.01/3.0
# The drowned's copper ingot: `chance = 100 / 11`, rare looting 0.02.
const COPPER_CHANCE = 11.0/100.0
const COPPER_LOOTING = 0.02
# `mob_class.wielditem_drop_probability`, which the drowned's trident and rod use;
# its nautilus shell is set with a probability of one.
const WIELD_DROP = 0.085
const WIELD_LOOTING = 0.01

# `drowned:generate_default_equipment`.
const EQUIP_ABOVE = 0.9
const TRIDENT_BELOW = 10 # of `random (0, 15)`
const NAUTILUS_CHANCE = 0.03
# The drowned's ranged numbers: `ranged_interval_min/max = 2.0` and
# `ranged_attack_radius = 10.0`, with `inaccuracy = 14 - difficulty * 4` degrees.
const TRIDENT_INTERVAL = 2.0
const TRIDENT_RADIUS = 10.0
const TRIDENT_SPEED = 50.0
const TRIDENT_DAMAGE = 8.0

# The husk's `dealt_effect`: hunger level one for seven seconds, scaled by the
# regional difficulty.
const HUSK_HUNGER = 7.0

# `drowned_spawner:test_spawn_position`: an ocean cell spawns at 1 in 6 and only
# more than five nodes below the source's sea level of zero.
const DROWNED_OCEAN_ODDS = 6
const DROWNED_OCEAN_DEPTH = 5

static func is_variant(kind: String) -> bool: return KINDS.has(kind)
static func is_zombie_kind(kind: String) -> bool: return ZOMBIE_FAMILY.has(kind)
static func is_skeleton_kind(kind: String) -> bool: return SKELETON_FAMILY.has(kind)
# The families whose drops this module rolls instead of the shared table.
static func rolls_drops(kind: String) -> bool: return ZOMBIE_FAMILY.has(kind) or SKELETON_FAMILY.has(kind)

# --- spawning ---------------------------------------------------------------

# The substitution described in the header. `roll` is a uniform [0, 1) draw.
static func biome_variant(kind: String, biome: String, outdoor: bool, roll: float) -> String:
	if not outdoor: return kind
	if kind == "zombie" and biome == DESERT_BIOME:
		return HUSK if roll < float(HUSK_WEIGHT)/float(HUSK_WEIGHT+DESERT_ZOMBIE_WEIGHT) else kind
	if kind == "skeleton" and biome == COLD_BIOME:
		return STRAY if roll < float(STRAY_WEIGHT)/float(STRAY_WEIGHT+COLD_SKELETON_WEIGHT) else kind
	return kind

# Whether an ocean cell may spawn a drowned, given the one-in-six draw. The cell
# must be water with water above it and more than five nodes below sea level.
static func drowned_cell_allowed(world: VoxelWorld, cell: Vector3i, sea: int, odds_roll: int) -> bool:
	if odds_roll != 1: return false
	if cell.y >= sea-DROWNED_OCEAN_DEPTH: return false
	return Fluids.water(world.node_at(cell)) and Fluids.water(world.node_at(cell+Vector3i.UP))

# A random water cell in the column under `near`, or `Vector3i.MAX` when the column
# holds no deep water. The sea level is the terrain generator's.
static func drowned_cell(world: VoxelWorld, near: Vector3, rng: RandomNumberGenerator) -> Vector3i:
	var x: int = floori(near.x)
	var z: int = floori(near.z)
	var sea: int = TerrainGenerator.SEA
	var cells: Array = []
	for y in range(sea-DROWNED_OCEAN_DEPTH-1,world.generator.min_y(),-1):
		var cell := Vector3i(x,y,z)
		var id: int = world.node_at(cell)
		if not Fluids.water(id): break
		if Fluids.water(world.node_at(cell+Vector3i.UP)): cells.append(cell)
	if cells.is_empty(): return Vector3i.MAX
	var picked: Vector3i = cells[rng.randi_range(0,cells.size()-1)]
	return picked if drowned_cell_allowed(world,picked,sea,rng.randi_range(1,DROWNED_OCEAN_ODDS)) else Vector3i.MAX

# --- equipment --------------------------------------------------------------

# `generate_default_equipment`: one in ten is armed, and of those ten in sixteen
# carry a trident and the rest a fishing rod; independently, three in a hundred
# hold a nautilus shell in the off hand.
static func equip_drowned(mob: Node3D, rng: RandomNumberGenerator) -> void:
	if rng.randf() > EQUIP_ABOVE:
		mob.set_meta("wield",VillageContent.TRIDENT if rng.randi_range(0,15) < TRIDENT_BELOW else VillageContent.FISHING_ROD)
	if rng.randf() < NAUTILUS_CHANCE: mob.set_meta("offhand",VillageContent.NAUTILUS_SHELL)

static func wield(mob: Node3D) -> int: return int(mob.get_meta("wield",0))
static func offhand(mob: Node3D) -> int: return int(mob.get_meta("offhand",0))

# `drowned:reconfigure_attack_type`: a trident makes the drowned a ranged attacker.
static func throws_trident(mob: Node3D) -> bool:
	return mob.kind == DROWNED and wield(mob) == VillageContent.TRIDENT

# --- targeting --------------------------------------------------------------

# `object_targetable_p`: by day a drowned only goes for a target that is in water.
static func drowned_targets_player(game: Node3D) -> bool:
	if game.daylight < 0.5: return true
	var cell := Vector3i(game.player.position.floor())
	return Fluids.water(game.world.node_at(cell)) or Fluids.water(game.world.node_at(cell+Vector3i.UP))

# --- combat -----------------------------------------------------------------

# The arrow a skeleton-family archer fires: `mcl_potions:slowness_arrow` for the
# stray, a plain arrow otherwise.
static func arrow_item(kind: String) -> int:
	return VillageContent.SLOWNESS_ARROW if kind == STRAY else Nodes.ARROW_ITEM

# `mcl_bows.add_inaccuracy`: a spread of `inaccuracy` degrees around the aim.
static func trident_velocity(aim: Vector3, difficulty: int, rng: RandomNumberGenerator) -> Vector3:
	var dir: Vector3 = aim.normalized() if aim.length() > 0.001 else Vector3.FORWARD
	var spread: float = deg_to_rad(maxf(0.0,14.0-float(RegionalDifficulty.source_level(difficulty))*4.0))
	var side: Vector3 = dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var up: Vector3 = side.cross(dir).normalized()
	dir = (dir+side*tan(spread)*rng.randf_range(-1.0,1.0)*0.5+up*tan(spread)*rng.randf_range(-1.0,1.0)*0.5).normalized()
	return dir*TRIDENT_SPEED

static func throw_trident(game: Node3D, mob: Node3D, target: Vector3) -> Node3D:
	var origin: Vector3 = mob.position+Vector3.UP*mob.height*0.85
	var arrow: Arrow = game.spawn_arrow(origin,trident_velocity(target-origin,game.difficulty,rng_for(game.world)))
	arrow.item_id = VillageContent.TRIDENT
	arrow.player_damage = TRIDENT_DAMAGE
	arrow.damage = TRIDENT_DAMAGE
	arrow.recoverable = false
	arrow.shooter_kind = mob.kind
	arrow.shooter_id = mob.get_instance_id()
	return arrow

# The husk's `dealt_effect`: seven seconds of hunger, multiplied by the regional
# difficulty at the husk. A zero-length result is skipped, as the source does.
static func husk_hunger_duration(regional: float) -> float:
	return HUSK_HUNGER*regional

static func deal_effect(game: Node3D, mob: Node3D, victim: Node3D) -> void:
	if mob.kind != HUSK or victim == null: return
	var duration: float = husk_hunger_duration(RegionalDifficulty.regional(game,mob.position))
	if duration > 0.0: PotionEffects.apply(victim,"hunger",duration,1)

# --- conversion -------------------------------------------------------------

static func eyes_submerged(game: Node3D, mob: Node3D) -> bool:
	return Fluids.water(game.world.node_at(Vector3i((mob.position+Vector3.UP*mob.height*0.9).floor())))

# The clock is kept on the mob so a save can carry it.
static func conversion_clock(mob: Node3D) -> float: return float(mob.get_meta("conversion_clock",0.0))

# The pure step of either conversion, returned as `[clock, shaking, convert]`.
static func step_submerged(clock: float, submerged: bool, delta: float) -> Array:
	if clock > SUBMERGED_SHAKE or submerged:
		clock += delta
		return [clock,clock > SUBMERGED_SHAKE,clock > SUBMERGED_CONVERT]
	return [0.0,false,false]

static func step_frozen(clock: float, in_snow: bool, delta: float) -> Array:
	if not in_snow: return [0.0,false,false]
	clock += delta
	return [clock,clock > FREEZE_SHAKE,clock > FREEZE_CONVERT]

# Runs the mob's conversion for this frame. Returns the successor when the mob was
# replaced, so the caller stops simulating the old body.
static func conversion_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	var result: Array = []
	var successor: String = ""
	if CONVERT_TO.has(mob.kind):
		result = step_submerged(conversion_clock(mob),eyes_submerged(game,mob),delta)
		successor = CONVERT_TO[mob.kind]
	elif mob.kind == "skeleton":
		result = step_frozen(conversion_clock(mob),mob.in_powder_snow(),delta)
		successor = STRAY
	else: return null
	mob.set_meta("conversion_clock",result[0])
	mob.set_meta("shaking",result[1])
	# The source's `shaking` flag jitters the body, which is the only warning.
	if mob.model != null:
		mob.model.position = Vector3(sin(mob.life*60.0),0,cos(mob.life*53.0))*0.03 if result[1] else Vector3.ZERO
	if not result[2]: return null
	return replace(game,mob,successor)

# `mob_class:replace_with (successor, true)`: the successor keeps the nametag, the
# persistence and the facing, and inherits the held items; health is the new
# mob's own, as the source creates it fresh.
static func replace(game: Node3D, mob: Node3D, successor: String) -> Node3D:
	var next: Node3D = game.spawn_creature(successor,mob.position)
	if next == null: return null
	next.custom_name = mob.custom_name
	if mob.has_meta("persistent"): next.set_meta("persistent",true)
	for key in ["wield","offhand"]:
		if mob.has_meta(key): next.set_meta(key,mob.get_meta(key))
		elif next.has_meta(key): next.remove_meta(key)
	next.set_meta("equipped",true)
	next.provoked = mob.provoked
	if mob.model != null and next.model != null: next.model.rotation.y = mob.model.rotation.y
	Farming.forget(mob)
	mob.queue_free()
	return next

# --- drops ------------------------------------------------------------------

# `mob_class:item_drop` for one definition: `chance` is the success probability,
# raised by `rare_factor` per looting level, and common looting adds
# `floor(random(0, looting) + 0.5)` only when the base roll succeeded.
static func roll_entry(rng: RandomNumberGenerator, chance: float, low: int, high: int, looting: int, common: bool, rare_factor: float = 0.0) -> int:
	if looting > 0 and not common and rare_factor > 0.0: chance += rare_factor*looting
	if rng.randf() >= chance: return 0
	var count: int = rng.randi_range(low,high)
	if common and looting > 0: count += rng.randi_range(0,looting)
	return count

static func roll_drops(kind: String, rng: RandomNumberGenerator, looting: int, mob: Node3D = null) -> Array:
	var out: Array = []
	if kind in ["zombie",HUSK]:
		out.append([Nodes.ROTTEN_FLESH,roll_entry(rng,1.0,0,2,looting,true)])
		for id in [Nodes.IRON,VillageContent.CARROT,VillageContent.POTATO]:
			out.append([id,roll_entry(rng,1.0/COMMON_RARE,1,1,looting,false,COMMON_RARE_LOOTING)])
	elif kind == DROWNED:
		out.append([Nodes.ROTTEN_FLESH,roll_entry(rng,1.0,0,2,looting,true)])
		out.append([Nodes.COPPER,roll_entry(rng,COPPER_CHANCE,1,1,looting,false,COPPER_LOOTING)])
	elif kind in SKELETON_FAMILY:
		out.append([Nodes.ARROW_ITEM,roll_entry(rng,1.0,0,2,looting,true)])
		out.append([Nodes.BONE,roll_entry(rng,1.0,0,2,looting,true)])
	if mob != null:
		if wield(mob) != 0 and rng.randf() < WIELD_DROP+WIELD_LOOTING*looting: out.append([wield(mob),1])
		if offhand(mob) != 0: out.append([offhand(mob),1])
	return out.filter(func(entry): return int(entry[1]) > 0)

# --- art --------------------------------------------------------------------

# The zombie body's palette. The husk is the source's sand-bleached zombie and the
# drowned its sea-green, kelp-ragged one.
static func zombie_palette(kind: String) -> Dictionary:
	match kind:
		HUSK: return {"shirt":Color("6b5a3e"),"skin":Color("b5a276"),"hair":Color("7a6a4c"),"trousers":Color("5a4b37"),"boots":Color("463b2c"),"mouth":Color("4d4130"),"eye":Color("2f2618")}
		DROWNED: return {"shirt":Color("3f7f7a"),"skin":Color("5f9e8e"),"hair":Color("2f5b53"),"trousers":Color("4b6f73"),"boots":Color("2d4a4c"),"mouth":Color("26463f"),"eye":Color("9be6e0")}
	return {}

static func skeleton_palette(kind: String) -> Dictionary:
	if kind == STRAY: return {"bone":Color("c6d3d4"),"cloak":Color("5d6f73")}
	return {}

# The stray's bones are the skeleton's shifted toward its frost blue-grey; every
# other kind keeps the colour it was given.
static func bone_tint(kind: String, base: Color) -> Color:
	if kind != STRAY: return base
	return base.lerp(Color("a9c3c8"),0.5)

# The stray's tattered cloak and the drowned's held items, added after the shared
# body is built.
static func dress(mob: Node3D) -> void:
	if mob.kind == STRAY:
		var pal: Dictionary = skeleton_palette(STRAY)
		mob._box(Vector3(0,1.02,0.02),Vector3(0.46,0.62,0.26),pal.cloak,"cloth")
		for side in [-1,1]: mob._box(Vector3(side*0.16,0.7,0.1),Vector3(0.1,0.22,0.06),pal.cloak.darkened(0.2),"cloth")
	elif mob.kind == DROWNED:
		# Kelp strands hang from the shoulders and the head.
		for side in [-1,1]:
			mob._box(Vector3(side*0.2,1.12,-0.15),Vector3(0.05,0.34,0.02),Color("3d7a3a"),"moss")
		if mob.head != null: mob._box(Vector3(0.12,0.3,-0.2),Vector3(0.05,0.18,0.02),Color("3d7a3a"),"moss",mob.head)
		refresh_held(mob)

static func refresh_held(mob: Node3D) -> void:
	if mob.arms.size() < 2: return
	for arm in mob.arms:
		for child in arm.get_children():
			if child.has_meta("held"): child.queue_free()
	if wield(mob) == VillageContent.TRIDENT:
		var shaft: MeshInstance3D = mob._box(Vector3(0,-0.62,-0.2),Vector3(0.05,0.05,0.9),Color("7c9590"),"",mob.arms[1])
		shaft.set_meta("held",true)
		for x in [-0.09,0.0,0.09]:
			var prong: MeshInstance3D = mob._box(Vector3(x,-0.62,-0.72),Vector3(0.035,0.04,0.2),Color("79c0ba"),"",mob.arms[1])
			prong.set_meta("held",true)
	elif wield(mob) == VillageContent.FISHING_ROD:
		var rod: MeshInstance3D = mob._box(Vector3(0,-0.6,-0.3),Vector3(0.035,0.035,0.8),Color("7a5a36"),"wood",mob.arms[1])
		rod.set_meta("held",true)
	if offhand(mob) == VillageContent.NAUTILUS_SHELL:
		var shell: MeshInstance3D = mob._box(Vector3(0,-0.55,-0.08),Vector3(0.16,0.16,0.12),Color("d9c2a8"),"",mob.arms[0])
		shell.set_meta("held",true)

# --- persistence and randomness ----------------------------------------------

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("undead_variants_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+31337
		world.set_meta("undead_variants_rng",rng)
	return world.get_meta("undead_variants_rng")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("undead_variants_rng"): world.remove_meta("undead_variants_rng")
