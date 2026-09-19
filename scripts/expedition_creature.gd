class_name ExpeditionCreature
extends Creature

var slime_size: int = 2
var slime_hop: float = 0.0
var crystal_key: String = ""
var wings: Array = []
var beam: MeshInstance3D
var beam_target: Creature
var attack_phase: float = 0.0

func _ready() -> void:
	super._ready()
	if kind == "slime": set_slime_size(2)

func info() -> Dictionary:
	var data: Dictionary = super.info()
	if kind == "slime":
		data = data.duplicate(); data.damage = slime_size if slime_size > 1 else 0; data.health = slime_size*slime_size
	return data

func _build_model() -> void:
	match kind:
		"shulker":
			_box(Vector3(0,0.25,0),Vector3(1,0.5,1),Color("986b9f"),"shell")
			_box(Vector3(0,0.74,0),Vector3(1,0.5,1),Color("ac82b1"),"shell")
			head = _joint(Vector3(0,0.55,0),"Head")
			_box(Vector3.ZERO,Vector3(0.48,0.35,0.48),Color("c9b5be"),"bone",head)
			for side in [-1,1]: _box(Vector3(side*0.11,0.01,-0.25),Vector3(0.08,0.07,0.015),Color("282131"),"",head)
		"enderman":
			_box(Vector3(0,1.9,0),Vector3(0.45,0.78,0.28),Color("24212c"),"skin")
			head = _joint(Vector3(0,2.52,0),"Head")
			_box(Vector3.ZERO,Vector3(0.46,0.48,0.45),Color("22202c"),"skin",head)
			for side in [-1,1]:
				var eye := _box(Vector3(side*0.13,0.05,-0.234),Vector3(0.18,0.05,0.015),Color("d796f2"),"",head)
				eye.material_override.emission_enabled = true; eye.material_override.emission = Color("c467e5")
				var leg := _joint(Vector3(side*0.14,1.55,0),"Leg")
				_box(Vector3(0,-0.76,0),Vector3(0.12,1.52,0.12),Color("24212c"),"skin",leg); legs.append(leg)
				var arm := _joint(Vector3(side*0.3,2.25,0),"Arm")
				_box(Vector3(0,-0.85,0),Vector3(0.115,1.7,0.115),Color("24212c"),"skin",arm); arms.append(arm)
		"ghast":
			_box(Vector3(0,2.3,0),Vector3(3.2,3.2,3.2),Color("e2dbd5"),"bone")
			for side in [-1,1]:
				_box(Vector3(side*0.65,2.4,-1.61),Vector3(0.42,0.22,0.02),Color("483e4e"))
				_box(Vector3(side*0.62,1.95,-1.62),Vector3(0.14,0.55,0.02),Color("a79da9"))
			_box(Vector3(0,1.75,-1.62),Vector3(0.35,0.24,0.02),Color("493846"))
			for x in [-1,0,1]:
				for z in [-1,0,1]:
					var tentacle := _joint(Vector3(x*0.85,0.8,z*0.85),"Tentacle")
					_box(Vector3(0,-0.55,0),Vector3(0.3,1.1+float((x+z+2)%3)*0.2,0.3),Color("cbc4cb"),"bone",tentacle)
					legs.append(tentacle)
		"blaze":
			head = _joint(Vector3(0,1.4,0),"Head")
			_box(Vector3.ZERO,Vector3(0.48,0.5,0.48),Color("dca331"),"skin",head)
			for side in [-1,1]: _box(Vector3(side*0.12,0.08,-0.25),Vector3(0.12,0.055,0.02),Color("362622"),"",head)
			for i in 12:
				var rod := _joint(Vector3.ZERO,"Rod")
				_box(Vector3(0.5,0.3+(i/4)*0.45,0),Vector3(0.12,0.48,0.12),Color("edb443"),"",rod)
				rod.rotation.y = TAU*(i%4)/4.0+i*0.2
				legs.append(rod)
		"slime":
			var skin := _box(Vector3(0,0.5,0),Vector3.ONE*0.95,Color("82b554"),"moss")
			skin.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			skin.material_override.albedo_color.a = 0.65
			_box(Vector3(0,0.5,0),Vector3.ONE*0.63,Color("a1c568"),"moss")
			_box(Vector3(0,0.32,-0.49),Vector3(0.2,0.055,0.025),Color("29432c"))
			for side in [-1,1]: _box(Vector3(side*0.2,0.6,-0.49),Vector3(0.15,0.15,0.025),Color("29432c"))
		"end_crystal":
			var core := _box(Vector3(0,0.7,0),Vector3.ONE*0.5,Color("e8a0e1"))
			core.material_override.emission_enabled = true; core.material_override.emission = Color("d26ad9")
			for axis in 3:
				for a in [-0.48,0.48]:
					for b in [-0.48,0.48]:
						var size := Vector3.ONE*0.055; size[axis] = 1
						var pos := Vector3.ZERO; pos[(axis+1)%3] = a; pos[(axis+2)%3] = b; pos.y += 0.7
						_box(pos,size,Color("edd5ef"))
		"ender_dragon":
			_box(Vector3(0,1.2,0.5),Vector3(2.5,2.4,5),Color("282330"),"shell")
			_box(Vector3(0,1.5,-2.3),Vector3(1.2,1.3,2.0),Color("302939"),"shell")
			head = _joint(Vector3(0,1.5,-3.5),"Head")
			_box(Vector3(0,0,-0.5),Vector3(1.6,1.2,2),Color("292330"),"shell",head)
			_box(Vector3(0,-0.3,-1.6),Vector3(1.2,0.6,1.3),Color("302a3a"),"shell",head)
			for side in [-1,1]:
				var eye := _box(Vector3(side*0.81,0.15,-0.95),Vector3(0.05,0.22,0.48),Color("ca7eea"),"",head)
				eye.material_override.emission_enabled = true; eye.material_override.emission = Color("b54ddd")
				_box(Vector3(side*0.6,0.9,0),Vector3(0.24,1.1,0.24),Color("aca0b1"),"bone",head)
				var wing := _joint(Vector3(side*1.1,1.8,0),"Wing")
				for segment in 3:
					var bone := _box(Vector3(side*(1.0+segment*1.6),0,segment*0.3),Vector3(2.0,0.18,0.2),Color("8e809b"),"bone",wing)
					bone.rotation.y = side*-0.18
					_box(Vector3(side*(1.0+segment*1.6),-0.06,1.0+segment*0.3),Vector3(1.85,0.06,2.2-segment*0.45),Color("403047"),"shell",wing)
				wings.append(wing)
				for z in [-0.8,2.2]:
					var leg := _joint(Vector3(side*1.0,0.4,z),"Leg")
					_box(Vector3(0,-0.65,0.2),Vector3(0.45,1.3,0.5),Color("322a3a"),"shell",leg)
					_box(Vector3(0,-1.25,-0.2),Vector3(0.7,0.3,1.2),Color("978aa2"),"bone",leg)
					legs.append(leg)
			for i in 6:
				_box(Vector3(0,1.1,3.1+i*1.0),Vector3(1.1-i*0.13,0.8-i*0.09,1.3),Color("302639"),"shell")
				_box(Vector3(0,2.2,0.4+i*1.2),Vector3(0.23,0.6,0.45),Color("9c8ca8"),"bone")
		_: super._build_model()

func aggressive() -> bool:
	if kind == "enderman": return provoked and game.gamemode != "creative"
	return super.aggressive()

func _physics_process(delta: float) -> void:
	if kind == "slime" and game.playing():
		slime_hop -= delta
		if grounded and slime_hop <= 0:
			velocity.y = 5.4; slime_hop = randf_range(0.6,1.4)
		model.scale = Vector3.ONE*(slime_size/2.0)*Vector3(1.0+sin(life*7)*0.04,1.0-sin(life*7)*0.06,1.0+sin(life*7)*0.04)
	if not game.playing(): return
	if game.leads.sleep_if_unloaded(self): return
	if Farming.sleep_if_unloaded(self): return
	if kind == "shulker":
		life += delta; attack_cooldown -= delta
		var near: bool = position.distance_to(game.player.position) < 22
		parts[1].position.y = lerpf(parts[1].position.y,1.2 if near else 0.74,delta*4)
		if near and aggressive() and _sees_player() and attack_cooldown <= 0:
			game.adventure.projectile("shulker",center()+Vector3.UP,(game.player.position+Vector3.UP-center()).normalized()*6,self)
			attack_cooldown = 3.5
		return
	if kind == "end_crystal":
		life += delta
		model.rotation.y += delta*0.8
		model.rotation.z = sin(life*0.8)*0.25
		model.position.y = sin(life*2)*0.12
		return
	if kind == "ender_dragon": _dragon(delta); return
	if kind in ["ghast","blaze"]:
		# A flying mob runs its own movement, but the weather rules still apply:
		# without this a blaze could never be put out by rain or hurt by water,
		# because it never reaches the shared step below.
		if not weather_step(delta): return
		_fly(delta); return
	if kind == "enderman":
		var eye: Vector3 = center()-game.player.camera.global_position
		if not PumpkinHelmet.worn(game.player) and eye.length() < 24 and (-game.player.camera.global_basis.z).dot(eye.normalized()) > 0.985 and _sees_player(): provoked = true
		if Fluids.water(game.world.node_at(Vector3i(position.floor()))) or (provoked and position.distance_to(game.player.position) > 8 and leap_cooldown <= 0):
			teleport_near(game.player.position if provoked else position)
			leap_cooldown = 4
	super._physics_process(delta)
	if kind == "enderman":
		for i in arms.size(): arms[i].rotation.x = sin(life*7+i*PI)*0.3*gait
		if fmod(life,0.3) < delta: game.puff(center(),Color("9b5ccc"),1,0.3)

func teleport_near(near: Vector3) -> bool:
	for attempt in 20:
		var p: Vector3 = near+Vector3(randf_range(-12,12),0,randf_range(-12,12))
		if not game.world.loaded_at(p): continue
		var floor_pos: Vector3 = game.world.cave_spawn(p,16)
		if is_inf(floor_pos.x) or game.world.intersects(floor_pos,width,height): continue
		game.puff(center(),Color("b375d8"),12)
		position = floor_pos
		game.puff(center(),Color("b375d8"),12)
		return true
	return false

func _fly(delta: float) -> void:
	life += delta
	attack_cooldown -= delta
	if position.distance_to(game.player.position) > 100: queue_free(); return
	if not game.world.loaded_at(position): return
	var toward: Vector3 = game.player.position+Vector3.UP*(7 if kind == "ghast" else 2)-position
	var chasing: bool = aggressive() and toward.length() < 48
	var desired: Vector3 = toward.normalized()*info().speed if chasing and toward.length() > (16 if kind == "ghast" else 7) else Vector3(sin(life*0.5),sin(life)*0.7,cos(life*0.5))*0.6
	for axis in 3:
		var next: Vector3 = position; next[axis] += desired[axis]*delta
		if not game.world.intersects(next,width,height): position = next
	if toward.length() > 0.01: model.rotation.y = lerp_angle(model.rotation.y,atan2(-toward.x,-toward.z),delta*2)
	for i in legs.size():
		if kind == "ghast": legs[i].rotation.x = sin(life*2+i)*0.2
		else: legs[i].rotation.y += delta*(1.0+float(i/4)*0.5)
	if chasing and _sees_player() and attack_cooldown <= 0:
		var forward: Vector3 = -model.global_basis.z
		var origin: Vector3 = center()+forward*(2 if kind == "ghast" else 0.6)
		var aim: Vector3 = (game.player.position+Vector3.UP-origin).normalized()
		game.adventure.projectile("ghast" if kind == "ghast" else "blaze",origin,aim*(10 if kind == "ghast" else 14),self)
		attack_cooldown = 3.6 if kind == "ghast" else 1.4
		game.puff(origin,Color("f9bc59"),6)

func _dragon(delta: float) -> void:
	if Vector2(game.player.position.x,game.player.position.z).length() > 150: queue_free(); return
	life += delta
	attack_cooldown -= delta
	attack_phase = fposmod(life,42)
	var perched: bool = attack_phase > 30
	var goal := Vector3(cos(life*0.22)*29,63+sin(life*0.4)*7,sin(life*0.22)*29)
	if perched: goal = Vector3(0,47,0)
	elif attack_phase > 23: goal = game.player.position+Vector3.UP*3
	var motion: Vector3 = goal-position
	position = position.move_toward(goal,delta*(13 if not perched else 10))
	if motion.length() > 0.1: model.rotation.y = lerp_angle(model.rotation.y,atan2(-motion.x,-motion.z),delta*2)
	for i in wings.size(): wings[i].rotation.z = (-1 if i == 0 else 1)*sin(life*(3 if perched else 5))*0.45
	for leg in legs: leg.rotation.x = 0 if perched else 0.55
	if game.gamemode != "creative" and attack_cooldown <= 0:
		var origin: Vector3 = head.global_position-model.global_basis.z*2
		game.adventure.projectile("breath",origin,(game.player.position+Vector3.UP-origin).normalized()*13,self)
		attack_cooldown = 1.8 if perched else 4.5
	if center().distance_to(game.player.position+Vector3.UP) < 4: game.player.hurt(7,false,position)
	beam_target = null
	var best: float = 48
	for mob in game.creatures.get_children():
		if mob.kind != "end_crystal" or mob.is_queued_for_deletion(): continue
		var d: float = mob.center().distance_to(center())
		if d < best: best = d; beam_target = mob
	if is_instance_valid(beam_target):
		health = minf(200,health+delta*2)
		if beam == null: beam = RedstoneArt.box(self,Vector3.ZERO,Vector3.ONE,Color("bc79dd"),0.9)
		beam.visible = true
		var a: Vector3 = beam_target.center()
		var b: Vector3 = center()
		beam.global_position = (a+b)*0.5
		var up: Vector3 = (b-a).normalized()
		var right: Vector3 = up.cross(Vector3.FORWARD).normalized()
		if right.length() < 0.1: right = Vector3.RIGHT
		beam.global_basis = Basis(right,up,right.cross(up)).scaled_local(Vector3(0.08,a.distance_to(b),0.08))
	elif beam != null: beam.visible = false
	game.world.adventure_state["dragon_health"] = health
	game.world.adventure_state["dragon_phase"] = life

func hit(damage: float, from: Vector3 = Vector3.INF, reason: String = "") -> void:
	if is_queued_for_deletion(): return
	if kind == "enderman" and leap_cooldown <= 0:
		teleport_near(position)
		leap_cooldown = 3
	super.hit(damage,from,reason)
	if kind == "ender_dragon": game.world.adventure_state["dragon_health"] = maxf(0,health)

func die() -> void:
	Farming.forget(self)
	PotionEffects.died(self)
	if kind == "slime":
		if slime_size > 1:
			for i in randi_range(2,4):
				var child: Creature = game.spawn_creature("slime",position+Vector3((i%2-0.5)*0.4,0.1,(i/2-0.5)*0.4))
				child.set_slime_size(slime_size/2)
		else: game.spawn_drop(center(),Nodes.SLIME_BALL,randi_range(1,2))
		game.experience += slime_size; game.puff(center(),Color("8db65e"),10); queue_free(); return
	if is_queued_for_deletion(): return
	if kind == "end_crystal":
		queue_free() # Mark first: nearby crystal explosions cannot re-enter death.
		game.adventure.crystal_destroyed(self)
		game.explode(center(),3.2,self)
		return
	if kind == "ender_dragon":
		queue_free()
		game.adventure.dragon_defeated()
		return
	if kind == "shulker" and not crystal_key.is_empty():
		if not game.world.adventure_state.has("city_guards"): game.world.adventure_state["city_guards"] = []
		game.world.adventure_state.city_guards.append(crystal_key)
	super.die()

func set_slime_size(value: int) -> void:
	slime_size = value if value in [1,2,4] else 2
	health = slime_size*slime_size
	width = 0.235*slime_size; height = 0.49*slime_size
	model.scale = Vector3.ONE*(slime_size/2.0)
