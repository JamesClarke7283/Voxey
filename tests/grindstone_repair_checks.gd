extends RefCounted

# The grindstone's repair half (`mcl_grindstone/init.lua:133-137` combine,
# `:139-144` condition, `:56-64` curse transfer, `:67-77` XP, `:255-283` the take
# handler's accounting). Voxey's grindstone branch used to spend one item for a
# flat three experience points; these checks pin the two-item combine and the
# per-item XP the source actually pays.
static func run(suite: Object, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_pouches: Array = game.inventory.pouch_slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_experience: float = game.experience
	var old_state: String = game.state
	# `game.experience`'s setter mends worn armor when the game is in one of its
	# live states, which would swallow the XP these checks measure.
	game.state = "paused"

	var pick: int = Nodes.TOOLS+10
	var span: int = Nodes.durability(pick)
	suite.check(Nodes.title(pick) == "Iron pickaxe" and span == 251,"the worn pair is the iron pickaxe, with the source's 251 durability")
	var axe: int = Nodes.TOOLS+11
	var worn_a: Dictionary = {"id":pick,"count":1,"wear":200}
	var worn_b: Dictionary = {"id":pick,"count":1,"wear":150}

	# --- compatibility -------------------------------------------------------
	suite.check(GrindstoneRepair.compatible(worn_a,worn_b),"two worn iron pickaxes are compatible")
	suite.check(not GrindstoneRepair.compatible(worn_a,{"id":axe,"count":1,"wear":200}),"two different items are not compatible")
	suite.check(not GrindstoneRepair.compatible(worn_a,{"id":pick,"count":1,"wear":0}),"a piece at full durability has nothing to combine")
	suite.check(not GrindstoneRepair.compatible({"id":pick,"count":1,"wear":0},worn_b),"the full-durability piece is rejected in the first position too")
	suite.check(not GrindstoneRepair.compatible({"id":Nodes.DIRT,"count":1,"wear":5},worn_b),"an item with no durability is never combined")
	suite.check(not GrindstoneRepair.compatible({"id":pick,"count":1,"wear":200},{"id":Nodes.DIRT,"count":1,"wear":5}),"an undamageable item is rejected in the second position too")
	suite.check(not GrindstoneRepair.compatible({"id":0,"count":0,"wear":0},worn_b) and not GrindstoneRepair.compatible(worn_a,{"id":0,"count":0,"wear":0}),"an empty slot is not compatible")
	# The source strips the `_enchanted` suffix before comparing names
	# (`:130-131`), so two pieces enchanted differently still combine.
	suite.check(GrindstoneRepair.compatible({"id":pick,"count":1,"wear":200,"data":{"enchantments":{"Efficiency":3}}},{"id":pick,"count":1,"wear":150,"data":{"enchantments":{"Silk Touch":1}}}),"differently enchanted pieces of the same item still combine")
	# Armor is registered as a tool in the source, so it repairs the same way.
	suite.check(GrindstoneRepair.compatible({"id":Nodes.ARMOR,"count":1,"wear":100},{"id":Nodes.ARMOR,"count":1,"wear":100}),"two worn chestplates are compatible, as the source's tool type covers armor")

	# --- the source's wear arithmetic ---------------------------------------
	# `calculate_repair` (:133-137) works on health: `(MAX_WEAR - dur1) +
	# (MAX_WEAR - dur2) * 1.05`, clamped to `0..MAX_WEAR`. Voxey stores wear
	# rather than health, so every `MAX_WEAR` is the item's own durability.
	# Hand-computed for wear 200 and 150 of a 251 span, with the 5% bonus on the
	# **second** term only: health = (251-200) + (251-150)*1.05 = 51 + 106.05 =
	# 157.05, and wear = 251 - 157.05 = 93.95, which the engine truncates to 93.
	var expected: float = 251.0-(51.0+101.0*1.05)
	suite.check(is_equal_approx(expected,93.95) and int(expected) == 93,"the hand-computed result of the source's formula is 93.95, truncated to 93")
	var combined: Dictionary = GrindstoneRepair.combine(worn_a,worn_b)
	suite.check(int(combined.get("wear",-1)) == 93 and int(combined.get("id",0)) == pick and int(combined.get("count",0)) == 1,"combining wear 200 and 150 yields wear 93, the source's formula with its 5% bonus truncated")
	suite.check(int(GrindstoneRepair.repair_wear(200,150,span)) == int(expected),"the combine result is the hand-computed value, and the bonus multiplies the second term alone")
	# The bonus is on one term only, so swapping the inputs is observable: 150
	# and 200 give health 101 + 51*1.05 = 154.55 and a wear of 96.45 -> 96.
	suite.check(int(GrindstoneRepair.repair_wear(150,200,span)) == int(251.0-(101.0+51.0*1.05)) and int(GrindstoneRepair.repair_wear(150,200,span)) == 96,"the 5% bonus applies to the second input alone, so order matters")
	# The conversion is per item: `MAX_WEAR - wear` is the item's own health, so the
	# same wear pair repairs differently on items of different durability. Wear 40
	# and 50 on a 60 span: health = 20 + 10*1.05 = 30.5, wear = 60 - 30.5 = 29.5 ->
	# 29. The identical pair on a 251 span: health = 211 + 201*1.05 = 422.05, which
	# over-repairs and floors at the source's `math.max(0, ...)`.
	var wood: int = Nodes.TOOLS+0
	var wood_span: int = Nodes.durability(wood)
	suite.check(wood_span == 60 and Nodes.title(wood) == "Wooden pickaxe" and span == 251,"the scaled pair is the wooden pickaxe at 60 durability, against the iron pickaxe's 251")
	suite.check(int(GrindstoneRepair.repair_wear(40,50,wood_span)) == int(60.0-(20.0+10.0*1.05)) and int(GrindstoneRepair.repair_wear(40,50,wood_span)) == 29,"a 60-durability item uses its own span: 60 - (20 + 10*1.05) = 29.5 -> 29")
	suite.check(int(GrindstoneRepair.combine({"id":wood,"count":1,"wear":40},{"id":wood,"count":1,"wear":50}).wear) == 29,"the repair reads the durability of the item it is repairing")
	suite.check(GrindstoneRepair.repair_wear(40,50,span) == 0 and GrindstoneRepair.repair_wear(40,50,span) != GrindstoneRepair.repair_wear(40,50,wood_span),"the identical pair on the 251-durability pickaxe gives a different answer, so the span is the item's own and not a fixed scale")
	# The source's `math.max(0, ...)` floor is therefore reachable: an over-worn
	# pair repairs to a whole item rather than to a negative wear.
	suite.check(int(GrindstoneRepair.combine({"id":wood,"count":1,"wear":20},{"id":wood,"count":1,"wear":15}).wear) == 0,"an over-repair floors at zero instead of going negative")
	# Two nearly whole pieces repair almost completely, and the result never
	# lands on the durability value that `Inventory.damage_tool` destroys at.
	suite.check(int(GrindstoneRepair.combine({"id":pick,"count":1,"wear":1},{"id":pick,"count":1,"wear":1}).wear) == 0,"two barely worn pieces combine to an unbroken item")
	suite.check(GrindstoneRepair.repair_wear(span,span,span) == span-1 and GrindstoneRepair.repair_wear(span,span,span) <= span-1,"the combined wear is capped one below the item's durability, never at it")
	for pair in [[1,37,120,200,250],[1,80,175,250]]:
		for first_wear in pair:
			for second_wear in pair:
				for durability in [wood_span,span,Nodes.durability(Nodes.ARMOR),Nodes.durability(Nodes.ELYTRA)]:
					var wear: int = int(GrindstoneRepair.repair_wear(first_wear,second_wear,durability))
					if wear < 0 or wear > durability-1:
						suite.check(false,"a combined wear stays inside the item's own range"); return
	suite.check(true,"every combined wear stays inside its item's own 0..durability-1 range")
	# The pair survives intact — `combine` reports a result, it does not consume.
	suite.check(int(worn_a.wear) == 200 and int(worn_b.wear) == 150 and not worn_a.has("data"),"combine leaves both inputs untouched")

	# --- curse transfer and the enchantments that are dropped ---------------
	# The source rebuilds the item with `create_new_item` and then re-applies the
	# curses from **both** inputs (`:142-143`), keeping nothing else.
	var cursed: Dictionary = {"id":pick,"count":1,"wear":200,"data":{"enchantments":{"Efficiency":3,"Curse of Vanishing":1}}}
	var sacrifice: Dictionary = {"id":pick,"count":1,"wear":150,"data":{"enchantments":{"Silk Touch":1,"Mending":1,"Curse of Binding":1}}}
	var repaired: Dictionary = GrindstoneRepair.combine(cursed,sacrifice)
	var kept: Dictionary = repaired.get("data",{}).get("enchantments",{})
	suite.check(int(kept.get("Curse of Vanishing",0)) == 1 and int(kept.get("Curse of Binding",0)) == 1,"curses from both pieces are transferred to the repaired item")
	suite.check(kept.size() == 2 and not kept.has("Efficiency") and not kept.has("Silk Touch") and not kept.has("Mending"),"ordinary enchantments are dropped rather than carried over")
	suite.check(int(GrindstoneRepair.combine(worn_a,sacrifice).data.enchantments.get("Curse of Binding",0)) == 1,"a curse on the second piece alone still survives")
	suite.check(GrindstoneRepair.combine(worn_a,worn_b).get("data",{}).is_empty(),"a pair with no enchantments produces no metadata at all")
	# `create_new_item` copies the name from the first input only (`:51`), so a
	# named first piece keeps its name and the second piece's name is dropped.
	var named: Dictionary = GrindstoneRepair.combine({"id":pick,"count":1,"wear":200,"data":{"custom_name":"Digger"}},{"id":pick,"count":1,"wear":150,"data":{"custom_name":"Spare"}})
	suite.check(str(named.get("data",{}).get("custom_name","")) == "Digger","the repaired item keeps the first piece's name, as `create_new_item` does")
	# Curses only, with no wear left to repair, still yields nothing.
	suite.check(GrindstoneRepair.combine(worn_a,{"id":pick,"count":1,"wear":0}).is_empty(),"an incompatible pair yields no result")

	# --- XP ----------------------------------------------------------------
	suite.check(GrindstoneRepair.xp_for(worn_a) == 0 and GrindstoneRepair.xp_for({}) == 0 and GrindstoneRepair.xp_for({"id":pick,"count":1,"wear":10,"data":{"enchantments":{}}}) == 0,"an item with no enchantments pays no experience")
	suite.check(GrindstoneRepair.xp_for({"id":pick,"count":1,"wear":10,"data":{"enchantments":{"Curse of Vanishing":1,"Curse of Binding":1}}}) == 0,"curses pay nothing, as `calculate_xp` skips them")
	# `math.random(7, 13) * level`, so a mirrored generator with the same seed and
	# the same single draw gives the exact value.
	var seed: int = 8675309
	var probe := RandomNumberGenerator.new(); probe.seed = seed
	var draw: int = probe.randi_range(7,13)
	var generator := RandomNumberGenerator.new(); generator.seed = seed
	suite.check(GrindstoneRepair.xp_for({"id":pick,"count":1,"wear":10,"data":{"enchantments":{"Efficiency":3}}},generator) == draw*3,"one level-three enchantment pays random(7,13) * level")
	# A curse consumes no draw, so the same seed still yields the same roll.
	var mixed_probe := RandomNumberGenerator.new(); mixed_probe.seed = seed
	var mixed_draw: int = mixed_probe.randi_range(7,13)
	var mixed := RandomNumberGenerator.new(); mixed.seed = seed
	var mixed_slot: Dictionary = {"id":pick,"count":1,"wear":10,"data":{"enchantments":{"Curse of Vanishing":1,"Silk Touch":2}}}
	suite.check(GrindstoneRepair.xp_for(mixed_slot,mixed) == mixed_draw*2,"a curse alongside one enchantment still draws exactly once")
	# Two enchantments each pay their own roll, so the total is a sum of two
	# draws rather than one draw times the level count.
	var pair := RandomNumberGenerator.new(); pair.seed = 42
	var sum: int = GrindstoneRepair.xp_for({"id":pick,"count":1,"wear":10,"data":{"enchantments":{"Efficiency":2,"Silk Touch":1}}},pair)
	var twice := RandomNumberGenerator.new(); twice.seed = 42
	var both: int = twice.randi_range(7,13)*2+twice.randi_range(7,13)
	suite.check(sum == both and sum >= 21 and sum <= 39,"each non-curse enchantment pays its own roll, giving 21..39 for levels two and one")
	# `calculate_xp` never asks whether the enchantment belongs on the item, so an
	# enchantment that cannot be on a pickaxe still pays.
	var foreign: int = GrindstoneRepair.xp_for({"id":pick,"count":1,"wear":10,"data":{"enchantments":{"Sharpness":1}}},RandomNumberGenerator.new())
	suite.check(foreign >= 7 and foreign <= 13,"a non-curse enchantment pays whatever item carries it, as the source's `calculate_xp` does")

	# --- the whole operation on a real inventory ---------------------------
	game.inventory.slots[0] = {"id":pick,"count":1,"wear":200,"data":{"enchantments":{"Efficiency":2}}}
	game.inventory.slots[1] = {"id":pick,"count":1,"wear":150,"data":{"enchantments":{"Curse of Vanishing":1,"Silk Touch":1}}}
	var started: float = game.experience
	var orbs_before: int = XpOrbs.orb_count(game)
	var acted: bool = GrindstoneRepair.use(game,game.inventory.slots[0],game.inventory.slots[1])
	var result: Dictionary = game.inventory.slots[0]
	suite.check(acted,"use combines a real inventory pair")
	suite.check(int(result.wear) == 93 and int(result.id) == pick and int(game.inventory.slots[1].id) == 0,"the first slot holds the repaired piece and the second is consumed")
	suite.check(int(result.get("data",{}).get("enchantments",{}).get("Curse of Vanishing",0)) == 1 and not result.get("data",{}).get("enchantments",{}).has("Efficiency"),"the repaired piece carries the second piece's curse and none of the ordinary enchantments")
	# `mcl_grindstone/init.lua`:282-283 **throws** the experience at the grindstone
	# rather than crediting it, so the reward is a set of orbs: Efficiency level two
	# and Silk Touch level one pay 7..13 * 2 plus 7..13 * 1 between them.
	var thrown: int = 0
	for orb in XpOrbs.orbs(game): thrown += int(orb.xp)
	suite.check(acted and game.experience == started and XpOrbs.orb_count(game) > orbs_before and thrown >= 21 and thrown <= 39,"the sacrificed pair throws random(7,13) per non-curse level, 21..39 for these two pieces")
	XpOrbs.clear(game)
	# A pair that cannot combine changes nothing at all.
	game.inventory.slots[0] = {"id":pick,"count":1,"wear":200}
	game.inventory.slots[1] = {"id":axe,"count":1,"wear":150}
	var before: float = game.experience
	suite.check(not GrindstoneRepair.use(game,game.inventory.slots[0],game.inventory.slots[1]),"use refuses two different items")
	suite.check(int(game.inventory.slots[0].wear) == 200 and int(game.inventory.slots[1].id) == axe and game.experience == before,"a refused pair consumes nothing and pays nothing")
	suite.check(not GrindstoneRepair.use(game,game.inventory.slots[0],game.inventory.slots[0]),"use refuses one slot offered as both inputs")
	suite.check(int(game.inventory.slots[0].wear) == 200,"offering one slot twice leaves it whole")
	# Two pieces with identical contents in different slots are still two pieces,
	# which is why the guard is reference identity and not equality.
	game.inventory.slots[0] = {"id":pick,"count":1,"wear":100,"data":{"enchantments":{"Efficiency":1}}}
	game.inventory.slots[1] = {"id":pick,"count":1,"wear":100,"data":{"enchantments":{"Efficiency":1}}}
	suite.check(game.inventory.slots[0] == game.inventory.slots[1] and not is_same(game.inventory.slots[0],game.inventory.slots[1]) and GrindstoneRepair.use(game,game.inventory.slots[0],game.inventory.slots[1]),"two identical stacks in different slots combine, since the guard is reference identity")

	game.experience = old_experience
	game.inventory.selected = old_selected
	game.inventory.restore(old_slots,old_pouches)
	game.state = old_state
	suite.check(game.inventory.slots == old_slots and game.experience == old_experience,"the inventory and experience are restored after the checks")
