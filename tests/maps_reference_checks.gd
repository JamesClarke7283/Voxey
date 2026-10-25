extends SceneTree
var passed: int = 0
var failed: int = 0
class WorldStub extends RefCounted:
	var seed_value: int = 1
	var edits: Dictionary = {}
	var columns: Dictionary = {}
	var blocks: Dictionary = {}
class GameStub extends Node3D:
	var world := WorldStub.new()
	var dimension: String = "overworld"
	var network: Node = null
	var survival: Node = null
func _init() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 12: push_error(text)
func run() -> void:
	var inv := Inventory.new()
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/maps_reference.json"))
	check(Nodes.max_stack(VillageContent.EMPTY_MAP) == int(ref.registry["mcl_maps:empty_map"].stack),"Registered empty-map stack limit")
	check(Nodes.max_stack(VillageContent.FILLED_MAP) == int(ref.registry["mcl_maps:filled_map"].stack),"Registered filled-map stack limit")
	check(not ref.registry["mcl_cartography_table:cartography_table"].gui,"Reference has no cartography GUI to invent")
	check(is_equal_approx(Nodes.hardness(VillageContent.CARTOGRAPHY_TABLE),float(ref.registry["mcl_cartography_table:cartography_table"].hardness)),"Registered cartography hardness")
	check(Nodes.fuel_time(VillageContent.CARTOGRAPHY_TABLE) == int(ref.registry["mcl_cartography_table:cartography_table"].burn),"Registered cartography fuel time")
	for row in ref.origins:
		var p := Vector3(row.pos.x,row.pos.y,row.pos.z)
		var origin: Vector3i = ExplorationMaps.origin(p)
		check(origin == Vector3i(row.item.min[0],row.item.min[1],row.item.min[2]),"Source cube alignment "+str(p))
		check(origin+Vector3i.ONE*127 == Vector3i(row.item.max[0],row.item.max[1],row.item.max[2]),"Source inclusive cube maximum")
	var game := GameStub.new(); var maps := ExplorationMaps.new(game)
	for row in ref.fills:
		var filled_id: String = ""
		for item in row.items if row.items is Array else []:
			if item.name == "mcl_maps:filled_map": filled_id = str(item.id)
		for item in row.drops if row.drops is Array else []: filled_id = str(item.id)
		maps.next_id = int(filled_id)
		inv.restore([]); inv.selected = 0
		if row.full:
			for i in inv.slots.size(): inv.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
		inv.slots[0] = {"id":VillageContent.EMPTY_MAP,"count":int(row.count),"wear":0}
		var result: Dictionary = maps.fill_inventory(inv,Vector3(8,650,9))
		check(inv.slots[0].count == int(row.result.count) and inv.slots[0].id == (VillageContent.EMPTY_MAP if row.result.name == "mcl_maps:empty_map" else VillageContent.FILLED_MAP),"Source empty-map use returns its final item to the hand")
		check(int(result.overflow) == (row.drops.size() if row.drops is Array else 0),"Source map overflow handling")
		check(result.item.data.map.id == filled_id and result.item.data.map.min == [0,640,0],"Source allocates a world-wide map ID and aligned position")
	var metadata: Dictionary = {"id":"5","min":[-128,0,0],"dimension":"overworld","created":1700000000,"positive_z":true}
	for row in ref.markers:
		var p := Vector3(row.pos.x,row.pos.y,row.pos.z)
		var native: Dictionary = ExplorationMaps.marker(metadata,p,"nether",float(row.yaw))
		var source: Dictionary = row.marker
		var pixel := Vector2(float(source.offset.x)/2+64,float(source.offset.y)/2+134)
		var dot: bool = str(source.text).contains("_dot")
		var turn: int = int(str(source.text).get_slice("transformR",1)) if str(source.text).contains("transformR") else 0
		check(native.visible and native.pixel.is_equal_approx(pixel) and native.outside == dot,"Source marker rounding/clamping "+str(p))
		check(dot or is_equal_approx(native.rotation,-deg_to_rad(turn)),"Source marker quarter turn "+str(row.yaw))
	var copied: Dictionary = ExplorationMaps.craft_output_data([{"id":VillageContent.FILLED_MAP,"data":{"map":metadata,"custom_name":"Remembered map","junk":"kept"}}])
	for row in ref.copies: check(copied.custom_name == row.label and copied.junk == row.junk and copied.map.id == row.id,"Source map copies retain all metadata")
	var ids: Dictionary = {"mcl_core:stone":Nodes.STONE,"mcl_core:glass":Nodes.GLASS,"mcl_core:water_source":Nodes.WATER,"mcl_core:leaves":Nodes.LEAVES,"mcl_core:dirt":Nodes.DIRT,"mcl_core:goldblock":Nodes.GOLD_BLOCK}
	var source: Dictionary = {"loaded":{},"columns":{},"edits":{}}
	for z in 8:
		for x in 8: source.columns[Vector2i(x,z)] = true
	for column in ref.columns:
		for layer in column.layers if column.layers is Array else []:
			var p := Vector3i(int(column.x),int(layer.y),int(column.z)); var b := Vector3i(p.x/16,p.y/16,p.z/16)
			if not source.loaded.has(b):
				var cells := PackedInt32Array(); cells.resize(4096); source.loaded[b] = cells
			source.loaded[b][posmod(p.x,16)+posmod(p.z,16)*16+posmod(p.y,16)*256] = int(ids[layer.name])
	var colors: Dictionary = {}
	for name in ids:
		var c: Variant = ref.palette.get(name)
		if c is Array and not c.is_empty() and c[0] is Array: c = c[0]
		colors[ids[name]] = Color.TRANSPARENT if not c is Array else Color(float(c[0])/255,float(c[1])/255,float(c[2])/255,float(c[3] if c.size()>3 else 255)/255)
	var rgb := PackedFloat32Array(); rgb.resize(128*128*3)
	var heights := PackedInt32Array(); heights.resize(128*128); heights.fill(ExplorationMaps.NO_HEIGHT)
	var opaque := PackedByteArray(); opaque.resize(128*128)
	var build: Dictionary = {"rgb":rgb,"heights":heights,"opaque":opaque,"column":0}
	for i in 64: ExplorationMaps._apply_samples(build,ExplorationMaps.render_column({"meta":{"min":[0,0,0],"dimension":"overworld"},"seed":1},source,i,colors))
	var image := Image.new(); image.load_png_from_buffer(ExplorationMaps.finish_image(build,true))
	var old := Image.new(); old.load_png_from_buffer(ExplorationMaps.finish_image(build,false))
	for z in 128:
		for x in 128:
			var c: Array = ref.pixels[z][x]
			var wanted := Color(roundf(float(c[0]))/255,roundf(float(c[1]))/255,roundf(float(c[2]))/255)
			check(image.get_pixel(x,127-z).is_equal_approx(wanted),"Actual source voxel compositor "+str(Vector2i(x,z)))
			check(old.get_pixel(x,z).is_equal_approx(image.get_pixel(x,127-z)),"Legacy image orientation is retained")
	var ready: Dictionary = {"meta":metadata,"png":Marshalls.raw_to_base64(image.save_png_to_buffer())}
	check(maps.accept_remote("5",ready),"A valid host image is accepted")
	check(maps.accept_remote("5",{"meta":metadata,"png":""}) and maps.records["5"].png == ready.png,"A delayed pending response cannot erase a completed host image")
	check(not maps.accept_remote("6",ready),"An image cannot be stored under another map identity")
	var small := Image.create(2,2,false,Image.FORMAT_RGB8)
	check(not maps.accept_remote("5",{"meta":metadata,"png":Marshalls.raw_to_base64(small.save_png_to_buffer())}),"A host map must have the registered 128 by 128 dimensions")
	maps.restore(maps.snapshot())
	check(maps.records["5"].get("remote",false) and maps.records["5"].png == ready.png,"Restoring a guest cache preserves host ownership and pixels")
	game.free()
	print("MAP SOURCE: %d origins, %d markers, 16384 pixels; %d passed, %d failed"%[ref.origins.size(),ref.markers.size(),passed,failed])
	quit(1 if failed else 0)
