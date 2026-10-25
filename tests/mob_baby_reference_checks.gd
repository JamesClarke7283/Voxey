extends SceneTree
var failed: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		if failed <= 12: push_error(message)
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_baby_reference.json"))
	for key in ["baby_zombie","baby_husk","baby_drowned"]:
		var source: Dictionary = data.registered[key]
		var mob := Creature.new(); mob.kind = MobBabies.base(key); mob.set_meta("undead_baby",true)
		var info: Dictionary = mob.info()
		check(info.width == source.box[3] and info.height == source.box[4] and info.reach == source.reach and info.xp == source.xp,"Baby dimensions, reach or reward differ: "+key)
		check(is_equal_approx(info.speed/Creature.KINDS[mob.kind].speed,1.5),"Baby speed bonus differs")
		mob.free()
	for row in data.spawns:
		var native: String = "baby_zombie" if row.kind == "zombie" and row.forced else MobBabies.natural(row.kind,row.roll)
		check("mobs_mc:"+native == row.result,"Baby spawn boundary differs: "+str(row))
	for row in data.jockey:
		check(MobJockeys.decision(true,false,int(row.first),int(row.second),row.found) == row.result,"Jockey decision differs: "+str(row))
		check(int(row.used) == (1 if row.first <= 5 else 2),"Source jockey random consumption changed")
	for row in data.chickens:
		var result: Dictionary = MobJockeys.chicken_step(row.timer,0.1,row.child,row.jockey)
		check(result.lay == (row.eggs > 0) and is_equal_approx(result.timer,row.remaining) and result.xp == row.xp,"Jockey chicken egg or XP behavior differs")
	for row in data.aging: check(row.result == row.age and not row.grew,"Source integer child flag unexpectedly grows into an adult")
	for row in data.infections:
		var kind: String = "zombie_villager" if row.kind == "villager_zombie" else MobBabies.base(row.kind)
		var result: bool = kind in ZombieVillagers.INFECTING_KINDS and ZombieVillagers.infection_allowed(int(row.difficulty)-1,int(row.coin))
		check(result == row.result,"Source infection family or difficulty gate differs: "+str(row))
	print("MOB BABY SOURCE: 3 baby definitions, %d spawns, %d jockey rolls, %d chicken cases, %d aging cases, %d infections; %d failures"%[data.spawns.size(),data.jockey.size(),data.chickens.size(),data.aging.size(),data.infections.size(),failed])
	quit(1 if failed else 0)
