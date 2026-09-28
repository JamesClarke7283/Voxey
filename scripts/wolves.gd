class_name Wolves
extends RefCounted

# `mobs_mc:wolf` (ENTITIES/mobs_mc/wolf.lua) and the owner rules it uses from
# ENTITIES/mcl_mobs/breeding.lua.
#
# * A wild wolf has 8 health, a tamed one 40 (`after_tame`, 185-190). Damage 4
#   at reach 2, 1-3 experience, no drops.
# * Taming (536-555). A bone on a wild wolf that is not attacking tames it at
#   1 in 3; either way the bone is used. A tamed wolf starts sitting.
# * A tamed wolf, right-clicked (482-535):
#   - food heals it by the food's value while it is hurt;
#   - its owner's dye recolours the collar (only to a different colour);
#   - food at full health breeds it, through `feed_tame`;
#   - otherwise its owner's click toggles sitting.
# * Targeting (832-857), in order:
#   - whoever hurt the owner in the last five seconds;
#   - whatever the owner hit in the last five seconds, except creepers, ghasts,
#     the owner's own wolves and tamed mobs;
#   - its own attacker, calling other wolves within 16 to join;
#   - sheep and rabbits, only while wild;
#   - skeletons, wither skeletons and strays, always.
# * Following (breeding.lua:497-559). A tamed wolf that is not sitting walks
#   back to its owner when further than 10 nodes. Beyond 12 it teleports to a
#   walkable cell within ±3 of the owner. It stops within 2. A sitting wolf
#   stays put, unless something other than its owner struck it recently while
#   the owner is within 12.
# * Breeding requires both wolves to be tamed and standing. A pup inherits one
#   parent's variant and collar, and the owner (150-170).
# * Wetness (618-660). Water or rain darkens the coat. On dry ground the wolf
#   shakes for a second and dries.
# * The coat variant is chosen by the spawn biome (100-145). Voxey's meadow is
#   the source's Forest (the `woods` wolf) and its cold highlands the SnowyTaiga
#   (the `ashen` wolf). Everywhere else gets the default `pale` wolf.
# * Spawning (888-960): packs of four on grass, snow blocks, coarse dirt or
#   podzol, at weight 8 in taiga and 5 in forest.

const KIND = "wolf"
const WILD_HEALTH = 8.0
const TAME_HEALTH = 40.0
const TAME_ODDS = 3
const MEMORY = 5.0
const ALERT_RANGE = 16.0
const TRACK_RANGE = 16.0
const FOLLOW = 10.0
const TELEPORT = 12.0
const STOP = 2.0
const SIT_WAKE = 12.0
const SHAKE = 1.0
const PACK = 4
const DEFAULT_COLLAR = "#FF0000"
const SKELETONS = ["skeleton","wither_skeleton","stray"]
const WILD_PREY = ["sheep","rabbit"]
const IGNORED_TARGETS = ["creeper","ghast"]

# `wolf_food`: the heal of each accepted food.
const FOOD = {
	VillageContent.PUFFERFISH:1,VillageContent.TROPICAL_FISH:1,
	VillageContent.RAW_CHICKEN:2,VillageContent.RAW_MUTTON:2,VillageContent.RAW_COD:2,VillageContent.RAW_SALMON:2,
	VillageContent.RAW_PORKCHOP:3,VillageContent.RAW_BEEF:3,VillageContent.RAW_RABBIT:3,
	Nodes.ROTTEN_FLESH:4,
	VillageContent.COOKED_RABBIT:5,VillageContent.COOKED_COD:5,
	VillageContent.COOKED_MUTTON:6,VillageContent.COOKED_CHICKEN:6,VillageContent.COOKED_SALMON:6,
	VillageContent.COOKED_PORKCHOP:8,VillageContent.COOKED_BEEF:8,
	VillageContent.RABBIT_STEW:10,
}

# The source's collar colours by dye group, keyed by Voxey's dye names.
const COLLARS = {
	"black":"#000000","blue":"#0000BB","brown":"#663300","cyan":"#01FFD8",
	"green":"#005B00","silver":"#C0C0C0","grey":"#303030","lime":"#00FF01",
	"magenta":"#FF05BB","orange":"#FF8401","pink":"#FF65B5","red":"#FF0000",
	"purple":"#5000CC","white":"#FFFFFF","yellow":"#FFFF00","light_blue":"#B0B0FF",
}

# The nine source variants, drawn as Voxey's own coat colours.
const VARIANTS = {
	"pale":[Color("d8d4cc"),Color("b3aea5")],"woods":[Color("8f7050"),Color("5f4a34")],
	"ashen":[Color("a4a9ad"),Color("6f7479")],"snowy":[Color("f1f1ec"),Color("cfd0cb")],
	"black":[Color("37332f"),Color("1f1c1a")],"chestnut":[Color("8e5e3e"),Color("5e3d27")],
	"rusty":[Color("b8703d"),Color("7d4523")],"spotted":[Color("c9a56c"),Color("7d6440")],
	"striped":[Color("aa8d66"),Color("6a5438")],
}
const BIOME_VARIANT = {"Oakwood meadow":"woods","Frostpine highlands":"ashen"}
# The source's weights beside the farm animals of the same biome (sheep 12,
# pig 10, chicken 10, cow 8): forest wolves at 5 and taiga wolves at 8.
const BIOME_WEIGHT = {"Oakwood meadow":5,"Frostpine highlands":8}
const FARM_WEIGHT = 40

static func is_wolf(kind: String) -> bool: return kind == KIND
static func tamed(mob: Node3D) -> bool: return bool(mob.get_meta("tamed",false))
static func owner(mob: Node3D) -> String: return str(mob.get_meta("owner",""))
static func sitting(mob: Node3D) -> bool: return tamed(mob) and bool(mob.get_meta("sitting",false))
static func collar(mob: Node3D) -> String: return str(mob.get_meta("collar",DEFAULT_COLLAR))
static func variant(mob: Node3D) -> String: return str(mob.get_meta("wolf_variant","pale"))
static func max_health(mob: Node3D) -> float: return TAME_HEALTH if tamed(mob) else WILD_HEALTH
static func is_food(id: int) -> bool: return FOOD.has(id)
static func heal_for(id: int) -> int: return int(FOOD.get(id,0))
static func variant_for_biome(biome: String) -> String: return str(BIOME_VARIANT.get(biome,"pale"))

static func collar_for(dye: String) -> String: return str(COLLARS.get(dye,""))

static func dye_name(id: int) -> String:
	var data: Dictionary = VillageContent.DATA.get(id,{})
	return str(data.get("dye","")) if data.get("family","") == "dye" else ""

# --- taming and orders ------------------------------------------------------

# `just_tame` + `after_tame`: owned, sitting, and at the tamed maximum of 40.
static func tame(mob: Node3D, owner_id: String) -> void:
	mob.set_meta("tamed",true)
	mob.set_meta("owner",owner_id)
	mob.set_meta("sitting",true)
	mob.provoked = false
	mob.health = TAME_HEALTH
	refresh(mob)

# The bone roll: `pr:next (1, 3) == 1`.
static func bone_tames(roll: int) -> bool: return roll == 1

static func angry(mob: Node3D) -> bool: return mob.provoked and not tamed(mob)

# The whole right-click. Returns true when the click was used.
static func use(game: Node3D, mob: Node3D, rng: RandomNumberGenerator = null) -> bool:
	if rng == null: rng = rng_for(game.world)
	var held: Dictionary = game.inventory.held()
	var id: int = int(held.id) if held.count > 0 else 0
	var creative: bool = game.gamemode == "creative"
	if tamed(mob):
		# Food heals a hurt wolf.
		if is_food(id) and mob.health < max_health(mob):
			mob.health = minf(max_health(mob),mob.health+heal_for(id))
			if not creative: game.inventory.consume_selected()
			game.sound("eat"); refresh(mob); Farming.remember(mob)
			return true
		# The owner's dye recolours the collar, and only a change uses the dye.
		if owner(mob) == game.player_id and not dye_name(id).is_empty():
			var color: String = collar_for(dye_name(id))
			if not color.is_empty() and color != collar(mob):
				mob.set_meta("collar",color)
				if not creative: game.inventory.consume_selected()
				refresh(mob); Farming.remember(mob)
			return true
		# `feed_tame` grows a pup before it considers breeding.
		if is_food(id) and mob.growth_remaining > 0:
			mob.growth_remaining *= 0.9
			if not creative: game.inventory.consume_selected()
			return true
		# Food at full health breeds a standing wolf, as `feed_tame` does.
		if is_food(id) and not sitting(mob) and mob.growth_remaining <= 0 and mob.breed_cooldown <= 0 and mob.love_time <= 0:
			mob.love_time = Farming.LOVE_TIME
			if not creative: game.inventory.consume_selected()
			game.puff(mob.center(),Color("ef7c8f"),6,1.2); game.sound("eat"); Farming.remember(mob)
			return true
		if owner(mob) == game.player_id:
			mob.set_meta("sitting",not sitting(mob))
			mob.direction = Vector3.ZERO
			refresh(mob); Farming.remember(mob)
			return true
		return false
	if id == Nodes.BONE and not mob.provoked:
		if not creative: game.inventory.consume_selected()
		if bone_tames(rng.randi_range(1,TAME_ODDS)):
			tame(mob,game.player_id)
			game.puff(mob.center()+Vector3.UP*0.3,Color("ef7c8f"),8,1.0)
			game.toast("The wolf is now your companion.")
		else:
			game.puff(mob.center()+Vector3.UP*0.3,Color("2b2b2b"),5,0.8)
		Farming.remember(mob)
		return true
	return false

# --- damage bookkeeping for the owner rules ----------------------------------

static func memory(game: Node3D) -> Dictionary:
	if not game.has_meta("wolf_memory"): game.set_meta("wolf_memory",{"assailant":null,"assailant_time":-INF,"target":null,"target_time":-INF,"serial":0})
	return game.get_meta("wolf_memory")

static func now(game: Node3D) -> float: return float(game.day_time)*1200.0

# `mcl_damage.register_modifier`: the source of a hit on the player is kept for
# five seconds, and so is the mob the player last struck.
static func record_player_hurt(game: Node3D, attacker: Node3D) -> void:
	if attacker == null or not is_instance_valid(attacker): return
	var data: Dictionary = memory(game)
	data.assailant = attacker; data.assailant_time = now(game); data.serial = int(data.serial)+1

static func record_player_struck(game: Node3D, victim: Node3D) -> void:
	if victim == null or not is_instance_valid(victim) or not victim is Creature: return
	var data: Dictionary = memory(game)
	data.target = victim; data.target_time = now(game); data.serial = int(data.serial)+1

static func remembered(game: Node3D, key: String) -> Node3D:
	var data: Dictionary = memory(game)
	var mob: Variant = data.get(key)
	if mob == null or not is_instance_valid(mob) or mob.is_queued_for_deletion(): return null
	if now(game)-float(data.get(key+"_time",-INF)) > MEMORY: return null
	return mob

# `should_attack_owner_assailant_or_target`.
static func may_attack(mob: Node3D, other: Node3D) -> bool:
	if other == null or other == mob or not other is Creature: return false
	if other.kind in IGNORED_TARGETS: return false
	if is_wolf(other.kind) and tamed(other) and owner(other) == owner(mob): return false
	if tamed(other): return false
	return true

# The wolf's current mob target, following the source's rule order. The player
# is never returned; an angry wild wolf goes for the player through `aggressive`.
static func target(game: Node3D, mob: Node3D) -> Node3D:
	if sitting(mob) and not woken(game,mob): return null
	if tamed(mob) and owner(mob) == game.player_id:
		var assailant: Node3D = remembered(game,"assailant")
		if may_attack(mob,assailant) and assailant.position.distance_to(mob.position) <= TRACK_RANGE: return assailant
		var struck: Node3D = remembered(game,"target")
		if may_attack(mob,struck) and struck.position.distance_to(mob.position) <= TRACK_RANGE: return struck
	var attacker: Node3D = attacker_of(mob)
	if attacker != null and may_attack(mob,attacker): return attacker
	var prey: Array = hunted(mob)
	var best: Node3D = null
	var best_distance: float = TRACK_RANGE
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not prey.has(other.kind): continue
		if tamed(other): continue
		var d: float = mob.position.distance_to(other.position)
		if d < best_distance and mob._sees(other.center()): best = other; best_distance = d
	return best

static func hunted(mob: Node3D) -> Array:
	return SKELETONS if tamed(mob) else WILD_PREY+SKELETONS

static func attacker_of(mob: Node3D) -> Node3D:
	var id: int = int(mob.get_meta("wolf_attacker",0))
	if id == 0 or not is_instance_id_valid(id): return null
	var other: Object = instance_from_id(id)
	return other if other is Creature and not other.is_queued_for_deletion() else null

# `sit_if_ordered`: a sitting wolf gets up when something other than its owner
# struck it recently and the owner is within twelve.
static func woken(game: Node3D, mob: Node3D) -> bool:
	return mob.scared <= 0 and float(mob.get_meta("wolf_hit_time",-INF)) > now(game)-MEMORY and mob.position.distance_to(game.player.position) < SIT_WAKE and (attacker_of(mob) != null or not bool(mob.get_meta("hit_by_owner",true)))

# Called from `Creature.hit`: remember the attacker, anger a wild wolf at a
# player, and call the wolves within sixteen.
static func struck(game: Node3D, mob: Node3D, from: Vector3) -> void:
	var attacker: Node3D = null
	var nearest: float = 1.6
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion(): continue
		var d: float = other.position.distance_to(from)
		if d < nearest: nearest = d; attacker = other
	var by_player: bool = attacker == null and from.distance_to(game.player.position) < 5.0
	mob.set_meta("wolf_hit_time",now(game))
	mob.set_meta("hit_by_owner",by_player and tamed(mob) and owner(mob) == game.player_id)
	if attacker != null: mob.set_meta("wolf_attacker",attacker.get_instance_id())
	# A tamed wolf never turns on its owner.
	if tamed(mob) and by_player and owner(mob) == game.player_id: mob.provoked = false; return
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not is_wolf(other.kind): continue
		if other.position.distance_to(mob.position) > ALERT_RANGE: continue
		if attacker != null:
			if may_attack(other,attacker): other.set_meta("wolf_attacker",attacker.get_instance_id())
		elif not tamed(other):
			other.provoked = true; other.last_seen = other.life

static func aggressive(game: Node3D, mob: Node3D) -> bool:
	return angry(mob) and game.gamemode != "creative" and mob.growth_remaining <= 0

# --- movement ------------------------------------------------------------------

# Used by `Farming.direction` after the mate search: sitting stops the wolf, and a
# tamed wolf returns to its owner past ten nodes.
static func direction(mob: Node3D) -> Vector3:
	if sitting(mob) and not woken(mob.game,mob): return Vector3.ZERO
	if tamed(mob) and owner(mob) == mob.game.player_id:
		var gap: float = mob.position.distance_to(mob.game.player.position)
		if gap > FOLLOW or (gap > STOP and mob.has_meta("wolf_travelling")):
			mob.set_meta("wolf_travelling",true)
			return ((mob.game.player.position-mob.position)*Vector3(1,0,1)).normalized()
		if mob.has_meta("wolf_travelling"): mob.remove_meta("wolf_travelling")
	return Vector3.INF

# `teleport_to_owner`: ten tries at a walkable cell within ±3 (±1 vertically).
static func teleport_to_owner(game: Node3D, mob: Node3D, rng: RandomNumberGenerator) -> bool:
	var base := Vector3i(game.player.position.floor())
	for attempt in 10:
		var cell: Vector3i = base+Vector3i(rng.randi_range(-3,3),rng.randi_range(-1,1),rng.randi_range(-3,3))
		if not game.world.loaded_at(Vector3(cell)): continue
		var below: int = game.world.node_at(cell+Vector3i.DOWN)
		if not Nodes.solid(below) or WoodTypes.is_leaves(below): continue
		var at: Vector3 = Vector3(cell)+Vector3(0.5,0.01,0.5)
		if game.world.intersects(at,mob.width,mob.height): continue
		mob.position = at; mob.velocity = Vector3.ZERO
		if mob.has_meta("wolf_travelling"): mob.remove_meta("wolf_travelling")
		return true
	return false

# The per-frame rules the shared step does not cover.
static func step(game: Node3D, mob: Node3D, delta: float) -> void:
	if tamed(mob) and not sitting(mob) and owner(mob) == game.player_id and mob.position.distance_to(game.player.position) > TELEPORT:
		teleport_to_owner(game,mob,rng_for(game.world))
	# Wetness: water or rain soaks the coat; dry ground shakes it off.
	var cell := Vector3i(mob.position.floor())
	var wet_now: bool = Fluids.water(game.world.node_at(cell)) or Weather.exposed_to_rain(game.world,cell)
	if wet_now:
		mob.set_meta("wolf_wet",true); mob.set_meta("wolf_shake",0.0)
	elif bool(mob.get_meta("wolf_wet",false)) and mob.grounded:
		var shake: float = float(mob.get_meta("wolf_shake",0.0))+delta
		mob.set_meta("wolf_shake",shake)
		if fmod(shake,0.25) < delta: game.puff(mob.center(),Color("8fb8d8"),3,0.6)
		if shake >= SHAKE: mob.set_meta("wolf_wet",false); mob.set_meta("wolf_shake",0.0)
	refresh(mob)

# --- breeding and persistence --------------------------------------------------

# `wolf:on_breed`: the pup takes one parent's look and is owned and tamed.
static func on_breed(parent: Node3D, mate: Node3D, pup: Node3D, rng: RandomNumberGenerator) -> void:
	var source: Node3D = parent if rng.randi_range(1,2) == 1 else mate
	set_variant(pup,variant(source))
	pup.set_meta("collar",collar(source))
	pup.set_meta("tamed",true)
	pup.set_meta("owner",owner(parent))
	pup.set_meta("sitting",false)
	pup.health = TAME_HEALTH
	refresh(pup)

static func snapshot(mob: Node3D) -> Dictionary:
	return {"tamed":tamed(mob),"owner":owner(mob),"sitting":sitting(mob),"collar":collar(mob),"variant":variant(mob)}

# Old or damaged records fall back to a wild pale wolf.
static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary: entry = {}
	var chosen: String = str(entry.get("variant","pale"))
	set_variant(mob,chosen if VARIANTS.has(chosen) else "pale")
	mob.set_meta("tamed",bool(entry.get("tamed",false)))
	mob.set_meta("owner",str(entry.get("owner","")) if tamed(mob) else "")
	mob.set_meta("sitting",bool(entry.get("sitting",false)) and tamed(mob))
	var color: String = str(entry.get("collar",DEFAULT_COLLAR))
	mob.set_meta("collar",color if COLLARS.values().has(color) else DEFAULT_COLLAR)
	refresh(mob)

# --- art --------------------------------------------------------------------

# A coat is baked into the merged body, so a different variant rebuilds it.
static func set_variant(mob: Node3D, chosen: String) -> void:
	if variant(mob) == chosen and mob.has_meta("wolf_variant"): return
	mob.set_meta("wolf_variant",chosen)
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	mob.merge_parts()
	CreatureArt.farm_age(mob,mob.growth_remaining > 0)

static func build(mob: Node3D) -> void:
	if not mob.has_meta("wolf_variant"):
		var biome: String = mob.game.world.generator.biome(floori(mob.position.x),floori(mob.position.z)) if mob.game != null and mob.game.world != null else ""
		mob.set_meta("wolf_variant",variant_for_biome(biome))
	var coat: Array = VARIANTS.get(variant(mob),VARIANTS.pale)
	var fur: Color = coat[0]; var dark: Color = coat[1]
	mob._box(Vector3(0,0.5,0.1),Vector3(0.36,0.34,0.62),fur,"fur")
	# The ruff: a wider mane over the shoulders.
	mob._box(Vector3(0,0.54,-0.2),Vector3(0.46,0.42,0.3),fur.lerp(dark,0.2),"fur")
	mob.head = mob._joint(Vector3(0,0.6,-0.4),"Head")
	mob._box(Vector3(0,0.02,-0.08),Vector3(0.34,0.3,0.24),fur,"fur",mob.head)
	mob._box(Vector3(0,-0.05,-0.26),Vector3(0.17,0.14,0.16),fur.lerp(Color.WHITE,0.15),"fur",mob.head)
	mob._box(Vector3(0,-0.01,-0.345),Vector3(0.07,0.05,0.02),Color("1f1b19"),"",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.1,0.21,-0.05),Vector3(0.09,0.12,0.05),dark,"fur",mob.head)
		var eye: MeshInstance3D = mob._box(Vector3(side*0.085,0.06,-0.205),Vector3(0.05,0.035,0.012),Color("1d1a17"),"",mob.head)
		eye.set_meta("wolf_eye",true)
		for z in [-0.18,0.32]:
			var leg: Node3D = mob._joint(Vector3(side*0.11,0.34,z),"Hip")
			mob._box(Vector3(0,-0.17,0),Vector3(0.11,0.34,0.11),fur,"fur",leg)
			mob.legs.append(leg)
	var tail: Node3D = mob._joint(Vector3(0,0.6,0.42),"Tail")
	mob._box(Vector3(0,-0.16,0.02),Vector3(0.1,0.34,0.1),fur,"fur",tail)
	tail.set_meta("wolf_tail",true)
	var band: MeshInstance3D = mob._box(Vector3(0,0.62,-0.29),Vector3(0.48,0.08,0.34),Color(DEFAULT_COLLAR),"cloth")
	band.set_meta("wolf_collar",true)
	refresh(mob)

# The collar shows on a tamed wolf in its colour; angry eyes glow red; a wet
# coat darkens; a tamed wolf's tail rises with its health (`get_tail_height`).
static func refresh(mob: Node3D) -> void:
	if mob.model == null: return
	# `_tint` rebuilds every part from `colors`, so the collar's and eyes' colours
	# are written there as well as to the material.
	for i in mob.parts.size():
		var part: Variant = mob.parts[i]
		if not is_instance_valid(part): continue
		var base: Variant = null
		if part.has_meta("wolf_collar"):
			part.visible = tamed(mob)
			base = Color(collar(mob))
		elif part.has_meta("wolf_eye"):
			var red: bool = angry(mob)
			base = Color("d02a1f") if red else Color.WHITE
			part.material_override.emission_enabled = red
			if red: part.material_override.emission = Color("7a120c")
		if base != null and i < mob.colors.size() and mob.colors[i] != base:
			mob.colors[i] = base
			part.material_override.albedo_color = base
			mob.tint_applied = []
	mob.model.scale = Vector3.ONE*(0.5 if mob.growth_remaining > 0 else 1.0)
	for child in mob.model.get_children():
		if child.has_meta("wolf_tail"):
			child.rotation.x = -(mob.health/TAME_HEALTH)*deg_to_rad(65.0) if tamed(mob) else -0.35
	# Sitting lowers the hindquarters.
	mob.model.rotation.x = -0.35 if sitting(mob) else 0.0
	# A wet coat is drawn by `Creature.rest_tint`.

# --- spawning --------------------------------------------------------------------

static func spawn_share(biome: String) -> float:
	var weight: int = int(BIOME_WEIGHT.get(biome,0))
	return float(weight)/float(weight+FARM_WEIGHT) if weight > 0 else 0.0

static func spawn_allowed(world: VoxelWorld, cell: Vector3i) -> bool:
	if world.dimension != "overworld": return false
	var below: int = world.node_at(cell+Vector3i.DOWN)
	if below not in [Nodes.GRASS,Nodes.SNOW_BLOCK,Nodes.DIRT]: return false
	return not world.intersects(Vector3(cell)+Vector3(0.5,0.01,0.5),0.3,0.85)

static func spawn_pack(game: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	# `build` reads the spawn biome, so a pack shares its variant.
	for i in PACK:
		var cell := Vector3i(pos.floor())+(Vector3i(rng.randi_range(-2,2),0,rng.randi_range(-2,2)) if i > 0 else Vector3i.ZERO)
		if not spawn_allowed(game.world,cell): continue
		var wolf: Node3D = game.spawn_creature(KIND,Vector3(cell)+Vector3(0.5,0.01,0.5))
		if wolf == null: continue
		Farming.remember(wolf)
		made.append(wolf)
	return made

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("wolves_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+4099
		world.set_meta("wolves_rng",rng)
	return world.get_meta("wolves_rng")
