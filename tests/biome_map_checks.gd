extends RefCounted

# Pure behavior checks for the canonical registry. No terrain selector, live world,
# numeric biome IDs or mutable registry state is involved.
static func run(suite: Object, _game: Node3D) -> void:
	var required: Array = ["Taiga","OldGrowthPineTaiga","OldGrowthSpruceTaiga","MushroomIslands","BambooJungle","LushCaves"]
	suite.check(required.all(func(id): return BiomeMap.is_canonical(id) and BiomeMap.canonical(id) == id),"all audited plant biomes use exact canonical Mineclonia IDs")
	suite.check(BiomeMap.DEFINITIONS.size() == 64 and BiomeMap.canonical_ids().size() == 64,"the registry contains the checkout's 64 canonical registrations and no aliases as biomes")
	suite.check(required.all(func(id): return BiomeMap.DEFINITIONS[id].get("id") == null),"canonical string identities do not acquire invented numeric IDs")

	var aliases_ok: bool = true
	var aliases_separate: bool = false
	for alias in BiomeMap.ALIASES:
		aliases_ok = aliases_ok and BiomeMap.canonical(alias) == BiomeMap.ALIASES[alias] and BiomeMap.is_canonical(BiomeMap.ALIASES[alias])
		aliases_separate = aliases_separate or BiomeMap.DEFINITIONS.has(alias)
	suite.check(aliases_ok and not aliases_separate,"every declared legacy alias resolves to a real canonical registration only")
	var expected_aliases: Dictionary = {
		"MegaTaiga":"OldGrowthPineTaiga","MegaSpruceTaiga":"OldGrowthSpruceTaiga",
		"MushroomIsland":"MushroomIslands","MushroomIslandShore":"MushroomIslands",
		"LushCaves_underground":"LushCaves","LushCaves_ocean":"LushCaves",
		"BambooJungle_ocean":"BambooJungle","ColdTaiga":"SnowyTaiga",
	}
	suite.check(expected_aliases.keys().all(func(alias): return BiomeMap.canonical(alias) == expected_aliases[alias]),"all audited legacy and subtype spellings resolve exactly")
	suite.check(BiomeMap.canonical("Taiga_underground") == "Taiga" and BiomeMap.canonical("ExtremeHills+_deep_ocean") == "WindsweptHills","source subtype suffixes resolve through their canonical base biome")
	suite.check(BiomeMap.canonical("MushroomFields").is_empty() and BiomeMap.groups("not_a_biome").is_empty() and not BiomeMap.allows("Taiga","not_a_biome"),"modern guesses and unknown IDs never become implicit registrations")
	suite.check(BiomeMap.temperature("unknown") == null and BiomeMap.downfall("unknown") == null,"unknown climate queries have no fabricated defaults")

	suite.check(is_equal_approx(BiomeMap.temperature("Taiga"),0.25) and is_equal_approx(BiomeMap.downfall("Taiga"),0.8),"ordinary Taiga preserves source temperature and downfall")
	suite.check(is_equal_approx(BiomeMap.temperature("OldGrowthPineTaiga"),0.3) and is_equal_approx(BiomeMap.temperature("OldGrowthSpruceTaiga"),0.25),"the two old-growth taigas remain distinct registrations rather than Taiga aliases")
	suite.check(BiomeMap.canonical("OldGrowthPineTaiga") != BiomeMap.canonical("OldGrowthSpruceTaiga") and BiomeMap.canonical("Taiga") != BiomeMap.canonical("OldGrowthPineTaiga"),"ordinary, pine old-growth and spruce old-growth identities cannot collapse")
	suite.check(BiomeMap.allows("#is_taiga","Taiga") and BiomeMap.allows("is_taiga","MegaTaiga") and BiomeMap.allows("#is_taiga","ColdTaiga"),"bare and hash taiga groups include ordinary, old-growth and snowy taigas")
	suite.check(BiomeMap.allows("#has_village_taiga","Taiga") and BiomeMap.allows("#has_pillager_outpost","Taiga"),"ordinary Taiga keeps its village and outpost structure eligibility")
	suite.check(not BiomeMap.allows("#has_village_taiga","OldGrowthPineTaiga") and not BiomeMap.allows("#has_pillager_outpost","OldGrowthSpruceTaiga"),"old-growth taigas do not inherit ordinary Taiga's exact-ID structure filters")
	suite.check(BiomeMap.allows("#has_trail_ruins","Taiga") and BiomeMap.allows("#has_trail_ruins","OldGrowthPineTaiga") and BiomeMap.allows("#has_trail_ruins","OldGrowthSpruceTaiga") and BiomeMap.allows("#has_trail_ruins","SnowyTaiga"),"trail ruins include all four taiga registrations explicitly")
	suite.check(BiomeMap.allows("#has_igloo","SnowyTaiga") and not BiomeMap.allows("#has_igloo","Taiga"),"igloo filtering distinguishes snowy Taiga from ordinary Taiga")

	suite.check(BiomeMap.canonical("BambooJungle") != BiomeMap.canonical("Jungle") and BiomeMap.allows("#is_jungle","BambooJungle") and BiomeMap.allows("#is_jungle","Jungle"),"BambooJungle and Jungle share is_jungle without sharing identity")
	suite.check(BiomeMap.allows("#has_jungle_temple","BambooJungle") and BiomeMap.allows("#has_jungle_temple","Jungle") and not BiomeMap.allows("#has_jungle_temple","SparseJungle"),"the jungle temple list includes BambooJungle and Jungle but not SparseJungle")
	suite.check(BiomeMap.allows("#has_trail_ruins","Jungle") and not BiomeMap.allows("#has_trail_ruins","BambooJungle"),"trail ruins retain Jungle's exact-ID distinction from BambooJungle")
	suite.check(BiomeMap.allows("#has_ruined_portal_jungle","BambooJungle") and BiomeMap.allows("#has_ruined_portal_jungle","SparseJungle"),"the jungle ruined-portal variant follows the full is_jungle group")

	var lush: Dictionary = BiomeMap.definition("LushCaves")
	suite.check(BiomeMap.is_underground("LushCaves") and lush.get("depth") == [0.2,0.9] and lush.get("humidity") == [0.7,1.0],"LushCaves retains its underground 3D identity and source depth/humidity extents")
	suite.check(BiomeMap.is_underground("LushCaves_underground") and BiomeMap.is_underground("LushCaves_ocean") and not BiomeMap.is_underground("Taiga"),"legacy LushCaves layers resolve to the same underground biome, not a surface rename")
	suite.check(BiomeMap.allows("LushCaves","LushCaves_underground") and not BiomeMap.allows("LushCaves","DeepDark"),"exact underground biome filters distinguish LushCaves from DeepDark")
	suite.check(BiomeMap.allows("#has_mineshaft","LushCaves") and BiomeMap.allows("#has_ruined_portal_standard","LushCaves"),"LushCaves retains its explicit mineshaft and standard ruined-portal eligibility")

	suite.check(BiomeMap.DEFINITIONS.MushroomIslands.groups == ["is_overworld"] and is_equal_approx(BiomeMap.temperature("MushroomIslands"),0.9) and is_equal_approx(BiomeMap.downfall("MushroomIsland"),1.0),"MushroomIslands preserves its lone base group and climate values")
	suite.check(not BiomeMap.allows("#is_ocean","MushroomIslands") and not BiomeMap.allows("#is_river","MushroomIslands") and not BiomeMap.allows("#is_jungle","MushroomIslands") and not BiomeMap.allows("#is_taiga","MushroomIslands"),"MushroomIslands is not silently added to ocean, river, jungle or taiga groups")
	suite.check(not BiomeMap.allows("#has_pillager_outpost","MushroomIslands") and not BiomeMap.allows("#has_village_plains","MushroomIslands") and not BiomeMap.allows("#has_trail_ruins","MushroomIslands") and not BiomeMap.allows("#has_jungle_temple","MushroomIslands"),"MushroomIslands stays outside outpost, village, trail-ruin and jungle-temple filters")
	suite.check(BiomeMap.allows("#has_mineshaft","MushroomIsland") and BiomeMap.allows("#has_stronghold","MushroomIslands") and BiomeMap.allows("#has_trial_chambers","MushroomIslands") and BiomeMap.allows("#has_ruined_portal_standard","MushroomIslands"),"MushroomIslands keeps the structures that explicitly or overworld-wide include it")
	suite.check(not BiomeMap.allows("#required_ocean_monument_surrounding","MushroomIslands"),"MushroomIslands is excluded from the monument's ocean/river surroundings")

	suite.check(BiomeMap.is_underground("DeepDark") and BiomeMap.allows("#mineshaft_blocking","DeepDark") and not BiomeMap.allows("#has_mineshaft","DeepDark"),"DeepDark carries mineshaft_blocking without becoming a mineshaft biome")
	suite.check(BiomeMap.allows("DeepDark","DeepDark") and not BiomeMap.allows("DeepDark","LushCaves"),"the ancient-hermitage-style exact DeepDark filter remains usable")
	suite.check(BiomeMap.allows("#is_ocean","DeepOcean") and BiomeMap.allows("#is_deep_ocean","DeepOcean") and BiomeMap.allows("#has_ocean_monument","DeepColdOcean"),"deep-ocean postprocessing adds is_ocean and monument eligibility")
	suite.check(BiomeMap.members("is_mountain") == ["CherryGrove","FrozenPeaks","JaggedPeaks","Meadow","SnowySlopes","StonyPeaks"],"mountain membership is exact, including CherryGrove and excluding hills")
	suite.check(BiomeMap.allows("#has_pillager_outpost","FrozenPeaks") and BiomeMap.allows("#has_pillager_outpost","Grove") and not BiomeMap.allows("#has_pillager_outpost","WindsweptHills"),"outposts combine the mountain group and explicit Grove without treating hills as mountains")
	suite.check(BiomeMap.allows("#has_ruined_portal_mountain","WindsweptHills") and BiomeMap.allows("#has_ruined_portal_mountain","Meadow") and not BiomeMap.allows("#has_ruined_portal_standard","Meadow"),"mountain portals include hills and mountains separately from standard portals")
	suite.check(BiomeMap.build_biome_list(["#is_taiga","MegaTaiga","Taiga"]) == ["OldGrowthPineTaiga","OldGrowthSpruceTaiga","SnowyTaiga","Taiga"],"biome-list expansion resolves aliases and removes duplicates deterministically")

	var copied: Array = BiomeMap.groups("MegaTaiga")
	copied.append("caller_mutation")
	suite.check(not BiomeMap.groups("OldGrowthPineTaiga").has("caller_mutation"),"group queries return independent data safe for independent workers")
	suite.check(BiomeMap.allows("is_not_registered","Taiga") == false and BiomeMap.build_biome_list(["UnknownBiome","#is_not_registered"]).is_empty(),"unknown exact IDs and groups fail closed")
