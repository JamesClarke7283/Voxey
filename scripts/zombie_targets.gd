class_name ZombieTargets
extends RefCounted

const REGULAR = ["zombie","husk","drowned","zombie_villager"]
const ALLIES = ["zombie","husk","drowned","zombie_villager","zombified_piglin"]

static func handles(kind: String) -> bool: return kind in ALLIES
static func initial() -> Dictionary:
	return {"mode":"","seen_attack":0,"attack":0,"unseen":15.0,"seek":0.0,"alert_time":0.0,"pulse":0.0}
static func range_for(mob: Creature) -> float:
	return ZombieTraits.view_range(mob) if mob.kind in REGULAR else 35.0
static func valid(mob: Creature, target: Variant) -> bool:
	if not is_instance_valid(target) or not (target is Creature or target is VoxeyPlayer) or target == mob or target.is_queued_for_deletion() or target.health <= 0: return false
	if target is VoxeyPlayer and mob.game.gamemode == "creative": return false
	if mob.kind == "drowned" and mob.game.daylight >= 0.5:
		if target is Creature and (Boats.is_passenger(target) or MobJockeys.vehicle(target) != null): return false
		if target is VoxeyPlayer and (mob.game.boats.ridden() or is_instance_valid(mob.game.survival.mount)): return false
		if not Fluids.water(mob.game.world.node_at(Vector3i(target.position.floor()))): return false
	return true
static func visible(mob: Creature, target: Node3D) -> bool:
	return mob._sees(target.position+Vector3.UP*(target.height*0.85 if target is Creature else 1.62))

# Return the *previous* visibility timer result, as track_current_target does.
static func track(state: Dictionary, delta: float, sight: bool, distance: float, limit: float, allowed: bool, persistence: float) -> bool:
	if not allowed or distance > limit: return false
	if sight: state.unseen = persistence; return true
	var old: float = float(state.get("unseen",persistence)); state.unseen = old-delta
	return old >= 0

static func retaliation(distance: float, limit: float, allowed: bool, owner: bool = false) -> Dictionary:
	return {"broadcast":allowed and not owner,"target":allowed and not owner and distance < limit}
static func alert_candidate(distance: float, allowed: bool) -> bool:
	return allowed and distance < 72
static func alert_track(state: Dictionary, delta: float, sight: bool, distance: float, limit: float, allowed: bool) -> bool:
	state.alert_time -= delta
	return track(state,delta,sight,distance,72 if state.alert_time > 0 else limit,allowed,15)

static func alert(mob: Creature, target: Node3D) -> bool:
	if not handles(mob.kind) or mob.zombie_target != null: return false
	mob.zombie_alert = target
	return true

static func struck(mob: Creature, attacker: Node3D) -> void:
	if not handles(mob.kind) or not is_instance_valid(attacker) or attacker == mob: return
	if not (attacker is Creature or attacker is VoxeyPlayer): return
	if mob.zombie_ai.is_empty(): mob.zombie_ai = initial()
	mob.zombie_ai.attack += 1; mob.zombie_attacker = attacker

static func in_alert_box(offset: Vector3, width: float, height: float, view: float) -> bool:
	return offset.x >= -view-width and offset.x <= view+width and offset.y >= -view and offset.y <= view+height and offset.z >= -view-width and offset.z <= view+width

static func broadcast(mob: Creature, target: Node3D, piglin_only: bool = false) -> void:
	for ally in mob.game.creatures.get_children():
		if ally == mob or ally.is_queued_for_deletion() or ally.kind not in ALLIES: continue
		if piglin_only:
			var offset: Vector3 = ally.position-mob.position
			if ally.kind != "zombified_piglin" or absf(offset.x) > range_for(mob) or absf(offset.z) > range_for(mob) or absf(offset.y) > 10: continue
		else:
			if mob.kind == "zombified_piglin" and ally.kind != "zombified_piglin": continue
			if not in_alert_box(ally.position-mob.position,mob.width,mob.height,range_for(mob)): continue
		alert(ally,target)

static func detection(invisible: bool, pieces: int, head_factor: float) -> float:
	return maxf(0.1,pieces/4.0)*0.7*head_factor if invisible else head_factor

static func detection_for(mob: Creature, target: Node3D) -> float:
	var slots: Array = target.armor_slots if target is VoxeyPlayer else target.mob_armor
	var pieces: int = 0
	for slot in slots:
		if int(slot.get("id",0)) != 0: pieces += 1
	var head_factor: float = mob.detection_factor() if target is VoxeyPlayer else 1.0
	return detection(PotionEffects.level(target,"invisibility") > 0,pieces,head_factor)

static func nearest(mob: Creature, group: Array, limit: float) -> Node3D:
	var best: Node3D; var distance: float = INF
	var candidates: Array = [mob.game.player] if group == ["player"] else mob.game.creatures.get_children()
	for target in candidates:
		if not valid(mob,target) or (target is Creature and target.kind not in group): continue
		var gap: float = mob.position.distance_to(target.position)
		var factor: float = detection_for(mob,target)
		if gap <= limit*factor and gap < distance and visible(mob,target): best = target; distance = gap
	return best

static func step(mob: Creature, delta: float) -> Node3D:
	if mob.zombie_ai.is_empty(): mob.zombie_ai = initial()
	var state: Dictionary = mob.zombie_ai; var before: String = state.mode; var old: Node3D = mob.zombie_target
	state.seek -= delta; var seek: bool = state.seek <= 0
	var result: Node3D; var mode: String = ""; var radius: float = range_for(mob)
	if before == "retaliation":
		if is_instance_valid(old) and track(state,delta,visible(mob,old),mob.position.distance_to(old.position),radius,valid(mob,old),15): result = old; mode = before
	elif state.seen_attack != state.attack:
		state.seen_attack = state.attack
		var distance: float = mob.position.distance_to(mob.zombie_attacker.position) if is_instance_valid(mob.zombie_attacker) else INF
		var reply: Dictionary = retaliation(distance,radius,valid(mob,mob.zombie_attacker))
		if reply.broadcast: broadcast(mob,mob.zombie_attacker)
		if reply.target: result = mob.zombie_attacker; mode = "retaliation"
	if result == null and mob.kind in REGULAR:
		var groups: Array = [["player"],["villager","wandering_trader"],["iron_golem"]]
		if mob.kind == "drowned": groups.append(["axolotl"])
		for group in groups:
			var name: String = str(group[0])
			if before == name:
				if is_instance_valid(old) and track(state,delta,visible(mob,old),mob.position.distance_to(old.position),radius,valid(mob,old),3): result = old
			elif seek:
				state.seek = 0.5; result = nearest(mob,group,radius)
			if result != null: mode = name; break
	if result == null:
		if before == "alert":
			if is_instance_valid(old) and alert_track(state,delta,visible(mob,old),mob.position.distance_to(old.position),radius,valid(mob,old)): result = old; mode = before
		elif is_instance_valid(mob.zombie_alert) and alert_candidate(mob.position.distance_to(mob.zombie_alert.position),valid(mob,mob.zombie_alert)):
			result = mob.zombie_alert; mode = "alert"; state.alert_time = 20
		mob.zombie_alert = null
	if result != old:
		state.unseen = 15 if mode in ["retaliation","alert"] else 3
		if before == "alert": state.alert_time = 0; mob.zombie_alert = null
	state.mode = mode; mob.zombie_target = result
	if mob.kind == "zombified_piglin" and result != null:
		state.pulse -= delta
		if state.pulse <= 0:
			broadcast(mob,result,true); state.pulse = ZombieTraits.rng_for(mob.game.world).integer(4,6)/20.0
	return result
