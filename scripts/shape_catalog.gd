class_name ShapeCatalog
extends RefCounted

# Loaded Mineclonia registrations; old native family IDs remain unchanged.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shapes.json"))
const NEW_FIRST = 14000
const NEW_END = 16000

static func new_family(id: int) -> int: return NEW_FIRST+(id-NEW_FIRST)/16*16
static func is_new(id: int) -> bool:
	return id >= NEW_FIRST and id < NEW_END and (id-NEW_FIRST)%16 <= 10 and data.families.has(str(new_family(id)))
static func profile(first: int) -> Dictionary: return data.families.get(str(first),{})
static func info(id: int) -> Dictionary:
	var row: Dictionary = profile(BuildingShapes.family(id))
	if row.is_empty(): return {}
	var state: int = BuildingShapes.variant(id)
	return row["stair" if state >= 3 else "double" if state == 2 else "top" if state == 1 else "slab"]
static func family_for(base: int) -> int: return int(data.by_material.get(str(base),0))
static func source_name(id: int) -> String: return str(info(id).get("name",""))
static func matches(source: String, id: int) -> bool:
	if id == 0: return false
	var name: String = ToolCapabilities.node_name(id)
	if source.begins_with("group:"):
		var node: Dictionary = ToolCapabilities.source.nodes.get(name,{})
		var groups: Variant = node.get("groups",{})
		return groups is Dictionary and int(groups.get(source.substr(6),0)) > 0
	return not name.is_empty() and Harvesting.canonical(name) == Harvesting.canonical(source)

static func recipes(inv: Inventory) -> void:
	var seen: Dictionary = {}
	for row in data.recipes:
		var width: int = int(row.width)
		var cells: Array = row.pattern.map(func(value): return int(value))
		var mirrored: Array = []
		if width > 0:
			for y in cells.size()/width:
				for x in range(width-1,-1,-1): mirrored.append(cells[y*width+x])
		var signature: String = str(row.id)+":"+str(width)+":"+(str(cells) if str(cells) < str(mirrored) else str(mirrored))
		if seen.has(signature): continue
		seen[signature] = true
		inv._recipe(BuildingShapes.title(int(row.id)),int(row.id),int(row.count),cells,maxi(2,width),"table" if width == 3 else "hand")
		var recipe: Dictionary = inv.recipes.back()
		recipe.source_items = row.source_items.duplicate()
		if width == 0: recipe.shapeless = true
