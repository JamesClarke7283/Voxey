class_name BiomeMap
extends RefCounted

# Canonical string registry from Mineclonia mcl_levelgen (GPL-3.0-or-later).
# Data and filter logic only: no numeric IDs, noise, terrain or climate selector.
# ID/group-list results are copies; definitions are read-only.

const DEFINITIONS: Dictionary = {
	"TheVoid":{"temperature":0.5,"downfall":0.5,"groups":[]},
	"Mesa":{"temperature":2.0,"downfall":0.0,"groups":["is_badlands","is_overworld"]},
	"BambooJungle":{"temperature":0.95,"downfall":0.9,"groups":["is_jungle","is_overworld"]},
	"BasaltDeltas":{"temperature":2.0,"downfall":0.0,"groups":["is_nether"]},
	"Beach":{"temperature":0.8,"downfall":0.4,"groups":["is_beach","is_overworld"]},
	"BirchForest":{"temperature":0.6,"downfall":0.6,"groups":["is_forest","is_overworld"]},
	"CherryGrove":{"temperature":0.5,"downfall":0.8,"groups":["is_mountain","is_overworld"]},
	# ColdOcean's source registration has is_ocean but not is_overworld.
	"ColdOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_ocean"]},
	"CrimsonForest":{"temperature":2.0,"downfall":0.0,"groups":["is_nether"]},
	"DarkForest":{"temperature":0.7,"downfall":0.8,"groups":["is_forest","is_overworld"]},
	"DeepColdOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_deep_ocean","is_overworld"]},
	"DeepDark":{"temperature":0.8,"downfall":0.4,"groups":["is_overworld"],"underground":true,"depth":[1.1,1.1]},
	"DeepFrozenOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_deep_ocean","is_overworld"]},
	"DeepLukewarmOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_deep_ocean","is_overworld"]},
	"DeepOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_deep_ocean","is_overworld"]},
	"Desert":{"temperature":2.0,"downfall":0.0,"groups":["is_overworld"]},
	"DripstoneCaves":{"temperature":0.8,"downfall":0.4,"groups":["is_overworld"],"underground":true,"depth":[0.2,0.9]},
	"EndBarrens":{"temperature":0.5,"downfall":0.5,"groups":["is_end"]},
	"EndHighlands":{"temperature":0.5,"downfall":0.5,"groups":["is_end"]},
	"EndMidlands":{"temperature":0.5,"downfall":0.5,"groups":["is_end"]},
	"ErodedMesa":{"temperature":2.0,"downfall":0.0,"groups":["is_badlands","is_overworld"]},
	"FlowerForest":{"temperature":0.7,"downfall":0.8,"groups":["is_forest","is_overworld"]},
	"Forest":{"temperature":0.7,"downfall":0.8,"groups":["is_forest","is_overworld"]},
	"FrozenOcean":{"temperature":0.0,"downfall":0.5,"groups":["is_ocean","is_overworld"]},
	"FrozenPeaks":{"temperature":-0.7,"downfall":0.9,"groups":["is_mountain","is_overworld"]},
	# FrozenRiver is not in is_river in this source checkout.
	"FrozenRiver":{"temperature":0.0,"downfall":0.5,"groups":["is_overworld"]},
	"Grove":{"temperature":-0.2,"downfall":0.8,"groups":["is_forest","is_overworld"]},
	"IceSpikes":{"temperature":0.0,"downfall":0.5,"groups":["is_overworld"]},
	"JaggedPeaks":{"temperature":-0.7,"downfall":0.9,"groups":["is_mountain","is_overworld"]},
	"Jungle":{"temperature":0.95,"downfall":0.9,"groups":["is_jungle","is_overworld"]},
	"LukewarmOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_ocean","is_overworld"]},
	"LushCaves":{"temperature":0.5,"downfall":0.5,"groups":["is_overworld"],"underground":true,"depth":[0.2,0.9],"humidity":[0.7,1.0]},
	"MangroveSwamp":{"temperature":0.8,"downfall":0.9,"groups":["is_overworld"]},
	"Meadow":{"temperature":0.5,"downfall":0.8,"groups":["is_mountain","is_overworld"]},
	"MushroomIslands":{"temperature":0.9,"downfall":1.0,"groups":["is_overworld"]},
	"NetherWastes":{"temperature":2.0,"downfall":0.0,"groups":["is_nether"]},
	"Ocean":{"temperature":0.5,"downfall":0.5,"groups":["is_ocean","is_overworld"]},
	"OldGrowthBirchForest":{"temperature":0.6,"downfall":0.6,"groups":["is_forest","is_overworld"]},
	"OldGrowthPineTaiga":{"temperature":0.3,"downfall":0.8,"groups":["is_overworld","is_taiga"]},
	"OldGrowthSpruceTaiga":{"temperature":0.25,"downfall":0.8,"groups":["is_overworld","is_taiga"]},
	"Plains":{"temperature":0.8,"downfall":0.4,"groups":["is_overworld"]},
	"River":{"temperature":0.5,"downfall":0.5,"groups":["is_overworld","is_river"]},
	"Savannah":{"temperature":2.0,"downfall":0.0,"groups":["is_overworld","is_savannah"]},
	"SavannahPlateau":{"temperature":2.0,"downfall":0.0,"groups":["is_overworld","is_savannah"]},
	"SmallEndIslands":{"temperature":0.5,"downfall":0.5,"groups":["is_end"]},
	"SnowyBeach":{"temperature":0.05,"downfall":0.3,"groups":["is_beach","is_overworld"]},
	"SnowyPlains":{"temperature":0.0,"downfall":0.5,"groups":["is_overworld"]},
	"SnowySlopes":{"temperature":-0.3,"downfall":0.9,"groups":["is_mountain","is_overworld"]},
	"SnowyTaiga":{"temperature":-0.5,"downfall":0.4,"groups":["is_overworld","is_taiga"]},
	"SoulSandValley":{"temperature":2.0,"downfall":0.0,"groups":["is_nether"]},
	"SparseJungle":{"temperature":0.95,"downfall":0.8,"groups":["is_jungle","is_overworld"]},
	"StonyPeaks":{"temperature":1.0,"downfall":0.3,"groups":["is_mountain","is_overworld"]},
	"StonyShore":{"temperature":0.2,"downfall":0.3,"groups":["is_overworld"]},
	"SunflowerPlains":{"temperature":0.8,"downfall":0.4,"groups":["is_overworld"]},
	"Swamp":{"temperature":0.8,"downfall":0.9,"groups":["is_overworld"]},
	"Taiga":{"temperature":0.25,"downfall":0.8,"groups":["is_overworld","is_taiga"]},
	"TheEnd":{"temperature":0.5,"downfall":0.5,"groups":["is_end"]},
	"WarmOcean":{"temperature":0.5,"downfall":0.5,"groups":["is_ocean","is_overworld"]},
	"WarpedForest":{"temperature":2.0,"downfall":0.0,"groups":["is_nether"]},
	"WindsweptForest":{"temperature":0.2,"downfall":0.3,"groups":["is_hill","is_overworld"]},
	"WindsweptGravellyHills":{"temperature":0.2,"downfall":0.3,"groups":["is_hill","is_overworld"]},
	"WindsweptHills":{"temperature":0.2,"downfall":0.3,"groups":["is_hill","is_overworld"]},
	"WindsweptSavannah":{"temperature":2.0,"downfall":0.0,"groups":["is_overworld","is_savannah"]},
	"WoodedMesa":{"temperature":2.0,"downfall":0.0,"groups":["is_badlands","is_overworld"]},
}

# Old built-in-mapgen names are accepted at API boundaries, never registered as
# additional biomes. The explicitly listed subtype spellings are used by saved
# data and dispatch code; LEGACY_SUFFIXES covers the remaining source subtypes.
const ALIASES: Dictionary = {
	"BasaltDelta":"BasaltDeltas",
	"BirchForestM":"OldGrowthBirchForest",
	"ColdTaiga":"SnowyTaiga",
	"DripstoneCave":"DripstoneCaves",
	"ExtremeHills":"WindsweptHills",
	"ExtremeHills+":"WindsweptHills",
	"ExtremeHillsM":"WindsweptGravellyHills",
	"IcePlains":"SnowyPlains",
	"IcePlainsSpikes":"IceSpikes",
	"JungleEdge":"SparseJungle",
	"JungleEdgeM":"SparseJungle",
	"JungleM":"Jungle",
	"MegaSpruceTaiga":"OldGrowthSpruceTaiga",
	"MegaTaiga":"OldGrowthPineTaiga",
	"MesaBryce":"ErodedMesa",
	"MesaPlateauF":"WoodedMesa",
	"MesaPlateauFM":"WoodedMesa",
	"MushroomIsland":"MushroomIslands",
	"MushroomIslandShore":"MushroomIslands",
	"Nether":"NetherWastes",
	"RoofedForest":"DarkForest",
	"Savanna":"Savannah",
	"SavannaM":"Savannah",
	"SoulsandValley":"SoulSandValley",
	"StoneBeach":"StonyShore",
	"Swampland":"Swamp",
	"End":"TheEnd",
	"EndBorder":"TheEnd",
	"EndIsland":"TheEnd",
	"EndSmallIslands":"SmallEndIslands",
	"LushCaves_underground":"LushCaves",
	"LushCaves_ocean":"LushCaves",
	"BambooJungle_ocean":"BambooJungle",
}

const LEGACY_SUFFIXES: Array = [
	"_shore","_beach","_deep_ocean","_ocean","_sandlevel","_snowtop",
	"_beach_water","_deep_underground","_underground",
]

# Post-registration expansion in biomes.lua: every deep ocean is also an ocean.
const GROUP_RULES: Dictionary = {
	"is_ocean":["#is_deep_ocean"],
}

# Source structure/spawn tags, expressed with the same biome and group selectors
# as their registrations. These are the non-ersatz structure forms; ersatz-only
# broadening is not silently mixed into the canonical registry.
const TAG_RULES: Dictionary = {
	"has_buried_treasure":["#is_beach"],
	"has_desert_pyramid":["Desert"],
	"has_end_city":["EndHighlands","EndMidlands"],
	"has_igloo":["SnowyTaiga","SnowyPlains","SnowySlopes"],
	"has_jungle_temple":["BambooJungle","Jungle"],
	"has_mineshaft":[
		"#is_beach","#is_forest","#is_hill","#is_jungle","#is_mountain",
		"#is_ocean","#is_river","#is_taiga","Desert","DripstoneCaves",
		"IceSpikes","LushCaves","MangroveSwamp","MushroomIslands","Plains",
		"Savannah","SavannahPlateau","SnowyPlains","StonyShore",
		"SunflowerPlains","Swamp","WindsweptSavannah",
	],
	"has_mineshaft_mesa":["#is_badlands"],
	"mineshaft_blocking":["DeepDark"],
	"has_nether_fortress":["#is_nether"],
	"has_bastion_remnant":["CrimsonForest","NetherWastes","SoulSandValley","WarpedForest"],
	"has_nether_fossil":["SoulSandValley"],
	"has_ocean_monument":["#is_deep_ocean"],
	"required_ocean_monument_surrounding":["#is_ocean","#is_river"],
	"has_ocean_ruin_cold":["FrozenOcean","ColdOcean","Ocean","DeepFrozenOcean","DeepColdOcean","DeepOcean"],
	"has_ocean_ruin_warm":["LukewarmOcean","WarmOcean","DeepLukewarmOcean"],
	"has_pillager_outpost":["Desert","Plains","Savannah","SnowyPlains","Taiga","#is_mountain","Grove"],
	"has_ruined_portal_standard":[
		"#is_beach","#is_river","#is_taiga","#is_forest","MushroomIslands",
		"IceSpikes","DripstoneCaves","LushCaves","Savannah","SnowyPlains",
		"Plains","SunflowerPlains",
	],
	"has_ruined_portal_desert":["Desert"],
	"has_ruined_portal_jungle":["#is_jungle"],
	"has_ruined_portal_swamp":["Swamp","MangroveSwamp"],
	"has_ruined_portal_mountain":["#is_badlands","#is_hill","SavannahPlateau","WindsweptSavannah","StonyShore","#is_mountain"],
	"has_ruined_portal_ocean":["#is_ocean"],
	"has_ruined_portal_nether":["#is_nether"],
	"has_shipwreck_beached":["#is_beach"],
	"has_shipwreck":["#is_ocean"],
	"stronghold_biased_to":[
		"BambooJungle","BirchForest","Desert","DripstoneCaves","ErodedMesa",
		"FlowerForest","Forest","FrozenPeaks","Grove","IceSpikes","JaggedPeaks",
		"Jungle","LushCaves","Meadow","Mesa","MushroomIslands",
		"OldGrowthBirchForest","OldGrowthPineTaiga","OldGrowthSpruceTaiga",
		"Plains","Savannah","SavannahPlateau","SnowyPlains","SnowySlopes",
		"SnowyTaiga","SparseJungle","StonyPeaks","SunflowerPlains","Taiga",
		"WindsweptForest","WindsweptGravellyHills","WindsweptHills",
		"WindsweptSavannah","WoodedMesa",
	],
	"has_stronghold":["#is_overworld"],
	"has_swamp_hut":["Swamp"],
	"has_trail_ruins":["Jungle","OldGrowthBirchForest","OldGrowthPineTaiga","OldGrowthSpruceTaiga","SnowyTaiga","Taiga"],
	"has_trial_chambers":["#is_overworld"],
	"has_woodland_mansion":["DarkForest"],
	"has_village_desert":["Desert"],
	"has_village_plains":["Plains","Meadow"],
	"has_village_savannah":["Savannah"],
	"has_village_snowy":["SnowyPlains"],
	"has_village_taiga":["Taiga"],
	"more_frequent_drowned_spawns":["#is_river"],
}

static func canonical(id: String) -> String:
	if DEFINITIONS.has(id): return id
	if ALIASES.has(id): return ALIASES[id]
	for suffix in LEGACY_SUFFIXES:
		if id.ends_with(suffix):
			var base: String = id.left(id.length()-suffix.length())
			var resolved: String = canonical(base)
			if not resolved.is_empty(): return resolved
	return ""

static func is_canonical(id: String) -> bool:
	return DEFINITIONS.has(id)

static func known(id: String) -> bool:
	return not canonical(id).is_empty()

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(canonical(id),{})

static func temperature(id: String) -> Variant:
	return definition(id).get("temperature")

static func downfall(id: String) -> Variant:
	return definition(id).get("downfall")

static func is_underground(id: String) -> bool:
	return definition(id).get("underground",false)

static func canonical_ids() -> Array:
	var result: Array = DEFINITIONS.keys()
	result.sort()
	return result

static func groups(id: String) -> Array:
	var def: Dictionary = definition(id)
	if def.is_empty(): return []
	var canonical_id: String = canonical(id)
	var result: Array = def.groups.duplicate()
	for group_name in GROUP_RULES:
		if allows("#"+group_name,canonical_id) and not result.has(group_name): result.append(group_name)
	for group_name in TAG_RULES:
		if allows("#"+group_name,canonical_id) and not result.has(group_name): result.append(group_name)
	result.sort()
	return result

# Filter first, biome second, matching structure_biome_test's purpose. A filter
# may be an exact canonical/legacy ID, "#is_taiga", or bare "is_taiga".
static func allows(filter: String, biome_id: String) -> bool:
	var id: String = canonical(biome_id)
	return not id.is_empty() and _matches(filter,id)

static func _matches(filter: String, id: String) -> bool:
	if filter.begins_with("#"):
		var group_name: String = filter.substr(1)
		if DEFINITIONS[id].groups.has(group_name): return true
		if GROUP_RULES.has(group_name): return _matches_any(GROUP_RULES[group_name],id)
		if TAG_RULES.has(group_name): return _matches_any(TAG_RULES[group_name],id)
		return false
	var selected: String = canonical(filter)
	if not selected.is_empty(): return selected == id
	# Unknown bare names are group names, not implicitly new biome IDs.
	return _matches("#"+filter,id) if not filter.is_empty() else false

static func _matches_any(filters: Array, id: String) -> bool:
	for filter in filters:
		if _matches(str(filter),id): return true
	return false

static func build_biome_list(filters: Array) -> Array:
	var result: Array = []
	for filter in filters:
		var text: String = str(filter)
		if text.begins_with("#"):
			for id in DEFINITIONS:
				if allows(text,id) and not result.has(id): result.append(id)
		else:
			var id: String = canonical(text)
			if not id.is_empty() and not result.has(id): result.append(id)
	result.sort()
	return result

static func members(group_name: String) -> Array:
	return build_biome_list([group_name if group_name.begins_with("#") else "#"+group_name])
