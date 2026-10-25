extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 15: push_error(message)
func same(items: Array, source: Array) -> bool:
	for i in items.size():
		if int(items[i].get("id",0)) != int(source[i].id) or int(items[i].get("count",0)) != int(source[i].count): return false
	return true
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/villager_social_reference.json"))
	for row in data.food:
		var person: Dictionary = {"inventory":VillagerInventory.clean(row.items),"food_level":int(row.level),"age":0}
		var points: int = VillagerFood.points(person.inventory)
		check(points == int(row.points) and VillagerFood.possible(person) == row.possible and (points > 24) == row.surplus and (points < 12) == row.needs,"Food thresholds differ: "+str(row))
		VillagerFood.eat(person)
		check(person.food_level == int(row.fed) and same(person.inventory,row.after),"Food consumption differs: "+str(row))
		VillagerFood.digest(person); check(person.food_level == int(row.digested),"Conception food cost differs")
	for row in data.sharing:
		var a: Dictionary = {"profession":row.sender,"inventory":VillagerInventory.clean(row.items)}
		var b: Dictionary = {"profession":row.receiver,"inventory":VillagerInventory.clean(row.target_items)}
		var result: Array = VillagerFood.shared_stacks(a,b)
		check(same(a.inventory,row.after) and result.size() == (row.thrown.size() if row.thrown is Array else 0),"Shared stack choice/count differs")
		for i in result.size(): check(result[i].id == int(row.thrown[i].id) and result[i].count == int(row.thrown[i].count),"Shared output differs")
		check(row.extra_count == 0,"The installed source now supports extra-item trading; revisit its array lookup")
	for row in data.reclaim:
		check(VillagerFood.may_reclaim(row.same,row.has_time,10,row.now) == row.picked,"Self-pickup timeout differs: "+str(row))
	for row in data.courtship:
		var result: Dictionary = VillagerSocial.courtship(null if row.timer == -1 else row.timer,row.dt,row.reciprocal,row.distance,row.moving)
		check(result.active == row.result and result.active == row.active,"Courtship activity differs: "+str(row))
		check(is_equal_approx(-1 if result.timer == null else result.timer,row.after_timer),"Courtship timer differs")
		var a: Dictionary = {"inventory":VillagerInventory.clean([{"id":Nodes.BREAD,"count":4}]),"food_level":0}
		var b: Dictionary = a.duplicate(true)
		if result.finish: VillagerFood.eat(a); VillagerFood.eat(b); VillagerFood.digest(a); VillagerFood.digest(b)
		check(int(result.finish and row.bed) == int(row.births) and a.food_level == int(row.food) and b.food_level == int(row.mate_food) and same(a.inventory,row.after) and same(b.inventory,row.mate_after),"Courtship outcome/food cost differs")
	print("VILLAGER SOCIAL SOURCE: %d food, %d sharing, %d reclaim, %d courtship; %d failures"%[data.food.size(),data.sharing.size(),data.reclaim.size(),data.courtship.size(),failures])
	quit(1 if failures else 0)
