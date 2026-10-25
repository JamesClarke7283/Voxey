extends SceneTree
var passed: int = 0
var failed: int = 0
var names: Dictionary = {}
class TestGame extends Node3D:
	var achievements: VoxeyAchievements
	var gamemode: String = "survival"
	func toast(_message: String) -> void: pass
	func sound(_name: String) -> void: pass
func _init() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 12: push_error(text)
func stack(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.has("name"): return Smithing.empty()
	var id: int = int(names.get(raw.name,0))
	var result: Dictionary = {"id":id,"count":int(raw.get("count",1)),"wear":0,"data":{"custom_name":str(raw.get("label","Remembered name")),"junk":"kept","pwp":3}}
	if raw.get("enchanted",false):
		var pair: Dictionary = Smithing.source.profiles.get(str(id),{})
		if pair.get("enchanted",{}).get("name","") != pair.get("base",{}).get("name",""): result.data.enchantments = {"Unbreaking":2,"Curse of Vanishing":1}
	if Nodes.durability(id) > 0: Durability.set_normalized(result,int(raw.get("wear",0)))
	else: result.wear = int(raw.get("wear",0))
	if raw.has("trim") and Smithing.profile(result).get("armor_texture",false):
		result.data.trim_overlay = raw.trim
		result.data.trim_material = int(names.get(raw.get("trim_material","mcl_core:gold_ingot"),0))
	return result
func snapshot(slot: Dictionary) -> Dictionary:
	var id: int = int(slot.id); var data: Dictionary = slot.get("data",{})
	var enchants: Dictionary = {}
	for title in data.get("enchantments",{}): enchants[str(Enchanting.source.definitions.get(title,{}).get("source_key",title))] = int(data.enchantments[title])
	return {"name":str(Smithing.profile(slot).get("name","")) if id else "","count":int(slot.count),"wear":Durability.normalized(slot) if Nodes.durability(id) > 0 else int(slot.wear),"label":str(data.get("custom_name","")),"junk":str(data.get("junk","")),"pwp":int(data.get("pwp",0)),"enchants":enchants,"trim":str(data.get("trim_overlay","")),"material":Smithing.item_name(int(data.get("trim_material",0)))}
func expected(raw: Dictionary) -> Dictionary:
	var r: Dictionary = raw.duplicate(true)
	r.count = int(r.count); r.wear = int(r.wear); r.pwp = int(r.pwp)
	if r.enchants == null: r.enchants = {}
	for key in r.enchants: r.enchants[key] = int(r.enchants[key])
	return r
func run() -> void:
	var inv := Inventory.new()
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/smithing_reference.json"))
	for id in ref.profiles: names[ref.profiles[id].base.name] = int(id)
	for name in ref.minerals:
		check(ArmorTrims.is_material(int(names[name])) and ArmorTrims.material_color(int(names[name])).is_equal_approx(Color(ref.minerals[name])),"Registered trim mineral color "+name)
	for name in ref.templates:
		var id: int = int(names[name]); var dupe: int = int(names.get(ref.templates[name].dupe_item,0))
		check(ArmorTrims.is_template(id) and Smithing.item_name(ArmorTrims.dupe_item(id)) == ref.templates[name].dupe_item,"Registered template duplication ingredient "+name)
		inv.grid = []
		for item in [Nodes.DIAMOND,id,Nodes.DIAMOND,Nodes.DIAMOND,dupe,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND]: inv.grid.append({"id":item,"count":1,"wear":0})
		var copied: Dictionary = inv.take_grid_result("table")
		check(int(copied.get("id",0)) == id and int(copied.get("count",0)) == 2,"Source template duplication recipe "+name)
	var game := TestGame.new()
	for row in ref.cases:
		var state: Dictionary = {"slots":[stack(row.a),stack(row.m),stack(row.t),Smithing.empty()]}
		Smithing.refresh(state)
		check(snapshot(state.slots[3]) == expected(row.preview),"Source preview "+str(row.a)+" / "+str(row.m)+" / "+str(row.t)+" got "+str(snapshot(state.slots[3]))+" expected "+str(row.preview))
		var taken: Dictionary = Smithing.take(state)
		for i in 4: check(snapshot(state.slots[i]) == expected(row.after[i]),"Source consumption / next preview: "+str(row.a)+" slot "+str(i))
		game.achievements = VoxeyAchievements.new(game); Smithing.award(game,taken.event)
		var awards: Array = []
		for id in game.achievements.unlocked: awards.append({"serious_dedication":"mcl:seriousDedication","crafting_a_new_look":"mcl:trim","smithing_with_style":"mcl:lots_of_trimming"}.get(id,id))
		check(awards == (row.awards if row.awards is Array else []),"Source smithing awards")
		var distinct: Dictionary = {}
		for key in game.achievements.distinct.get("smithing_with_style",{}): distinct["mcl_armor:"+key] = true
		check(distinct == (row.distinct if row.distinct is Dictionary else {}),"Source required trim set")
	var lists: Array = ["upgrade_item","mineral","template","upgraded_item"]
	for id in ref.profiles:
		if int(id) == 0: continue
		for variant in ["base","enchanted"]:
			var slot: Dictionary = {"id":int(id),"count":1,"wear":0}
			if variant == "enchanted": slot.data = {"enchantments":{"Unbreaking":1}}
			for i in 4: check(Smithing.accepts(i,slot) == bool(ref.profiles[id][variant].allowed[lists[i]]),"Source slot filter "+id+" "+variant+" "+lists[i])
	for row in ref.sorter:
		var id: int = int(names[row.name]); var state: Dictionary = {"slots":[Smithing.empty(),Smithing.empty(),Smithing.empty(),Smithing.empty()]}
		var slot: Dictionary = {"id":id,"count":Nodes.max_stack(id),"wear":0}
		check(Smithing.sorted_count(state,slot) == int(row.empty),"Source sorter accepts a full stack "+row.name+" native max "+str(slot.count)+" expected "+str(row.empty)+" got "+str(Smithing.sorted_count(state,slot)))
		if int(row.empty) > 0:
			var index: int = Smithing.sort_index(slot)
			check(lists[index] == row.target,"Source sorter destination")
			Smithing.quick_move(state,slot)
			var another: Dictionary = {"id":id,"count":Nodes.max_stack(id),"wear":0}
			check(Smithing.sorted_count(state,another) == int(row.blocked),"Source full destination rejects sorter insertion")
			state.slots[index].count -= 1
			if state.slots[index].count == 0: state.slots[index] = Smithing.empty()
			check(Smithing.sorted_count(state,another) == int(row.partial),"Source partial destination limits sorter count")
	for wood in WoodTypes.PLANKS:
		inv.grid = []
		for id in [Nodes.IRON,Nodes.IRON,0,wood,wood,0,wood,wood,0]: inv.grid.append({"id":id,"count":1 if id else 0,"wear":0})
		check(inv.take_grid_result("table").get("id",0) == VillageContent.SMITHING_TABLE,"Source table crafting uses any wood")
	check(Nodes.hardness(VillageContent.SMITHING_TABLE) == float(ref.node.hardness),"Source smithing hardness")
	check(ArmorTrims.is_material(Nodes.QUARTZ) and not ArmorTrims.is_material(Netherite.SCRAP),"Quartz is a trim material; Netherite scrap is not")
	game.free()
	print("SMITHING SOURCE: %d cases, %d profiles; %d passed, %d failed"%[ref.cases.size(),ref.profiles.size(),passed,failed])
	quit(1 if failed else 0)
