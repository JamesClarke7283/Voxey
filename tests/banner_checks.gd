extends RefCounted

# Focused regression for banner emblazoning. The reference keeps an ordered list
# of layers in the banner's metadata, builds its description from that list, and
# lets a banner absorb another banner's layers. The pattern table is the source's
# own 42 entries: 32 dye-grid patterns and 10 special ones with their own item.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"

	# --- the pattern table -------------------------------------------------
	t.check(Banners.PATTERNS.size() == 42 and Banners.PATTERN_KEYS.size() == 42,"the source's 42 patterns are all present")
	var dye_grids: int = 0
	var specials: int = 0
	for key in Banners.PATTERNS:
		if Banners.is_special(key): specials += 1
		else: dye_grids += 1
	t.check(dye_grids == 32 and specials == 10,"the table has the source's 32 dye patterns and 10 special patterns")
	# Every dye pattern's grid is nine cells of dye or empty.
	var grids_ok: bool = true
	for key in Banners.PATTERNS:
		if Banners.is_special(key): continue
		var cells: Array = Banners.grid(key)
		if cells.size() != 9: grids_ok = false
		for cell in cells:
			if cell != Banners.DYE and cell != Banners.EMPTY: grids_ok = false
	t.check(grids_ok,"every dye pattern is a nine-cell grid of dye or empty")
	# The special patterns are exactly the source's ten.
	for key in ["thing","skull","creeper","flower","bricks","curly_border","globe","piglin","guster","flow"]:
		t.check(Banners.is_special(key),"the source's special pattern '%s' is registered"%key)
	# A few grids match the source's own transcription.
	t.check(Banners.grid("border") == ["d","d","d","d","e","d","d","d","d"],"the border pattern's ring matches the source grid")
	t.check(Banners.grid("circle") == ["e","e","e","e","d","e","e","e","e"],"the roundel's centre matches the source grid")
	t.check(Banners.grid("cross") == ["d","e","d","e","d","e","d","e","d"],"the saltire's diagonals match the source grid")
	t.check(Banners.grid("half_horizontal") == ["d","d","d","d","d","d","e","e","e"],"per fess matches the source grid")

	# --- colours and items -------------------------------------------------
	t.check(Banners.is_banner(VillageContent.BANNER_FIRST) and Banners.is_banner(VillageContent.BANNER_FIRST+15),"all sixteen banner colours are banners")
	t.check(not Banners.is_banner(VillageContent.BANNER_FIRST+16) and not Banners.is_banner(Nodes.WOOL),"the range stops after sixteen and wool is not a banner")
	t.check(Banners.color_index(VillageContent.BANNER_FIRST) == 0 and Banners.color_index(VillageContent.BANNER_FIRST+15) == 15,"banner colour indices resolve")
	# The ten pattern items are registered, in the source's own order.
	for i in Banners.ITEM_KEYS.size():
		t.check(Nodes.exists(VillageContent.PATTERN_FIRST+i),"pattern item %d is registered"%i)
	t.check(Banners.pending_pattern(VillageContent.PATTERN_FIRST) == "thing","the first pattern item selects the thing pattern")
	t.check(Banners.pending_pattern(VillageContent.PATTERN_FIRST+3) == "flower","the flower pattern item selects its own pattern")
	# A dye resolves to its banner colour index, and a non-dye does not.
	t.check(Banners.dye_color(VillageContent.DYE_WHITE) == 0,"white dye maps to banner colour zero")
	t.check(Banners.dye_color(VillageContent.DYE_WHITE+15) == 15,"the sixteenth dye maps to banner colour fifteen")
	t.check(Banners.dye_color(Nodes.IRON) < 0 and Banners.dye_color(Nodes.STICK) < 0,"ordinary items are not dyes")

	# --- layers ------------------------------------------------------------
	var banner: Dictionary = {"id":VillageContent.BANNER_RED-635+VillageContent.BANNER_FIRST,"count":1}
	t.check(Banners.layers(banner).is_empty(),"a fresh banner has no layers")
	t.check(Banners.emblazon(banner,"border",15),"a pattern can be applied to a fresh banner")
	t.check(Banners.layers(banner).size() == 1 and Banners.layers(banner)[0].pattern == "border","the applied layer is recorded with its pattern")
	t.check(int(Banners.layers(banner)[0].color) == 15,"the applied layer records the dye colour")
	t.check(Banners.describe(banner).contains("Bordure"),"the banner's description names its pattern")
	# A second layer appends on top rather than replacing.
	t.check(Banners.emblazon(banner,"circle",4),"a second pattern can be applied")
	t.check(Banners.layers(banner).size() == 2,"the banner now carries two layers")
	t.check(Banners.layers(banner)[1].pattern == "circle","the newest layer is the last one")
	t.check(Banners.describe(banner).contains("Roundel"),"the description lists the newer pattern too")
	# The source's layer limit is enforced.
	var many: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	for i in Banners.MAX_LAYERS: Banners.emblazon(many,"border",0)
	t.check(Banners.layers(many).size() == Banners.MAX_LAYERS,"a banner takes at most the source's layer limit")
	t.check(not Banners.emblazon(many,"circle",0),"a banner at its layer limit refuses another pattern")
	# An unknown pattern is refused.
	t.check(not Banners.emblazon(banner,"not_a_pattern",0),"an unknown pattern is refused")

	# --- combining ---------------------------------------------------------
	# A banner absorbs another's layers, appending them in order.
	var host: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	Banners.emblazon(host,"cross",1)
	var guest: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	Banners.emblazon(guest,"border",2)
	Banners.emblazon(guest,"circle",3)
	t.check(Banners.combine(host,guest),"a banner can absorb another's pattern layers")
	t.check(Banners.layers(host).size() == 3,"the combined banner carries both sets of layers")
	t.check(Banners.layers(host)[1].pattern == "border" and Banners.layers(host)[2].pattern == "circle","the absorbed layers keep their order")
	# Combining identical emblazoning does nothing, which the source also refuses.
	var twin: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	twin["data"] = {"layers":Banners.layers(host).duplicate(true)}
	t.check(not Banners.combine(host,twin),"combining an identical banner does nothing")
	# A plain banner contributes nothing.
	var plain: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	t.check(not Banners.combine(host,plain),"a banner with no layers adds nothing")

	# --- recipes -----------------------------------------------------------
	var inv := Inventory.new()
	# Every special pattern is craftable from paper plus its item.
	var craftable: int = 0
	for i in Banners.ITEM_KEYS.size():
		if inv.recipe_index(VillageContent.PATTERN_FIRST+i) >= 0: craftable += 1
	t.check(craftable == 10,"all ten special banner patterns are craftable")
	var thing_index: int = inv.recipe_index(VillageContent.PATTERN_FIRST)
	if thing_index >= 0:
		var recipe: Dictionary = inv.recipes[thing_index]
		t.check(recipe.shapeless and recipe.ingredients.get(Nodes.PAPER,0) == 1,"the pattern recipe is shapeless paper plus one item, as the source has it")
	# The signature items resolve to real Voxey items rather than zero.
	for key in ["bricks","curly_border","flower","creeper","skull"]:
		t.check(Banners.key_item(key) != 0,"the signature item for '%s' resolves to a real item"%key)

	# --- art ---------------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Banners.draw(art,VillageContent.BANNER_FIRST,0,[])
	var plain_pixels: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: plain_pixels += 1
	t.check(plain_pixels > 0,"a plain banner draws a non-empty icon")
	# An emblazoned banner's icon differs from the plain one, which is the point.
	var decorated := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Banners.draw(decorated,VillageContent.BANNER_FIRST,0,Banners.layers(host))
	var differs: bool = false
	for y in 16:
		for x in 16:
			if not art.get_pixel(x,y).is_equal_approx(decorated.get_pixel(x,y)): differs = true
	t.check(differs,"an emblazoned banner's icon differs from a plain one")
	# Two different patterns give different icons.
	var a := Image.create(16,16,false,Image.FORMAT_RGBA8)
	var b := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Banners.draw(a,VillageContent.BANNER_FIRST,0,[{"pattern":"border","color":15}])
	Banners.draw(b,VillageContent.BANNER_FIRST,0,[{"pattern":"circle","color":15}])
	var pattern_differs: bool = false
	for y in 16:
		for x in 16:
			if not a.get_pixel(x,y).is_equal_approx(b.get_pixel(x,y)): pattern_differs = true
	t.check(pattern_differs,"different patterns render differently")
