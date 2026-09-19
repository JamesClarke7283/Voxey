class_name AlchemyCreature
extends Creature

func _build_model() -> void:
	if kind == "silverfish":
		for i in 5:
			_box(Vector3(0,0.15,i*0.13-0.25),Vector3(0.28-absf(i-2)*0.06,0.2,0.15),Color("a3aaa0"))
			for side in [-1,1]: _box(Vector3(side*0.18,0.08,i*0.13-0.25),Vector3(0.17,0.04,0.035),Color("808879"))
		for side in [-1,1]: _box(Vector3(side*0.06,0.18,-0.34),Vector3(0.04,0.04,0.02),Color("232d26"))
	elif kind == "turtle":
		_box(Vector3(0,0.3,0),Vector3(0.85,0.43,1.05),Color("4f7d48"),"skin")
		_box(Vector3(0,0.56,0),Vector3(0.6,0.12,0.75),Color("638c4a"))
		head = _joint(Vector3(0,0.25,-0.63),"Head"); _box(Vector3.ZERO,Vector3(0.32,0.25,0.3),Color("8ba868"),"skin",head)
		for side in [-1,1]:
			_box(Vector3(side*0.14,0.04,-0.155),Vector3(0.035,0.06,0.025),Color("283a29"),"",head)
			for z in [-0.32,0.32]:
				var flipper := _joint(Vector3(side*0.45,0.14,z),"Flipper"); _box(Vector3(side*0.1,0,0),Vector3(0.3,0.08,0.25),Color("809752"),"",flipper); legs.append(flipper)
	elif AquaticMobs.is_fish(kind):
		# A fish is a small flattened body with a tail fin and side fins. Each
		# species carries its own colour, which is its only visible difference.
		var body: Color = AquaticMobs.colour(kind)
		_box(Vector3(0,0.22,0),Vector3(0.3,0.34,0.62),body,"skin")
		_box(Vector3(0,0.19,-0.3),Vector3(0.24,0.24,0.2),body.lightened(0.08),"skin")
		var tail := _joint(Vector3(0,0.22,0.36),"Tail")
		_box(Vector3(0,0,0.12),Vector3(0.06,0.3,0.24),body.darkened(0.12),"skin",tail)
		for side in [-1,1]:
			_box(Vector3(side*0.16,0.24,0.05),Vector3(0.16,0.05,0.18),body.darkened(0.06),"skin")
			_box(Vector3(side*0.1,0.27,-0.3),Vector3(0.07,0.07,0.05),Color("141b1b"))
	elif AquaticMobs.is_squid(kind):
		# A squid is a rounded mantle over a skirt of tentacles, with two long
		# feeding arms. A glow squid is the same shape in a luminous colour.
		var mantle: Color = Color("e8f0a8") if kind == "glow_squid" else Color("6d6f86")
		_box(Vector3(0,0.62,0),Vector3(0.42,0.6,0.42),mantle,"skin")
		_box(Vector3(0,0.92,0),Vector3(0.34,0.16,0.34),mantle.lightened(0.1),"skin")
		head = _joint(Vector3(0,0.3,0),"Head")
		for i in 8:
			var angle: float = TAU*float(i)/8.0
			var arm2 := _joint(Vector3(sin(angle)*0.16,0.0,cos(angle)*0.16),"Tentacle",head)
			_box(Vector3(0,-0.14,0),Vector3(0.1,0.32,0.1),mantle.darkened(0.15),"skin",arm2)
			legs.append(arm2)
		for side in [-1,1]:
			_box(Vector3(side*0.2,0.62,-0.24),Vector3(0.1,0.14,0.1),Color("12161c"))
	elif kind == "phantom":
		_box(Vector3(0,0.4,0),Vector3(0.45,0.3,0.95),Color("50647d"),"skin")
		_box(Vector3(0,0.4,-0.58),Vector3(0.5,0.25,0.4),Color("586982"))
		for side in [-1,1]:
			_box(Vector3(side*0.15,0.44,-0.79),Vector3(0.09,0.06,0.02),Color("abce5b"))
			var wing := _joint(Vector3(side*0.22,0.43,0),"Wing"); _box(Vector3(side*0.7,0,0.1),Vector3(1.4,0.055,0.7),Color("647d95"),"",wing); arms.append(wing)
		_box(Vector3(0,0.35,0.8),Vector3(0.13,0.12,0.8),Color("52677b"))
	elif kind == "breeze":
		_box(Vector3(0,1.25,0),Vector3(0.58,0.5,0.58),Color("849dae"))
		for side in [-1,1]: _box(Vector3(side*0.15,1.3,-0.301),Vector3(0.11,0.07,0.02),Color("e1eabc"))
		for i in 4:
			var ring := _joint(Vector3(0,0.3+i*0.22,0),"Wind"); ring.rotation.y = i*0.9
			_box(Vector3.ZERO,Vector3(0.35+i*0.15,0.09,0.35+i*0.15),Color("b9cbd1")); arms.append(ring)
	elif kind == "pillager":
		_box(Vector3(0,1,0),Vector3(0.5,0.65,0.3),Color("685151"),"cloth")
		head = _joint(Vector3(0,1.57,0),"Head"); _box(Vector3.ZERO,Vector3(0.5,0.5,0.46),Color("939f96"),"skin",head)
		_box(Vector3(0,-0.09,-0.31),Vector3(0.12,0.27,0.17),Color("7b887f"),"",head)
		for side in [-1,1]:
			_box(Vector3(side*0.13,0.015,-0.24),Vector3(0.11,0.065,0.02),Color("34413b"),"",head)
			var leg := _joint(Vector3(side*0.14,0.67,0),"Leg"); _box(Vector3(0,-0.3,0),Vector3(0.22,0.6,0.27),Color("454b45"),"",leg); legs.append(leg)
		_box(Vector3(0,1.06,-0.35),Vector3(0.6,0.14,0.15),Color("949c8e"))
		_box(Vector3(0,1.09,-0.57),Vector3(0.15,0.16,0.55),Color("956c48"))
		_box(Vector3(0,1.09,-0.7),Vector3(0.7,0.1,0.12),Color("ac8557"))

func _physics_process(delta: float) -> void:
	if game.playing() and game.leads.sleep_if_unloaded(self): return
	if not custom_name.is_empty() and (not game.world.loaded_at(position) or position.distance_to(game.player.position) > 90): return
	if get_meta("raid",false) and position.distance_to(game.player.position) > 85: return
	if kind != "phantom": super._physics_process(delta); return
	if not game.playing() or is_queued_for_deletion(): return
	# A phantom flies its own path, so it has to run the shared weather rules
	# explicitly — exactly as the flying branch does. Without this it would keep its
	# own daylight burn but miss the water and freezing rules entirely.
	if not weather_step(delta): return
	life += delta; attack_cooldown = maxf(0,attack_cooldown-delta)
	var destination: Vector3 = game.player.position+Vector3.UP*(1 if fmod(life,8) > 5 else 8)
	var desired: Vector3 = (destination-position).normalized()*6*PotionEffects.speed(self)
	velocity = velocity.move_toward(desired,delta*5)
	var next: Vector3 = position+velocity*delta
	if not game.world.intersects(next,width,height): position = next
	else: velocity.y = 5
	model.rotation.y = atan2(-velocity.x,-velocity.z)
	for i in arms.size(): arms[i].rotation.z = sin(life*9)*(1 if i == 0 else -1)*0.4
	if position.distance_to(game.player.position) < 1.7 and attack_cooldown <= 0 and aggressive(): game.player.hurt(4,false,position); attack_cooldown = 1.5
	if custom_name.is_empty() and position.distance_to(game.player.position) > 100: queue_free()

func die() -> void:
	if kind == "pillager" and not get_meta("raid",false): game.spawn_drop(center(),PotionCatalog.find("ominous"))
	super.die()
