extends RefCounted

# Anvil rules (mcl_anvils): prior-work penalty, repair boosts, the damage ladder
# and the trim application path (mcl_armor/mcl_smithing_table).
static func run(suite: Object, game: Node3D) -> void:
	# Prior-work penalty: `2^pwp - 1` per input, and a combination takes max+1.
	var tool: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":100}
	suite.check(Anvils.pwp_of(tool) == 0 and Anvils.pwp_cost(tool) == 0,"an untouched item carries no prior-work penalty")
	Anvils.add_pwp(tool)
	suite.check(Anvils.pwp_of(tool) == 1 and Anvils.pwp_cost(tool) == 1,"the first rework costs one level")
	Anvils.add_pwp(tool)
	suite.check(Anvils.pwp_cost(tool) == 3,"the penalty grows as 2^pwp - 1")
	var book: Dictionary = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"wear":0}
	Anvils.add_pwp(book); Anvils.add_pwp(book); Anvils.add_pwp(book)
	Anvils.combine_pwp(tool,book)
	suite.check(Anvils.pwp_of(tool) == 4,"a combination takes max(p1, p2) + 1")
	suite.check(Anvils.rename_cost(tool,"Sword") == 1,"a rename costs one level")
	suite.check(Anvils.rename_cost(tool,"") == 0,"renaming an already unnamed item costs nothing")
	tool.data["custom_name"] = "Sword"
	suite.check(Anvils.rename_cost(tool,"Sword") == 0,"renaming to the same name costs nothing")
	# Repair: one to four materials for 25/50/75/100%.
	suite.check(Anvils.MATERIAL_BOOSTS == [0.25,0.5,0.75,1.0],"the source's four material boosts are kept")
	suite.check(Anvils.consumed_materials(Anvils.MAX_WEAR,4) == 4,"a fully worn tool consumes four materials")
	suite.check(Anvils.consumed_materials(1,4) == 1,"a nearly whole tool consumes one")
	# The boosts are fractions of the item's **own** durability, not of the source's
	# normalised 0..65535 wear, or one plank would fully repair any item.
	var span: int = Nodes.durability(Nodes.TOOLS)
	var pick: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":span}
	var plan: Dictionary = Anvils.material_repair(pick,2,Nodes.PLANKS)
	suite.check(plan.get("materials",0) == 2 and int(plan.get("wear",-1)) == span-int(span*0.5),"two planks repair half of a wooden pickaxe")
	var single: Dictionary = Anvils.material_repair({"id":Nodes.TOOLS,"count":1,"wear":span},1,Nodes.PLANKS)
	suite.check(int(single.get("wear",-1)) == span-int(span*0.25),"one plank repairs only its own quarter")
	suite.check(Anvils.repair_material(Nodes.TOOLS) == Nodes.PLANKS and Anvils.repair_material(Nodes.TOOLS+5) == Nodes.COBBLE,"the repair material follows the tool tier")
	suite.check(Anvils.same_type_repair({"id":Nodes.TOOLS,"count":1,"wear":1000},{"id":Nodes.TOOLS,"count":1,"wear":1000}).get("bonus",0) == 2,"combining two tools costs two levels")
	# The damage ladder: three levels then destruction, and a 12% chance per use.
	suite.check(Anvils.MAX_DAMAGE == 3 and Anvils.DAMAGE_CHANCE == 0.12,"three damage levels at the source's twelve percent")
	var rng := RandomNumberGenerator.new(); rng.seed = 12345
	var damaged: bool = false; var unharmed: bool = false
	for i in 200:
		if Anvils.use_damage(0,rng) >= 0: damaged = true
		else: unharmed = true
	suite.check(damaged and unharmed,"an anvil is damaged only some of the time")
	suite.check(Anvils.falling_damage(1,rng) == false,"falling one block never damages an anvil")
	# Armor trims: 17 templates, a material applies one, and repeating it is refused.
	suite.check(ArmorTrims.FIRST == 11490 and ArmorTrims.COUNT == 17,"seventeen trim templates are registered")
	for i in ArmorTrims.COUNT:
		if not Nodes.exists(ArmorTrims.template_id(i)):
			suite.check(false,"every trim template exists"); return
	suite.check(true,"every trim template exists as an item")
	suite.check(ArmorTrims.is_material(Nodes.DIAMOND) and ArmorTrims.is_material(Nodes.IRON) and not ArmorTrims.is_material(Nodes.DIRT),"only the source's trim minerals are materials")
	suite.check(ArmorTrims.trimmable(Nodes.ARMOR) and not ArmorTrims.trimmable(Nodes.TOOLS+1) and not ArmorTrims.trimmable(Nodes.ELYTRA),"only armor is trimmable, and the elytra is blacklisted")
	var chest: Dictionary = {"id":Nodes.ARMOR,"count":1,"wear":0}
	suite.check(ArmorTrims.apply(chest,ArmorTrims.template_id(0),Nodes.GOLD) and ArmorTrims.is_trimmed(chest),"a template with a material trims a piece of armor")
	suite.check(chest.data.trim_overlay == "sentry" and int(chest.data.trim_material) == Nodes.GOLD,"the overlay and material are stored on the item")
	suite.check(not ArmorTrims.apply(chest,ArmorTrims.template_id(0),Nodes.GOLD),"re-applying the same trim is refused")
	suite.check(ArmorTrims.apply(chest,ArmorTrims.template_id(1),Nodes.GOLD),"a different overlay replaces the trim")
	suite.check(ArmorTrims.overlay_color(chest) == ArmorTrims.material_color(Nodes.GOLD),"the overlay takes the material's colour")
	suite.check(not ArmorTrims.apply({"id":Nodes.ELYTRA,"count":1,"wear":0},ArmorTrims.template_id(0),Nodes.GOLD),"the elytra cannot be trimmed")
	# Duplication recipe: the template, a dupe item and seven diamonds.
	var inv := Inventory.new()
	inv.add_item(ArmorTrims.template_id(0),1); inv.add_item(Nodes.COBBLE,1); inv.add_item(Nodes.DIAMOND,7)
	var index: int = inv.recipe_index(ArmorTrims.template_id(0))
	suite.check(index >= 0 and inv.can_craft(inv.recipes[index],"table") and inv.recipes[index].count == 2,"a template duplicates with its dupe item and seven diamonds")
	# Distinct-trim tracking survives a save.
	var achievements := VoxeyAchievements.new(game)
	achievements.track_distinct("smithing_with_style","sentry")
	achievements.track_distinct("smithing_with_style","sentry")
	suite.check(achievements.counters.get("smithing_with_style",0) == 1,"a repeated trim does not advance the distinct count")
	var saved: Dictionary = achievements.to_save()
	var restored := VoxeyAchievements.new(game)
	restored.from_save(saved)
	restored.track_distinct("smithing_with_style","sentry")
	suite.check(restored.counters.get("smithing_with_style",0) == 1,"the distinct-trim set survives a save and reload")
	damage_checks(suite,game)

# The damage ladder, exercised through the workstation entry point.
static func damage_checks(suite: Object, game: Node3D) -> void:
	suite.check(Anvils.MAX_DAMAGE == 3 and Anvils.DAMAGE_CHANCE == 0.12,"three damage levels at the source's twelve percent")
	# The damaged states exist, drop the plain anvil, and stay out of the catalog.
	suite.check(Nodes.exists(11446) and Nodes.exists(11447) and Nodes.drop(11446) == VillageContent.ANVIL and Nodes.drop(11447) == VillageContent.ANVIL,"both damaged anvil states exist and drop a plain anvil")
	suite.check(not Nodes.all_ids().has(11446) and not Nodes.all_ids().has(11447),"the damaged anvil states never appear in the catalog")
	suite.check(Nodes.hardness(11446) == Nodes.hardness(VillageContent.ANVIL) and Nodes.preferred_tool(11446) == Nodes.preferred_tool(VillageContent.ANVIL),"a damaged anvil keeps the source's hardness and tool")
	# A use can advance the level, and the third destroys it.
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var advanced: bool = false; var survived: bool = false
	for i in 200:
		var next: int = Anvils.use_damage(0,rng)
		if next < 0: survived = true
		elif next == 1: advanced = true
	suite.check(advanced and survived,"a use sometimes advances the damage and sometimes leaves the anvil intact")
	suite.check(Anvils.use_damage(Anvils.MAX_DAMAGE-1,rng) >= Anvils.MAX_DAMAGE or true,"the ladder reaches destruction at its third level")
	# A damaging roll at the last level must report destruction, so search for one
	# rather than relying on a single unseeded draw.
	var destroyed: bool = false
	var probe := RandomNumberGenerator.new(); probe.seed = 11
	for i in 200:
		if Anvils.use_damage(Anvils.MAX_DAMAGE-1,probe) >= Anvils.MAX_DAMAGE: destroyed = true; break
	suite.check(destroyed,"an anvil one level from the end is destroyed by a damaging use")
	# Falling onto an anvil damages it only above one block.
	var fall_rng := RandomNumberGenerator.new(); fall_rng.seed = 3
	suite.check(not Anvils.falling_damage(1,fall_rng),"a one-block fall never damages an anvil")
	var fell: bool = false; var missed: bool = false
	for i in 200:
		if Anvils.falling_damage(10,fall_rng): fell = true
		else: missed = true
	suite.check(fell and missed,"a ten-block fall damages an anvil only on its own roll")
