class_name Cats
extends RefCounted

# `mobs_mc:cat` (ENTITIES/mobs_mc/ocelot.lua, 400-1110).
#
# * 10 health, 0-2 string, 1-3 experience. It despawns once 120 seconds old
#   unless tamed, fed or named. Creepers keep away from cats (creeper.lua:27).
# * Coats (404-437): ten ordinary coats; a witch hut's cat is all black; under
#   a full moon the all-black coat joins the ten.
# * Taming (918-990). Raw cod or salmon tames a wild cat at one in three; either
#   way the fish is eaten and the cat becomes persistent. A new pet sits.
# * A tamed cat, right-clicked by its owner:
#   - a dye recolours its collar;
#   - fish heals it by the fish's food value, or breeds it at full health;
#   - otherwise the click toggles sitting.
# * Following (`check_travel_to_owner`, chase 10, stop 5): as the wolf's rules,
#   teleporting beyond twelve.
# * Sleeping (545-610, 521-543). A standing tamed cat within ten of its owner
#   lies on the owner's bed while they sleep. At the wake, if the time is 0.25 to
#   0.30 of the day, it leaves a gift at seven in ten: rabbit hide, a rabbit's
#   foot, raw chicken, a feather, rotten flesh or string, each weighted 10.
# * Resting (611-770): an idle tamed cat sits on a bed within 3 or a chest or
#   furnace within 4, for up to 60 seconds.
# * A wild cat hunts rabbits (798-804).
# * Spawning (1000-1101): every sixty seconds, in a village with at least five
#   homes and no more than four cats within 48, and in a witch hut.

const KIND = "cat"
const COATS = ["black","british_shorthair","calico","jellie","persian","ragdoll","red","siamese","tabby","white"]
const ALL_BLACK = "all_black"
const COAT_COLOURS = {"black":[Color("2c2a2e"),Color("f0f0f0")],"british_shorthair":[Color("8b9097"),Color("a9adb3")],"calico":[Color("e9e1d5"),Color("c47b3a")],"jellie":[Color("5d6066"),Color("e8e6e0")],"persian":[Color("e0c79a"),Color("f3e6c8")],"ragdoll":[Color("efe7da"),Color("7b6a5c")],"red":[Color("d98a45"),Color("f0c690")],"siamese":[Color("ece0cc"),Color("4f3c30")],"tabby":[Color("8a6a48"),Color("5a4430")],"white":[Color("f2f1ee"),Color("dcdad4")],"all_black":[Color("1c1b1e"),Color("1c1b1e")]}
const FOODS = {VillageContent.RAW_COD:2,VillageContent.RAW_SALMON:2}
const TAME_ODDS = 3
const GIFT_CHANCE = 0.7
const GIFT_WINDOW = Vector2(0.25,0.30)
const GIFTS = [VillageContent.RABBIT_HIDE,VillageContent.RABBIT_FOOT,VillageContent.RAW_CHICKEN,Nodes.FEATHER,Nodes.ROTTEN_FLESH,Nodes.STRING]
const SLEEP_RANGE = 10.0
const FOLLOW = 10.0
const STOP = 5.0
const TELEPORT = 12.0
const REST_SECONDS = 60.0
const BED_SEARCH = Vector3i(3,1,3)
const BLOCK_SEARCH = Vector3i(4,1,4)
const SPAWN_INTERVAL = 60.0
const VILLAGE_HOMES = 5
const VILLAGE_CATS = 4
const VILLAGE_RANGE = 48.0
const DESPAWN_AGE = 120.0
const PREY = ["rabbit"]

static func is_cat(kind: String) -> bool: return kind == KIND
static func tamed(mob: Node3D) -> bool: return bool(mob.get_meta("tamed",false))
static func owner(mob: Node3D) -> String: return str(mob.get_meta("owner",""))
static func sitting(mob: Node3D) -> bool: return tamed(mob) and bool(mob.get_meta("sitting",false))
static func coat(mob: Node3D) -> String: return str(mob.get_meta("cat_coat","tabby"))
static func collar(mob: Node3D) -> String: return str(mob.get_meta("collar",Wolves.DEFAULT_COLLAR))
# A cat worth keeping: tamed, fed or named; the rest despawn.
static func keeps(mob: Node3D) -> bool:
	return is_cat(mob.kind) and (tamed(mob) or mob.has_meta("persistent") or not mob.custom_name.is_empty())

static func coats_for(witch_hut: bool, full_moon: bool) -> Array:
	if witch_hut: return [ALL_BLACK]
	return [ALL_BLACK]+COATS if full_moon else COATS

static func pick_coat(rng: RandomNumberGenerator, witch_hut: bool, full_moon: bool) -> String:
	var pool: Array = coats_for(witch_hut,full_moon)
	return pool[rng.randi_range(0,pool.size()-1)]

# --- taming and orders -----------------------------------------------------------

static func use(game: Node3D, mob: Node3D, rng: RandomNumberGenerator = null) -> bool:
	if rng == null: rng = Wolves.rng_for(game.world)
	var held: Dictionary = game.inventory.held()
	var id: int = int(held.id) if held.count > 0 else 0
	var creative: bool = game.gamemode == "creative"
	if tamed(mob) and owner(mob) == game.player_id:
		var dye: String = Wolves.dye_name(id)
		if not dye.is_empty():
			mob.set_meta("collar",Wolves.collar_for(dye))
			if not creative: game.inventory.consume_selected()
			refresh(mob); Farming.remember(mob)
			return true
		if FOODS.has(id):
			if mob.health < mob.info().health:
				mob.health = minf(mob.info().health,mob.health+float(FOODS[id]))
				if not creative: game.inventory.consume_selected()
				Farming.remember(mob)
				return true
			if not sitting(mob) and mob.growth_remaining <= 0.0 and mob.love_time <= 0.0 and mob.breed_cooldown <= 0.0:
				mob.love_time = Farming.LOVE_TIME
				if not creative: game.inventory.consume_selected()
				game.puff(mob.center(),Color("ef7c8f"),6,1.0)
				Farming.remember(mob)
				return true
		mob.set_meta("sitting",not sitting(mob))
		mob.direction = Vector3.ZERO
		refresh(mob); Farming.remember(mob)
		return true
	if not tamed(mob) and FOODS.has(id):
		if not creative: game.inventory.consume_selected()
		# Feeding a wild cat keeps it, tamed or not.
		mob.set_meta("persistent",true)
		if rng.randi_range(1,TAME_ODDS) == 1:
			mob.set_meta("tamed",true); mob.set_meta("owner",game.player_id); mob.set_meta("sitting",true)
			game.puff(mob.center()+Vector3.UP*0.3,Color("ef7c8f"),8,0.8)
		else:
			game.puff(mob.center()+Vector3.UP*0.3,Color("2b2b2b"),5,0.6)
		refresh(mob); Farming.remember(mob)
		return true
	return false

# --- movement ---------------------------------------------------------------------------

static func direction(game: Node3D, mob: Node3D) -> Vector3:
	if sitting(mob): return Vector3.ZERO
	if not tamed(mob) or owner(mob) != game.player_id: return Vector3.INF
	if mob.has_meta("cat_rest"):
		var spot: Vector3i = mob.get_meta("cat_rest")
		var gap: Vector3 = Vector3(spot)+Vector3(0.5,0,0.5)-mob.position
		if Vector2(gap.x,gap.z).length() < 0.7: return Vector3.ZERO
		return (gap*Vector3(1,0,1)).normalized()
	var distance: float = mob.position.distance_to(game.player.position)
	if distance > FOLLOW or (distance > STOP and mob.has_meta("cat_travelling")):
		mob.set_meta("cat_travelling",true)
		return ((game.player.position-mob.position)*Vector3(1,0,1)).normalized()
	if mob.has_meta("cat_travelling"): mob.remove_meta("cat_travelling")
	return Vector3.INF

# A wild cat's prey: the nearest rabbit it can see.
static func target(game: Node3D, mob: Node3D) -> Node3D:
	if tamed(mob): return null
	var best: Node3D = null
	var best_distance: float = 16.0
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not PREY.has(other.kind): continue
		var d: float = mob.position.distance_to(other.position)
		if d < best_distance and mob._sees(other.center()): best = other; best_distance = d
	return best

static func resting_block(id: int) -> bool:
	return VillageContent.is_bed(id) or id == Nodes.CHEST or id == Nodes.FURNACE

# `cat_sit_on_bed` and `cat_sit_on_block`: a free bed, chest or furnace nearby.
static func find_rest(world: VoxelWorld, here: Vector3i) -> Vector3i:
	var best := Vector3i.MAX
	var best_distance: float = INF
	for y in range(-1,2):
		for z in range(-BLOCK_SEARCH.z,BLOCK_SEARCH.z+1):
			for x in range(-BLOCK_SEARCH.x,BLOCK_SEARCH.x+1):
				var cell: Vector3i = here+Vector3i(x,y,z)
				var id: int = world.node_at(cell)
				if not resting_block(id): continue
				if VillageContent.is_bed(id) and (absi(x) > BED_SEARCH.x or absi(z) > BED_SEARCH.z): continue
				if Nodes.solid(world.node_at(cell+Vector3i.UP)): continue
				var d: float = Vector3(cell).distance_to(Vector3(here))
				if d < best_distance: best = cell+Vector3i.UP; best_distance = d
	return best

static func step(game: Node3D, mob: Node3D, delta: float) -> void:
	mob.set_meta("cat_age",float(mob.get_meta("cat_age",0.0))+delta)
	if not tamed(mob) or owner(mob) != game.player_id: return
	if not sitting(mob) and mob.position.distance_to(game.player.position) > TELEPORT:
		Wolves.teleport_to_owner(game,mob,Wolves.rng_for(game.world))
	# Resting on a bed, chest or furnace.
	var clock: float = float(mob.get_meta("cat_rest_clock",0.0))+delta
	mob.set_meta("cat_rest_clock",clock)
	if mob.has_meta("cat_rest"):
		var spot: Vector3i = mob.get_meta("cat_rest")
		if not resting_block(game.world.node_at(spot+Vector3i.DOWN)) or clock > REST_SECONDS:
			mob.remove_meta("cat_rest"); mob.set_meta("cat_rest_clock",0.0)
	elif clock > 2.0 and not sitting(mob):
		mob.set_meta("cat_rest_clock",0.0)
		var spot: Vector3i = find_rest(game.world,Vector3i(mob.position.floor()))
		if spot != Vector3i.MAX: mob.set_meta("cat_rest",spot)

# --- the owner's sleep -----------------------------------------------------------------------

# Called when the owner sleeps: every standing tamed cat within ten lies down on
# the bed, and when the night is skipped each may leave a gift.
static func owner_slept(game: Node3D, bed: Vector3i, rng: RandomNumberGenerator) -> Array:
	var gifts: Array = []
	for mob in game.creatures.get_children():
		if not is_cat(mob.kind) or mob.is_queued_for_deletion() or not tamed(mob) or sitting(mob): continue
		if owner(mob) != game.player_id or mob.position.distance_to(game.player.position) > SLEEP_RANGE: continue
		mob.position = Vector3(bed)+Vector3(0.5,0.6,0.5)
		var gift: int = wake_gift(fposmod(game.day_time,1.0),rng)
		if gift != 0:
			var drop: Node3D = game.spawn_drop(mob.position+Vector3.UP*0.3,gift)
			if drop != null: gifts.append(gift)
	return gifts

# `give_wakeup_gift`: in the dawn window, seven in ten, one weighted draw.
static func wake_gift(time_of_day: float, rng: RandomNumberGenerator) -> int:
	if time_of_day < GIFT_WINDOW.x or time_of_day > GIFT_WINDOW.y: return 0
	if rng.randf() >= GIFT_CHANCE: return 0
	return GIFTS[rng.randi_range(0,GIFTS.size()-1)]

# --- breeding and spawning -------------------------------------------------------------------

static func breed_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	mob.breed_cooldown = maxf(0.0,mob.breed_cooldown-delta)
	mob.love_time = maxf(0.0,mob.love_time-delta)
	if mob.love_time <= 0.0 or mob.growth_remaining > 0.0 or sitting(mob): return null
	for other in game.creatures.get_children():
		if other == mob or not is_cat(other.kind) or other.love_time <= 0.0 or other.growth_remaining > 0.0: continue
		if other.position.distance_to(mob.position) > 8.0 or mob.get_instance_id() > other.get_instance_id(): continue
		var together: float = float(mob.get_meta("mate_time",0.0))+delta
		mob.set_meta("mate_time",together)
		if together < Farming.BREED_TIME: return null
		mob.set_meta("mate_time",0.0)
		for parent in [mob,other]: parent.love_time = 0.0; parent.breed_cooldown = Farming.COOLDOWN
		var kitten: Node3D = game.spawn_creature(KIND,mob.position)
		if kitten == null: return null
		var source: Node3D = mob if randi_range(1,2) == 1 else other
		set_coat(kitten,coat(source))
		kitten.set_meta("collar",collar(source)); kitten.set_meta("tamed",true); kitten.set_meta("owner",owner(mob))
		kitten.set_meta("persistent",true)
		kitten.growth_remaining = Farming.GROW_TIME; Farming.resize(kitten)
		refresh(kitten); Farming.remember(kitten)
		XpOrbs.throw_xp(game,kitten.center(),randi_range(1,7))
		return kitten
	return null

# The village rule: at least five homes and at most four cats within 48.
static func village_allows(homes: int, cats: int) -> bool: return homes >= VILLAGE_HOMES and cats <= VILLAGE_CATS

static func count_near(game: Node3D, pos: Vector3) -> int:
	var count: int = 0
	for mob in game.creatures.get_children():
		if is_cat(mob.kind) and not mob.is_queued_for_deletion() and mob.position.distance_to(pos) <= VILLAGE_RANGE: count += 1
	return count

# The homes (`is_home` points of interest) within 48: Voxey's villages have a
# bed in each of their thirteen homes at fixed places.
static func homes_near(game: Node3D, pos: Vector3) -> int:
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,pos)
	if village.is_empty(): return 0
	var homes: int = 0
	for i in VillageGenerator.HOMES.size():
		if Vector3(VillageGenerator.bed(village,i)).distance_to(pos) <= VILLAGE_RANGE: homes += 1
	return homes

static func spawn_step(game: Node3D, delta: float, rng: RandomNumberGenerator) -> Node3D:
	var clock: float = float(game.world.get_meta("cat_spawn_clock",0.0))+delta
	if clock < SPAWN_INTERVAL: game.world.set_meta("cat_spawn_clock",clock); return null
	game.world.set_meta("cat_spawn_clock",0.0)
	if game.dimension != "overworld": return null
	var dx: int = rng.randi_range(8,31)*(1 if rng.randi_range(0,1) == 0 else -1)
	var dz: int = rng.randi_range(8,31)*(1 if rng.randi_range(0,1) == 0 else -1)
	var at: Vector3 = game.player.position+Vector3(dx,0,dz)
	if not game.world.loaded_at(at): return null
	if not village_allows(homes_near(game,at),count_near(game,at)): return null
	var ground: Vector3 = game._safe_spawn(at)
	if is_inf(ground.x): return null
	return game.spawn_creature(KIND,ground)

# --- persistence ----------------------------------------------------------------------------------

static func snapshot(mob: Node3D) -> Dictionary:
	return {"tamed":tamed(mob),"owner":owner(mob),"sitting":sitting(mob),"collar":collar(mob),"coat":coat(mob)}

static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary: return
	var chosen: String = str(entry.get("coat",""))
	if COAT_COLOURS.has(chosen): set_coat(mob,chosen)
	mob.set_meta("tamed",bool(entry.get("tamed",false)))
	mob.set_meta("owner",str(entry.get("owner","")) if tamed(mob) else "")
	mob.set_meta("sitting",bool(entry.get("sitting",false)) and tamed(mob))
	var colour: String = str(entry.get("collar",Wolves.DEFAULT_COLLAR))
	mob.set_meta("collar",colour if Wolves.COLLARS.values().has(colour) else Wolves.DEFAULT_COLLAR)
	refresh(mob)

# --- art ---------------------------------------------------------------------------------------------

static func set_coat(mob: Node3D, chosen: String) -> void:
	if coat(mob) == chosen and mob.has_meta("cat_coat"): return
	mob.set_meta("cat_coat",chosen)
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	mob.merge_parts()
	CreatureArt.farm_age(mob,mob.growth_remaining > 0)
	refresh(mob)

static func build(mob: Node3D) -> void:
	var colours: Array = COAT_COLOURS.get(coat(mob),COAT_COLOURS.tabby)
	var fur: Color = colours[0]; var patch: Color = colours[1]
	mob._box(Vector3(0,0.3,0),Vector3(0.28,0.24,0.55),fur,"fur")
	mob._box(Vector3(0,0.24,-0.05),Vector3(0.22,0.06,0.4),patch,"fur")
	mob.head = mob._joint(Vector3(0,0.42,-0.3),"Head")
	mob._box(Vector3(0,0.02,0),Vector3(0.24,0.22,0.22),fur,"fur",mob.head)
	mob._box(Vector3(0,-0.04,-0.12),Vector3(0.12,0.08,0.04),patch,"fur",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.08,0.17,0.02),Vector3(0.07,0.09,0.05),fur.darkened(0.15),"fur",mob.head)
		mob._box(Vector3(side*0.07,0.02,-0.12),Vector3(0.045,0.035,0.02),Color("c9d16a"),"",mob.head)
		for z in [-0.18,0.18]:
			var leg: Node3D = mob._joint(Vector3(side*0.09,0.18,z),"Hip")
			mob._box(Vector3(0,-0.09,0),Vector3(0.06,0.18,0.06),fur,"fur",leg)
			mob.legs.append(leg)
	var tail: Node3D = mob._joint(Vector3(0,0.36,0.28),"Tail")
	tail.rotation.x = -0.9
	mob._box(Vector3(0,0.1,0),Vector3(0.05,0.26,0.05),fur.darkened(0.1),"fur",tail)
	var band: MeshInstance3D = mob._box(Vector3(0,0.42,-0.2),Vector3(0.26,0.05,0.1),Color(Wolves.DEFAULT_COLLAR),"cloth")
	band.set_meta("cat_collar",true)

static func refresh(mob: Node3D) -> void:
	for i in mob.parts.size():
		var part: Variant = mob.parts[i]
		if not is_instance_valid(part) or not part.has_meta("cat_collar"): continue
		part.visible = tamed(mob)
		var base := Color(collar(mob))
		if i < mob.colors.size() and mob.colors[i] != base:
			mob.colors[i] = base; part.material_override.albedo_color = base; mob.tint_applied = []
	if mob.model != null: mob.model.rotation.x = -0.35 if sitting(mob) or mob.has_meta("cat_resting") else 0.0
