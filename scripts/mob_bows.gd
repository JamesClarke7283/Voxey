class_name MobBows
extends RefCounted

# mcl_mobs:attack_bowshoot and mobs_mc/skeleton+stray.lua. NPCs draw for
# longer than a player and alternate between pathing and a slow strafe.
const RANGE = 16.0
const SPEED = 0.5333333*60.0

static func handles(kind: String) -> bool:
	return kind in ["skeleton","stray","wither_skeleton"]

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("mob_bow_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+73332
		world.set_meta("mob_bow_rng",rng)
	return world.get_meta("mob_bow_rng")

static func initial() -> Dictionary:
	return {"attacking":false,"visible":0.0,"strafe":-1.0,"x":1,"z":1,"cooldown":0.0,"using":-1.0,"path_timer":0.0,"path_set":false,"mode":"","moving":false}

static func tick(state: Dictionary, delta: float, sight: bool, distance: float, difficulty: int, rng: RandomNumberGenerator = null, unit: float = -1, roll: int = -1) -> Array:
	if state.using >= 0: state.using += delta
	if state.path_set: state.path_timer -= delta
	if not state.attacking:
		state.visible = 0.0; state.strafe = -1.0; state.x = 1; state.z = 1; state.cooldown = 0.0; state.attacking = true
	state.visible = maxf(state.visible,0)+delta if sight else minf(state.visible,0)-delta
	var events: Array = []
	if distance < 15 and state.visible >= 1:
		if state.mode == "path":
			events.append(["cancel"]); events.append(["halt"]); state.mode = ""; state.moving = false
		state.strafe += delta; state.path_timer = 0.0; state.path_set = true
	else:
		if state.mode == "strafe":
			events.append(["halt"]); state.mode = ""; state.moving = false
		if not state.path_set:
			state.path_set = true; state.path_timer = (rng.randf() if unit < 0 else unit)*0.5
		if state.path_timer <= 0:
			state.path_timer = 0.5; state.mode = "path"; state.moving = true; events.append(["path",1.0])
		state.strafe = -1.0
	if state.strafe >= 1:
		if (rng.randi_range(1,10) if roll < 0 else roll) <= 3: state.z = -state.z
		if (rng.randi_range(1,10) if roll < 0 else roll) <= 3: state.x = -state.x
		state.strafe = 0.0
	if state.strafe > -1:
		if distance > 15*0.75: state.z = 1
		elif distance < 15*0.55: state.z = -1
		state.mode = "strafe"; state.moving = true
		events.append(["look"]); events.append(["walk"])
	if state.using >= 0:
		if not sight and state.visible < -3:
			state.using = -1.0; events.append(["release"])
		elif sight and state.using > 1:
			state.using = -1.0; state.cooldown = 1.0 if difficulty >= 3 else 2.0
			events.append(["release"]); events.append(["fire"])
	else:
		state.cooldown = maxf(0,state.cooldown-delta)
		if state.cooldown <= 0: state.using = 0.0; events.append(["use"])
	return events

static func initialize(mob: Creature) -> void:
	if not mob.bow_weapon.is_empty() or mob.held_weapon_ready: return
	var rng: RandomNumberGenerator = rng_for(mob.game.world)
	mob.bow_weapon = {"id":Nodes.BOW,"count":1,"wear":0}
	var factor: float = RegionalDifficulty.special(mob.game,mob.position)
	if rng.randf() < 0.25*factor:
		var roll: Dictionary = Enchanting.generate_reliable(mob.bow_weapon,floorf(5+factor*rng.randi_range(1,18)),EnchantRolls.new(1,rng))
		if not roll.is_empty(): mob.bow_weapon.data = {"enchantments":roll.enchantments}
	mob.bow_ai = initial()

static func stop(mob: Creature) -> void:
	mob.bow_target = null; mob.bow_lost = 0; mob.bow_ai = initial()

static func visible(mob: Creature, target: Node3D) -> bool:
	var start: Vector3 = mob.position+Vector3.UP*1.74
	var offset: Vector3 = target.position+Vector3.UP*(target.height*0.85 if target is Creature else 1.62)-start
	var hit: Dictionary = mob.game.world.raycast(start,offset.normalized(),offset.length())
	return hit.is_empty() or float(hit.distance) >= offset.length()-0.15

static func alive(mob: Creature, target: Node3D) -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target != mob and target.health > 0 and (not target is VoxeyPlayer or mob.game.gamemode != "creative")

static func eligible(mob: Creature, target: Node3D) -> bool:
	if not alive(mob,target) or mob.position.distance_to(target.position) > RANGE*mob.detection_factor(): return false
	return mob.aggressive() if target is VoxeyPlayer else target is Creature and (target.kind == "iron_golem" or mob.kind == "wither_skeleton" and target.kind in ["piglin","piglin_brute"])

static func choose_target(mob: Creature, delta: float) -> Node3D:
	var revenge: Node3D = mob.bow_revenge
	if alive(mob,revenge) and mob.position.distance_to(revenge.position) <= RANGE:
		mob.bow_revenge_lost = 0 if visible(mob,revenge) else mob.bow_revenge_lost+delta
		if mob.bow_revenge_lost <= 15: return revenge
	mob.bow_revenge = null
	if eligible(mob,mob.game.player) and visible(mob,mob.game.player):
		mob.bow_lost = 0; return mob.game.player
	if eligible(mob,mob.bow_target):
		mob.bow_lost = 0 if visible(mob,mob.bow_target) else mob.bow_lost+delta
		if mob.bow_lost <= 3: return mob.bow_target
	var best: Node3D; var distance: float = RANGE+1
	for group in [["iron_golem"],["piglin","piglin_brute"] if mob.kind == "wither_skeleton" else []]:
		for target in mob.game.creatures.get_children():
			if target.kind in group and eligible(mob,target) and visible(mob,target):
				var gap: float = mob.position.distance_to(target.position)
				if gap < distance: best = target; distance = gap
		if best != null: break
	if best != null: mob.bow_lost = 0
	return best

static func struck_by(mob: Creature, attacker: Node3D) -> void:
	if not alive(mob,attacker): return
	if alive(mob,mob.bow_revenge): return
	mob.bow_revenge = attacker; mob.bow_revenge_lost = 0

static func step(mob: Creature, delta: float) -> Dictionary:
	initialize(mob)
	if not is_inf(mob.runaway_threat(["wolf"],6.0).x):
		stop(mob); return {"active":false,"direction":Vector3.ZERO,"speed":1.0}
	var target: Node3D = choose_target(mob,delta)
	if target == null:
		stop(mob); return {"active":false,"direction":Vector3.ZERO,"speed":1.0}
	if target != mob.bow_target and not mob.bow_ai.get("resume",false): mob.bow_ai = initial()
	mob.bow_ai.erase("resume"); mob.bow_target = target
	if int(mob.bow_weapon.get("id",0)) != Nodes.BOW:
		mob.prey_target = target if target is Creature else null
		return {"active":true,"direction":((target.position-mob.position)*Vector3(1,0,1)).normalized(),"toward":((target.position-mob.position)*Vector3(1,0,1)).normalized(),"speed":1.0}
	mob.prey_target = null
	var events: Array = tick(mob.bow_ai,delta,visible(mob,target),mob.position.distance_to(target.position),RegionalDifficulty.source_level(mob.game.difficulty),rng_for(mob.game.world))
	for event in events:
		if event[0] == "fire": shoot(mob,target.position,target.height if target is Creature else 1.8)
	var toward: Vector3 = ((target.position-mob.position)*Vector3(1,0,1)).normalized()
	var direction: Vector3 = toward if mob.bow_ai.moving else Vector3.ZERO
	var speed: float = 1.0
	if mob.bow_ai.mode == "strafe":
		direction = toward*mob.bow_ai.z*0.5+toward.cross(Vector3.UP)*mob.bow_ai.x*0.5; speed = 0.25
		# Match the source's safe forward fallback at an obstruction or ledge.
		var next: Vector3 = mob.position+direction*mob.info().speed*speed*0.05
		if mob.game.world.intersects(next,mob.width,mob.height) or not mob.game.world.intersects(next-Vector3.UP*0.15,mob.width,0.1): direction = toward
	return {"active":true,"direction":direction,"toward":toward,"speed":speed}

static func aim(origin: Vector3, target: Vector3, target_height: float) -> Vector3:
	var direction: Vector3 = target+Vector3.UP*target_height*0.33-origin
	direction.y += 0.12*direction.length()
	return direction.normalized()

static func shoot(mob: Creature, target: Vector3, target_height: float, samples: Array = []) -> Arrow:
	var rng: RandomNumberGenerator = rng_for(mob.game.world)
	if samples.size() < 8:
		samples = []; for i in 8: samples.append(rng.randf())
	var origin: Vector3 = mob.position+Vector3.UP*1.5
	var params: Dictionary = projectile(mob.bow_weapon,origin,target,target_height,RegionalDifficulty.source_level(mob.game.difficulty),samples)
	var shot: Arrow = mob.game.spawn_arrow(origin,params.velocity,UndeadVariants.arrow_item(mob.kind))
	shot.damage = params.damage; shot.punch = params.punch; shot.flame = params.flame
	shot.critical = false; shot.recoverable = false; shot.shooter_id = mob.get_instance_id(); shot.shooter_kind = mob.kind
	return shot

static func projectile(item: Dictionary, origin: Vector3, target: Vector3, target_height: float, level: int, samples: Array) -> Dictionary:
	var direction: Vector3 = aim(origin,target,target_height)+BowUse.inaccuracy(Vector3.ZERO,samples.slice(2))*(14-level*4)
	var damage: float = 2.0+level*0.11+0.57425*(float(samples[0])-float(samples[1]))
	var power: int = Inventory.enchantment(item,"Power")
	if power > 0: damage += power*0.5+0.5
	return {"velocity":direction*SPEED,"damage":damage,"punch":Inventory.enchantment(item,"Punch"),"flame":Inventory.enchantment(item,"Flame") > 0}

static func drop_weapon(mob: Creature, rng: RandomNumberGenerator, sample: float = -1.0) -> Dictionary:
	return MobWeapons.drop_item(mob,EnchantRolls.new(1,rng),sample)

static func die(mob: Creature) -> void:
	var item: Dictionary = drop_weapon(mob,rng_for(mob.game.world))
	if not item.is_empty() and item.get("id",0) != 0: mob.game.spawn_drop(mob.center(),item.id,1,int(item.wear),item.get("data",{}))

static func qualifies_for_sniper(kind: String, reason: String, player_source: bool, distance: float) -> bool:
	# The inherited on_die callback tests the player's current distance > 20,
	# despite the source achievement's fifty-block description.
	return kind in ["skeleton","stray"] and reason in ["arrow","trident"] and player_source and distance > 20

static func killed_by(mob: Creature, attacker: Node3D, reason: String, was_alive: bool) -> void:
	if not was_alive or mob.health > 0 or not is_instance_valid(attacker): return
	if qualifies_for_sniper(mob.kind,reason,attacker is VoxeyPlayer,mob.position.distance_to(attacker.position)):
		mob.game.achievements.award("sniper_duel")

static func pose(mob: Creature) -> void:
	if int(mob.bow_weapon.get("id",0)) != Nodes.BOW:
		for arm in mob.arms: arm.rotation.y = 0
		return
	var using: float = float(mob.bow_ai.get("using",-1))
	var stage: int = -1 if using < 0 else 2 if using >= 0.5 else 1 if using >= 0.2 else 0
	if mob.bow_model != null and stage != mob.bow_model_stage:
		mob.bow_model_stage = stage; mob.bow_model.mesh = ItemArt.mesh(Nodes.BOW,stage); mob.bow_model.material_override = ItemArt.material(Nodes.BOW,stage)
	for arm in mob.arms: arm.rotation.y = 0
	if is_instance_valid(mob.bow_target):
		var offset: Vector3 = mob.bow_target.position+Vector3.UP*0.6-mob.position-Vector3.UP*1.5
		var pitch: float = atan2(offset.y,Vector2(offset.x,offset.z).length())
		for arm in mob.arms: arm.rotation.x = 1.5+pitch; arm.rotation.y = 0
		if mob.arms.size() > 1: mob.arms[0].rotation.y = -0.65
	if mob.bow_hand != null: mob.bow_hand.rotation.x = -1.5

static func build_weapon(mob: Creature) -> void:
	mob.bow_hand = mob._joint(Vector3(0,-0.56,0),"Bow",mob.arms[1])
	mob.bow_model = MeshInstance3D.new(); mob.bow_model.scale = Vector3.ONE*0.55
	mob.bow_model.rotation = Vector3(0,PI/2,0); mob.bow_hand.add_child(mob.bow_model); pose(mob)

static func snapshot(mob: Creature) -> Dictionary:
	return {"weapon":mob.bow_weapon.duplicate(true),"ai":mob.bow_ai.duplicate(true),"conversion_clock":UndeadVariants.conversion_clock(mob)}

static func restore(mob: Creature, record: Dictionary) -> void:
	if record.get("weapon") is Dictionary: mob.bow_weapon = Inventory.clean_slot(record.weapon)
	initialize(mob); mob.bow_ai = initial()
	if record.get("ai") is Dictionary:
		for key in mob.bow_ai:
			if record.ai.has(key): mob.bow_ai[key] = record.ai[key]
		mob.bow_ai.resume = true
	mob.set_meta("conversion_clock",float(record.get("conversion_clock",0)))
	mob.bow_target = null; pose(mob)
