class_name Inventory
extends RefCounted

signal changed
var slots: Array = []
var selected: int = 0
var recipes: Array = []
var grid: Array = []

func _init() -> void:
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
	_recipe("Stone bricks", Nodes.BRICKS, 4, [3,3,3,3], 2)
	_recipe("Bread", Nodes.BREAD, 1, [71,71,71,0,0,0,0,0,0], 3, "table")
	_recipe("Bed", Nodes.BED, 1, [75,75,75,8,8,8,0,0,0], 3, "table")
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
	_recipe("Paper", Nodes.PAPER, 3, [Nodes.SUGAR], 1)
	_recipe("Book", Nodes.BOOK, 1, [Nodes.PAPER,Nodes.PAPER,Nodes.PAPER,Nodes.LEATHER], 2)
	_recipe("Bricks", Nodes.BRICK_ITEM, 4, [Nodes.CLAY_BALL,Nodes.CLAY_BALL,Nodes.CLAY_BALL,Nodes.CLAY_BALL], 2)
	_recipe("Pumpkin pie", Nodes.PUMPKIN_PIE, 1, [Nodes.PUMPKIN,Nodes.SUGAR,Nodes.GRAIN,0,0,0,0,0,0], 3, "table")
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

func _recipe(label: String, id: int, count: int, pattern: Array, width: int, station: String = "hand") -> void:
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

func count_item(id: int) -> int:
	var n: int = 0
	for slot in slots:
		if slot.id == id: n += slot.count
	return n

# Return leftover quantity: callers can leave a physical drop if the bag is full.
func add_item(id: int, amount: int = 1, wear: int = 0) -> int:
	if id == 0 or amount <= 0: return 0
	for pass_index in 2:
		for slot in slots:
			if (pass_index == 0 and slot.id == id and slot.wear == wear) or (pass_index == 1 and slot.id == 0):
				var moved: int = mini(amount, Nodes.max_stack(id) - int(slot.count))
				if moved <= 0: continue
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
	if count_item(id) < amount: return false
	for slot in slots:
		if slot.id != id: continue
		var taken: int = mini(amount, int(slot.count))
		slot.count -= taken
		amount -= taken
		if slot.count == 0: slot.id = 0; slot.wear = 0
		if amount == 0: break
	changed.emit()
	return true

func consume_selected(amount: int = 1) -> void:
	var slot: Dictionary = held()
	slot.count = maxi(0, slot.count - amount)
	if slot.count == 0: slot.id = 0; slot.wear = 0
	changed.emit()

func damage_tool() -> bool:
	var slot: Dictionary = held()
	if not Nodes.is_tool_id(slot.id): return false
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
	return true

func craft(index: int, station: String) -> bool:
	var recipe: Dictionary = recipes[index]
	if not can_craft(recipe, station): return false
	var before: Array = slots.duplicate(true)
	for id in recipe.ingredients: remove_item(id, recipe.ingredients[id])
	if add_item(recipe.id, recipe.count) > 0:
		slots = before
		changed.emit()
		return false
	return true

static func clean_slot(slot) -> Dictionary:
	if not slot is Dictionary: return {"id":0,"count":0,"wear":0}
	var id: int = Nodes.migrate(int(slot.get("id", 0)))
	if not Nodes.exists(id) or id == Nodes.AIR: return {"id":0,"count":0,"wear":0}
	var result: Dictionary = {"id":id, "count":clampi(int(slot.get("count",0)), 0, Nodes.max_stack(id)), "wear":maxi(0,int(slot.get("wear",0)))}
	if result.count == 0: result.id = 0; result.wear = 0
	return result

func restore(data: Array) -> void:
	for i in mini(data.size(), slots.size()):
		if not data[i] is Dictionary: continue
		slots[i] = clean_slot(data[i])
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
		cells.append(int(grid[i].id))
	var normalized: Dictionary = _normalized_pattern(cells,3)
	if normalized.is_empty(): return -1
	for i in recipes.size():
		var recipe: Dictionary = recipes[i]
		if recipe.station == "table" and station != "table": continue
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
	for slot in grid:
		if slot.id == 0: continue
		slot.count -= 1
		if slot.count == 0: slot.id = 0; slot.wear = 0
	changed.emit()
	return {"id":recipes[index].id,"count":recipes[index].count,"wear":0}

func grid_to_inventory() -> Array:
	var overflow: Array = []
	for slot in grid:
		if slot.id == 0: continue
		var rest: int = add_item(slot.id,slot.count,slot.wear)
		if rest > 0: overflow.append({"id":slot.id,"count":rest,"wear":slot.wear})
		slot.id = 0; slot.count = 0; slot.wear = 0
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
	for id in recipe.ingredients: amount = mini(amount,count_item(id)/int(recipe.ingredients[id]))
	for i in recipe.pattern.size():
		var id: int = recipe.pattern[i]
		if id == 0: continue
		var destination: int = i%int(recipe.width)+(i/int(recipe.width))*3
		remove_item(id,amount)
		grid[destination] = {"id":id,"count":amount,"wear":0}
	changed.emit()
	return true

func craft_grid_to_inventory(station: String) -> bool:
	var before_slots: Array = slots.duplicate(true)
	var before_grid: Array = grid.duplicate(true)
	var result: Dictionary = take_grid_result(station)
	if result.is_empty(): return false
	if add_item(result.id,result.count) > 0:
		slots = before_slots; grid = before_grid; changed.emit(); return false
	return true
