class_name MobCrossbows
extends RefCounted

# mcl_mobs/combat.lua and mobs_mc/pillager.lua. NPCs have their own crossbow
# state machine and shoot speed; the player's Quick Charge timing is different.
const RADIUS = 20.0
const VIEW = 32.0
const CHARGE = 0.9
const HALF = 0.35
const SHOT_SPEED = 32.0
const DROP_CHANCE = 0.085

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("mob_crossbow_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+37189
		world.set_meta("mob_crossbow_rng",rng)
	return world.get_meta("mob_crossbow_rng")

static func initial(loaded: bool = false) -> Dictionary:
	return {"attacking":false,"phase":0,"visible":0.0,"repath":0.0,"delay":0.0,"using":-1.0,"loaded":loaded,"moving":false,"move_scale":1.0}

static func draw(low: int, high: int, sample: int, rng: RandomNumberGenerator) -> int:
	return clampi(sample,low,high) if sample >= 0 else rng.randi_range(low,high)

static func tick(state: Dictionary, delta: float, visible: bool, distance: float, rng: RandomNumberGenerator = null, sample: int = -1) -> Array:
	if float(state.using) >= 0: state.using += delta
	if not state.attacking:
		state.visible = 0.0; state.repath = 0.0; state.delay = 0.0; state.phase = 0; state.attacking = true
		if state.loaded: state.phase = 2; state.delay = 1+draw(0,20,sample,rng)*0.05
	state.visible = maxf(state.visible,0)+delta if visible else minf(state.visible,0)-delta
	var approach: bool = state.visible < 0.25 or distance > RADIUS
	var events: Array = []
	if approach:
		state.repath -= delta
		if state.repath <= 0:
			state.moving = true; state.move_scale = 0.5 if state.phase > 0 else 1.0
			events.append(["path",state.move_scale]); state.repath = draw(1,2,sample,rng)
	else:
		state.repath = 0.0; state.moving = false
		events.append(["cancel"]); events.append(["halt"]); events.append(["look"])
	match int(state.phase):
		0:
			if not approach: state.phase = 1; state.using = 0.0
		1:
			if state.using < 0: state.phase = 0
			elif state.using >= CHARGE:
				state.loaded = true; state.using = -1.0; state.phase = 2
				state.delay = 1+draw(0,20,sample,rng)*0.05
		2:
			state.delay -= delta
			if state.delay <= 0: state.phase = 3
		3:
			if visible:
				state.phase = 0; state.loaded = false; state.using = -1.0; events.append(["fire"])
	return events

static func initialize(mob: Creature) -> void:
	if not mob.crossbow_weapon.is_empty(): return
	var rng: RandomNumberGenerator = rng_for(mob.game.world)
	var weapon: Dictionary = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"crossbow_loaded":false,"mob_crossbow":true}}
	var factor: float = RegionalDifficulty.special(mob.game,mob.position)
	if rng.randf() < 0.25*factor:
		var roll: Dictionary = Enchanting.generate_reliable(weapon,floorf(5+factor*rng.randi_range(1,18)),EnchantRolls.new(1,rng))
		if not roll.is_empty(): weapon.data.enchantments = roll.enchantments
	if rng.randi_range(1,300) == 1:
		if not weapon.data.has("enchantments"): weapon.data.enchantments = {}
		weapon.data.enchantments["Piercing"] = 1
	mob.crossbow_weapon = weapon
	mob.crossbow_ai = initial()

static func stop(mob: Creature) -> void:
	mob.crossbow_target = null; mob.crossbow_lost = 0
	mob.crossbow_ai = initial(CrossbowUse.loaded_form(mob.crossbow_weapon))

static func visible(mob: Creature, target: Node3D) -> bool:
	var to: Vector3 = target.position+Vector3.UP*(target.height*0.85 if target is Creature else 1.62)
	var from: Vector3 = mob.position+Vector3.UP*1.5
	var ray: Vector3 = to-from
	var hit: Dictionary = mob.game.world.raycast(from,ray.normalized(),ray.length())
	return hit.is_empty() or float(hit.distance) >= ray.length()-0.15

static func eligible(mob: Creature, target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target == mob or target.health <= 0: return false
	if mob.position.distance_to(target.position) > VIEW*mob.detection_factor(): return false
	if target is VoxeyPlayer: return mob.aggressive()
	return target is Creature and target.kind in ["villager","wandering_trader","iron_golem"]

static func choose_target(mob: Creature, delta: float) -> Node3D:
	var current: Node3D = mob.crossbow_target
	var revenge: Node3D = mob.crossbow_revenge
	if is_instance_valid(revenge) and not revenge.is_queued_for_deletion() and revenge.health > 0 and mob.position.distance_to(revenge.position) <= VIEW and (not revenge is VoxeyPlayer or mob.game.gamemode != "creative"):
		mob.crossbow_revenge_lost = 0 if visible(mob,revenge) else mob.crossbow_revenge_lost+delta
		if mob.crossbow_revenge_lost <= 15: return revenge
	mob.crossbow_revenge = null
	if eligible(mob,mob.game.player) and visible(mob,mob.game.player):
		mob.crossbow_lost = 0; return mob.game.player
	if eligible(mob,current):
		if visible(mob,current): mob.crossbow_lost = 0
		else: mob.crossbow_lost += delta
		if mob.crossbow_lost <= 3.0: return current
	for group in [["villager","wandering_trader"],["iron_golem"]]:
		var best: Node3D; var distance: float = VIEW+1
		for target in mob.game.creatures.get_children():
			if target is Creature and target.kind in group and eligible(mob,target) and visible(mob,target):
				var gap: float = mob.position.distance_to(target.position)
				if gap < distance: best = target; distance = gap
		if best != null: mob.crossbow_lost = 0; return best
	return null

static func struck_by(mob: Creature, attacker: Node3D) -> void:
	if not is_instance_valid(attacker) or attacker == mob: return
	if attacker is Creature and attacker.kind in ["pillager","vindicator","evoker","witch","ravager","vex"]: return
	if is_instance_valid(mob.crossbow_revenge) and mob.crossbow_revenge.health > 0: return
	mob.crossbow_revenge = attacker; mob.crossbow_revenge_lost = 0
	for ally in mob.game.creatures.get_children():
		if ally is Creature and ally != mob and ally.kind == "pillager" and not is_instance_valid(ally.crossbow_target) and mob.position.distance_to(ally.position) <= VIEW:
			ally.crossbow_revenge = attacker; ally.crossbow_revenge_lost = 0

static func step(mob: Creature, delta: float) -> Dictionary:
	initialize(mob)
	var target: Node3D = choose_target(mob,delta)
	if target == null:
		stop(mob); return {"active":false,"direction":Vector3.ZERO,"speed":1.0}
	if target != mob.crossbow_target and not mob.crossbow_ai.get("resume",false):
		# A loaded weapon remains loaded across target loss and acquisition.
		mob.crossbow_ai = initial(CrossbowUse.loaded_form(mob.crossbow_weapon))
	mob.crossbow_ai.erase("resume")
	mob.crossbow_target = target
	var events: Array = tick(mob.crossbow_ai,delta,visible(mob,target),mob.position.distance_to(target.position),rng_for(mob.game.world))
	mob.crossbow_weapon.data.crossbow_loaded = mob.crossbow_ai.loaded
	for event in events:
		if event[0] == "fire": shoot(mob,target.position)
	var toward: Vector3 = ((target.position-mob.position)*Vector3(1,0,1)).normalized()
	return {"active":true,"direction":toward if mob.crossbow_ai.moving else Vector3.ZERO,"toward":toward,"speed":mob.crossbow_ai.move_scale if mob.crossbow_ai.moving else 1.0}

static func aim(origin: Vector3, target: Vector3) -> Vector3:
	var direction: Vector3 = target-origin
	direction.y += 0.12*direction.length()
	return direction.normalized()

static func shoot(mob: Creature, target: Vector3, samples: Array = []) -> Array:
	var origin: Vector3 = mob.position+Vector3.UP*1.475
	var directions: Array = CrossbowUse.directions(mob.crossbow_weapon,aim(origin,target),mob.model.rotation.y,samples,14-RegionalDifficulty.source_level(mob.game.difficulty)*4)
	var shots: Array = []
	for direction in directions:
		var shot: Arrow = mob.game.spawn_arrow(origin,direction*SHOT_SPEED)
		shot.shooter_id = mob.get_instance_id(); shot.shooter_kind = "pillager"
		shot.critical = true; shot.recoverable = false; shot.piercing = Inventory.enchantment(mob.crossbow_weapon,"Piercing")
		shots.append(shot)
	return shots

static func visual_stage(mob: Creature) -> int:
	if CrossbowUse.loaded_form(mob.crossbow_weapon): return 3
	var used: float = float(mob.crossbow_ai.get("using",-1.0))
	return -1 if used < 0 else 2 if used >= CHARGE else 1 if used >= HALF else 0

static func pose(mob: Creature) -> void:
	var phase: int = int(mob.crossbow_ai.get("phase",0))
	var pitch: float = 0
	if is_instance_valid(mob.crossbow_target):
		var local: Vector3 = mob.model.to_local(mob.crossbow_target.position)-Vector3.UP*1.5
		pitch = atan2(local.y,Vector2(local.x,local.z).length())
	for i in mob.arms.size():
		mob.arms[i].rotation.x = 1.25+(pitch if phase == 2 else 0.15 if phase == 1 else 0.0)
		mob.arms[i].rotation.y = (0.3 if i == 0 else -0.3) if phase == 1 else 0.0
	if mob.crossbow_model != null:
		var stage: int = visual_stage(mob)
		if stage != mob.crossbow_model_stage:
			mob.crossbow_model_stage = stage
			mob.crossbow_model.mesh = ItemArt.mesh(VillageContent.CROSSBOW,stage)
			mob.crossbow_model.material_override = ItemArt.material(VillageContent.CROSSBOW,stage)
		mob.crossbow_model.rotation.x = -PI/2-(pitch if phase == 2 else 0.0)

static func build_weapon(mob: Creature) -> void:
	for side in [-1,1]:
		var arm: Node3D = mob._joint(Vector3(side*0.29,1.27,0),"CrossbowArm")
		mob._box(Vector3(0,-0.26,0),Vector3(0.16,0.52,0.18),Color("777e70"),"skin",arm)
		mob.arms.append(arm)
	mob.crossbow_model = MeshInstance3D.new(); mob.crossbow_model.position = Vector3(0,1.15,-0.43)
	mob.crossbow_model.scale = Vector3.ONE*0.65; mob.model.add_child(mob.crossbow_model)
	pose(mob)

static func raid_buff(mob: Creature, wave: int, level: int, rng: RandomNumberGenerator, sample: float = -1) -> void:
	var chance: float = [0.0,0.0,0.1,0.25,0.5,0.75][clampi(level,0,5)]
	if (rng.randf() if sample < 0 else sample) >= chance: return
	var data: Dictionary = mob.crossbow_weapon.data
	if not data.has("enchantments"): data.enchantments = {}
	if wave > 3: data.enchantments["Quick Charge"] = 2 if wave > 5 else 1
	data.enchantments["Multishot"] = 1

static func drop_wear(item: Dictionary, first: int, second: int) -> int:
	var uses: float = Durability.uses(item)
	var upper: int = maxi(0,floori(uses)-4)
	return floori(65535.0/uses*clampi(second,0,clampi(first,0,upper))) if uses > 0 else 0

static func drop_weapon(mob: Creature, rng: RandomNumberGenerator, sample: float = -1.0) -> Dictionary:
	var weapon: Dictionary = mob.crossbow_weapon.duplicate(true)
	if weapon.is_empty() or Inventory.enchantment(weapon,"Curse of Vanishing") > 0: return {}
	var chance: float = DROP_CHANCE+int(mob.get_meta("looting",0))*0.01
	if (rng.randf() if sample < 0 else sample) > chance: return {}
	var upper: int = maxi(0,floori(Durability.uses(weapon))-4)
	var first: int = rng.randi_range(0,upper)
	Durability.set_normalized(weapon,Durability.normalized(weapon)+drop_wear(weapon,first,rng.randi_range(0,first)))
	return weapon

static func die(mob: Creature) -> void:
	var rng: RandomNumberGenerator = rng_for(mob.game.world)
	var count: int = rng.randi_range(0,2)+rng.randi_range(0,maxi(0,int(mob.get_meta("looting",0))))
	if count: mob.game.spawn_drop(mob.center(),Nodes.ARROW_ITEM,count)
	var weapon: Dictionary = drop_weapon(mob,rng)
	if not weapon.is_empty() and weapon.get("id",0) != 0: mob.game.spawn_drop(mob.center(),weapon.id,1,int(weapon.wear),weapon.get("data",{}))

static func snapshot(mob: Creature) -> Dictionary:
	return {"weapon":mob.crossbow_weapon.duplicate(true),"ai":mob.crossbow_ai.duplicate(true)}

static func restore(mob: Creature, record: Dictionary) -> void:
	if record.get("weapon") is Dictionary: mob.crossbow_weapon = Inventory.clean_slot(record.weapon)
	if mob.crossbow_weapon.get("id",0) != VillageContent.CROSSBOW: mob.crossbow_weapon = {}; initialize(mob)
	if not mob.crossbow_weapon.has("data"): mob.crossbow_weapon.data = {}
	mob.crossbow_weapon.data["mob_crossbow"] = true
	if not mob.crossbow_weapon.data.has("crossbow_loaded"): mob.crossbow_weapon.data["crossbow_loaded"] = false
	mob.crossbow_ai = initial(CrossbowUse.loaded_form(mob.crossbow_weapon))
	if record.get("ai") is Dictionary:
		for key in mob.crossbow_ai:
			if record.ai.has(key): mob.crossbow_ai[key] = record.ai[key]
		mob.crossbow_ai["resume"] = true
	mob.crossbow_target = null; pose(mob)
