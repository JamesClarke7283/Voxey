class_name Parrots
extends RefCounted

# `mobs_mc:parrot` (ENTITIES/mobs_mc/parrot.lua).
#
# * 6 health, 1-2 feathers, 1-3 experience, no fall damage, five colours (blue,
#   green, grey, red-blue, yellow-blue).
# * Seeds tame a wild parrot at one in ten, each seed eaten (`feed_tame (clicker,
#   4, false, true, false, 0.1)`); parrots never breed. A cookie kills any parrot
#   outright and poisons it (97-116).
# * A tamed parrot follows its owner (chase 5, stop 1) and toggles sitting on the
#   owner's click. Coming within half a node of its standing owner, it perches on
#   a free shoulder, left first then right. It hops off when the owner is over
#   air or in water or lava, and waits a second before perching again (182-241).
# * Within three nodes of a playing jukebox it dances (298-327).
# * Every thirty seconds it imitates the nearest other mob within twenty, or at
#   one in twenty any mob's sound, at twice and a half the pitch (153-180).

const KIND = "parrot"
const COLOURS = ["blue","green","grey","red_blue","yellow_blue"]
const COLOUR_TINTS = {"blue":[Color("2f5fb8"),Color("e9e2c8")],"green":[Color("3f9a3a"),Color("e5d34a")],"grey":[Color("9aa0a6"),Color("d8d8d0")],"red_blue":[Color("c0392b"),Color("2b6ca3")],"yellow_blue":[Color("e0b92c"),Color("2b8fbf")]}
const SEEDS = [Nodes.SEEDS,VillageContent.BEETROOT_SEEDS,FruitCrops.PUMPKIN_SEEDS,FruitCrops.MELON_SEEDS]
const TAME_CHANCE = 0.1
const PERCH_RANGE = 0.5
const PERCH_COOLDOWN = 1.0
const FOLLOW = 5.0
const STOP = 1.0
const TELEPORT = 12.0
const DANCE_RANGE = 3.0
const IMITATE_INTERVAL = 30.0
const IMITATE_RANGE = 20.0
const IMITATE_WILD_ODDS = 20
const IMITATE_PITCH = 2.5
const SHOULDERS = {"left":Vector3(-0.3,1.45,0.0),"right":Vector3(0.3,1.45,0.0)}

static func is_parrot(kind: String) -> bool: return kind == KIND
static func tamed(mob: Node3D) -> bool: return bool(mob.get_meta("tamed",false))
static func owner(mob: Node3D) -> String: return str(mob.get_meta("owner",""))
static func sitting(mob: Node3D) -> bool: return tamed(mob) and bool(mob.get_meta("sitting",false))
static func colour(mob: Node3D) -> String: return str(mob.get_meta("parrot_colour","red_blue"))
static func perch(mob: Node3D) -> String: return str(mob.get_meta("perch",""))
static func keeps(mob: Node3D) -> bool: return is_parrot(mob.kind) and (tamed(mob) or not mob.custom_name.is_empty())
static func dancing(mob: Node3D) -> bool: return bool(mob.get_meta("dancing",false))

static func use(game: Node3D, mob: Node3D, rng: RandomNumberGenerator = null) -> bool:
	if rng == null: rng = Wolves.rng_for(game.world)
	var held: Dictionary = game.inventory.held()
	var id: int = int(held.id) if held.count > 0 else 0
	var creative: bool = game.gamemode == "creative"
	# A cookie is lethal to any parrot.
	if id == VillageContent.COOKIE:
		if not creative: game.inventory.consume_selected()
		PotionEffects.apply(mob,"poison",900.0,10)
		mob.hit(65535.0,game.player.position,"magic")
		return true
	if not tamed(mob) and SEEDS.has(id):
		if not creative: game.inventory.consume_selected()
		if rng.randf() <= TAME_CHANCE:
			mob.set_meta("tamed",true); mob.set_meta("owner",game.player_id)
			game.puff(mob.center()+Vector3.UP*0.2,Color("ef7c8f"),6,0.6)
			Farming.remember(mob)
		else: game.puff(mob.center()+Vector3.UP*0.2,Color("2b2b2b"),4,0.5)
		return true
	if tamed(mob) and owner(mob) == game.player_id:
		mob.set_meta("sitting",not sitting(mob))
		if sitting(mob): unperch(mob)
		Farming.remember(mob)
		return true
	return false

# `get_shoulder`: the left shoulder unless taken, then the right, else none.
static func free_shoulder(game: Node3D, ignoring: Node3D = null) -> String:
	var taken: Dictionary = {}
	for other in game.creatures.get_children():
		if other != ignoring and is_parrot(other.kind) and not other.is_queued_for_deletion() and not perch(other).is_empty(): taken[perch(other)] = true
	if not taken.has("left"): return "left"
	if not taken.has("right"): return "right"
	return ""

static func unperch(mob: Node3D) -> void:
	if perch(mob).is_empty(): return
	mob.set_meta("perch","")
	mob.set_meta("perch_cooldown",PERCH_COOLDOWN)

# `check_perch`'s drop-off test: the owner over air, or in water or lava.
static func must_leave(game: Node3D) -> bool:
	var world: VoxelWorld = game.world
	var feet: Vector3 = game.player.position
	var below: int = world.node_at(Vector3i((feet+Vector3.DOWN*0.6).floor()))
	var inside: int = world.node_at(Vector3i(feet.floor()))
	return below == Nodes.AIR or Fluids.liquid(inside)

static func step(game: Node3D, mob: Node3D, delta: float, rng: RandomNumberGenerator) -> bool:
	mob.set_meta("perch_cooldown",maxf(0.0,float(mob.get_meta("perch_cooldown",0.0))-delta))
	# Dancing beside a playing jukebox.
	var dance: bool = false
	for p in Jukeboxes.players(game.world):
		if mob.position.distance_to(Vector3(p)+Vector3(0.5,0.5,0.5)) <= DANCE_RANGE: dance = true
	mob.set_meta("dancing",dance)
	if dance and mob.model != null: mob.model.rotation.z = sin(mob.life*9.0)*0.35
	elif mob.model != null: mob.model.rotation.z = 0.0
	# Imitation.
	var clock: float = float(mob.get_meta("imitate_clock",0.0))+delta
	if clock >= IMITATE_INTERVAL:
		clock = 0.0
		imitate(game,mob,rng)
	mob.set_meta("imitate_clock",clock)
	# Perching.
	if not perch(mob).is_empty():
		if not tamed(mob) or owner(mob) != game.player_id or must_leave(game): unperch(mob); return false
		var offset: Vector3 = SHOULDERS[perch(mob)]
		mob.position = game.player.position+game.player.global_basis*offset
		mob.velocity = Vector3.ZERO
		mob.model.rotation.y = game.player.rotation.y
		return true
	if tamed(mob) and not sitting(mob) and owner(mob) == game.player_id and float(mob.get_meta("perch_cooldown",0.0)) <= 0.0:
		if mob.position.distance_to(game.player.position+Vector3.UP*1.0) < PERCH_RANGE+1.0 and not must_leave(game):
			var shoulder: String = free_shoulder(game,mob)
			if not shoulder.is_empty(): mob.set_meta("perch",shoulder); return true
	if tamed(mob) and not sitting(mob) and owner(mob) == game.player_id and mob.position.distance_to(game.player.position) > TELEPORT:
		Wolves.teleport_to_owner(game,mob,rng)
	return false

static func direction(game: Node3D, mob: Node3D) -> Vector3:
	if sitting(mob) or dancing(mob): return Vector3.ZERO
	if not tamed(mob) or owner(mob) != game.player_id: return Vector3.INF
	var gap: float = mob.position.distance_to(game.player.position)
	if gap > FOLLOW or (gap > STOP and mob.has_meta("parrot_travelling")):
		mob.set_meta("parrot_travelling",true)
		return ((game.player.position-mob.position)*Vector3(1,0,1)).normalized()
	if mob.has_meta("parrot_travelling"): mob.remove_meta("parrot_travelling")
	return Vector3.INF

# `imitate_mob_sound`: the nearest other mob's voice, or at one in twenty any
# mob's, at 2.5 pitch. Returns the kind whose voice was used, or "".
static func imitate(game: Node3D, mob: Node3D, rng: RandomNumberGenerator) -> String:
	var heard: String = ""
	for other in game.creatures.get_children():
		if other == mob or is_parrot(other.kind) or other.is_queued_for_deletion(): continue
		if other.position.distance_to(mob.position) > IMITATE_RANGE: continue
		heard = other.kind; break
	if heard.is_empty(): return ""
	var voice: String = str(Creature.KINDS.get(heard,{}).get("voice",""))
	if voice.is_empty() or rng.randi_range(1,IMITATE_WILD_ODDS) == 1:
		var voices: Array = []
		for kind in Creature.KINDS:
			if not str(Creature.KINDS[kind].get("voice","")).is_empty(): voices.append(kind)
		heard = voices[rng.randi_range(0,voices.size()-1)]
		voice = str(Creature.KINDS[heard].voice)
	game.sound_at(voice,mob.position,IMITATE_PITCH)
	return heard

static func snapshot(mob: Node3D) -> Dictionary:
	return {"tamed":tamed(mob),"owner":owner(mob),"sitting":sitting(mob),"colour":colour(mob)}

static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary: return
	var chosen: String = str(entry.get("colour",""))
	if COLOURS.has(chosen): set_colour(mob,chosen)
	mob.set_meta("tamed",bool(entry.get("tamed",false)))
	mob.set_meta("owner",str(entry.get("owner","")) if tamed(mob) else "")
	mob.set_meta("sitting",bool(entry.get("sitting",false)) and tamed(mob))

static func set_colour(mob: Node3D, chosen: String) -> void:
	if colour(mob) == chosen and mob.has_meta("parrot_colour"): return
	mob.set_meta("parrot_colour",chosen)
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	mob.merge_parts()

static func build(mob: Node3D) -> void:
	if not mob.has_meta("parrot_colour"): mob.set_meta("parrot_colour",COLOURS[randi_range(0,COLOURS.size()-1)])
	var tints: Array = COLOUR_TINTS.get(colour(mob),COLOUR_TINTS.red_blue)
	var body: Color = tints[0]; var wing_colour: Color = tints[1]
	mob._box(Vector3(0,0.5,0.03),Vector3(0.26,0.3,0.38),body,"feather")
	mob.head = mob._joint(Vector3(0,0.72,-0.16),"Head")
	mob._box(Vector3(0,0.04,0),Vector3(0.21,0.22,0.2),body.lightened(0.08),"feather",mob.head)
	mob._box(Vector3(0,0.03,-0.14),Vector3(0.1,0.1,0.09),Color("4a4a4a"),"",mob.head)
	mob._box(Vector3(0,-0.05,-0.15),Vector3(0.07,0.08,0.06),Color("3a3a3a"),"",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.1,0.08,-0.09),Vector3(0.045,0.045,0.02),Color("f2e9d8"),"",mob.head)
		mob._box(Vector3(side*0.055,0.07,-0.085),Vector3(0.02,0.02,0.012),Color("1c1c1c"),"",mob.head)
		var wing: Node3D = mob._joint(Vector3(side*0.15,0.62,0.02),"Wing")
		mob._box(Vector3(side*0.02,-0.08,0),Vector3(0.07,0.2,0.3),wing_colour,"feather",wing)
		mob.arms.append(wing)
		var leg: Node3D = mob._joint(Vector3(side*0.07,0.36,0.01),"Hip")
		mob._box(Vector3(0,-0.09,0),Vector3(0.04,0.18,0.04),Color("6f6f6f"),"",leg)
		for toe in [-1,0,1]: mob._box(Vector3(toe*0.032,-0.19,-0.05),Vector3(0.024,0.03,0.12),Color("6f6f6f"),"",leg)
		mob.legs.append(leg)
	for i in 3:
		mob._box(Vector3((i-1)*0.06,0.42,0.3),Vector3(0.065,0.26,0.08),wing_colour.darkened(0.2),"feather")
