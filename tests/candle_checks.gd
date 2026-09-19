extends RefCounted

# Candles (mcl_candles): four counts per colour, unlit and lit, the source's
# `light_source = 3 * n`, same-colour stacking, ignition and extinguishing.
static func run(suite: Object, game: Node3D) -> void:
	var p: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+2,4)
	for x in range(2,8):
		for z in range(2,8):
			for y in range(p.y-1,p.y+3): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	# Id arithmetic: eight ids per colour, four unlit then four lit.
	suite.check(Candles.FIRST == 11072 and Candles.PER_COLOR == 8 and Candles.COUNT == 16,"candles use eight ids per colour, four unlit then four lit")
	var all_ok: bool = true
	for c in Candles.COUNT:
		for n in range(1,Candles.MAX_COUNT+1):
			var unlit: int = Candles.FIRST+c*Candles.PER_COLOR+n-1
			var lit: int = Candles.FIRST+c*Candles.PER_COLOR+Candles.MAX_COUNT+n-1
			if not Nodes.exists(unlit) or not Nodes.exists(lit): all_ok = false
			if not Nodes.placeable(unlit) or not Nodes.placeable(lit): all_ok = false
			if Candles.is_lit(unlit) or not Candles.is_lit(lit): all_ok = false
			if Candles.color_index(unlit) != c or Candles.color_index(lit) != c: all_ok = false
			if Candles.count_of(unlit) != n or Candles.count_of(lit) != n: all_ok = false
			if Candles.unlit_of(lit) != unlit or Candles.lit_of(unlit) != lit: all_ok = false
			if Candles.light_level(lit) != 3*n or Candles.light_level(unlit) != 0: all_ok = false
			if Candles.dye_of(unlit) != VillageContent.DYE_WHITE+c: all_ok = false
	suite.check(all_ok,"all 128 candle nodes map to their colour and count, and lit light is the source's 3 * n")
	# A candle is a small non-solid decoration, not a cube.
	suite.check(not Nodes.solid(Candles.FIRST) and Nodes.transparent(Candles.FIRST) and Nodes.hardness(Candles.FIRST) == Candles.HARDNESS,"a candle is a non-solid decoration at the source's hardness")
	suite.check(Nodes.preferred_tool(Candles.FIRST) == -1 and Candles.boxes(Candles.FIRST)[0].size == Candles.BOXES[0].size,"a candle has no preferred tool and its own small footprint")
	suite.check(Candles.boxes(Candles.FIRST+3)[0] == Candles.BOXES[3],"a four-candle stack uses the source's widest footprint")
	# Placing on solid ground, then stacking the same colour to four.
	var ground: Vector3i = p
	game.world.set_node(ground,Nodes.STONE)
	var at: Vector3i = ground+Vector3i.UP
	var target: Dictionary = {"pos":ground,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0,"point":Vector3(ground)}
	game.gamemode = "survival"
	game.inventory.slots[game.inventory.selected] = {"id":Candles.FIRST+3,"count":4,"wear":0}
	var existing: Vector3i = at
	game.world.set_node(existing,Candles.FIRST+3)
	suite.check(Candles.place(game,target,Candles.FIRST+3) and game.world.node_at(existing) == Candles.FIRST+3+0,"placing on a candle of the same colour stacks")
	# From a fresh single candle, stacking four times reaches the four-count form.
	game.world.set_node(existing,Candles.FIRST)
	for i in 3:
		game.inventory.slots[game.inventory.selected] = {"id":Candles.FIRST,"count":1,"wear":0}
		Candles.place(game,target,Candles.FIRST)
	suite.check(game.world.node_at(existing) == Candles.FIRST+3,"four placements of the same colour fill a four-candle stack")
	game.inventory.slots[game.inventory.selected] = {"id":Candles.FIRST,"count":1,"wear":0}
	Candles.place(game,target,Candles.FIRST)
	suite.check(game.world.node_at(existing) == Candles.FIRST+3 and game.inventory.held().count == 1,"a full stack consumes nothing")
	# A different colour does not stack onto it.
	game.world.set_node(existing+Vector3i.RIGHT,Nodes.AIR)
	game.world.set_node(existing,Nodes.AIR)
	game.world.set_node(at,Candles.FIRST+8)
	game.inventory.slots[game.inventory.selected] = {"id":Candles.FIRST+1,"count":1,"wear":0}
	Candles.place(game,target,Candles.FIRST+1)
	suite.check(game.world.node_at(at) == Candles.FIRST+8,"a different colour does not stack onto an existing candle")
	# Ignition and extinguishing.
	game.inventory.slots[game.inventory.selected] = {"id":Nodes.FLINT_AND_STEEL,"count":1,"wear":0}
	var flame_target: Dictionary = {"pos":at,"normal":Vector3i.UP,"id":game.world.node_at(at),"distance":2.0,"point":Vector3(at)}
	suite.check(Candles.use(game,flame_target) and Candles.is_lit(game.world.node_at(at)),"flint and steel lights an unlit candle")
	suite.check(Candles.light_level(game.world.node_at(at)) == 3 and not Nodes.solid(game.world.node_at(at)),"a lit single candle emits the source's three")
	game.inventory.slots[game.inventory.selected] = {"id":0,"count":0,"wear":0}
	suite.check(Candles.use(game,flame_target) and not Candles.is_lit(game.world.node_at(at)),"right-clicking a lit candle extinguishes it")
	# Light reaches the world's light solver.
	game.world.set_node(at,Candles.FIRST+Candles.MAX_COUNT+3)
	suite.check(Pasture.emission(game.world,at) == 12,"a lit four-candle stack emits the source's twelve")
	game.world.set_node(at,Candles.FIRST)
	suite.check(Pasture.emission(game.world,at) == 0,"an unlit candle emits nothing")
	# Breaking a stack returns one item per candle, as the source's count does.
	game.world.set_node(at,Candles.FIRST+3)
	var before: int = game.drops.get_child_count()
	game.gamemode = "survival"
	game.break_node(at,Candles.FIRST+3,0)
	var total: int = 0
	for i in range(game.drops.get_child_count()):
		var drop: ItemDrop = game.drops.get_child(i)
		if drop.item_id == Candles.FIRST: total += drop.amount
	suite.check(game.drops.get_child_count() > before and total == 4,"breaking a four-candle stack returns one candle per candle in the stack")
	# Recipe: string over honeycomb, and the shapeless dye recolour.
	var inv := Inventory.new()
	inv.add_item(Nodes.STRING,1); inv.add_item(Beehives.COMB,1)
	var index: int = inv.recipe_index(Candles.FIRST)
	suite.check(index >= 0 and inv.can_craft(inv.recipes[index],"table"),"the source's string over honeycomb recipe makes a candle")
	inv = Inventory.new(); inv.add_item(Candles.FIRST,1); inv.add_item(VillageContent.DYE_BLUE,1)
	var recolour: int = inv.recipe_index(Candles.item_for(9))
	suite.check(recolour >= 0 and inv.recipes[recolour].shapeless and inv.can_craft(inv.recipes[recolour],"table"),"a candle and a dye recolour it shapelessly")
	# Only the single unlit candle of each colour is an obtainable item.
	suite.check(Nodes.all_ids().has(Candles.item_for(0)) and not Nodes.all_ids().has(Candles.FIRST+3) and not Nodes.all_ids().has(Candles.FIRST+Candles.MAX_COUNT),"only the single unlit candle of each colour is catalogued")
	# Art and a dedicated atlas tile.
	var varied: bool = false
	for x in 16:
		for y in 16:
			if Candles.pixel(Candles.FIRST,x,y,Color(0.5,0.5,0.5)) != Color(0.5,0.5,0.5): varied = true
	suite.check(varied and Nodes.tile(Candles.FIRST,0) != 0,"candles draw their own tile with a flame above the body")
	# The lit run begins at `FIRST + MAX_COUNT`; the flame is drawn over the candle's
	# own column and the body below it is opaque for both forms.
	var lit_single: int = Candles.FIRST+Candles.MAX_COUNT
	var lit_flame: Color = Candles.pixel(lit_single,7,2,Color(0.5,0.5,0.5))
	var unlit_flame: Color = Candles.pixel(Candles.FIRST,7,2,Color(0.5,0.5,0.5))
	var body: Color = Candles.pixel(Candles.FIRST,7,8,Color(0.5,0.5,0.5))
	suite.check(not Candles.is_lit(lit_single) == false and lit_flame.a > 0.0 and unlit_flame.a == 0.0 and body.a > 0.0,"a lit candle draws a flame where an unlit one is empty, over an opaque body")
