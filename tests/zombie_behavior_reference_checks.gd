extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 12: push_error(message)
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/zombie_behavior_reference.json"))
	for row in data.traits:
		var rng := EnchantRolls.new(int(row.seed)); var value: Dictionary = ZombieTraits.generate(row.factor,rng)
		for key in ["knockback","view","reinforcement","health_bonus"]: check(is_equal_approx(float(value[key]),float(row[key])),"Zombie trait differs "+key+": "+str(row)+" got="+str(value))
		check(value.break_doors == row.break_doors and is_equal_approx(row.hp_max,20+20*value.health_bonus) and row.health == 20,"Zombie leader health/door eligibility differs")
		check(rng.state == int(row.state),"Zombie attribute RNG differs")
	for row in data.doors:
		var pos := Vector3(row.x,row.y,0); var velocity := Vector3(row.velocity[0],row.velocity[1],row.velocity[2])
		var valid: bool = ZombieDoors.valid(pos,Vector3.ZERO,velocity,row.kind == "wood")
		var state: Dictionary = ZombieDoors.initial(); state.time = row.time; state.stage = floori(row.time/12*10)
		var result: Dictionary = ZombieDoors.tick(state,0.1,row.protected,20) if valid else {"break":false}
		check(valid and result["break"] == (row.dug > 0) or not valid and row.dug == 0,"Door removal differs: "+str(row))
		check((valid and not result["break"]) == row.active,"Door cancellation differs: "+str(row))
		if row.active: check(is_equal_approx(state.time,row.elapsed) and state.stage == int(row.stage),"Door progress differs")
	for row in data.reinforcements:
		var allowed: bool = ZombieTraits.reinforcement_gate(int(row.difficulty),row.accept,true,row.chance,row.sample)
		var attempts: Array = row.attempts if row.attempts is Array else []
		check(attempts.size() == (50 if allowed else 0),"Reinforcement gate differs")
		var rng := EnchantRolls.new(17); var chance: float = row.chance; var children: int = 0
		for i in attempts.size():
			var pos: Vector3i = ZombieTraits.offset(rng); var source: Array = attempts[i]
			check(pos == Vector3i(int(source[0]),int(source[1]),int(source[2])),"Reinforcement position differs")
			if row.pattern == "all" or row.pattern == "alternate" and i%2 == 0:
				chance = ZombieTraits.attenuate(chance); children += 1
		check(is_equal_approx(chance,row.caller) and children == (row.children.size() if row.children is Array else 0),"Reinforcement count/attenuation differs")
		if row.children is Array:
			for value in row.children: check(is_equal_approx(value,0.05),"Callee chance attenuation differs")
		check(rng.state == int(row.state),"Reinforcement random stream differs")
	print("ZOMBIE SOURCE: %d traits, %d door states, %d reinforcement cases; %d failures"%[data.traits.size(),data.doors.size(),data.reinforcements.size(),failures])
	quit(1 if failures else 0)
