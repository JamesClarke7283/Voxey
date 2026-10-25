extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 20: push_error(message)
func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not equivalent(a[k],b[k]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b
func mapped(source: Dictionary, id: int) -> bool:
	var name: String = source.name
	var colors: Array = ["white","grey","silver","black","yellow","orange","red","magenta","purple","blue","cyan","lime","green","pink","light_blue","brown"]
	if id >= 635 and id < 651: return name == "mcl_banners:banner_item_"+str(colors[id-635])
	if id >= 821 and id < 837: return name == "mcl_dyes:"+str(colors[id-821])
	if id >= 842 and id <= 854:
		var arrows: Array = ["healing","harming","night_vision","swiftness","slowness","leaping","poison","regeneration","strength","weakness","invisibility","water_breathing","fire_resistance"]
		return name == "mcl_potions:"+str(arrows[id-842])+"_arrow"
	var special: Dictionary = {263:"mcl_books:writable_book",531:"mcl_campfires:campfire_lit",775:"mcl_farming:sweet_berry",777:"mcl_potions:speckled_melon",786:"mcl_fishing:clownfish_raw",787:"mcl_fishing:pufferfish_raw",792:"mcl_mobitems:ink_sac",805:"mcl_mobitems:rabbit_foot",809:"mcl_experience:bottle",1386:"mcl_banners:pattern_globe"}
	if special.has(id): return name == special[id]
	if name.ends_with("_enchanted"): name = name.trim_suffix("_enchanted")
	if name == "mcl_enchanting:book": name = "mcl_books:book"
	if name.begins_with("mcl_candles:"):
		var color: String = str(source.metadata.get("palette_index","")) if source.get("metadata") is Dictionary else ""
		return id == (547 if color == "14" else 548)
	var expected: int = Harvesting.item_id(name)
	if id == VillageContent.ENCHANTED_BOOK: return name in ["mcl_books:book","mcl_enchanting:book_enchanted"]
	return expected == id or ToolCapabilities.node_name(id) == name
func person() -> Dictionary:
	return {"trade_version":1,"trade_rng":1,"future_offers":[],"levelup_in":0.0,"level":1,"xp":0,"profession":"farmer","offers":[]}
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/villager_trading_reference.json"))
	check(data.price_refresh.result and int(data.price_refresh.count) == 1 and int(data.price_refresh.numeric_length) == 0,"source object-keyed trading tables must reapply prices when refreshed")
	var catalog_count: int = 0
	for profession in data.catalog:
		var rows: Array = data.catalog[profession]; var native: Array = VillageTrades.DATA[profession]
		check(rows.size() == native.size(),"Catalog size differs: "+profession)
		for i in mini(rows.size(),native.size()):
			var a: Dictionary = native[i]; var b: Dictionary = rows[i]; catalog_count += 1
			var ok: bool = int(a.tier) == int(b.tier) and int(a.stock) == int(b.stock) and int(a.xp) == int(b.xp) and is_equal_approx(a.multiplier,b.multiplier) and a.cost.size() == b.costs.size()
			for j in mini(a.cost.size(),b.costs.size()):
				ok = ok and mapped(b.costs[j].item,int(a.cost[j][0])) and int(a.cost[j][1]) == int(b.costs[j].low) and int(a.cost[j][2]) == int(b.costs[j].high)
			ok = ok and mapped(b.give.item,int(a.give[0])) and int(a.give[1]) == int(b.give.low) and int(a.give[2]) == int(b.give.high)
			check(ok,"Catalog row differs %s/%d: %s => %s"%[profession,i,str(a),str(b)])
	for row in data.generated:
		var rng := EnchantRolls.new(int(row.seed)); var actual: Dictionary = VillagerTrading.generate(VillageTrades.DATA[row.profession][int(row.index)],rng)
		var target: Dictionary = row.after; var ok: bool = actual.uses == int(target.uses) and actual.stock == int(target.stock) and actual.xp == int(target.xp) and is_equal_approx(actual.multiplier,target.multiplier) and actual.reward_xp == target.reward
		for i in actual.cost.size(): ok = ok and actual.cost[i][1] == int(target.costs[i].count)
		ok = ok and actual.give[1] == int(target.give.count) and equivalent(actual.data.get("enchantments",{}),target.give.enchantments if target.give.enchantments is Dictionary else {}) and rng.state == int(row.state)
		check(ok,"Generation differs %s/%d seed %d: %s => %s state %d/%d"%[row.profession,int(row.index),int(row.seed),str(actual),str(target),rng.state,int(row.state)])
	for row in data.restock:
		var p: Dictionary = person(); p.restock_day = int(row.last_day); p.restock_time = row.last_time; p.restocks = int(row.remaining)
		p.offers = [{"uses":int(row.used),"demand":2,"stock":16},{"uses":0,"demand":-1,"stock":4}]
		VillagerTrading.restock(p,row.clock,int(row.day)); var e: Dictionary = row.after
		check(p.restock_day == int(e.day) and p.restock_time == e.time and p.restocks == int(e.remaining) and p.offers[0].uses == int(e.uses[0]) and p.offers[1].uses == int(e.uses[1]) and p.offers[0].demand == int(e.demands[0]) and p.offers[1].demand == int(e.demands[1]),"Restock differs: "+str(row)+" actual="+str(p))
	for row in data.progress:
		var p: Dictionary = person(); p.level = int(row.tier); p.xp = int(row.xp)
		var scheduled: bool = VillagerTrading.transaction(p,int(row.gain)); var pending: float = p.levelup_in
		var advanced: bool = VillagerTrading.advance(p,row.dt); var e: Dictionary = row.after
		check(p.level == int(e.tier) and p.xp == int(e.xp) and is_equal_approx(p.levelup_in,e.timer) and pending == e.pending and int(scheduled)*5 == int(e.bonus) and int(advanced) == int(e.regenerations),"Promotion differs: "+str(row))
	for row in data.activation:
		var p: Dictionary = person(); p.profession = row.profession; p.level = int(row.tier)
		for tier in range(1,p.level+1): VillagerTrading.activate(p,tier)
		check(p.offers.size() == int(row.before),"Initial tier count differs")
		if p.level < 5: p.level += 1; VillagerTrading.activate(p,p.level)
		check(p.offers.size() == int(row.after),"Activated tier count differs")
	print("VILLAGER TRADING SOURCE: %d catalog, %d generated, %d restock, %d progression, %d activation cases; %d failures"%[catalog_count,data.generated.size(),data.restock.size(),data.progress.size(),data.activation.size(),failures])
	quit(1 if failures else 0)
