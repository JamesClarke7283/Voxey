class_name Composters
extends RefCounted

# Mineclonia mcl_composters/init.lua and the compostability groups of the
# corresponding foods and plants. Failed rolls still consume the ingredient.
static func chance(id: int) -> int:
	if FruitCrops.is_seed(id): return 30
	if WoodTypes.is_leaves(id) or WoodTypes.is_sapling(id): return 30
	if FoodFeatures.flower(id): return 65
	if id in [Nodes.SEEDS,Nodes.SAPLING,Nodes.LEAVES,VillageContent.BEETROOT_SEEDS,VillageContent.KELP,VillageContent.DRIED_KELP,VillageContent.SWEET_BERRY,VillageContent.NETHER_WART_ITEM,VillageContent.SWAMP_GRASS]: return 30
	if id in [Nodes.CACTUS,Nodes.VINE,Nodes.SUGAR_CANE,Nodes.MELON_SLICE,VillageContent.DRIED_KELP_BLOCK]: return 50
	if id in [Nodes.APPLE,Nodes.GRAIN,Nodes.FLOWER,Nodes.PUMPKIN,Nodes.SNOW_GOLEM_SCARECROW,Nodes.MELON,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT,VillageContent.COCOA_BEANS,VillageContent.LILY_PAD]: return 65
	if id in [Nodes.BREAD,Nodes.HAY_BALE,VillageContent.COOKIE,VillageContent.BAKED_POTATO]: return 85
	if id in [Nodes.PUMPKIN_PIE,VillageContent.CAKE]: return 100
	# The lush-cave plants carry the source's own `compostability` percentages.
	if LushCaveExtra.compostability(id) > 0: return LushCaveExtra.compostability(id)
	return 0

static func level(station: Dictionary) -> int:
	return clampi(int(station.get("compost",0)),0,8)

static func add(station: Dictionary, id: int, roll: int = -1) -> bool:
	var probability: int = chance(id)
	if level(station) >= 7 or probability == 0: return false
	if roll < 0: roll = randi_range(1,100)
	if roll <= probability:
		station.compost = level(station)+1
		if level(station) == 7: station.maturation = 1.0
	return true

static func step(station: Dictionary, delta: float) -> void:
	if level(station) != 7: return
	station.maturation = maxf(0,float(station.get("maturation",1.0))-delta)
	if station.maturation <= 0:
		station.compost = 8
		station.erase("maturation")

static func harvest(station: Dictionary) -> bool:
	if level(station) != 8: return false
	station.compost = 0
	station.erase("maturation")
	return true

static func interact(game: Node, p: Vector3i) -> void:
	var station: Dictionary = game.world.get_station(p,"composter")
	var before: int = level(station)
	if harvest(station):
		game.spawn_drop(Vector3(p)+Vector3(0.5,1.2,0.5),Nodes.BONE_MEAL)
		game.toast("Collected bone meal.")
	elif add(station,game.inventory.held().id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place")
		if level(station) > before: game.puff(Vector3(p)+Vector3(0.5,1.1,0.5),Color("8dbb56"),5)
		game.toast("Compost %d / 7%s"%[mini(7,level(station))," · maturing" if level(station) == 7 else ""])
	elif before == 7: game.toast("The compost is maturing.")
	else: game.toast("Add plants or food. Each item has a chance to add a compost layer.")
	game.survival.refresh_displays()

static func recipes(inv: Inventory) -> void:
	var slab: int = BuildingShapes.slab_for(Nodes.PLANKS)
	inv._recipe("Composter",VillageContent.COMPOSTER,1,[slab,0,slab,slab,0,slab,slab,slab,slab],3,"table")

static func fill_model(station: Dictionary) -> MeshInstance3D:
	var fill := MeshInstance3D.new()
	var box := BoxMesh.new()
	var height: float = (1+mini(7,level(station))*2)/16.0
	box.size = Vector3(0.75,height,0.75)
	fill.mesh = box
	fill.position = Vector3(0.5,height/2,0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d5d7b0") if level(station) == 8 else Color("70533d")
	fill.material_override = mat
	return fill
