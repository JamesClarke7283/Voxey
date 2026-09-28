class_name Llamas
extends RefCounted

# The llama (ENTITIES/mobs_mc/llama.lua) and the llama half of the trader llama
# (wandering_trader.lua:562-678). A llama is `table.merge (horse, ...)`, so the
# wild one joins the horse family (`Equines`) for its temper taming, food, chest,
# breeding and persistence. This module holds what is only a llama's.
#
# * Statistics (97-150). Health is the horse's `15 + random(0, 8) + random(0, 9)`.
#   Strength is `1 + random(0, max_bonus - 1)`, where `max_bonus` is 5 at a 4%
#   chance and otherwise 3. The chest holds strength × 3 slots, which is what the
#   source's window draws (`list[...;strength,3;]`).
# * Food (66-80). Wheat heals 2, ages 10 ticks and adds 3 temper; a hay bale heals
#   10, ages 90 ticks, adds 6 temper and breeds. `_max_temper` is 30, so a llama
#   tames far sooner than a horse. It follows a player holding a hay bale.
# * Decor (161-195). A tamed llama's saddle slot takes a carpet, which it wears
#   as its decor. It cannot be steered (`should_drive` is false).
# * Breeding (99-125). Only a tamed llama breeds. The cria takes one parent's
#   owner and a strength of `random(1, max(s1, s2))`, plus one at 5% up to five.
# * Spit (200-222, 369-409). Struck, a llama spits once at its attacker within
#   forty, on the source's four-second ranged timer, then calls the attack off.
#   It spits at any untamed wolf within ten until the wolf is gone. Spit flies at
#   40 under gravity and deals 1.
# * Caravans (224-352). A llama that is not leashed joins the nearest llama
#   within nine that is leashed, or that trails a caravan with at most seven ahead
#   of it. It walks after the one ahead beyond three, and gives up beyond 26 once
#   its speed-up runs out. A caravan comes apart from the front when the lead is
#   released.
# * Wolves (wolf.lua:72-75, 823-828) run from a llama when its strength beats
#   `random(0, 4)`.
# * Spawning (486-507). Packs of four to six in the hills at weight 5. Voxey's
#   Frostpine highlands stand for the hills; there is no savannah.

const KIND = "llama"
const TRADER = "trader_llama"
const KINDS = [KIND,TRADER]
const MAX_TEMPER = 30
# `_food_items`: heal, age in ticks, temper, breeds.
const FOOD = {
	Nodes.GRAIN:[2.0,10,3,false],
	Nodes.HAY_BALE:[10.0,90,6,true],
}
const FOLLOW = [Nodes.HAY_BALE]
# The four named coats plus `mobs_mc_llama.png`, which is the creamy coat again.
const COATS = ["brown","creamy","gray","white","creamy"]
const COAT_NAMES = ["brown","creamy","gray","white"]
const COAT_COLOURS = {"brown":Color("875a2a"),"creamy":Color("e3d2b2"),"gray":Color("b6b5b1"),"white":Color("ecebdc")}
const STRENGTH_MAX = 5
const STRONG_CHANCE = 0.04
const BONUS_CHANCE = 0.05
const SLOTS_PER_STRENGTH = 3
# `ranged_interval_min`/`max`, `ranged_attack_radius`, `tracking_distance` and
# `shoot_offset`.
const RANGED_INTERVAL = 4.0
const ATTACK_RADIUS = 20.0
const TRACKING = 40.0
const WOLF_RANGE = TRACKING*0.25
const SEEK_INTERVAL = 0.5
const SIGHT_DELAY = 0.25
# `track_current_target`'s persistence: fifteen seconds unseen for an attacker,
# and the source's `SIGHT_PERSISTENCE` of three for a wolf.
const RETALIATE_PERSISTENCE = 15.0
const WOLF_PERSISTENCE = 3.0
const RUNAWAY_TIME = 5.0
const SHOOT_HEIGHT = 1.6
const SPIT_SPEED = 40.0
const SPIT_DAMAGE = 1.0
const SPIT_GRAVITY = 9.81
const SPIT_LIFE = 5.0
const SPIT_RADIUS = 0.15625
# `follow_caravan`.
const CARAVAN_JOIN_RADIUS = 9.0
const CARAVAN_MAX_AHEAD = 7
const CARAVAN_CLOSE = 3.0
const CARAVAN_FAR = 26.0
const CARAVAN_SPEED = 2.1
const CARAVAN_SPEED_MAX = 3.0
const CARAVAN_SPEED_STEP = 1.2
const CARAVAN_TIMEOUT = 2.0
const CARAVAN_CHECK = 0.3
# How long a wolf keeps running from a llama once it has decided to: the source
# holds the decision until its escape path finishes.
const WOLF_AVOID_TIME = 2.0
# `llama_spawner`: weight 5 beside the hills' farm animals, packs of four to six.
const WEIGHT = 5
const HIGHLAND = "Frostpine highlands"
const HIGHLAND_ANIMALS = 40
const PACK_MIN = 4
const PACK_MAX = 6

static func is_llama(kind: String) -> bool: return KINDS.has(kind)
static func strength(mob: Node3D) -> int: return clampi(int(mob.get_meta("llama_strength",1)),1,STRENGTH_MAX)
static func coat(mob: Node3D) -> String: return str(mob.get_meta("llama_coat","creamy"))
static func carpet(mob: Node3D) -> int: return int(mob.get_meta("llama_carpet",0))
static func chest_slots(mob: Node3D) -> int: return strength(mob)*SLOTS_PER_STRENGTH
static func is_carpet(id: int) -> bool:
	return VillageContent.DATA.has(id) and str(VillageContent.DATA[id].get("family","")) == "carpet"

# --- the statistics -------------------------------------------------------------

# `initial_movement_properties`: `chance < 0.04 and 5 or 3`.
static func roll_strength(chance: float, roll: int) -> int:
	var max_bonus: int = 5 if chance < STRONG_CHANCE else 3
	return 1+clampi(roll,0,max_bonus-1)

# `on_spawn` for both kinds: the strength and one of the five coat textures.
static func initialize(mob: Node3D, rng: RandomNumberGenerator) -> void:
	if mob.has_meta("llama_strength"): return
	var chance: float = rng.randf()
	mob.set_meta("llama_strength",roll_strength(chance,rng.randi_range(0,(5 if chance < STRONG_CHANCE else 3)-1)))
	mob.set_meta("llama_coat",COATS[rng.randi_range(0,COATS.size()-1)])

# `llama:on_breed`: `random(1, max(s1, s2))`, plus one at 5% while under five.
static func child_strength(s1: int, s2: int, roll: int, bonus: float) -> int:
	var value: int = clampi(roll,1,maxi(s1,s2))
	if bonus < BONUS_CHANCE and value < STRENGTH_MAX: value += 1
	return value

static func make_cria(game: Node3D, a: Node3D, b: Node3D, rng: RandomNumberGenerator) -> Node3D:
	var parent: Node3D = a if rng.randi_range(1,2) == 1 else b
	var cria: Node3D = game.spawn_creature(KIND,a.position)
	if cria == null: return null
	# The source copies the parent's owner but not its tamed flag.
	if parent.has_meta("owner"): cria.set_meta("owner",str(parent.get_meta("owner")))
	cria.set_meta("llama_strength",child_strength(strength(a),strength(b),rng.randi_range(1,maxi(strength(a),strength(b))),rng.randf()))
	cria.growth_remaining = Equines.GROW_TIME
	Farming.resize(cria)
	cria.set_meta("persistent",true)
	XpOrbs.throw_xp(game,cria.center(),rng.randi_range(1,7))
	return cria

# --- decor ------------------------------------------------------------------------

# `horse:set_saddle` with `llama:is_saddle_item`: a carpet goes on only while the
# slot is empty.
static func set_carpet(mob: Node3D, id: int) -> bool:
	if not is_carpet(id) or carpet(mob) != 0: return false
	mob.set_meta("llama_carpet",id)
	draw_carpet(mob)
	return true

static func remove_carpet(mob: Node3D) -> int:
	var id: int = carpet(mob)
	if id == 0: return 0
	mob.remove_meta("llama_carpet")
	for part in mob.parts:
		if is_instance_valid(part) and part.has_meta("llama_carpet_part"): part.visible = false
	return id

# --- the click ----------------------------------------------------------------------

# The owner's click on a tamed adult: a carpet, or shears to take it back.
# Returns true when the click was used.
static func decorate(game: Node3D, mob: Node3D, id: int) -> bool:
	if mob.kind != KIND or not Equines.tamed(mob) or mob.growth_remaining > 0.0 or game.survival.mount == mob: return false
	var creative: bool = game.gamemode == "creative"
	if is_carpet(id) and set_carpet(mob,id):
		if not creative: game.inventory.consume_selected()
		game.sound("equip")
		return true
	if id == Nodes.SHEARS and carpet(mob) != 0:
		var removed: int = remove_carpet(mob)
		if not creative:
			game.spawn_drop(mob.position+Vector3.UP,removed)
			game.inventory.damage_tool()
		return true
	return false

# --- spitting -------------------------------------------------------------------------

static func node_of(id: int) -> Node3D:
	if id == 0 or not is_instance_id_valid(id): return null
	var other: Object = instance_from_id(id)
	if not other is Node3D or other.is_queued_for_deletion(): return null
	return other

static func target(mob: Node3D) -> Node3D: return node_of(int(mob.get_meta("llama_target",0)))
static func rule(mob: Node3D) -> String: return str(mob.get_meta("llama_rule",""))
static func has_spit(mob: Node3D) -> bool: return bool(mob.get_meta("llama_has_spit",false))

static func eye(game: Node3D, other: Node3D) -> Vector3:
	if other == game.player: return game.player.position+Vector3.UP*1.5
	return other.position+Vector3.UP*float(other.height)*0.85

# Called from `RuralAnimal.hit` with the blow's origin: the source's
# `read_last_attacker`.
static func struck(game: Node3D, mob: Node3D, from: Vector3) -> void:
	mob.set_meta("llama_hit_at",mob.life)
	if is_inf(from.x): return
	var attacker: Node3D = GuardianAuras.attacker_at(game,from,mob)
	if attacker != null: mob.set_meta("llama_attacker",attacker.get_instance_id())

static func attack_allowed(game: Node3D, other: Node3D) -> bool:
	if other == game.player: return game.gamemode != "creative" and game.player.health > 0
	return other is Creature and not other.is_queued_for_deletion() and other.health > 0

static func begin(mob: Node3D, other: Node3D, kind: String) -> void:
	mob.set_meta("llama_target",other.get_instance_id())
	mob.set_meta("llama_rule",kind)
	mob.set_meta("llama_shoot",RANGED_INTERVAL)
	mob.set_meta("llama_seen",0.0)
	mob.set_meta("llama_unseen",RETALIATE_PERSISTENCE if kind == "retaliate" else WOLF_PERSISTENCE)
	mob.set_meta("llama_has_spit",false)

static func end_attack(mob: Node3D) -> void:
	var was: String = rule(mob)
	for key in ["llama_target","llama_rule","llama_shoot","llama_seen","llama_unseen","llama_has_spit"]:
		if mob.has_meta(key): mob.remove_meta(key)
	# `check_frightened` follows `check_attack`: a llama still inside the source's
	# five-second `runaway_timer` flees for what is left of it.
	if was == "retaliate":
		var left: float = RUNAWAY_TIME-(mob.life-float(mob.get_meta("llama_hit_at",-INF)))
		if left > 0.0: mob.scared = left

# The nearest untamed wolf within ten that the llama can see.
static func nearest_wolf(game: Node3D, mob: Node3D) -> Node3D:
	var best: Node3D = null
	var best_distance: float = WOLF_RANGE
	for other in game.creatures.get_children():
		if not Wolves.is_wolf(other.kind) or other.is_queued_for_deletion() or Wolves.tamed(other): continue
		var d: float = mob.position.distance_to(other.position)
		if d > best_distance or not mob._sees(eye(game,other)): continue
		best = other; best_distance = d
	return best

# `track_current_target`: out of range, or unseen past the persistence.
static func keeps(game: Node3D, mob: Node3D, other: Node3D, delta: float) -> bool:
	if other == null or not attack_allowed(game,other): return false
	var reach: float = TRACKING if rule(mob) == "retaliate" else WOLF_RANGE
	if mob.position.distance_to(other.position) > reach: return false
	if mob._sees(eye(game,other)):
		mob.set_meta("llama_unseen",RETALIATE_PERSISTENCE if rule(mob) == "retaliate" else WOLF_PERSISTENCE)
		return true
	var left: float = float(mob.get_meta("llama_unseen",0.0))
	mob.set_meta("llama_unseen",left-delta)
	return left >= 0.0

# The source's `_targeting_rules`, in order: retaliation, then untamed wolves.
static func targeting_step(game: Node3D, mob: Node3D, delta: float) -> void:
	# A player's arrow or blow marks the mob after `hit`, so it is read here.
	if bool(mob.get_meta("player_struck",false)):
		mob.remove_meta("player_struck")
		mob.set_meta("llama_attacker",game.player.get_instance_id())
	var attacker: Node3D = node_of(int(mob.get_meta("llama_attacker",0)))
	if mob.has_meta("llama_attacker"): mob.remove_meta("llama_attacker")
	var current: Node3D = target(mob)
	if current != null and rule(mob) == "retaliate" and has_spit(mob): end_attack(mob); current = null
	if attacker != null and attacker != current and attacker != mob and attack_allowed(game,attacker) and mob.position.distance_to(attacker.position) < TRACKING:
		begin(mob,attacker,"retaliate")
		return
	if current != null:
		if not keeps(game,mob,current,delta): end_attack(mob)
		return
	if mob.has_meta("llama_target"): end_attack(mob)
	var clock: float = float(mob.get_meta("llama_seek",0.0))-delta
	if clock > 0.0: mob.set_meta("llama_seek",clock); return
	mob.set_meta("llama_seek",SEEK_INTERVAL)
	var wolf: Node3D = nearest_wolf(game,mob)
	if wolf != null: begin(mob,wolf,"wolf")

# `attack_ranged`: close to within twenty and in sight for a quarter second,
# then spit when the four-second timer runs out.
static func attack_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	var other: Node3D = target(mob)
	if other == null: return null
	var sees: bool = mob._sees(eye(game,other))
	mob.set_meta("llama_seen",float(mob.get_meta("llama_seen",0.0))+delta if sees else 0.0)
	var to: Vector3 = (other.position-mob.position)*Vector3(1,0,1)
	if to.length() > 0.01 and mob.model != null: mob.model.rotation.y = lerp_angle(mob.model.rotation.y,atan2(-to.x,-to.z),minf(1.0,delta*5.0))
	var shoot: float = maxf(0.0,float(mob.get_meta("llama_shoot",RANGED_INTERVAL))-delta)
	if shoot > 0.0:
		mob.set_meta("llama_shoot",shoot)
		return null
	mob.set_meta("llama_shoot",RANGED_INTERVAL)
	if not sees: return null
	var spit: Node3D = discharge(game,mob,eye(game,other))
	if rule(mob) == "retaliate": mob.set_meta("llama_has_spit",true)
	return spit

# `llama:discharge_ranged`: aimed at the eyes, lifted by 0.04 of the distance.
static func aim(from: Vector3, to: Vector3) -> Vector3:
	var vec: Vector3 = to-from
	vec.y += 0.04*vec.length()
	return vec.normalized()

static func discharge(game: Node3D, mob: Node3D, at: Vector3) -> Node3D:
	var origin: Vector3 = mob.position+Vector3.UP*SHOOT_HEIGHT
	var heading: Vector3 = aim(origin,at)
	var spit := Spit.new()
	spit.game = game
	spit.shooter = mob
	spit.position = origin
	spit.velocity = heading*SPIT_SPEED
	game.entities.add_child(spit)
	game.sound_at("arrow",origin,1.8)
	return spit

# `mobs_mc:llama_spit`: a small gob that falls under gravity, stops at the first
# node, and deals one to the first player or mob it meets other than its shooter.
class Spit extends Node3D:
	var game: Node3D
	var shooter: Node3D
	var velocity := Vector3.ZERO
	var life: float = 0.0

	func _ready() -> void:
		RedstoneArt.box(self,Vector3.ZERO,Vector3.ONE*0.2,Color("e8f6ff"))
		RedstoneArt.box(self,Vector3(0.06,0.05,0.04),Vector3.ONE*0.1,Color("c5c5c5"))

	func _physics_process(delta: float) -> void:
		if not game.playing(): return
		life += delta
		if life > Llamas.SPIT_LIFE: queue_free(); return
		velocity.y -= Llamas.SPIT_GRAVITY*delta
		var motion: Vector3 = velocity*delta
		var steps: int = maxi(1,ceili(motion.length()/0.1))
		for step in steps:
			var next: Vector3 = position+motion/steps
			if game.world.intersects(next-Vector3.UP*Llamas.SPIT_RADIUS,Llamas.SPIT_RADIUS,Llamas.SPIT_RADIUS*2.0):
				game.puff(position,Color("e8f6ff"),4,0.4)
				queue_free()
				return
			position = next
			if hit_something(): return

	func hit_something() -> bool:
		var from: Vector3 = shooter.position if is_instance_valid(shooter) else position-velocity
		if position.distance_to(game.player.position+Vector3.UP*0.9) < 0.7:
			game.player.hurt(Llamas.SPIT_DAMAGE,false,from,"projectile")
			if is_instance_valid(shooter): Wolves.record_player_hurt(game,shooter)
			game.puff(position,Color("e8f6ff"),6,0.5)
			queue_free()
			return true
		for mob in game.creatures.get_children():
			if mob == shooter or mob.is_queued_for_deletion(): continue
			if position.distance_to(mob.center()) >= maxf(0.55,mob.width+0.2): continue
			mob.hit(Llamas.SPIT_DAMAGE,from)
			game.puff(position,Color("e8f6ff"),6,0.5)
			queue_free()
			return true
		return false

# --- caravans ---------------------------------------------------------------------------

# `is_leashed`: the source leaves this for when leashes exist. Voxey has leads, so
# a llama on a lead leads a caravan; a trader llama is led by its trader.
static func leashed(game: Node3D, mob: Node3D) -> bool:
	if mob is WanderingTraders.LlamaMob and mob.linked(): return true
	return mob is Creature and game.leads.attached(mob)

static func head(mob: Node3D) -> Node3D:
	var other: Node3D = node_of(int(mob.get_meta("caravan_head",0)))
	return other if other != null and is_llama(other.kind) else null

static func tail(mob: Node3D) -> Node3D:
	var other: Node3D = node_of(int(mob.get_meta("caravan_tail",0)))
	return other if other != null and is_llama(other.kind) else null

static func join(mob: Node3D, ahead: Node3D) -> void:
	mob.set_meta("caravan_head",ahead.get_instance_id())
	ahead.set_meta("caravan_tail",mob.get_instance_id())
	mob.set_meta("caravan_timeout",0.0)
	mob.set_meta("caravan_speed",CARAVAN_SPEED)

static func leave(mob: Node3D) -> void:
	var ahead: Node3D = head(mob)
	if ahead != null and ahead.has_meta("caravan_tail"): ahead.remove_meta("caravan_tail")
	for key in ["caravan_head","caravan_timeout","caravan_speed"]:
		if mob.has_meta(key): mob.remove_meta(key)

# `check_caravan`: forget a vanished neighbour, and release the one behind once
# this llama is neither following nor leashed.
static func check(game: Node3D, mob: Node3D) -> void:
	if mob.has_meta("caravan_head") and head(mob) == null: mob.remove_meta("caravan_head")
	if mob.has_meta("caravan_tail") and tail(mob) == null: mob.remove_meta("caravan_tail")
	if not mob.has_meta("caravan_head") and not leashed(game,mob) and mob.has_meta("caravan_tail"):
		var behind: Node3D = tail(mob)
		mob.remove_meta("caravan_tail")
		if behind != null and behind.has_meta("caravan_head"): behind.remove_meta("caravan_head")

static func count_ahead(mob: Node3D) -> int:
	var n: int = 0
	var ahead: Node3D = head(mob)
	while ahead != null and n < 64:
		n += 1
		ahead = head(ahead)
	return n

static func caravan_step(game: Node3D, mob: Node3D, delta: float) -> void:
	check(game,mob)
	# A llama put on a lead leaves the line it was in and leads its own.
	if leashed(game,mob) and mob.has_meta("caravan_head"): leave(mob)
	var ahead: Node3D = head(mob)
	if ahead != null:
		var gap: float = mob.position.distance_to(ahead.position)
		var factor: float = float(mob.get_meta("caravan_speed",CARAVAN_SPEED))
		var timeout: float = float(mob.get_meta("caravan_timeout",0.0))
		if gap > CARAVAN_FAR:
			if factor < CARAVAN_SPEED_MAX:
				factor *= CARAVAN_SPEED_STEP
				mob.set_meta("caravan_speed",factor)
				timeout = CARAVAN_TIMEOUT
			if timeout == 0.0:
				leave(mob)
				return
		mob.set_meta("caravan_timeout",maxf(0.0,timeout-delta))
		return
	if leashed(game,mob): return
	var clock: float = float(mob.get_meta("caravan_clock",0.0))-delta
	if clock > 0.0: mob.set_meta("caravan_clock",clock); return
	mob.set_meta("caravan_clock",CARAVAN_CHECK)
	var straggler: Node3D = null
	var led: Node3D = null
	var d1: float = INF
	var d2: float = INF
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or not is_llama(other.kind): continue
		var d: float = other.position.distance_to(mob.position)
		if d > CARAVAN_JOIN_RADIUS or tail(other) != null: continue
		if head(other) != null and d < d1: straggler = other; d1 = d
		if leashed(game,other) and d < d2: led = other; d2 = d
	# The source punts as soon as the nearest straggler is too far down its line.
	if straggler != null:
		if count_ahead(straggler) > CARAVAN_MAX_AHEAD: return
		join(mob,straggler)
		return
	if led != null: join(mob,led)

static func caravan_direction(mob: Node3D) -> Vector3:
	var ahead: Node3D = head(mob)
	if ahead == null: return Vector3.INF
	if mob.position.distance_to(ahead.position) <= CARAVAN_CLOSE: return Vector3.ZERO
	return ((ahead.position-mob.position)*Vector3(1,0,1)).normalized()*float(mob.get_meta("caravan_speed",CARAVAN_SPEED))

# --- the step and the heading ---------------------------------------------------------------

static func step(game: Node3D, mob: Node3D, delta: float) -> void:
	caravan_step(game,mob,delta)
	targeting_step(game,mob,delta)
	attack_step(game,mob,delta)

# The source's `ai_functions` order: the caravan, the attack, fleeing, then
# following a hay bale. INF leaves the shared wander in charge.
static func direction(game: Node3D, mob: Node3D) -> Vector3:
	var along: Vector3 = caravan_direction(mob)
	if along != Vector3.INF: return along
	var other: Node3D = target(mob)
	if other != null:
		var gap: float = mob.position.distance_to(other.position)
		if gap < ATTACK_RADIUS and float(mob.get_meta("llama_seen",0.0)) > SIGHT_DELAY: return Vector3.ZERO
		return ((other.position-mob.position)*Vector3(1,0,1)).normalized()
	if mob.scared > 0: return Vector3.INF
	return Equines.follow_direction(game,mob)

# `wolf:should_runaway_from_mob`: strength against `random(0, 4)`, held while
# the wolf runs.
static func frightens(wolf: Node3D, llama: Node3D, rng: RandomNumberGenerator) -> bool:
	if int(wolf.get_meta("avoiding_llama",0)) == llama.get_instance_id() and float(wolf.get_meta("avoid_until",-INF)) > wolf.life: return true
	if strength(llama) < rng.randi_range(0,4): return false
	wolf.set_meta("avoiding_llama",llama.get_instance_id())
	wolf.set_meta("avoid_until",wolf.life+WOLF_AVOID_TIME)
	return true

# --- persistence -------------------------------------------------------------------------

static func snapshot(mob: Node3D) -> Dictionary:
	return {"strength":strength(mob),"coat":coat(mob),"carpet":carpet(mob)}

static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary or entry.is_empty(): return
	mob.set_meta("llama_strength",clampi(int(entry.get("strength",1)),1,STRENGTH_MAX))
	var saved_coat: String = str(entry.get("coat",""))
	if COAT_NAMES.has(saved_coat): mob.set_meta("llama_coat",saved_coat)
	var saved_carpet: int = int(entry.get("carpet",0))
	if mob.has_meta("llama_carpet"): mob.remove_meta("llama_carpet")
	if is_carpet(saved_carpet): mob.set_meta("llama_carpet",saved_carpet)
	refresh(mob)

# --- spawning -----------------------------------------------------------------------------

static func spawn_share(biome: String) -> float:
	if biome != HIGHLAND: return 0.0
	return float(WEIGHT)/float(WEIGHT+HIGHLAND_ANIMALS)

static func spawn_pack(game: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var size: int = rng.randi_range(PACK_MIN,PACK_MAX)
	for i in size:
		var at: Vector3 = pos+(Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3)) if i > 0 else Vector3.ZERO)
		if i > 0 and game.world.intersects(at,0.5,1.9): continue
		var mob: Node3D = game.spawn_creature(KIND,at)
		if mob != null: made.append(mob)
	return made

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("llamas_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+4127
		world.set_meta("llamas_rng",rng)
	return world.get_meta("llamas_rng")

# --- art --------------------------------------------------------------------------------------

# Rebuild the body after the coat, carpet or chest changed from outside a click.
static func refresh(mob: Node3D) -> void:
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	mob.merge_parts()
	CreatureArt.farm_age(mob,mob.growth_remaining > 0)

static func build(mob: Node3D) -> void:
	var fur: Color = COAT_COLOURS.get(coat(mob),COAT_COLOURS.creamy)
	var dark: Color = fur.darkened(0.16)
	var hoof := Color("3a2c1d")
	mob._box(Vector3(0,1.0,0.1),Vector3(0.62,0.6,1.05),fur,"fur")
	mob._box(Vector3(0,1.42,-0.34),Vector3(0.3,0.72,0.34),fur,"fur")
	mob.head = mob._joint(Vector3(0,1.8,-0.44),"Head")
	mob._box(Vector3(0,-0.06,-0.13),Vector3(0.34,0.4,0.5),fur,"fur",mob.head)
	mob._box(Vector3(0,-0.14,-0.36),Vector3(0.3,0.24,0.2),fur.lightened(0.12),"fur",mob.head)
	for side in [-1,1]:
		mob._box(Vector3(side*0.1,0.26,0.02),Vector3(0.08,0.3,0.1),dark,"fur",mob.head)
		mob._box(Vector3(side*0.14,0.06,-0.2),Vector3(0.045,0.06,0.03),Color("2b2a26"),"",mob.head)
		for z in [-0.36,0.44]:
			var leg: Node3D = mob._joint(Vector3(side*0.22,0.8,z),"Hip")
			mob._box(Vector3(0,-0.34,0),Vector3(0.16,0.68,0.19),dark,"fur",leg)
			mob._box(Vector3(0,-0.74,-0.015),Vector3(0.18,0.14,0.22),hoof,"",leg)
			mob.legs.append(leg)
	mob._box(Vector3(0,0.82,0.72),Vector3(0.14,0.66,0.13),dark,"fur")
	# `mobs_mc_llama_decor_wandering_trader`: the trader's blue and gold blanket
	# and its pack.
	if mob.kind == TRADER:
		mob._box(Vector3(0,1.34,0.06),Vector3(0.66,0.12,0.72),Color("3d5fa8"),"cloth")
		mob._box(Vector3(0,1.345,0.06),Vector3(0.68,0.1,0.2),Color("e8c070"),"cloth")
		mob._box(Vector3(0,1.05,-0.12),Vector3(0.5,0.42,0.5),Color("6d4f34"),"cloth")
	if carpet(mob) != 0: draw_carpet(mob)
	if mob.has_meta("equine_chest"): draw_chest(mob)

static func draw_carpet(mob: Node3D) -> void:
	var tint := Color(str(VillageContent.DATA.get(carpet(mob),{}).get("color","e4e4d7")))
	var blanket: MeshInstance3D = mob._box(Vector3(0,1.34,0.06),Vector3(0.66,0.12,0.72),tint,"cloth")
	blanket.set_meta("llama_carpet_part",true)
	var fringe: MeshInstance3D = mob._box(Vector3(0,1.12,0.06),Vector3(0.68,0.3,0.6),tint.darkened(0.12),"cloth")
	fringe.set_meta("llama_carpet_part",true)

static func draw_chest(mob: Node3D) -> void:
	for side in [-1,1]:
		var bag: MeshInstance3D = mob._box(Vector3(side*0.4,1.02,0.3),Vector3(0.18,0.4,0.4),Color("7a5431"),"wood")
		bag.set_meta("equine_chest_box",true)
