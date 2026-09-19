class_name NoteBlocks
extends RefCounted

# Mechanics ported from Mineclonia mcl_noteblock/init.lua (GPL-3.0-or-later).
# Procedural artwork and NoteBlockTones synthesis are original Voxey work.
const ID = 6700
const DATA = {6700:{"name":"Note block","block":true,"color":"976239","hardness":0.8,"tool":1,"fuel":15,"flammable":false,"note_material":"wood"}}
const WOOD = [Nodes.LOG,Nodes.PLANKS,Nodes.CRIMSON_STEM,Nodes.WARPED_STEM,Nodes.WORKBENCH,Nodes.CHEST,Nodes.BOOKSHELF,VillageContent.COMPOSTER,VillageContent.BARREL,VillageContent.FLETCHING_TABLE,VillageContent.LOOM,VillageContent.CARTOGRAPHY_TABLE,ID]
const STONE = [Nodes.STONE,Nodes.COBBLE,Nodes.COAL_ORE,Nodes.IRON_ORE,Nodes.GOLD_ORE,Nodes.COPPER_ORE,Nodes.DIAMOND_ORE,Nodes.LAPIS_ORE,Nodes.REDSTONE_ORE,Nodes.BRICKS,Nodes.OBSIDIAN,Nodes.BEDROCK,Nodes.RED_BRICKS,Nodes.MOSSY_COBBLE,Nodes.MOSSY_BRICKS,Nodes.COAL_BLOCK,Nodes.SANDSTONE,Nodes.SANDSTONE_BRICK,Nodes.NETHERRACK,Nodes.NETHER_BRICKS,Nodes.BASALT,Nodes.CRIMSON_NYLIUM,Nodes.WARPED_NYLIUM,Nodes.NETHER_QUARTZ_ORE,Nodes.FURNACE,Nodes.OBSERVER,Nodes.DISPENSER,Nodes.DROPPER,Nodes.END_STONE,Nodes.END_BRICKS,Nodes.PURPUR,Netherite.ANCIENT_DEBRIS,Netherite.BLOCK,Bastions.CRYING_OBSIDIAN,Bastions.POLISHED,Bastions.BRICKS,Bastions.CHISELED,Bastions.GILDED,Bastions.LODESTONE,MinecloniaOres.NETHER_GOLD,MinecloniaOres.BLACKSTONE,MinecloniaOres.TUFF,VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE,VillageContent.STONECUTTER,VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CHISELED_BRICKS,VillageContent.DRIPSTONE_BLOCK,VillageContent.QUARTZ_BLOCK,VillageContent.QUARTZ_PILLAR,PortableStorage.ENDER_CHEST,Nodes.TERRACOTTA,VillageContent.GRANITE,VillageContent.DIORITE,VillageContent.ANDESITE,VillageContent.POLISHED_GRANITE,VillageContent.POLISHED_DIORITE,VillageContent.POLISHED_ANDESITE]
const NAMES = {"piano":"Piano","bass_guitar":"Bass guitar","bass_drum":"Bass drum","snare":"Snare drum","hit":"Sticks","bell":"Bell","flute":"Flute","chime":"Chime","guitar":"Guitar","xylophone_wood":"Wooden xylophone","xylophone_metal":"Iron xylophone","cowbell":"Cow bell","didgeridoo":"Didgeridoo","squarewave":"Square wave","banjo":"Banjo","piano_digital":"Electric piano"}

static func is_note_block(id: int) -> bool: return id == ID

static func definitions() -> Dictionary:
	return DATA

static func recipes(inv: Inventory) -> void:
	var wood: int = Nodes.PLANKS
	inv._recipe("Note block",ID,1,[wood,wood,wood,wood,Nodes.REDSTONE_WIRE,wood,wood,wood,wood],3,"table")

static func state(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var result: Dictionary = world.circuits.state(p)
	result["note"] = posmod(int(result.get("note",0)),25)
	result["powered"] = result.get("powered",false) == true
	result["out"] = 0
	return result

static func pitch(note: int) -> float: return pow(2.0,(clampi(note,0,24)-12)/12.0)

static func color(note: int) -> Color:
	note = clampi(note,0,24)
	if note < 8: return Color8(floori(note/8.0*255),floori((8-note)/8.0*255),0)
	if note < 16: return Color8(floori((16-note)/8.0*255),0,floori((note-8)/8.0*255))
	return Color8(0,floori((note-16)/9.0*255),floori((25-note)/9.0*255))

# Only actual source groups determine these fallbacks. A wooden-looking sign,
# bed, torch or leaf is not automatically material_wood; ordinary ice is not
# glass, and iron/gold/diamond blocks are not material_stone.
static func group(id: int) -> String:
	if id == Jukeboxes.ID: return "wood"
	if RedstoneInputs.is_device(id):
		if RedstoneInputs.wooden(id): return "wood"
		return "stone" if RedstoneInputs.kind(id) in [0,7] else ""
	if BuildingShapes.is_shape(id): return group(BuildingShapes.material(id))
	if Barriers.is_barrier(id): return group(Barriers.material(id))
	if Doors.is_door(id): return "wood" if not Doors.iron(id) else ""
	if Trapdoors.is_trapdoor(id): return "wood" if Trapdoors.item(id) != Trapdoors.IRON else ""
	if WoodTypes.is_log(id) or WoodTypes.is_planks(id) or id in WOOD: return "wood"
	if id in [Nodes.GLASS,VillageContent.GLASS_PANE]: return "glass"
	if id in [Nodes.SAND,Nodes.GRAVEL]: return "sand"
	if id in STONE or id in Nodes.DEEP_NODES or id == Nodes.DEEP_REDSTONE_ORE or id in Masonry.BLOCKS: return "stone"
	var definition: Dictionary = VillageContent.DATA.get(id,Nodes.custom_nodes.get(id,{}))
	if definition.get("family","") in ["terracotta","glazed_terracotta"]: return "stone"
	var groups: Dictionary = definition.get("groups",{})
	for material in ["glass","wood","sand","stone"]:
		if int(groups.get("material_"+material,0)) != 0 or definition.get("note_material","") == material: return material
	return ""

static func instrument(id: int) -> String:
	# Exact-node instruments take precedence over the material group below.
	if id in [Nodes.GOLD_BLOCK,Nodes.GOLD_NODE]: return "bell"
	if id == Nodes.CLAY: return "flute"
	if id in [Nodes.IRON_BLOCK,Nodes.IRON_NODE]: return "xylophone_metal"
	if id == Nodes.SOUL_SAND: return "cowbell"
	if id == VillageContent.EMERALD_BLOCK: return "squarewave"
	if id == Nodes.HAY_BALE: return "banjo"
	if id == Nodes.GLOWSTONE: return "piano_digital"
	if id == Nodes.WOOL or VillageContent.DATA.get(id,{}).get("family","") == "wool": return "guitar"
	if id in [Nodes.PUMPKIN,Nodes.SNOW_GOLEM_SCARECROW]: return "didgeridoo"
	# Exact source annotations also preserve bone's sound in all three axes.
	var source_name: String = str(VillageContent.DATA.get(id,Nodes.custom_nodes.get(id,{})).get("source_node",""))
	if source_name == "mcl_core:packed_ice": return "chime"
	if source_name == "mcl_core:bone_block": return "xylophone_wood"
	if source_name == "mcl_pale_oak:block_of_resin": return "flute"
	return {"glass":"hit","wood":"bass_guitar","sand":"snare","stone":"bass_drum"}.get(group(id),"piano")

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or int(target.get("id",0)) != ID or game.target_mob() != null: return false
	if Signs.sneaking(game): return false
	var data: Dictionary = state(game.world,target.pos)
	data.note = (int(data.note)+1)%25
	play(game.world,target.pos)
	game.world.circuits.notify_observers(target.pos)
	game.player.swing = 1
	game.toast("%s · note %d / 25"%[NAMES[instrument(game.world.node_at(target.pos+Vector3i.DOWN))],int(data.note)+1])
	return true

static func punch(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or int(target.get("id",0)) != ID: return false
	return play(game.world,target.pos)

static func power(world: VoxelWorld, p: Vector3i, on: bool, was_on: bool) -> void:
	var data: Dictionary = state(world,p); data.powered = on
	if on and not was_on: play(world,p)

static func play(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != ID or not world.loaded_at(Vector3(p)): return false
	# Source requires literal air, even glass/flowers/liquids silence the block.
	if world.node_at(p+Vector3i.UP) != Nodes.AIR: return false
	var data: Dictionary = state(world,p)
	var voice: String = instrument(world.node_at(p+Vector3i.DOWN))
	var game: Node3D = world.get_parent()
	if game.audio_enabled:
		var key: String = "note_"+voice
		if not game.sounds.has(key): game.sounds[key] = NoteBlockTones.sample(voice)
		game.sound_at(key,Vector3(p)+Vector3.ONE*0.5,pitch(data.note))
	particle(game,p,data.note)
	return true

static func particle(game: Node3D, p: Vector3i, note: int) -> void:
	if Vector3(p).distance_to(game.player.position) > 70 or not is_instance_valid(game.entities): return
	var label := Label3D.new(); label.name = "NoteParticle"; label.text = "♪"
	label.modulate = color(note); label.outline_size = 0; label.shaded = false
	label.font_size = 36; label.pixel_size = 0.008; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var start: Vector3 = Vector3(p)+Vector3(0.5,0.85,0.5)
	label.position = start; game.entities.add_child(label)
	var animation: Tween = label.create_tween()
	animation.tween_method(func(time: float): label.position = start+Vector3.UP*(2*time-time*time),0.0,1.0,1.0)
	animation.tween_callback(label.queue_free)

static func pixel(_id: int, x: int, y: int, noise: Color) -> Color:
	if x in [0,15] or y in [0,15]: return Color("81532f")
	if x == 1 or y == 1: return Color("d39a58")
	if x == 14 or y == 14: return Color("ba8248")
	return noise.lightened(0.05) if x%2 == 1 and y%2 == 1 else Color("35271e")

static func draw(img: Image, _id: int = ID) -> void:
	img.fill(Color("81532f"))
	img.fill_rect(Rect2i(1,1,14,14),Color("ba8248"))
	img.fill_rect(Rect2i(2,2,12,12),Color("35271e"))
	for y in range(3,14,2):
		for x in range(3,14,2): img.set_pixel(x,y,Color("ad7947"))
	for i in range(2,14): img.set_pixel(i,1,Color("d39a58")); img.set_pixel(1,i,Color("d39a58"))
