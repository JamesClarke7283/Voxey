class_name Paintings
extends RefCounted

# Mineclonia ENTITIES/mcl_paintings, GPL-3.0-or-later. Original GDScript using the
# source as a behaviour reference; all art is original procedural code.
#
# The source registers one craftitem and hung the painting as a **wall entity**:
# the item carries the chosen motive in its metadata, and placing it against a
# wall picks the *largest* registered motive that fits the free space at the
# click, resolving ties at random. There is no node at all — the painting is a
# display entity that persists its facing and motive, and a punch removes it and
# returns the item.
#
# Voxey follows that shape. A hung painting is a record in
# `world.adventure_state.paintings`, keyed by its anchor cell — the same place
# boats and carts keep theirs, so it persists, streams and travels between
# dimensions with the rest of the world state. The motive travels in the item's
# `data["motive"]`, which is how the source's `mcl_paintings:placed_painting`
# metadata works.
#
# Source rules reproduced here:
# - The motive set is the source's own 26, from 1x1 to 4x4. Their sizes are
#   transcribed from `registrations.lua`.
# - Placement picks the largest-area motive that fits, breaking ties at random.
#   The free space is measured from the anchor cell rightward and upward, and a
#   cell is usable only when the block behind is solid, the painting cell itself
#   is replaceable, and no other painting already claims it.
# - A painting needs a horizontal wall: aiming at a floor or ceiling does
#   nothing.
# - Punching removes it and returns the item in survival.
# - The source's own recipe: three sticks, a wool centre row and three sticks.

# The source's `registrations.lua`, in its own order. `w` and `h` are the motive's
# size in blocks, `title` the display name.
const MOTIVES = [
	{"key":"ancient_octopus","title":"Ancient Octopus","w":1,"h":1},
	{"key":"snowy_mountain","title":"Snowy Mountain","w":1,"h":1},
	{"key":"balding_man","title":"Balding Man","w":1,"h":1},
	{"key":"poster","title":"Poster","w":1,"h":1},
	{"key":"notes","title":"Notes","w":1,"h":1},
	{"key":"viking_shield","title":"Viking Shield","w":1,"h":1},
	{"key":"butcher_knives","title":"Butcher Knives","w":1,"h":1},
	{"key":"green_bottles","title":"Green Bottles","w":2,"h":1},
	{"key":"battle_axe","title":"Battle Axe","w":2,"h":1},
	{"key":"cooking_utensils","title":"Cooking Utensils","w":2,"h":1},
	{"key":"dense_jungle_forest","title":"Dense Jungle Forest","w":2,"h":1},
	{"key":"endless_dunes","title":"Endless Dunes","w":2,"h":1},
	{"key":"green_banner","title":"Green Banner","w":1,"h":2},
	{"key":"red_banner","title":"Red Banner","w":1,"h":2},
	{"key":"quest_board","title":"Quest Board","w":4,"h":2},
	{"key":"support_truss","title":"Support Truss","w":2,"h":2},
	{"key":"froggy_pond","title":"Froggy Pond","w":2,"h":2},
	{"key":"moonshine_tundra","title":"Moonshine Tundra","w":2,"h":2},
	{"key":"desert_castle","title":"Desert Castle","w":2,"h":2},
	{"key":"sarmatian_decoration","title":"Sarmatian Decoration","w":2,"h":2},
	{"key":"decorative_swords","title":"Decorative Swords","w":2,"h":2},
	{"key":"gloom_gloom_mountain","title":"Gloom Gloom Mountain","w":4,"h":3},
	{"key":"elf_utopia","title":"Elf Utopia","w":4,"h":3},
	{"key":"waterfall_bridge","title":"Waterfall Bridge","w":4,"h":4},
	{"key":"mountain_tower","title":"Mountain Tower","w":4,"h":4},
	{"key":"volendam_costume","title":"Volendam Costume","w":4,"h":4},
]

# A motive's texture is drawn at sixteen pixels per block, so an image is as many
# pixels wide and tall as the motive is blocks.
static func canvas_side(size: int) -> int:
	return size*16

# The four horizontal facings, described by the wall the painting hangs on, in the
# same order as the source's `wallmounted` values 2..5.
const FACINGS = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]

static func motive(index: int) -> Dictionary: return MOTIVES[clampi(index,0,MOTIVES.size()-1)]
static func motive_of(item: Dictionary) -> int: return clampi(int(item.get("data",{}).get("motive",0)),0,MOTIVES.size()-1)

# The horizontal tangent of a wall facing, which is the direction a painting's
# width runs. This is the source's `rotate_dir_90_deg_clockwise`.
static func tangent(facing_index: int) -> Vector3i: return tangent_of_dir(FACINGS[clampi(facing_index,0,FACINGS.size()-1)])
static func tangent_of_dir(facing: Vector3i) -> Vector3i: return Vector3i(-facing.z,0,facing.x)

# The facing index for a wall normal, or -1 when the wall is not vertical.
static func facing_of(normal: Vector3i) -> int:
	if normal.y != 0: return -1
	return FACINGS.find(normal)

# --- geometry ----------------------------------------------------------------

# The cells a motive would occupy, anchored at `p` running along the tangent and
# upward. The first entry is the anchor itself.
static func cells(p: Vector3i, facing: int, width: int, height: int) -> Array:
	var t: Vector3i = tangent(facing)
	var list: Array = []
	for y in height:
		for x in width:
			list.append(p+t*x+Vector3i(0,y,0))
	return list

# Whether one motive fits at the anchor without overlapping or blocking.
static func fits(world: VoxelWorld, anchor: Vector3i, facing: int, index: int, taken: Dictionary) -> bool:
	var motive: Dictionary = MOTIVES[index]
	var t: Vector3i = tangent(facing)
	for y in int(motive.h):
		for x in int(motive.w):
			var cell: Vector3i = anchor+t*x+Vector3i(0,y,0)
			if taken.has(cell) or not open_cell(world,cell,facing): return false
	return true

# The largest-area motive that fits at the anchor, ties broken at random, or -1
# when nothing fits. A cell is usable when it is replaceable air, no painting
# already claims it and its block behind the wall is solid.
static func biggest_fit(world: VoxelWorld, anchor: Vector3i, facing: int, rng: RandomNumberGenerator) -> int:
	var taken: Dictionary = occupied(world)
	var candidates: Array = []
	var best_area: int = 0
	for index in MOTIVES.size():
		var motive: Dictionary = MOTIVES[index]
		if not fits(world,anchor,facing,index,taken): continue
		var area: int = int(motive.w)*int(motive.h)
		if area > best_area: best_area = area; candidates = [index]
		elif area == best_area: candidates.append(index)
	if candidates.is_empty(): return -1
	return int(candidates[rng.randi_range(0,candidates.size()-1)])

# A painting cell is open when it holds nothing solid and the block on the wall
# side of it is solid, which is the source's `is_node_okay_for_placement`.
static func open_cell(world: VoxelWorld, cell: Vector3i, facing: int) -> bool:
	if not world.loaded_at(Vector3(cell)): return false
	if not SnowCover.replaceable(world.node_at(cell)): return false
	var wall: Vector3i = cell-FACINGS[clampi(facing,0,FACINGS.size()-1)]
	return world.loaded_at(Vector3(wall)) and Nodes.solid(world.node_at(wall)) and not Nodes.transparent(world.node_at(wall))

# Every cell claimed by a hung painting, in world coordinates.
static func occupied(world: VoxelWorld) -> Dictionary:
	var result: Dictionary = {}
	for key in records(world):
		var entry: Dictionary = records(world)[key]
		var anchor: Vector3i = anchor_of(key)
		var facing: int = int(entry.get("facing",0))
		var motive: Dictionary = motive(int(entry.get("motive",0)))
		for cell in cells(anchor,facing,int(motive.w),int(motive.h)): result[cell] = true
	return result

# Whether any hung painting claims this cell, and the anchor that owns it.
static func anchor_for(world: VoxelWorld, cell: Vector3i) -> Dictionary:
	for key in records(world):
		var entry: Dictionary = records(world)[key]
		var anchor: Vector3i = anchor_of(key)
		var facing: int = int(entry.get("facing",0))
		var motive: Dictionary = motive(int(entry.get("motive",0)))
		if cell in cells(anchor,facing,int(motive.w),int(motive.h)): return {"key":key,"anchor":anchor,"entry":entry}
	return {}

# --- records -----------------------------------------------------------------

static func records(world: VoxelWorld) -> Dictionary:
	if not world.adventure_state.get("paintings") is Dictionary: world.adventure_state["paintings"] = {}
	return world.adventure_state.paintings

static func anchor_of(key: String) -> Vector3i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 3: return Vector3i.ZERO
	return Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))

static func key_of(p: Vector3i) -> String: return VoxelWorld.station_key(p)

# Hang a painting of `motive` at `anchor`, facing the wall normal. The caller has
# already checked that the motive fits; this only records it and refreshes the
# displays. Returns the record key.
static func hang(game: Node3D, anchor: Vector3i, facing: int, motive_index: int) -> String:
	var key: String = key_of(anchor)
	records(game.world)[key] = {"facing":facing,"motive":motive_index}
	if game.get("survival") != null: game.survival.refresh_displays()
	return key

# Remove a hung painting by its anchor cell, returning its record or an empty
# dictionary. `drop` also hands the item back, which is the source's punch.
static func remove(game: Node3D, key: String, drop: bool = false) -> Dictionary:
	var entry: Dictionary = records(game.world).get(key,{})
	if entry.is_empty(): return {}
	records(game.world).erase(key)
	if drop and game.gamemode != "creative":
		var anchor: Vector3i = anchor_of(key)
		game.spawn_drop(Vector3(anchor)+Vector3.ONE*0.5,VillageContent.PAINTING,1,0,{"motive":int(entry.get("motive",0))})
	if game.get("survival") != null: game.survival.refresh_displays()
	return entry

# --- interaction -------------------------------------------------------------

# `on_place`: the largest motive that fits the wall face the player aimed at.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != VillageContent.PAINTING or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var normal: Vector3i = target.get("normal",Vector3i.UP)
	var facing: int = facing_of(normal)
	if facing < 0:
		game.toast("Paintings hang on walls.")
		return true
	# The anchor is the air cell in front of the wall, which is where the source
	# places the entity (offset half a block from the face).
	var anchor: Vector3i = target.get("replace",target.pos+normal)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# The item's own motive wins when it fits, which is the source's
	# `mcl_paintings:placed_painting` reuse path; otherwise the largest motive that
	# fits the free space is chosen, ties broken at random.
	var taken: Dictionary = occupied(world)
	var chosen: int = motive_of(game.inventory.held())
	if not fits(world,anchor,facing,chosen,taken): chosen = biggest_fit(world,anchor,facing,rng)
	if chosen < 0:
		game.toast("There is no room for a painting here.")
		return true
	hang(game,anchor,facing,chosen)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place")
	game.player.swing = 1
	game.api.emit_node_placed(anchor,VillageContent.PAINTING)
	return true

# The painting the player is aiming at, by ray against each hung painting's box,
# or an empty dictionary. Mirrors `Boats.target`.
static func target(game: Node3D) -> Dictionary:
	var origin: Vector3 = game.player.camera.global_position
	var direction: Vector3 = -game.player.camera.global_basis.z
	var reach: float = minf(4.5,float(game.player.target.get("distance",4.5)))
	var best: Dictionary = {}
	var best_distance: float = reach+0.001
	for key in records(game.world):
		var entry: Dictionary = records(game.world)[key]
		var anchor: Vector3i = anchor_of(key)
		var face_dir: Vector3i = FACINGS[clampi(int(entry.get("facing",0)),0,FACINGS.size()-1)]
		var motive: Dictionary = motive(int(entry.get("motive",0)))
		var t: Vector3i = tangent(clampi(int(entry.get("facing",0)),0,FACINGS.size()-1))
		var width: float = float(motive.w); var height: float = float(motive.h)
		# The plane sits 1/16 in front of the wall, spanning width by height.
		var center: Vector3 = Vector3(anchor)+Vector3(t)*width*0.5+Vector3.UP*height*0.5-Vector3(face_dir)*0.02
		var half: Vector3 = Vector3(absf(float(t.x))*width*0.5+absf(float(face_dir.x))*0.03,height*0.5,absf(float(t.z))*width*0.5+absf(float(face_dir.z))*0.03)
		var box := AABB(center-half,half*2.0)
		var point: Variant = box.intersects_ray(origin,direction)
		if point is Vector3:
			var distance: float = origin.distance_to(point)
			if distance < best_distance: best_distance = distance; best = {"key":key,"entry":entry,"anchor":anchor}
	return best

# A punch on a painting removes it and returns the item. Used by the player's
# attack path before any block is mined.
static func punch_target(game: Node3D) -> bool:
	var hit: Dictionary = target(game)
	if hit.is_empty(): return false
	remove(game,str(hit.key),true)
	Hunger.exhaust(game.player,Hunger.ATTACK)
	game.player.swing = 1
	return true

# --- art ---------------------------------------------------------------------

# A hung painting is one quad carrying the motive's texture, sized to its blocks
# and offset one sixteenth from the wall so it does not z-fight the block behind.
static func display_model(game: Node3D, anchor: Vector3i, entry: Dictionary) -> MeshInstance3D:
	var facing_index: int = clampi(int(entry.get("facing",0)),0,FACINGS.size()-1)
	var face_dir: Vector3i = FACINGS[facing_index]
	var index: int = int(entry.get("motive",0))
	var motive: Dictionary = motive(index)
	var t: Vector3i = tangent(facing_index)
	var w: float = float(motive.w); var h: float = float(motive.h)
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new(); quad.size = Vector2(w,h)
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture(index)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	# The quad's front faces +Z by default; the wall is at -face_dir, so the painter
	# turns it to look away from the wall. The centre sits half the motive's size up
	# and along the tangent from the anchor.
	var center: Vector3 = Vector3(anchor)+Vector3(t)*w*0.5+Vector3.UP*h*0.5-Vector3(face_dir)*0.03
	mesh.position = center
	mesh.rotation.y = atan2(float(face_dir.x),float(face_dir.z))
	return mesh

static var textures: Dictionary = {}

# A painting's face is drawn into one image per motive, then stretched over the
# quad as a single texture rather than per-block tiles. All art is original: a
# simple scene per motive, drawn deterministically, so a motive looks the same
# every time it is hung.
static func texture(index: int) -> ImageTexture:
	var safe: int = clampi(index,0,MOTIVES.size()-1)
	if textures.has(safe): return textures[safe]
	var motive: Dictionary = MOTIVES[safe]
	var w: int = canvas_side(int(motive.w)); var h: int = canvas_side(int(motive.h))
	var img := Image.create(w,h,false,Image.FORMAT_RGBA8)
	_draw_scene(img,motive)
	# A painted frame border, one pixel of darkened wood, as the source's own
	# texture pack wraps each image.
	for x in w:
		img.set_pixel(x,0,Color("6b4a2e")); img.set_pixel(x,h-1,Color("6b4a2e"))
	for y in h:
		img.set_pixel(0,y,Color("6b4a2e")); img.set_pixel(w-1,y,Color("6b4a2e"))
	textures[safe] = ImageTexture.create_from_image(img)
	return textures[safe]

static func _draw_scene(img: Image, motive: Dictionary) -> void:
	var w: int = img.get_width(); var h: int = img.get_height()
	var key: String = motive.key
	match key:
		"ancient_octopus": _octopus(img,Color("6a3f7a"))
		"notes": _notes(img)
		"snowy_mountain","moonshine_tundra","mountain_tower","waterfall_bridge","gloom_gloom_mountain","elf_utopia":
			_landscape(img,motive)
		"poster","quest_board","red_banner","green_banner":
			_banner_poster(img,motive)
		"balding_man","volendam_costume","sarmatian_decoration":
			_portrait(img,motive)
		"viking_shield","battle_axe","decorative_swords","butcher_knives","cooking_utensils","support_truss":
			_implements(img,motive)
		_:
			_scene(img,motive)

	# A thin inner shade so the painting reads as framed art.
	for x in range(1,maxi(1,w-1)):
		img.set_pixel(x,1,img.get_pixel(x,1).darkened(0.25)); img.set_pixel(x,h-2,img.get_pixel(x,h-2).darkened(0.25))

static func _fill_sky_ground(img: Image, sky: Color, ground: Color, horizon: float) -> void:
	var w: int = img.get_width(); var h: int = img.get_height()
	var line: int = clampi(int(h*horizon),1,h-2)
	for y in h:
		for x in w:
			img.set_pixel(x,y,(sky.lightened(0.06*(h-y)/float(h)) if y < line else ground.darkened(0.15*(y-line)/float(h))))

static func _landscape(img: Image, motive: Dictionary) -> void:
	var snowy: bool = motive.key in ["snowy_mountain","moonshine_tundra"]
	var sky: Color = Color("2b3a5c") if motive.key == "moonshine_tundra" else Color("9cc2da")
	var ground: Color = Color("e8eef2") if snowy else Color("5f7a42")
	_fill_sky_ground(img,sky,ground,0.62)
	var w: int = img.get_width(); var h: int = img.get_height()
	# A layered ridge, tallest in the middle of the picture.
	for x in w:
		var ridge: int = int(h*0.66-sin(PI*x/float(maxi(1,w-1)))*h*0.34)
		for y in range(maxi(1,ridge),int(h*0.66)):
			img.set_pixel(x,y,(Color("dfe6ea") if snowy else Color("5a5f57")).darkened(0.05*((y-ridge)/float(h))))
	if motive.key in ["mountain_tower","elf_utopia"]:
		var cx: int = w/2; var base: int = int(h*0.66)
		for y in range(int(h*0.28),base):
			for x in range(cx-2,cx+3):
				if x >= 0 and x < w: img.set_pixel(x,y,Color("8a6b4a") if (y/2)%2==0 else Color("6f5439"))
	if motive.key == "waterfall_bridge":
		var cx2: int = w/2
		for y in range(int(h*0.36),int(h*0.66)):
			for x in range(cx2-2,cx2+3):
				if x >= 1 and x < w-1: img.set_pixel(x,y,Color("cfe3ee"))

static func _banner_poster(img: Image, motive: Dictionary) -> void:
	var w: int = img.get_width(); var h: int = img.get_height()
	var cloth: Color = Color("3f7d3a") if motive.key == "green_banner" else (Color("9c2f2f") if motive.key == "red_banner" else Color("c9b489"))
	img.fill(cloth)
	for x in w:
		for y in h:
			if (x+y)%7 == 0: img.set_pixel(x,y,cloth.darkened(0.12))
	var cx: int = w/2; var cy: int = h/2; var r: int = maxi(2,mini(w,h)/4)
	for y in range(cy-r,cy+r+1):
		for x in range(cx-r,cx+r+1):
			var d: int = (x-cx)*(x-cx)+(y-cy)*(y-cy)
			if d <= r*r and x > 0 and y > 0 and x < w-1 and y < h-1: img.set_pixel(x,y,cloth.lightened(0.35))

static func _portrait(img: Image, motive: Dictionary) -> void:
	_fill_sky_ground(img,Color("3a3630"),Color("4a4238"),0.9)
	var w: int = img.get_width(); var h: int = img.get_height()
	var skin: Color = Color("d8a982") if motive.key == "balding_man" else Color("c9a06a")
	var cx: int = w/2
	for y in range(int(h*0.22),int(h*0.78)):
		for x in range(cx-w/8,cx+w/8):
			if x > 0 and x < w-1: img.set_pixel(x,y,skin)
	for x in range(cx-w/8-1,cx+w/8+1):
		if x > 0 and x < w-1:
			img.set_pixel(x,int(h*0.48),Color("3a2b20")); img.set_pixel(x,int(h*0.49),Color("3a2b20"))

static func _implements(img: Image, motive: Dictionary) -> void:
	var w: int = img.get_width(); var h: int = img.get_height()
	_fill_sky_ground(img,Color("6d5a44"),Color("4b3d2d"),0.85)
	var metal: Color = Color("b9c0c6"); var wood: Color = Color("7a5636")
	var cx: int = w/2
	if motive.key in ["viking_shield"]:
		_disc(img,cx,h/2,mini(w,h)/3,Color("9c4a3a"),Color("c9b06a"))
	elif motive.key in ["battle_axe","decorative_swords"]:
		for y in range(int(h*0.2),int(h*0.8)):
			for x in range(cx-1,cx+2):
				if x > 0 and x < w-1: img.set_pixel(x,y,wood)
		for y in range(int(h*0.28),int(h*0.56)):
			for x in range(cx-3,cx+4):
				if x > 0 and x < w-1: img.set_pixel(x,y,metal)
	elif motive.key in ["butcher_knives","cooking_utensils"]:
		for y in range(int(h*0.22),int(h*0.78)):
			for x in range(cx-3,cx+4):
				if x > 0 and x < w-1: img.set_pixel(x,y,metal if (y/3)%2==0 else wood)
	else:
		for x in range(int(w*0.2),int(w*0.8)):
			for y in range(int(h*0.4),int(h*0.6)):
				if y > 0 and y < h-1: img.set_pixel(x,y,wood if (x/3)%2==0 else metal)

static func _octopus(img: Image, body: Color) -> void:
	_fill_sky_ground(img,Color("2c4a5c"),Color("1d3542"),0.95)
	_disc(img,img.get_width()/2,img.get_height()/2,mini(img.get_width(),img.get_height())/4,body,body.lightened(0.3))

static func _notes(img: Image) -> void:
	_fill_sky_ground(img,Color("d9cba6"),Color("c6b48a"),0.95)
	var w: int = img.get_width(); var h: int = img.get_height()
	for y in range(int(h*0.25),int(h*0.75),4):
		for x in range(int(w*0.15),int(w*0.85)):
			if x > 0 and x < w-1: img.set_pixel(x,y,Color("5a4a34"))

static func _scene(img: Image, motive: Dictionary) -> void:
	_fill_sky_ground(img,Color("7fa8c4"),Color("5f7a42"),0.7)
	_disc(img,img.get_width()/3,img.get_height()/3,mini(img.get_width(),img.get_height())/8,Color("f0d98a"),Color("fff0b0"))

static func _disc(img: Image, cx: int, cy: int, radius: int, fill: Color, edge: Color) -> void:
	var w: int = img.get_width(); var h: int = img.get_height()
	for y in range(cy-radius,cy+radius+1):
		for x in range(cx-radius,cx+radius+1):
			if x <= 0 or y <= 0 or x >= w-1 or y >= h-1: continue
			var d: int = (x-cx)*(x-cx)+(y-cy)*(y-cy)
			if d <= (radius-1)*(radius-1): img.set_pixel(x,y,fill)
			elif d <= radius*radius: img.set_pixel(x,y,edge)

# The recipe already lives in `VillageContent` beside the item frame's, using the
# source's own pattern: three sticks, a wool centre row and three sticks.
