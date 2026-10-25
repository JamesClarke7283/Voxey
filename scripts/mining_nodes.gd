class_name MiningNodes
extends RefCounted

# Stable Voxey IDs -> actual registered Mineclonia nodes, including placed
# variants. Names are checked against the exported registry; an absent source
# counterpart keeps the native timing rather than borrowing another material.
static var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mining_nodes.json")).bindings
static var cache: Dictionary = {}
static var initialized: bool = false
const WOODS = ["oak","spruce","birch","jungle","acacia","dark_oak","cherry_blossom","mangrove","pale_oak","crimson","warped","bamboo"]
const OXIDATION = ["","_exposed","_weathered","_oxidized"]
const WALLS = ["mcl_walls:cobble","mcl_walls:mossycobble","mcl_walls:brick","mcl_walls:sandstone","mcl_walls:stonebrick","mcl_walls:stonebrickmossy","mcl_walls:granite","mcl_walls:diorite","mcl_walls:andesite","mcl_walls:netherbrick","mcl_walls:endbricks","mcl_blackstone:wall","mcl_blackstone:polishedwall","mcl_blackstone:polishedbrickwall","mcl_deepslate:deepslatecobbledwall","mcl_deepslate:deepslatepolishedwall","mcl_deepslate:deepslatebrickswall","mcl_deepslate:deepslatetileswall","mcl_deepslate:tuffwall","mcl_deepslate:tuffpolishedwall","mcl_deepslate:tuffbrickswall","mcl_walls:rednetherbrick","","","","","","","mcl_walls:prismarine","mcl_walls:mudbrick"]
const SHAPES = {
	3:"stone_rough",9:"cobble",20:"stonebrick",30:"sandstone",31:"sandstonesmooth",39:"diamondblock",48:"ironblock",52:"brick_block",60:"stonebrickmossy",62:"hardened_clay",
	184:"nether_brick",195:"deepslate_cobbled",196:"deepslate_polished",197:"deepslate_bricks",230:"end_stone",231:"end_bricks",Nodes.PURPUR:"purpur_block",
	533:"granite",534:"diorite",535:"andesite",536:"granite_smooth",537:"diorite_smooth",538:"andesite_smooth",541:"quartzblock",697:"blackstone",
	1100:"blackstone_polished",1101:"blackstone_brick_polished",1150:"deepslate_tiles",1151:"deepslate_bricks_cracked",1152:"deepslate_tiles_cracked",
	Nodes.MOSSY_COBBLE:"mossycobble",MinecloniaOres.TUFF:"tuff",Masonry.POLISHED_TUFF:"tuff_polished",Masonry.TUFF_BRICKS:"tuff_bricks",
}

static func initialize() -> void:
	if initialized: return
	initialized = true
	Copper.register_families()
	WoodTypes.register_families()

static func canonical(name: String) -> String:
	for _i in 16:
		if not ToolCapabilities.source.aliases.has(name): break
		name = str(ToolCapabilities.source.aliases[name])
	return name if ToolCapabilities.source.nodes.has(name) else ""

static func wood(id: int) -> String:
	var species: int = WoodTypes.species(id)
	return WOODS[species] if species >= 0 and species < WOODS.size() else ""

static func node_name(id: int) -> String:
	initialize()
	if not cache.has(id): cache[id] = canonical(resolve(id))
	return cache[id]

static func shape_key(material: int) -> String:
	if WoodTypes.is_planks(material): return wood(material)
	if material in BuildingShapes.BARK_MATERIALS:
		# The source registers unstripped bark shapes only. The native stripped
		# variants remain explicit extensions with their original timing.
		if WoodTypes.stripped(material): return ""
		return wood(material)+"_bark"
	if material >= 603 and material <= 618: return "hardened_clay_"+Candles.COLORS[material-603]
	if material in Copper.CUT_STAGES: return "copper"+OXIDATION[Copper.CUT_STAGES.find(material)]+"_cut"
	if material == BambooWood.MOSAIC: return "bamboo_mosaic"
	var name: String = str(bindings.get(str(material),{}).get("node",ToolCapabilities.CORE.get(material,"")))
	var extra: Dictionary = {
		Nodes.GOLD_BLOCK:"goldblock",NetherBlocks.RED_NETHER_BRICKS:"red_nether_brick",
		NetherBlocks.SMOOTH_QUARTZ:"quartz_smooth",PaleOak.RESIN_BRICK_BLOCK:"resin_brick",
		EndMud.MUD_BRICKS:"mud_brick",VillageContent.PRISMARINE:"prismarine",VillageContent.PRISMARINE_BRICK:"prismarine_brick",
	}
	return str(extra.get(material,SHAPES.get(material,name.get_slice(":",1))))

static func resolve(id: int) -> String:
	if id == Masonry.SMOOTH_STONE: return "mcl_core:stone_smooth"
	if id == Masonry.SMOOTH_SANDSTONE: return "mcl_core:sandstonesmooth2"
	if BuildingShapes.is_shape(id):
		var registered: String = ShapeCatalog.source_name(id)
		if not registered.is_empty(): return registered
		var key: String = shape_key(BuildingShapes.material(id))
		if key.is_empty(): return ""
		var variant: int = BuildingShapes.variant(id)
		return "mcl_stairs:"+("stair_" if variant >= 3 else "slab_")+key+("_top" if variant == 1 else "_double" if variant == 2 else "")
	if Doors.is_door(id) or Doors.is_item(id):
		var item: int = Doors.item(id)
		var base: String = "mcl_copper:door"+OXIDATION[Copper.DOOR_ITEMS.find(item)] if item in Copper.DOOR_ITEMS else "mcl_doors:iron_door" if Doors.iron(id) else "mcl_doors:door_"+wood(Doors.material(id))
		return base+("_t_" if Doors.is_door(id) and Doors.upper(id) else "_b_")+("2" if Doors.is_door(id) and Doors.opened(id) else "1")
	if Trapdoors.is_trapdoor(id):
		var item: int = Trapdoors.item(id)
		var base: String = "mcl_copper:trapdoor"+OXIDATION[Copper.TRAPDOOR_ITEMS.find(item)] if item in Copper.TRAPDOOR_ITEMS else "mcl_doors:iron_trapdoor" if item == Trapdoors.IRON else "mcl_doors:trapdoor_"+wood(Trapdoors.material(id))
		return base+("_open" if Trapdoors.open(id) else "")
	if Barriers.is_wall(id): return BarrierCatalog.source_name(id)
	if Barriers.is_fence(id) or Barriers.is_gate(id):
		var material: int = Barriers.material(id)
		var key: String = "nether_brick" if material == Nodes.NETHER_BRICKS else "red_nether_brick" if material == NetherBlocks.RED_NETHER_BRICKS else wood(material)
		return "mcl_fences:"+key+"_fence"+("_gate" if Barriers.is_gate(id) else "")+("_open" if Barriers.open(id) else "")
	if Signs.is_any(id):
		var material: int = Signs.hanging_material(id) if Signs.is_hanging(id) else Signs.material(id)
		return "mcl_signs:"+("hanging_sign_wall_" if Signs.hanging_wall(id) else "hanging_sign_" if Signs.is_hanging(id) else "wall_sign_" if Signs.wall(id) else "standing_sign_")+wood(material)
	if RedstoneInputs.is_device(id):
		var material: int = RedstoneInputs.material(id)
		var key: String = wood(material) if WoodTypes.is_planks(material) else "stone" if material == Nodes.STONE else "polished_blackstone" if material == Bastions.POLISHED else "light" if material == Nodes.GOLD_BLOCK else "heavy"
		return "mcl_buttons:button_"+key+"_off" if RedstoneInputs.is_button(id) else "mcl_pressureplates:pressure_plate_"+key+"_off"
	if Candles.is_candle(id): return "mcl_candles:candle"+("_lit" if Candles.is_lit(id) else "")+"_"+str(Candles.count_of(id))
	if WoodTypes.is_wood(id):
		var key: String = wood(id)
		var part: int = WoodTypes.part(id)
		if part == 2 and key == "mangrove": return "mcl_mangrove:propagule"
		return "mcl_trees:"+({0:"tree_",1:"leaves_",2:"sapling_",3:"wood_",4:"stripped_",5:"bark_",6:"bark_stripped_",8:"tree_",9:"tree_",10:"stripped_",11:"stripped_"}.get(part,""))+key
	for chain in [Copper.BLOCK_STAGES,Copper.CUT_STAGES,Copper.CHISELED_STAGES,Copper.GRATE_STAGES,Copper.BULB_OFF_STAGES,Copper.BULB_ON_STAGES,Copper.ROD_STAGES,Copper.ROD_POWERED_STAGES]:
		if id not in chain: continue
		var stage: String = OXIDATION[chain.find(id)]
		if chain == Copper.ROD_STAGES or chain == Copper.ROD_POWERED_STAGES: return "mcl_lightning_rods:rod"+stage+("_powered" if chain == Copper.ROD_POWERED_STAGES else "")
		if chain == Copper.BULB_OFF_STAGES or chain == Copper.BULB_ON_STAGES: return "mcl_copper:bulb"+stage+("_on" if chain == Copper.BULB_ON_STAGES else "_off")
		return "mcl_copper:block"+stage+("_cut" if chain == Copper.CUT_STAGES else "_chiseled" if chain == Copper.CHISELED_STAGES else "_grate" if chain == Copper.GRATE_STAGES else "")
	if id >= 11530 and id <= 11545:
		var kind: int = (id-11530)/4
		var stage: String = OXIDATION[(id-11530)%4]
		return "mcl_lanterns:copper_lantern"+stage+("_floor" if kind == 0 else "_ceiling") if kind <= 1 else "mcl_lanterns:copper_chain"+stage if kind == 2 else "mcl_panes:copper_bar"+stage+"_flat"
	var colored: String = colored_name(id)
	if not colored.is_empty(): return colored
	if SnowCover.is_snow(id): return "mcl_core:snow"+("_"+str(SnowCover.layers(id)) if SnowCover.layers(id) > 1 else "")
	if SeaPickles.is_pickle(id): return "mcl_ocean:sea_pickle_"+str(SeaPickles.size(id))+("" if SeaPickles.lit(id) else "_off")+"_dead_brain_coral_block"
	if CocoaCrops.is_cocoa(id): return "mcl_cocoas:cocoa_"+({VillageContent.COCOA_POD:"1",VillageContent.COCOA_POD_MID:"2",VillageContent.RIPE_COCOA_POD:"3"}[id])
	if id >= VillageContent.NETHER_WART_0 and id <= VillageContent.NETHER_WART_3:
		return "mcl_nether:nether_wart" if id == VillageContent.NETHER_WART_3 else "mcl_nether:nether_wart_"+str(id-VillageContent.NETHER_WART_0)
	if id >= VillageContent.SWEET_BERRIES_0 and id <= VillageContent.SWEET_BERRIES_3: return "mcl_farming:sweet_berry_bush_"+str(id-VillageContent.SWEET_BERRIES_0)
	if CropFarming.is_crop(id):
		var kind: int = CropFarming.family(id)
		return "mcl_farming:"+["wheat","carrot","potato","beetroot"][kind]+("" if CropFarming.mature(id) else "_"+str(CropFarming.stage(id)-(1 if kind == 3 else 0)))
	if LargePlants.is_large(id): return str(LargePlants.DATA[LargePlants.bottom(id)].source_node)+("_top" if not LargePlants.is_bottom(id) else "")
	if FruitCrops.is_pumpkin_head(id): return "mcl_farming:pumpkin_face"+("_light" if FruitCrops.lit(id) else "")
	if FruitCrops.is_stem(id):
		var base: String = "mcl_farming:"+("melontige" if FruitCrops.melon(id) else "pumpkin")
		if FruitCrops.attached(id): return ("mcl_farming:melontige" if FruitCrops.melon(id) else "mcl_farming:pumpkintige")+"_linked_"+["r","l","t","b"][id-FruitCrops.base(id)-8]
		if FruitCrops.stage(id) == 8: return "mcl_farming:"+("melontige" if FruitCrops.melon(id) else "pumpkintige")+"_unconnect"
		return base+"_"+str(FruitCrops.stage(id))
	if FoodFeatures.is_cake(id) and not Candles.is_cake(id): return "mcl_cake:cake"+("_"+str(7-FoodFeatures.slices(id)) if FoodFeatures.slices(id) < 7 else "")
	if Rails.is_rail(id): return "mcl_minecarts:"+({Rails.RAIL_BASE:"rail",Rails.POWERED:"golden_rail",Rails.DETECTOR:"detector_rail",Rails.ACTIVATOR:"activator_rail"}.get(Rails.item(id),""))+("_on" if Rails.is_on(id) else "")
	if Amethyst.is_crystal(id): return "mcl_amethyst:"+["small_amethyst_bud","medium_amethyst_bud","large_amethyst_bud","amethyst_cluster"][Amethyst.stage(id)]
	if Heads.kind(id) >= 0: return "mcl_heads:"+["zombie","creeper","steve","skeleton","wither_skeleton","piglin","dragon"][Heads.kind(id)]+("_wall" if Heads.is_wall(id) else "_ceiling" if Heads.is_ceiling(id) else "")
	if Corals.is_coral(id): return "mcl_ocean:"+("dead_" if Corals.dead(id) else "")+Corals.SPECIES[Corals.species(id)]+"_coral"+("_block" if Corals.is_block(id) else "_fan" if Corals.is_fan(id) else "")
	if PointedDripstone.is_stage(id): return "mcl_dripstone:dripstone_"+("top_" if PointedDripstone.is_top(id) else "bottom_")+PointedDripstone.STAGES[PointedDripstone.stage(id)-1]
	if id in Torches.WALLS: return "mcl_torches:torch_wall"
	if id in Torches.COPPER_WALLS: return "mcl_copper:copper_torch_wall"
	var named: String = str(VillageContent.DATA.get(id,{}).get("source_node",""))
	if not named.is_empty(): return named
	if bindings.has(str(id)): return str(bindings[str(id)].node)
	if ToolCapabilities.CORE.has(id): return ToolCapabilities.CORE[id]
	for name in TrialChambers.SIMPLE:
		if TrialChambers.SIMPLE[name] == id: return name
	return ""

static func colored_name(id: int) -> String:
	for entry in [[571,"mcl_wool:"],[587,"mcl_wool:","_carpet"],[603,"mcl_colorblocks:hardened_clay_"],[619,"mcl_colorblocks:glazed_terracotta_"],[651,"mcl_beds:bed_","_bottom"],[667,"mcl_beds:bed_","_top"],[11040,"mcl_colorblocks:concrete_powder_"],[11056,"mcl_colorblocks:concrete_"],[11210,"mcl_core:glass_"],[11226,"mcl_panes:pane_","_flat"]]:
		if id >= entry[0] and id < entry[0]+16: return entry[1]+Candles.COLORS[id-entry[0]]+(entry[2] if entry.size() > 2 else "")
	if id >= 635 and id < 651: return "mcl_banners:standing_banner"
	if id >= 1181 and id < 1197:
		var colors: Array = ["white","dark_grey","grey","black","yellow","orange","red","magenta","violet","blue","cyan","green","dark_green","pink","lightblue","brown"]
		return "mcl_chests:"+colors[id-1181]+"_shulker_box_small"
	return ""

static func native_reason(id: int) -> String:
	if id in [27,685]: return "Original generic plant without a single source species"
	if id == 692: return "Original recovery chest"
	if id >= 12000 and id <= 12006: return "Original steam machine"
	if id in [13098,13099,13130,13131]: return "Legacy nether tree leaf/sapling; the source uses fungi and wart blocks"
	var materials: Array = [NetherBlocks.NETHER_WART_BLOCK,NetherBlocks.CHISELED_QUARTZ,NetherBlocks.QUARTZ_BRICK,NetherBlocks.POLISHED_BASALT,NetherBlocks.CRACKED_BLACKSTONE_BRICKS]
	if BuildingShapes.is_shape(id):
		var material: int = BuildingShapes.material(id)
		if material in materials or material in BuildingShapes.BARK_MATERIALS and WoodTypes.stripped(material): return "Native shape with no registered source counterpart"
	if Barriers.is_wall(id) and (Barriers.material(id) in materials or Barriers.material(id) == NetherBlocks.SMOOTH_QUARTZ): return "Native wall with no registered source counterpart"
	return ""
