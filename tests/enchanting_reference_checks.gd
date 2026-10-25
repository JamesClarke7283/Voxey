extends SceneTree

var failed: int = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func _init() -> void: call_deferred("run")

func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enchanting_reference.json"))
	var matched: int = 0
	for fixture in reference.rolls:
		var rng := EnchantRolls.new(int(fixture.seed))
		var result: Dictionary = Enchanting.generate({"id":int(fixture.id),"count":1},fixture.power,rng,fixture.treasure,fixture.no_reduced_bonus)
		var expected: Dictionary = fixture.value if fixture.value is Dictionary else {}
		if equivalent(result,expected) and rng.state == int(fixture.state): matched += 1
		else: push_error("Roll mismatch: "+str(fixture)+" actual="+str(result)+" state="+str(rng.state))
	check(matched == reference.rolls.size(),"all %d single-item rolls match source enchantments, hint and RNG consumption (%d matched)"%[reference.rolls.size(),matched])
	matched = 0
	for fixture in reference.offers:
		var rng := EnchantRolls.new(int(fixture.seed))
		var result: Array = Enchanting.generate_offers({"id":int(fixture.id),"count":1},int(fixture.shelves),rng)
		var expected: Array = []
		for row in fixture.value: expected.append(row if row is Dictionary else {})
		for row in result: row.erase("glyphs")
		if equivalent(result,expected) and rng.state == int(fixture.state): matched += 1
		else: push_error("Offer mismatch: "+str(fixture)+" actual="+str(result)+" state="+str(rng.state))
	check(matched == reference.offers.size(),"all %d three-offer tables match source powers, blank slots and RNG consumption (%d matched)"%[reference.offers.size(),matched])
	check(Enchanting.source.definitions.size() == 39 and not Enchanting.source.definitions.has("Aqua Affinity") and not Enchanting.source.definitions.has("Sweeping Edge"),"table catalog contains exactly the 39 active source definitions")
	check(Enchanting.ability(Netherite.TOOLS) == 10 and Enchanting.ability(Netherite.ARMOR) == 10 and Enchanting.ability(1110) == 22,"netherite and gold use the source material enchantabilities")
	check(not Enchanting.fresh({"id":Nodes.SHEARS}) and not Enchanting.fresh({"id":VillageContent.SHIELD}) and not Enchanting.fresh({"id":Archaeology.BRUSH}),"anvil-only equipment cannot enter the enchanting table")
	var boot_choices: Array = Enchanting.candidates(107,{},false)
	check(not boot_choices.has("Depth Strider") and boot_choices.has("Feather Falling"),"secondary-only equipment enchantments are excluded from direct table offers")
	var mace_choices: Array = Enchanting.candidates(VillageContent.MACE,{},false)
	check(mace_choices.has("Density") and mace_choices.has("Breach") and mace_choices.has("Wind Burst"),"primary mace enchantments remain table eligible despite their treasure flags")
	check(not Enchanting.candidates(Nodes.BOOK,{},true).has("Soul Speed") and not Enchanting.candidates(Nodes.BOOK,{},true).has("Wind Burst"),"random treasure books exclude the two nontradable enchantments")
	check(Enchanting.candidates(Nodes.BOOK,{"Fortune":1},false).has("Silk Touch") and not Enchanting.candidates(95,{"Fortune":1},false).has("Silk Touch"),"books preserve the source exception allowing otherwise incompatible enchantments")
	var levels: Dictionary = {0:0,1:7,16:352,17:394,30:1395,31:1507,32:1628,40:2920}
	for level in levels:
		check(ExperienceCurve.total(level) == levels[level] and ExperienceCurve.level(levels[level]) == level,"experience curve round trips level "+str(level))
	check(ExperienceCurve.level(351) == 15 and ExperienceCurve.level(1506) == 30 and ExperienceCurve.level(1627) == 31,"experience boundaries remain below the next level until enough XP is earned")
	check(ExperienceCurve.spend(1451,3) == 1137 and is_equal_approx(ExperienceCurve.progress(1451),0.5),"spending levels preserves fractional bar progress using the source curve")
	var direct := EnchantRolls.new(1); var retried := EnchantRolls.new(1)
	var roll: Dictionary = {}; var attempts: int = 0
	while roll.is_empty() and attempts < 256:
		roll = Enchanting.generate({"id":95},1,direct,true,true); attempts += 1
	var reliable: Dictionary = Enchanting.generate_reliable({"id":95},1,retried,true,true)
	check(attempts > 1 and direct.state == retried.state and reliable == roll,"reliable loot retries empty rolls without changing the successful source result")
	var loot_matches: bool = true; var loot_cases: int = 0
	for pool_name in ["vault","ominous_vault"]:
		for pool in TrialLoot.tables()[pool_name]:
			for entry in pool.items:
				if not entry.has("enchant_power"): continue
				loot_cases += 1
				var rng := RandomNumberGenerator.new(); rng.seed = 1729
				var mirror := RandomNumberGenerator.new(); mirror.seed = 1729
				mirror.randi_range(entry.amount_min,entry.amount_max)
				var power: int = mirror.randi_range(entry.enchant_power[0],entry.enchant_power[1])
				var expected: Dictionary = Enchanting.generate_reliable({"id":TrialLoot.item_id(entry.item)},power,EnchantRolls.new(1,mirror),true,true)
				var reward: Dictionary = TrialLoot.stack(entry,rng)
				loot_matches = loot_matches and reward.get("data",{}).get("enchantments",{}) == expected.get("enchantments",{}) and rng.state == mirror.state
	check(loot_matches and loot_cases == 9,"all nine powered vault reward entries use the shared source engine and continuation flags")
	print("ENCHANTING REFERENCE TESTS: ",failed," failed")
	quit(1 if failed else 0)
