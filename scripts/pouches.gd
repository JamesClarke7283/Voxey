class_name Pouches
extends RefCounted

# Stable IDs retain the original single/double pouches as levels one/two.
const SINGLE = 1000
const DOUBLE = 1016
const MAX_LEVEL = 5

static func is_pouch(id: int) -> bool:
	return id >= SINGLE and id < SINGLE+16*MAX_LEVEL

static func level_of(id: int) -> int:
	return 1+(id-SINGLE)/16 if is_pouch(id) else 0

static func size_of(id: int) -> int:
	return 27*level_of(id)

static func contents(slot: Dictionary) -> Array:
	if not slot.has("data"): slot.data = {}
	if not slot.data.has("contents"): slot.data.contents = []
	while slot.data.contents.size() < size_of(slot.id): slot.data.contents.append({"id":0,"count":0,"wear":0})
	return slot.data.contents

# Upgrades retain both inputs. Refuse the craft before consuming either pouch
# if their combined cargo cannot fit after merging identical stacks.
static func output_data(id: int, ingredients: Array) -> Dictionary:
	if not is_pouch(id): return {}
	var result: Array = []
	for input in ingredients:
		if not is_pouch(input.id): continue
		for cargo in contents(input):
			if PortableStorage.contains_kind(cargo,false): return {"error":"Pouches cannot contain other pouches, including inside boxes."}
		if result.is_empty():
			result = contents(input).duplicate(true)
			while result.size() < size_of(id): result.append({"id":0,"count":0,"wear":0})
			continue
		for cargo in contents(input):
			if cargo.id == 0: continue
			var remaining: int = cargo.count
			for pass_index in 2:
				for target in result:
					if (pass_index == 0 and target.id == cargo.id and target.wear == cargo.wear and target.get("data",{}) == cargo.get("data",{})) or (pass_index == 1 and target.id == 0):
						var moved: int = mini(remaining,Nodes.max_stack(cargo.id)-int(target.count))
						Inventory.copy_data(target,cargo)
						target.id = cargo.id; target.wear = cargo.wear; target.count += moved; remaining -= moved
						if remaining == 0: break
				if remaining == 0: break
			if remaining > 0: return {"error":"Empty some cargo before combining these pouches."}
	return {"contents":result} if not result.is_empty() else {}

static func color_of_material(id: int) -> int:
	if id >= VillageContent.DYE_WHITE and id <= VillageContent.DYE_BROWN: return id-VillageContent.DYE_WHITE
	if id == Nodes.WOOL: return 0
	if id >= VillageContent.WOOL_WHITE and id <= VillageContent.WOOL_BROWN: return id-VillageContent.WOOL_WHITE
	return -1

static func special_recipe(cells: Array) -> Dictionary:
	var present: Array = []
	for slot in cells:
		if slot.id != 0: present.append(Nodes.migrate(slot.id))
	if present.size() != 2: return {}
	var source: int = present[0]; var material: int = present[1]
	var result: int = 0
	if is_pouch(source) and is_pouch(material):
		if level_of(source) != level_of(material) or level_of(source) >= MAX_LEVEL: return {}
		result = source+16
	else:
		if is_pouch(material) or (source >= VillageContent.DYE_WHITE and source <= VillageContent.DYE_BROWN):
			source = present[1]; material = present[0]
		var color: int = color_of_material(material)
		if color < 0: return {}
		if is_pouch(source): result = SINGLE+16*(level_of(source)-1)+color
		elif material >= VillageContent.DYE_WHITE and material <= VillageContent.DYE_BROWN and (source == Nodes.WOOL or source >= VillageContent.WOOL_WHITE and source <= VillageContent.WOOL_BROWN):
			result = Nodes.WOOL if color == 0 else VillageContent.WOOL_WHITE+color
	if result == 0: return {}
	var ingredients: Dictionary = {source:1}
	ingredients[material] = ingredients.get(material,0)+1
	return {"name":Nodes.title(result),"id":result,"count":1,"pattern":[source,material],"width":2,"ingredients":ingredients,"station":"hand","shapeless":true,"dynamic":true}

static func recipes(inv: Inventory) -> void:
	var thread: int = Nodes.STRING
	# Intentional Voxey recipes requested by the user: unpack any wool into
	# four string, then hand-craft the first pouch from those four string alone.
	inv._recipe("White pouch",SINGLE,1,[thread,thread,thread,thread],2)
	for color in 16:
		var wool: int = Nodes.WOOL if color == 0 else VillageContent.WOOL_WHITE+color
		inv._recipe("String from "+Nodes.title(wool).to_lower(),thread,4,[wool],1)
		if color != 0: inv._shapeless(Nodes.title(SINGLE+color),SINGLE+color,1,[SINGLE,VillageContent.DYE_WHITE+color])
		for level in range(1,MAX_LEVEL):
			var source: int = SINGLE+(level-1)*16+color
			inv._shapeless(Nodes.title(source+16),source+16,1,[source,source])
