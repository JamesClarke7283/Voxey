class_name VillageMob
extends Creature

var person_key: String = ""
var profession: String = "unemployed"
var route: Array = []
var destination := Vector3.INF
var path_timer: float = 0.0
var sleeping: bool = false

func bind(person: Dictionary) -> void:
	person_key = person.key; profession = person.profession; health = person.health
	rebuild()

func rebuild() -> void:
	for child in model.get_children(): child.queue_free()
	parts.clear(); colors.clear(); legs.clear(); arms.clear(); _build_model()

func _build_model() -> void:
	if kind == "iron_golem":
		_box(Vector3(0,1.55,0),Vector3(0.95,1.25,0.62),Color("d4d2b9"),"stone")
		head = _joint(Vector3(0,2.28,-0.12),"Head")
		_box(Vector3(0,0.16,0),Vector3(0.55,0.64,0.48),Color("d9d5be"),"stone",head)
		_box(Vector3(0,-0.08,-0.29),Vector3(0.16,0.3,0.24),Color("bdb9a3"),"stone",head)
		for side in [-1,1]:
			_box(Vector3(side*0.13,0.21,-0.25),Vector3(0.13,0.065,0.025),Color("aa4c3e"),"",head)
			var arm := _joint(Vector3(side*0.62,2.08,0),"Arm")
			_box(Vector3(0,-0.7,0),Vector3(0.33,1.5,0.4),Color("c6c8b2"),"stone",arm); arms.append(arm)
			var leg := _joint(Vector3(side*0.27,0.96,0),"Hip")
			_box(Vector3(0,-0.45,0),Vector3(0.35,0.9,0.42),Color("b0b4a0"),"stone",leg); legs.append(leg)
		for i in 5: _box(Vector3(-0.2+i%2*0.12,1.95-i*0.2,-0.322),Vector3(0.16,0.24,0.015),Color("6c8850"),"moss")
		return
	var index: int = maxi(0,VillageContent.PROFESSIONS.find(profession))
	var robe: Color = [Color("967047"),Color("63897d"),Color("795946"),Color("a99576"),Color("bd6558"),Color("7597a2"),Color("656672"),Color("926140"),Color("b4aba0"),Color("5c5364"),Color("6b786e"),Color("8558a1"),Color("987d68")][index]
	if profession == "unemployed": robe = Color("8f7058")
	_box(Vector3(0,0.98,0),Vector3(0.52,0.9,0.36),robe,"cloth")
	_box(Vector3(0,1.08,-0.193),Vector3(0.37,0.52,0.04),robe.lightened(0.18),"cloth")
	_box(Vector3(0,0.7,-0.208),Vector3(0.5,0.08,0.035),Color("68513c"),"cloth")
	head = _joint(Vector3(0,1.49,0),"Head")
	_box(Vector3(0,0.19,0),Vector3(0.46,0.53,0.44),Color("bd9873"),"skin",head)
	_box(Vector3(0,0.09,-0.28),Vector3(0.13,0.25,0.2),Color("ab805c"),"skin",head)
	_box(Vector3(0,0.32,-0.236),Vector3(0.39,0.045,0.025),Color("4e4133"),"",head)
	for side in [-1,1]:
		_box(Vector3(side*0.12,0.25,-0.23),Vector3(0.11,0.07,0.02),Color("e5dec7"),"",head)
		_box(Vector3(side*0.1,0.25,-0.245),Vector3(0.046,0.065,0.015),Color("467258"),"",head)
		var leg := _joint(Vector3(side*0.14,0.55,0),"Hip")
		_box(Vector3(0,-0.24,0),Vector3(0.2,0.46,0.25),robe.darkened(0.25),"cloth",leg)
		_box(Vector3(0,-0.5,-0.045),Vector3(0.22,0.1,0.33),Color("514636"),"",leg); legs.append(leg)
		_box(Vector3(side*0.28,1.16,-0.05),Vector3(0.17,0.36,0.25),robe,"cloth")
	_box(Vector3(0,1.04,-0.27),Vector3(0.61,0.2,0.21),robe.darkened(0.12),"cloth")
	_box(Vector3(0,1.04,-0.387),Vector3(0.17,0.16,0.025),Color("b98f69"),"skin")
	if profession == "farmer":
		_box(Vector3(0,0.47,0),Vector3(0.74,0.09,0.66),Color("d3b875"),"cloth",head)
		_box(Vector3(0,0.56,0.03),Vector3(0.48,0.18,0.43),Color("bea161"),"cloth",head)
	elif profession != "unemployed":
		_box(Vector3(0,0.46,0.015),Vector3(0.49,0.16,0.47),robe.darkened(0.15),"cloth",head)
		if profession == "librarian":
			for side in [-1,1]: _box(Vector3(side*0.13,0.255,-0.253),Vector3(0.18,0.12,0.018),Color("dfc88d"),"",head)
		if profession == "fletcher": _box(Vector3(0.22,0.65,0.05),Vector3(0.04,0.32,0.14),Color("e9dfc2"),"",head)
	if game != null and not person_key.is_empty():
		var r: Dictionary = game.villages.record(person_key)
		if not r.is_empty():
			_box(Vector3(0.13,0.82,-0.23),Vector3(0.09,0.09,0.025),[Color("b78a5b"),Color("a2a5a5"),Color("dfbb53"),Color("40bd89"),Color("72d5d0")][int(r.level)-1],"")
			var young: bool = r.get("age",0.0) > 0
			model.scale = Vector3.ONE*(0.55 if young else 1.0)
			height = 1.1 if young else 1.95; width = 0.16 if young else 0.28

func store_record() -> void:
	var r: Dictionary = game.villages.record(person_key)
	if r.is_empty(): return
	r.position = [position.x,position.y,position.z]; r.health = health

func _physics_process(delta: float) -> void:
	if not game.playing() or not game.world.loaded_at(position): return
	var r: Dictionary = game.villages.record(person_key)
	if r.is_empty(): return
	life += delta; attack_cooldown -= delta; path_timer -= delta
	var goal: Vector3 = VillageLife.vec(r.job)+Vector3(1.5,0,0.5)
	var threat: Creature = null; var distance: float = 20.0
	for mob in game.creatures.get_children():
		if mob == self or not mob.hostile or mob.is_queued_for_deletion(): continue
		var d: float = position.distance_to(mob.position)
		if d < distance: threat = mob; distance = d
	if profession == "farmer" and int(life)%24 > 8 and fposmod(game.day_time,1.0) > 0.25 and fposmod(game.day_time,1.0) < 0.55:
		goal = VillageLife.vec(r.center)+Vector3(-14,1,-5)
	var night: bool = fposmod(game.day_time,1.0) > 0.72 or fposmod(game.day_time,1.0) < 0.2
	if kind == "iron_golem":
		goal = threat.position if threat != null else VillageLife.vec(r.center)+Vector3(6+sin(life*0.07)*5,1,cos(life*0.07)*5)
		if threat != null and distance < 2.4 and attack_cooldown <= 0:
			attack_cooldown = 1.1; threat.hit(randi_range(7,16),position); threat.velocity.y = 7.0
	else:
		if night or game.villages.alarm > 0 or threat != null: goal = VillageLife.vec(r.bed)+Vector3(-1,0,0.5)
		elif fposmod(game.day_time,1.0) > 0.55: goal = VillageLife.vec(r.center)+Vector3(5+sin(life*0.09+float(person_key.hash()%12))*3,1,cos(life*0.09)*4)
		if threat != null and distance < 1.5 and attack_cooldown <= 0:
			attack_cooldown = 1; super.hit(3,threat.position); store_record()
			if health <= 0: return
		if r.get("age",0.0) > 0: goal = VillageLife.vec(r.center)+Vector3(sin(life*0.3)*5,1,cos(life*0.3)*5)
	if game.leads.attached(self): goal = game.player.position
	sleeping = not game.leads.attached(self) and kind == "villager" and night and position.distance_to(goal) < 1.0 and VillageContent.is_bed(game.world.node_at(Vector3i(VillageLife.vec(r.bed))))
	model.rotation.x = PI*0.5 if sleeping else 0.0
	model.position = Vector3(1,0.6,0) if sleeping else Vector3.ZERO
	if sleeping: return
	if path_timer <= 0 or destination.distance_to(goal) > 2:
		path_timer = 2.0; destination = goal; route = path_to(goal)
	var toward: Vector3 = ((route[0] if not route.is_empty() else goal)-position)*Vector3(1,0,1)
	if toward.length() < 0.3 and not route.is_empty(): route.pop_front()
	var moving: bool = toward.length() > 0.3
	var speed: float = (2.2 if threat != null else 1.15) if kind == "villager" else 2.3
	velocity.x = toward.normalized().x*speed if moving else 0.0; velocity.z = toward.normalized().z*speed if moving else 0.0
	velocity.y = maxf(-20,velocity.y-20*delta)
	for axis in [0,2,1]:
		var next: Vector3 = position; next[axis] += velocity[axis]*delta
		var door: Vector3i = Vector3i((next+toward.normalized()*0.4).floor())
		if game.world.node_at(door) == VillageContent.WOODEN_DOOR: game.survival.toggle_door(door)
		if not game.world.intersects(next,width,height): position = next
		elif axis == 1: velocity.y = 0
		elif not game.world.intersects(position+Vector3.UP*1.05,width,height): velocity.y = 6.0
	if moving: model.rotation.y = lerp_angle(model.rotation.y,atan2(-toward.x,-toward.z),delta*5)
	else:
		var look: Vector3 = game.player.position-position
		if look.length() < 5: model.rotation.y = lerp_angle(model.rotation.y,atan2(-look.x,-look.z),delta*3)
	for i in legs.size(): legs[i].rotation.x = sin(life*7+i*PI)*0.38 if moving else 0.0
	for arm in arms: arm.rotation.x = -1.0 if attack_cooldown > 0.65 else 0.0

func path_to(goal: Vector3) -> Array:
	var start := Vector3i(position.floor()); var end := Vector3i(goal.floor())
	var queue: Array = [start]; var parents: Dictionary = {start:start}; var best: Vector3i = start
	var cursor: int = 0
	while cursor < queue.size() and cursor < 600:
		var p: Vector3i = queue[cursor]; cursor += 1
		if Vector3(p-end).length_squared() < Vector3(best-end).length_squared(): best = p
		if p == end: break
		for dir in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			var q: Vector3i = p+dir
			if parents.has(q): continue
			if game.world.node_at(q) != VillageContent.WOODEN_DOOR and game.world.intersects(Vector3(q)+Vector3(0.5,0,0.5),width,height): continue
			if not Nodes.solid(game.world.node_at(q+Vector3i.DOWN)): continue
			parents[q] = p; queue.append(q)
	var result: Array = []
	while best != start: result.push_front(Vector3(best)+Vector3(0.5,0,0.5)); best = parents[best]
	return result

func hit(damage: float, from: Vector3 = Vector3.INF) -> void:
	var r: Dictionary = game.villages.record(person_key)
	if not r.is_empty():
		if not r.has("reputations"): r.reputations = {}
		r.reputations[game.player_id] = maxi(-100,game.villages.reputation(r)-25)
	super.hit(damage,from)
	store_record()

func die() -> void:
	PotionEffects.died(self)
	var r: Dictionary = game.villages.record(person_key)
	if not r.is_empty(): r.dead = true; r.health = 0.0
	if kind == "iron_golem": game.spawn_drop(position+Vector3.UP,Nodes.IRON,randi_range(3,5))
	game.puff(center(),Color("bfb6a5"),14); queue_free()
