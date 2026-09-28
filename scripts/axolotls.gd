class_name Axolotls
extends RefCounted

# `mobs_mc:axolotl` (ENTITIES/mobs_mc/axolotl.lua).
#
# * 14 health, 2 damage at reach 2, 1-7 experience, no drops, `can_despawn`. It
#   breathes in water and holds 300 seconds of air on land, then takes one damage
#   a second; rain keeps it wet.
# * Seven colours (`textures`, 38-46), one chosen at random when it appears.
# * Playing dead (190-208). When a sourced hit lands in water, at one in two, if
#   either `random(0, 2) < damage` or it is below half health, and the hit would
#   not kill it, it plays dead: ten seconds of regeneration I, during which it
#   lies still and no hunter targets it (`valid_enemy`).
# * Hunting (257-290). It always hunts guardians and elder guardians. It hunts
#   dolphins, cod, salmon, tropical fish, squid and glow squid unless it is on a
#   120-second cooldown, which a kill starts. A kill of a mob a player had struck,
#   with that player within 20, gives the player five more seconds of
#   regeneration I (up to 120) and clears their mining fatigue (210-240).
# * A bucket of tropical fish feeds and breeds it and leaves a water bucket
#   (60-86). A water bucket captures it as a bucket of axolotl that keeps its name
#   and colour.
# * Spawning (294-328): the lush caves, in water over clay, packs of four to six,
#   in its own `axolotl` category with a cap of five.

const KIND = "axolotl"
const COLOURS = ["brown","yellow","green","pink","black","purple","white"]
const COLOUR_TINTS = {"brown":Color("8d5f3e"),"yellow":Color("e5c75a"),"green":Color("7ea85a"),"pink":Color("e8a0b8"),"black":Color("3a3336"),"purple":Color("9a7ac8"),"white":Color("ece6e2")}
const MAX_AIR = 300.0
const PLAY_DEAD_SECONDS = 10.0
const HUNT_COOLDOWN = 120.0
const REWARD_RANGE = 20.0
const REWARD_SECONDS = 5.0
const REWARD_CAP = 120.0
const ENEMIES = ["guardian","guardian_elder"]
const PREY = ["dolphin","cod","salmon","tropical_fish","squid","glow_squid"]
const HUNT_RANGE = 16.0
const BUCKET = 11563
const DATA = {11563:{"name":"Bucket of axolotl","color":"e8a0b8","stack":1,"family":"fish_bucket"}}
const PACK_MIN = 4
const PACK_MAX = 6
const CAP = 5

static func is_axolotl(kind: String) -> bool: return kind == KIND
static func colour(mob: Node3D) -> String: return str(mob.get_meta("axolotl_colour","pink"))
static func playing_dead(mob: Node3D) -> bool: return float(mob.get_meta("axolotl_dead",0.0)) > 0.0
static func cooldown(mob: Node3D) -> float: return float(mob.get_meta("axolotl_cooldown",0.0))

static func pick_colour(rng: RandomNumberGenerator) -> String:
	return COLOURS[rng.randi_range(0,COLOURS.size()-1)]

# `axolotl:receive_damage`'s test, given its two rolls.
static func plays_dead(coin: int, roll: int, damage: float, health: float, max_health: float, in_water: bool, sourced: bool) -> bool:
	if coin != 1 or not in_water or not sourced: return false
	if damage >= health: return false
	return float(roll) < damage or health/max_health < 0.5

static func on_hurt(game: Node3D, mob: Node3D, damage: float, sourced: bool, rng: RandomNumberGenerator) -> void:
	if playing_dead(mob): return
	var wet: bool = Fluids.water(game.world.node_at(Vector3i(mob.position.floor())))
	if plays_dead(rng.randi_range(1,2),rng.randi_range(0,2),damage,mob.health,mob.info().health,wet,sourced):
		mob.set_meta("axolotl_dead",PLAY_DEAD_SECONDS)
		PotionEffects.apply(mob,"regeneration",PLAY_DEAD_SECONDS,1)

# The mob this axolotl hunts, or null: guardians always, prey off cooldown.
static func target(game: Node3D, mob: Node3D) -> Node3D:
	if playing_dead(mob): return null
	var best: Node3D = null
	var best_distance: float = HUNT_RANGE
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or other.health <= 0: continue
		var hunted: bool = ENEMIES.has(other.kind) or (PREY.has(other.kind) and cooldown(mob) <= 0.0)
		if not hunted or (is_axolotl(other.kind) and playing_dead(other)): continue
		var d: float = mob.position.distance_to(other.position)
		if d < best_distance: best = other; best_distance = d
	return best

# `track_current_target` when the target died: the cooldown, and the player's
# reward when the player had struck it and stands within twenty.
static func killed(game: Node3D, mob: Node3D, victim: Node3D) -> void:
	mob.set_meta("axolotl_cooldown",HUNT_COOLDOWN)
	if victim == null or not bool(victim.get_meta("player_struck",false)): return
	if game.player.position.distance_to(mob.position) >= REWARD_RANGE: return
	var left: float = float(game.survival.effects.get("regeneration",0.0))
	if left < REWARD_CAP: PotionEffects.apply(game.player,"regeneration",minf(REWARD_CAP,left+REWARD_SECONDS),1)
	PotionEffects.clear_one(game.player,"fatigue")

static func step(game: Node3D, mob: Node3D, delta: float) -> void:
	mob.set_meta("axolotl_dead",maxf(0.0,float(mob.get_meta("axolotl_dead",0.0))-delta))
	mob.set_meta("axolotl_cooldown",maxf(0.0,cooldown(mob)-delta))
	var cell := Vector3i(mob.position.floor())
	var wet: bool = Fluids.water(game.world.node_at(cell)) or Weather.exposed_to_rain(game.world,cell)
	var air: float = MAX_AIR if wet else maxf(0.0,float(mob.get_meta("axolotl_air",MAX_AIR))-delta)
	mob.set_meta("axolotl_air",air)
	if air <= 0.0:
		var clock: float = float(mob.get_meta("axolotl_dry",0.0))+delta
		if clock >= 1.0:
			clock -= 1.0
			mob.health -= 1.0; mob.hurt_flash = 0.2
			if mob.health <= 0.0: mob.set_meta("axolotl_dry",0.0); mob.die(); return
		mob.set_meta("axolotl_dry",clock)
	# Playing dead: it rolls onto its side and stops.
	if mob.model != null: mob.model.rotation.z = move_toward(mob.model.rotation.z,PI*0.5 if playing_dead(mob) else 0.0,delta*6.0)

# A bucket of tropical fish is its food; the source hands back a water bucket.
static func feed(game: Node3D, mob: Node3D) -> bool:
	var held: Dictionary = game.inventory.held()
	if int(held.id) != FishBuckets.TROPICAL_FISH_BUCKET or held.count <= 0: return false
	var consumed: bool = false
	if mob.health < mob.info().health: mob.health = minf(mob.info().health,mob.health+4.0); consumed = true
	elif mob.growth_remaining > 0: mob.growth_remaining *= 0.9; consumed = true
	elif mob.breed_cooldown <= 0 and mob.love_time <= 0: mob.love_time = Farming.LOVE_TIME; consumed = true
	if not consumed: return false
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		game.survival.give(Nodes.WATER_BUCKET,1)
	game.puff(mob.center(),Color("ef7c8f"),6,1.0)
	Farming.remember(mob)
	return true

static func capture(game: Node3D, mob: Node3D) -> bool:
	if mob == null or not is_axolotl(mob.kind) or mob.health <= 0: return false
	var held: Dictionary = game.inventory.held()
	if int(held.id) != Nodes.WATER_BUCKET or held.count <= 0: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	var data: Dictionary = {"colour":colour(mob)}
	if not mob.custom_name.is_empty(): data["name"] = NameTags.bounded(mob.custom_name,FishBuckets.NAME_LIMIT)
	game.survival.give(BUCKET,1,data)
	Farming.forget(mob)
	mob.queue_free()
	return true

# Released from its bucket: its colour back, and persistent like a released fish.
static func released(mob: Node3D, stack: Dictionary) -> void:
	var data: Dictionary = stack.get("data",{})
	var saved: String = str(data.get("colour",""))
	if COLOURS.has(saved): set_colour(mob,saved)
	mob.set_meta("persistent",true)

# A colour is baked into the merged body, so a different colour rebuilds it.
static func set_colour(mob: Node3D, chosen: String) -> void:
	if colour(mob) == chosen and mob.has_meta("axolotl_colour"): return
	mob.set_meta("axolotl_colour",chosen)
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	mob.merge_parts()
	CreatureArt.farm_age(mob,mob.growth_remaining > 0)

static func spawn_allowed(world: VoxelWorld, cell: Vector3i) -> bool:
	if world.dimension != "overworld" or world.open_sky(cell): return false
	if not Fluids.water(world.node_at(cell)): return false
	# The source requires clay; Voxey's lush caves carry moss instead of clay
	# pools, so a moss floor also qualifies.
	return world.node_at(cell+Vector3i.DOWN) in [Nodes.CLAY,LushCaves.MOSS]

static func build(mob: Node3D) -> void:
	if not mob.has_meta("axolotl_colour"): mob.set_meta("axolotl_colour",pick_colour(rng_for_colour()))
	var skin: Color = COLOUR_TINTS.get(colour(mob),COLOUR_TINTS.pink)
	var gill: Color = skin.darkened(0.3)
	mob._box(Vector3(0,0.2,0.05),Vector3(0.36,0.24,0.6),skin,"skin")
	mob.head = mob._joint(Vector3(0,0.24,-0.3),"Head")
	mob._box(Vector3(0,0,-0.1),Vector3(0.42,0.26,0.26),skin,"skin",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.12,0.05,-0.235),Vector3(0.05,0.05,0.02),Color("1a1616"),"",mob.head)
		# Three feathery gills on each side, the axolotl's whole silhouette.
		for i in 3: mob._box(Vector3(side*0.26,0.1-i*0.08,-0.05),Vector3(0.1,0.04,0.04),gill,"",mob.head)
		for z in [-0.15,0.2]:
			var leg: Node3D = mob._joint(Vector3(side*0.2,0.12,z),"Hip")
			mob._box(Vector3(side*0.05,-0.06,0),Vector3(0.1,0.1,0.08),skin,"skin",leg)
			mob.legs.append(leg)
	var tail: Node3D = mob._joint(Vector3(0,0.22,0.35),"Tail")
	mob._box(Vector3(0,0,0.2),Vector3(0.06,0.2,0.42),skin.lightened(0.1),"skin",tail)
	tail.set_meta("tail",true)

static var colour_rng: RandomNumberGenerator = null
static func rng_for_colour() -> RandomNumberGenerator:
	if colour_rng == null:
		colour_rng = RandomNumberGenerator.new(); colour_rng.randomize()
	return colour_rng

static func count_near(game: Node3D) -> int:
	var count: int = 0
	for mob in game.creatures.get_children():
		if is_axolotl(mob.kind) and not mob.is_queued_for_deletion() and mob.position.distance_to(game.player.position) <= 128: count += 1
	return count

# A pack of four to six in the water around `near`, stopped by the cap.
static func spawn_pack(game: Node3D, near: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var room: int = CAP-count_near(game)
	if room <= 0: return made
	var size: int = mini(rng.randi_range(PACK_MIN,PACK_MAX),room)
	for attempt in 24:
		if made.size() >= size: break
		var cell := Vector3i(near.floor())+Vector3i(rng.randi_range(-6,6),rng.randi_range(-3,3),rng.randi_range(-6,6))
		if not game.world.loaded_at(Vector3(cell)) or not spawn_allowed(game.world,cell): continue
		var mob: Node3D = game.spawn_creature(KIND,Vector3(cell)+Vector3(0.5,0.05,0.5))
		if mob != null: made.append(mob)
	return made
