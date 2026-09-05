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
			_box(Vector3(0,1.08,0),Vector3(0.48,0.65,0.3),Color("475f67"))
			_box(Vector3(0,1.63,-0.03),Vector3.ONE*0.42,Color("7e9672"))
			_box(Vector3(-0.11,1.68,-0.25),Vector3(0.07,0.06,0.02),Color("1f2a24"))
			_box(Vector3(0.11,1.68,-0.25),Vector3(0.07,0.06,0.02),Color("1f2a24"))
			for side in [-1,1]:
				_box(Vector3(side*0.34,1.18,-0.2),Vector3(0.18,0.18,0.66),Color("7e9672"))
				legs.append(_box(Vector3(side*0.14,0.38,0),Vector3(0.2,0.74,0.22),Color("3e4656")))
		"skeleton":
			_box(Vector3(0,1.1,0),Vector3(0.38,0.62,0.2),Color("d9d9cf"))
			for y in [0.95,1.1,1.25]: _box(Vector3(0,y,-0.11),Vector3(0.3,0.05,0.02),Color("9c9b90"))
			_box(Vector3(0,1.62,0),Vector3.ONE*0.4,Color("e3e2d8"))
			_box(Vector3(-0.1,1.66,-0.22),Vector3(0.09,0.08,0.03),Color("2a2a28"))
			_box(Vector3(0.1,1.66,-0.22),Vector3(0.09,0.08,0.03),Color("2a2a28"))
			_box(Vector3(0.24,1.2,-0.25),Vector3(0.1,0.1,0.6),Color("d9d9cf"))
			_box(Vector3(0.24,1.2,-0.62),Vector3(0.05,0.7,0.05),Color("6f5233"))
			_box(Vector3(-0.24,1.2,0),Vector3(0.1,0.6,0.1),Color("d9d9cf"))
			for side in [-1,1]: legs.append(_box(Vector3(side*0.12,0.39,0),Vector3(0.12,0.76,0.12),Color("d9d9cf")))
		"spider":
			_box(Vector3(0,0.45,0.15),Vector3(0.8,0.45,0.95),Color("2e2a2e"))
			_box(Vector3(0,0.45,-0.55),Vector3(0.5,0.4,0.45),Color("3a3339"))
			for x in [-0.16,-0.06,0.06,0.16]: _box(Vector3(x,0.52,-0.78),Vector3(0.06,0.06,0.02),Color("d8312a"))
			for i in 4:
				for side in [-1,1]:
					var leg := _box(Vector3(side*0.62,0.5,-0.35+i*0.28),Vector3(0.75,0.07,0.07),Color("2a252a"))
					leg.rotation.z = side*0.35
					legs.append(leg)
		"creeper":
			_box(Vector3(0,0.85,0),Vector3(0.42,0.85,0.3),Color("4fa441"))
			_box(Vector3(0,1.5,0),Vector3.ONE*0.46,Color("5cb24c"))
			for side in [-1,1]:
				_box(Vector3(side*0.1,1.56,-0.24),Vector3(0.1,0.1,0.02),Color("1d2a1c"))
			_box(Vector3(0,1.42,-0.24),Vector3(0.12,0.16,0.02),Color("1d2a1c"))
			for x in [-0.12,0.12]:
				for z in [-0.14,0.14]: legs.append(_box(Vector3(x,0.2,z),Vector3(0.2,0.4,0.24),Color("3e8a36")))
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

func _box(pos: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	instance.material_override = mat
	model.add_child(instance)
	parts.append(instance)
	colors.append(color)
	return instance

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
	if direction.length() > 0.1: model.rotation.y = lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*5)
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
	for i in legs.size():
		var swing: float = sin(life*8+i*PI)*0.35 if direction.length()>0.1 else 0.0
		if kind == "spider": legs[i].rotation.y = swing*0.6
		else: legs[i].rotation.x = swing
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
