class_name Enchanting
extends RefCounted

# Active source definitions and the mcl_enchanting/engine.lua selection loop.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enchanting.json"))
const TOOL_MATERIALS = ["wood","stone","iron","diamond","netherite"]
const ARMOR_MATERIALS = ["leather","iron","gold","diamond","netherite"]
const ROMAN = ["","I","II","III","IV","V"]

static func item_profile(id: int, enchanted: bool = false) -> Dictionary:
	var pair: Dictionary = source.get("profiles",{}).get(str(id),{})
	return pair.get("enchanted" if enchanted else "base",{})

static func ability(id: int) -> int:
	var registered: Dictionary = item_profile(id)
	if not registered.is_empty(): return int(registered.ability)
	if source.get("profiles",{}).get(str(id),{}).has("missing"): return 0
	if MobArmor.copper(id): return 8
	if id in [Nodes.BOOK,VillageContent.ENCHANTED_BOOK,Nodes.BOW,VillageContent.CROSSBOW,VillageContent.FISHING_ROD,VillageContent.TRIDENT]: return 1
	if id == Nodes.ELYTRA or id == VillageContent.TURTLE_HELMET: return 9
	if id in [Nodes.SHEARS,VillageContent.SHIELD,Archaeology.BRUSH,Screwdriver.ID,Nodes.FLINT_AND_STEEL] or PigRiding.is_steering_item(id): return -1
	if id == VillageContent.MACE: return 10
	if id >= VillageContent.CHAIN_HELMET and id < VillageContent.CHAIN_HELMET+4: return int(source.materials.armor.chain)
	if Nodes.is_armor(id) and Nodes.durability(id) > 0:
		return int(source.materials.armor.get(ARMOR_MATERIALS[clampi(Nodes.armor_material(id),0,4)],0))
	if id >= 1110 and id < 1115: return int(source.materials.tool.gold)
	if Nodes.is_tool_id(id): return int(source.materials.tool.get(TOOL_MATERIALS[clampi(Nodes.tool_tier(id),0,4)],0))
	return int(Nodes.custom_items.get(id,{}).get("enchantability",0))

static func book(id: int) -> bool: return id in [Nodes.BOOK,VillageContent.ENCHANTED_BOOK]

static func fresh(slot: Dictionary) -> bool:
	return ability(int(slot.get("id",0))) > 0 and int(slot.get("id",0)) != VillageContent.ENCHANTED_BOOK and slot.get("data",{}).get("enchantments",{}).is_empty()

static func support(id: int, name: String, enchanted: bool = false) -> Vector2i:
	if ability(id) == 0 or not source.definitions.has(name): return Vector2i.ZERO
	var def: Dictionary = source.definitions[name]
	if book(id): return Vector2i(1,0 if def.treasure else 1)
	var registered: Dictionary = item_profile(id,enchanted)
	if def.requires_tool and not (registered.tool if not registered.is_empty() else Nodes.durability(id) > 0): return Vector2i.ZERO
	var tags: Array = registered.groups.keys() if not registered.is_empty() else Enchantments.tags(id)
	for tag in def.disallow:
		if tags.has(tag): return Vector2i.ZERO
	for tag in def.primary:
		if tags.has(tag): return Vector2i.ONE
	for tag in def.secondary:
		if tags.has(tag): return Vector2i(1,0)
	return Vector2i.ZERO

# Registered enchanted variants can retain different groups from their base item.
# Trade generation can supply an explicit variant; ordinary callers use exported item profiles.
static func candidates(id: int, current: Dictionary, treasure: bool, source_profile: Dictionary = {}) -> Array:
	var result: Array = []
	for name in source.order:
		var def: Dictionary = source.definitions[name]
		var supported: Vector2i = support(id,name,not current.is_empty())
		if not source_profile.is_empty(): supported = Vector2i(int(name in source_profile.primary or name in source_profile.secondary),int(name in source_profile.primary))
		if supported.x == 0 or current.has(name): continue
		if supported.y == 0 and not (treasure and def.treasure and def.tradable): continue
		if not book(id) and def.incompatible.any(func(other):return current.has(other)): continue
		result.append(name)
	return result

# The source validates the new enchantment against the current stack, with
# one-way incompatibility and an explicit level bound.
static func can_apply(id: int, name: String, level: int, current: Dictionary = {}, enchanted: bool = false) -> bool:
	if not source.definitions.has(name) or level < 1 or level > int(source.definitions[name].max_level): return false
	if current.has(name) or support(id,name,enchanted or not current.is_empty()).x == 0: return false
	return book(id) or not source.definitions[name].incompatible.any(func(other): return current.has(other))

static func choose(id: int, current: Dictionary, treasure: bool, rng: EnchantRolls, weighted: bool = true, source_profile: Dictionary = {}) -> String:
	var possible: Array = candidates(id,current,treasure,source_profile)
	var total: int = 0
	for name in possible: total += int(source.definitions[name].weight) if weighted else 1
	if total == 0: return ""
	var roll: int = rng.integer(1,total)
	for name in possible:
		roll -= int(source.definitions[name].weight) if weighted else 1
		if roll <= 0: return name
	return ""

static func description(name: String, level: int) -> String:
	return name+(" "+ROMAN[clampi(level,0,5)] if source.definitions[name].max_level > 1 else "")

static func generate(slot: Dictionary, power: float, rng: EnchantRolls, treasure: bool = false, no_reduced_bonus: bool = false, ignore_enchanted: bool = false, source_profile: Dictionary = {}) -> Dictionary:
	var id: int = int(slot.get("id",0))
	if ability(id) <= 0 or not ignore_enchanted and not fresh(slot): return {}
	var quarter: int = int(source_profile.get("ability",ability(id)))/4
	power += 1+rng.integer(0,quarter)+rng.integer(0,quarter)
	power += power*(rng.unit()+rng.unit()-1)*0.15
	var level: int = maxi(1,floori(power+0.5))*2
	var current: Dictionary = slot.get("data",{}).get("enchantments",{}).duplicate(true)
	var result: Dictionary = {"enchantments":{},"description":""}
	while level > 0:
		level /= 2
		if level == 0: break
		var name: String = choose(id,current,treasure,rng,true,source_profile)
		if name.is_empty(): break
		var def: Dictionary = source.definitions[name]
		var potency: int = 0
		for i in range(int(def.max_level)-1,-1,-1):
			if level >= def.power_range_table[i][0] and level <= def.power_range_table[i][1]: potency = i+1; break
		if result.description.is_empty():
			if potency == 0: return {}
			result.description = description(name,potency)
		if potency > 0:
			result.enchantments[name] = potency; current[name] = potency
		if not no_reduced_bonus and rng.unit() >= (level+1)/50.0: break
	if result.description.is_empty(): result.erase("description")
	return result

static func generate_reliable(slot: Dictionary, power: float, rng: EnchantRolls, treasure: bool = false, no_reduced_bonus: bool = false, source_profile: Dictionary = {}) -> Dictionary:
	if not fresh(slot) or candidates(int(slot.id),{},treasure,source_profile).is_empty(): return {}
	# Loot retries an empty first roll; table offers deliberately do not.
	for attempt in 256:
		var result: Dictionary = generate(slot,power,rng,treasure,no_reduced_bonus,false,source_profile)
		if not result.is_empty(): return result
	return {}

static func generate_offers(slot: Dictionary, shelves: int, rng: EnchantRolls) -> Array:
	if not fresh(slot): return [{},{},{}]
	shelves = clampi(shelves,0,15)
	var base: int = rng.integer(1,8)+shelves/2+rng.integer(0,shelves)
	var requirements: Array = [maxf(base/3.0,1.0),base*2.0/3.0+1.0,maxi(base,shelves*2)]
	var result: Array = []
	for i in 3:
		var offer: Dictionary = generate(slot,float(requirements[i]),rng)
		if not offer.is_empty():
			offer.level_requirement = maxi(i+1,floori(requirements[i]))
			offer.glyphs = []
			for glyph in 9: offer.glyphs.append(rng.integer(1,18))
		result.append(offer)
	return result

static func bookshelf_power(world: VoxelWorld, p: Vector3i) -> int:
	var count: int = 0
	for i in source.bookshelf_positions.size():
		var shelf: Array = source.bookshelf_positions[i]; var air: Array = source.air_positions[i]
		if world.node_at(p+Vector3i(shelf[0],shelf[1],shelf[2])) == Nodes.BOOKSHELF and world.node_at(p+Vector3i(air[0],air[1],air[2])) == Nodes.AIR: count += 1
	return mini(count,15)

static func state(game: Node3D) -> Dictionary:
	var key: String = game.player_id
	if not game.enchanting_state.has(key):
		game.enchanting_state[key] = {"seed":randi_range(1,2147483646),"serial":0,"cache":{}}
	return game.enchanting_state[key]

static func offers(game: Node3D, slot: Dictionary, shelves: int) -> Array:
	if not fresh(slot): return [{},{},{}]
	var saved: Dictionary = state(game)
	var key: String = "%d:%d"%[clampi(shelves,0,15),int(slot.id)]
	if not saved.cache.has(key):
		var seed_value: int = int(saved.seed)^((int(saved.serial)+1)*73856093)^key.hash()
		var generated: Array = generate_offers(slot,shelves,EnchantRolls.new(seed_value))
		for i in 3:
			if not generated[i].is_empty(): generated[i].token = (key+":"+str(saved.serial)+":"+str(i)+":"+JSON.stringify(generated[i])).sha256_text().substr(0,20)
		saved.cache[key] = generated
	return saved.cache[key].duplicate(true)

static func reset(game: Node3D) -> void:
	var saved: Dictionary = state(game)
	saved.serial = (int(saved.serial)+1)%2147483647; saved.cache.clear()

static func restore(raw: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not raw is Dictionary: return result
	for player in raw:
		if not player is String or not raw[player] is Dictionary: continue
		var saved: Dictionary = raw[player]
		var clean: Dictionary = {"seed":clampi(int(saved.get("seed",1)),1,2147483646),"serial":clampi(int(saved.get("serial",0)),0,2147483646),"cache":{}}
		if saved.get("cache") is Dictionary:
			for key in saved.cache:
				var parts: PackedStringArray = str(key).split(":")
				if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): continue
				var id: int = int(parts[1]); var rows: Variant = saved.cache[key]
				if int(parts[0]) < 0 or int(parts[0]) > 15 or ability(id) <= 0 or not rows is Array or rows.size() != 3: continue
				var valid: bool = true
				for row in rows:
					if not row is Dictionary: valid = false; break
					if row.is_empty(): continue
					if not row.get("enchantments") is Dictionary or not row.get("token") is String or not row.get("description") is String or not row.get("glyphs") is Array: valid = false; break
					if not row.get("level_requirement") is float and not row.get("level_requirement") is int: valid = false; break
					if row.enchantments.is_empty() or row.level_requirement < 1 or row.level_requirement > 30 or row.glyphs.size() != 9: valid = false; break
					for glyph in row.glyphs:
						if not glyph is float and not glyph is int or int(glyph) < 1 or int(glyph) > 18: valid = false; break
					for name in row.enchantments:
						if not source.definitions.has(name) or support(id,name).x == 0: valid = false; break
						if not row.enchantments[name] is float and not row.enchantments[name] is int: valid = false; break
						if int(row.enchantments[name]) < 1 or int(row.enchantments[name]) > int(source.definitions[name].max_level): valid = false; break
				if valid:
					var clean_rows: Array = rows.duplicate(true)
					for row in clean_rows:
						if row.is_empty(): continue
						row.level_requirement = int(row.level_requirement)
						for i in row.glyphs.size(): row.glyphs[i] = int(row.glyphs[i])
						for name in row.enchantments: row.enchantments[name] = int(row.enchantments[name])
					clean.cache[str(key)] = clean_rows
		result[player] = clean
	return result
