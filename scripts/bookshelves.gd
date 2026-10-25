class_name Bookshelves
extends RefCounted

# Mineclonia mcl_books/chiseled_bookshelf.lua. Original native implementation.
const ID = 11546
const BLOCKS = [ID]
const SLOTS = 6
const SLOT_COLUMNS = 3
const SLOT_ROWS = 2
const FRONTS = [Vector3i.FORWARD,Vector3i.LEFT,Vector3i.BACK,Vector3i.RIGHT]
const DATA = {11546:{"name":"Chiseled bookshelf","block":true,"shape":"cube","color":"a5814f","hardness":1.5,"tool":1,"family":"bookshelf","flammable":true,"fuel":15}}
static var textures: Dictionary = {}

static func empty() -> Dictionary:
	return {"id":0,"count":0,"wear":0}

static func is_book(id: int) -> bool:
	return id in [Nodes.BOOK,Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK,VillageContent.ENCHANTED_BOOK]

# The plain shelf has a separate 27-slot inventory. Its player put/take
# callbacks accept the book group and enchanted books (mcl_books/init.lua).
static func plain_allows(id: int) -> bool:
	return id == Nodes.AIR or is_book(id)

static func clean_state(record: Dictionary) -> void:
	var entries: Array = record.get("slots",[]) if record.get("slots") is Array else []
	var books: Array = []
	for i in SLOTS:
		var item: Dictionary = Inventory.clean_slot(entries[i]) if i < entries.size() else empty()
		if not is_book(int(item.id)) or item.count <= 0: item = empty()
		else: item.count = 1
		books.append(item)
	record.slots = books; record.kind = "bookshelf"; record.shelf_ready = true
	record.last_slot = clampi(int(record.get("last_slot",0)),0,6)
	record.facing = posmod(int(record.get("facing",0)),4)

static func state(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if world.node_at(p) != ID:
		var unused: Dictionary = {}; clean_state(unused); return unused
	if not world.stations.has(key): world.stations[key] = {}
	var record: Dictionary = world.stations[key]
	if not record.get("shelf_ready",false) or not record.get("slots") is Array or record.slots.size() != SLOTS: clean_state(record)
	if not record.has("facing"): record.facing = 0
	return record

static func slots(world: VoxelWorld, p: Vector3i) -> Array: return state(world,p).slots
static func filled(world: VoxelWorld, p: Vector3i) -> int:
	var count: int = 0
	for slot in slots(world,p):
		if slot.id != 0: count += 1
	return count

static func bits(world: VoxelWorld, p: Vector3i) -> int:
	var result: int = 0; var books: Array = slots(world,p)
	for i in SLOTS:
		if books[i].id != 0: result |= 1 << i
	return result

static func facing(world: VoxelWorld, p: Vector3i) -> int: return posmod(int(state(world,p).facing),4)
static func front(world: VoxelWorld, p: Vector3i) -> Vector3i: return FRONTS[facing(world,p)]
static func facing_for_yaw(yaw: float) -> int: return posmod(int(floorf(yaw/(PI/2)+0.5))+2,4)

# Source get_surface_sixth: top row first; the horizontal coordinate reverses
# on the opposite face. Exact boundaries retain the source's floor arithmetic.
static func slot_at(hit: Vector3, face: int) -> int:
	var vertical: int = 3 if hit.y < 0.5 else 0
	match posmod(face,4):
		0: return vertical+2-floori((1-hit.x)*3)
		1: return vertical+floori((1-hit.z)*3)
		2: return vertical+floori((1-hit.x)*3)
		_: return vertical+2-floori((1-hit.z)*3)

static func redraw(world: VoxelWorld, p: Vector3i, index: int = -1) -> void:
	if index >= 0: state(world,p).last_slot = index+1
	world.circuits.notify_observers(p)
	var game: Node = world.get_parent()
	if game != null and game.get("survival") != null: game.survival.refresh_displays()

static func insert(world: VoxelWorld, p: Vector3i, index: int, held: Dictionary) -> bool:
	if world.node_at(p) != ID or index < 0 or index >= SLOTS or not is_book(int(held.get("id",0))) or int(held.get("count",0)) <= 0: return false
	var books: Array = slots(world,p)
	if books[index].id != 0: return false
	var item: Dictionary = Inventory.clean_slot(held); item.count = 1
	books[index] = item; redraw(world,p,index)
	return true

static func take(world: VoxelWorld, p: Vector3i, index: int) -> Dictionary:
	if world.node_at(p) != ID or index < 0 or index >= SLOTS: return {}
	var books: Array = slots(world,p)
	if books[index].id == 0: return {}
	var item: Dictionary = books[index].duplicate(true)
	books[index] = empty(); redraw(world,p,index)
	return item

static func hopper_in(world: VoxelWorld, p: Vector3i, item: Dictionary) -> bool:
	for i in SLOTS:
		if slots(world,p)[i].id == 0: return insert(world,p,i,item)
	return false

# Source move_item_container selects the first occupied slot; if that item
# cannot fit, it does not skip ahead to a later book.
static func hopper_out(world: VoxelWorld, p: Vector3i, destination: Array) -> bool:
	for i in SLOTS:
		var item: Dictionary = slots(world,p)[i]
		if item.id == 0: continue
		if not RedstoneCircuit.insert_one(destination,item): return false
		take(world,p,i); return true
	return false

static func comparator_output(world: VoxelWorld, p: Vector3i) -> int:
	return clampi(int(state(world,p).last_slot),0,6)

static func contents(world: VoxelWorld, p: Vector3i) -> Array:
	var result: Array = []
	for item in slots(world,p):
		if item.id != 0: result.append(item.duplicate(true))
	return result

static func info(world: VoxelWorld, p: Vector3i) -> PackedStringArray:
	var lines := PackedStringArray()
	for item in slots(world,p):
		if item.id == 0: continue
		var data: Dictionary = item.get("data",{})
		var title: String = str(data.get("custom_name",data.get("title",Nodes.title(item.id))))
		if title.is_empty(): title = Nodes.title(item.id)
		if not str(data.get("author","")).is_empty(): title += " · "+str(data.author)
		for enchant in data.get("enchantments",{}): title += " · "+str(enchant)
		lines.append(title.replace("\n"," ").left(90))
	return lines

static func click(world: VoxelWorld, p: Vector3i, index: int, held: Dictionary) -> Dictionary:
	var hand: Dictionary = Inventory.clean_slot(held)
	if index < 0 or index >= SLOTS: return {"hand":hand,"drop":{}}
	var item: Dictionary = take(world,p,index)
	if not item.is_empty():
		if hand.id == 0: hand = item
		elif hand.id == item.id and hand.wear == item.wear and hand.get("data",{}) == item.get("data",{}) and hand.count < Nodes.max_stack(hand.id): hand.count += 1
		else: return {"hand":hand,"drop":item}
	elif insert(world,p,index,hand):
		hand.count -= 1
		if hand.count <= 0: hand = empty()
	else: redraw(world,p)
	return {"hand":hand,"drop":{}}

static func interact(game: Node3D, p: Vector3i, normal: Vector3i, hit: Vector3, bag: Inventory) -> bool:
	if game.world.node_at(p) != ID or normal != front(game.world,p) or not hit.is_finite(): return false
	if hit.x < -0.001 or hit.x > 1.001 or hit.y < -0.001 or hit.y > 1.001 or hit.z < -0.001 or hit.z > 1.001: return false
	var result: Dictionary = click(game.world,p,slot_at(hit,facing(game.world,p)),bag.held())
	bag.slots[bag.selected] = result.hand; bag.changed.emit()
	if not result.drop.is_empty():
		var item: Dictionary = result.drop
		game.spawn_drop(Vector3(p+normal)+Vector3.ONE*0.5,item.id,item.count,item.wear,item.get("data",{}))
	game.sound("place"); return true

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or int(target.id) != ID: return false
	var p: Vector3i = target.pos; var normal: Vector3i = target.get("normal",Vector3i.ZERO)
	if normal != front(game.world,p): return false
	var hit: Vector3 = target.get("point",Vector3(p)+Vector3.ONE*0.5)-Vector3(p)
	if game.network != null and game.network.client():
		game.network.use_bookshelf.rpc_id(1,p,normal,hit,game.player.position,game.network.inventory_snapshot()); return true
	return interact(game,p,normal,hit,game.inventory)

static func try_place(game: Node3D, target: Dictionary) -> bool:
	if game.inventory.held().id != ID or target.is_empty(): return false
	if game.network != null and game.network.client():
		game.network.place_bookshelf.rpc_id(1,target.pos,int(target.id),target.normal,game.player.rotation.y,game.player.position,game.network.inventory_snapshot())
	else: place(game,target,game.inventory,game.player.rotation.y)
	return true

static func place(game: Node3D, target: Dictionary, bag: Inventory, yaw: float) -> bool:
	if bag.held().id != ID or bag.held().count <= 0: return false
	var normal: Vector3i = target.get("normal",Vector3i.ZERO)
	if absi(normal.x)+absi(normal.y)+absi(normal.z) != 1 or not is_finite(yaw): return false
	var at: Vector3i = target.get("replace",target.pos if Doors.replaceable(game.world.node_at(target.pos)) else target.pos+target.normal)
	if not game.world.loaded_at(Vector3(at)) or not Doors.replaceable(game.world.node_at(at)): return false
	if not game.world.set_node(at,ID): return false
	state(game.world,at).facing = facing_for_yaw(yaw)
	if game.gamemode != "creative": bag.consume_selected()
	redraw(game.world,at); game.sound("place"); game.api.emit_node_placed(at,ID)
	return true

static func rotate(world: VoxelWorld, p: Vector3i) -> bool:
	state(world,p).facing = posmod(facing(world,p)+1,4)
	redraw(world,p); return true

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id == ID and id != ID: world.stations.erase(VoxelWorld.station_key(p))
	if id == ID: state(world,p)

static func break_node(game: Node3D, p: Vector3i, id: int, tool: int, blast: bool = false) -> bool:
	if id != ID: return false
	var books: Array = contents(game.world,p)
	var held: Dictionary = game.inventory.held() if game.inventory.held().id == tool else {"id":tool}
	var harvested: Dictionary = Harvesting.harvest(ID,held)
	if not game.world.set_node(p,Nodes.AIR): return true
	# after_dig_node drops the metadata inventory even for a creative dig and
	# the explosion engine's dig_node path. The block itself needs Silk Touch.
	for item in books: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,item.id,item.count,item.wear,item.get("data",{}))
	if not blast and game.gamemode != "creative":
		for entry in harvested.get("drops",[]): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	game._break_particles(p,id); game.sound("break"); game.api.emit_node_broken(p,id)
	game.survival.refresh_displays(); return true

static func recipes(inv: Inventory) -> void:
	var p: int = Nodes.PLANKS; var slab: int = BuildingShapes.slab_for(p)
	inv._recipe("Chiseled bookshelf",ID,1,[p,p,p,slab,slab,slab,p,p,p],3,"table")
	inv.recipes.back()["wood_slab_group"] = true

static func texture(mask: int) -> Texture2D:
	if textures.has(mask): return textures[mask]
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var shade: Color = pixel(ID,x,y,Color("b29365")) if mask >= 0 else Color("a5814f").darkened(0.12 if y%4 == 0 else 0)
			img.set_pixel(x,y,shade)
	if mask >= 0:
		for i in SLOTS:
			var rect: Rect2i = slot_rect(i)
			img.fill_rect(rect,Color("493529"))
			if mask & (1 << i):
				img.fill_rect(rect,slot_color(i)); img.fill_rect(Rect2i(rect.position+Vector2i(0,1),Vector2i(rect.size.x,1)),Color("e5cc8e"))
	textures[mask] = ImageTexture.create_from_image(img)
	return textures[mask]

static func display_model(world: VoxelWorld, p: Vector3i) -> Node3D:
	var root := Node3D.new(); root.position = Vector3(p)+Vector3.ONE*0.5; root.rotation.y = facing(world,p)*PI/2
	var box := MeshInstance3D.new(); var shape := BoxMesh.new(); shape.size = Vector3.ONE*1.001; box.mesh = shape
	var wood := StandardMaterial3D.new(); wood.albedo_texture = texture(-1); wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; box.material_override = wood; root.add_child(box)
	var face := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2.ONE; face.mesh = quad; face.position.z = -0.502
	var mat := StandardMaterial3D.new(); mat.albedo_texture = texture(bits(world,p)); mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; face.material_override = mat; root.add_child(face)
	return root

# --- art ---------------------------------------------------------------------

# The shelf's front face draws one book per filled slot, from the saved pattern, so
# the display matches the source's 64-node trick without 64 ids. The mesher asks for
# a tile, and this module also exposes the per-slot overlay.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	# A plank body with the shelf frame: a raised border and two shelf lines.
	if x in [0,15] or y in [0,15]: return base.darkened(0.4)
	if y in [7,8]: return base.darkened(0.45)
	if x in [5,10]: return base.darkened(0.2)
	return noise.lerp(base,0.75)

# The colour of the book in a slot, which is the source's per-slot book texture.
static func slot_color(index: int) -> Color:
	return [Color("b8433c"),Color("3f6fa8"),Color("4f8a44"),Color("c8a03c"),Color("8a4f9c"),Color("3f8a86")][clampi(index,0,SLOTS-1)]

# The slot's rectangle on a 16x16 face, for a caller drawing the overlay.
static func slot_rect(index: int) -> Rect2i:
	var column: int = index % SLOT_COLUMNS
	var row: int = index / SLOT_COLUMNS
	# Three books across each shelf, five pixels wide with a one-pixel gap.
	return Rect2i(1+column*5,1+row*8,4,6)
