class_name ArmorEffects
extends RefCounted

# mcl_armor/damage.lua. Normal wear, protection and per-piece Thorns run in one
# pass, so a piece still protects against the hit that breaks it.
static func flags(cause: String, legacy_bypass: bool = false) -> Dictionary:
	var key: String = DeathMessages._source_reason(cause)
	if DeathMessages.DECLARED.has(key): return DeathMessages.DECLARED[key].duplicate()
	return {"bypasses_armor":legacy_bypass,"is_fire":cause == "fire"}

static func roll(rng: EnchantRolls, low: int, high: int) -> int:
	return rng.integer(low,high) if rng != null else randi_range(low,high)

static func chance(rng: EnchantRolls) -> float:
	return rng.unit() if rng != null else randf()

static func resolve(slots: Array, damage: float, damage_flags: Dictionary, cause: String = "mob", has_source: bool = false, rng: EnchantRolls = null, order: Array = [0,1,2,3], retaliate: Callable = Callable(), breach: int = 0, self_source: bool = false) -> Dictionary:
	var result: Dictionary = {"damage":damage,"reflected":0,"broken":[]}
	if damage_flags.get("bypasses_armor",false) and damage_flags.get("bypasses_magic",false): return result
	var wear_uses: int = maxi(1,floori(damage/4))
	var points: float = 0; var toughness: float = 0; var protection: int = 0
	var regular: int = 0; var irregular: int = 0; var thorns: Array = []
	for index in order:
		if index < 0 or index >= slots.size(): continue
		var slot: Dictionary = slots[index]
		var id: int = int(slot.get("id",0))
		if id == 0: continue
		var enchants: Dictionary = slot.get("data",{}).get("enchantments",{}).duplicate()
		if not damage_flags.get("bypasses_armor",false) and Nodes.armor_points(id) > 0 and id != Nodes.ELYTRA:
			points += Nodes.armor_points(id); toughness += Nodes.armor_toughness(id)
			if Durability.use(slot,wear_uses): result.broken.append(id)
		if not damage_flags.get("bypasses_magic",false):
			protection += int(enchants.get("Protection",0))
			if cause == "fall": protection += 3*int(enchants.get("Feather Falling",0))
			if damage_flags.get("is_fire",false): protection += 2*int(enchants.get("Fire Protection",0))
			if damage_flags.get("is_explosion",false): protection += 2*int(enchants.get("Blast Protection",0))
			if damage_flags.get("is_projectile",false): protection += 2*int(enchants.get("Projectile Protection",0))
		var level: int = int(enchants.get("Thorns",0))
		if has_source and level > 0:
			if level > 10: irregular += level-10
			elif regular < 4 and chance(rng) < level*0.15: regular = mini(4,regular+roll(rng,1,4))
			thorns.append(index)
	result.damage = damage*(1-minf(20,maxf(points/5.0,points-damage/(2+toughness/4.0)))/25.0)
	result.damage *= 1-mini(20,protection)/25.0
	result.damage *= 1.0+0.15*breach
	result.reflected = regular+irregular if cause != "thorns" and not self_source else 0
	if result.reflected > 0 and cause != "thorns":
		var alive: bool = true if not retaliate.is_valid() else bool(retaliate.call(result.reflected))
		if alive:
			var index: int = thorns[roll(rng,0,thorns.size()-1)]
			var id: int = int(slots[index].get("id",0))
			if Durability.use(slots[index],2) and id > 0: result.broken.append(id)
		else:
			# The source modifier returns nil if retaliation removes its source;
			# run_modifiers then retains the damage from before armor processing.
			result.damage = damage
	return result
