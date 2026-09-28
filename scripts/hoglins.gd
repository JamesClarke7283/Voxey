class_name Hoglins
extends RefCounted

# `mobs_mc:hoglin` and `mobs_mc:zoglin` (ENTITIES/mobs_mc/hoglin+zoglin.lua).
#
# The hoglin is a monster that is also a farm animal:
# * 40 health, `armor = {fleshy = 90}`, 9 experience, reach 3, one swing every
#   `melee_interval = 2` seconds, and knockback resistance 0.6. It never despawns
#   (`persist_in_peaceful`).
# * `custom_attack` (352-395): an adult deals `damage / 2 + random(0, damage - 1)`,
#   so 3 to 8. It throws its target sideways by `(0.2 + random × 0.5) × 20`,
#   turned up to ten degrees, and up by `random × 20` if the target is a player
#   (`random × 10` if it is a mob), all scaled by one minus the target's
#   knockback resistance. A baby deals 0.5 and throws nothing.
# * Drops: two to four raw porkchops and up to one leather, cooked when the
#   hoglin dies burning.
# * Repellents (148-166, 213-230): warped fungus, a potted warped fungus, a
#   nether portal or a respawn anchor within ±8 horizontally and ±4 vertically.
#   Sensing one keeps the hoglin passive toward players for ten seconds, and it
#   walks away from one closer than eight. The sensor runs every 0.2 seconds.
# * Targeting (408-445): it retaliates on its attacker. It hunts the nearest
#   player unless passive. When struck it calls every visible hoglin within 16
#   to join, unless it is a baby, or the attacker is a piglin and the piglins
#   outnumber the hoglins; then it retreats from the attacker instead for five
#   to twenty seconds, or until it is fifteen away.
# * Breeding (449-471) on crimson fungus, through `feed_tame (clicker, 4, true)`.
#   Babies are 20% of natural spawns.
# * Conversion (477-503): fifteen seconds in the Overworld turns a hoglin into a
#   zoglin, which then has nausea for ten seconds.
#
# The zoglin (571-615) is the undead form. It is fire-resistant with
# `armor = {undead = 90, fleshy = 90}` and harmed by healing. It never breeds
# and attacks any mob in reach except creepers and other zoglins, and any player.

const HOGLIN = "hoglin"
const ZOGLIN = "zoglin"
const MELEE_INTERVAL = 2.0
const BABY_MELEE_FACTOR = 0.375
const KNOCKBACK_RESISTANCE = 0.6
const SENSE_INTERVAL = 0.2
const SENSE_BOX = Vector3i(8,4,8)
const FLEE_RANGE = 8.0
const PASSIVE_SECONDS = 10.0
const CALL_RANGE = 16.0
const RETREAT_MIN = 5.0
const RETREAT_MAX = 20.0
const RETREAT_RANGE = 15.0
const CONVERT_SECONDS = 15.0
const NAUSEA_SECONDS = 10.0
const BABY_SHARE = 0.2
const PIGLINS = ["piglin","piglin_brute"]
const ZOGLIN_SPARED = ["creeper",ZOGLIN]

static func is_hoglin(kind: String) -> bool: return kind == HOGLIN
static func is_zoglin(kind: String) -> bool: return kind == ZOGLIN
static func is_family(kind: String) -> bool: return kind == HOGLIN or kind == ZOGLIN
static func baby(mob: Node3D) -> bool: return mob.growth_remaining > 0

static func make_baby(mob: Node3D) -> void:
	mob.growth_remaining = Farming.GROW_TIME
	Farming.resize(mob)

static func repellent(id: int) -> bool:
	return id == CrimsonPlants.WARPED_FUNGUS or id == Nodes.NETHER_PORTAL or RespawnAnchors.is_anchor(id)

# `custom_attack`'s damage, from a uniform `random(0, damage - 1)`.
static func damage_roll(base: int, child: bool, roll: int) -> float:
	if child: return 0.5
	return float(base)/2.0+float(roll)

static func attack_damage(mob: Node3D, rng: RandomNumberGenerator) -> float:
	var base: int = int(mob.info().damage)
	return damage_roll(base,baby(mob),rng.randi_range(0,base-1))

# The toss: horizontal toward the target, turned by up to ten degrees; vertical
# up to twenty for a player and ten for a mob.
static func toss(from: Vector3, to: Vector3, resistance: float, player: bool, rng: RandomNumberGenerator) -> Vector3:
	var strength: float = 1.0-resistance
	if strength <= 0.0: return Vector3.ZERO
	var flat := Vector3(to.x-from.x,0,to.z-from.z)
	flat = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	var turned: Vector3 = flat.rotated(Vector3.UP,deg_to_rad(float(rng.randi_range(1,21)-11)))
	var v: Vector3 = turned*strength*(rng.randf()*0.5+0.2)*20.0
	v.y = rng.randf()*(20.0 if player else strength*10.0)
	return v

# --- sensing and passivity --------------------------------------------------

static func nearest_repellent(world: VoxelWorld, pos: Vector3) -> Vector3i:
	var here := Vector3i(pos.floor())
	var best := Vector3i.MAX
	var best_distance: float = INF
	for y in range(-SENSE_BOX.y,SENSE_BOX.y+1):
		for z in range(-SENSE_BOX.z,SENSE_BOX.z+1):
			for x in range(-SENSE_BOX.x,SENSE_BOX.x+1):
				var cell: Vector3i = here+Vector3i(x,y,z)
				if not repellent(world.node_at(cell)): continue
				var d: float = pos.distance_to(Vector3(cell)+Vector3(0.5,0.5,0.5))
				if d < best_distance: best = cell; best_distance = d
	return best

static func passive(mob: Node3D) -> bool: return float(mob.get_meta("hoglin_passive",0.0)) > 0.0

static func sense(game: Node3D, mob: Node3D, delta: float) -> void:
	mob.set_meta("hoglin_passive",maxf(0.0,float(mob.get_meta("hoglin_passive",0.0))-delta))
	var clock: float = float(mob.get_meta("hoglin_sense",0.0))-delta
	if clock > 0.0: mob.set_meta("hoglin_sense",clock); return
	mob.set_meta("hoglin_sense",SENSE_INTERVAL)
	var cell: Vector3i = nearest_repellent(game.world,mob.position)
	if cell == Vector3i.MAX:
		if mob.has_meta("hoglin_repellent"): mob.remove_meta("hoglin_repellent")
		return
	mob.set_meta("hoglin_repellent",cell)
	mob.set_meta("hoglin_passive",PASSIVE_SECONDS)

# The hoglin's movement override: away from a close repellent or a retreat, or
# INF when neither applies.
static func direction(mob: Node3D) -> Vector3:
	if mob.has_meta("hoglin_repellent"):
		var cell: Vector3i = mob.get_meta("hoglin_repellent")
		var away: Vector3 = mob.position-(Vector3(cell)+Vector3(0.5,0,0.5))
		if away.length() < FLEE_RANGE: return (away*Vector3(1,0,1)).normalized()
	var from: Variant = retreat_from(mob)
	if from != null: return ((mob.position-from)*Vector3(1,0,1)).normalized()
	return Vector3.INF

# --- retaliation and retreat --------------------------------------------------

static func count_near(game: Node3D, mob: Node3D, kinds: Array) -> int:
	var count: int = 0
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not kinds.has(other.kind): continue
		if other.position.distance_to(mob.position) <= CALL_RANGE and mob._sees(other.center()): count += 1
	return count

# The retreat target, or null. Ends when the timer runs out, the hoglins now
# outnumber the piglins, or the threat is fifteen away.
static func retreat_from(mob: Node3D) -> Variant:
	if not mob.has_meta("hoglin_retreat_time"): return null
	var from: Vector3 = mob.get_meta("hoglin_retreat_from")
	if float(mob.get_meta("hoglin_retreat_time")) <= 0.0 or mob.position.distance_to(from) > RETREAT_RANGE:
		mob.remove_meta("hoglin_retreat_time"); return null
	return from

static func begin_retreat(mob: Node3D, from: Vector3, rng: RandomNumberGenerator) -> void:
	mob.set_meta("hoglin_retreat_from",from)
	mob.set_meta("hoglin_retreat_time",rng.randf_range(RETREAT_MIN,RETREAT_MAX))

static func tick_retreat(game: Node3D, mob: Node3D, delta: float) -> void:
	if not mob.has_meta("hoglin_retreat_time"): return
	mob.set_meta("hoglin_retreat_time",float(mob.get_meta("hoglin_retreat_time"))-delta)
	# `_nearby_hoglins` counts the other hoglins, not this one.
	if count_near(game,mob,[HOGLIN]) > count_near(game,mob,PIGLINS): mob.remove_meta("hoglin_retreat_time")

# `call_group_attack`: returns true when the hoglin fights back.
static func struck(game: Node3D, mob: Node3D, attacker: Node3D, from: Vector3, rng: RandomNumberGenerator) -> bool:
	if not is_hoglin(mob.kind): return true
	# The player is struck back through `aggressive`; only a mob is a mob target.
	if not attacker is Creature: attacker = null
	var by_piglin: bool = attacker != null and PIGLINS.has(attacker.kind)
	if baby(mob) or by_piglin and count_near(game,mob,PIGLINS) > count_near(game,mob,[HOGLIN]):
		begin_retreat(mob,from,rng)
		if not baby(mob):
			for other in game.creatures.get_children():
				if other != mob and is_hoglin(other.kind) and other.position.distance_to(mob.position) <= CALL_RANGE: begin_retreat(other,from,rng)
		return false
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not is_hoglin(other.kind): continue
		if other.position.distance_to(mob.position) > CALL_RANGE or not mob._sees(other.center()): continue
		other.provoked = true; other.last_seen = other.life
		if attacker != null: other.set_meta("hoglin_target",attacker.get_instance_id())
	if attacker != null: mob.set_meta("hoglin_target",attacker.get_instance_id())
	return true

static func aggressive(game: Node3D, mob: Node3D) -> bool:
	if game.gamemode == "creative" or retreat_from(mob) != null: return false
	if is_zoglin(mob.kind): return true
	return mob.provoked or not passive(mob)

# A mob the hoglin or zoglin is fighting, or null. A zoglin takes the nearest mob
# it may attack; a hoglin only the mob that struck it or its kin.
static func target(game: Node3D, mob: Node3D) -> Node3D:
	var id: int = int(mob.get_meta("hoglin_target",0))
	if id != 0 and is_instance_id_valid(id):
		var other: Object = instance_from_id(id)
		if other is Creature and not other.is_queued_for_deletion() and other.position.distance_to(mob.position) <= CALL_RANGE: return other
	if not is_zoglin(mob.kind): return null
	var best: Node3D = null
	var best_distance: float = CALL_RANGE
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or ZOGLIN_SPARED.has(other.kind): continue
		var d: float = mob.position.distance_to(other.position)
		if d < best_distance and mob._sees(other.center()): best = other; best_distance = d
	return best

# --- conversion ---------------------------------------------------------------

static func conversion_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	if not is_hoglin(mob.kind): return null
	if game.dimension != "overworld":
		mob.set_meta("hoglin_convert",0.0)
		if mob.model != null: mob.model.position = Vector3.ZERO
		return null
	var clock: float = float(mob.get_meta("hoglin_convert",0.0))+delta
	mob.set_meta("hoglin_convert",clock)
	if mob.model != null: mob.model.position = Vector3(sin(mob.life*60.0),0,cos(mob.life*53.0))*0.03
	if clock <= CONVERT_SECONDS: return null
	var next: Node3D = UndeadVariants.replace(game,mob,ZOGLIN)
	if next == null: return null
	if baby(mob): make_baby(next)
	PotionEffects.apply(next,"nausea",NAUSEA_SECONDS,1)
	return next

# --- drops ------------------------------------------------------------------------

static func roll_drops(rng: RandomNumberGenerator, looting: int) -> Array:
	var out: Array = []
	var chops: int = UndeadVariants.roll_entry(rng,1.0,2,4,looting,false)
	var hide: int = UndeadVariants.roll_entry(rng,1.0,0,1,looting,false)
	if chops > 0: out.append([VillageContent.RAW_PORKCHOP,chops])
	if hide > 0: out.append([Nodes.LEATHER,hide])
	return out

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("hoglins_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+6151
		world.set_meta("hoglins_rng",rng)
	return world.get_meta("hoglins_rng")

# --- art --------------------------------------------------------------------------

static func build(mob: Node3D) -> void:
	var rotten: bool = is_zoglin(mob.kind)
	var hide: Color = Color("c48a8a") if rotten else Color("9a6b4a")
	var mane: Color = Color("e8dcc8") if rotten else Color("5f3f2a")
	var snout: Color = Color("d8a6a0") if rotten else Color("c79a7c")
	mob._box(Vector3(0,0.85,0.1),Vector3(0.95,0.8,1.4),hide,"fur")
	# The bristling mane along the back.
	for i in 5: mob._box(Vector3(0,1.3,-0.4+i*0.22),Vector3(0.18,0.2+float(i%2)*0.08,0.14),mane,"fur")
	mob.head = mob._joint(Vector3(0,0.95,-0.62),"Head")
	mob._box(Vector3(0,-0.05,-0.25),Vector3(0.7,0.55,0.55),hide,"fur",mob.head)
	mob._box(Vector3(0,-0.15,-0.55),Vector3(0.4,0.3,0.12),snout,"skin",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.12,-0.14,-0.62),Vector3(0.06,0.06,0.02),Color("3a2420"),"",mob.head)
		# The tusks curling up beside the snout, which are the hoglin's silhouette.
		mob._box(Vector3(side*0.26,0.02,-0.55),Vector3(0.07,0.24,0.07),Color("efe6cf"),"bone",mob.head)
		mob._box(Vector3(side*0.3,0.18,-0.18),Vector3(0.16,0.1,0.12),hide.darkened(0.2),"fur",mob.head)
		mob._box(Vector3(side*0.2,0.1,-0.525),Vector3(0.07,0.05,0.02),Color("f0e0a0") if rotten else Color("2a1c16"),"",mob.head)
		for z in [-0.35,0.55]:
			var leg: Node3D = mob._joint(Vector3(side*0.3,0.5,z),"Hip")
			mob._box(Vector3(0,-0.25,0),Vector3(0.26,0.5,0.26),hide.darkened(0.1),"fur",leg)
			mob._box(Vector3(0,-0.48,-0.02),Vector3(0.28,0.06,0.3),Color("3b2c24"),"",leg)
			mob.legs.append(leg)
	if rotten:
		# Exposed ribs on the flank.
		for side in [-1,1]:
			for i in 3: mob._box(Vector3(side*0.48,0.85,-0.1+i*0.2),Vector3(0.02,0.35,0.06),Color("efe6cf"),"bone")
