extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 12: push_error(message)
func vector(value: Array) -> Vector3i:
	return Vector3i(int(value[0]),int(value[1]),int(value[2]))
func vectors(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for v in value: result.append(vector(v))
	return result
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/zombie_target_reference.json"))
	var state: Dictionary = {}
	for row in data.tracking:
		if row.step == 1: state = {}
		var active: bool = ZombieTargets.track(state,row.dt,false,row.distance,35,true,row.persist)
		check(active == row.active,"Unseen target boundary differs: "+str(row))
		if row.timer is float: check(is_equal_approx(state.unseen,row.timer),"Unseen target timer differs")
	for row in data.alerts:
		var active: bool
		if not row.current:
			state = {"alert_time":20.0}
			active = ZombieTargets.alert_candidate(row.distance,row.allowed)
		else:
			active = ZombieTargets.alert_track(state,0.5,true,row.distance,35,row.allowed)
		check(active == row.active,"Alert target boundary differs: "+str(row))
		if row.time is float: check(is_equal_approx(state.alert_time,row.time),"Alert approach timer differs")
	for row in data.retaliation:
		var reply: Dictionary = ZombieTargets.retaliation(row.distance,35,row.allowed,row.owner)
		check(reply.target == row.active and int(reply.broadcast) == int(row.sent),"Retaliation selection/broadcast differs: "+str(row))
	for row in data.detection:
		check(is_equal_approx(ZombieTargets.detection(row.invisible,int(row.pieces),row.head),row.value),"Invisibility/head detection differs")
	for row in data.heat:
		var centers: Array = []
		for p in row.sources: centers.append(VillagePois.section(vector(p)))
		check(VillagePois.heat_from_sections(vector(row.pos),centers) == int(row.value),"POI section propagation differs: "+str(row))
	for row in data.pacing:
		var rng := EnchantRolls.new(int(row.seed)); var samples: Array = []
		for i in 10: samples.append(Vector3i(rng.integer(-15,15),rng.integer(-7,7),rng.integer(-15,15)))
		var centers: Array = [Vector3i.ZERO] if row.heated else []
		var result: Variant = ZombieVillage.pick(Vector3i.ZERO,samples,centers,vectors(row.points),vectors(row.visited))
		check((result == null and row.result is bool) or (row.result is Array and result == vector(row.result)),"Unvisited POI choice differs: "+str(row))
		check(rng.state == int(row.state),"POI candidate random stream differs")
	print("ZOMBIE TARGET SOURCE: %d tracking, %d alerts, %d retaliation, %d detection, %d heat, %d pacing; %d failures"%[data.tracking.size(),data.alerts.size(),data.retaliation.size(),data.detection.size(),data.heat.size(),data.pacing.size(),failures])
	quit(1 if failures else 0)
