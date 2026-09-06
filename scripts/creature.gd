class_name Creature
extends Node3D

# Every mob shares one controller. KINDS describes the differences: shape, speed,
# hit points, drops, voice, and the special behaviours enabled by flags.
const KINDS = {
	"sheep": {"hostile":false,"health":8.0,"speed":0.8,"width":0.3,"height":1.1,"damage":0,"drops":[[Nodes.RAW_MEAT,1,2],[Nodes.WOOL,1,2]],"voice":"sheep","pitch":1.0},
	"cow": {"hostile":false,"health":10.0,"speed":0.7,"width":0.36,"height":1.35,"damage":0,"drops":[[Nodes.RAW_MEAT,1,3],[Nodes.LEATHER,0,2]],"voice":"cow","pitch":0.75},
	"pig": {"hostile":false,"health":10.0,"speed":0.9,"width":0.3,"height":0.9,"damage":0,"drops":[[Nodes.RAW_MEAT,1,3]],"voice":"pig","pitch":1.0},
	"chicken": {"hostile":false,"health":4.0,"speed":1.0,"width":0.18,"height":0.65,"damage":0,"drops":[[Nodes.RAW_MEAT,1,1],[Nodes.FEATHER,1,2]],"voice":"chicken","pitch":1.5,"glides":true},
	"zombie": {"hostile":true,"health":20.0,"speed":2.1,"width":0.28,"height":1.8,"damage":3,"drops":[[Nodes.ROTTEN_FLESH,0,2]],"voice":"zombie","pitch":0.9,"burns":true},
	"skeleton": {"hostile":true,"health":20.0,"speed":2.4,"width":0.28,"height":1.8,"damage":2,"drops":[[Nodes.BONE,0,2]],"voice":"skeleton","pitch":1.1,"burns":true,"ranged":true},
	"spider": {"hostile":true,"health":16.0,"speed":3.2,"width":0.5,"height":0.8,"damage":2,"drops":[[Nodes.STRING,0,2]],"voice":"spider","pitch":1.0,"neutral_by_day":true,"leaps":true},
	"creeper": {"hostile":true,"health":20.0,"speed":2.0,"width":0.28,"height":1.6,"damage":0,"drops":[[Nodes.GUNPOWDER,0,2]],"voice":"","pitch":1.0,"explodes":true},
}
const PASSIVE = ["sheep","cow","pig","chicken"]
const HOSTILE = ["zombie","zombie","skeleton","spider","creeper"]

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
		"zombie":
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
				arm.rotation.x = -1.35
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
				arm.rotation.x = -1.3 if side == 1 else -0.7
				arms.append(arm)
			_box(Vector3(0,0.09,-0.175),Vector3(0.04,0.065,0.03),Color("4c5149"),"",head)
			_box(Vector3(0,-0.035,-0.025),Vector3(0.3,0.055,0.29),Color("d5d3bf"),"bone",head)
			for x in [-0.1,-0.035,0.035,0.1]:
				_box(Vector3(x,0.01,-0.17),Vector3(0.045,0.055,0.025),Color("dddaca"),"bone",head)
			# Bow is attached to the hand and follows the aiming pose.
			var bow := _joint(Vector3(0,-0.57,0),"Bow",arms[1])
			bow.rotation.x = 1.3
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
		"cow":
			_box(Vector3(0,0.85,0),Vector3(0.78,0.7,1.25),Color("5b3d2b"))
			_box(Vector3(0.2,0.95,0.1),Vector3(0.3,0.3,0.4),Color("f0e9dc"))
			_box(Vector3(0,1.05,-0.78),Vector3(0.44,0.44,0.46),Color("6b4a35"))
			_box(Vector3(0,0.9,-1.0),Vector3(0.3,0.16,0.06),Color("d9b6a2"))
			for side in [-1,1]: _box(Vector3(side*0.25,1.28,-0.7),Vector3(0.08,0.12,0.08),Color("e7dcc4"))
			_box(Vector3(0,0.48,0.35),Vector3(0.3,0.14,0.3),Color("e6a9a0"))
			for x in [-0.25,0.25]:
				for z in [-0.4,0.4]: legs.append(_box(Vector3(x,0.27,z),Vector3(0.18,0.55,0.18),Color("4a3224")))
		"pig":
			_box(Vector3(0,0.55,0),Vector3(0.62,0.55,1.0),Color("e8a7a0"))
			_box(Vector3(0,0.65,-0.62),Vector3(0.44,0.42,0.38),Color("edb0a8"))
			_box(Vector3(0,0.58,-0.84),Vector3(0.2,0.12,0.08),Color("d68f88"))
			for side in [-1,1]: _box(Vector3(side*0.13,0.75,-0.8),Vector3(0.06,0.06,0.02),Color("2b1f24"))
			for x in [-0.2,0.2]:
				for z in [-0.32,0.32]: legs.append(_box(Vector3(x,0.15,z),Vector3(0.16,0.3,0.16),Color("d99a93")))
		"chicken":
			_box(Vector3(0,0.42,0),Vector3(0.36,0.34,0.5),Color("f2f0e6"))
			_box(Vector3(0,0.7,-0.22),Vector3(0.22,0.3,0.22),Color("f6f4ec"))
			_box(Vector3(0,0.68,-0.38),Vector3(0.1,0.08,0.12),Color("e5a13a"))
			_box(Vector3(0,0.58,-0.34),Vector3(0.08,0.1,0.06),Color("d43d3a"))
			for side in [-1,1]:
				_box(Vector3(side*0.06,0.74,-0.33),Vector3(0.04,0.04,0.02),Color("22201c"))
				_box(Vector3(side*0.2,0.42,0),Vector3(0.05,0.24,0.34),Color("e9e6da"))
				legs.append(_box(Vector3(side*0.08,0.14,0),Vector3(0.05,0.28,0.05),Color("e5a13a")))
		_:
			_box(Vector3(0,0.73,0),Vector3(0.68,0.65,1.0),Color("e0dec6"))
			_box(Vector3(0,0.9,-0.57),Vector3(0.42,0.43,0.4),Color("c9b9a0"))
			_box(Vector3(-0.22,0.95,-0.68),Vector3(0.03,0.065,0.09),Color("303b32"))
			_box(Vector3(0.22,0.95,-0.68),Vector3(0.03,0.065,0.09),Color("303b32"))
			for x in [-0.23,0.23]:
				for z in [-0.32,0.32]: legs.append(_box(Vector3(x,0.22,z),Vector3(0.15,0.44,0.16),Color("877965")))
			# The wool coat is a separate layer so shearing can hide it.
			wool_parts.append(_box(Vector3(0,0.88,0.1),Vector3(0.82,0.72,0.95),Color("e5e0ce")))
			wool_parts.append(_box(Vector3(0,1.0,-0.62),Vector3(0.6,0.62,0.4),Color("eae5d4")))
			wool_parts.append(_box(Vector3(0,0.55,0.42),Vector3(0.55,0.3,0.3),Color("e5e0ce")))

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
		var phase: float = i*PI if kind != "spider" else (i/2+i%2)*PI
		var swing: float = sin(life*8+phase)*0.4*gait
		if kind == "spider":
			legs[i].rotation.y = float(legs[i].get_meta("rest_y",0.0))+swing*0.5
			legs[i].rotation.z = sin(life*8+phase+PI/2)*0.1*gait
		else: legs[i].rotation.x = swing
	for i in arms.size():
		var rest: float = -1.35 if kind == "zombie" else (-1.3 if i == 1 else -0.7)
		arms[i].rotation.x = rest+sin(life*4+i)*0.07+sin(life*8+i*PI)*gait*0.1
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
	if not hostile or game.gamemode == "creative": return false
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
	var speed: float = data.speed
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
			game.player.hurt(data.damage,false,position)
			if data.voice != "": game.sound_at(data.voice,position,data.pitch*1.15)
		if data.get("leaps",false) and distance < 5 and distance > 1.5 and grounded and leap_cooldown <= 0:
			leap_cooldown = 2.4
			velocity.y = 6.0
			knock = toward*4.5
		if data.get("ranged",false) and distance < 15 and attack_cooldown <= 0 and _sees_player():
			attack_cooldown = 2.2
			var origin: Vector3 = position+Vector3.UP*1.45
			var aim: Vector3 = (player_pos+Vector3.UP*1.1-origin).normalized()*15+Vector3.UP*distance*0.22
			game.spawn_arrow(origin,aim)
	if data.get("burns",false) and game.daylight > 0.8 and position.y > game.world.generator.terrain_height(int(floor(position.x)),int(floor(position.z))):
		health -= delta*0.8
		if fmod(life,0.4) < delta: game.puff(center(),Color("f0a23a"),3)
		if health <= 0: queue_free(); return
	elif hostile and not data.get("burns",false) and game.daylight > 0.8 and distance > 32 and randf() < delta*0.05:
		queue_free()
		return
	if ambient <= 0:
		ambient = randf_range(4.0,10.0) if hostile else randf_range(6.0,16.0)
		if data.voice != "" and distance < 30: game.sound_at(data.voice,position,data.pitch*randf_range(0.94,1.06))

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
	health -= damage
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
	game.MOD_HOOK_CREATURE_KILLED(self)
	if kind == "zombie": game.achievements.award("kill_zombie")
	for entry in info().drops:
		var amount: int = randi_range(int(entry[1]),int(entry[2]))
		if amount > 0: game.spawn_drop(center(),int(entry[0]),amount)
	game.experience += 2 if hostile else 1
	game.sound_at("mob_hurt",position,info().pitch*0.7)
	game.puff(center(),colors[0] if not colors.is_empty() else Color.WHITE,12)
	queue_free()
