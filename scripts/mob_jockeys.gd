class_name MobJockeys
extends RefCounted

const SEAT = Vector3(0,0.176,0)

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("mob_jockey_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+239771
		world.set_meta("mob_jockey_rng",rng)
	return world.get_meta("mob_jockey_rng")

static func vehicle(mob: Creature) -> Creature:
	var result: Variant = mob.get_meta("jockey_vehicle") if mob.has_meta("jockey_vehicle") else null
	return result if is_instance_valid(result) and not result.is_queued_for_deletion() else null

static func rider(mob: Creature) -> Creature:
	var result: Variant = mob.get_meta("jockey_rider") if mob.has_meta("jockey_rider") else null
	return result if is_instance_valid(result) and not result.is_queued_for_deletion() else null

static func eligible(chicken: Creature) -> bool:
	return chicken.kind == "chicken" and chicken.health > 0 and not chicken.is_queued_for_deletion() and rider(chicken) == null

# The source's if/elseif is deliberate: failing to find a chicken after the
# first successful roll does not proceed to the new-chicken roll.
static func decision(child: bool, disabled: bool, first: int, second: int, found: bool) -> String:
	if not child or disabled: return "none"
	if first <= 5: return "existing" if found else "none"
	return "new" if second <= 5 else "none"

static func chicken_step(timer: float, delta: float, child: bool, jockey: bool) -> Dictionary:
	if child or jockey: return {"timer":timer,"lay":false,"xp":10 if jockey else 1}
	var remaining: float = timer-delta
	return {"timer":remaining if remaining > 0 else -1.0,"lay":remaining <= 0,"xp":1}

static func spawn_for(mob: Creature) -> void:
	if not MobBabies.baby(mob) or mob.get_meta("no_jockey",false) or vehicle(mob) != null: return
	var rng: RandomNumberGenerator = rng_for(mob.game.world)
	var first: int = rng.randi_range(1,100)
	if first <= 5:
		for candidate in mob.game.creatures.get_children():
			if eligible(candidate) and mob.position.distance_to(candidate.position) <= 8:
				attach(mob,candidate); return
	elif rng.randi_range(1,100) <= 5:
		var chicken: Creature = mob.game.spawn_creature("chicken",mob.position)
		if chicken != null: attach(mob,chicken)

static func attach(child: Creature, chicken: Creature) -> bool:
	if child == chicken or (not MobBabies.baby(child) and child.kind != "villager") or not eligible(chicken) or vehicle(child) != null or Boats.is_passenger(child): return false
	child.set_meta("jockey_vehicle",chicken); chicken.set_meta("jockey_rider",child)
	child.set_meta("jockey_owned",true); chicken.set_meta("chicken_jockey",true)
	if child.has_meta("trial_key"):
		chicken.set_meta("jockey_trial_owner",true); Farming.forget(chicken)
	if child is VillageMob:
		child.game.villages.record(child.person_key)["jockey_vehicle"] = chicken.farm_id
	Farming.forget(child); sync(child); Farming.remember(chicken)
	return true

static func sync(child: Creature) -> void:
	var chicken: Creature = vehicle(child)
	if chicken == null: return
	child.position = chicken.position+SEAT*chicken.model.scale.y
	child.velocity = chicken.velocity; child.grounded = chicken.grounded
	child.model.rotation.y = chicken.model.rotation.y
	for i in child.legs.size(): child.legs[i].rotation = Vector3(-1.3,(-0.3 if i == 0 else 0.3),0)

static func detach(child: Creature) -> void:
	var chicken: Creature = vehicle(child)
	child.remove_meta("jockey_vehicle"); child.remove_meta("jockey_owned")
	for leg in child.legs: leg.rotation = Vector3.ZERO
	if child is VillageMob: child.game.villages.record(child.person_key).erase("jockey_vehicle")
	if chicken != null:
		chicken.remove_meta("jockey_rider"); chicken.remove_meta("jockey_trial_owner"); Farming.register(chicken)
	Farming.register(child)

static func died(mob: Creature) -> void:
	var child: Creature = rider(mob)
	if child != null: detach(child)
	var chicken: Creature = vehicle(mob)
	if chicken != null:
		chicken.remove_meta("jockey_rider"); chicken.remove_meta("jockey_trial_owner"); Farming.register(chicken)
		mob.remove_meta("jockey_vehicle"); mob.remove_meta("jockey_owned")

static func remove_pair(mob: Creature, permanent: bool = false) -> void:
	var child: Creature = rider(mob)
	if child != null:
		if permanent and child is VillageMob: child.game.villages.record(child.person_key)["dead"] = true
		child.remove_meta("jockey_vehicle"); child.remove_meta("jockey_owned"); child.queue_free()
	mob.remove_meta("jockey_rider")

static func hold_vehicle(mob: Creature, delta: float) -> bool:
	if rider(mob) == null: return false
	mob.weather_step(delta)
	return true

static func move(child: Creature, delta: float, direction: Vector3) -> bool:
	var chicken: Creature = vehicle(child)
	if chicken == null: return false
	if Boats.is_passenger(chicken): sync(child); return true
	var speed: float = float(chicken.info().speed)*PotionEffects.speed(chicken)
	chicken.direction = direction; chicken.knock = chicken.knock.move_toward(Vector3.ZERO,delta*12)
	chicken.velocity.x = direction.x*speed+chicken.knock.x; chicken.velocity.z = direction.z*speed+chicken.knock.z
	if chicken.submerged(): chicken.velocity.y = clampf((float(chicken.water_surface())+1-chicken.position.y)*2,-1.6,2.4)
	else: chicken.velocity.y = maxf(-1.6,chicken.velocity.y-22*delta)
	chicken.grounded = false
	var moved: Vector3 = chicken.position
	for axis in [0,2,1]:
		var next: Vector3 = moved; next[axis] += chicken.velocity[axis]*delta
		if not chicken.game.world.intersects(next,chicken.width,chicken.height): moved = next
		elif axis == 1:
			chicken.grounded = chicken.velocity.y < 0; chicken.velocity.y = 0
		elif not chicken.game.world.intersects(moved+Vector3.UP*1.05,chicken.width,chicken.height): chicken.velocity.y = 7.2
	chicken.position = moved
	if direction.length() > 0.1: chicken.model.rotation.y = lerp_angle(chicken.model.rotation.y,atan2(-direction.x,-direction.z),delta*5)
	chicken.animate(delta); sync(child)
	return true

static func snapshot(chicken: Creature) -> Dictionary:
	var child: Creature = rider(chicken)
	if child == null: return {}
	var saved: Dictionary = Farming.state(child)
	if child is VillageMob:
		child.store_record(); saved.person = child.game.villages.record(child.person_key).duplicate(true)
	return saved

static func restore(chicken: Creature, record: Dictionary) -> void:
	chicken.set_meta("chicken_jockey",bool(record.get("chicken_jockey",false)))
	var saved: Variant = record.get("jockey",{})
	if not saved is Dictionary or saved.is_empty() or rider(chicken) != null: return
	var child: Creature
	if saved.get("person") is Dictionary and not saved.person.is_empty():
		for existing in chicken.game.creatures.get_children():
			if existing is VillageMob and existing.person_key == saved.person.key and not existing.is_queued_for_deletion(): child = existing; break
	if child == null: child = chicken.game.spawn_creature(str(saved.get("kind","zombie")),chicken.position,str(saved.get("farm_id","")),{"baby":bool(saved.get("baby",false)),"jockey":false,"owned":true})
	if child is VillageMob and saved.get("person") is Dictionary:
		var people: Dictionary = chicken.game.villages.state().people
		if child.person_key != str(saved.person.key): people.erase(child.person_key)
		people[saved.person.key] = saved.person.duplicate(true)
		child.bind(people[saved.person.key])
	if child == null: return
	Farming.restore_state(child,saved)
	if not attach(child,chicken): child.queue_free()

# Trial encounters own both entities; ordinary pairs are owned by the chicken.
static func vehicle_state(child: Creature) -> Dictionary:
	var chicken: Creature = vehicle(child)
	return Farming.state(chicken,false) if chicken != null else {}

static func restore_vehicle(child: Creature, data: Dictionary) -> void:
	if data.is_empty() or vehicle(child) != null: return
	var chicken: Creature = Farming.active(child.game,str(data.get("farm_id","")))
	if chicken == null: chicken = child.game.spawn_creature("chicken",child.position,str(data.get("farm_id","")))
	Farming.restore_state(chicken,data)
	if not attach(child,chicken): chicken.queue_free()

static func removing(child: Creature) -> void:
	var chicken: Creature = vehicle(child)
	if chicken != null and chicken.get_meta("jockey_trial_owner",false):
		chicken.remove_meta("jockey_rider"); chicken.queue_free()
