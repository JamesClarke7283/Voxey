class_name Dolphins
extends RefCounted

# `mobs_mc:dolphin` (ENTITIES/mobs_mc/dolphin.lua).
#
# * 10 health, 2.5 damage at reach 2, 1-3 experience, drops 0-1 raw cod. It is
#   neutral: it retaliates on whatever strikes it except guardians, and calls the
#   dolphins in range to join (`build_retaliation_target_rule`, 648-653).
# * Air (392-394, 515-547): it holds 240 seconds of air under water and refills
#   at the surface. Below five seconds it heads straight up for air.
# * Moisture (105-116): out of water and out of the rain it dries for 120
#   seconds, then takes one damage a second.
# * Swimming with a player (278-328): it joins the nearest swimming player within
#   sixteen, keeps within 2.5 of them, and each tick grants Dolphin's Grace for
#   five seconds at one in six.
# * Boats (124-194): it swims alongside a boat whose driver is moving, within
#   four nodes, heading where the boat heads.
# * Treasure (84-99, 343-373, 396-461): raw cod, salmon or tropical fish feeds
#   it. A fed dolphin with air leads to the nearest chest within 64 nodes
#   horizontally and from 16 below it to one above it, and stops two nodes from
#   it horizontally.
# * Leaping (221-276): every half second, at one in ten scaled to the tick, it
#   breaches when water lies ahead with two air cells above it, adding
#   `(dx × 12, 14, dz × 12)` to its velocity.
# * Spawning (656-684): the source's warm oceans at weight 2 and the others at 1,
#   in packs of one or two.
#
# A source quirk ported as written: `dolphin_return_to_water_1` returns
# `nodes[0]`, which is always nil in a Lua array, so a beached dolphin never walks
# back to water on its own; it dries out unless the rain or a player saves it.

const KIND = "dolphin"
const MAX_AIR = 240.0
const LOW_AIR = 5.0
const MOISTURE = 120.0
const DRY_DAMAGE_INTERVAL = 1.0
const SWIM_RANGE = 16.0
const SWIM_CLOSE = 2.5
const GRACE_SECONDS = 5.0
const GRACE_ODDS = 6
const BOAT_RANGE = 4.0
const FOODS = [VillageContent.RAW_COD,VillageContent.RAW_SALMON,VillageContent.TROPICAL_FISH]
const TREASURE_REACH = 64
const TREASURE_BELOW = 16
const TREASURE_STOP = 2.0
const JUMP_INTERVAL = 0.5
const JUMP_ODDS = 10
const JUMP_PUSH = 12.0
const JUMP_LIFT = 14.0
const IGNORED_ATTACKERS = ["guardian","guardian_elder"]
const OCEAN_WEIGHT = 1
const WATER_CREATURE_WEIGHT = 10

static func is_dolphin(kind: String) -> bool: return kind == KIND
static func is_food(id: int) -> bool: return FOODS.has(id)

static func air(mob: Node3D) -> float: return float(mob.get_meta("dolphin_air",MAX_AIR))
static func moisture(mob: Node3D) -> float: return float(mob.get_meta("dolphin_moisture",MOISTURE))

static func in_water(world: VoxelWorld, mob: Node3D) -> bool:
	return Fluids.water(world.node_at(Vector3i(mob.position.floor())))

static func head_under(world: VoxelWorld, mob: Node3D) -> bool:
	return Fluids.water(world.node_at(Vector3i((mob.position+Vector3.UP*mob.height*0.9).floor())))

static func player_swimming(game: Node3D) -> bool:
	return Fluids.contains(game.world,game.player.position+Vector3.UP*0.05,Nodes.WATER)

# The pure air and moisture step, as `[air, moisture, damage]`.
static func breathe(air_left: float, moisture_left: float, submerged: bool, wet: bool, delta: float) -> Array:
	var damage: float = 0.0
	air_left = maxf(0.0,air_left-delta) if submerged else MAX_AIR
	if air_left <= 0.0: damage += delta
	moisture_left = MOISTURE if wet else maxf(0.0,moisture_left-delta)
	if moisture_left <= 0.0: damage += delta
	return [air_left,moisture_left,damage]

# Feeding: a fish sets the dolphin searching and is consumed.
static func feed(game: Node3D, mob: Node3D) -> bool:
	var held: Dictionary = game.inventory.held()
	if held.count <= 0 or not is_food(int(held.id)): return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	mob.set_meta("dolphin_fed",true)
	var chest: Vector3i = nearest_chest(game.world,Vector3i(mob.position.floor()))
	if chest == Vector3i.MAX: mob.remove_meta("dolphin_treasure")
	else: mob.set_meta("dolphin_treasure",chest)
	game.puff(mob.center(),Color("9fd8ea"),6,0.8)
	return true

static func nearest_chest(world: VoxelWorld, here: Vector3i) -> Vector3i:
	var best := Vector3i.MAX
	var best_distance: float = INF
	# `vector.offset (self_pos, 64, math.min (1, self_pos.y + 16), 64)`: the top of the
	# box is at most one node above the dolphin, and the source's `y + 16` is read
	# against its sea level of zero.
	var top: int = here.y+mini(1,here.y-TerrainGenerator.SEA+TREASURE_BELOW)
	# Every chest with a station: generated structure chests get theirs, with their
	# loot, when their column loads. A double chest's key names both halves.
	for key in world.stations:
		var parts: PackedStringArray = str(key).get_slice("+",0).split(",")
		if parts.size() != 3: continue
		var p := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		if world.node_at(p) != Nodes.CHEST: continue
		if absi(p.x-here.x) > TREASURE_REACH or absi(p.z-here.z) > TREASURE_REACH: continue
		if p.y < here.y-TREASURE_BELOW or p.y > top: continue
		var d: float = Vector3(p).distance_to(Vector3(here))
		if d < best_distance: best = p; best_distance = d
	return best

# Where the dolphin swims this step, or INF when nothing overrides its wander.
static func direction(game: Node3D, mob: Node3D) -> Vector3:
	if air(mob) < LOW_AIR: return Vector3.ZERO
	if mob.has_meta("dolphin_treasure") and bool(mob.get_meta("dolphin_fed",false)):
		var chest: Vector3i = mob.get_meta("dolphin_treasure")
		var flat := Vector3(chest.x+0.5-mob.position.x,0,chest.z+0.5-mob.position.z)
		if flat.length() <= TREASURE_STOP:
			mob.set_meta("dolphin_fed",false); mob.remove_meta("dolphin_treasure")
			return Vector3.ZERO
		return flat.normalized()
	# `dolphin_swim_with_boat`: the player's boat, while it is moving.
	var boat: Variant = game.boats.riding if game.boats != null and game.boats.ridden() else null
	if boat is Node3D and is_instance_valid(boat) and Vector2(game.player.velocity.x,game.player.velocity.z).length() > 0.1 and boat.position.distance_to(mob.position) <= BOAT_RANGE*3.0:
		var heading: Vector3 = -boat.global_basis.z
		return (Vector3(heading.x,0,heading.z)).normalized() if boat.position.distance_to(mob.position) <= BOAT_RANGE else ((boat.position-mob.position)*Vector3(1,0,1)).normalized()
	var gap: float = mob.position.distance_to(game.player.position)
	if player_swimming(game) and gap < SWIM_RANGE:
		return Vector3.ZERO if gap < SWIM_CLOSE else ((game.player.position-mob.position)*Vector3(1,0,1)).normalized()
	return Vector3.INF

# The vertical swim: straight up when air is low, toward a swimming companion or
# the treasure's depth otherwise. NAN leaves the shared swim alone.
static func lift(game: Node3D, mob: Node3D) -> float:
	if air(mob) < LOW_AIR: return 3.0
	if mob.has_meta("dolphin_treasure") and bool(mob.get_meta("dolphin_fed",false)):
		var chest: Vector3i = mob.get_meta("dolphin_treasure")
		return clampf((float(chest.y)+1.0-mob.position.y)*0.5,-2.0,2.0)
	if player_swimming(game) and mob.position.distance_to(game.player.position) < SWIM_RANGE:
		return clampf((game.player.position.y-mob.position.y)*0.5,-2.0,2.0)
	return NAN

# Air, moisture, the grace and the leap, once per step.
static func step(game: Node3D, mob: Node3D, delta: float, rng: RandomNumberGenerator) -> void:
	var world: VoxelWorld = game.world
	var wet: bool = in_water(world,mob) or Weather.exposed_to_rain(world,Vector3i(mob.position.floor()))
	var result: Array = breathe(air(mob),moisture(mob),head_under(world,mob),wet,delta)
	mob.set_meta("dolphin_air",result[0]); mob.set_meta("dolphin_moisture",result[1])
	var hurt: float = float(mob.get_meta("dolphin_hurt",0.0))+float(result[2])
	if hurt >= DRY_DAMAGE_INTERVAL:
		hurt -= DRY_DAMAGE_INTERVAL
		# Drowning and drying are not an attacker, so they must not provoke it.
		mob.health -= 1.0; mob.hurt_flash = 0.2
		if mob.health <= 0.0: mob.die(); return
	mob.set_meta("dolphin_hurt",hurt)
	if mob.is_queued_for_deletion() or mob.health <= 0: return
	if mob.has_meta("dolphin_leaping") and mob.velocity.y <= 0.0 and in_water(world,mob): mob.remove_meta("dolphin_leaping")
	var gap: float = mob.position.distance_to(game.player.position)
	if player_swimming(game) and gap < SWIM_RANGE and rng.randi_range(1,Bats.scale_chance(GRACE_ODDS,delta)) == 1:
		PotionEffects.apply(game.player,"dolphins_grace",GRACE_SECONDS,1)
	var clock: float = float(mob.get_meta("dolphin_jump",0.0))-delta
	if clock > 0.0: mob.set_meta("dolphin_jump",clock); return
	mob.set_meta("dolphin_jump",JUMP_INTERVAL)
	if rng.randi_range(1,Bats.scale_chance(JUMP_ODDS,JUMP_INTERVAL)) != 1: return
	var ahead: Vector3 = -mob.model.global_basis.z if mob.model != null else Vector3.FORWARD
	if can_leap(world,Vector3i(mob.position.floor()),ahead): leap(mob,ahead)

# `CLEARANCE_STEPS`: water ahead at one to three cells with two air cells above.
static func can_leap(world: VoxelWorld, cell: Vector3i, ahead: Vector3) -> bool:
	var dx: int = int(signf(roundf(ahead.x))) if absf(ahead.x) >= absf(ahead.z) else 0
	var dz: int = int(signf(roundf(ahead.z))) if absf(ahead.z) > absf(ahead.x) else 0
	if dx == 0 and dz == 0: return false
	for i in [1,2,3]:
		var water: Vector3i = cell+Vector3i(dx*i,0,dz*i)
		if not Fluids.water(world.node_at(water)): return false
		if world.node_at(water+Vector3i.UP) != Nodes.AIR or world.node_at(water+Vector3i.UP*2) != Nodes.AIR: return false
	return true

static func leap(mob: Node3D, ahead: Vector3) -> void:
	var flat := Vector3(ahead.x,0,ahead.z).normalized()
	mob.knock += flat*JUMP_PUSH
	mob.velocity.y += JUMP_LIFT
	mob.set_meta("dolphin_leaping",true)

# `build_retaliation_target_rule (ignore guardians, alert dolphins)`.
static func struck(game: Node3D, mob: Node3D, attacker: Node3D) -> void:
	if attacker is Creature and IGNORED_ATTACKERS.has(attacker.kind): return
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not is_dolphin(other.kind): continue
		if other.position.distance_to(mob.position) <= SWIM_RANGE:
			other.provoked = true; other.last_seen = other.life

static func aggressive(game: Node3D, mob: Node3D) -> bool:
	return mob.provoked and game.gamemode != "creative"

static func spawn_share() -> float: return float(OCEAN_WEIGHT)/float(OCEAN_WEIGHT+WATER_CREATURE_WEIGHT)

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("dolphins_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+2081
		world.set_meta("dolphins_rng",rng)
	return world.get_meta("dolphins_rng")

static func build(mob: Node3D) -> void:
	var grey := Color("7f98a8")
	var belly := Color("d8e0e4")
	mob._box(Vector3(0,0.3,0.05),Vector3(0.45,0.4,1.0),grey,"skin")
	mob._box(Vector3(0,0.18,0.05),Vector3(0.36,0.14,0.9),belly,"skin")
	mob.head = mob._joint(Vector3(0,0.32,-0.46),"Head")
	mob._box(Vector3(0,0.02,-0.12),Vector3(0.38,0.34,0.3),grey,"skin",mob.head)
	mob._box(Vector3(0,-0.06,-0.34),Vector3(0.14,0.1,0.18),belly,"skin",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.15,0.06,-0.27),Vector3(0.05,0.05,0.02),Color("1c2a33"),"",mob.head)
		var fin: Node3D = mob._joint(Vector3(side*0.23,0.2,-0.12),"Wing")
		mob._box(Vector3(side*0.12,-0.03,0.05),Vector3(0.24,0.04,0.16),grey.darkened(0.15),"skin",fin)
		mob.arms.append(fin)
	mob._box(Vector3(0,0.56,0.1),Vector3(0.06,0.22,0.2),grey.darkened(0.15),"skin")
	var tail: Node3D = mob._joint(Vector3(0,0.3,0.55),"Tail")
	mob._box(Vector3(0,0,0.18),Vector3(0.22,0.2,0.36),grey,"skin",tail)
	mob._box(Vector3(0,0,0.4),Vector3(0.5,0.05,0.14),grey.darkened(0.15),"skin",tail)
	tail.set_meta("tail",true)
