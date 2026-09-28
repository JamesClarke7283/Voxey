class_name FurnaceRules
extends RefCounted

# `mcl_furnaces/init.lua`:407 stores one point of experience per smelted item in the
# furnace's own metadata, paid out when the output is withdrawn (`give_xp`, :99-111).
# The source's own comment records that every recipe shares this single count.
const XP_PER_SMELT = 1

# All insertion paths share this rule; extracting items never needs permission.
static func accepts(slots: Array, index: int, id: int) -> bool:
	if id == 0: return true
	if slots.size() != 3: return false
	if index == 1: return Nodes.fuel_time(id) > 0
	return index == 0 and int(slots[2].get("count",0)) == 0 and Nodes.smelt_result(id) != 0

# `mcl_furnaces.give_xp`: the whole accumulated count is paid out when the output is
# withdrawn, and the store is cleared. `player` picks the source's branch — a player
# taking the output is credited directly, while an automated extraction (a hopper)
# throws the experience at the furnace as orbs.
static func payout(game: Node3D, station: Dictionary, at: Vector3, player: bool = true) -> int:
	var xp: int = int(station.get("xp",0))
	if xp <= 0: return 0
	station.erase("xp")
	if player: game.experience += xp
	else: XpOrbs.throw_xp(game,at,xp)
	return xp
