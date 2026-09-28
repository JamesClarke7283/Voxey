class_name Equines
extends RefCounted

# The horse family (ENTITIES/mobs_mc/horse.lua): the horse, the donkey, the mule,
# and the skeleton and zombie horses, plus the skeleton trap that
# ENVIRONMENT/mcl_lightning/init.lua spawns.
#
# * Every horse is its own animal (950-1033). Health is
#   `15 + random(0, 8) + random(0, 9)`. Jump strength is
#   `(0.4 + 3 × 0.2 × random) × 20`, so 8 to 20. Speed is
#   `(0.45 + 3 × 0.3 × random) × 20 × 0.25`, so 2.25 to 6.75. A donkey or mule
#   rolls only its health; its speed is 3.5 and its jump 10. A foal takes the
#   source's `child_properties` blend of its parents.
# * The coat is one of seven bases with one of five markings (33-63). A foal
#   takes one parent's coat, with a one-in-nine mutation of each part.
# * Taming (236-282). Mounting an untamed horse with an empty hand starts the
#   evaluation; on average every 2.5 seconds it rolls `random(1, 120) <=
#   temper + 1`. Success tames it to the rider. Failure adds 5 to its temper
#   and throws the rider off. Food adds temper as well (98-135):
#
#   | Food | Heal | Age (ticks) | Temper | Breeds |
#   | --- | --- | --- | --- | --- |
#   | wheat | 2 | 20 | 3 | |
#   | sugar | 1 | 30 | 3 | |
#   | hay bale | 2 | 20 | 3 | |
#   | apple | 3 | 60 | 3 | |
#   | golden carrot | 4 | 60 | 5 | yes |
#   | golden apple | 10 | 240 | 10 | yes |
#
# * A tamed horse takes a saddle and horse armour. Armour sets the share of
#   fleshy damage it takes: leather 88, copper 86, iron 85, gold 60, diamond 56.
#   Donkeys and mules take no armour, but carry a 15-slot chest instead. Shears
#   take the armour back first, then the saddle.
# * Breeding (1041-1085, 1339-1350): tamed horses and donkeys breed on golden
#   food. Horse and horse makes a horse, donkey and donkey a donkey, and horse and
#   donkey a mule; mules never breed.
# * Skeleton trap (lightning init.lua:160-176, horse.lua:1095-1230). A strike
#   onto open air spawns a trap horse at `regional difficulty × 0.01`. A player
#   within ten sets it off: lightning, three more tamed skeleton horses, and a
#   skeleton rider on each. An unsprung trap leaves after 900 seconds.
# * Spawning (1365-1411): horses in packs of two to six in the plains at weight
#   5, donkeys alone at weight 1 in the meadow. Voxey's meadow stands for both.
#
# Recorded deviations. Voxey keeps its fixed-name `trust` field as the tamed
# flag, three meaning tamed, so existing saves and leads keep working. Ride speed
# and jump are the source's statistics scaled so that an average horse keeps
# Voxey's old feel: speed × 8 / 4.5 and jump × 9.5 / 14. The trap's riders carry
# no enchanted helmet, because Voxey's mobs wear no armour.

const HORSE = "horse"
const DONKEY = "donkey"
const MULE = "mule"
const SKELETON = "skeleton_horse"
const ZOMBIE = "zombie_horse"
const KINDS = [HORSE,DONKEY,MULE,SKELETON,ZOMBIE]
const UNDEAD_KINDS = [SKELETON,ZOMBIE]
const TAMED_TRUST = 3
const MAX_TEMPER = 120
const BUCK_TEMPER = 5
const EVALUATE_TICKS = 50
const TICK = 0.05
const BASES = ["brown","darkbrown","white","gray","black","chestnut","creamy"]
const BASE_COLOURS = {"brown":Color("8a5a36"),"darkbrown":Color("4e3322"),"white":Color("e6e2da"),"gray":Color("8d8a86"),"black":Color("2c2724"),"chestnut":Color("a4583a"),"creamy":Color("d3b389")}
const MARKINGS = ["","whitedots","blackdots","whitefield","white"]
const MUTATE_ODDS = 9
# `_food_items`: heal, age in ticks, temper, breeds.
const FOOD = {
	Nodes.GRAIN:[2.0,20,3,false],
	Nodes.SUGAR:[1.0,30,3,false],
	Nodes.HAY_BALE:[2.0,20,3,false],
	Nodes.APPLE:[3.0,60,3,false],
	VillageContent.GOLDEN_CARROT:[4.0,60,5,true],
	Nodes.GOLDEN_APPLE:[10.0,240,10,true],
}
# The horse armour items and the percentage of fleshy damage they let through.
const COPPER_ARMOR = 11564
const IRON_ARMOR = 11565
const GOLD_ARMOR = 11566
const DIAMOND_ARMOR = 11567
const ARMOR = {
	VillageContent.LEATHER_HORSE_ARMOR:88,COPPER_ARMOR:86,IRON_ARMOR:85,GOLD_ARMOR:60,DIAMOND_ARMOR:56,
}
const ARMOR_COLOURS = {VillageContent.LEATHER_HORSE_ARMOR:Color("76563e"),COPPER_ARMOR:Color("c07a4f"),IRON_ARMOR:Color("c9cdd2"),GOLD_ARMOR:Color("e2c14a"),DIAMOND_ARMOR:Color("5fd6cf")}
const DATA = {
	11564:{"name":"Copper horse armor","color":"c07a4f","stack":1,"family":"horse_armor"},
	11565:{"name":"Iron horse armor","color":"c9cdd2","stack":1,"family":"horse_armor"},
	11566:{"name":"Golden horse armor","color":"e2c14a","stack":1,"family":"horse_armor"},
	11567:{"name":"Diamond horse armor","color":"5fd6cf","stack":1,"family":"horse_armor"},
}
const CHEST_SLOTS = 15
const DONKEY_SPEED = 3.5
const DONKEY_JUMP = 10.0
const SKELETON_SPEED = 4.0
const RIDE_SCALE = 8.0/4.5
const JUMP_SCALE = 9.5/14.0
const BREED_TIME = 3.5
const BREED_COOLDOWN = 300.0
const LOVE_TIME = 15.0
const GROW_TIME = 1200.0
const TRAP_RANGE = 10.0
const TRAP_LIFE = 900.0
const TRAP_CHANCE = 0.01
const TRAP_HORSES = 3
const HERD_MIN = 2
const HERD_MAX = 6
const HORSE_WEIGHT = 5
const DONKEY_WEIGHT = 1
const MEADOW = "Oakwood meadow"
const MEADOW_ANIMALS = 40

static func is_equine(kind: String) -> bool: return KINDS.has(kind)
static func is_undead(kind: String) -> bool: return UNDEAD_KINDS.has(kind)
static func carries_chest(kind: String) -> bool: return kind == DONKEY or kind == MULE
static func wears_armor(kind: String) -> bool: return kind in [HORSE,SKELETON,ZOMBIE]
static func breeds(kind: String) -> bool: return kind == HORSE or kind == DONKEY
static func tamed(mob: Node3D) -> bool: return int(mob.trust) >= TAMED_TRUST
static func temper(mob: Node3D) -> int: return int(mob.get_meta("temper",0))

# --- the statistics -------------------------------------------------------------

static func roll_health(rng: RandomNumberGenerator) -> float: return 15.0+rng.randi_range(0,8)+rng.randi_range(0,9)

static func jump_from(t1: float, t2: float, t3: float) -> float: return (0.4+t1*0.2+t2*0.2+t3*0.2)*20.0
static func speed_from(t1: float, t2: float, t3: float) -> float: return (0.45+t1*0.3+t2*0.3+t3*0.3)*20.0*0.25
static func roll_jump(rng: RandomNumberGenerator) -> float: return jump_from(rng.randf(),rng.randf(),rng.randf())
static func roll_speed(rng: RandomNumberGenerator) -> float: return speed_from(rng.randf(),rng.randf(),rng.randf())

# `horse:child_properties`: the parents' mean pushed by their spread, reflected
# back inside the species' range.
static func child_value(p1: float, p2: float, low: float, high: float, rng: RandomNumberGenerator) -> float:
	p1 = clampf(p1,low,high); p2 = clampf(p2,low,high)
	var spread: float = absf(p1-p2)+0.15*(high-low)*2.0
	var value: float = (p1+p2)/2.0+spread*((rng.randf()+rng.randf()+rng.randf())/3.0)
	if value > high: return high-(value-high)
	if value < low: return low+(low-value)
	return value

static func max_health(mob: Node3D) -> float: return float(mob.get_meta("max_health",mob.info().health))
static func speed(mob: Node3D) -> float:
	match mob.kind:
		DONKEY,MULE: return DONKEY_SPEED
		SKELETON,ZOMBIE: return float(mob.get_meta("speed",SKELETON_SPEED))
	return float(mob.get_meta("speed",4.5))
static func jump(mob: Node3D) -> float:
	if mob.kind == DONKEY or mob.kind == MULE: return DONKEY_JUMP
	return float(mob.get_meta("jump",14.0))
static func ride_speed(mob: Node3D) -> float: return speed(mob)*RIDE_SCALE
static func jump_velocity(mob: Node3D) -> float: return jump(mob)*JUMP_SCALE

# `on_spawn`: the rolled statistics and the coat.
static func initialize(mob: Node3D, rng: RandomNumberGenerator) -> void:
	if mob.has_meta("max_health"): return
	var hp: float = 30.0 if is_undead(mob.kind) else roll_health(rng)
	mob.set_meta("max_health",hp); mob.health = hp
	if mob.kind in [HORSE,SKELETON,ZOMBIE]: mob.set_meta("jump",roll_jump(rng))
	if mob.kind == HORSE:
		mob.set_meta("speed",roll_speed(rng))
		mob.set_meta("horse_base",BASES[rng.randi_range(0,BASES.size()-1)])
		mob.set_meta("horse_markings",MARKINGS[rng.randi_range(0,MARKINGS.size()-1)])

# --- taming, food and equipment -----------------------------------------------------

static func feed(game: Node3D, mob: Node3D, id: int) -> bool:
	if not FOOD.has(id) or is_undead(mob.kind): return false
	var entry: Array = FOOD[id]
	var used: bool = false
	if mob.health < max_health(mob): mob.health = minf(max_health(mob),mob.health+float(entry[0])); used = true
	if mob.growth_remaining > 0.0 and int(entry[1]) > 0:
		mob.growth_remaining = maxf(0.01,mob.growth_remaining-float(entry[1])*TICK); used = true
	if mob.growth_remaining <= 0.0 and temper(mob) < MAX_TEMPER:
		mob.set_meta("temper",mini(MAX_TEMPER,temper(mob)+int(entry[2]))); used = true
	if bool(entry[3]) and mob.growth_remaining <= 0.0 and tamed(mob) and breeds(mob.kind) and mob.love_time <= 0.0 and mob.breed_cooldown <= 0.0:
		mob.love_time = LOVE_TIME; used = true
	if used:
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("eat")
	return used

static func armor_factor(mob: Node3D) -> float:
	var id: int = int(mob.get_meta("horse_armor_id",0))
	if id == 0 and mob.horse_armor: id = VillageContent.LEATHER_HORSE_ARMOR
	return float(ARMOR.get(id,100))/100.0

static func equip_armor(mob: Node3D, id: int) -> bool:
	if not ARMOR.has(id) or not wears_armor(mob.kind) or int(mob.get_meta("horse_armor_id",0)) != 0 or mob.horse_armor: return false
	mob.set_meta("horse_armor_id",id)
	mob.horse_armor = true
	var plate: MeshInstance3D = mob._box(Vector3(0,1.1,0.02),Vector3(0.69,0.53,1.02),ARMOR_COLOURS.get(id,Color("76563e")),"cloth")
	plate.set_meta("horse_armor_plate",true)
	return true

static func armor_id(mob: Node3D) -> int:
	var id: int = int(mob.get_meta("horse_armor_id",0))
	return VillageContent.LEATHER_HORSE_ARMOR if id == 0 and mob.horse_armor else id

static func remove_armor(mob: Node3D) -> int:
	var id: int = armor_id(mob)
	if id == 0: return 0
	mob.horse_armor = false
	mob.remove_meta("horse_armor_id")
	for part in mob.parts:
		if is_instance_valid(part) and part.has_meta("horse_armor_plate"): part.visible = false
	return id

static func chest(mob: Node3D) -> Array:
	if not mob.has_meta("equine_chest"): return []
	return mob.get_meta("equine_chest")

static func add_chest(mob: Node3D) -> bool:
	if not carries_chest(mob.kind) or mob.has_meta("equine_chest") or not tamed(mob): return false
	var slots: Array = []
	for i in CHEST_SLOTS: slots.append({"id":0,"count":0,"wear":0})
	mob.set_meta("equine_chest",slots)
	var bag: MeshInstance3D = mob._box(Vector3(0,1.0,0.35),Vector3(0.8,0.36,0.3),Color("7a5431"),"wood")
	bag.set_meta("equine_chest_box",true)
	return true

static func open_chest(game: Node3D, mob: Node3D) -> bool:
	var slots: Array = chest(mob)
	if slots.is_empty(): return false
	game.hud.return_cursor()
	game.state = "inventory"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	game.hud.show_inventory("chest",{"kind":mob.kind,"label":"%s · %d slots" % [mob.kind.capitalize(),CHEST_SLOTS],"slots":slots})
	return true

# The whole right-click, in `horse:on_rightclick`'s order. Returns true when used.
static func use(game: Node3D, mob: Node3D) -> bool:
	var held: Dictionary = game.inventory.held()
	var id: int = int(held.id) if held.count > 0 else 0
	var creative: bool = game.gamemode == "creative"
	var sneaking: bool = Signs.sneaking(game)
	if mob.growth_remaining > 0.0 and not FOOD.has(id): return true
	# A tamed donkey or mule takes a chest, and a sneaking click opens it.
	if carries_chest(mob.kind) and tamed(mob):
		if id == Nodes.CHEST and add_chest(mob):
			if not creative: game.inventory.consume_selected()
			return true
		if sneaking and open_chest(game,mob): return true
	if FOOD.has(id):
		feed(game,mob,id)
		return true
	if tamed(mob) and mob.growth_remaining <= 0.0:
		if id == Nodes.SADDLE and not mob.saddled:
			mob.equip_saddle()
			if not creative: game.inventory.consume_selected()
			return true
		if ARMOR.has(id) and equip_armor(mob,id):
			if not creative: game.inventory.consume_selected()
			game.sound("equip")
			return true
		if id == Nodes.SHEARS and (armor_id(mob) != 0 or mob.saddled):
			if armor_id(mob) != 0:
				var removed: int = remove_armor(mob)
				if not creative and removed != 0: game.spawn_drop(mob.position+Vector3.UP,removed)
			else:
				unsaddle(mob)
				if not creative: game.spawn_drop(mob.position+Vector3.UP,Nodes.SADDLE)
			if not creative: game.inventory.damage_tool()
			return true
	# An untamed horse can only be mounted with an empty hand; anything else
	# angers it.
	if not tamed(mob) and id != 0:
		game.puff(mob.center()+Vector3.UP*0.5,Color("7a3b2b"),4,0.6)
		return true
	if not tamed(mob) and is_undead(mob.kind): return true
	if game.boats.ridden(): game.toast("Leave the boat before mounting."); return true
	game.survival.mount = mob
	mob.set_meta("evaluating",not tamed(mob))
	if tamed(mob): game.toast("Mounted. Move to ride, Space to jump, Ctrl to dismount.")
	return true

static func unsaddle(mob: Node3D) -> void:
	mob.saddled = false
	for part in mob.parts:
		if is_instance_valid(part) and part.has_meta("equine_saddle"): part.visible = false

# `horse_maybe_tame`: an untamed horse with a rider rolls, on average every fifty
# ticks, whether it accepts them. Returns "tamed", "bucked" or "".
static func evaluate(game: Node3D, mob: Node3D, delta: float, rng: RandomNumberGenerator) -> String:
	if tamed(mob) or game.survival.mount != mob: return ""
	if rng.randi_range(1,Bats.scale_chance(EVALUATE_TICKS,delta)) != 1: return ""
	if rng.randi_range(1,MAX_TEMPER) <= temper(mob)+1:
		mob.trust = TAMED_TRUST
		mob.set_meta("owner",game.player_id)
		mob.remove_meta("evaluating")
		game.puff(mob.center()+Vector3.UP*0.6,Color("ef7c8f"),8,1.0)
		game.toast("The horse accepts you as its rider.")
		return "tamed"
	mob.set_meta("temper",mini(MAX_TEMPER,temper(mob)+BUCK_TEMPER))
	game.survival.mount = null
	game.player.position = mob.position+Vector3(1,0.4,0)
	game.player.velocity = Vector3(0,5,0)
	game.puff(mob.center()+Vector3.UP*0.5,Color("7a3b2b"),6,0.8)
	return "bucked"

# --- breeding -------------------------------------------------------------------------

static func mate_kind(a: String, b: String) -> String:
	if a == HORSE and b == HORSE: return HORSE
	if a == DONKEY and b == DONKEY: return DONKEY
	if (a == HORSE and b == DONKEY) or (a == DONKEY and b == HORSE): return MULE
	return ""

static func inherit_coat(a: Node3D, b: Node3D, rng: RandomNumberGenerator) -> Array:
	var source: Node3D = a if rng.randi_range(1,2) == 1 else b
	var base: String = str(source.get_meta("horse_base","brown"))
	var markings: String = str(source.get_meta("horse_markings",""))
	if rng.randi_range(1,MUTATE_ODDS) == 1: base = BASES[rng.randi_range(0,BASES.size()-1)]
	if rng.randi_range(1,MUTATE_ODDS) == 1: markings = MARKINGS[rng.randi_range(0,MARKINGS.size()-1)]
	return [base,markings]

static func breed_step(game: Node3D, mob: Node3D, delta: float) -> Node3D:
	mob.breed_cooldown = maxf(0.0,mob.breed_cooldown-delta)
	mob.love_time = maxf(0.0,mob.love_time-delta)
	if mob.love_time <= 0.0 or mob.growth_remaining > 0.0: return null
	var mate: Node3D = null
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion() or mate_kind(mob.kind,other.kind).is_empty(): continue
		if other.love_time <= 0.0 or other.growth_remaining > 0.0: continue
		if other.position.distance_to(mob.position) <= 8.0: mate = other; break
	if mate == null: return null
	if mob.get_instance_id() > mate.get_instance_id(): return null
	var together: float = float(mob.get_meta("mate_time",0.0))+delta
	mob.set_meta("mate_time",together)
	if together < BREED_TIME: return null
	mob.set_meta("mate_time",0.0)
	for parent in [mob,mate]:
		parent.love_time = 0.0; parent.breed_cooldown = BREED_COOLDOWN
	var rng := RandomNumberGenerator.new(); rng.randomize()
	return make_foal(game,mob,mate,rng)

static func make_foal(game: Node3D, a: Node3D, b: Node3D, rng: RandomNumberGenerator) -> Node3D:
	var kind: String = mate_kind(a.kind,b.kind)
	if kind.is_empty(): return null
	var foal: Node3D = game.spawn_creature(kind,a.position)
	if foal == null: return null
	var hp: float = child_value(max_health(a),max_health(b),15.0,32.0,rng)
	foal.set_meta("max_health",hp); foal.health = hp
	if kind == HORSE:
		foal.set_meta("jump",child_value(jump(a),jump(b),jump_from(0,0,0),jump_from(1,1,1),rng))
		foal.set_meta("speed",child_value(speed(a),speed(b),speed_from(0,0,0),speed_from(1,1,1),rng))
		var coat: Array = inherit_coat(a,b,rng)
		set_coat(foal,coat[0],coat[1])
	foal.growth_remaining = GROW_TIME
	Farming.resize(foal)
	foal.set_meta("persistent",true)
	XpOrbs.throw_xp(game,foal.center(),rng.randi_range(1,7))
	return foal

# --- persistence -------------------------------------------------------------------------

# `get_meta` treats a null default as no default, so an absent field reads here.
static func optional(mob: Node3D, key: String) -> Variant:
	return mob.get_meta(key) if mob.has_meta(key) else null

static func snapshot(mob: Node3D) -> Dictionary:
	var slots: Array = []
	for slot in chest(mob): slots.append(Inventory.clean_slot(slot))
	return {"max_health":max_health(mob),"speed":optional(mob,"speed"),"jump":optional(mob,"jump"),
		"base":mob.get_meta("horse_base",""),"markings":mob.get_meta("horse_markings",""),"temper":temper(mob),
		"armor":armor_id(mob),"chest":slots if mob.has_meta("equine_chest") else null,"trap":optional(mob,"trap_age"),
		"growth":mob.growth_remaining,"owner":mob.get_meta("owner","")}

static func restore(mob: Node3D, entry: Variant) -> void:
	if not entry is Dictionary or entry.is_empty(): return
	var hp: Variant = entry.get("max_health")
	if (hp is float or hp is int) and float(hp) >= 1.0 and float(hp) <= 64.0: mob.set_meta("max_health",float(hp))
	for key in ["speed","jump"]:
		var value: Variant = entry.get(key)
		if (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0: mob.set_meta(key,float(value))
	mob.set_meta("temper",clampi(int(entry.get("temper",0)),0,MAX_TEMPER))
	if not str(entry.get("owner","")).is_empty(): mob.set_meta("owner",str(entry.owner))
	var base: String = str(entry.get("base",""))
	if BASES.has(base): set_coat(mob,base,str(entry.get("markings","")) if MARKINGS.has(str(entry.get("markings",""))) else "")
	var armor: int = int(entry.get("armor",0))
	if ARMOR.has(armor): mob.horse_armor = false; equip_armor(mob,armor)
	if entry.get("chest") is Array and carries_chest(mob.kind):
		var was_tamed: int = mob.trust
		mob.trust = TAMED_TRUST
		add_chest(mob)
		mob.trust = was_tamed
		var slots: Array = chest(mob)
		for i in mini(slots.size(),entry.chest.size()): slots[i] = Inventory.clean_slot(entry.chest[i])
	var trap: Variant = entry.get("trap")
	if (trap is float or trap is int) and mob.kind == SKELETON: mob.set_meta("trap_age",float(trap))
	var growth: Variant = entry.get("growth")
	if (growth is float or growth is int) and float(growth) > 0.0:
		mob.growth_remaining = minf(float(growth),GROW_TIME); Farming.resize(mob)

# --- the skeleton trap ---------------------------------------------------------------------

static func trap_roll(difficulty: float, roll: float) -> bool: return roll <= difficulty*TRAP_CHANCE

# Called for a lightning strike: the source's trap spawn in open air.
static func strike(game: Node3D, cell: Vector3i, rng: RandomNumberGenerator) -> Node3D:
	var world: VoxelWorld = game.world
	if world.node_at(cell) != Nodes.AIR or Fluids.liquid(world.node_at(cell+Vector3i.DOWN)): return null
	if not trap_roll(RegionalDifficulty.regional(game,Vector3(cell)),float(rng.randi_range(0,26000))/26000.0): return null
	var horse: Node3D = game.spawn_creature(SKELETON,Vector3(cell)+Vector3(0.5,0.01,0.5))
	if horse == null: return null
	horse.set_meta("trap_age",0.0)
	horse.set_meta("persistent",true)
	return horse

static func is_trap(mob: Node3D) -> bool: return mob.kind == SKELETON and mob.has_meta("trap_age")

# `check_skeleton_trap` and the 900-second life. Returns the riders spawned.
static func trap_step(game: Node3D, mob: Node3D, delta: float) -> Array:
	if not is_trap(mob): return []
	var age: float = float(mob.get_meta("trap_age"))+delta
	mob.set_meta("trap_age",age)
	if age > TRAP_LIFE:
		mob.queue_free(); return []
	if mob.position.distance_to(game.player.position) > TRAP_RANGE: return []
	mob.remove_meta("trap_age")
	mob.trust = TAMED_TRUST
	game.world.set_meta("trap_strike",true)
	Weather.strike(game.world,RandomNumberGenerator.new(),mob.position)
	game.world.remove_meta("trap_strike")
	var horses: Array = [mob]
	for i in TRAP_HORSES:
		var extra: Node3D = game.spawn_creature(SKELETON,mob.position+Vector3(randf_range(-1,1),0,randf_range(-1,1)))
		if extra == null: continue
		extra.trust = TAMED_TRUST; extra.set_meta("persistent",true)
		horses.append(extra)
	var riders: Array = []
	for horse in horses:
		var rider: Node3D = game.spawn_creature("skeleton",horse.position+Vector3.UP*1.6)
		if rider == null: continue
		rider.set_meta("jockey",horse.get_instance_id()); horse.set_meta("jockey",rider.get_instance_id())
		rider.set_meta("persistent",true)
		riders.append(rider)
	return riders

# --- spawning -------------------------------------------------------------------------------

static func spawn_share(biome: String) -> float:
	if biome != MEADOW: return 0.0
	return float(HORSE_WEIGHT+DONKEY_WEIGHT)/float(HORSE_WEIGHT+DONKEY_WEIGHT+MEADOW_ANIMALS)

static func spawn_herd(game: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var donkeys: bool = rng.randi_range(1,HORSE_WEIGHT+DONKEY_WEIGHT) <= DONKEY_WEIGHT
	var size: int = 1 if donkeys else rng.randi_range(HERD_MIN,HERD_MAX)
	for i in size:
		var at: Vector3 = pos+(Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3)) if i > 0 else Vector3.ZERO)
		if i > 0 and game.world.intersects(at,0.5,1.6): continue
		var mob: Node3D = game.spawn_creature(DONKEY if donkeys else HORSE,at)
		if mob != null: made.append(mob)
	return made

# --- art --------------------------------------------------------------------------------------

static func set_coat(mob: Node3D, base: String, markings: String) -> void:
	mob.set_meta("horse_base",base); mob.set_meta("horse_markings",markings)
	if mob.model == null: return
	for child in mob.model.get_children(): child.free()
	mob.parts.clear(); mob.colors.clear(); mob.legs.clear(); mob.arms.clear()
	mob.head = null; mob.box_count = 0; mob.tint_applied = []
	build(mob)
	if mob.saddled: draw_saddle(mob)
	var armor: int = armor_id(mob)
	if armor != 0:
		mob.horse_armor = false; mob.remove_meta("horse_armor_id"); equip_armor(mob,armor)
	if mob.has_meta("equine_chest"):
		var bag: MeshInstance3D = mob._box(Vector3(0,1.0,0.35),Vector3(0.8,0.36,0.3),Color("7a5431"),"wood")
		bag.set_meta("equine_chest_box",true)
	mob.merge_parts()
	CreatureArt.farm_age(mob,mob.growth_remaining > 0)

static func palette(mob: Node3D) -> Dictionary:
	match mob.kind:
		DONKEY: return {"coat":Color("8a7c6c"),"dark":Color("5c5146"),"muzzle":Color("cfc3b2"),"mane":Color("3f352c")}
		MULE: return {"coat":Color("5a3a22"),"dark":Color("3b2515"),"muzzle":Color("9c7a5c"),"mane":Color("241810")}
		SKELETON: return {"coat":Color("d8d5c4"),"dark":Color("b3b09f"),"muzzle":Color("e6e3d4"),"mane":Color("a9a693")}
		ZOMBIE: return {"coat":Color("4f7a4a"),"dark":Color("35573a"),"muzzle":Color("6c9360"),"mane":Color("2c4128")}
	var coat: Color = BASE_COLOURS.get(str(mob.get_meta("horse_base","brown")),BASE_COLOURS.brown)
	return {"coat":coat,"dark":coat.darkened(0.25),"muzzle":coat.lightened(0.3),"mane":coat.darkened(0.55)}

static func build(mob: Node3D) -> void:
	var pal: Dictionary = palette(mob)
	var markings: String = str(mob.get_meta("horse_markings","")) if mob.kind == HORSE else ""
	var scale: float = 0.86 if mob.kind == DONKEY else (0.94 if mob.kind == MULE else 1.0)
	var skin: String = "bone" if mob.kind == SKELETON else "fur"
	mob._box(Vector3(0,1.03,0.08)*scale,Vector3(0.65,0.66,1.24)*scale,pal.coat,skin)
	mob._box(Vector3(0,1.43,-0.47)*scale,Vector3(0.38,0.78,0.42)*scale,pal.coat,skin)
	mob.head = mob._joint(Vector3(0,1.8,-0.58)*scale,"Head")
	mob._box(Vector3(0,-0.08,-0.1)*scale,Vector3(0.4,0.45,0.65)*scale,pal.coat,skin,mob.head)
	mob._box(Vector3(0,-0.17,-0.4)*scale,Vector3(0.42,0.27,0.24)*scale,pal.muzzle,skin,mob.head)
	# A donkey's and a mule's long ears are their whole silhouette.
	var ear: float = 0.42 if mob.kind in [DONKEY,MULE] else 0.24
	for side in [-1,1]:
		mob._box(Vector3(side*0.13,0.26+ear*0.3,0.06)*scale,Vector3(0.1,ear,0.14)*scale,pal.dark,skin,mob.head)
		mob._box(Vector3(side*0.21,0.035,-0.24)*scale,Vector3(0.025,0.07,0.07)*scale,Color("302d29"),"",mob.head)
		for z in [-0.39,0.55]:
			var leg: Node3D = mob._joint(Vector3(side*0.23,0.83,z)*scale,"Leg")
			var sock: bool = markings == "white"
			mob._box(Vector3(0,-0.35,0)*scale,Vector3(0.17,0.7,0.2)*scale,pal.dark,skin,leg)
			mob._box(Vector3(0,-0.77,-0.015)*scale,Vector3(0.2,0.15,0.24)*scale,Color("ece8df") if sock else Color("393933"),"",leg)
			mob.legs.append(leg)
	mob._box(Vector3(0,1.49,-0.235)*scale,Vector3(0.16,0.75,0.09)*scale,pal.mane,skin)
	mob._box(Vector3(0,0.83,0.82)*scale,Vector3(0.16,0.83,0.15)*scale,pal.mane,skin)
	# The markings: white or black dots, a white field, or a blaze and stockings.
	match markings:
		"whitedots","blackdots":
			var dot: Color = Color("f2efe8") if markings == "whitedots" else Color("1f1b19")
			for i in 6: mob._box(Vector3(-0.2+float(i%3)*0.2,1.37,-0.2+float(i/3)*0.45)*scale,Vector3(0.08,0.02,0.08)*scale,dot,"")
		"whitefield":
			mob._box(Vector3(0,1.365,0.25)*scale,Vector3(0.6,0.02,0.6)*scale,Color("ece8df"),"fur")
		"white":
			mob._box(Vector3(0,-0.02,-0.43)*scale,Vector3(0.12,0.3,0.02)*scale,Color("ece8df"),"",mob.head)
	if mob.kind == ZOMBIE:
		for i in 3: mob._box(Vector3(0.33*scale,1.1,-0.2+i*0.2),Vector3(0.02,0.3,0.05),Color("d8d5c4"),"bone")

static func draw_saddle(mob: Node3D) -> void:
	var scale: float = 0.86 if mob.kind == DONKEY else (0.94 if mob.kind == MULE else 1.0)
	var plate: MeshInstance3D = mob._box(Vector3(0,1.37,0.17)*scale,Vector3(0.66,0.12,0.56)*scale,Color("784c34"),"cloth")
	plate.set_meta("equine_saddle",true)
	for side in [-1,1]:
		var strap: MeshInstance3D = mob._box(Vector3(side*0.35,1.06,0.17)*scale,Vector3(0.06,0.5,0.16)*scale,Color("c5ad78"),"")
		strap.set_meta("equine_saddle",true)

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("equines_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+3571
		world.set_meta("equines_rng",rng)
	return world.get_meta("equines_rng")

# `post_apply_driver_input`: the share of the jump strength a charge of `seconds`
# releases. Under ten ticks it rises with the charge; from ten it falls back
# toward 0.8; and anything at 0.9 or more is a full jump.
static func jump_scale(seconds: float) -> float:
	var ticks: int = floori(seconds*20.0)
	var scale: float = 0.8+2.0/float(ticks-9)*0.1 if ticks >= 10 else float(ticks)*0.1
	if scale >= 0.9: return 1.0
	return 0.4+0.4*scale/0.9
