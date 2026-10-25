class_name Durability
extends RefCounted

# mcl_util/item.lua and the actual registered reference item capabilities.
const SCALE = 65535
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/durability.json")).profiles

static func profile(id: int) -> Dictionary:
	return profiles.get(str(id),{})

static func uses(slot: Dictionary) -> float:
	var id: int = int(slot.get("id",0))
	var level: int = Inventory.enchantment(slot,"Unbreaking")
	var stats: Dictionary = profile(id)
	if not stats.is_empty():
		if level in range(4): return float(stats.uses[level])
		var base: float = stats.uses[0]
		return base/(0.6+0.4/(level+1)) if stats.armor and not stats.elytra else base*(level+1)
	var base: float = Nodes.durability(id)
	return base/(0.6+0.4/(level+1)) if Nodes.is_armor(id) and id != Nodes.ELYTRA else base*(level+1)

static func normalized(slot: Dictionary) -> int:
	var id: int = int(slot.get("id",0)); var span: int = Nodes.durability(id)
	if id == 0 or span <= 0: return 0
	var data: Dictionary = slot.get("data",{})
	if int(data.get("wear_display",-1)) == int(slot.get("wear",0)) and data.has("wear_normalized"):
		return clampi(int(data.wear_normalized),0,SCALE)
	return clampi(floori(float(slot.get("wear",0))*SCALE/span),0,SCALE)

static func set_normalized(slot: Dictionary, wear: int) -> void:
	var span: int = Nodes.durability(int(slot.get("id",0)))
	if span <= 0: return
	if wear > SCALE:
		slot.clear(); slot.merge({"id":0,"count":0,"wear":0}); return
	wear = maxi(0,wear)
	slot.wear = ceili(float(wear)*span/SCALE)
	if not slot.has("data"): slot.data = {}
	if wear == 0:
		slot.data.erase("wear_normalized"); slot.data.erase("wear_display")
		if slot.data.is_empty(): slot.erase("data")
	else:
		slot.data.wear_normalized = wear; slot.data.wear_display = int(slot.wear)

# Luanti add_wear_by_uses distributes the remainder between its last uses,
# yielding exactly max_uses uses instead of repeatedly rounding a fraction.
static func next_wear(wear: int, max_uses: int) -> int:
	if max_uses <= 0: return wear
	max_uses = mini(max_uses,65535)
	var step: int = 65536/max_uses
	var remainder: int = 65536%max_uses
	var boundary: int = step*(max_uses-remainder)
	return wear+step+(1 if wear >= boundary else 0)

static func use(slot: Dictionary, amount: float = 1) -> bool:
	if int(slot.get("id",0)) == 0 or amount <= 0: return false
	var before: int = normalized(slot)
	var updated: int = next_wear(before,floori(uses(slot)/amount))
	set_normalized(slot,updated)
	return int(slot.get("id",0)) == 0

# The caller supplies the source candidate order: main hand, four armor slots,
# then offhand. Only one worn Mending item can consume a single XP award.
static func mend(slots: Array, xp: float, rng: EnchantRolls = null) -> float:
	var candidates: Array = []
	for slot in slots:
		if Inventory.enchantment(slot,"Mending") > 0 and normalized(slot) > 0 and uses(slot) > 0: candidates.append(slot)
	if candidates.is_empty(): return xp
	var choice: int = rng.integer(0,candidates.size()-1) if rng != null else randi_range(0,candidates.size()-1)
	var slot: Dictionary = candidates[choice]
	var multiplier: float = 2.0*SCALE/uses(slot)*(Inventory.enchantment(slot,"Unbreaking")+1)
	var next: float = normalized(slot)-xp*multiplier
	var remainder: float = floorf(-next/multiplier+0.5) if next < 0 else 0.0
	set_normalized(slot,maxi(0,floori(next)))
	return remainder
