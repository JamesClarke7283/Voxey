extends SceneTree
var failures: int = 0
var steps: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 8: push_error(message)
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_crossbow_reference.json"))
	for sequence in source.sequences:
		var state: Dictionary = MobCrossbows.initial(sequence.loaded)
		for row in sequence.rows:
			var events: Array = MobCrossbows.tick(state,sequence.dt,row.sight,row.distance,null,int(sequence.roll))
			check(int(state.phase) == int(row.state) and state.loaded == row.loaded,"Crossbow phase differs: "+str(sequence.scenario)+" "+str(row))
			check(is_equal_approx(state.visible,row.visible) and is_equal_approx(state.repath,row.repath) and is_equal_approx(state.delay,row.delay) and is_equal_approx(state.using,row.using),"Crossbow timing differs: "+str(state)+" expected="+str(row))
			var expected: Array = row.events if row.events is Array else []
			check(events.size() == expected.size(),"Navigation/shoot event count differs")
			for i in mini(events.size(),expected.size()):
				check(events[i][0] == expected[i][0] and (events[i].size() == 1 or is_equal_approx(events[i][1],expected[i][1])),"Navigation/shoot event differs")
			steps += 1
	for row in source.shots:
		var weapon: Dictionary = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"enchantments":{"Multishot":int(row.multishot),"Piercing":int(row.piercing)}}}
		var origin := Vector3(0,1.475,0)
		var target := Vector3(row.target[0],row.target[1],row.target[2])
		var dirs: Array = CrossbowUse.directions(weapon,MobCrossbows.aim(origin,target),row.yaw,source.samples,14-int(row.difficulty)*4)
		check(dirs.size() == row.shots.size(),"Pillager multishot count differs")
		for i in dirs.size():
			var shot: Dictionary = row.shots[i]
			check((dirs[i]*MobCrossbows.SHOT_SPEED).is_equal_approx(Vector3(shot.velocity[0],shot.velocity[1],shot.velocity[2])) and origin.is_equal_approx(Vector3(shot.position[0],shot.position[1],shot.position[2])),"Pillager aiming differs: "+str(row))
			check(shot.critical and not shot.collectable and shot.damage == 2 and int(shot.piercing) == int(row.piercing),"Source projectile flags differ")
	for row in source.wear:
		var weapon: Dictionary = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"enchantments":{"Unbreaking":int(row.level)}}}
		check(Durability.uses(weapon) == row.uses and MobCrossbows.drop_wear(weapon,int(row.roll),int(row.roll)) == int(row.wear),"Dropped crossbow durability differs: "+str(row))
	print("MOB CROSSBOW SOURCE: %d AI steps, %d firing cases, %d drop wear cases; %d failures"%[steps,source.shots.size(),source.wear.size(),failures])
	quit(1 if failures else 0)
