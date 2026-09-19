class_name Candles
extends RefCounted

# Mineclonia ITEMS/mcl_candles/init.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference; all art is original procedural code.
#
# The source registers a candle per colour **and** per count, because up to four
# candles share one cell: `candle_<n>` and `candle_lit_<n>` for n = 1..4, with the
# colour in `param2` as a palette index. Voxey keeps the colour in the id (as it
# does for wool, terracotta, banners and beds) and keeps the count in the id too,
# which is the source's own scheme and makes the rendered stack exact. Per colour
# there are eight ids: four unlit counts then four lit counts.
#
# Source rules reproduced here:
# - A candle is a short, non-solid decoration: `not_solid`, `sunlight_propagates`,
#   hardness 0.1, and it must sit on a supporting block.
# - Up to four candles of the **same colour** share a cell. Placing a candle on a
#   candle of the same colour raises the count by one, capped at four. A different
#   colour does not stack, and a full stack consumes nothing.
# - Light follows the count exactly: the lit forms use `light_source = 3 * n`, so
#   one lit candle is 3, two 6, three 9 and four 12.
# - Flint and steel ignites an unlit candle; right-clicking a lit one extinguishes
#   it. The source also ignites on a burning arrow and extinguishes on a wind
#   charge; neither exists in this checkout, so those two paths are recorded here
#   rather than invented.
# - Placing a candle on a cake candled the cake, and breaking the candles on it
#   returns them.
# - Recipe: one string over one honeycomb. The dyeing recipe is shapeless
#   candle + dye.
#
# Source boxes (`candle_boxes`) give the four collision footprints a stack uses.

# Per colour: counts 1..4 unlit, then counts 1..4 lit. So a colour's block is
# `FIRST + color*8 + (4 if lit else 0) + (count-1)`.
const FIRST = 11072
const COUNT = 16
const PER_COLOR = 8
const COLORS = ["white","grey","silver","black","yellow","orange","red","magenta","purple","blue","cyan","lime","green","pink","light_blue","brown"]
const BLOCKS = [11072,11073,11074,11075,11076,11077,11078,11079,11080,11081,11082,11083,11084,11085,11086,11087,
	11088,11089,11090,11091,11092,11093,11094,11095,11096,11097,11098,11099,11100,11101,11102,11103,
	11104,11105,11106,11107,11108,11109,11110,11111,11112,11113,11114,11115,11116,11117,11118,11119,
	11120,11121,11122,11123,11124,11125,11126,11127,11128,11129,11130,11131,11132,11133,11134,11135,
	11136,11137,11138,11139,11140,11141,11142,11143,11144,11145,11146,11147,11148,11149,11150,11151,
	11152,11153,11154,11155,11156,11157,11158,11159,11160,11161,11162,11163,11164,11165,11166,11167,
	11168,11169,11170,11171,11172,11173,11174,11175,11176,11177,11178,11179,11180,11181,11182,11183,
	11184,11185,11186,11187,11188,11189,11190,11191,11192,11193,11194,11195,11196,11197,11198,11199]
const CAKE = 11280
const CAKE_LIT = 11281
# Source `light_source = 3 * i` for i = 1..4.
const LIGHT_PER_CANDLE = 3
const MAX_COUNT = 4
# Source `_mcl_hardness = 0.1`.
const HARDNESS = 0.1
# Source `candle_boxes`, one per count, in block-local coordinates.
const BOXES = [
	AABB(Vector3(0.4375,0.0,0.4375),Vector3(0.125,0.375,0.125)),
	AABB(Vector3(0.3125,0.0,0.4375),Vector3(0.375,0.375,0.1875)),
	AABB(Vector3(0.3125,0.0,0.3125),Vector3(0.3125,0.375,0.375)),
	AABB(Vector3(0.3125,0.0,0.375),Vector3(0.375,0.375,0.3125)),
]
# Where each candle in a stack of n stands, matching the source's box layout.
const SPOTS = [
	[Vector2(0.5,0.5)],
	[Vector2(0.375,0.5),Vector2(0.625,0.5)],
	[Vector2(0.375,0.375),Vector2(0.625,0.375),Vector2(0.5,0.625)],
	[Vector2(0.375,0.375),Vector2(0.625,0.375),Vector2(0.375,0.625),Vector2(0.625,0.625)],
]

static func is_candle(id: int) -> bool: return id >= FIRST and id < FIRST+COUNT*PER_COLOR
static func is_lit(id: int) -> bool: return is_candle(id) and (id-FIRST)%PER_COLOR >= MAX_COUNT
static func color_index(id: int) -> int: return (id-FIRST)/PER_COLOR if is_candle(id) else -1
static func count_of(id: int) -> int: return (id-FIRST)%PER_COLOR%MAX_COUNT+1 if is_candle(id) else 0
# The canonical item for a colour: one unlit candle.
static func item_for(color: int) -> int: return FIRST+color*PER_COLOR
static func unlit_of(id: int) -> int: return FIRST+color_index(id)*PER_COLOR+count_of(id)-1 if is_candle(id) else 0
static func lit_of(id: int) -> int: return FIRST+color_index(id)*PER_COLOR+MAX_COUNT+count_of(id)-1 if is_candle(id) else 0
# The next count in the same colour and lit state, or 0 when already full.
static func grown(id: int) -> int:
	return 0 if count_of(id) >= MAX_COUNT else id+1
static func dye_of(id: int) -> int: return VillageContent.DYE_WHITE+color_index(id) if is_candle(id) else 0
# Source `light_source = 3 * i`.
static func light_level(id: int) -> int: return LIGHT_PER_CANDLE*count_of(id) if is_lit(id) else 0
static func is_cake(id: int) -> bool: return id == CAKE or id == CAKE_LIT
# Breaking a stack hands back one item per candle, which is the source's
# `ItemStack("mcl_candles:candle_1 " .. group)`. The item is always the single
# unlit candle of that colour; the stack count is how many candles it is.
static func drop_id(id: int) -> int: return item_for(color_index(id)) if is_candle(id) else CAKE
static func drop_count(id: int) -> int: return count_of(id) if is_candle(id) else 1

# A candle stack breaks into its own count of single candles, so it must not go
# through the generic one-item drop path.
static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int) -> bool:
	if not is_candle(id) and not is_cake(id): return false
	var drops: Array = [[drop_id(id),drop_count(id)]]
	if is_cake(id):
		# A candled cake keeps its ordinary cake behaviour; `FoodFeatures` owns
		# that path, so only the candles are this module's to return.
		var state: Dictionary = game.world.block_states.get(VoxelWorld.station_key(p),{})
		drops = [[item_for(clampi(int(state.get("color",0)),0,COUNT-1)),1]] if state.has("color") else []
	if not game.world.set_node(p,Nodes.AIR): return true
	if game.gamemode != "creative":
		for entry in drops: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	game._break_particles(p,id)
	game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

# --- interaction -------------------------------------------------------------

# A candle only rests on a solid block, which is the source's `attached_node`.
static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	return world.loaded_at(Vector3(p+Vector3i.DOWN)) and Nodes.solid(world.node_at(p+Vector3i.DOWN))

static func boxes(id: int) -> Array: return [BOXES[count_of(id)-1]] if is_candle(id) else []

# `on_place`: stacking on a candle of the same colour, candling a cake, or placing
# a fresh candle. Returns true whenever the call was this module's to handle, so
# the generic placement path stops; a refused stack still consumes nothing.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if not is_candle(held) or target.is_empty(): return false
	var world: VoxelWorld = game.world
	# A candle can be aimed at either directly or through the block beneath it, so
	# both the targeted cell and the cell the candle would occupy are candidates for
	# stacking. Without the second, placing onto the ground under an existing candle
	# would add a second node instead of growing the stack.
	var stack_at: Vector3i = Vector3i(-2147483647,-2147483647,-2147483647)
	for candidate in [target.pos,target.get("replace",target.pos+target.normal)]:
		var here: int = world.node_at(candidate)
		if is_candle(here) and color_index(here) == color_index(held): stack_at = candidate; break
	if stack_at.x != -2147483647:
		var existing: int = world.node_at(stack_at)
		var room: int = MAX_COUNT-count_of(existing)
		if room <= 0: return true
		# A held stack places as many candles as the cell has room for, which is the
		# source's `group < #candle_boxes` check against the stack count.
		var held_count: int = maxi(1,int(game.inventory.held().get("count",1)))
		var placed: int = mini(room,held_count)
		if world.set_node(stack_at,FIRST+color_index(held)*PER_COLOR+count_of(existing)+placed-1):
			if game.gamemode != "creative": game.inventory.consume_selected(placed)
			game.sound("place"); game.player.swing = 1
			game.api.emit_node_placed(stack_at,world.node_at(stack_at))
		return true
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	if not SnowCover.replaceable(world.node_at(at)) or not BuildingShapes.supports(world,at+Vector3i.DOWN,Vector3i.DOWN):
		game.toast("Candles need a solid block underneath.")
		return true
	# A candle placed on a cake candled it, which is the source's own swap.
	if FoodFeatures.is_cake(world.node_at(at)):
		if world.set_node(at,CAKE_LIT if is_lit(held) else CAKE):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place"); game.player.swing = 1
			game.api.emit_node_placed(at,world.node_at(at))
		return true
	if not world.set_node(at,held):
		return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,world.node_at(at))
	return true

# The source's `on_rightclick` (extinguish), `_on_ignite` (flint and steel) and the
# candled-cake branch, sharing one entry point.
static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var world: VoxelWorld = game.world
	var p: Vector3i = target.pos
	var id: int = world.node_at(p)
	if not is_candle(id) and not is_cake(id): return false
	var held: int = game.inventory.held().id
	if is_cake(id):
		# Flint and steel lights or extinguishes the cake's candles.
		if held != Nodes.FLINT_AND_STEEL: return false
		return _swap(game,p,CAKE if id == CAKE_LIT else CAKE_LIT)
	if held == Nodes.FLINT_AND_STEEL:
		if not is_lit(id): _swap(game,p,lit_of(id))
		return true
	if is_lit(id): return _swap(game,p,unlit_of(id))
	return false

static func _swap(game: Node3D, p: Vector3i, to: int) -> bool:
	if not game.world.set_node(p,to): return false
	if game.gamemode != "creative": game.inventory.damage_tool()
	game.sound("place"); game.player.swing = 1
	return true

# `drop_candles`: breaking a stack returns its candles as one item of that count,
# and a candled cake returns the candles.
static func harvest(id: int) -> Array:
	return [[unlit_of(id),count_of(id)]] if is_candle(id) else []

# A candle needs support; losing it drops the stack, which is `on_destruct`.
static func changed(world: VoxelWorld, p: Vector3i, _old_id: int, id: int) -> void:
	for at in [p,p+Vector3i.UP]:
		if not world.loaded_at(Vector3(at)): continue
		var here: int = world.node_at(at)
		if (is_candle(here) or is_cake(here)) and not supported(world,at):
			var items: Array = harvest(here)
			if world.set_node(at,Nodes.AIR):
				var game: Node = world.get_parent()
				if game != null and game.has_method("spawn_drop"):
					for entry in items: game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,entry[0],entry[1])

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# `mcl_candles:init.lua` registers `string` over `honeycomb` -> one candle,
	# with Voxey's white entry canonical, matching wool, terracotta and the banners.
	inv._recipe("Candle",item_for(0),1,[Nodes.STRING,0,0,Beehives.COMB],2)
	# The source's shapeless `group:candles` + `group:dye` recolour.
	for i in COUNT:
		inv._shapeless("%s candle"%COLORS[i].replace("_"," ").capitalize(),item_for(i),1,[item_for(0),VillageContent.DYE_WHITE+i])

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if is_cake(id):
		# The cake surface plus the candle standing in it, so a candled cake reads
		# as a cake with a candle rather than a plain one.
		if y < 4: return Color("f0d4a5").darkened(0.05 if x%3 == 0 else 0.0)
		if absi(x-7) <= 1: return (Color("ffe87a") if y < 2 else base) if is_lit(id) else base
		return Color("f0d4a5").darkened(0.08 if y%2 == 0 else 0.0)
	# A candle is a narrow column: body in the middle, a flame above when lit, and
	# the surroundings transparent so the block behind shows through.
	if absi(x-7) > 1: return Color(0,0,0,0)
	if y < 4: return (Color("ffe87a") if y > 0 else Color("ffb347")) if is_lit(id) else Color(0,0,0,0)
	if y < 6: return Color("2b2b2b")
	return noise.lerp(base,0.7) if y%3 == 0 else base

# The candled cake's own geometry: one candle standing in the middle of the cake,
# which is what the source's `mcl_candles_cake.obj` shows. `FoodFeatures.mesh`
# draws the cake body and calls this for the candle.
static func candles_on(out: Array, at: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(item_for(0),0)
	BlockMesher._art_box(out,at+Vector3(0.5,0.5,0.5),Vector3(0.125,0.375,0.125),tile,tile)
	if id == CAKE_LIT:
		BlockMesher._art_box(out,at+Vector3(0.5,0.75,0.5),Vector3(0.09,0.125,0.09),tile,tile)
