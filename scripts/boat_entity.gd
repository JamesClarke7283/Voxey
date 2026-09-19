class_name BoatEntity
extends Node3D

var game: Node3D
var service: Boats
var key: String
var item_id: int = VillageContent.BOAT_OAK
var saved: Dictionary = {}
var passenger: Creature
var passenger_processing: bool = true
var speed: float = 0
var vertical: float = 0
var health: float = 4
var regeneration: float = 0
var control := Vector3.ZERO
var removed: bool = false
var pickup_timer: float = 0
var animation: float = 0
var paddles: Array = []

func _ready() -> void:
	paddles = BoatArt.build(self,item_id)

func _physics_process(delta: float) -> void:
	if removed or game == null or not game.playing() or not game.world.loaded_at(position): return
	step(delta)

func step(delta: float) -> void:
	if removed: return
	if is_instance_valid(passenger) and (passenger.is_queued_for_deletion() or passenger.health <= 0): passenger = null; saved.erase("passenger")
	if is_instance_valid(passenger):
		Farming.tick(passenger,delta)
		if passenger is SnowGolem:
			passenger.environment(delta)
			if passenger.health <= 0 or passenger.is_queued_for_deletion(): passenger = null; saved.erase("passenger")
		if is_instance_valid(passenger) and passenger.kind == "chicken" and passenger.growth_remaining <= 0:
			passenger.egg_timer -= delta
			if passenger.egg_timer <= 0:
				game.spawn_drop(passenger.position+Vector3.UP*0.3,Nodes.EGG); passenger.egg_timer = randi_range(300,600)
	regeneration += delta
	if health < 4 and regeneration >= 0.5: health = minf(4,health+1); regeneration = 0
	if health >= 4: regeneration = 0
	if service.riding != self: control = Vector3.ZERO
	# A fixed 20 Hz reference preserves the source's per-server-step forces
	# while substeps keep faster renders and long frames from changing speed.
	var remaining: float = minf(delta,0.5)
	while remaining > 0.00001 and not removed:
		var part: float = minf(remaining,0.05); remaining -= part
		_move_step(part)
	if removed: return
	pickup_timer += delta
	if pickup_timer >= 0.25:
		pickup_timer = 0
		if service.riding != self and not is_instance_valid(passenger):
			for mob in game.creatures.get_children():
				if Boats.can_ride(mob) and mob.position.distance_to(position) < 1.3: attach_mob(mob); break
	seat_occupants()
	animation += delta*6*signf(-control.z)
	for i in paddles.size():
		paddles[i].rotation.y = sin(animation)*0.5 if control.length_squared() > 0 else 0

func _move_step(delta: float) -> void:
	var floor_pos: Vector3 = position-Vector3.UP*0.3
	var floor_id: int = game.world.node_at(Vector3i(floor_pos.floor()))
	if Fire.is_fire(floor_id) or Fluids.lava(floor_id) or Fire.is_fire(game.world.node_at(Vector3i(position.floor()))): service.destroy(self); return
	if position.y < game.world.generator.min_y()-5: service.destroy(self); return
	var water: bool = Fluids.contains(game.world,floor_pos,Nodes.WATER)
	var submerged: bool = Fluids.contains(game.world,position+Vector3.UP*0.65,Nodes.WATER)
	var ice: bool = DenseMaterials.is_ice(floor_id) and not submerged
	var factor: float = 0.75 if submerged else (1.0 if water or ice else 0.5)
	var friction: float = 0.05 if submerged else (0.02 if water or ice else 0.04)
	if absf(control.z) > 0.01: speed += -signf(control.z)*2.0*factor*delta
	if absf(control.x) > 0.01:
		rotation.y -= signf(control.x)*0.63*factor*delta*(-1 if speed < 0 else 1)
	if not ice and not water and not submerged and absf(speed) > 2: friction = minf(absf(speed)-2,friction*5)
	elif not ice and submerged and absf(speed) > 1.5: friction = minf(absf(speed)-1.5,friction*5)
	speed = move_toward(speed,0,friction*20*delta)
	if submerged and water: vertical = maxf(-0.2,vertical-0.2*delta)
	elif water and vertical < 1:
		var cell := Vector3i(floor_pos.floor())
		var surface: float = cell.y+(Fluids.height(floor_id) if Fluids.water(floor_id) else 1.0)
		var afloat := Vector3(position.x,surface-0.15,position.z)
		if not blocked(afloat): position.y = afloat.y
		vertical = 0
	else: vertical = maxf(-8,vertical-9.8*delta)
	var motion: Vector3 = -basis.z*speed
	var terminal: float = 57.1 if ice else 8.0
	motion.x = clampf(motion.x,-terminal,terminal); motion.z = clampf(motion.z,-terminal,terminal); motion.y = vertical
	speed = Vector2(motion.x,motion.z).length()*signf(speed)
	var steps: int = maxi(1,ceili((motion*delta).length()/0.15))
	var part: Vector3 = motion*delta/steps
	for i in steps:
		for axis in [0,2,1]:
			if absf(part[axis]) < 0.000001: continue
			var next: Vector3 = position; next[axis] += part[axis]
			if not game.world.loaded_at(next): speed = 0; vertical = 0; part = Vector3.ZERO; break
			clear_lily_pads(next)
			if not blocked(next): position = next; continue
			var low: float = 0; var high: float = 1
			for iteration in 8:
				var mid: float = (low+high)*0.5
				var probe: Vector3 = position; probe[axis] += part[axis]*mid
				if blocked(probe): high = mid
				else: low = mid
			position[axis] += part[axis]*low
			if axis == 1: vertical = 0
			else: speed = 0
			part[axis] = 0

func blocked(pos: Vector3) -> bool:
	if game.world.intersects(pos,0.5,0.55): return true
	var box := AABB(pos+Vector3(-0.5,0,-0.5),Vector3(1,0.55,1))
	for other in service.active.values():
		if other == self or not is_instance_valid(other) or other.removed or other.is_queued_for_deletion(): continue
		if pos.distance_squared_to(other.position) > 3: continue
		if box.intersects(AABB(other.position+Vector3(-0.5,0,-0.5),Vector3(1,0.55,1))): return true
	return false

func clear_lily_pads(pos: Vector3) -> void:
	for x in range(floori(pos.x-0.5),floori(pos.x+0.5)+1):
		for z in range(floori(pos.z-0.5),floori(pos.z+0.5)+1):
			for y in range(floori(pos.y),floori(pos.y+0.55)+1):
				var p := Vector3i(x,y,z)
				if game.world.node_at(p) == VillageContent.LILY_PAD and game.world.set_node(p,Nodes.AIR): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,VillageContent.LILY_PAD)

func attach_mob(mob: Creature) -> bool:
	if is_instance_valid(passenger) or mob == null or Boats.is_passenger(mob): return false
	if Boats.is_chest(item_id) and service.riding == self: return false
	passenger = mob; passenger_processing = mob.is_physics_processing()
	mob.set_meta("boat_key",key); mob.set_physics_process(false); mob.velocity = Vector3.ZERO; mob.knock = Vector3.ZERO
	seat_occupants(); store_record()
	return true

func release_mob(move_mob: bool = true) -> void:
	if is_instance_valid(passenger) and not passenger.is_queued_for_deletion():
		passenger.remove_meta("boat_key")
		if move_mob: passenger.position = service.exit_position(self,passenger.width,passenger.height)
		passenger.velocity = Vector3.ZERO; passenger.set_physics_process(passenger_processing)
		Farming.remember(passenger)
		if passenger is VillageMob: passenger.game.villages.relocate(passenger); passenger.store_record()
		if passenger is NetherResident or passenger is SnowGolem: passenger.store_record()
	passenger = null; saved.erase("passenger")

func seat_occupants() -> void:
	if service.riding == self:
		game.player.position = position+basis*Vector3(0,0.15,-0.1)
		game.player.velocity = Vector3.ZERO; game.player.grounded = false
	if is_instance_valid(passenger) and not passenger.is_queued_for_deletion():
		passenger.position = position+basis*Vector3(0,0.15,0.45 if service.riding == self else -0.1)
		if is_instance_valid(passenger.model): passenger.model.rotation.y = rotation.y

func store_record() -> void:
	if removed: return
	saved["position"] = [position.x,position.y,position.z]; saved["yaw"] = rotation.y
	saved["speed"] = speed; saved["vertical"] = vertical; saved["health"] = health; saved["rider"] = service.riding == self
	if is_instance_valid(passenger) and not passenger.is_queued_for_deletion() and passenger.health > 0:
		Farming.remember(passenger)
		if passenger is VillageMob or passenger is SnowGolem: passenger.store_record()
		saved["passenger"] = game.leads.record({"mob":passenger})
		if Farming.managed(passenger): saved.passenger["farm_state"] = Farming.state(passenger)
	else: saved.erase("passenger")

func hit(damage: float, player_broke: bool = false) -> void:
	if removed or damage <= 0: return
	health -= damage; regeneration = 0
	if health <= 0: service.destroy(self,player_broke)
