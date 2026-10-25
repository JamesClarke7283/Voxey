extends SceneTree
var failures: int = 0
var steps: int = 0

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 10: push_error(message)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_bow_reference.json"))
	for kind in source.registered:
		var registered: Dictionary = source.registered[kind]
		check(Creature.KINDS[kind].can_despawn == registered.despawn and Creature.KINDS[kind].height == registered.collisionbox[4] and Creature.KINDS[kind].width == registered.collisionbox[3],"Skeleton registered bounds/despawning differ")
		check(MobBows.RANGE == registered.range and MobBows.RANGE == registered.tracking and registered.shoot_offset == 1.5,"Skeleton registered attack range differs")
	for sequence in source.sequences:
		var state: Dictionary = MobBows.initial()
		for row in sequence.rows:
			var events: Array = MobBows.tick(state,sequence.dt,row.sight,row.distance,int(sequence.difficulty),null,sequence.unit,int(sequence.roll))
			for key in ["visible","strafe","x","z","cooldown","using","path_timer"]:
				check(is_equal_approx(float(state[key]),float(row[key])),"Bow AI "+str(sequence.scenario)+" step "+str(steps)+" "+key+" expected "+str(row[key])+" got "+str(state[key]))
			check(state.path_set == row.path_set and state.mode == row.mode,"Bow movement state differs: "+str(state)+" expected "+str(row))
			var expected: Array = row.events if row.events is Array else []
			check(events.size() == expected.size(),"Bow event count differs: "+str(events)+" expected "+str(expected))
			for i in mini(events.size(),expected.size()):
				check(events[i][0] == expected[i][0] and (events[i].size() == 1 or is_equal_approx(events[i][1],expected[i][1])),"Bow event differs")
			steps += 1
	for row in source.shots:
		var ench: Dictionary = {} if row.power == 0 else {"Power":int(row.power),"Punch":2,"Flame":1}
		var item: Dictionary = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":ench}}
		var origin := Vector3(0,1.5,0)
		var expected: Dictionary = MobBows.projectile(item,origin,Vector3(row.target[0],row.target[1],row.target[2]),row.target[3],int(row.difficulty),source.samples)
		check(origin.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])) and expected.velocity.is_equal_approx(Vector3(row.velocity[0],row.velocity[1],row.velocity[2])),"Skeleton arrow origin/velocity differs: "+str(row))
		check(is_equal_approx(expected.damage,row.damage) and expected.punch == row.punch and expected.flame == row.flame and not row.critical and not row.collectable,"Skeleton arrow properties differ")
		check(row.name == ("mcl_potions:slowness_arrow_entity" if row.kind == "stray" else "mcl_bows:arrow_entity"),"Stray arrow type differs")
	for row in source.kills:
		check(MobBows.qualifies_for_sniper(row.kind,row.reason,row.player,row.distance) == row.awarded,"Skeleton projectile-kill achievement differs: "+str(row))
	for row in source.wear:
		var item: Dictionary = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Unbreaking":int(row.level)}}}
		check(Durability.uses(item) == row.uses and MobCrossbows.drop_wear(item,int(row.roll),int(row.roll)) == int(row.wear),"Dropped bow wear differs")
	print("MOB BOW SOURCE: %d AI steps, %d firing cases, %d kill cases, %d wear cases; %d failures"%[steps,source.shots.size(),source.kills.size(),source.wear.size(),failures])
	quit(1 if failures else 0)
