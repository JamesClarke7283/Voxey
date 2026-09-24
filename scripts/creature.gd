class_name Creature
extends Node3D

# Every mob shares one controller. KINDS describes the differences: shape, speed,
# hit points, drops, voice, and the special behaviours enabled by flags.
const KINDS = {
	"silverfish":{"hostile":true,"health":8.0,"speed":2.2,"width":0.2,"height":0.35,"damage":1,"drops":[],"voice":"spider","pitch":1.7,"xp":5,"armor":{"fleshy":100,"arthropod":100}},
	"turtle":{"hostile":false,"health":30.0,"speed":0.5,"width":0.45,"height":0.7,"damage":0,"drops":[[VillageContent.TURTLE_SCUTE,1,2]],"voice":"","pitch":0.7},
	"phantom":{"hostile":true,"health":20.0,"speed":6.0,"width":0.7,"height":0.65,"damage":4,"drops":[[VillageContent.PHANTOM_MEMBRANE,1,2]],"voice":"","pitch":1.3,"xp":5},
	"breeze":{"hostile":true,"health":30.0,"speed":2.8,"width":0.35,"height":1.6,"damage":4,"drops":[[VillageContent.BREEZE_ROD,1,2]],"voice":"","pitch":1.1,"leaps":true,"xp":6},
	"pillager":{"hostile":true,"health":24.0,"speed":2.2,"width":0.3,"height":1.95,"damage":4,"drops":[[VillageContent.EMERALD,0,2],[VillageContent.CROSSBOW,0,1]],"voice":"","pitch":0.9,"ranged":true,"xp":6,"armor":{"fleshy":100}},
	"rabbit":{"hostile":false,"health":3.0,"speed":1.3,"width":0.22,"height":0.95,"damage":0,"drops":[[VillageContent.RAW_RABBIT,1,1],[VillageContent.RABBIT_HIDE,1,1],[VillageContent.RABBIT_FOOT,0,1]],"voice":"","pitch":1.5},
	"horse":{"hostile":false,"health":30.0,"speed":1.4,"width":0.4,"height":2.2,"damage":0,"drops":[[Nodes.LEATHER,1,2]],"voice":"","pitch":1.0},
	"villager":{"hostile":false,"health":20.0,"speed":1.2,"width":0.28,"height":1.95,"damage":0,"drops":[],"voice":"","pitch":1.0},
	# `mobs_mc:wandering_trader` and its llama escort. Neither carries
	# `can_despawn`: the source's default is false and both leave on their own
	# twenty-minute timer, which `WanderingTraders` owns.
	"wandering_trader":{"hostile":false,"health":20.0,"speed":1.6,"width":0.28,"height":1.95,"damage":0,"drops":[],"voice":"","pitch":1.0,"xp":0},
	"trader_llama":{"hostile":false,"health":15.0,"speed":0.45,"width":0.45,"height":1.87,"damage":0,"drops":[[Nodes.LEATHER,0,2]],"voice":"","pitch":1.0,"xp":1},
	"snow_golem":{"hostile":false,"health":4.0,"speed":2.0,"width":0.35,"height":1.89,"damage":0,"drops":[[Nodes.SNOWBALL,0,15]],"voice":"","pitch":1.0,"armor":{"fleshy":100,"water_vulnerable":100}},
	"iron_golem":{"hostile":false,"health":100.0,"speed":2.5,"width":0.7,"height":2.69,"damage":15,"drops":[],"voice":"","pitch":1.0},
	"shulker": {"hostile":true,"health":30.0,"speed":0.0,"width":0.5,"height":1.0,"damage":4,"drops":[[Nodes.SHULKER_SHELL,1,2]],"voice":"","pitch":0.9,"xp":5},
	"enderman": {"hostile":true,"health":40.0,"speed":3.6,"width":0.3,"height":2.9,"damage":5,"drops":[[Nodes.ENDER_PEARL,1,2]],"voice":"","pitch":0.6,"water_sensitive":true,"can_despawn":true,"reach":3,"xp":5,"armor":{"fleshy":100,"water_vulnerable":100}},
	"ghast": {"hostile":true,"health":10.0,"speed":2.0,"width":1.6,"height":4.0,"damage":6,"drops":[[Nodes.GHAST_TEAR,1,2],[Nodes.GUNPOWDER,1,3]],"voice":"","pitch":0.6,"xp":5},
	"blaze": {"hostile":true,"health":20.0,"speed":2.4,"width":0.35,"height":1.8,"damage":4,"drops":[[Nodes.BLAZE_ROD,1,2]],"voice":"","pitch":0.8,"water_sensitive":true,"xp":10,"armor":{"fleshy":100,"snowball_vulnerable":100,"water_vulnerable":100}},
	# A slime's reward is its own size, which the source splits three ways: a big slime
	# pays four, a small two and a tiny one. `ExpeditionCreature.die` awards
	# `slime_size` directly because a big slime also splits on death, so this value is
	# the one a size-4 slime would pay and the field is informational for a slime.
	"slime": {"hostile":true,"health":4.0,"speed":1.6,"width":0.45,"height":1.0,"damage":2,"drops":[[Nodes.SLIME_BALL,1,3]],"voice":"","pitch":0.8,"leaps":true,"xp":4},
	"end_crystal": {"hostile":false,"health":1.0,"speed":0.0,"width":0.6,"height":1.4,"damage":0,"drops":[],"voice":"","pitch":1.0,"xp":0},
	"ender_dragon": {"hostile":true,"health":200.0,"speed":13.0,"width":3.0,"height":4.0,"damage":7,"drops":[],"voice":"","pitch":0.4},
	"piglin_brute":{"hostile":true,"health":50.0,"speed":2.5,"width":0.3,"height":1.8,"damage":7,"drops":[],"voice":"pig","pitch":0.55,"xp":20,"armor":{"fleshy":90}},
	"piglin": {"hostile":true,"health":16.0,"speed":2.5,"width":0.3,"height":1.8,"damage":4,"drops":[[Nodes.GOLD_NUGGET,1,4]],"voice":"pig","pitch":0.65,"floats":false,"xp":9,"armor":{"fleshy":90}},
	# The source's zombified piglin: a piglin rotted to green, neutral to players
	# until struck, immune to sunlight (its `ignited_by_sunlight` is false) and to
	# fire, dropping rotten flesh and gold. A lightning strike on a pig makes one.
	"zombified_piglin": {"hostile":true,"health":20.0,"speed":2.5,"width":0.3,"height":1.8,"damage":5,"drops":[[Nodes.ROTTEN_FLESH,1,1],[Nodes.GOLD_NUGGET,0,1],[Nodes.GOLD,0,1]],"voice":"zombie","pitch":0.7,"neutral":true,"xp":5,"armor":{"undead":90,"fleshy":90}},
	"magma_cube": {"hostile":true,"health":16.0,"speed":1.5,"width":0.43,"height":1.0,"damage":3,"drops":[[Nodes.MAGMA_CREAM,1,2]],"voice":"","pitch":0.8,"leaps":true,"xp":4},
	"sheep": {"hostile":false,"health":8.0,"speed":0.8,"width":0.3,"height":1.1,"damage":0,"drops":[[VillageContent.RAW_MUTTON,1,2],[Nodes.WOOL,1,1]],"voice":"sheep","pitch":1.0,"xp":1},
	"cow": {"hostile":false,"health":10.0,"speed":0.7,"width":0.36,"height":1.35,"damage":0,"drops":[[VillageContent.RAW_BEEF,1,3],[Nodes.LEATHER,1,2]],"voice":"cow","pitch":0.75,"xp":1},
	"pig": {"hostile":false,"health":10.0,"speed":0.9,"width":0.3,"height":0.9,"damage":0,"drops":[[VillageContent.RAW_PORKCHOP,1,3]],"voice":"pig","pitch":1.0,"xp":1},
	"chicken": {"hostile":false,"health":4.0,"speed":1.0,"width":0.18,"height":0.65,"damage":0,"drops":[[VillageContent.RAW_CHICKEN,1,1],[Nodes.FEATHER,1,2]],"voice":"chicken","pitch":1.5,"glides":true,"xp":1},
	# The source's parrot: six health, a feather or two, and a glider like the
	# chicken. It is what perches in a pillager outpost.
	"parrot": {"hostile":false,"health":6.0,"speed":1.1,"width":0.25,"height":0.9,"damage":0,"drops":[[Nodes.FEATHER,1,2]],"voice":"chicken","pitch":1.8,"glides":true,"xp":1},
	"zombie": {"hostile":true,"health":20.0,"speed":2.1,"width":0.28,"height":1.8,"damage":3,"drops":[[Nodes.ROTTEN_FLESH,0,2]],"voice":"zombie","pitch":0.9,"burns":true,"hunts_villagers":true,"floats":false,"reach":2,"xp":5,"armor":{"undead":90,"fleshy":90}},
	# The source's zombie villager: a zombie in every respect except that a golden
	# apple can cure it back into a villager. Its drops match the zombie's.
	"zombie_villager": {"hostile":true,"health":20.0,"speed":2.1,"width":0.3,"height":1.95,"damage":3,"drops":[[Nodes.ROTTEN_FLESH,0,2]],"voice":"zombie","pitch":0.9,"burns":true,"hunts_villagers":true,"floats":false,"reach":2,"xp":5},
	# The source's witch: a ranged attacker whose drops are rolled by `Witches`,
	# because their chance denominators cannot be expressed in this table.
	"witch": {"hostile":true,"health":26.0,"speed":1.4,"width":0.3,"height":1.95,"damage":6,"drops":[],"voice":"witch","pitch":1.2,"ranged":true,"can_despawn":true,"xp":5,"armor":{"fleshy":100}},
	# The source's illagers. Their drops are rolled by `Illagers`, because the
	# evoker's guaranteed totem is the only survival route to one.
	"vindicator": {"hostile":true,"health":24.0,"speed":2.3,"width":0.3,"height":1.95,"damage":5,"drops":[],"voice":"zombie","pitch":0.85,"xp":6,"armor":{"fleshy":100}},
	# The two remaining raid roles, whose numbers live in `RaidMobs`.
	"ravager":{"hostile":true,"health":100.0,"speed":2.6,"width":0.6,"height":1.6,"damage":12,"drops":[[124,1,1,1]],"voice":"zombie","pitch":0.55,"xp":20,"armor":{"fleshy":100}},
	"vex":{"hostile":true,"health":14.0,"speed":4.5,"width":0.2,"height":0.8,"damage":4,"drops":[],"voice":"zombie","pitch":1.35,"xp":6,"armor":{"fleshy":100}},
	"evoker": {"hostile":true,"health":24.0,"speed":1.6,"width":0.4,"height":1.95,"damage":0,"drops":[],"voice":"zombie","pitch":0.7,"xp":6,"armor":{"fleshy":100}},
	# The source's cat, which the witch hut spawns in black.
	"cat": {"hostile":false,"health":10.0,"speed":1.5,"width":0.3,"height":0.7,"damage":0,"drops":[],"voice":"cat","pitch":1.6,"xp":1},
	"skeleton": {"hostile":true,"health":20.0,"speed":2.4,"width":0.28,"height":1.8,"damage":2,"drops":[[Nodes.BONE,0,2]],"voice":"skeleton","pitch":1.1,"burns":true,"ranged":true,"floats":false,"reach":2,"xp":6,"armor":{"undead":100,"fleshy":100}},
	"spider": {"hostile":true,"health":16.0,"speed":3.2,"width":0.5,"height":0.8,"damage":2,"drops":[[Nodes.STRING,0,2],[VillageContent.SPIDER_EYE,0,1]],"voice":"spider","pitch":1.0,"neutral_by_day":true,"leaps":true,"reach":2,"xp":5,"armor":{"fleshy":100,"arthropod":100}},
	"creeper": {"hostile":true,"health":20.0,"speed":2.0,"width":0.28,"height":1.6,"damage":0,"drops":[[Nodes.GUNPOWDER,0,2]],"voice":"","pitch":1.0,"explodes":true,"reach":3,"runaway":true,"xp":5},
	"guardian": {"hostile":true,"health":30.0,"speed":2.0,"width":0.85,"height":0.85,"damage":6,"drops":[],"voice":"","pitch":0.7,"swims":true,"ranged":true,"xp":10},
	# The source's aquatic creatures. Their drops carry chance denominators the
	# shared table cannot express, so they are rolled by AquaticMobs instead.
	"cod": {"hostile":false,"health":3.0,"speed":1.6,"width":0.3,"height":0.79,"damage":0,"drops":[],"voice":"","pitch":1.4,"swims":true,"flees":true,"can_despawn":true,"xp":1},
	"salmon": {"hostile":false,"health":3.0,"speed":1.7,"width":0.3,"height":0.79,"damage":0,"drops":[],"voice":"","pitch":1.3,"swims":true,"flees":true,"can_despawn":true,"xp":1},
	"pufferfish": {"hostile":false,"health":3.0,"speed":1.2,"width":0.3,"height":0.79,"damage":0,"drops":[],"voice":"","pitch":1.5,"swims":true,"flees":true,"can_despawn":true,"xp":1},
	"tropical_fish": {"hostile":false,"health":3.0,"speed":1.6,"width":0.3,"height":0.79,"damage":0,"drops":[],"voice":"","pitch":1.6,"swims":true,"flees":true,"can_despawn":true,"xp":1},
	"squid": {"hostile":false,"health":10.0,"speed":1.4,"width":0.4,"height":0.9,"damage":0,"drops":[],"voice":"","pitch":0.8,"swims":true,"can_despawn":true,"xp":1},
	"glow_squid": {"hostile":false,"health":10.0,"speed":1.4,"width":0.4,"height":0.9,"damage":0,"drops":[],"voice":"","pitch":0.85,"swims":true,"can_despawn":true,"xp":1},
	"wither": {"hostile":true,"health":600.0,"speed":3.0,"width":1.0,"height":3.5,"damage":8,"drops":[],"voice":"","pitch":0.4,"ranged":true,"flies":true,"fires":true,"can_despawn":false,"reach":5,"xp":50,"armor":{"undead":80,"fleshy":100}},
	"wither_skeleton": {"hostile":true,"health":20.0,"speed":2.0,"width":0.3,"height":2.4,"damage":5,"drops":[[Nodes.COAL,0,1],[Nodes.BONE,0,2]],"voice":"skeleton","pitch":0.7,"burns":false,"skull_chance":40,"floats":false,"reach":2,"xp":5,"armor":{"undead":100,"fleshy":100}},
	"guardian_elder": {"hostile":true,"health":80.0,"speed":1.4,"width":1.99,"height":2.0,"damage":8,"drops":[],"voice":"","pitch":0.5,"swims":true,"ranged":true,"xp":10},
}
# Kinds the game spawns as AlchemyCreature, which is also the set AlchemyWorld
# persists. One list, so spawning and saving cannot drift apart: a kind added
# here is saved and restored automatically.
const ALCHEMY_KINDS = ["silverfish","turtle","phantom","breeze","pillager","cod","salmon","pufferfish","tropical_fish","squid","glow_squid"]
const PASSIVE = ["sheep","cow","pig","chicken","rabbit","horse","parrot"]
const HOSTILE = ["zombie","zombie","skeleton","spider","creeper","enderman"]

var game: Node3D
var kind: String = "sheep"
var hostile: bool = false
var health: float = 8.0
var width: float = 0.28
var height: float = 1.1
var velocity := Vector3.ZERO
var direction := Vector3.FORWARD
var knock := Vector3.ZERO
var think: float = 0.0
var attack_cooldown: float = 0.0
var leap_cooldown: float = 0.0
var ambient: float = 3.0
var fuse: float = 0.0
# A guardian's laser charge, in seconds; zero means it is not charging.
var laser: float = 0.0
# A boss's invulnerable opening phase, in seconds; it ignores damage while set.
var spawn_invulnerable: float = 0.0
var last_seen: float = 0.0
# Sight is sampled a few times a second rather than every physics tick: it was
# the largest part of a mob's step, and a chase already remembers four seconds.
const SIGHT_INTERVAL = 0.2
# Beyond this a mob cannot close to chase range within that memory.
const SIGHT_RANGE = 64.0
var sight_timer: float = 0.0
var hurt_flash: float = 0.0
# A lightning-struck creeper, and the only death cause that yields a head:
# source `mob_head` requires an explosion from `mobs_mc:creeper_charged`.
var charged: bool = false
var killed_by_charged: bool = false
var life: float = 0.0
var legs: Array = []
var arms: Array = []
var bow_hand: Node3D
var head: Node3D
var gait: float = 0.0
var egg_timer: float = 300.0
var parts: Array = []
# How many boxes the model was built from; `merge_parts` joins them into fewer
# meshes.
var box_count: int = 0
var colors: Array = []
var model: Node3D
var scared: float = 0.0
var provoked: bool = false
# A water-sensitive mob's own half-second damage timer, which the source keeps per
# mob as `check_timer("rain_damage", 0.5)`.
var water_clock: float = 0.0
const WEATHER_INTERVAL: float = 0.5
# Powder-snow freezing: the source slows a mob to a standstill over seven seconds,
# then damages it every two while it stays in. A wither skeleton is the one mob that
# opts out, through `can_freeze = false`.
var frozen_for: float = 0.0
var freeze_clock: float = 0.0
const FREEZE_SECONDS: float = 7.0
const FREEZE_INTERVAL: float = 2.0

# Whether the mob is under water, which is what the float rule acts on. A fish and a
# guardian have their own `swims` behaviour instead.
func submerged() -> bool:
	if not Fluids.water(game.world.node_at(Vector3i(position.floor()))): return false
	# Submerged means the water reaches the mob's head, not merely its feet.
	return Fluids.water(game.world.node_at(Vector3i((position+Vector3.UP*height*0.9).floor())))

# The topmost water cell above the mob, which the float rule rises toward. Returns the
# mob's own cell when it cannot find one, so the caller's depth term is zero.
func water_surface() -> int:
	var cell := Vector3i(position.floor())
	for i in range(1,24):
		if not Fluids.water(game.world.node_at(Vector3i(cell.x,cell.y+i,cell.z))): return cell.y+i-1
	return cell.y

# Whether the mob is standing in powder snow. The block is not solid — a mob sinks
# into it — so this reads the body cell rather than a collision.
func _surface_height() -> int:
	var cell := Vector2i(int(floor(position.x)),int(floor(position.z)))
	if cell != surface_cell:
		surface_cell = cell
		surface_height = game.world.generator.terrain_height(cell.x,cell.y)
	return surface_height

func in_powder_snow() -> bool:
	var cell := Vector3i(position.floor())
	if PowderSnow.is_powder_snow(game.world.node_at(cell)): return true
	return PowderSnow.is_powder_snow(game.world.node_at(cell+Vector3i.UP))
# The villager this mob is currently hunting, when the source has it attack NPCs.
var prey_target: Node3D = null
# The villager search scans every creature and traces sight to each nearby
# villager, so its answer is kept for a quarter of a second.
var prey_choice: Node3D = null
var prey_timer: float = 0.0
# Engine ticks pose the model once per rendered frame, with the time since.
var anim_frame: int = -1
var anim_delta: float = 0.0
# Engine ticks bunch up after a slow frame, and only the last one is ever seen.
# A mob steps on the first tick of each rendered frame and again only once
# 1/30 s has built up, carrying the time forward; at 60 FPS every tick steps
# as before. Direct calls (scripted steps, checks) always step.
var step_frame: int = -1
var step_delta: float = 0.0
# The terrain surface under the mob's cell, for the daylight burn check.
var surface_cell := Vector2i(2147483647,0)
var surface_height: int = 0
var grounded: bool = false
var tinted: bool = false
# The tint last written to the part materials, with the part count; a new part
# clears it. A creeper sets its tint every step, mostly to the same value.
var tint_applied: Array = []
var sheared: bool = false
var wool_timer: float = 0.0
var wool_parts: Array = []
var sheep_color: String = "white"
var grazing: float = 0.0
var graze_consumed: bool = false
var farm_id: String = ""
var custom_name: String = ""
var growth_remaining: float = 0.0
var love_time: float = 0.0
var breed_cooldown: float = 0.0
var farm_mate: String = ""
var mate_time: float = 0.0

func _ready() -> void:
	if not KINDS.has(kind): kind = "sheep"
	var info: Dictionary = KINDS[kind]
	hostile = info.hostile
	health = info.health
	width = info.width
	height = info.height
	ambient = randf_range(2.0,8.0)
	model = Node3D.new()
	add_child(model)
	_build_model()
	Farming.initialize(self)
	Farming.register(self)
	merge_parts()

func _build_model() -> void:
	# A guardian is a spiked water orb with a single eye, so it takes its own
	# branch rather than the biped body the hostile mobs share.
	if Guardians.is_guardian(kind):
		var scale_factor: float = 1.6 if Guardians.is_elder(kind) else 1.0
		var body_color: Color = Color("7a9c8f") if Guardians.is_elder(kind) else Color("6f9c9c")
		_box(Vector3(0,0.42,0),Vector3(0.85,0.85,0.85)*scale_factor,body_color,"skin")
		# The eye faces forward, and the spikes ring the shell.
		_box(Vector3(0,0.45,-0.44)*scale_factor,Vector3(0.3,0.3,0.12)*scale_factor,Color("1c2a2a"),"skin")
		_box(Vector3(0,0.45,-0.5)*scale_factor,Vector3(0.16,0.16,0.06)*scale_factor,Color("d8d05a"),"skin")
		for i in 6:
			var angle: float = TAU*float(i)/6.0
			_box(Vector3(sin(angle)*0.5,0.42,cos(angle)*0.5)*scale_factor,Vector3(0.16,0.16,0.16)*scale_factor,body_color.darkened(0.25),"skin")
		for i in 4:
			var angle: float = TAU*float(i)/4.0
			_box(Vector3(sin(angle)*0.32,0.9,cos(angle)*0.32)*scale_factor,Vector3(0.14,0.22,0.14)*scale_factor,body_color.darkened(0.25),"skin")
		return
	match kind:
		"vindicator","evoker":
			# The illagers share the villager's robe silhouette with a darker palette,
			# which is how the source's own models differ from a villager.
			_box(Vector3(0,0.6,0),Vector3(0.5,1.2,0.3),Color("4a4a52"),"cloth")
			_box(Vector3(0,1.24,0),Vector3(0.34,0.1,0.34),Color("6c6c74"),"cloth")
			head = _joint(Vector3(0,1.34,0),"Head")
			_box(Vector3(0,0.16,0),Vector3(0.44,0.42,0.42),Color("9c8f82"),"skin",head)
			# The illagers' long nose is their most distinctive feature.
			_box(Vector3(0,0.08,-0.28),Vector3(0.11,0.16,0.14),Color("8f8276"),"skin",head)
			for side in [-1,1]:
				_box(Vector3(side*0.11,0.2,-0.22),Vector3(0.075,0.055,0.02),Color("3b332c"),"",head)
				var arm := _joint(Vector3(side*0.34,1.16,0),"Arm")
				_box(Vector3(0,-0.24,0),Vector3(0.16,0.5,0.18),Color("4a4a52"),"cloth",arm)
				if kind == "vindicator":
					# A vindicator carries an iron axe, which is its whole silhouette.
					_box(Vector3(0,-0.52,-0.04),Vector3(0.05,0.5,0.05),Color("8a6b3f"),"",arm)
					_box(Vector3(0,-0.3,-0.1),Vector3(0.06,0.22,0.26),Color("c9c9d2"),"",arm)
				arms.append(arm)
				var leg := _joint(Vector3(side*0.12,0.6,0),"Hip")
				_box(Vector3(0,-0.3,0),Vector3(0.17,0.6,0.19),Color("3a3a42"),"cloth",leg)
				legs.append(leg)
		"ravager":
			# A bulky four-legged beast: a heavy barrel body on four stocky legs with
			# the source's dark hide and its horns.
			_box(Vector3(0,0.95,0),Vector3(0.95,0.8,1.5),Color("3f3a3a"),"skin")
			_box(Vector3(0,1.05,-0.85),Vector3(0.6,0.6,0.45),Color("4a4444"),"skin")
			head = _joint(Vector3(0,1.15,-1.0),"Head")
			_box(Vector3(0,0.05,-0.28),Vector3(0.5,0.45,0.4),Color("4a4444"),"skin",head)
			for side in [-1,1]:
				# The horns curve up either side of the muzzle.
				_box(Vector3(side*0.24,0.24,-0.36),Vector3(0.12,0.3,0.12),Color("d8d2c0"),"",head)
				_box(Vector3(side*0.11,0.1,-0.46),Vector3(0.08,0.08,0.02),Color("1e1a1a"),"",head)
			for side in [-1,1]:
				for end in [-1,1]:
					var leg := _joint(Vector3(side*0.34,0.55,end*0.55),"Hip")
					_box(Vector3(0,-0.3,0),Vector3(0.24,0.6,0.24),Color("353131"),"skin",leg)
					legs.append(leg)
			var tail := _joint(Vector3(0,0.95,0.78),"Hip")
			_box(Vector3(0,-0.1,0.16),Vector3(0.12,0.5,0.12),Color("353131"),"skin",tail)
		"vex":
			# A small flying spirit: a pale head over a dark tunic with two thin wings.
			_box(Vector3(0,0.34,0),Vector3(0.28,0.45,0.2),Color("4a4f63"),"cloth")
			head = _joint(Vector3(0,0.62,0),"Head")
			_box(Vector3(0,0.1,0),Vector3(0.3,0.3,0.3),Color("b9c2d0"),"skin",head)
			_box(Vector3(0,0.1,-0.17),Vector3(0.2,0.1,0.03),Color("7d8698"),"",head)
			for side in [-1,1]:
				_box(Vector3(side*0.28,0.44,0.06),Vector3(0.34,0.2,0.04),Color("9aa7bd"),"",self)
				var arm := _joint(Vector3(side*0.2,0.42,0),"Arm")
				_box(Vector3(0,-0.14,0),Vector3(0.1,0.28,0.1),Color("4a4f63"),"cloth",arm)
				arms.append(arm)
		"witch":
			# The source's witch: a robed figure with a pointed hat, green skin and a
			# wart on her nose.
			_box(Vector3(0,0.6,0),Vector3(0.52,1.2,0.3),Color("3b2a49"),"cloth")
			_box(Vector3(0,0.02,0),Vector3(0.54,0.12,0.32),Color("2b1d37"),"cloth")
			head = _joint(Vector3(0,1.3,0),"Head")
			_box(Vector3(0,0.16,0),Vector3(0.44,0.42,0.42),Color("6d8f57"),"skin",head)
			# The pointed hat, which is what makes the silhouette unmistakable.
			_box(Vector3(0,0.42,0),Vector3(0.6,0.08,0.6),Color("2b1d37"),"cloth",head)
			_box(Vector3(0,0.58,0),Vector3(0.36,0.26,0.36),Color("2b1d37"),"cloth",head)
			_box(Vector3(0,0.8,0),Vector3(0.2,0.24,0.2),Color("2b1d37"),"cloth",head)
			for side in [-1,1]:
				_box(Vector3(side*0.11,0.2,-0.22),Vector3(0.08,0.06,0.02),Color("1c2b1a"),"",head)
				# The wart on the nose, which the source gives her.
				_box(Vector3(side*0.05,0.02,-0.23),Vector3(0.07,0.07,0.06),Color("5b7a48"),"skin",head)
				var arm := _joint(Vector3(side*0.34,1.16,0),"Arm")
				_box(Vector3(0,-0.24,0),Vector3(0.16,0.5,0.18),Color("3b2a49"),"cloth",arm)
				_box(Vector3(0,-0.52,0),Vector3(0.14,0.12,0.14),Color("6d8f57"),"skin",arm)
				arms.append(arm)
				var leg := _joint(Vector3(side*0.12,0.6,0),"Hip")
				_box(Vector3(0,-0.3,0),Vector3(0.17,0.6,0.19),Color("2b1d37"),"cloth",leg)
				legs.append(leg)
		"zombie","zombie_villager","piglin","piglin_brute","zombified_piglin":
			var rotted: bool = kind == "zombified_piglin"
			_box(Vector3(0,1.08,0),Vector3(0.48,0.64,0.28),Color("3f6b52" if rotted else "416f72"),"cloth")
			_box(Vector3(0,1.36,-0.145),Vector3(0.18,0.12,0.025),Color("6f8c62" if rotted else "7a8c55"),"skin")
			head = _joint(Vector3(0,1.51,-0.015),"Head")
			_box(Vector3(0,0.13,0),Vector3(0.43,0.43,0.42),Color("7d9455" if rotted else "81935d"),"skin",head)
			_box(Vector3(0,0.31,0.015),Vector3(0.44,0.075,0.43),Color("44503a"),"skin",head)
			for side in [-1,1]:
				_box(Vector3(side*0.105,0.16,-0.216),Vector3(0.105,0.055,0.018),Color("25362a"),"",head)
				_box(Vector3(side*0.12,0.08,-0.218),Vector3(0.075,0.045,0.019),Color("64764b"),"skin",head)
				var arm := _joint(Vector3(side*0.335,1.31,0),"Arm")
				_box(Vector3(0,-0.11,0),Vector3(0.18,0.25,0.22),Color("416f72"),"cloth",arm)
				_box(Vector3(0,-0.39,0),Vector3(0.16,0.33,0.19),Color("7d9455" if rotted else "81935d"),"skin",arm)
				arm.rotation.x = 1.35
				arms.append(arm)
				var leg := _joint(Vector3(side*0.13,0.77,0),"Hip")
				_box(Vector3(0,-0.33,0),Vector3(0.21,0.65,0.24),Color("465063"),"cloth",leg)
				_box(Vector3(0,-0.69,-0.035),Vector3(0.22,0.14,0.3),Color("323d40"),"",leg)
				legs.append(leg)
			_box(Vector3(0,0.005,-0.22),Vector3(0.18,0.04,0.02),Color("39412d"),"",head)
			_box(Vector3(0.04,0.012,-0.233),Vector3(0.045,0.027,0.015),Color("c4be8d"),"",head)
		"skeleton":
			_box(Vector3(0,1.08,0.035),Vector3(0.09,0.62,0.1),Color("b6b6a4"),"bone")
			_box(Vector3(0,0.8,0),Vector3(0.34,0.12,0.2),Color("cfcebb"),"bone")
			_box(Vector3(0,1.36,0),Vector3(0.43,0.09,0.15),Color("dddaca"),"bone")
			for y in [0.98,1.12,1.26]:
				for side in [-1,1]:
					_box(Vector3(side*0.105,y,-0.055),Vector3(0.17,0.06,0.18),Color("d5d3bf"),"bone")
			head = _joint(Vector3(0,1.48,0),"Head")
			_box(Vector3(0,0.17,0.02),Vector3(0.4,0.36,0.36),Color("dddaca"),"bone",head)
			for side in [-1,1]:
				_box(Vector3(side*0.103,0.18,-0.17),Vector3(0.12,0.115,0.025),Color("363c39"),"",head)
				_box(Vector3(side*0.103,0.257,-0.178),Vector3(0.15,0.04,0.028),Color("b7b7a5"),"bone",head)
				var leg := _joint(Vector3(side*0.115,0.76,0),"Hip")
				_box(Vector3(0,-0.32,0),Vector3(0.095,0.64,0.11),Color("d5d3bf"),"bone",leg)
				_box(Vector3(0,-0.35,-0.01),Vector3(0.12,0.09,0.13),Color("b8b9a8"),"bone",leg)
				_box(Vector3(0,-0.71,-0.04),Vector3(0.13,0.09,0.23),Color("d5d3bf"),"bone",leg)
				legs.append(leg)
				var arm := _joint(Vector3(side*0.27,1.34,0),"Arm")
				_box(Vector3(0,-0.29,0),Vector3(0.09,0.58,0.1),Color("d5d3bf"),"bone",arm)
				arm.rotation.x = 1.3 if side == 1 else 0.7
				arms.append(arm)
			_box(Vector3(0,0.09,-0.175),Vector3(0.04,0.065,0.03),Color("4c5149"),"",head)
			_box(Vector3(0,-0.035,-0.025),Vector3(0.3,0.055,0.29),Color("d5d3bf"),"bone",head)
			for x in [-0.1,-0.035,0.035,0.1]:
				_box(Vector3(x,0.01,-0.17),Vector3(0.045,0.055,0.025),Color("dddaca"),"bone",head)
			# Bow is attached to the hand and follows the aiming pose.
			var bow := _joint(Vector3(0,-0.57,0),"Bow",arms[1])
			bow.rotation.x = -1.3
			bow_hand = bow
			for i in 5:
				var limb := _box(Vector3(0,(i-2)*0.135,-0.12+absf(i-2)*0.045),Vector3(0.045,0.17,0.045),Color("8b603b"),"wood",bow)
				limb.rotation.x = (i-2)*0.22
			_box(Vector3(0,0,-0.005),Vector3(0.012,0.56,0.012),Color("d5cdb1"),"",bow)
		"spider":
			_box(Vector3(0,0.52,0.28),Vector3(0.72,0.46,0.78),Color("383039"),"shell")
			_box(Vector3(0,0.49,-0.24),Vector3(0.48,0.32,0.4),Color("4b3a3d"),"shell")
			head = _joint(Vector3(0,0.47,-0.55),"Head")
			_box(Vector3.ZERO,Vector3(0.48,0.32,0.36),Color("3c3036"),"shell",head)
			for side in [-1,1]:
				for i in 3:
					var eye := _box(Vector3(side*(0.055+i*0.07),0.06+float(i%2)*0.055,-0.188),Vector3.ONE*(0.075 if i == 0 else 0.045),Color("f04d35"),"",head)
					eye.material_override.emission_enabled = true
					eye.material_override.emission = Color("a52215")
				_box(Vector3(side*0.095,-0.17,-0.2),Vector3(0.055,0.19,0.065),Color("c4ae87"),"bone",head)
			for i in 4:
				for side in [-1,1]:
					var leg := _joint(Vector3(side*0.22,0.47,-0.32+i*0.2),"Leg")
					var upper := _box(Vector3(side*0.26,0.1,0),Vector3(0.58,0.08,0.085),Color("49383e"),"shell",leg)
					upper.rotation.z = side*0.34
					var lower := _box(Vector3(side*0.62,-0.12,0),Vector3(0.075,0.57,0.075),Color("302b32"),"shell",leg)
					lower.rotation.z = side*0.4
					leg.rotation.y = side*(i-1.5)*0.28
					leg.set_meta("rest_y",leg.rotation.y)
					legs.append(leg)
		"creeper":
			_box(Vector3(0,0.86,0.02),Vector3(0.4,0.84,0.3),Color("678c46"),"moss")
			head = _joint(Vector3(0,1.29,0),"Head")
			_box(Vector3(0,0.21,0),Vector3(0.49,0.48,0.46),Color("789e50"),"moss",head)
			for side in [-1,1]:
				_box(Vector3(side*0.115,0.28,-0.237),Vector3(0.105,0.105,0.02),Color("233526"),"",head)
				_box(Vector3(side*0.08,0.085,-0.238),Vector3(0.065,0.11,0.02),Color("233526"),"",head)
			_box(Vector3(0,0.16,-0.239),Vector3(0.1,0.1,0.02),Color("233526"),"",head)
			for x in [-0.13,0.13]:
				for z in [-0.16,0.19]:
					var leg := _joint(Vector3(x,0.43,z),"Hip")
					_box(Vector3(0,-0.19,0),Vector3(0.23,0.38,0.29),Color("547b3e"),"moss",leg)
					_box(Vector3(0,-0.38,-0.015),Vector3(0.23,0.07,0.32),Color("344b2b"),"moss",leg)
					legs.append(leg)
		"magma_cube":
			for i in 4:
				_box(Vector3(0,0.14+i*0.23,0),Vector3(0.84,0.17,0.84),Color("492526"),"moss")
				var core := _box(Vector3(0,0.24+i*0.2,0),Vector3(0.73,0.07,0.73),Color("f28826"))
				core.material_override.emission_enabled = true
				core.material_override.emission = Color("e4551b")
			for side in [-1,1]: _box(Vector3(side*0.2,0.69,-0.431),Vector3(0.15,0.14,0.025),Color("ffca4b"))
		"cow","pig","chicken","sheep","parrot","cat":
			_build_animal()
	# Small anatomical details sharpen the hostile silhouettes.
	if kind in ["piglin","piglin_brute"]:
		for part in parts:
			part.material_override.albedo_texture = CreatureArt.texture("skin",Color("b88b72"))
		_box(Vector3(0,0.1,-0.28),Vector3(0.29,0.16,0.16),Color("d3a088"),"skin",head)
		for side in [-1,1]:
			_box(Vector3(side*0.27,0.22,-0.02),Vector3(0.15,0.24,0.12),Color("bc8c74"),"skin",head)
			_box(Vector3(side*0.095,0.025,-0.33),Vector3(0.045,0.13,0.045),Color("eee0bc"),"bone",head)
		_box(Vector3(0,-0.75,0),Vector3(0.07,0.62,0.06),Color("e9bd48"),"",arms[1])
		_box(Vector3(0,-0.49,0),Vector3(0.25,0.055,0.08),Color("c59635"),"",arms[1])
		if kind == "piglin_brute":
			_box(Vector3(0,1.04,-0.025),Vector3(0.56,0.74,0.4),Color("332c2b"),"cloth")
			_box(Vector3(0,0.77,-0.24),Vector3(0.18,0.15,0.04),Color("e8c253"))
			_box(Vector3(0.14,-0.75,0),Vector3(0.29,0.26,0.09),Color("e8c253"),"",arms[1])
	elif kind == "zombie":
		_box(Vector3(0.15,1.02,-0.151),Vector3(0.075,0.2,0.025),Color("7b8950"),"skin")
		_box(Vector3(-0.15,0.77,-0.15),Vector3(0.1,0.06,0.03),Color("344c55"),"cloth")
	elif kind == "skeleton":
		_box(Vector3(0,1.13,-0.16),Vector3(0.055,0.38,0.055),Color("d5d3bf"),"bone")
		for side in [-1,1]:
			_box(Vector3(side*0.15,0.075,-0.16),Vector3(0.07,0.06,0.055),Color("c0c0ad"),"bone",head)
	elif kind == "spider":
		for side in [-1,1]:
			_box(Vector3(side*0.065,0.0,-0.19),Vector3(0.045,0.045,0.02),Color("f35a32"),"",head)
			_box(Vector3(side*0.21,0.76,0.3),Vector3(0.16,0.025,0.4),Color("745151"),"shell")
	elif kind == "creeper":
		for y in [0.6,0.8,1.0]:
			_box(Vector3(0,y,0.18),Vector3(0.08,0.13,0.035),Color("334e32"),"moss")

func _animal_leg(pos: Vector3, length: float, width_value: float, skin_color: Color, hoof: Color) -> void:
	var leg := _joint(pos,"Hip")
	_box(Vector3(0,-length*0.5,0),Vector3(width_value,length,width_value),skin_color,"fur",leg)
	_box(Vector3(0,-length+0.05,-0.025),Vector3(width_value+0.015,0.1,width_value+0.05),hoof,"",leg)
	legs.append(leg)

func _animal_eyes(parent: Node3D, x: float, y: float, z: float) -> void:
	for side in [-1,1]:
		_box(Vector3(side*x,y,z),Vector3(0.085,0.085,0.022),Color("eee6d7"),"",parent)
		_box(Vector3(side*(x-0.012),y-0.005,z-0.015),Vector3(0.037,0.054,0.018),Color("292629"),"",parent)

func _build_animal() -> void:
	match kind:
		"cow":
			_box(Vector3(0,0.83,0.08),Vector3(0.72,0.65,1.12),Color("f0e7d4"),"cow")
			head = _joint(Vector3(0,1.0,-0.58),"Head")
			_box(Vector3(0,0.04,-0.11),Vector3(0.45,0.46,0.43),Color("f0e7d4"),"cow",head)
			_box(Vector3(0,-0.1,-0.37),Vector3(0.39,0.19,0.18),Color("cfaa9b"),"skin",head)
			_animal_eyes(head,0.135,0.09,-0.334)
			for side in [-1,1]:
				_box(Vector3(side*0.105,-0.08,-0.466),Vector3(0.055,0.042,0.018),Color("644749"),"",head)
				_box(Vector3(side*0.3,0.13,-0.06),Vector3(0.19,0.105,0.14),Color("765743"),"fur",head)
				_box(Vector3(side*0.19,0.34,0),Vector3(0.09,0.18,0.09),Color("ddcdb1"),"bone",head)
			_box(Vector3(0,0.47,0.26),Vector3(0.3,0.15,0.3),Color("d7a398"),"skin")
			for x in [-0.09,0.09]:
				for z in [0.17,0.35]: _box(Vector3(x,0.36,z),Vector3(0.055,0.09,0.055),Color("bd827d"),"skin")
			for x in [-0.25,0.25]:
				for z in [-0.3,0.45]: _animal_leg(Vector3(x,0.52,z),0.51,0.16,Color("d8cbb8"),Color("40372e"))
			var tail := _joint(Vector3(0,0.97,0.65),"Tail")
			_box(Vector3(0,-0.2,0.02),Vector3(0.055,0.4,0.06),Color("d2c4ab"),"fur",tail)
			_box(Vector3(0,-0.42,0.02),Vector3(0.12,0.13,0.1),Color("4a382c"),"fur",tail)
			tail.set_meta("tail",true)
		"pig":
			_box(Vector3(0,0.54,0.06),Vector3(0.65,0.5,0.95),Color("e6a29b"),"pig")
			head = _joint(Vector3(0,0.66,-0.48),"Head")
			_box(Vector3(0,0,-0.07),Vector3(0.46,0.42,0.39),Color("ecada6"),"pig",head)
			_box(Vector3(0,-0.055,-0.32),Vector3(0.26,0.17,0.14),Color("d78989"),"skin",head)
			_animal_eyes(head,0.15,0.07,-0.273)
			for side in [-1,1]:
				_box(Vector3(side*0.065,-0.05,-0.394),Vector3(0.045,0.065,0.016),Color("925258"),"",head)
				var ear := _box(Vector3(side*0.18,0.22,0),Vector3(0.13,0.18,0.075),Color("d98f94"),"skin",head)
				ear.rotation.z = side*0.3
			for x in [-0.22,0.22]:
				for z in [-0.27,0.38]: _animal_leg(Vector3(x,0.3,z),0.29,0.16,Color("dc9794"),Color("9a6663"))
			# A squared curl, clearly visible from behind.
			for part in [Vector3(0,0.6,0.6),Vector3(0.08,0.6,0.65),Vector3(0.08,0.68,0.65),Vector3(0.015,0.7,0.65)]:
				_box(part,Vector3(0.08,0.06,0.06),Color("cf868a"),"pig")
		"parrot":
			# A perched bird: a red body with blue wing tips, a hooked grey beak and
			# a fanned tail. The source's parrots are red with blue markings.
			_box(Vector3(0,0.5,0.03),Vector3(0.26,0.3,0.38),Color("c0392b"),"feather")
			head = _joint(Vector3(0,0.72,-0.16),"Head")
			_box(Vector3(0,0.04,0),Vector3(0.21,0.22,0.2),Color("c94a35"),"feather",head)
			# The hooked beak points down, which is what tells a parrot from a chicken.
			_box(Vector3(0,0.03,-0.14),Vector3(0.1,0.1,0.09),Color("4a4a4a"),"",head)
			_box(Vector3(0,-0.05,-0.15),Vector3(0.07,0.08,0.06),Color("3a3a3a"),"",head)
			for side in [-1,1]:
				_box(Vector3(side*0.1,0.08,-0.09),Vector3(0.045,0.045,0.02),Color("f2e9d8"),"",head)
				_box(Vector3(side*0.055,0.07,-0.085),Vector3(0.02,0.02,0.012),Color("1c1c1c"),"",head)
				var wing := _joint(Vector3(side*0.15,0.62,0.02),"Wing")
				_box(Vector3(side*0.02,-0.08,0),Vector3(0.07,0.2,0.3),Color("2b6ca3"),"feather",wing)
				arms.append(wing)
				var leg := _joint(Vector3(side*0.07,0.36,0.01),"Hip")
				_box(Vector3(0,-0.09,0),Vector3(0.04,0.18,0.04),Color("6f6f6f"),"",leg)
				for toe in [-1,0,1]: _box(Vector3(toe*0.032,-0.19,-0.05),Vector3(0.024,0.03,0.12),Color("6f6f6f"),"",leg)
				legs.append(leg)
			for i in 3:
				_box(Vector3((i-1)*0.06,0.42,0.3),Vector3(0.065,0.26,0.08),Color("8e44ad"),"feather")
		"cat":
			# A small quadruped with a raised tail and pointed ears. A cat spawned by
			# a witch hut is all black, which the source sets explicitly.
			_box(Vector3(0,0.3,0),Vector3(0.28,0.24,0.55),Color("2c2c2c"),"fur")
			head = _joint(Vector3(0,0.42,-0.3),"Head")
			_box(Vector3(0,0.02,0),Vector3(0.24,0.22,0.22),Color("2c2c2c"),"fur",head)
			for side in [-1,1]:
				# Pointed ears, which is what tells a cat from a small dog.
				_box(Vector3(side*0.08,0.17,0.02),Vector3(0.07,0.09,0.05),Color("232323"),"fur",head)
				_box(Vector3(side*0.07,0.02,-0.12),Vector3(0.045,0.035,0.02),Color("c9d16a"),"",head)
				var leg := _joint(Vector3(side*0.09,0.18,-0.18),"Hip")
				_box(Vector3(0,-0.09,0),Vector3(0.06,0.18,0.06),Color("2c2c2c"),"fur",leg)
				legs.append(leg)
			var tail := _joint(Vector3(0,0.36,0.28),"Tail")
			tail.rotation.x = -0.9
			_box(Vector3(0,0.1,0),Vector3(0.05,0.26,0.05),Color("232323"),"fur",tail)
		"chicken":
			_box(Vector3(0,0.39,0.04),Vector3(0.34,0.32,0.46),Color("eeeadd"),"feather")
			head = _joint(Vector3(0,0.58,-0.18),"Head")
			_box(Vector3(0,0.08,0),Vector3(0.24,0.28,0.23),Color("f5f0e5"),"feather",head)
			_box(Vector3(0,0.28,0.01),Vector3(0.055,0.13,0.18),Color("b93d35"),"skin",head)
			_box(Vector3(0,0.05,-0.18),Vector3(0.17,0.09,0.15),Color("dfa33d"),"",head)
			_box(Vector3(0,-0.055,-0.14),Vector3(0.075,0.13,0.07),Color("c83e35"),"skin",head)
			for side in [-1,1]:
				_box(Vector3(side*0.124,0.12,-0.06),Vector3(0.016,0.055,0.055),Color("292a27"),"",head)
				var wing := _joint(Vector3(side*0.19,0.5,0.025),"Wing")
				_box(Vector3(side*0.025,-0.09,0),Vector3(0.09,0.24,0.34),Color("d9d8c8"),"feather",wing)
				arms.append(wing)
				var leg := _joint(Vector3(side*0.09,0.25,0.015),"Hip")
				_box(Vector3(0,-0.11,0),Vector3(0.045,0.22,0.045),Color("dba143"),"",leg)
				for toe in [-1,0,1]: _box(Vector3(toe*0.038,-0.23,-0.065),Vector3(0.028,0.035,0.15),Color("dba143"),"",leg)
				legs.append(leg)
			for i in 3:
				var feather := _box(Vector3((i-1)*0.075,0.52,0.32),Vector3(0.08,0.3,0.09),Color("dedccc"),"feather")
				feather.rotation.x = 0.5
		"sheep":
			_box(Vector3(0,0.65,0.05),Vector3(0.57,0.44,0.85),Color("b9a78b"),"fur").set_meta("sheep_skin",true)
			wool_parts.append(_box(Vector3(0,0.74,0.07),Vector3(0.76,0.64,1.0),Color("e5dfce"),"wool"))
			head = _joint(Vector3(0,0.91,-0.51),"Head")
			_box(Vector3(0,-0.07,-0.11),Vector3(0.35,0.38,0.37),Color("b5a083"),"fur",head)
			wool_parts.append(_box(Vector3(0,0.14,-0.025),Vector3(0.46,0.19,0.38),Color("ede7d8"),"wool",head))
			_animal_eyes(head,0.115,0.015,-0.305)
			_box(Vector3(0,-0.18,-0.32),Vector3(0.21,0.12,0.09),Color("aa8d7b"),"skin",head)
			_box(Vector3(0,-0.21,-0.37),Vector3(0.09,0.02,0.015),Color("60554a"),"",head)
			for side in [-1,1]: _box(Vector3(side*0.24,0.0,-0.02),Vector3(0.15,0.08,0.13),Color("b3a18b"),"fur",head)
			for x in [-0.22,0.22]:
				for z in [-0.27,0.38]:
					_animal_leg(Vector3(x,0.45,z),0.44,0.14,Color("aa967b"),Color("5b5144"))
					wool_parts.append(_box(Vector3(x,0.46,z),Vector3(0.24,0.22,0.25),Color("e5dfce"),"wool"))
			wool_parts.append(_box(Vector3(0,0.6,0.62),Vector3(0.21,0.28,0.16),Color("e5dfce"),"wool"))

func _joint(pos: Vector3, label: String, parent: Node3D = null) -> Node3D:
	var joint := Node3D.new()
	joint.name = label
	joint.position = pos
	(parent if parent != null else model).add_child(joint)
	return joint

func _box(pos: Vector3, size_value: Vector3, color: Color, skin: String = "", parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = CreatureArt.cuboid(size_value)
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = CreatureArt.texture(skin,color)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	instance.material_override = mat
	(parent if parent != null else model).add_child(instance)
	parts.append(instance)
	colors.append(Color.WHITE)
	tint_applied = []
	box_count += 1
	return instance

# Boxes that move together are drawn as one mesh, and the merged meshes of a
# creature share one material over an atlas of their skins: a creature costs a
# draw call per joint instead of one per box. Boxes that may change later stay
# apart: those another variable refers to, those with children, metadata or a
# customised material, and every box of a shulker, which moves one by index.
static var skin_atlases: Dictionary = {}
# Merged meshes by an exact key of their boxes, shared by creatures built alike.
static var merged_meshes: Dictionary = {}
# Per script, the variables other than `parts` that can refer to a box.
static var box_references: Dictionary = {}

func merge_parts() -> void:
	if kind == "shulker": return
	var names: Variant = box_references.get(get_script())
	if names == null:
		names = []
		for property in get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0 or property.name == "parts": continue
			if property.type in [TYPE_NIL,TYPE_OBJECT,TYPE_ARRAY,TYPE_DICTIONARY]: names.append(property.name)
		box_references[get_script()] = names
	var kept: Dictionary = {}
	for property_name in names:
		var value: Variant = get(property_name)
		var items: Array = value.values() if value is Dictionary else (value if value is Array else [value])
		for item in items:
			if item is MeshInstance3D: kept[item] = true
	var groups: Dictionary = {}
	for part in parts:
		if kept.has(part) or not _plain_part(part): continue
		var parent: Node = part.get_parent()
		if not groups.has(parent): groups[parent] = []
		groups[parent].append(part)
	var textures: Array = []
	for parent in groups.keys():
		if groups[parent].size() < 2: groups.erase(parent); continue
		for box in groups[parent]:
			if not textures.has(box.material_override.albedo_texture): textures.append(box.material_override.albedo_texture)
	if groups.is_empty(): return
	var material := StandardMaterial3D.new()
	material.albedo_texture = _skin_atlas(textures)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	var merged_boxes: Dictionary = {}
	var meshes: Array = []
	for parent in groups:
		var key: Array = [textures.size()]
		for box in groups[parent]:
			key.append(box.mesh.get_instance_id()); key.append(box.transform); key.append(textures.find(box.material_override.albedo_texture))
			merged_boxes[box] = true
		var hash_value: int = key.hash()
		var cached: Variant = merged_meshes.get(hash_value)
		if cached == null or cached[0] != key:
			cached = [key,_merged_mesh(groups[parent],textures)]
			merged_meshes[hash_value] = cached
		var merged := MeshInstance3D.new()
		merged.mesh = cached[1]; merged.material_override = material
		parent.add_child(merged)
		meshes.append(merged)
	var kept_parts: Array = []; var kept_colors: Array = []
	for i in parts.size():
		if merged_boxes.has(parts[i]): parts[i].free()
		else: kept_parts.append(parts[i]); kept_colors.append(colors[i])
	parts = kept_parts+meshes
	colors = kept_colors
	for mesh in meshes: colors.append(Color.WHITE)
	tint_applied = []

static func _merged_mesh(boxes: Array, textures: Array) -> ArrayMesh:
	var width: float = textures.size()*18.0
	var vertices := PackedVector3Array(); var normals := PackedVector3Array(); var uvs := PackedVector2Array(); var indices := PackedInt32Array()
	for box in boxes:
		var arrays: Array = box.mesh.surface_get_arrays(0)
		var offset: int = vertices.size()
		var xform: Transform3D = box.transform
		var normal_basis: Basis = xform.basis.inverse().transposed()
		# Each skin sits one texel inside its 18-texel cell, so nearest filtering
		# reads the same texels as the skin on its own.
		var left: float = textures.find(box.material_override.albedo_texture)*18.0+1.0
		for v in arrays[Mesh.ARRAY_VERTEX]: vertices.append(xform*v)
		for n in arrays[Mesh.ARRAY_NORMAL]: normals.append((normal_basis*n).normalized())
		for uv in arrays[Mesh.ARRAY_TEX_UV]: uvs.append(Vector2((left+uv.x*16.0)/width,(1.0+uv.y*16.0)/18.0))
		for index in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+index)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

# A box exactly as `_box` made it, with a 16x16 skin. Creature code changes only
# emission, transparency and the albedo alpha, so those are what is compared.
func _plain_part(part: Variant) -> bool:
	if not part is MeshInstance3D or not is_instance_valid(part) or part.get_child_count() > 0 or not part.get_meta_list().is_empty(): return false
	if not part.visible or part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON or part.transparency != 0.0: return false
	if not part.mesh is ArrayMesh or part.mesh.get_surface_count() != 1: return false
	var mat: Variant = part.material_override
	if not mat is StandardMaterial3D or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.emission_enabled or mat.albedo_color != Color.WHITE: return false
	if mat.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST or mat.roughness != 1.0: return false
	var skin: Variant = mat.albedo_texture
	return skin is Texture2D and skin.get_width() == 16 and skin.get_height() == 16

# One row of 18x18 cells, each skin framed by the texels of its opposite edges,
# as the repeating skin on its own would read past an edge.
static func _skin_atlas(textures: Array) -> Texture2D:
	var key: String = ""
	for texture in textures: key += str(texture.get_instance_id())+","
	if skin_atlases.has(key): return skin_atlases[key]
	var image := Image.create(textures.size()*18,18,false,Image.FORMAT_RGBA8)
	for i in textures.size():
		var skin: Image = textures[i].get_image()
		if skin.get_format() != Image.FORMAT_RGBA8: skin.convert(Image.FORMAT_RGBA8)
		var x: int = i*18
		image.blit_rect(skin,Rect2i(0,0,16,16),Vector2i(x+1,1))
		image.blit_rect(skin,Rect2i(0,15,16,1),Vector2i(x+1,0)); image.blit_rect(skin,Rect2i(0,0,16,1),Vector2i(x+1,17))
		image.blit_rect(skin,Rect2i(15,0,1,16),Vector2i(x,1)); image.blit_rect(skin,Rect2i(0,0,1,16),Vector2i(x+17,1))
	var atlas := ImageTexture.create_from_image(image)
	skin_atlases[key] = atlas
	return atlas

func animate(delta: float, chasing: bool = false) -> void:
	var moving: bool = direction.length() > 0.1
	gait = move_toward(gait,1.0 if moving else 0.0,delta*5.0)
	for i in legs.size():
		var phase: float = (i/2+i%2)*PI if legs.size() == 4 or kind == "spider" else i*PI
		var swing: float = sin(life*8+phase)*0.4*gait
		if kind == "spider":
			legs[i].rotation.y = float(legs[i].get_meta("rest_y",0.0))+swing*0.5
			legs[i].rotation.z = sin(life*8+phase+PI/2)*0.1*gait
		else: legs[i].rotation.x = swing
	for i in arms.size():
		if kind == "chicken":
			arms[i].rotation.z = (-1 if i == 0 else 1)*(0.12+absf(sin(life*14))*(0.8 if not grounded else 0.08))
			continue
		var rest: float = 1.35 if kind in ["zombie","piglin","piglin_brute"] else (1.3 if i == 1 else 0.7)
		arms[i].rotation.x = rest+sin(life*4+i)*0.07+sin(life*8+i*PI)*gait*0.1
	for child in model.get_children():
		if child.has_meta("tail"): child.rotation.z = sin(life*2.6)*0.2
	if head != null:
		head.rotation.x = -0.8+sin(life*12)*0.08 if kind == "sheep" and grazing > 0 else sin(life*1.8)*0.035
		if chasing:
			var target: Vector3 = model.to_local(game.player.position+Vector3.UP*1.5)
			head.rotation.y = lerp_angle(head.rotation.y,clampf(atan2(-target.x,-target.z),-0.6,0.6),delta*5)
		else: head.rotation.y = sin(life*0.8)*0.08

func info() -> Dictionary:
	return KINDS[kind]

# The source's `armor`, which is a percentage of the damage a mob **takes** from a
# given group — not a resistance. A mob with `armor = 100` takes everything; one with
# `{undead = 90, fleshy = 90}` takes ninety percent of either, and a group the table
# omits deals **nothing at all**, which is what makes a bow useless against a mob that
# only accepts `fleshy`.
#
# A plain number is the source's shorthand for `{fleshy = <number>}`.
# Damage that is a *type* rather than a punch group. The source's punch path scales by
# `armor`, but its typed damage (`mcl_damage`) does not: lightning, magic, freezing and
# the environment are all outside the table.
# Damage that is a *type* rather than a melee punch. The source's `armor` table is
# consulted on its punch path only; everything it routes through `mcl_damage` —
# lightning, arrows, fireballs, magic, freezing, the environment — is outside it.
const BYPASSES_ARMOR = ["magic","environment","freeze","starve","void","lightning","arrow","fireball","snowball","explosion","charged_explosion"]

func armor_factor(reason: String) -> float:
	var armor: Variant = info().get("armor",100)
	if armor is int or armor is float: return float(armor)/100.0
	var table: Dictionary = armor
	return float(table.get(group_for(reason),0))/100.0

# Voxey's damage reasons mapped to the source's damage groups. Only a thrown snowball
# deals `snowball_vulnerable` and only a water potion deals `water_vulnerable`; every
# other physical blow is an ordinary `fleshy` one. The source's own group names pass
# through unchanged, which is what the enchantment bonuses use.
static func group_for(reason: String) -> String:
	if reason == "snowball": return "snowball_vulnerable"
	if reason == "water_potion": return "water_vulnerable"
	if reason in ["undead","arthropod","fleshy","snowball_vulnerable","water_vulnerable"]: return reason
	return "fleshy"

# The source's `xp_min`/`xp_max`, which are equal for every mob in the checkout, so a
# kill always pays a fixed amount. `xp` carries that value where it differs from the
# old flat award; a passive mob the source gives nothing (a villager, a golem) keeps
# its existing value.
func xp_reward() -> int:
	# The source's `xp_min` defaults to zero, so a mob that does not declare one is
	# worth nothing. Voxey's old flat award was a guess rather than a reading.
	return int(info().get("xp",0))

# The source's `reach`, which defaults to three. `gap` is measured centre to centre,
# and a mob's own width is added since the source measures from its collision box.
func melee_reach() -> float:
	return float(info().get("reach",3)) + width

# The weather step every mob shares, extracted because a flying mob overrides
# `_physics_process` and would otherwise never run it: a blaze that skips the burn
# and water rules is a blaze that cannot be put out by rain.
#
# The source's `_water_sensitive` mobs take one damage every half second while standing
# in water or out in the rain, and the rain also extinguishes them. It is what makes
# water a blaze's counter and an enderman's hazard.
#
# Returns false when the mob died, so the caller stops.
func weather_step(delta: float) -> bool:
	var data: Dictionary = info()
	# An `ignited_by_sunlight` mob burns in daylight, which is the source's own name
	# for the `burns` flag.
	if data.get("burns",false) and not has_meta("effect_fire_resistance") and game.daylight > 0.8 and position.y > _surface_height():
		health -= delta*0.8
		if fmod(life,0.4) < delta: game.puff(center(),Color("f0a23a"),3)
		if health <= 0: Farming.forget(self); queue_free(); return false
	# Powder snow freezes a mob, which is the source's `can_freeze`. It slows to a
	# standstill over seven seconds and then takes one damage every two, and it puts
	# out a burning mob — which is why powder snow is a fire escape.
	if data.get("can_freeze",true) and in_powder_snow():
		frozen_for = minf(frozen_for+delta,FREEZE_SECONDS)
		# Powder snow also puts a burning mob out, which is why it is a fire escape.
		if has_meta("effect_burning"): remove_meta("effect_burning")
		# The damage clock only runs once the mob is fully frozen, so a mob passing
		# through a shallow drift is slowed but never hurt.
		if frozen_for >= FREEZE_SECONDS:
			freeze_clock += delta
			if freeze_clock >= FREEZE_INTERVAL:
				freeze_clock -= FREEZE_INTERVAL
				hit(1.0,Vector3.INF,"freeze")
				if health <= 0: Farming.forget(self); queue_free(); return false
		else: freeze_clock = 0.0
	elif frozen_for > 0.0: frozen_for = maxf(0.0,frozen_for-delta); freeze_clock = 0.0
	if not data.get("water_sensitive",false): return true
	var cell := Vector3i(position.floor())
	var wet: bool = cell.y >= 0 and Fluids.water(game.world.node_at(cell)) or cell.y > 0 and Fluids.water(game.world.node_at(cell-Vector3i.UP))
	var rained_on: bool = Weather.exposed_to_rain(game.world,cell)
	if not (wet or rained_on): water_clock = 0.0; return true
	# Rain puts the mob out, which the source does before applying its damage.
	if rained_on and has_meta("effect_burning"): remove_meta("effect_burning")
	water_clock += delta
	if water_clock >= WEATHER_INTERVAL:
		water_clock = 0.0
		hit(1.0,Vector3.INF,"environment")
		if health <= 0: Farming.forget(self); queue_free(); return false
	return true

# The nearest villager within sight, for a mob the source gives `attack_npcs`. The
# distance is the source's `view_range`, and line of sight is required so a zombie
# does not claw at a wall.
func nearest_villager() -> Node3D:
	var best: Node3D = null
	var best_distance: float = 16.0
	for mob in game.creatures.get_children():
		if not mob is VillageMob or mob.is_queued_for_deletion() or mob.kind != "villager": continue
		var d: float = position.distance_to(mob.position)
		if d >= best_distance: continue
		if not _sees(mob.position+Vector3.UP*mob.height*0.6): continue
		best = mob; best_distance = d
	return best

func center() -> Vector3:
	return position+Vector3.UP*height*0.55

func aggressive() -> bool:
	if not hostile or game.gamemode == "creative" or (not provoked and PotionEffects.level(game.player,"invisibility") > 0 and position.distance_to(game.player.position) > 2+game.player.armor_points()*0.35): return false
	if info().get("neutral_by_day",false) and game.daylight >= 0.5 and not provoked: return false
	# The source's `_neutral_to_players`: a zombified piglin ignores players until
	# one strikes it, which is the whole point of it being neutral rather than hostile.
	if info().get("neutral",false) and not provoked: return false
	return true

func _engine_step(delta: float) -> float:
	if not Engine.is_in_physics_frame(): return delta
	step_delta += delta
	var frame: int = Engine.get_process_frames()
	if frame == step_frame and step_delta < 1.0/30.0: return -1.0
	step_frame = frame
	var elapsed: float = step_delta
	step_delta = 0.0
	return elapsed

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	delta = _engine_step(delta)
	if delta < 0.0: return
	if game.leads.sleep_if_unloaded(self): return
	if Farming.sleep_if_unloaded(self): return
	if not custom_name.is_empty() and not Farming.managed(self) and (not game.world.loaded_at(position) or position.distance_to(game.player.position) > 90): return
	Farming.tick(self,delta)
	life += delta
	attack_cooldown = maxf(0,attack_cooldown-delta)
	leap_cooldown = maxf(0,leap_cooldown-delta)
	scared = maxf(0,scared-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	if spawn_invulnerable > 0.0: spawn_invulnerable = maxf(0,spawn_invulnerable-delta)
	ambient -= delta
	if kind == "chicken" and growth_remaining <= 0:
		egg_timer -= delta
		if egg_timer <= 0:
			game.spawn_drop(position+Vector3.UP*0.3,Nodes.EGG)
			egg_timer = randi_range(300,600)
	var player_pos: Vector3 = game.player.position
	var distance: float = position.distance_to(player_pos)
	var data: Dictionary = info()
	# The source's `can_despawn` defaults to false, and only twelve mobs opt in — so a
	# piglin, a shulker, a villager, an evoker or the wither is *never* removed for
	# distance. Everything else despawns once it is well out of sight, which is what
	# keeps a night's spawns from accumulating.
	if distance > 90 and data.get("can_despawn",false): queue_free(); return
	# A mob that may not despawn still stops simulating when it is far away, so a
	# distant piglin costs nothing while it waits.
	if distance > 220: return
	if not game.world.loaded_at(position): return
	think -= delta
	if think <= 0:
		think = randf_range(1.5,4.0)
		direction = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized() if randf()>0.35 else Vector3.ZERO
	var toward: Vector3 = ((player_pos-position)*Vector3(1,0,1)).normalized()
	# Mobs keep hunting for a few seconds after losing sight, then give up.
	# Only a hostile mob ever chases, so only it needs to look.
	sight_timer -= delta
	if hostile and sight_timer <= 0 and distance < SIGHT_RANGE:
		sight_timer = SIGHT_INTERVAL
		if _sees_player(): last_seen = life
	var chasing: bool = aggressive() and distance < 24 and life-last_seen < 4.0
	# The source gives a zombie `attack_npcs = true`, so it goes for a villager as
	# readily as for the player, and takes whichever is nearer. Without this a
	# zombie never lands the killing blow that infects a villager, so the infection
	# rule below could never fire.
	if data.get("hunts_villagers",false) and not (scared > 0 and not hostile):
		prey_timer -= delta
		if prey_timer <= 0 or prey_choice != null and (not is_instance_valid(prey_choice) or prey_choice.is_queued_for_deletion()):
			prey_timer = 0.25
			prey_choice = nearest_villager()
		var prey: Node3D = prey_choice
		if prey != null:
			var to_prey: Vector3 = ((prey.position-position)*Vector3(1,0,1)).normalized()
			if not chasing or prey.position.distance_to(position) < distance:
				direction = to_prey
				toward = to_prey
				chasing = true
				prey_target = prey
	elif prey_target != null: prey_target = null
	if chasing:
		if data.get("ranged",false):
			direction = -toward if distance < 5 else (toward if distance > 9 else Vector3.ZERO)
		else: direction = toward
	# A mob that has just been hit runs *away* from whoever hit it, which overrides the
	# chase: the source's `runaway` is independent of hostility, so a struck creeper
	# backs off rather than only ever advancing.
	if scared > 0: direction = -toward
	# The source's `runaway_from = {"players"}` with `runaway_view_range = 8`: a fish
	# keeps away from a nearby player without being provoked first.
	elif data.get("flees",false) and distance < AquaticMobs.FLEE_RANGE and distance > 0.1: direction = -toward
	var farm_direction: Vector3 = Vector3.INF
	if game.leads.player_attached(self): direction = toward if distance > 2.5 else Vector3.ZERO
	elif Farming.supports(kind):
		farm_direction = Farming.direction(self)
		if farm_direction != Vector3.INF: direction = farm_direction
	if Farming.graze(self,delta,scared <= 0 and not game.leads.attached(self) and farm_direction == Vector3.INF): direction = Vector3.ZERO
	# A frozen mob is slowed in proportion to how long it has been in the snow, which
	# is the source's `-1.0 * t / 7.0` factor: a full seven seconds stops it dead.
	var speed: float = data.speed*PotionEffects.speed(self)*(1.0-frozen_for/FREEZE_SECONDS)
	if not hostile and scared > 0: speed = 3.0
	if data.get("explodes",false):
		if chasing and distance < 3.2:
			if fuse == 0: game.sound_at("creeper",position)
			fuse += delta
			direction = Vector3.ZERO
			if fuse >= 1.5:
				game.explode(center(),Heads.CHARGED_RADIUS if charged else 2.6,self)
				Farming.forget(self)
				queue_free()
				return
		elif fuse > 0: fuse = maxf(0,fuse-delta*2)
	if chasing and data.get("ranged",false):
		model.rotation.y = lerp_angle(model.rotation.y,atan2(-toward.x,-toward.z),delta*5)
		# A guardian charges its laser for the source's delay, then fires; inside
		# three blocks it paces instead of attacking, as `get_active_target` does.
		if Guardians.is_guardian(kind):
			if distance <= Guardians.MIN_ATTACK_DISTANCE:
				laser = 0.0
			else:
				if laser <= 0.0: laser = Guardians.laser_delay(kind); game.sound_at("guardian",position,data.pitch)
				laser -= delta
				if laser <= 0.0:
					game.player.hurt(Guardians.MAGIC_DAMAGE+data.damage,false,position,"magic")
					game.puff(game.player.position+Vector3.UP,Color("b98adf"),12,2.0)
					laser = Guardians.laser_delay(kind)
	elif direction.length() > 0.1:
		var facing: float = lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*5)
		if absf(angle_difference(facing,model.rotation.y)) > 0.0001: model.rotation.y = facing
	knock = knock.move_toward(Vector3.ZERO,delta*12)
	velocity.x = direction.x*speed+knock.x
	velocity.z = direction.z*speed+knock.z
	# A guardian swims: it holds its depth in water rather than falling, which is
	# the source's `swims = true` behaviour.
	# A wither flies: it holds its altitude above the target rather than falling.
	if data.get("flies",false) and kind == "wither":
		var want: float = game.player.position.y+4.0
		velocity.y = clampf((want-position.y)*0.8,-3.0,3.0)
	elif data.get("swims",false) and Fluids.water(game.world.node_at(Vector3i(position.floor()))):
		velocity.y = knock.y*0.2
		if chasing and distance > Guardians.MIN_ATTACK_DISTANCE:
			velocity.y = clampf((game.player.position.y-position.y)*0.5,-2.0,2.0)
	elif data.get("floats",true) and submerged():
		# The source gives almost every mob `floats = 1` by default, so a land mob
		# that walks into deep water **bobs up** instead of sinking to the bottom. It
		# applies while the mob is under the surface, and it holds at the waterline
		# rather than launching it out, which is the source's `LIQUID_JUMP_THRESHOLD`.
		var surface: float = float(water_surface())+1.0
		var depth: float = surface-position.y
		velocity.y = clampf(depth*2.0,-1.6,2.4)
	else:
		velocity.y = maxf(-25,velocity.y-22*delta)
	if data.get("glides",false) and velocity.y < -1.6: velocity.y = -1.6
	# Move in a local first: every assignment to `position` pushes a transform
	# update through each part of the model.
	grounded = false
	var moved: Vector3 = position
	for axis in [0,2,1]:
		# A still axis cannot collide anew; only an embedded mob would differ.
		if axis != 1 and velocity[axis] == 0.0: continue
		var next: Vector3 = moved
		next[axis] += velocity[axis]*delta
		if not game.world.intersects(next,width,height): moved = next
		elif axis == 1:
			if velocity.y < 0: grounded = true
			velocity.y = 0
		elif game.world.intersects(moved-Vector3.UP*0.08,width,1.0) and not game.world.intersects(moved+Vector3.UP*1.05,width,height): velocity.y = 7.2
	if not grounded and game.world.intersects(moved-Vector3.UP*0.04,width,0.5): grounded = true
	if moved != position: position = moved
	# Beyond the fog's far edge a pose cannot be seen. Several engine ticks in
	# one slow frame share a single pose update; direct calls always animate.
	if distance < 64:
		anim_delta += delta
		if not Engine.is_in_physics_frame() or Engine.get_process_frames() != anim_frame:
			anim_frame = Engine.get_process_frames()
			animate(anim_delta,chasing)
			anim_delta = 0.0
	if data.get("explodes",false):
		model.scale = Vector3.ONE*(1.0+fuse*0.25)
		_tint(Color.WHITE,0.7 if fuse > 0 and int(fuse*12)%2 == 0 else 0.0)
	if hurt_flash > 0: _tint(Color("d8402f"),0.55)
	elif tinted and not data.get("explodes",false): _tint(Color.WHITE,0.0)
	if chasing and data.damage > 0:
		# A hunt for a villager strikes the villager, not the player, so the victim
		# is whichever target the chase settled on.
		var on_prey: bool = prey_target != null and is_instance_valid(prey_target) and not prey_target.is_queued_for_deletion()
		var gap: float = distance if not on_prey else position.distance_to(prey_target.position)
		# The source gives each mob its own `reach` (default three), so a wither swings
		# five blocks out while a zombie needs to be within two. Voxey used one fixed
		# value for every mob, which made a wither harmless at its own range.
		if gap <= melee_reach() and attack_cooldown <= 0 and not data.get("ranged",false):
			attack_cooldown = 1.1
			if on_prey: prey_target.hit(maxf(0,data.damage*PotionEffects.melee(self)),position)
			else: game.player.hurt(maxf(0,data.damage*PotionEffects.melee(self)),false,position)
			if data.voice != "": game.sound_at(data.voice,position,data.pitch*1.15)
		if data.get("leaps",false) and distance < 5 and distance > 1.5 and grounded and leap_cooldown <= 0:
			leap_cooldown = 2.4
			velocity.y = 6.0
			knock = toward*4.5
		if data.get("ranged",false) and distance < 15 and attack_cooldown <= 0 and _sees_player() and facing_player():
			attack_cooldown = 2.2
			var forward: Vector3 = -model.global_basis.z
			var origin: Vector3 = bow_hand.global_position+forward*0.15 if bow_hand != null else position+Vector3.UP*1.45+forward*0.4
			var pitch: float = (player_pos.y+1.1-origin.y)/maxf(1.0,Vector2(player_pos.x-origin.x,player_pos.z-origin.z).length())
			var aim: Vector3 = (forward+Vector3.UP*pitch).normalized()*15+Vector3.UP*distance*0.22
			var arrow: Arrow = game.spawn_arrow(origin,aim)
			arrow.shooter_kind = kind; arrow.shooter_id = get_instance_id()
	# A curing zombie villager advances its cure and shakes while it does.
	ZombieVillagers.update(game,self,delta)
	# An elder guardian fatigues nearby players on its own sixty-second cycle,
	# which is the source's own aura.
	if Guardians.is_elder(kind): GuardianAuras.aura_step(game,self,delta)
	# The weather rules live in one place so a flying mob can run them too.
	if not weather_step(delta): return
	# A hostile mob that survives daylight out of sight despawns, which the source
	# does in its own step rather than as part of the burning rule.
	if hostile and custom_name.is_empty() and not Farming.managed(self) and not data.get("burns",false) and game.daylight > 0.8 and distance > 32 and randf() < delta*0.05:
		queue_free()
		return
	if ambient <= 0:
		ambient = randf_range(4.0,10.0) if hostile else randf_range(6.0,16.0)
		if data.voice != "" and distance < 30: game.sound_at(data.voice,position,data.pitch*randf_range(0.94,1.06))

func facing_player() -> bool:
	var toward: Vector3 = ((game.player.position-position)*Vector3(1,0,1)).normalized()
	return (-model.global_basis.z).dot(toward) >= cos(deg_to_rad(5.0))

func _sees_player() -> bool:
	return _sees(game.player.position+Vector3.UP*1.1)

# Line-of-sight via voxel DDA between the mob's eye and a point; walls and other
# opaque nodes block vision, water and plants do not.
func _sees(point: Vector3) -> bool:
	var origin: Vector3 = position+Vector3.UP*height*0.85
	var to_point: Vector3 = point-origin
	if to_point.length() < 0.01: return true
	var hit: Dictionary = game.world.raycast(origin,to_point.normalized(),to_point.length())
	return hit.is_empty() or hit.distance >= to_point.length()-0.35

func _tint(color: Color, amount: float) -> void:
	tinted = amount > 0
	var applied: Array = [color,amount,parts.size()]
	if applied == tint_applied: return
	tint_applied = applied
	for i in parts.size():
		var mat: StandardMaterial3D = parts[i].material_override
		mat.albedo_color = colors[i].lerp(color,amount)

# A blow can carry bonuses that belong to different damage groups, which is how the
# source's enchantments work: Sharpness adds `fleshy`, Smite `undead` and Bane of
# Arthropods `arthropod`, and each is scaled by the target's own `armor` for its group.
# So a wither's `undead = 80` cuts a Smite bonus by a fifth, which the flat addition this
# replaced could not express. They accumulate per group rather than sharing one slot,
# because an enchantment set can carry more than one.
var bonuses: Dictionary = {}

# Registers a grouped bonus and returns the damage it contributes after this mob's own
# armor for that group, so the caller can report a total a player would recognise while
# `hit` still applies the group correctly.
func add_bonus(group: String, amount: float) -> float:
	if amount <= 0.0: return 0.0
	bonuses[group] = float(bonuses.get(group,0.0))+amount
	return amount*armor_factor(group)

func hit(damage: float, from: Vector3 = Vector3.INF, reason: String = "") -> void:
	# A summoning boss cannot be hurt while it rises, as the source's `_spawning`
	# counter arranges, and the armoured phase halves incoming arrow damage.
	if spawn_invulnerable > 0.0: return
	if kind == "wither" and health < info().health/2.0 and reason == "arrow": return
	if kind == "wither" and health < info().health/2.0: damage *= 0.5
	if reason == "charged_explosion": killed_by_charged = true
	if is_inf(from.x): from = game.player.position
	# A guardian answers a melee attacker with the source's two thorns damage. The
	# attacker is whoever is standing where the blow came from, so the retaliation
	# goes back to them rather than to the player unconditionally.
	if Guardians.is_guardian(kind) and not is_inf(from.x) and GuardianAuras.retaliates(self,false,false):
		GuardianAuras.thorns(self,GuardianAuras.attacker_at(game,from,self))
	PotionEffects.damaged(self)
	# The source's `armor` table scales damage **per damage group**, so a zombie shrugs
	# off part of an ordinary blow and a blaze accepts a snowball. Magic is not a group
	# at all — the source's potions write health directly — so a named non-physical
	# reason bypasses the table entirely.
	var armor_applies: bool = reason not in BYPASSES_ARMOR
	var scaled: float = damage if not armor_applies else damage*armor_factor(reason)
	# The grouped bonus is scaled by its own group, which is the part that makes Smite
	# and Bane interact with a mob's armor rather than bypassing it.
	if not bonuses.is_empty():
		for group in bonuses:
			scaled += float(bonuses[group])*(armor_factor(group) if armor_applies else 1.0)
		bonuses.clear()
	health -= scaled*PotionEffects.resistance(self)
	provoked = true
	hurt_flash = 0.2
	# The source's `runaway`: a mob that declares it flees for five seconds when hit,
	# whether or not it is hostile. A creeper is `runaway = true` — so it backs off
	# when struck rather than only ever advancing. A passive mob flees by default,
	# which is what makes a cow run from a player who hits it.
	if info().get("runaway", not hostile): scared = 5
	var away: Vector3 = ((position-from)*Vector3(1,0,1)).normalized()
	knock = away*5.0
	if grounded: velocity.y = 4.0
	game.sound_at("mob_hurt",position,info().pitch*randf_range(0.95,1.05))
	if health <= 0: die()

# Shearing a woolly sheep drops 1-3 wool and reveals the bare skin; the coat
# regrows when grazing consumes the grass beneath the sheep.
func shear() -> bool:
	if kind != "sheep" or growth_remaining > 0 or sheared or health <= 0 or is_queued_for_deletion(): return false
	sheared = true
	wool_timer = 0
	for part in wool_parts: part.visible = false
	var amount: int = randi_range(1,3)
	game.spawn_drop(center()+Vector3.UP*0.4,Farming.wool_item(sheep_color),amount)
	game.sound_at("sheep",position,1.2)
	game.achievements.award("wool_gatherer")
	Farming.remember(self)
	return true

func die() -> void:
	Farming.forget(self)
	PotionEffects.died(self)
	game.MOD_HOOK_CREATURE_KILLED(self)
	if kind == "zombie": game.achievements.award("kill_zombie")
	# The source's Monster Hunter fires on any hostile kill, and Cow Tipper on
	# collecting leather from a cow.
	if kind in HOSTILE: game.achievements.award("monster_hunter")
	if kind == "blaze": game.achievements.award("into_fire")
	if kind in ["cow","mooshroom"]: game.achievements.award("cow_tipper")
	# Source `mob_head`: a head drops only when a charged creeper's explosion
	# killed the mob, never from an ordinary death.
	if killed_by_charged and growth_remaining <= 0 and kind != "creeper":
		var head: int = Heads.mob_head(kind)
		if head >= 0: game.spawn_drop(center(),head,1)
	# A guardian's drops carry chance denominators the shared table cannot
	# express, so they are rolled by the module instead.
	# A wither skeleton drops its own skull at the source's 1 in 40, which is the
	# only route to the summoning ritual's heads.
	if kind == "wither_skeleton" and growth_remaining <= 0:
		var skull_rng := RandomNumberGenerator.new()
		if skull_rng.randi_range(1,40) == 1:
			game.spawn_drop(center(),Heads.FLOOR+4,1)
	# The wither's nether star is guaranteed, and is the beacon's ingredient.
	if kind == "wither":
		game.spawn_drop(center(),VillageContent.NETHER_STAR,Withers.roll_star(RandomNumberGenerator.new()))
	if Guardians.is_guardian(kind) and growth_remaining <= 0:
		var rng := RandomNumberGenerator.new()
		for entry in Guardians.roll_drops(kind,rng,int(get_meta("looting",0))):
			game.spawn_drop(center(),int(entry[0]),int(entry[1]))
	# An aquatic creature's drops carry chance denominators too, so they are rolled
	# by their own module: a fish yields its raw item and bone meal at 1 in 20, and
	# a squid yields an ink sac, or a glow squid a glow ink sac.
	# A witch's drops carry chance denominators too: her redstone always drops and
	# the brewing supplies roll one in eight each.
	# An illager's drops are rolled by their own module: the vindicator's emerald
	# and the evoker's guaranteed totem of undying.
	if Illagers.is_illager(kind) and growth_remaining <= 0:
		var illager_rng := RandomNumberGenerator.new()
		for entry in Illagers.roll_drops(kind,illager_rng,int(get_meta("looting",0))):
			game.spawn_drop(center(),int(entry[0]),int(entry[1]))
	if Witches.is_witch(kind) and growth_remaining <= 0:
		var witch_rng := RandomNumberGenerator.new()
		for entry in Witches.roll_drops(witch_rng,int(get_meta("looting",0))):
			game.spawn_drop(center(),int(entry[0]),int(entry[1]))
	if AquaticMobs.is_aquatic(kind) and growth_remaining <= 0:
		var water_rng := RandomNumberGenerator.new()
		for entry in AquaticMobs.roll_drops(kind,water_rng,int(get_meta("looting",0))):
			game.spawn_drop(center(),int(entry[0]),int(entry[1]))
	for entry in ([] if growth_remaining > 0 or Guardians.is_guardian(kind) or kind == "wither" or AquaticMobs.is_aquatic(kind) or Witches.is_witch(kind) or Illagers.is_illager(kind) else info().drops):
		var amount: int = randi_range(int(entry[1]),int(entry[2]))+randi_range(0,int(get_meta("looting",0)))
		var item: int = int(entry[0])
		if kind == "sheep" and item == Nodes.WOOL:
			if sheared: continue
			item = Farming.wool_item(sheep_color)
		if PotionEffects.level(self,"burning") > 0 and Nodes.food(Nodes.smelt_result(item)) > 0: item = Nodes.smelt_result(item)
		if amount > 0: game.spawn_drop(center(),item,amount)
	# The source gives each mob its own `xp_min`/`xp_max`, and the spread is wide: a
	# wither is worth fifty, a blaze ten, a zombie five and a cow one. Voxey awarded a
	# flat two for any hostile mob and one for anything else, so a wither and a zombie
	# were worth the same.
	if growth_remaining <= 0: game.experience += xp_reward()
	game.sound_at("mob_hurt",position,info().pitch*0.7)
	game.puff(center(),colors[0] if not colors.is_empty() else Color.WHITE,12)
	queue_free()
