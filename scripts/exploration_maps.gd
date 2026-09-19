class_name ExplorationMaps
extends RefCounted

# Source: Mineclonia mcl_maps/init.lua. See docs/maps-source.md.
const SIZE = 128
const NO_HEIGHT = -2147483648
var game: Node3D
var records: Dictionary = {}
var next_id: int = 0
var textures: Dictionary = {}
var sources: Dictionary = {}
var builds: Dictionary = {}
var job: Dictionary = {}
var retired: Array = []
var view_id: String = ""
var view_image: TextureRect
var view_status: Label
var view_marker: Label
var held_panel: Panel
var held_image: TextureRect
var held_status: Label
var held_marker: Label
var placeholder: Texture2D

func _init(owner_game: Node3D) -> void:
	game = owner_game

static func origin(position: Vector3) -> Vector3i:
	return Vector3i(floori(position.x/SIZE)*SIZE,floori(position.y/SIZE)*SIZE,floori(position.z/SIZE)*SIZE)

static func clean_data(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("id") is String or not str(raw.id).is_valid_int() or int(raw.id) < 0: return {}
	if raw.get("dimension","") not in ["overworld","nether","end"]: return {}
	if not raw.get("min") is Array or raw.min.size() != 3: return {}
	var point: Array = []
	for value in raw.min:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > 32000: return {}
		point.append(floori(float(value)/SIZE)*SIZE)
	return {"id":str(int(raw.id)),"dimension":str(raw.dimension),"min":point,"created":maxi(0,int(raw.get("created",0)))}

static func craft_output_data(ingredients: Array) -> Dictionary:
	for slot in ingredients:
		if int(slot.get("id",0)) != VillageContent.FILLED_MAP: continue
		var metadata: Dictionary = slot.get("data",{}).duplicate(true)
		var map: Dictionary = clean_data(metadata.get("map",{}))
		if map.is_empty(): return {"error":"Open this legacy map before copying it."}
		metadata.map = map
		return metadata
	return {"error":"Copying needs a filled map."}

static func special_recipe(grid: Array) -> Dictionary:
	var ingredients: Dictionary = {}
	for slot in grid:
		var id: int = int(slot.get("id",0))
		if id == 0: continue
		if id not in [VillageContent.EMPTY_MAP,VillageContent.FILLED_MAP]: return {}
		ingredients[id] = int(ingredients.get(id,0))+1
	if ingredients != {VillageContent.EMPTY_MAP:1,VillageContent.FILLED_MAP:1}: return {}
	return {"name":"Copy map","id":VillageContent.FILLED_MAP,"count":2,"ingredients":ingredients,"station":"hand","dynamic":true,"shapeless":true,"pattern":[VillageContent.FILLED_MAP,VillageContent.EMPTY_MAP],"width":2}

func reset() -> void:
	# Never wait for terrain generation on the main thread. At most one retired
	# column finishes in the background; it cannot publish into the new world.
	if not job.is_empty(): retired.append(job); job = {}
	records.clear(); textures.clear(); sources.clear(); builds.clear(); next_id = 0; view_id = ""
	if is_instance_valid(held_panel): held_panel.queue_free()

func snapshot() -> Dictionary:
	return {"version":1,"next_id":next_id,"records":records.duplicate(true)}

func restore(value: Variant) -> void:
	reset()
	if not value is Dictionary or not value.get("records") is Dictionary: return
	next_id = maxi(0,int(value.get("next_id",0)))
	for key in value.records:
		var raw: Variant = value.records[key]
		if not raw is Dictionary: continue
		var metadata: Dictionary = clean_data(raw.get("meta",{}))
		if metadata.is_empty() or metadata.id != str(key): continue
		var record: Dictionary = {"meta":metadata,"seed":int(raw.get("seed",game.world.seed_value)),"edits":[],"png":""}
		if raw.get("png") is String and str(raw.png).length() <= 200000:
			var png: PackedByteArray = Marshalls.base64_to_raw(raw.png)
			var image := Image.new()
			if not png.is_empty() and image.load_png_from_buffer(png) == OK and image.get_size() == Vector2i(SIZE,SIZE): record.png = str(raw.png)
		if record.png.is_empty() and raw.get("edits") is Array:
			var minimum := Vector3i(int(metadata.min[0]),int(metadata.min[1]),int(metadata.min[2]))
			for entry in raw.edits:
				if not entry is Array or entry.size() != 4: continue
				var p := Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))
				if in_cube(p,minimum) and Nodes.exists(int(entry[3])): record.edits.append([p.x,p.y,p.z,int(entry[3])])
		records[metadata.id] = record
		next_id = maxi(next_id,int(metadata.id)+1)

static func in_cube(p: Vector3i, minimum: Vector3i) -> bool:
	return p.x >= minimum.x and p.x < minimum.x+SIZE and p.y >= minimum.y and p.y < minimum.y+SIZE and p.z >= minimum.z and p.z < minimum.z+SIZE

func create(position: Vector3, dimension: String = "") -> Dictionary:
	if dimension.is_empty(): dimension = game.dimension
	var minimum: Vector3i = origin(position)
	var metadata: Dictionary = {"id":str(next_id),"dimension":dimension,"min":[minimum.x,minimum.y,minimum.z],"created":int(Time.get_unix_time_from_system())}
	next_id += 1
	_capture(metadata)
	return {"id":VillageContent.FILLED_MAP,"count":1,"wear":0,"data":{"map":metadata.duplicate(true)}}

func _capture(metadata: Dictionary) -> void:
	var minimum := Vector3i(int(metadata.min[0]),int(metadata.min[1]),int(metadata.min[2]))
	var record: Dictionary = {"meta":metadata.duplicate(true),"seed":game.world.seed_value,"edits":[],"png":""}
	var source: Dictionary = {"loaded":{},"columns":{},"edits":{}}
	if metadata.dimension == game.dimension:
		for p in game.world.edits:
			if in_cube(p,minimum): record.edits.append([p.x,p.y,p.z,int(game.world.edits[p])])
		for cz in range(minimum.z/16,(minimum.z+SIZE)/16):
			for cx in range(minimum.x/16,(minimum.x+SIZE)/16):
				var column := Vector2i(cx,cz)
				if not game.world.columns.has(column): continue
				source.columns[column] = true
				for cy in range(minimum.y/16,(minimum.y+SIZE)/16):
					var block := Vector3i(cx,cy,cz)
					if game.world.blocks.has(block): source.loaded[block] = game.world.blocks[block].data.duplicate()
	else:
		for entry in game.dimension_states.get(metadata.dimension,{}).get("edits",[]):
			if entry is Array and entry.size() == 4 and in_cube(Vector3i(int(entry[0]),int(entry[1]),int(entry[2])),minimum): record.edits.append(entry.duplicate())
	for entry in record.edits: source.edits[Vector3i(entry[0],entry[1],entry[2])] = int(entry[3])
	records[metadata.id] = record; sources[metadata.id] = source

func ensure(slot: Dictionary) -> Dictionary:
	if int(slot.get("id",0)) != VillageContent.FILLED_MAP: return {}
	var metadata: Dictionary = clean_data(slot.get("data",{}).get("map",{}))
	if metadata.is_empty():
		metadata = create(game.player.position).data.map
		if not slot.has("data"): slot.data = {}
		slot.data.map = metadata.duplicate(true)
	elif not records.has(metadata.id):
		next_id = maxi(next_id,int(metadata.id)+1)
		_capture(metadata)
	return metadata

func use() -> bool:
	var slot: Dictionary = game.inventory.held()
	if int(slot.get("id",0)) not in [VillageContent.EMPTY_MAP,VillageContent.FILLED_MAP]: return false
	if slot.id == VillageContent.EMPTY_MAP:
		var filled: Dictionary = create(game.player.position)
		# Source consumes one empty map in creative too; an overflow is dropped.
		game.inventory.consume_selected()
		var leftover: int = game.inventory.add_item(filled.id,1,0,filled.data)
		if leftover: game.spawn_drop(game.player.position+Vector3.UP,filled.id,leftover,0,filled.data)
		show_map(filled)
	else: show_map(slot)
	return true

func copy_map(index: int = -1) -> bool:
	if index < 0:
		if game.inventory.held().id == VillageContent.FILLED_MAP: index = game.inventory.selected
		else:
			for i in game.inventory.slots.size():
				if game.inventory.slots[i].id == VillageContent.FILLED_MAP: index = i; break
	if index < 0 or index >= game.inventory.slots.size() or game.inventory.slots[index].id != VillageContent.FILLED_MAP:
		game.toast("Bring a filled map and an empty map."); return false
	ensure(game.inventory.slots[index])
	var original: Dictionary = game.inventory.slots[index]
	var trial := Inventory.new(); trial.slots = game.inventory.slots.duplicate(true)
	if not trial.remove_item(VillageContent.EMPTY_MAP,1): game.toast("Copying needs one empty map."); return false
	if trial.add_item(VillageContent.FILLED_MAP,1,original.wear,original.data) > 0:
		game.toast("Make room for the copied map."); return false
	game.inventory.slots = trial.slots; game.inventory.changed.emit(); game.sound("place")
	game.toast("Copied map #"+str(original.data.map.id)+"."); return true

func _prepare(id: String) -> void:
	var record: Dictionary = records[id]
	if not sources.has(id):
		var edits: Dictionary = {}
		for entry in record.edits: edits[Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))] = int(entry[3])
		sources[id] = {"loaded":{},"columns":{},"edits":edits}
	var rgb := PackedFloat32Array(); rgb.resize(SIZE*SIZE*3)
	var heights := PackedInt32Array(); heights.resize(SIZE*SIZE); heights.fill(NO_HEIGHT)
	var opaque := PackedByteArray(); opaque.resize(SIZE*SIZE)
	builds[id] = {"column":0,"rgb":rgb,"heights":heights,"opaque":opaque}

func update() -> void:
	for old in retired.duplicate():
		if WorkerThreadPool.is_task_completed(old.task): WorkerThreadPool.wait_for_task_completion(old.task); retired.erase(old)
	if not job.is_empty() and WorkerThreadPool.is_task_completed(job.task):
		WorkerThreadPool.wait_for_task_completion(job.task)
		var id: String = job.id
		if records.has(id) and builds.has(id):
			if job.kind == "finish":
				records[id].png = Marshalls.raw_to_base64(job.result)
				records[id].edits.clear(); builds.erase(id); sources.erase(id)
				if game.survival != null: game.survival.refresh_displays()
			else: _apply_samples(builds[id],job.result)
		job = {}
	if job.is_empty() and retired.is_empty():
		for id in records:
			if not str(records[id].png).is_empty(): continue
			if not builds.has(id): _prepare(id)
			var work: Dictionary = {"id":str(id),"kind":"column","result":{}}
			if int(builds[id].column) >= 64:
				work.kind = "finish"
				var snapshot_build: Dictionary = builds[id].duplicate()
				work.task = WorkerThreadPool.add_task(func(): work.result = finish_image(snapshot_build),false,"Encode persistent map")
			else:
				var record: Dictionary = records[id].duplicate(true)
				var source: Dictionary = sources[id]
				var column: int = builds[id].column
				work.task = WorkerThreadPool.add_task(func(): work.result = render_column(record,source,column),false,"Survey map column")
			job = work; break
	_update_views()

static func map_color(id: int) -> Color:
	if id == Nodes.AIR: return Color.TRANSPARENT
	var color: Color = Nodes.color(id)
	# Keep the source catalogue's alpha for the matching basic materials;
	# RGB uses Voxey's own palette, and other plants use a generic coverage.
	if Fluids.water(id): color.a = 224.0/255.0
	elif id == Nodes.GLASS: color.a = 64.0/255.0
	elif WoodTypes.is_leaves(id): color.a = 181.0/255.0
	elif id == Nodes.FLOWER: color.a = 58.0/255.0
	elif id == Nodes.SUGAR_CANE: color.a = 132.0/255.0
	elif id == Nodes.RIPE_WHEAT: color.a = 97.0/255.0
	elif id == Nodes.WHEAT: color.a = 27.0/255.0
	elif WoodTypes.is_sapling(id): color.a = 138.0/255.0
	elif id == Nodes.BROWN_MUSHROOM: color.a = 28.0/255.0
	elif id == Nodes.RED_MUSHROOM: color.a = 34.0/255.0
	elif Nodes.plant(id): color.a = 0.55
	else: color.a = 1.0
	return color

static func render_column(record: Dictionary, source: Dictionary, index: int) -> Dictionary:
	var minimum := Vector3i(int(record.meta.min[0]),int(record.meta.min[1]),int(record.meta.min[2]))
	var column := Vector2i(minimum.x/16+index%8,minimum.z/16+index/8)
	var blocks: Dictionary = {}; var edits: Dictionary = {}
	for p in source.edits:
		if floori(p.x/16.0) == column.x and floori(p.z/16.0) == column.y: edits[p] = source.edits[p]
	if source.columns.has(column):
		for cy in range(minimum.y/16,(minimum.y+SIZE)/16):
			var key := Vector3i(column.x,cy,column.y)
			if source.loaded.has(key): blocks[cy] = source.loaded[key]
	else:
		var gen := TerrainGenerator.new(int(record.seed),str(record.meta.dimension))
		if minimum.y < gen.terrain_ceiling() and minimum.y+SIZE > gen.min_y():
			var generated: Dictionary = gen.generate_column(column,edits,true)
			for block in generated.blocks:
				if int(block.y)*16 >= minimum.y and int(block.y)*16 < minimum.y+SIZE: blocks[int(block.y)] = block.data
	var rgb := PackedFloat32Array(); rgb.resize(256*3)
	var heights := PackedInt32Array(); heights.resize(256); heights.fill(NO_HEIGHT)
	var opaque := PackedByteArray(); opaque.resize(256)
	if blocks.is_empty() and edits.is_empty(): return {"index":index,"rgb":rgb,"heights":heights,"opaque":opaque}
	var palette: Dictionary = {}
	for z in 16:
		for x in 16:
			var pixel: int = x+z*16; var alpha: float = 0.0; var aggregate := Vector3.ZERO
			for y in range(minimum.y+SIZE-1,minimum.y-1,-1):
				var p := Vector3i(column.x*16+x,y,column.y*16+z)
				var id: int = int(edits[p]) if edits.has(p) else (int(blocks[floori(y/16.0)][x+z*16+posmod(y,16)*256]) if blocks.has(floori(y/16.0)) else Nodes.AIR)
				if id == Nodes.AIR: continue
				if not palette.has(id): palette[id] = map_color(id)
				var color: Color = palette[id]; var factor: float = color.a*(1.0-alpha)
				aggregate += Vector3(color.r,color.g,color.b)*255.0*factor; alpha += factor
				if alpha > 0.70 and heights[pixel] == NO_HEIGHT: heights[pixel] = y
				if alpha >= 0.99: opaque[pixel] = 1; break
			rgb[pixel*3] = aggregate.x; rgb[pixel*3+1] = aggregate.y; rgb[pixel*3+2] = aggregate.z
	return {"index":index,"rgb":rgb,"heights":heights,"opaque":opaque}

static func _apply_samples(build: Dictionary, sample: Dictionary) -> void:
	var base_x: int = int(sample.index)%8*16; var base_z: int = int(sample.index)/8*16
	for z in 16:
		for x in 16:
			var src: int = x+z*16; var dst: int = base_x+x+(base_z+z)*SIZE
			for channel in 3: build.rgb[dst*3+channel] = sample.rgb[src*3+channel]
			build.heights[dst] = sample.heights[src]; build.opaque[dst] = sample.opaque[src]
	build.column += 1

static func finish_image(build: Dictionary) -> PackedByteArray:
	var pixels := PackedByteArray(); pixels.resize(SIZE*SIZE*3)
	for x in SIZE:
		var last_height: int = NO_HEIGHT
		for z in SIZE:
			var pixel: int = x+z*SIZE; var height: int = build.heights[pixel]; var shade: int = 0
			if build.opaque[pixel] and height != NO_HEIGHT and last_height != NO_HEIGHT: shade = clampi((height-last_height)*8,-32,32)
			for channel in 3: pixels[pixel*3+channel] = clampi(roundi(float(build.rgb[pixel*3+channel])+shade),0,255)
			last_height = height
	return Image.create_from_data(SIZE,SIZE,false,Image.FORMAT_RGB8,pixels).save_png_to_buffer()

func texture(id: String) -> Texture2D:
	if textures.has(id): return textures[id]
	if records.has(id) and not str(records[id].png).is_empty():
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(records[id].png)) == OK:
			textures[id] = ImageTexture.create_from_image(image); return textures[id]
	if placeholder == null:
		var image := Image.create(SIZE,SIZE,false,Image.FORMAT_RGB8); image.fill(Color("d9c99a"))
		placeholder = ImageTexture.create_from_image(image)
	return placeholder

func frame_model(slot: Dictionary) -> MeshInstance3D:
	var metadata: Dictionary = ensure(slot)
	var mesh := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(0.85,0.85); mesh.mesh = quad
	# Existing frames face negative Z. Turn the quad's front toward the viewer
	# so the saved image is not horizontally mirrored through its back face.
	mesh.rotation.y = PI
	var material := StandardMaterial3D.new(); material.albedo_texture = texture(str(metadata.get("id","")))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	return mesh

static func marker(metadata: Dictionary, position: Vector3, dimension: String, yaw: float) -> Dictionary:
	if metadata.is_empty() or metadata.dimension != dimension: return {"visible":false}
	var x: float = roundf(position.x)-float(metadata.min[0]); var z: float = roundf(position.z)-float(metadata.min[2])
	var outside: bool = x < 0 or x > SIZE-1 or z < 0 or z > SIZE-1
	return {"visible":true,"pixel":Vector2(clampf(x,0,SIZE-1),clampf(z,0,SIZE-1)),"outside":outside,"rotation":-roundf(yaw/(PI/2.0))*(PI/2.0)}

func show_map(slot: Dictionary = {}) -> bool:
	if slot.is_empty():
		if game.state == "map" and records.has(view_id): slot = {"id":VillageContent.FILLED_MAP,"count":1,"wear":0,"data":{"map":records[view_id].meta}}
		elif game.inventory.held().id == VillageContent.FILLED_MAP: slot = game.inventory.held()
		else:
			for candidate in game.inventory.slots:
				if candidate.id == VillageContent.FILLED_MAP: slot = candidate; break
	if slot.is_empty() or slot.get("id",0) != VillageContent.FILLED_MAP:
		game.toast("Use an empty map to survey this region first."); return false
	var metadata: Dictionary = ensure(slot); view_id = metadata.id
	game.state = "map"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud._clear(); game.hud.screen = "map"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(620,610))
	game.hud._label(panel,"MAP #"+view_id+" · "+str(metadata.dimension).to_upper(),Vector2(24,16),23,game.hud.ACCENT)
	view_image = _image(panel,Vector2(80,58),460)
	view_marker = _marker(view_image)
	view_status = game.hud._label(panel,"",Vector2(24,527),14,game.hud.MUTED)
	game.hud._button(panel,"Done",Rect2(24,565,572,32),game.resume)
	_update_views(); return true

func _image(parent: Control, position: Vector2, size: float) -> TextureRect:
	var image := TextureRect.new(); image.position = position; image.size = Vector2.ONE*size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(image); return image

func _marker(parent: Control) -> Label:
	var label := Label.new(); label.text = "▲"; label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color.WHITE); label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.pivot_offset = Vector2(9,12); parent.add_child(label); return label

func _paint(id: String, image: TextureRect, label: Label, pointer: Label) -> void:
	if not records.has(id): return
	var record: Dictionary = records[id]; var metadata: Dictionary = record.meta
	image.texture = texture(id)
	var ready: bool = not str(record.png).is_empty()
	if not ready: label.text = "Surveying region… %d / 64 columns"%int(builds.get(id,{}).get("column",0))
	elif image.size.x < 300: label.text = "Map #"+id+" · North ↑\n1 block / pixel"
	else: label.text = "North ↑ · 1 block / pixel · snapshot #"+id+"\nX %d–%d · Z %d–%d · Y %d–%d"%[metadata.min[0],int(metadata.min[0])+127,metadata.min[2],int(metadata.min[2])+127,metadata.min[1],int(metadata.min[1])+127]
	var mark: Dictionary = marker(metadata,game.player.position,game.dimension,game.player.rotation.y)
	pointer.visible = ready and mark.visible
	if pointer.visible:
		pointer.text = "●" if mark.outside else "▲"; pointer.rotation = 0.0 if mark.outside else mark.rotation
		pointer.position = mark.pixel/(SIZE-1.0)*(image.size-Vector2(18,24))

func _update_views() -> void:
	if game.state == "map" and is_instance_valid(view_image) and is_instance_valid(view_status): _paint(view_id,view_image,view_status,view_marker)
	var held: Dictionary = game.inventory.held()
	if game.state != "playing" or held.id != VillageContent.FILLED_MAP:
		if is_instance_valid(held_panel): held_panel.queue_free(); held_panel = null
		return
	var metadata: Dictionary = ensure(held)
	if not is_instance_valid(held_panel):
		held_panel = Panel.new(); held_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; held_panel.size = Vector2(224,248)
		game.hud.layer.add_child(held_panel); held_image = _image(held_panel,Vector2(12,12),200); held_marker = _marker(held_image)
		held_status = game.hud._label(held_panel,"",Vector2(10,218),10,game.hud.MUTED)
	held_panel.position = Vector2(maxf(4,game.hud.size.x-248),maxf(4,game.hud.size.y-370))
	_paint(metadata.id,held_image,held_status,held_marker)
