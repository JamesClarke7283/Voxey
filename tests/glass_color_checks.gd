extends RefCounted

# Stained glass and stained panes (mcl_core/nodes_glass.lua, mcl_panes/init.lua):
# sixteen colours each, made from plain glass and a dye, dropping nothing unless
# Silk Touch is used.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(GlassColors.FIRST == 11210 and GlassColors.PANE_FIRST == 11226 and GlassColors.COUNT == 16,"stained glass occupies sixteen block ids followed by sixteen pane ids")
	var all_ok: bool = true
	for i in GlassColors.COUNT:
		var glass: int = GlassColors.FIRST+i
		var pane: int = GlassColors.PANE_FIRST+i
		if not Nodes.exists(glass) or not Nodes.exists(pane): all_ok = false
		if not Nodes.placeable(glass) or not Nodes.placeable(pane): all_ok = false
		if not GlassColors.is_stained_glass(glass) or not GlassColors.is_stained_pane(pane): all_ok = false
		if GlassColors.is_stained(pane) != true or GlassColors.index(glass) != i: all_ok = false
		if GlassColors.pane_for(glass) != pane or GlassColors.glass_for(pane) != glass: all_ok = false
		if not Nodes.transparent(glass) or not Nodes.transparent(pane): all_ok = false
		if Nodes.hardness(glass) != 0.3 or Nodes.hardness(pane) != 0.3: all_ok = false
		if Nodes.preferred_tool(glass) != -1 or Nodes.preferred_tool(pane) != -1: all_ok = false
		if VillageContent.DATA[glass].dye != GlassColors.COLORS[i]: all_ok = false
	suite.check(all_ok,"all sixteen stained glasses and panes exist, pair by colour and are transparent at the source's hardness")
	suite.check(Nodes.solid(GlassColors.FIRST) and not Nodes.plant(GlassColors.PANE_FIRST),"stained glass blocks movement while a pane is a thin pane like the plain one")
	# The source's `drop = ""`: ordinary breaks yield nothing, Silk Touch yields the block.
	suite.check(Nodes.drop(GlassColors.FIRST) == 0 and Nodes.drop(GlassColors.PANE_FIRST) == 0,"stained glass drops nothing through the generic path")
	var plain: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0}
	suite.check(Enchantments.harvest(GlassColors.FIRST,plain).is_empty(),"an unenchanted pickaxe recovers no stained glass")
	var silk: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
	suite.check(Enchantments.harvest(GlassColors.FIRST,silk) == [[GlassColors.FIRST,1]] and Enchantments.harvest(GlassColors.PANE_FIRST,silk) == [[GlassColors.PANE_FIRST,1]],"Silk Touch returns the stained glass and its pane")
	game.gamemode = "survival"
	var at: Vector3i = Vector3i(6,game.world.generator.terrain_height(6,6)+3,6)
	game.world.set_node(at,GlassColors.FIRST+9)
	var before: int = game.drops.get_child_count()
	game.break_node(at,GlassColors.FIRST+9,0)
	suite.check(game.drops.get_child_count() == before and game.world.node_at(at) == Nodes.AIR,"breaking stained glass in survival leaves no drop")
	# Recipes: eight glass around a dye, and six of that glass into sixteen panes.
	var inv := Inventory.new()
	inv.add_item(Nodes.GLASS,8); inv.add_item(VillageContent.DYE_RED,1)
	var glass_index: int = inv.recipe_index(GlassColors.FIRST+6)
	suite.check(glass_index >= 0 and inv.can_craft(inv.recipes[glass_index],"table") and inv.recipes[glass_index].count == 8,"the source's eight-glass-and-a-dye recipe makes eight red stained glass")
	suite.check(inv.craft(glass_index,"table") and inv.count_item(GlassColors.FIRST+6) == 8,"crafting stained glass consumes the dye and yields the source's eight")
	inv = Inventory.new(); inv.add_item(GlassColors.FIRST+6,6)
	var pane_index: int = inv.recipe_index(GlassColors.PANE_FIRST+6)
	suite.check(pane_index >= 0 and inv.can_craft(inv.recipes[pane_index],"table") and inv.recipes[pane_index].count == 16,"six stained glass blocks make the source's sixteen panes")
	# Art must be translucent inside the frame rather than opaque.
	var frame: Color = GlassColors.pixel(GlassColors.FIRST,0,0,Color(0.5,0.5,0.5))
	# The interior is drawn below the terrain shader's 0.5 alpha-scissor threshold so
	# it is a real hole; the diagonal and highlight pixels over it stay solid, so the
	# interior is read from a cell that carries neither.
	var interior: Color = GlassColors.pixel(GlassColors.FIRST,2,9,Color(0.5,0.5,0.5))
	suite.check(frame.a >= 1.0 and interior.a > 0.0 and interior.a < 0.5,"stained glass draws a solid leading frame around a see-through interior")
	suite.check(Nodes.tile(GlassColors.FIRST,0) != 0 and Nodes.tile(GlassColors.PANE_FIRST,0) != 0,"stained glass and panes have their own atlas tiles")
	suite.check(not GlassColors.is_stained(GlassColors.FIRST-1) and not GlassColors.is_stained(GlassColors.PANE_FIRST+16),"the stained glass id range does not leak into neighbouring content")
