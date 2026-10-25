class_name BiomeFauna
extends RefCounted

# The source's biome-only missing creatures:
# * `cow+mooshroom.lua`: a mooshroom spawner in `MushroomIslands`, weight 8,
#   packs of four to eight, on mycelium.
# * `ocelot.lua`: infrequent jungle ocelots on grass or leaves, one to three
#   in `Jungle` and one in `BambooJungle`; a trusting ocelot breeds, and its
#   offspring is a cat.
const MOOSHROOM = "mooshroom"
const OCELOT = "ocelot"
const MOOSHROOM_BIOME = "MushroomIslands"
const MOOSHROOM_WEIGHT = 8
const MOOSHROOM_PACK_MIN = 4
const MOOSHROOM_PACK_MAX = 8
const OCELOT_ODDS = 3
const JUNGLE_PACK_MAX = 3
const BAMBOO_PACK_MAX = 1
const TRUST_ODDS = 3
const FOLLOW = 6.0
const STOP = 2.0
# `ocelot.lua`'s `runaway_view_range`, shared by its `runaway_from = players`.
const FLEE_RANGE = 8.0
const FOODS = [VillageContent.RAW_COD,VillageContent.RAW_SALMON]

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("biome_fauna_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+4241
		world.set_meta("biome_fauna_rng",rng)
	return world.get_meta("biome_fauna_rng")

static func is_ocelot(kind: String) -> bool: return kind == OCELOT
static func trusts(mob: Node3D) -> bool: return bool(mob.get_meta("ocelot_trusts",false))
static func following(mob: Node3D) -> bool: return bool(mob.get_meta("ocelot_following",false))
static func gains_trust(rng: RandomNumberGenerator) -> bool: return rng.randi_range(1,TRUST_ODDS) == 1

# A mooshroom is the only creature spawner in its source biome, so a valid
# mushroom-island pick always selects it.
static func mooshroom_share(biome: String) -> float:
	return 1.0 if biome == MOOSHROOM_BIOME else 0.0

static func mooshroom_allowed(world: VoxelWorld, cell: Vector3i) -> bool:
	if world.dimension != "overworld" or BiomeMap.canonical(world.generator.biome(cell.x,cell.z)) != MOOSHROOM_BIOME: return false
	var below: int = world.node_at(cell+Vector3i.DOWN)
	if below not in [SoilVariants.MYCELIUM,SoilVariants.SNOWY_MYCELIUM]: return false
	if Pasture.light(world,cell,9) < 9: return false
	return not world.intersects(Vector3(cell)+Vector3(0.5,0.01,0.5),0.5,1.35)

static func spawn_mooshrooms(game: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var count: int = rng.randi_range(MOOSHROOM_PACK_MIN,MOOSHROOM_PACK_MAX)
	for i in count:
		var at: Vector3 = pos+(Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3)) if i > 0 else Vector3.ZERO)
		var cell := Vector3i(at.floor())
		if not mooshroom_allowed(game.world,cell): continue
		var mob: Creature = game.spawn_creature(MOOSHROOM,Vector3(cell)+Vector3(0.5,0.01,0.5))
		if mob != null: made.append(mob)
	return made

# `ocelot_spawner`: weight 2 among monsters, one-in-three position test, and a
# floor of grass or leaves. The pack size depends on the two source spawners.
static func ocelot_biome(biome: String) -> bool:
	return biome == "Jungle" or biome == "BambooJungle"

static func ocelot_pack_max(biome: String) -> int:
	return BAMBOO_PACK_MAX if biome == "BambooJungle" else JUNGLE_PACK_MAX

static func ocelot_allowed(world: VoxelWorld, cell: Vector3i, roll: float) -> bool:
	if world.dimension != "overworld" or cell.y < 0 or roll >= 1.0/float(OCELOT_ODDS): return false
	var below: int = world.node_at(cell+Vector3i.DOWN)
	if not (Pasture.is_grass(below) or WoodTypes.is_leaves(below)): return false
	return not world.intersects(Vector3(cell)+Vector3(0.5,0.01,0.5),0.3,0.7)

static func spawn_ocelots(game: Node3D, pos: Vector3, biome: String, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	for i in rng.randi_range(1,ocelot_pack_max(biome)):
		var at: Vector3 = pos+(Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2)) if i > 0 else Vector3.ZERO)
		var cell := Vector3i(at.floor())
		if not ocelot_allowed(game.world,cell,rng.randf()): continue
		var mob: Creature = game.spawn_creature(OCELOT,Vector3(cell)+Vector3(0.5,0.01,0.5))
		if mob != null: made.append(mob)
	return made

# Only a trusting, shy ocelot that has followed a fish-holding player can gain
# trust. The fish is consumed on every attempt and one in three succeeds.
static func use_ocelot(game: Node3D, mob: Creature, rng: RandomNumberGenerator) -> bool:
	if not is_ocelot(mob.kind): return false
	var held: Dictionary = game.inventory.held()
	if int(held.get("count",0)) <= 0 or not FOODS.has(int(held.id)): return false
	if trusts(mob):
		if mob.health < mob.info().health:
			mob.health = minf(mob.info().health,mob.health+2.0)
		elif mob.growth_remaining <= 0.0 and mob.love_time <= 0.0 and mob.breed_cooldown <= 0.0:
			mob.love_time = Farming.LOVE_TIME
		else: return true
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.puff(mob.center(),Color("ef7c8f"),4,0.9)
		Farming.remember(mob)
		return true
	if not following(mob) or mob.position.distance_to(game.player.position) >= 9.0: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	mob.set_meta("persistent",true)
	if gains_trust(rng):
		mob.set_meta("ocelot_trusts",true)
		game.puff(mob.center()+Vector3.UP*0.4,Color("ef7c8f"),6,0.9)
	else:
		game.puff(mob.center()+Vector3.UP*0.4,Color("2b2b2b"),4,0.6)
	Farming.remember(mob)
	return true

# The shy follow: a player holding fish within six and beyond three gets
# followed until they look or move abruptly. Voxey has no head-pitch signal at
# this distance, so movement and distance are the available conditions.
static func direction(game: Node3D, mob: Node3D) -> Vector3:
	if not is_ocelot(mob.kind) or trusts(mob): return Vector3.INF
	var held: int = game.inventory.held().id
	if not FOODS.has(held): mob.set_meta("ocelot_following",false); return Vector3.INF
	var gap: Vector3 = game.player.position-mob.position
	var distance: float = gap.length()
	if distance < STOP or distance > FOLLOW: mob.set_meta("ocelot_following",false); return Vector3.INF
	mob.set_meta("ocelot_following",true)
	return (gap*Vector3(1,0,1)).normalized()

# Trusted ocelots breed like cats; their child is a cat with one parent's coat.
static func breed_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	mob.breed_cooldown = maxf(0.0,mob.breed_cooldown-delta)
	mob.love_time = maxf(0.0,mob.love_time-delta)
	if mob.kind != OCELOT or not trusts(mob) or mob.love_time <= 0.0 or mob.growth_remaining > 0.0: return null
	for other in game.creatures.get_children():
		if other == mob or not is_ocelot(other.kind) or not trusts(other) or other.love_time <= 0.0 or other.growth_remaining > 0.0: continue
		if other.position.distance_to(mob.position) > 8.0 or mob.get_instance_id() > other.get_instance_id(): continue
		var together: float = float(mob.get_meta("mate_time",0.0))+delta
		mob.set_meta("mate_time",together)
		if together < Farming.BREED_TIME: return null
		mob.set_meta("mate_time",0.0)
		for parent in [mob,other]: parent.love_time = 0.0; parent.breed_cooldown = Farming.COOLDOWN
		var cat: Creature = game.spawn_creature(Cats.KIND,mob.position)
		if cat == null: return null
		var source: Node3D = mob if randi_range(1,2) == 1 else other
		Cats.set_coat(cat,Cats.COATS[randi_range(0,Cats.COATS.size()-1)])
		cat.set_meta("tamed",true); cat.set_meta("owner",game.player_id); cat.set_meta("persistent",true)
		Cats.refresh(cat); Farming.remember(cat)
		XpOrbs.throw_xp(game,cat.center(),randi_range(1,7))
		return cat
	return null

static func managed(mob: Creature) -> bool:
	return mob.kind == OCELOT and (trusts(mob) or mob.has_meta("persistent") or not mob.custom_name.is_empty())

static func snapshot(mob: Node3D) -> Dictionary:
	return {"trusts":trusts(mob),"following":following(mob)}

static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary: return
	mob.set_meta("ocelot_trusts",bool(entry.get("trusts",false)))
	mob.set_meta("ocelot_following",false)
	if trusts(mob): mob.set_meta("persistent",true)

# `ocelot.lua`'s `_targeting_rules`: a nearest chicken. A trusting ocelot still
# has the rule in the source; the trust affects avoidance and breeding, not prey.
static func target(game: Node3D, mob: Node3D) -> Node3D:
	var best: Node3D = null
	var best_distance: float = 12.0
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or other.kind != "chicken": continue
		var d: float = mob.position.distance_to(other.position)
		if d < best_distance and mob._sees(other.center()): best = other; best_distance = d
	return best

static func build_ocelot(mob: Node3D) -> void:
	var fur := Color("d8a94f"); var dark := Color("604f36"); var cream := Color("efe2bd")
	mob._box(Vector3(0,0.3,0),Vector3(0.28,0.24,0.55),fur,"fur")
	mob._box(Vector3(0,0.25,-0.04),Vector3(0.2,0.06,0.4),cream,"fur")
	mob.head = mob._joint(Vector3(0,0.42,-0.3),"Head")
	mob._box(Vector3(0,0.02,0),Vector3(0.24,0.22,0.22),fur,"fur",mob.head)
	mob._box(Vector3(0,-0.04,-0.12),Vector3(0.12,0.08,0.04),cream,"fur",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.08,0.17,0.02),Vector3(0.07,0.09,0.05),dark,"fur",mob.head)
		mob._box(Vector3(side*0.07,0.02,-0.12),Vector3(0.045,0.035,0.02),Color("c9d16a"),"",mob.head)
		for z in [-0.18,0.18]:
			var leg: Node3D = mob._joint(Vector3(side*0.09,0.18,z),"Hip")
			mob._box(Vector3(0,-0.09,0),Vector3(0.06,0.18,0.06),fur,"fur",leg)
			mob.legs.append(leg)
	var tail: Node3D = mob._joint(Vector3(0,0.36,0.28),"Tail")
	tail.rotation.x = -0.9
	mob._box(Vector3(0,0.1,0),Vector3(0.05,0.26,0.05),fur,"fur",tail)
	mob._box(Vector3(0,0.25,0),Vector3(0.055,0.06,0.055),dark,"fur",tail)
