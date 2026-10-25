extends SceneTree

var passed: int = 0
var failed: int = 0
const PLANTS = ["plant_wheat","plant_carrot","plant_potato","plant_beetroot"]
const IDS = {
	"air":Nodes.AIR,"mcl_core:dirt":Nodes.DIRT,"mcl_core:stone":Nodes.STONE,"mcl_core:glass":Nodes.GLASS,
	"mcl_core:grass_path":VillageContent.PATH,"mcl_farming:soil":Farmland.DRY,
	"mcl_farming:soil_wet":Farmland.WET,"mcl_farming:wheat_1":Nodes.WHEAT,
	"mcl_composters:composter":VillageContent.COMPOSTER,"mcl_chests:chest_small":Nodes.CHEST,
	"mcl_hoppers:hopper":Nodes.HOPPER,"mcl_pistons:piston_pusher":Nodes.PISTON_HEAD,
	"mcl_stairs:slab_oak":BuildingShapes.FIRST,"mcl_honey:honey_block":Beehives.HONEY_BLOCK,
	"mcl_lush_caves:hanging_roots":LushCaves.HANGING_ROOTS,
}

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 16: push_error(message)

func run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/farming_reference.json"))
	check(Farmland.INTERVAL == ref.timers.hydration.interval and Farmland.CHANCE == ref.timers.hydration.chance,"Source hydration interval and chance")
	check(Farmland.COVER_INTERVAL == ref.timers.covered.interval and Farmland.COVER_CHANCE == ref.timers.covered.chance,"Source covered-soil interval and chance")
	for key in IDS:
		if key == "mcl_stairs:slab_oak": continue
		for group in ref.nodes[key]: check(FarmingRules.group(IDS[key],group) == ref.nodes[key][group],"Bound farming group: "+key+" / "+str(group))
	for i in PLANTS.size():
		var entry: Dictionary = ref.plants[PLANTS[i]]
		check(CropFarming.INTERVALS[i] == entry.interval and CropFarming.CHANCES[i] == entry.chance,"Registered crop interval/chance: "+PLANTS[i])
		check(CropFarming.STAGES[i].size() == entry.names.size()+1,"Registered crop stages: "+PLANTS[i])
	for row in ref.growth:
		var entry: Dictionary = ref.plants[row.plant]
		var start: int = entry.names.find(row.name)+1
		var meta: Dictionary = {"last_time":float(row.last),"light_count":int(row.count),"light_total":int(row.total)}
		var next: int = FarmingRules.growth(meta,start,entry.names.size()+1,float(entry.interval)*float(entry.chance),float(row.time),int(row.light),1,row.ignore,row.slow,int(row.roll))
		var after: String = row.name
		if next > 0:
			after = entry.full_grown if next > entry.names.size() else entry.names[next-1]
			meta = {}
		check(after == row.after and (next > 0) == (row.result == "true"),"Source crop growth: "+str(row))
		var expected: Dictionary = row.meta if row.meta is Dictionary else {}
		check(meta.is_empty() == expected.is_empty(),"Growth clears metadata on source set_node")
		if not expected.is_empty():
			check(int(meta.light_count) == int(expected.avg_light_count) and int(meta.light_total) == int(expected.avg_light_summary) and absf(float(meta.last_time)-float(expected.last_gametime)) < 0.00001,"Source crop history after failed growth")
	for row in ref.hydration:
		var above_known: bool = row.above != "ignore"
		var plant: bool = above_known and int(ref.nodes[row.above].plant) != 0
		var result: Dictionary = Farmland.hydration_result(IDS[row.name],int(row.wet),1 if row.water else (-1 if row.unknown else 0),row.rain and row.outdoor,above_known,plant)
		check(result.id == IDS[row.after] and result.wet == int(row.after_wet),"Source moisture transition: "+str(row))
	for row in ref.covered:
		var after: String = "mcl_core:dirt" if FarmingRules.group(IDS[row.above],"solid") != 0 else row.name
		check(after == row.after,"Source covered-soil callback: "+str(row))
	for row in ref.placement:
		var groups: Dictionary = FarmingRules.groups(IDS[row.above])
		var after: String = "mcl_core:dirt" if int(groups.solid) != 0 or int(groups.dirtifier) != 0 else row.name
		check(after == row.after,"Source dirtifier placement: "+str(row))
	print("FARMING SOURCE: %d crop cases, %d hydration cases; %d passed, %d failed"%[ref.growth.size(),ref.hydration.size(),passed,failed])
	quit(1 if failed else 0)
