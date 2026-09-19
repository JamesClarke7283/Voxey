class_name SnowGolem
extends Creature

var golem_key: String = ""
var creator: String = ""
var environment_clock: float = 0.0
var trail_clock: float = 0.0
var target: Creature
var pumpkin_parts: Array = []

func _build_model() -> void:
	_box(Vector3(0,0.37,0),Vector3(0.72,0.74,0.64),Color("e8edef"),"snow")
	_box(Vector3(0,0.98,0),Vector3(0.57,0.55,0.5),Color("f2f4ef"),"snow")
	for y in [0.84,1.0,1.15]: _box(Vector3(0,y,-0.262),Vector3(0.06,0.065,0.025),Color("3c4140"))
	head = _joint(Vector3(0,1.56,0),"Head")
	_box(Vector3.ZERO,Vector3(0.43,0.43,0.43),Color("f4f7f3"),"snow",head)
	for x in [-0.11,0.11]: _box(Vector3(x,0.07,-0.225),Vector3(0.055,0.065,0.022),Color("363b38"),"",head)
	for x in [-0.1,0,0.1]: _box(Vector3(x,-0.095+absf(x)*0.2,-0.226),Vector3(0.05,0.035,0.024),Color("39413c"),"",head)
	_box(Vector3(0,-0.015,-0.28),Vector3(0.07,0.065,0.15),Color("d9903b"),"",head)
	var shell: MeshInstance3D = _box(Vector3.ZERO,Vector3(0.63,0.63,0.63),Color("d69536"),"wood",head)
	pumpkin_parts.append(shell)
	for x in [-0.15,0.15]: pumpkin_parts.append(_box(Vector3(x,0.065,-0.322),Vector3(0.13,0.14,0.02),Color("574129"),"",head))
	for x in [-0.2,-0.1,0,0.1,0.2]: pumpkin_parts.append(_box(Vector3(x,-0.16+absf(x)*0.2,-0.323),Vector3(0.08,0.07,0.025),Color("59422a"),"",head))
	pumpkin_parts.append(_box(Vector3(0,0.35,0),Vector3(0.1,0.12,0.1),Color("667141"),"wood",head))
	for side in [-1,1]:
		var arm: Node3D = _joint(Vector3(side*0.29,1.08,0),"TwigArm")
		var twig: MeshInstance3D = _box(Vector3(side*0.3,0,0),Vector3(0.65,0.065,0.07),Color("826442"),"wood",arm)
		twig.rotation.z = side*0.18
		_box(Vector3(side*0.58,0.07,0),Vector3(0.055,0.2,0.06),Color("826442"),"wood",arm)
		arms.append(arm)
	refresh_head()

func refresh_head() -> void:
	for part in pumpkin_parts: part.visible = not sheared

func bind(record: Dictionary) -> void:
	health = clampf(float(record.get("health",4)),0,4)
	sheared = bool(record.get("sheared",false)); creator = str(record.get("creator",""))
	custom_name = NameTags.bounded(str(record.get("custom_name","")),30)
	model.rotation.y = float(record.get("yaw",0)); environment_clock = clampf(float(record.get("environment_clock",0)),0,0.5)
	trail_clock = clampf(float(record.get("trail_clock",0)),0,0.5)
	for effect in record.get("effects",{}):
		var saved: Dictionary = record.effects[effect]
		PotionEffects.apply(self,effect,float(saved.get("duration",0)),int(saved.get("level",1)))
		if effect == "absorption": PotionEffects.restore_absorption(self,saved.get("remaining",0))
	refresh_head(); NameTags.refresh(self)

func store_record() -> void:
	if golem_key.is_empty() or is_queued_for_deletion(): return
	Golems.state(game).snow[golem_key] = {"position":[position.x,position.y,position.z],"health":health,"sheared":sheared,"creator":creator,"custom_name":custom_name,"yaw":model.rotation.y,"environment_clock":environment_clock,"trail_clock":trail_clock,"effects":PotionEffects.snapshot(self)}

func shear(drop_head: bool = true) -> bool:
	if sheared or health <= 0 or is_queued_for_deletion(): return false
	sheared = true; refresh_head(); store_record()
	if drop_head: game.spawn_drop(position+Vector3.UP*1.4,FruitCrops.CARVED)
	game.sound_at("dig",position,1.4)
	return true

func environment(delta: float) -> void:
	environment_clock += delta
	while environment_clock >= 0.5 and health > 0:
		environment_clock -= 0.5
		if Golems.wet(game,position): environmental_damage(1)
		if health > 0 and Golems.hot(game,position) and PotionEffects.level(self,"fire_resistance") <= 0: environmental_damage(1)
		var id: int = game.world.node_at(Vector3i(position.floor()))
		if health > 0 and (Fluids.lava(id) or Fire.is_fire(id)) and PotionEffects.level(self,"fire_resistance") <= 0: environmental_damage(4 if Fluids.lava(id) else 1)
	trail_clock += delta
	if health > 0 and trail_clock > 0.5:
		trail_clock = 0.0
		trail()

func environmental_damage(amount: float) -> void:
	health -= amount*PotionEffects.resistance(self); hurt_flash = 0.2
	if health <= 0: die()
	else: store_record()

func trail() -> bool:
	if not bool(game.game_rules.get("mobGriefing",true)): return false
	var p := Vector3i(position.floor()); var id: int = game.world.node_at(p)
	if id != Nodes.AIR and not Nodes.plant(id) and id != SnowCover.BASE and not Fire.is_fire(id): return false
	if not SnowCover.supported(game.world,p): return false
	return game.world.set_node(p,SnowCover.BASE)

func acquire_target() -> Creature:
	var best: Creature; var distance: float = 16.0
	for mob in game.creatures.get_children():
		if mob == self or not mob.hostile or mob.health <= 0 or mob.is_queued_for_deletion(): continue
		var at: float = position.distance_to(mob.position)
		if at < distance and Golems.visible(game,position+Vector3.UP*1.7,mob.center()): best = mob; distance = at
	return best

func shoot(victim: Creature) -> ThrownItem:
	if not is_instance_valid(victim) or victim.health <= 0: return null
	var origin: Vector3 = position+Vector3.UP*1.4
	var offset: Vector3 = victim.center()-origin
	var flight: float = Vector2(offset.x,offset.z).length()/Throwables.SPEED
	var aim: Vector3 = offset+Vector3.UP*(Throwables.GRAVITY*flight*flight*0.5)
	return Throwables.launch(game,Nodes.SNOWBALL,origin,aim,self)

func _physics_process(delta: float) -> void:
	if not game.playing() or health <= 0: return
	if not game.world.loaded_at(position) or position.distance_to(game.player.position) > 95:
		store_record(); game.leads.hibernate(self); queue_free(); return
	life += delta; attack_cooldown = maxf(0,attack_cooldown-delta); hurt_flash = maxf(0,hurt_flash-delta)
	environment(delta)
	if health <= 0 or is_queued_for_deletion(): return
	think -= delta
	if think <= 0:
		think = 0.5; target = acquire_target()
		if target == null and randf() < 0.2: direction = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized() if randf() > 0.25 else Vector3.ZERO
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.health > 0:
		var to: Vector3 = target.position-position; var distance: float = to.length()
		direction = (to*Vector3(1,0,1)).normalized() if distance > 7 else Vector3.ZERO
		model.rotation.y = lerp_angle(model.rotation.y,atan2(-to.x,-to.z),delta*5)
		if distance <= 10 and attack_cooldown <= 0 and Golems.visible(game,position+Vector3.UP*1.7,target.center()):
			shoot(target); attack_cooldown = 1.0
	elif direction.length() > 0.1: model.rotation.y = lerp_angle(model.rotation.y,atan2(-direction.x,-direction.z),delta*5)
	if game.leads.player_attached(self): direction = ((game.player.position-position)*Vector3(1,0,1)).normalized()
	knock = knock.move_toward(Vector3.ZERO,delta*12)
	var speed: float = 2.5 if is_instance_valid(target) else 2.0
	velocity.x = direction.x*speed*PotionEffects.speed(self)+knock.x; velocity.z = direction.z*speed*PotionEffects.speed(self)+knock.z
	velocity.y = maxf(-25,velocity.y-22*delta); grounded = false
	for axis in [0,2,1]:
		var next: Vector3 = position; next[axis] += velocity[axis]*delta
		if not game.world.intersects(next,width,height): position = next
		elif axis == 1:
			grounded = velocity.y < 0; velocity.y = 0
		elif game.world.intersects(position-Vector3.UP*0.08,width,0.5) and not game.world.intersects(position+Vector3.UP*1.05,width,height): velocity.y = 7.2
	for i in arms.size(): arms[i].rotation.z = sin(life*3+i*PI)*0.05
	if hurt_flash > 0: _tint(Color("d8402f"),0.45)
	elif tinted: _tint(Color.WHITE,0)

func hit(damage: float, from: Vector3 = Vector3.INF, reason: String = "") -> void:
	super.hit(damage,from,reason)
	if health > 0: store_record()

func die() -> void:
	if is_queued_for_deletion(): return
	Golems.state(game).snow.erase(golem_key)
	PotionEffects.died(self); game.MOD_HOOK_CREATURE_KILLED(self)
	var count: int = randi_range(0,15)
	if count > 0: game.spawn_drop(center(),Nodes.SNOWBALL,count)
	game.puff(center(),Color("e7eef0"),18); game.sound_at("mob_hurt",position,1.3); queue_free()
