class_name FarmingRules
extends RefCounted

# Completed Mineclonia registry and callbacks; see docs/farmland-source.md.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/farming.json"))
static var groups_cache: Dictionary = {}
# `farming.json` intentionally contains only the crop/soil callback groups.
# These additional source groups are needed by mycelium and giant-spruce logic.
# Numeric IDs are the stable registrations, including snowed group inheritance.
const DIRT_GROUP = {1:2,13:2,2:1,13600:3,11470:1,13602:2,13603:2,13604:2,13605:2,685:2}
const SPREADING_GROUP = {1:1,685:1,13604:1}
const SOIL_FUNGUS_GROUP = {1:1,13:1,2:1,13600:1,11470:1,13602:1,13603:1,13604:1,13605:1,685:1,683:1,186:1,187:1,21:1,8000:1,1204:1,11526:1,1223:1}

static func non_mycelium_plant(id: int) -> bool:
	if id in [Nodes.SUGAR_CANE,Nodes.CACTUS,Nodes.FLOWER,DryTerrain.DEAD_BUSH]: return true
	if Bamboo.is_bamboo(id) or FoodFeatures.flower(id) or FoodFeatures.is_tall_grass(id) or FlowersExtra.is_plant(id) or LargePlants.is_large(id): return true
	if LushCaveExtra.is_azalea(id): return true
	return WoodTypes.is_sapling(id) and not CrimsonPlants.is_fungus(id) and id not in [13099,13131]

static func groups(id: int) -> Dictionary:
	if groups_cache.has(id): return groups_cache[id]
	# These two placed variants were absent from the original mining bindings.
	var name: String = {8000:"mcl_farming:soil_wet",221:"mcl_pistons:piston_pusher"}.get(id,MiningNodes.node_name(id))
	var result: Dictionary = source.nodes.get(name,{})
	groups_cache[id] = result
	return result

static func group(id: int, key: String) -> int:
	var registered: Dictionary = groups(id)
	if registered.has(key): return int(registered[key])
	match key:
		"dirt": return int(DIRT_GROUP.get(id,0))
		"spreading_dirt_type": return int(SPREADING_GROUP.get(id,0))
		"soil_fungus": return int(SOIL_FUNGUS_GROUP.get(id,0))
		"non_mycelium_plant": return int(non_mycelium_plant(id))
	return 0

# Metadata is updated even when the source's low-speed/light gates reject
# growth. Successful set_node is responsible for clearing the old metadata.
static func growth(metadata: Dictionary, stage: int, maximum: int, period: float, current: float, light: int, stages: int = 1, ignore_light: bool = false, slow: bool = false, roll: int = 0) -> int:
	var count: int = int(metadata.get("light_count",0))
	var total: int = int(metadata.get("light_total",0))
	if count > 99: count = 51; total = ceili(total/2.0)
	else: count += 1
	total += light; metadata.light_count = count; metadata.light_total = total
	var mean: float = ceilf(float(total)/count)
	var last: float = float(metadata.get("last_time",0))
	if last < 1: last = current-period/10.0
	elif last == current: current += period
	var intervals: float = (current-last)/period
	metadata.last_time = current
	if slow:
		if intervals < 1.01 and roll > 0: return 0
		intervals /= 10.0
	if not ignore_light and light < 10 and intervals < 1.5: return 0
	if intervals >= 1.5:
		if mean < 0.1: return 0
		if mean < 10: intervals *= mean/10.0
	var target: int = stage+stages+ceili(intervals)
	# An out-of-range source stage (including a rewound clock) selects mature.
	return maximum if target < 1 or target >= maximum else target
