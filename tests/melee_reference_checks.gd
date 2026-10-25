extends SceneTree

var failures: int = 0
var names: Dictionary = {}

func _init() -> void: call_deferred("run")

func vector(raw: Array) -> Vector3: return Vector3(raw[0],raw[1],raw[2])

func run() -> void:
	for name in Enchanting.source.definitions: names[Enchanting.source.definitions[name].source_key] = name
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/melee_reference.json"))
	var matched: int = 0
	for row in reference.cases:
		var c: Dictionary = row.case
		var enchants: Dictionary = {}
		if c.enchantments is Dictionary:
			for key in c.enchantments: enchants[names.get(key,key)] = int(c.enchantments[key])
		var slot: Dictionary = {"id":int(c.id),"count":1 if c.id else 0,"wear":0,"data":{"enchantments":enchants}}
		Durability.set_normalized(slot,int(c.wear))
		var state: Dictionary = c.duplicate(true)
		for key in ["velocity","target_velocity","direction"]: state[key] = vector(c[key])
		var rng := EnchantRolls.new(int(c.seed))
		var result: Dictionary = MeleeCombat.resolve(slot,c.armor,state,rng)
		var actual_wear: int = Durability.normalized(slot) if slot.id else -1
		var ok: bool = is_equal_approx(result.damage,float(row.damage)) and is_equal_approx(float(result.burning),float(row.burning)) and is_equal_approx(float(result.slowness),float(row.slowness)) and actual_wear == int(row.wear) and int(row.state) == rng.state and int(row.swings) == int(result.accepted) and result.player_velocity.is_equal_approx(vector(row.player_velocity)) and result.target_velocity.is_equal_approx(vector(row.target_velocity)) and int(row.mace_stamp) == result.mace_stamp and int(row.looting) == int(result.get("looting",0))
		if ok: matched += 1
		elif failures < 5:
			failures += 1; push_error("Melee mismatch: "+str(row)+" actual="+str(result)+" wear="+str(actual_wear)+" state="+str(rng.state))
	print("MELEE SOURCE CASES: ",matched," / ",reference.cases.size()," matched")
	quit(0 if matched == reference.cases.size() else 1)
