extends SceneTree
var failed: int = 0
var labels: Dictionary

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		if failed <= 14: push_error(message)

func item(raw: Dictionary) -> Dictionary:
	var id: int = int(raw.get("id",0))
	if id == 0: return MobWeapons.empty_item()
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
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_weapon_reference.json")); labels = source.labels
	for row in source.generated:
		var rng := EnchantRolls.new(int(row.seed)); var result: Dictionary = MobWeapons.generate(row.factor,int(row.difficulty),rng)
		check(same(result,row.item),"Generated weapon differs: "+str(row)+" got="+str(result))
		check(rng.state == int(row.state),"Weapon generation random stream differs: "+str(row))
	for row in source.preferences:
		check(MobWeapons.better(item(row.new),item(row.old),row.kind == "drowned") == row.value,"Weapon preference differs: "+str(row))
	for row in source.caps:
		var result: Dictionary = MobWeapons.caps(item(row.item),row.base)
		check(is_equal_approx(result.interval,row.interval),"Weapon interval differs: "+str(row)+" got="+str(result))
		for key in row.groups: check(is_equal_approx(float(result.groups.get(key,0)),float(row.groups[key])),"Weapon damage differs: "+str(row)+" got="+str(result))
		for key in result.groups: check(is_zero_approx(float(result.groups[key])) or row.groups.has(key),"Extra weapon damage group: "+str(row)+" got="+str(result))
	for row in source.drops:
		var result: Dictionary = MobWeapons.dropped(item(row.item),row.probability,int(row.looting),EnchantRolls.new(33),row.sample)
		var empty: bool = not row.result is Dictionary or int(row.result.get("id",0)) == 0
		check(result.is_empty() if empty else not result.is_empty() and same(result,row.result),"Weapon drop differs: "+str(row)+" got="+str(result))
		check(row.cleared,"Source did not clear its dropped weapon")
	for row in source.modes: check(MobWeapons.attack_mode(row.kind,int(row.id)) == row.mode,"Weapon attack mode differs: "+str(row))
	for row in source.player_scale: check(is_equal_approx(MobWeapons.player_scale(row.amount,int(row.difficulty)),row.result),"Player difficulty scaling differs: "+str(row))
	print("MOB WEAPON SOURCE: %d generated, %d preferences, %d capabilities, %d drops, %d attack modes, %d difficulty cases; %d failures"%[source.generated.size(),source.preferences.size(),source.caps.size(),source.drops.size(),source.modes.size(),source.player_scale.size(),failed])
	quit(1 if failed else 0)
