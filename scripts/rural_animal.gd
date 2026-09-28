class_name RuralAnimal
extends Creature

var trust: int = 0
var saddled: bool = false
var horse_armor: bool = false

func _ready() -> void:
	# `horse:on_spawn`: each horse rolls its own statistics and coat before its
	# body is built, so the coat is drawn once.
	if Equines.is_equine(kind) and game != null and game.world != null: Equines.initialize(self,Equines.rng_for(game.world))
	super._ready()
	if Equines.is_equine(kind): health = Equines.max_health(self)

func _build_model() -> void:
	# The horse family draws its own bodies (`Equines.build`); a pig keeps the
	# shared quadruped model.
	if Equines.is_equine(kind): Equines.build(self); return
	if kind not in ["rabbit","horse"]:
		super._build_model(); return
	if kind == "rabbit":
		_box(Vector3(0,0.32,0.08),Vector3(0.34,0.4,0.48),Color("ae987c"),"fur")
		head = _joint(Vector3(0,0.42,-0.24),"Head")
		_box(Vector3.ZERO,Vector3(0.28,0.28,0.3),Color("c1ad8e"),"fur",head)
		for side in [-1,1]:
			_box(Vector3(side*0.085,0.3,0.03),Vector3(0.07,0.42,0.08),Color("b49d80"),"fur",head)
			_box(Vector3(side*0.085,0.3,-0.015),Vector3(0.035,0.3,0.012),Color("caab9c"),"",head)
			_box(Vector3(side*0.105,0.04,-0.16),Vector3(0.045,0.045,0.02),Color("39332d"),"",head)
			for z in [-0.17,0.21]: _box(Vector3(side*0.16,0.06,z),Vector3(0.14,0.12,0.28),Color("b6a082"),"fur")
		_box(Vector3(0,0.3,0.37),Vector3.ONE*0.14,Color("e4dac6"),"fur")
	else:
		_box(Vector3(0,1.03,0.08),Vector3(0.65,0.66,1.24),Color("98704e"),"fur")
		_box(Vector3(0,1.43,-0.47),Vector3(0.38,0.78,0.42),Color("a17b56"),"fur")
		head = _joint(Vector3(0,1.8,-0.58),"Head")
		_box(Vector3(0,-0.08,-0.1),Vector3(0.4,0.45,0.65),Color("a98460"),"fur",head)
		_box(Vector3(0,-0.17,-0.4),Vector3(0.42,0.27,0.24),Color("cebb9a"),"fur",head)
		for side in [-1,1]:
			_box(Vector3(side*0.13,0.26,0.06),Vector3(0.1,0.24,0.14),Color("815d42"),"fur",head)
			_box(Vector3(side*0.21,0.035,-0.24),Vector3(0.025,0.07,0.07),Color("302d29"),"",head)
			for z in [-0.39,0.55]:
				var leg := _joint(Vector3(side*0.23,0.83,z),"Leg")
				_box(Vector3(0,-0.35,0),Vector3(0.17,0.7,0.2),Color("8b6649"),"fur",leg)
				_box(Vector3(0,-0.77,-0.015),Vector3(0.2,0.15,0.24),Color("393933"),"",leg); legs.append(leg)
		_box(Vector3(0,1.49,-0.235),Vector3(0.16,0.75,0.09),Color("4a3d30"),"fur")
		_box(Vector3(0,0.83,0.82),Vector3(0.16,0.83,0.15),Color("493d32"),"fur")

func _physics_process(delta: float) -> void:
	if game.playing() and game.leads.sleep_if_unloaded(self): return
	if Equines.is_equine(kind) and (trust > 0 or not custom_name.is_empty()) and position.distance_to(game.player.position) > 85: return
	# A llama's caravan, retaliation and spit (`Llamas.step`).
	if Llamas.is_llama(kind) and game.playing(): Llamas.step(game,self,delta)
	if Equines.is_equine(kind) and game.playing():
		Equines.trap_step(game,self,delta)
		if is_queued_for_deletion(): return
		Equines.breed_step(game,self,delta)
		if growth_remaining > 0.0:
			growth_remaining = maxf(0.0,growth_remaining-delta)
			if growth_remaining == 0.0: Farming.resize(self)
	if game.survival.mount == self:
		animate(delta,true)
		# `horse_maybe_tame`: an untamed horse decides whether to keep its rider.
		if Equines.is_equine(kind) and not Equines.tamed(self): Equines.evaluate(game,self,delta,Equines.rng_for(game.world))
		if Equines.is_equine(kind) and not Equines.drivable(self): Equines.ridden_wander(self,delta)
		return
	if kind == "rabbit" and grounded and leap_cooldown <= 0:
		velocity.y = 4.2; leap_cooldown = 1.1
	super._physics_process(delta)

func equip_saddle() -> void:
	if Equines.is_equine(kind):
		saddled = true; Equines.draw_saddle(self); return
	saddled = true
	_box(Vector3(0,1.37,0.17),Vector3(0.66,0.12,0.56),Color("784c34"),"cloth")
	for side in [-1,1]: _box(Vector3(side*0.35,1.06,0.17),Vector3(0.06,0.5,0.16),Color("c5ad78"),"")

func equip_horse_armor() -> void:
	# The legacy flag is leather horse armour.
	if Equines.is_equine(kind): Equines.equip_armor(self,VillageContent.LEATHER_HORSE_ARMOR); return
	horse_armor = true
	_box(Vector3(0,1.1,0.02),Vector3(0.69,0.53,1.02),Color("76563e"),"cloth")

func hit(damage: float, from: Vector3 = Vector3.INF, reason: String = "") -> void:
	if Llamas.is_llama(kind): Llamas.struck(game,self,from)
	# Horse armour sets the share of fleshy damage that lands.
	if Equines.is_equine(kind): super.hit(damage*(Equines.armor_factor(self) if reason not in Creature.BYPASSES_ARMOR else 1.0),from,reason); return
	super.hit(damage*0.7 if horse_armor else damage,from,reason)

func die() -> void:
	if saddled: game.spawn_drop(center(),Nodes.SADDLE)
	if Equines.is_equine(kind):
		if Equines.armor_id(self) != 0: game.spawn_drop(center(),Equines.armor_id(self))
		if Llamas.carpet(self) != 0: game.spawn_drop(center(),Llamas.carpet(self))
		if has_meta("equine_chest"):
			game.spawn_drop(center(),Nodes.CHEST)
			for slot in Equines.chest(self):
				if int(slot.get("count",0)) > 0: game.spawn_drop(center(),int(slot.id),int(slot.count),int(slot.get("wear",0)),slot.get("data",{}))
	elif horse_armor: game.spawn_drop(center(),VillageContent.LEATHER_HORSE_ARMOR)
	if game.survival.mount == self: game.survival.mount = null
	super.die()
