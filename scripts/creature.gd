class_name Creature
extends Node3D

# Every mob shares one controller. KINDS describes the differences: shape, speed,
# hit points, drops, voice, and the special behaviours enabled by flags.
const KINDS = {
	"silverfish":{"hostile":true,"health":8.0,"speed":2.2,"width":0.2,"height":0.35,"damage":1,"drops":[],"voice":"spider","pitch":1.7},
	"turtle":{"hostile":false,"health":30.0,"speed":0.5,"width":0.45,"height":0.7,"damage":0,"drops":[[VillageContent.TURTLE_SCUTE,1,2]],"voice":"","pitch":0.7},
	"phantom":{"hostile":true,"health":20.0,"speed":6.0,"width":0.7,"height":0.65,"damage":4,"drops":[[VillageContent.PHANTOM_MEMBRANE,1,2]],"voice":"","pitch":1.3},
	"breeze":{"hostile":true,"health":30.0,"speed":2.8,"width":0.35,"height":1.6,"damage":4,"drops":[[VillageContent.BREEZE_ROD,1,2]],"voice":"","pitch":1.1,"leaps":true},
	"pillager":{"hostile":true,"health":24.0,"speed":2.2,"width":0.3,"height":1.95,"damage":4,"drops":[[VillageContent.EMERALD,0,2],[VillageContent.CROSSBOW,0,1]],"voice":"","pitch":0.9,"ranged":true},
	"rabbit":{"hostile":false,"health":3.0,"speed":1.3,"width":0.22,"height":0.95,"damage":0,"drops":[[VillageContent.RAW_RABBIT,1,1],[VillageContent.RABBIT_HIDE,1,1],[VillageContent.RABBIT_FOOT,0,1]],"voice":"","pitch":1.5},
	"horse":{"hostile":false,"health":30.0,"speed":1.4,"width":0.4,"height":2.2,"damage":0,"drops":[[Nodes.LEATHER,1,2]],"voice":"","pitch":1.0},
	"villager":{"hostile":false,"health":20.0,"speed":1.2,"width":0.28,"height":1.95,"damage":0,"drops":[],"voice":"","pitch":1.0},
	"iron_golem":{"hostile":false,"health":100.0,"speed":2.3,"width":0.55,"height":2.8,"damage":10,"drops":[],"voice":"","pitch":1.0},
	"shulker": {"hostile":true,"health":30.0,"speed":0.0,"width":0.5,"height":1.0,"damage":4,"drops":[[Nodes.SHULKER_SHELL,1,2]],"voice":"","pitch":0.9},
	"enderman": {"hostile":true,"health":40.0,"speed":3.6,"width":0.3,"height":2.9,"damage":5,"drops":[[Nodes.ENDER_PEARL,1,2]],"voice":"","pitch":0.6},
	"ghast": {"hostile":true,"health":10.0,"speed":2.0,"width":1.6,"height":4.0,"damage":6,"drops":[[Nodes.GHAST_TEAR,1,2],[Nodes.GUNPOWDER,1,3]],"voice":"","pitch":0.6},
	"blaze": {"hostile":true,"health":20.0,"speed":2.4,"width":0.35,"height":1.8,"damage":4,"drops":[[Nodes.BLAZE_ROD,1,2]],"voice":"","pitch":0.8},
	"slime": {"hostile":true,"health":4.0,"speed":1.6,"width":0.45,"height":1.0,"damage":2,"drops":[[Nodes.SLIME_BALL,1,3]],"voice":"","pitch":0.8,"leaps":true},
	"end_crystal": {"hostile":false,"health":1.0,"speed":0.0,"width":0.6,"height":1.4,"damage":0,"drops":[],"voice":"","pitch":1.0},
	"ender_dragon": {"hostile":true,"health":200.0,"speed":13.0,"width":3.0,"height":4.0,"damage":7,"drops":[],"voice":"","pitch":0.4},
	"piglin_brute":{"hostile":true,"health":50.0,"speed":2.5,"width":0.3,"height":1.8,"damage":7,"drops":[],"voice":"pig","pitch":0.55},
	"piglin": {"hostile":true,"health":16.0,"speed":2.5,"width":0.3,"height":1.8,"damage":4,"drops":[[Nodes.GOLD_NUGGET,1,4]],"voice":"pig","pitch":0.65},
	"magma_cube": {"hostile":true,"health":16.0,"speed":1.5,"width":0.43,"height":1.0,"damage":3,"drops":[[Nodes.MAGMA_CREAM,1,2]],"voice":"","pitch":0.8,"leaps":true},
	"sheep": {"hostile":false,"health":8.0,"speed":0.8,"width":0.3,"height":1.1,"damage":0,"drops":[[VillageContent.RAW_MUTTON,1,2],[Nodes.WOOL,1,2]],"voice":"sheep","pitch":1.0},
	"cow": {"hostile":false,"health":10.0,"speed":0.7,"width":0.36,"height":1.35,"damage":0,"drops":[[VillageContent.RAW_BEEF,1,3],[Nodes.LEATHER,1,2]],"voice":"cow","pitch":0.75},
	"pig": {"hostile":false,"health":10.0,"speed":0.9,"width":0.3,"height":0.9,"damage":0,"drops":[[VillageContent.RAW_PORKCHOP,1,3]],"voice":"pig","pitch":1.0},
	"chicken": {"hostile":false,"health":4.0,"speed":1.0,"width":0.18,"height":0.65,"damage":0,"drops":[[VillageContent.RAW_CHICKEN,1,1],[Nodes.FEATHER,1,2]],"voice":"chicken","pitch":1.5,"glides":true},
	"zombie": {"hostile":true,"health":20.0,"speed":2.1,"width":0.28,"height":1.8,"damage":3,"drops":[[Nodes.ROTTEN_FLESH,0,2]],"voice":"zombie","pitch":0.9,"burns":true},
	"skeleton": {"hostile":true,"health":20.0,"speed":2.4,"width":0.28,"height":1.8,"damage":2,"drops":[[Nodes.BONE,0,2]],"voice":"skeleton","pitch":1.1,"burns":true,"ranged":true},
	"spider": {"hostile":true,"health":16.0,"speed":3.2,"width":0.5,"height":0.8,"damage":2,"drops":[[Nodes.STRING,0,2],[VillageContent.SPIDER_EYE,0,1]],"voice":"spider","pitch":1.0,"neutral_by_day":true,"leaps":true},
	"creeper": {"hostile":true,"health":20.0,"speed":2.0,"width":0.28,"height":1.6,"damage":0,"drops":[[Nodes.GUNPOWDER,0,2]],"voice":"","pitch":1.0,"explodes":true},
}
const PASSIVE = ["sheep","cow","pig","chicken","rabbit","horse"]
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
var last_seen: float = 0.0
var hurt_flash: float = 0.0
var life: float = 0.0
var legs: Array = []
var arms: Array = []
var bow_hand: Node3D
var head: Node3D
var gait: float = 0.0
var egg_timer: float = 90.0
var parts: Array = []
var colors: Array = []
var model: Node3D
var scared: float = 0.0
var provoked: bool = false
var grounded: bool = false
var tinted: bool = false
var sheared: bool = false
var wool_timer: float = 0.0
var wool_parts: Array = []

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

func _build_model() -> void:
	match kind:
		"zombie","piglin","piglin_brute":
			_box(Vector3(0,1.08,0),Vector3(0.48,0.64,0.28),Color("416f72"),"cloth")
			_box(Vector3(0,1.36,-0.145),Vector3(0.18,0.12,0.025),Color("7a8c55"),"skin")
			head = _joint(Vector3(0,1.51,-0.015),"Head")
			_box(Vector3(0,0.13,0),Vector3(0.43,0.43,0.42),Color("81935d"),"skin",head)
			_box(Vector3(0,0.31,0.015),Vector3(0.44,0.075,0.43),Color("44503a"),"skin",head)
			for side in [-1,1]:
				_box(Vector3(side*0.105,0.16,-0.216),Vector3(0.105,0.055,0.018),Color("25362a"),"",head)
				_box(Vector3(side*0.12,0.08,-0.218),Vector3(0.075,0.045,0.019),Color("64764b"),"skin",head)
				var arm := _joint(Vector3(side*0.335,1.31,0),"Arm")
				_box(Vector3(0,-0.11,0),Vector3(0.18,0.25,0.22),Color("416f72"),"cloth",arm)
				_box(Vector3(0,-0.39,0),Vector3(0.16,0.33,0.19),Color("81935d"),"skin",arm)
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
		"cow","pig","chicken","sheep":
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
			_box(Vector3(0,0.65,0.05),Vector3(0.57,0.44,0.85),Color("b9a78b"),"fur")
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
	return instance

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
		head.rotation.x = sin(life*1.8)*0.035
		if chasing:
			var target: Vector3 = model.to_local(game.player.position+Vector3.UP*1.5)
			head.rotation.y = lerp_angle(head.rotation.y,clampf(atan2(-target.x,-target.z),-0.6,0.6),delta*5)
		else: head.rotation.y = sin(life*0.8)*0.08

func info() -> Dictionary:
	return KINDS[kind]

func center() -> Vector3:
	return position+Vector3.UP*height*0.55

func aggressive() -> bool:
	if not hostile or game.gamemode == "creative" or (not provoked and PotionEffects.level(game.player,"invisibility") > 0 and position.distance_to(game.player.position) > 2+game.player.armor_points()*0.35): return false
	if info().get("neutral_by_day",false) and game.daylight >= 0.5 and not provoked: return false
	return true

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	life += delta
	attack_cooldown = maxf(0,attack_cooldown-delta)
	leap_cooldown = maxf(0,leap_cooldown-delta)
	scared = maxf(0,scared-delta)
	hurt_flash = maxf(0,hurt_flash-delta)
	ambient -= delta
	if kind == "chicken":
		egg_timer -= delta
		if egg_timer <= 0:
			game.spawn_drop(position+Vector3.UP*0.3,Nodes.EGG)
			egg_timer = randf_range(90.0,150.0)
	if sheared and kind == "sheep":
		wool_timer -= delta
		if wool_timer <= 0:
			sheared = false
			for part in wool_parts: part.visible = true
	var player_pos: Vector3 = game.player.position
	var distance: float = position.distance_to(player_pos)
	if distance > 90: queue_free(); return
	if not game.world.loaded_at(position): return
	var data: Dictionary = info()
	think -= delta
	if think <= 0:
		think = randf_range(1.5,4.0)
		direction = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized() if randf()>0.35 else Vector3.ZERO
	var toward: Vector3 = ((player_pos-position)*Vector3(1,0,1)).normalized()
	# Mobs keep hunting for a few seconds after losing sight, then give up.
	if _sees_player(): last_seen = life
	var chasing: bool = aggressive() and distance < 24 and life-last_seen < 4.0
	if chasing:
		if data.get("ranged",false):
			direction = -toward if distance < 5 else (toward if distance > 9 else Vector3.ZERO)
		else: direction = toward
	elif scared > 0 and not hostile: direction = -toward
	if game.leads.attached(self): direction = toward if distance > 2.5 else Vector3.ZERO
	var speed: float = data.speed*PotionEffects.speed(self)
	if not hostile and scared > 0: speed = 3.0
	if data.get("explodes",false):
		if chasing and distance < 3.2:
			if fuse == 0: game.sound_at("creeper",position)
			fuse += delta
			direction = Vector3.ZERO
			if fuse >= 1.5:
				game.explode(center(),2.6,self)
				queue_free()
				return
		elif fuse > 0: fuse = maxf(0,fuse-delta*2)
	if chasing and data.get("ranged",false): model.rotation.y = lerp_angle(model.rotation.y,atan2(-toward.x,-toward.z),delta*5)
	elif direction.length() > 0.1: model.rotation.y = lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*5)
	knock = knock.move_toward(Vector3.ZERO,delta*12)
	velocity.x = direction.x*speed+knock.x
	velocity.z = direction.z*speed+knock.z
	velocity.y = maxf(-25,velocity.y-22*delta)
	if data.get("glides",false) and velocity.y < -1.6: velocity.y = -1.6
	grounded = false
	for axis in [0,2,1]:
		var next: Vector3 = position
		next[axis] += velocity[axis]*delta
		if not game.world.intersects(next,width,height): position = next
		elif axis == 1:
			if velocity.y < 0: grounded = true
			velocity.y = 0
		elif game.world.intersects(position-Vector3.UP*0.08,width,1.0) and not game.world.intersects(position+Vector3.UP*1.05,width,height): velocity.y = 7.2
	if not grounded and game.world.intersects(position-Vector3.UP*0.04,width,0.5): grounded = true
	animate(delta,chasing)
	if data.get("explodes",false):
		model.scale = Vector3.ONE*(1.0+fuse*0.25)
		_tint(Color.WHITE,0.7 if fuse > 0 and int(fuse*12)%2 == 0 else 0.0)
	if hurt_flash > 0: _tint(Color("d8402f"),0.55)
	elif tinted and not data.get("explodes",false): _tint(Color.WHITE,0.0)
	if chasing and data.damage > 0:
		if distance < 1.3+width and attack_cooldown <= 0 and not data.get("ranged",false):
			attack_cooldown = 1.1
			game.player.hurt(maxf(0,data.damage*PotionEffects.melee(self)),false,position)
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
			game.spawn_arrow(origin,aim)
	if data.get("burns",false) and not has_meta("effect_fire_resistance") and game.daylight > 0.8 and position.y > game.world.generator.terrain_height(int(floor(position.x)),int(floor(position.z))):
		health -= delta*0.8
		if fmod(life,0.4) < delta: game.puff(center(),Color("f0a23a"),3)
		if health <= 0: queue_free(); return
	elif hostile and not data.get("burns",false) and game.daylight > 0.8 and distance > 32 and randf() < delta*0.05:
		queue_free()
		return
	if ambient <= 0:
		ambient = randf_range(4.0,10.0) if hostile else randf_range(6.0,16.0)
		if data.voice != "" and distance < 30: game.sound_at(data.voice,position,data.pitch*randf_range(0.94,1.06))

func facing_player() -> bool:
	var toward: Vector3 = ((game.player.position-position)*Vector3(1,0,1)).normalized()
	return (-model.global_basis.z).dot(toward) >= cos(deg_to_rad(5.0))

func _sees_player() -> bool:
	# Line-of-sight via voxel DDA between the mob's eye and the player's chest;
	# walls and other opaque nodes block vision, water and plants do not.
	var origin: Vector3 = position+Vector3.UP*height*0.85
	var to_player: Vector3 = game.player.position+Vector3.UP*1.1-origin
	if to_player.length() < 0.01: return true
	var hit: Dictionary = game.world.raycast(origin,to_player.normalized(),to_player.length())
	return hit.is_empty() or hit.distance >= to_player.length()-0.35

func _tint(color: Color, amount: float) -> void:
	tinted = amount > 0
	for i in parts.size():
		var mat: StandardMaterial3D = parts[i].material_override
		mat.albedo_color = colors[i].lerp(color,amount)

func hit(damage: float, from: Vector3 = Vector3.INF) -> void:
	if is_inf(from.x): from = game.player.position
	PotionEffects.damaged(self)
	health -= damage*PotionEffects.resistance(self)
	provoked = true
	hurt_flash = 0.2
	if not hostile: scared = 5
	var away: Vector3 = ((position-from)*Vector3(1,0,1)).normalized()
	knock = away*5.0
	if grounded: velocity.y = 4.0
	game.sound_at("mob_hurt",position,info().pitch*randf_range(0.95,1.05))
	if health <= 0: die()

# Shearing a woolly sheep drops 1-3 wool and reveals the bare skin; the coat
# regrows after a couple of minutes of grazing.
func shear() -> bool:
	if sheared: return false
	sheared = true
	wool_timer = randf_range(100.0,160.0)
	for part in wool_parts: part.visible = false
	var amount: int = randi_range(1,3)
	game.spawn_drop(center()+Vector3.UP*0.4,Nodes.WOOL,amount)
	game.sound_at("sheep",position,1.2)
	game.achievements.award("wool_gatherer")
	return true

func die() -> void:
	PotionEffects.died(self)
	game.MOD_HOOK_CREATURE_KILLED(self)
	if kind == "zombie": game.achievements.award("kill_zombie")
	for entry in info().drops:
		var amount: int = randi_range(int(entry[1]),int(entry[2]))+randi_range(0,int(get_meta("looting",0)))
		var item: int = int(entry[0])
		if PotionEffects.level(self,"burning") > 0 and Nodes.food(Nodes.smelt_result(item)) > 0: item = Nodes.smelt_result(item)
		if amount > 0: game.spawn_drop(center(),item,amount)
	game.experience += 20 if kind == "piglin_brute" else (2 if hostile else 1)
	game.sound_at("mob_hurt",position,info().pitch*0.7)
	game.puff(center(),colors[0] if not colors.is_empty() else Color.WHITE,12)
	queue_free()
