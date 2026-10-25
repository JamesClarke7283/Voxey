extends SceneTree
var failed: int = 0
var labels: Dictionary

class Fixed extends EnchantRolls:
	var values: Array
	var cursor: int = 0
	func _init(input: Array) -> void: values = input
	func unit() -> float:
		var value: float = values[cursor]; cursor += 1; return value
	func integer(_low: int, _high: int) -> int:
		var value: int = int(values[cursor]); cursor += 1; return value

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		if failed <= 12: push_error(message)

func item(raw: Dictionary) -> Dictionary:
	var id: int = int(raw.get("id",0))
	if id == 0: return {"id":0,"count":0,"wear":0}
	var enchanted: Dictionary = {}
	if raw.get("enchantments") is Dictionary:
		for key in raw.enchantments: enchanted[labels.get(key,key)] = raw.enchantments[key]
	var value: Dictionary = {"id":id,"count":1,"wear":0,"data":{"enchantments":enchanted}}
	Durability.set_normalized(value,int(raw.get("wear",0)))
	return value

func same(a: Dictionary, raw: Dictionary) -> bool:
	var expected: Dictionary = item(raw)
	if int(a.id) != int(expected.id): return false
	if a.id == 0: return true
	return Durability.normalized(a) == Durability.normalized(expected) and a.get("data",{}).get("enchantments",{}) == expected.get("data",{}).get("enchantments",{})

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_armor_reference.json")); labels = source.labels
	for row in source.generated:
		var rng := EnchantRolls.new(int(row.seed)); var result: Dictionary = MobArmor.generate(row.factor,int(row.difficulty),rng)
		for index in 4: check(same(result.slots[index],row.slots[index]),"Generated armor differs seed="+str(row.seed)+" factor="+str(row.factor)+" expected="+str(row.slots)+" got="+str(result.slots))
		check(rng.state == int(row.state),"Armor generation random stream differs")
	for row in source.fixed:
		var rng := Fixed.new(row.rolls); var result: Dictionary = MobArmor.generate(1,int(row.difficulty),rng)
		for index in 4: check(same(result.slots[index],row.slots[index]),"Fixed material/stop boundary differs")
		check(rng.cursor == row.used,"Fixed armor draw count differs")
	for row in source.better: check(MobArmor.better(item(row.new),item(row.old)) == row.value,"Armor preference differs: "+str(row))
	for row in source.drops:
		var result: Dictionary = MobArmor.dropped(item(row.item),row.probability,int(row.looting),EnchantRolls.new(33),row.sample)
		var no_item: bool = not row.result is Dictionary or int(row.result.get("id",0)) == 0
		check(result.is_empty() if no_item else not result.is_empty() and same(result,row.result),"Armor drop/wear differs: "+str(row))
	for row in source.damage:
		var slots: Array = MobArmor.empty_slots()
		if row.input is Array:
			for index in row.input.size(): slots[index] = item(row.input[index])
		var result: Dictionary = ArmorEffects.resolve(slots,row.amount,row.flags if row.flags is Dictionary else {},"fire" if row.reason == "on_fire" else row.reason,true,EnchantRolls.new(int(row.seed)),source.order)
		check(is_equal_approx(result.damage,row.damage) and result.reflected == row.reflected,"Mob armor damage/Thorns differs: "+str(row))
		for index in 4: check(same(slots[index],row.slots[index]),"Mob armor hit wear differs")
	for row in source.sunlight:
		var slots: Array = MobArmor.empty_slots(); slots[0] = item({"id":row.id,"wear":row.wear})
		var ignited: bool = MobArmor.sunlight_wear(slots,row.gate == 1,row.wear_gate == 1)
		check(ignited == (row.ignited > 0) and same(slots[0],row.head),"Sunlight armor wear differs")
	var carved: Dictionary = Inventory.clean_slot({"id":FruitCrops.CARVED,"count":1,"wear":0,"data":{"enchantments":{"Curse of Binding":1,"Curse of Vanishing":1}}})
	check(Inventory.enchantment(carved,"Curse of Binding") == 1 and Inventory.enchantment(carved,"Curse of Vanishing") == 1,"Noncombat head armor must retain its supported curses")
	print("MOB ARMOR SOURCE: %d generated, %d boundary, %d preferences, %d drops, %d damage, %d sunlight cases; %d failures"%[source.generated.size(),source.fixed.size(),source.better.size(),source.drops.size(),source.damage.size(),source.sunlight.size(),failed])
	quit(1 if failed else 0)
