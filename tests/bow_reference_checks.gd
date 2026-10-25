extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		if failures < 10: push_error(description)
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bow_reference.json"))
	check(is_equal_approx(source.speed_factor,BowUse.SPEED_FACTOR),"Bow speed multiplier differs")
	for row in source.shots:
		var bow: Dictionary = {"id":Nodes.BOW,"count":1,"wear":0,"data":{"enchantments":{"Unbreaking":int(row.unbreaking),"Infinity":int(row.infinity),"Power":int(row.power),"Punch":2 if row.power > 0 else 0,"Flame":1 if row.power > 0 else 0}}}
		Durability.set_normalized(bow,int(row.before))
		var ammo: int = Nodes.ARROW_ITEM if row.ammo == "regular" else VillageContent.POISON_ARROW if row.ammo == "tipped" else 0
		var plan: Dictionary = BowUse.shot_plan(bow,ammo,row.creative,int(row.charge))
		check(plan.fires == row.fires,"Bow availability differs: "+str(row))
		var count: int = 0 if ammo == 0 else 3-(1 if plan.fires and plan.consume else 0)
		check(count == int(row.count),"Bow ammo consumption differs: "+str(row))
		if plan.fires:
			Durability.set_normalized(bow,Durability.normalized(bow)+int(plan.wear))
			var velocity: Vector3 = BowUse.inaccuracy(Vector3.FORWARD,source.samples)*float(plan.speed)
			check(velocity.is_equal_approx(Vector3(row.velocity[0],row.velocity[1],row.velocity[2])),"Bow trajectory differs: "+str(row))
			check(plan.critical == row.critical and plan.damage == row.damage and plan.punch == row.punch and plan.flame == row.flame and plan.collectable == row.collectable,"Bow properties differ: "+str(row))
		check(bow.count == int(row.bow_count) and Durability.normalized(bow) == int(row.wear),"Bow wear differs: "+str(row))
	print("BOW SOURCE: %d actual shots, %d failures" % [source.shots.size(),failures])
	quit(1 if failures else 0)
