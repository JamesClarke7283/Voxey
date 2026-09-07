class_name Inventory
extends RefCounted

signal changed
const BASE_SLOTS = 36
const POUCH_SLOTS = 3
var slots: Array = []
var pouch_slots: Array = []
var selected: int = 0
var recipes: Array = []
var grid: Array = []
var dynamic_recipe: int = -1

func _init() -> void:
	changed.connect(sync_pouches)
	for i in POUCH_SLOTS: pouch_slots.append({"id":0,"count":0,"wear":0})
	for i in 36: slots.append({"id":0, "count":0, "wear":0})
	for i in 9: grid.append({"id":0, "count":0, "wear":0})
	_recipe("Oak planks", Nodes.PLANKS, 4, [Nodes.LOG], 1)
	_recipe("Sticks", Nodes.STICK, 4, [Nodes.PLANKS, 0, Nodes.PLANKS, 0], 2)
	_recipe("Crafting table", Nodes.WORKBENCH, 1, [8,8,8,8], 2)
	_recipe("Torches", Nodes.TORCH, 4, [65,0,64,0], 2)
	for tier in 4:
		var material: int = [Nodes.PLANKS, Nodes.COBBLE, Nodes.IRON, Nodes.DIAMOND][tier]
		var patterns: Array = [[material,material,material,0,64,0,0,64,0], [material,material,0,material,64,0,0,64,0], [0,material,0,0,64,0,0,64,0], [0,material,0,0,material,0,0,64,0], [material,material,0,0,64,0,0,64,0]]
		for kind in 5:
			var id: int = Nodes.TOOLS + tier * 5 + kind
			_recipe(Nodes.title(id), id, 1, patterns[kind], 3, "table")
	_recipe("Furnace", Nodes.FURNACE, 1, [9,9,9,9,0,9,9,9,9], 3, "table")
	_recipe("Chest", Nodes.CHEST, 1, [8,8,8,8,0,8,8,8,8], 3, "table")
	_recipe("Polished deepslate",Nodes.POLISHED_DEEPSLATE,4,[Nodes.COBBLED_DEEPSLATE,Nodes.COBBLED_DEEPSLATE,Nodes.COBBLED_DEEPSLATE,Nodes.COBBLED_DEEPSLATE],2)
	_recipe("Deepslate bricks",Nodes.DEEPSLATE_BRICKS,4,[Nodes.POLISHED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE],2)
	_recipe("Stone bricks", Nodes.BRICKS, 4, [3,3,3,3], 2)
	_recipe("Bread", Nodes.BREAD, 1, [71,71,71,0,0,0,0,0,0], 3, "table")
	_recipe("Bed", Nodes.BED_FOOT, 1, [75,75,75,8,8,8,0,0,0], 3, "table")
	_recipe("Wool", Nodes.WOOL, 1, [Nodes.STRING,Nodes.STRING,Nodes.STRING,Nodes.STRING], 2)
	_recipe("Bone meal", Nodes.BONE_MEAL, 3, [Nodes.BONE], 1)
	_recipe("TNT", Nodes.TNT, 1, [117,4,117,4,117,4,117,4,117], 3, "table")
	for pair in [[Nodes.GOLD,Nodes.GOLD_NODE],[Nodes.COPPER,Nodes.COPPER_NODE],[Nodes.IRON,Nodes.IRON_NODE],[Nodes.DIAMOND,Nodes.DIAMOND_NODE]]:
		_recipe(Nodes.title(pair[1]),pair[1],1,[pair[0],pair[0],pair[0],pair[0],pair[0],pair[0],pair[0],pair[0],pair[0]],3,"table")
		_recipe(Nodes.title(pair[0])+"s",pair[0],9,[pair[1]],1)
	# Armor follows the classic Mineclonia patterns for every material.
	for material in 4:
		var m: int = Nodes.ARMOR_INGREDIENT[material]
		var patterns: Array = [[m,m,m,m,0,m,0,0,0], [m,0,m,m,m,m,m,m,m], [m,m,m,m,0,m,m,0,m], [m,0,m,m,0,m,0,0,0]]
		for piece in 4:
			var id: int = Nodes.armor_id(material,piece)
			_recipe(Nodes.title(id), id, 1, patterns[piece], 3, "table")
	# Luanti/Mineclonia-style expansion items.
	_recipe("Shears", Nodes.SHEARS, 1, [0,Nodes.IRON,Nodes.IRON,0], 2)
	_recipe("Bucket", Nodes.BUCKET, 1, [Nodes.IRON,0,Nodes.IRON,0,Nodes.IRON,0], 2)
	_recipe("Sandstone", Nodes.SANDSTONE, 1, [Nodes.SAND,Nodes.SAND,Nodes.SAND,Nodes.SAND], 2)
	_recipe("Sandstone bricks", Nodes.SANDSTONE_BRICK, 4, [Nodes.SANDSTONE,Nodes.SANDSTONE,Nodes.SANDSTONE,Nodes.SANDSTONE], 2)
	_recipe("Snow block", Nodes.SNOW_BLOCK, 1, [Nodes.SNOWBALL,Nodes.SNOWBALL,Nodes.SNOWBALL,Nodes.SNOWBALL], 2)
	_recipe("Ladder", Nodes.LADDER, 3, [Nodes.STICK,0,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK,Nodes.STICK,0,Nodes.STICK], 3)
	_recipe("Bookshelf", Nodes.BOOKSHELF, 1, [Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,Nodes.BOOK,Nodes.BOOK,Nodes.BOOK,Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS], 3, "table")
	_recipe("Paper", Nodes.PAPER, 3, [Nodes.SUGAR_CANE,Nodes.SUGAR_CANE,Nodes.SUGAR_CANE], 3, "table")
	_shapeless("Book", Nodes.BOOK, 1, [Nodes.PAPER,Nodes.PAPER,Nodes.PAPER,Nodes.LEATHER])
	_shapeless("Writable book", Nodes.WRITABLE_BOOK, 1, [Nodes.BOOK,Nodes.FEATHER,Nodes.CHARCOAL])
	_recipe("Enchanting table",Nodes.ENCHANTING_TABLE,1,[0,Nodes.BOOK,0,Nodes.DIAMOND,Nodes.OBSIDIAN,Nodes.DIAMOND,Nodes.OBSIDIAN,Nodes.OBSIDIAN,Nodes.OBSIDIAN],3,"table")
	_recipe("Nether bricks",Nodes.NETHER_BRICKS,4,[Nodes.NETHERRACK,Nodes.NETHERRACK,Nodes.NETHERRACK,Nodes.NETHERRACK],2)
	_shapeless("Pumpkin pie", Nodes.PUMPKIN_PIE, 1, [Nodes.PUMPKIN,Nodes.SUGAR,Nodes.EGG])
	_recipe("Golden apple", Nodes.GOLDEN_APPLE, 1, [Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.APPLE,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD], 3, "table")
	_recipe("Bow", Nodes.BOW, 1, [0,Nodes.STICK,Nodes.STRING,Nodes.STICK,0,Nodes.STRING,0,Nodes.STICK,Nodes.STRING], 3, "table")
	_recipe("Arrows", Nodes.ARROW_ITEM, 4, [0,Nodes.FLINT,0,0,Nodes.STICK,0,0,Nodes.FEATHER,0], 3, "table")
	_recipe("Block of iron", Nodes.IRON_BLOCK, 1, [Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON], 3, "table")
	_recipe("Block of gold", Nodes.GOLD_BLOCK, 1, [Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD], 3, "table")
	_recipe("Block of diamond", Nodes.DIAMOND_BLOCK, 1, [Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND], 3, "table")
	_recipe("Iron ingots", Nodes.IRON, 9, [Nodes.IRON_BLOCK], 1)
	_recipe("Gold ingots", Nodes.GOLD, 9, [Nodes.GOLD_BLOCK], 1)
	_recipe("Diamonds", Nodes.DIAMOND, 9, [Nodes.DIAMOND_BLOCK], 1)
	_recipe("Glowstone", Nodes.GLOWSTONE, 1, [Nodes.COAL,Nodes.GOLD,Nodes.COAL,Nodes.GOLD,Nodes.COAL,Nodes.GOLD,Nodes.COAL,Nodes.GOLD,Nodes.COAL], 3, "table")
	_recipe("Flint and steel", Nodes.FLINT_AND_STEEL, 1, [Nodes.FLINT,0,0,0,Nodes.IRON], 2)
	_recipe("Charcoal torches", Nodes.TORCH, 4, [Nodes.CHARCOAL,Nodes.STICK], 1)
	_recipe("Sugar", Nodes.SUGAR, 1, [Nodes.SUGAR_CANE], 1)
	_recipe("Bowls", Nodes.BOWL, 4, [Nodes.PLANKS,0,Nodes.PLANKS,0,Nodes.PLANKS,0], 3, "table")
	_shapeless("Mushroom stew", Nodes.MUSHROOM_STEW, 1, [Nodes.BOWL,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM])
	_shapeless("Mossy cobblestone", Nodes.MOSSY_COBBLE, 1, [Nodes.COBBLE,Nodes.VINE])
	_shapeless("Mossy stone bricks", Nodes.MOSSY_BRICKS, 1, [Nodes.BRICKS,Nodes.VINE])
	_recipe("Red bricks", Nodes.RED_BRICKS, 1, [Nodes.BRICK_ITEM,Nodes.BRICK_ITEM,Nodes.BRICK_ITEM,Nodes.BRICK_ITEM], 2)
	_recipe("Clay", Nodes.CLAY, 1, [Nodes.CLAY_BALL,Nodes.CLAY_BALL,Nodes.CLAY_BALL,Nodes.CLAY_BALL], 2)
	for pair in [[Nodes.GRAIN,Nodes.HAY_BALE],[Nodes.COAL,Nodes.COAL_BLOCK],[Nodes.GOLD_NUGGET,Nodes.GOLD],[Nodes.IRON_NUGGET,Nodes.IRON]]:
		var square: Array = []; square.resize(9); square.fill(pair[0])
		_recipe(Nodes.title(pair[1]),pair[1],1,square,3,"table")
		_recipe(Nodes.title(pair[0])+" (unpack)",pair[0],9,[pair[1]],1)

	# Redstone components and the Nether-to-End survival chain.
	_recipe("Redstone torch",Nodes.REDSTONE_TORCH,1,[Nodes.REDSTONE_WIRE,Nodes.STICK],1)
	_recipe("Lever",Nodes.LEVER,1,[Nodes.STICK,Nodes.COBBLE],1)
	_recipe("Stone button",Nodes.BUTTON,1,[Nodes.STONE],1)
	_recipe("Pressure plate",Nodes.PRESSURE_PLATE,1,[Nodes.STONE,Nodes.STONE],2)
	_recipe("Repeater",Nodes.REPEATER,1,[Nodes.REDSTONE_TORCH,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_TORCH,Nodes.STONE,Nodes.STONE,Nodes.STONE],3,"table")
	_recipe("Comparator",Nodes.COMPARATOR,1,[0,Nodes.REDSTONE_TORCH,0,Nodes.REDSTONE_TORCH,Nodes.QUARTZ,Nodes.REDSTONE_TORCH,Nodes.STONE,Nodes.STONE,Nodes.STONE],3,"table")
	_recipe("Piston",Nodes.PISTON,1,[Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,Nodes.COBBLE,Nodes.IRON,Nodes.COBBLE,Nodes.COBBLE,Nodes.REDSTONE_WIRE,Nodes.COBBLE],3,"table")
	_recipe("Sticky piston",Nodes.STICKY_PISTON,1,[Nodes.SLIME_BALL,Nodes.PISTON],1)
	_recipe("Redstone lamp",Nodes.REDSTONE_LAMP,1,[0,Nodes.REDSTONE_WIRE,0,Nodes.REDSTONE_WIRE,Nodes.GLOWSTONE,Nodes.REDSTONE_WIRE,0,Nodes.REDSTONE_WIRE,0],3,"table")
	_recipe("Observer",Nodes.OBSERVER,1,[Nodes.COBBLE,Nodes.COBBLE,Nodes.COBBLE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.QUARTZ,Nodes.COBBLE,Nodes.COBBLE,Nodes.COBBLE],3,"table")
	for device in [Nodes.DISPENSER,Nodes.DROPPER]:
		_recipe(Nodes.title(device),device,1,[Nodes.COBBLE,Nodes.COBBLE,Nodes.COBBLE,Nodes.COBBLE,Nodes.BOW if device == Nodes.DISPENSER else 0,Nodes.COBBLE,Nodes.COBBLE,Nodes.REDSTONE_WIRE,Nodes.COBBLE],3,"table")
	_recipe("Hopper",Nodes.HOPPER,1,[Nodes.IRON,0,Nodes.IRON,Nodes.IRON,Nodes.CHEST,Nodes.IRON,0,Nodes.IRON,0],3,"table")
	_recipe("Iron door",Nodes.IRON_DOOR,3,[Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON],2,"table")
	_recipe("Iron bars",Nodes.IRON_BARS,16,[Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON],3,"table")
	_recipe("Redstone block",Nodes.REDSTONE_BLOCK,1,[Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE,Nodes.REDSTONE_WIRE],3,"table")
	_recipe("Redstone dust",Nodes.REDSTONE_WIRE,9,[Nodes.REDSTONE_BLOCK],1)
	_recipe("Blaze powder",Nodes.BLAZE_POWDER,2,[Nodes.BLAZE_ROD],1)
	_shapeless("Eye of Ender",Nodes.ENDER_EYE,1,[Nodes.ENDER_PEARL,Nodes.BLAZE_POWDER])
	_shapeless("Magma cream",Nodes.MAGMA_CREAM,1,[Nodes.SLIME_BALL,Nodes.BLAZE_POWDER])
	_recipe("Nether bricks",Nodes.NETHER_BRICKS,1,[Nodes.NETHER_BRICK_ITEM,Nodes.NETHER_BRICK_ITEM,Nodes.NETHER_BRICK_ITEM,Nodes.NETHER_BRICK_ITEM],2)
	_recipe("End crystal",Nodes.END_CRYSTAL,1,[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.ENDER_EYE,Nodes.GLASS,Nodes.GLASS,Nodes.GHAST_TEAR,Nodes.GLASS],3,"table")
	_recipe("End stone bricks",Nodes.END_BRICKS,4,[Nodes.END_STONE,Nodes.END_STONE,Nodes.END_STONE,Nodes.END_STONE],2)
	_recipe("Purpur",Nodes.PURPUR,4,[Nodes.CHORUS_FRUIT,Nodes.CHORUS_FRUIT,Nodes.CHORUS_FRUIT,Nodes.CHORUS_FRUIT],2)
	_recipe("End rods",Nodes.END_ROD,4,[Nodes.BLAZE_ROD,Nodes.CHORUS_FRUIT],1)

	VillageContent.recipes(self)
	PotionCatalog.recipes(self)
	Pouches.recipes(self)

func _shapeless(label: String, id: int, count: int, ingredients: Array) -> void:
	_recipe(label,id,count,ingredients,2)
	recipes.back()["shapeless"] = true

func _recipe(label: String, id: int, count: int, pattern: Array, width: int, station: String = "hand") -> void:
	id = Nodes.migrate(id)
	pattern = pattern.map(func(item): return Nodes.migrate(int(item)))
	var ingredients: Dictionary = {}
	for item in pattern:
		if item: ingredients[item] = ingredients.get(item, 0) + 1
	recipes.append({"name":label, "id":id, "count":count, "pattern":pattern, "width":width, "ingredients":ingredients, "station":station})

func recipe_index(id: int) -> int:
	for i in recipes.size():
		if recipes[i].id == id: return i
	return -1

func held() -> Dictionary:
	return slots[selected]

# The flat inventory shares its cargo dictionaries with the equipped pouches.
# Sync also handles transactions which replace the entire flat array.
func sync_pouches() -> void:
	var offset: int = BASE_SLOTS
	for pouch in pouch_slots:
		if not Pouches.is_pouch(pouch.id): continue
		var cargo: Array = Pouches.contents(pouch)
		for i in cargo.size():
			if offset+i < slots.size(): cargo[i] = slots[offset+i]
		offset += cargo.size()

func rebuild_pouches() -> void:
	slots = slots.slice(0,BASE_SLOTS)
	for pouch in pouch_slots:
		if Pouches.is_pouch(pouch.id): slots.append_array(Pouches.contents(pouch))
	changed.emit()

func exchange_pouch(index: int, incoming: Dictionary) -> Dictionary:
	if index < 0 or index >= POUCH_SLOTS or (incoming.id != 0 and (not Pouches.is_pouch(incoming.id) or incoming.count != 1)): return incoming
	sync_pouches()
	var previous: Dictionary = pouch_slots[index]
	pouch_slots[index] = incoming.duplicate(true)
	rebuild_pouches()
	return previous

func pouch_offset(index: int) -> int:
	var offset: int = BASE_SLOTS
	for i in index: offset += Pouches.size_of(pouch_slots[i].id)
	return offset

func page_count() -> int:
	return maxi(1,ceili((slots.size()-9)/27.0))

func page_indices(page: int) -> Array:
	var result: Array = range(9)
	for i in 27:
		var index: int = 9+27*clampi(page,0,page_count()-1)+i
		result.append(index if index < slots.size() else -1)
	return result

func count_item(id: int) -> int:
	id = Nodes.migrate(id)
	var n: int = 0
	for slot in slots:
		if Nodes.migrate(slot.id) == id: n += slot.count
	return n

# Return leftover quantity: callers can leave a physical drop if the bag is full.
func capacity(id: int, wear: int = 0, data: Dictionary = {}) -> int:
	id = Nodes.migrate(id)
	var available: int = 0
	for i in slots.size():
		if i >= BASE_SLOTS and Pouches.is_pouch(id): continue
		var slot: Dictionary = slots[i]
		if slot.id == 0: available += Nodes.max_stack(id)
		elif Nodes.migrate(slot.id) == id and slot.wear == wear and slot.get("data",{}) == data: available += Nodes.max_stack(id)-int(slot.count)
	return available

static func copy_data(to: Dictionary, source: Dictionary) -> void:
	to.erase("data")
	if source.id != 0 and not source.get("data",{}).is_empty(): to["data"] = source.data.duplicate(true)

static func enchantment(slot: Dictionary, kind: String) -> int:
	return int(slot.get("data",{}).get("enchantments",{}).get(kind,0)) if slot.id != 0 else 0

func add_item(id: int, amount: int = 1, wear: int = 0, data: Dictionary = {}, exclude_start: int = -1, exclude_end: int = -1) -> int:
	id = Nodes.migrate(id)
	if id == 0 or amount <= 0: return 0
	for pass_index in 2:
		for i in slots.size():
			if (i >= BASE_SLOTS and Pouches.is_pouch(id)) or (i >= exclude_start and i < exclude_end): continue
			var slot: Dictionary = slots[i]
			if (pass_index == 0 and Nodes.migrate(slot.id) == id and slot.wear == wear and slot.get("data",{}) == data) or (pass_index == 1 and slot.id == 0):
				var moved: int = mini(amount, Nodes.max_stack(id) - int(slot.count))
				if moved <= 0: continue
				copy_data(slot,{"id":id,"data":data})
				slot.id = id
				slot.wear = wear
				slot.count += moved
				amount -= moved
				if amount == 0:
					changed.emit()
					return 0
	changed.emit()
	return amount

func remove_item(id: int, amount: int = 1) -> bool:
	id = Nodes.migrate(id)
	if count_item(id) < amount: return false
	for slot in slots:
		if Nodes.migrate(slot.id) != id: continue
		var taken: int = mini(amount, int(slot.count))
		slot.count -= taken
		amount -= taken
		if slot.count == 0: slot.id = 0; slot.wear = 0; slot.erase("data")
		if amount == 0: break
	changed.emit()
	return true

func consume_selected(amount: int = 1) -> void:
	var slot: Dictionary = held()
	slot.count = maxi(0, slot.count - amount)
	if slot.count == 0: slot.id = 0; slot.wear = 0; slot.erase("data")
	changed.emit()

func damage_tool() -> bool:
	var slot: Dictionary = held()
	if Nodes.durability(slot.id) <= 0: return false
	if randf() < float(enchantment(slot,"Unbreaking"))/(enchantment(slot,"Unbreaking")+1.0): return false
	slot.wear += 1
	if slot.wear >= Nodes.durability(slot.id):
		consume_selected()
		return true
	changed.emit()
	return false

func can_craft(recipe: Dictionary, station: String) -> bool:
	if recipe.station == "table" and station != "table": return false
	for id in recipe.ingredients:
		if count_item(id) < recipe.ingredients[id]: return false
	return not Pouches.output_data(recipe.id,recipe_inputs(recipe)).has("error")

func recipe_inputs(recipe: Dictionary) -> Array:
	var needed: Dictionary = recipe.ingredients.duplicate()
	var inputs: Array = []
	for slot in slots:
		var amount: int = mini(slot.count,needed.get(slot.id,0))
		if amount <= 0: continue
		var ingredient: Dictionary = slot.duplicate(true)
		ingredient.count = amount
		inputs.append(ingredient)
		needed[slot.id] -= amount
	return inputs

func craft(index: int, station: String) -> bool:
	var recipe: Dictionary = recipes[index]
	if not can_craft(recipe, station): return false
	var before: Array = slots.duplicate(true)
	var output_data: Dictionary = Pouches.output_data(recipe.id,recipe_inputs(recipe))
	for id in recipe.ingredients: remove_item(id, recipe.ingredients[id])
	var leftovers: int = add_item(recipe.id, recipe.count,0,output_data)
	if recipe.ingredients.has(Nodes.MILK_BUCKET): leftovers += add_item(Nodes.BUCKET,recipe.ingredients[Nodes.MILK_BUCKET])
	if leftovers > 0:
		slots = before
		changed.emit()
		return false
	return true

static func clean_slot(slot, allow_pouches: bool = true) -> Dictionary:
	if not slot is Dictionary: return {"id":0,"count":0,"wear":0}
	var id: int = Nodes.migrate(int(slot.get("id", 0)))
	if not Nodes.exists(id) or id == Nodes.AIR or (not allow_pouches and Pouches.is_pouch(id)): return {"id":0,"count":0,"wear":0}
	var result: Dictionary = {"id":id, "count":clampi(int(slot.get("count",0)), 0, Nodes.max_stack(id)), "wear":maxi(0,int(slot.get("wear",0)))}
	if slot.get("data") is Dictionary and result.count > 0:
		var raw: Dictionary = slot.data
		var metadata: Dictionary = {}
		if Pouches.is_pouch(id) and raw.get("contents") is Array:
			var clean: Array = []
			for i in mini(Pouches.size_of(id),raw.contents.size()): clean.append(clean_slot(raw.contents[i],false))
			metadata["contents"] = clean
		if id in [Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK]:
			metadata["title"] = str(raw.get("title","Untitled")).left(64)
			metadata["text"] = str(raw.get("text","")).left(12000)
		if result.id == VillageContent.CROSSBOW and Nodes.exists(int(raw.get("loaded_arrow",0))):
			var arrow: int = int(raw.loaded_arrow)
			if arrow == Nodes.ARROW_ITEM or VillageContent.DATA.get(arrow,{}).get("family","") == "arrow":
				metadata["loaded_arrow"] = arrow
				metadata["charge"] = clampf(float(raw.get("charge",0)),0,1.25)
		if raw.get("enchantments") is Dictionary:
			var ench: Dictionary = Enchantments.clean(id,raw.enchantments)
			if not ench.is_empty(): metadata["enchantments"] = ench
		if not metadata.is_empty(): result["data"] = metadata
	if result.count == 0: result.id = 0; result.wear = 0
	return result

func restore(data: Array, equipped: Array = []) -> void:
	slots.clear(); pouch_slots.clear()
	for i in BASE_SLOTS: slots.append(clean_slot(data[i] if i < data.size() else {}))
	for i in POUCH_SLOTS:
		var pouch: Dictionary = clean_slot(equipped[i] if i < equipped.size() else {})
		pouch_slots.append(pouch if Pouches.is_pouch(pouch.id) else {"id":0,"count":0,"wear":0})
	rebuild_pouches()
	selected = clampi(selected, 0, 8)
	changed.emit()

# Patterns are normalized to their occupied rectangle. Recipes can be moved
# around the grid, and asymmetric tools accept the mirrored arrangement.
static func _normalized_pattern(cells: Array, width: int) -> Dictionary:
	var min_x: int = width
	var min_y: int = 3
	var max_x: int = -1
	var max_y: int = -1
	for i in cells.size():
		if int(cells[i]) == 0: continue
		min_x = mini(min_x,i%width); max_x = maxi(max_x,i%width)
		min_y = mini(min_y,i/width); max_y = maxi(max_y,i/width)
	if max_x < 0: return {}
	var result: Array = []
	for y in range(min_y,max_y+1):
		for x in range(min_x,max_x+1):
			var index: int = x+y*width
			result.append(int(cells[index]) if index<cells.size() else 0)
	return {"width":max_x-min_x+1,"height":max_y-min_y+1,"cells":result}

func matching_recipe(station: String) -> int:
	var cells: Array = []
	for i in grid.size():
		if station != "table" and (i%3>1 or i/3>1) and grid[i].id != 0: return -1
		cells.append(Nodes.migrate(int(grid[i].id)))
	var special: Dictionary = Pouches.special_recipe(grid)
	if not special.is_empty():
		if Pouches.output_data(special.id,grid).has("error"): return -1
		if dynamic_recipe < 0: dynamic_recipe = recipes.size(); recipes.append(special)
		else: recipes[dynamic_recipe] = special
		return dynamic_recipe
	var normalized: Dictionary = _normalized_pattern(cells,3)
	if normalized.is_empty(): return -1
	for i in recipes.size():
		var recipe: Dictionary = recipes[i]
		if recipe.get("dynamic",false): continue
		if recipe.station == "table" and station != "table": continue
		if recipe.get("shapeless",false):
			var present: Dictionary = {}
			for cell in cells:
				if cell: present[cell] = present.get(cell,0)+1
			if present == recipe.ingredients: return i
			continue
		var pattern: Dictionary = _normalized_pattern(recipe.pattern,recipe.width)
		if pattern.width != normalized.width or pattern.height != normalized.height: continue
		if pattern.cells == normalized.cells: return i
		var mirrored: Array = []
		for y in pattern.height:
			for x in range(pattern.width-1,-1,-1): mirrored.append(pattern.cells[x+y*pattern.width])
		if mirrored == normalized.cells: return i
	return -1

func take_grid_result(station: String) -> Dictionary:
	var index: int = matching_recipe(station)
	if index < 0: return {}
	var result: Dictionary = {"id":recipes[index].id,"count":recipes[index].count,"wear":0}
	var metadata: Dictionary = Pouches.output_data(result.id,grid)
	if metadata.has("error"): return {}
	if not metadata.is_empty(): result["data"] = metadata
	for slot in grid:
		if slot.id == 0: continue
		slot.count -= 1
		if slot.count == 0:
			if slot.id == Nodes.MILK_BUCKET: slot.id = Nodes.BUCKET; slot.count = 1
			else: slot.id = 0; slot.wear = 0; slot.erase("data")
	changed.emit()
	return result

func grid_to_inventory() -> Array:
	var overflow: Array = []
	for slot in grid:
		if slot.id == 0: continue
		var rest: int = add_item(slot.id,slot.count,slot.wear,slot.get("data",{}))
		if rest > 0: overflow.append({"id":slot.id,"count":rest,"wear":slot.wear,"data":slot.get("data",{}).duplicate(true)})
		slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
	changed.emit()
	return overflow

func fill_grid(index: int, station: String, all_available: bool = false) -> bool:
	var before_slots: Array = slots.duplicate(true)
	var before_grid: Array = grid.duplicate(true)
	var overflow: Array = grid_to_inventory()
	if not overflow.is_empty() or not can_craft(recipes[index],station):
		slots = before_slots; grid = before_grid; changed.emit(); return false
	var recipe: Dictionary = recipes[index]
	var amount: int = 64 if all_available else 1
	for id in recipe.ingredients: amount = mini(amount,mini(Nodes.max_stack(id),count_item(id)/int(recipe.ingredients[id])))
	for i in recipe.pattern.size():
		var id: int = recipe.pattern[i]
		if id == 0: continue
		var destination: int = i%int(recipe.width)+(i/int(recipe.width))*3
		var ingredient: Dictionary = {}
		for slot in slots:
			if slot.id == id and slot.count >= amount: ingredient = slot.duplicate(true); break
		if ingredient.is_empty(): ingredient = {"id":id,"count":amount,"wear":0}
		remove_item(id,amount)
		ingredient.count = amount
		grid[destination] = ingredient
	changed.emit()
	return true

func craft_grid_to_inventory(station: String) -> bool:
	var before_slots: Array = slots.duplicate(true)
	var before_grid: Array = grid.duplicate(true)
	var result: Dictionary = take_grid_result(station)
	if result.is_empty(): return false
	if add_item(result.id,result.count,result.wear,result.get("data",{})) > 0:
		slots = before_slots; grid = before_grid; changed.emit(); return false
	return true
