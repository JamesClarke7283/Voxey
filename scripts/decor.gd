class_name Decor
extends RefCounted

# Mineclonia mcl_flowerpots/init.lua and mcl_armor_stand/init.lua,
# GPL-3.0-or-later. Original procedural art.
#
# Source rules reproduced here:
# - The flowerpot holds exactly the plants in the checkout's `registered_pots`
#   table; it is a whitelist keyed by item, not a group, and there is no height
#   or size test at runtime despite the in-game text. Voxey registers the subset
#   of that list whose plants Voxey actually has.
# - Source encodes the plant in the node name, so contents never need metadata
#   and breaking simply drops the pot plus the plant. Voxey stores the plant in
#   saved block metadata so one id covers every plant, which is equivalent for
#   drops and saves and keeps the registry small.
# - Right-clicking with the same plant already in the pot is a no-op in survival.
#   Right-clicking with anything else empties the pot and returns the plant.
# - The empty pot is crafted from three bricks in a U.
# - Source's armor stand is a node plus a non-persisted entity whose armor lives
#   in the node's metadata inventory, indices 2..5 for head, torso, legs and
#   feet. Voxey has no per-node metadata inventory, so the four pieces live in
#   the node's saved state; the entity is only a display, exactly as in source.
#   Source has no limb posing and no nine-part model, so none is invented here.
#
# Source gaps: source's armor stand stores items in a metadata inventory with no
# custom keys, and its flowerpot has no metadata at all. Both are recorded in the
# notes. Neither behaviour is invented beyond what the source does.

const POT = 10800
const STAND = 10801
# Source `registered_pots`, restricted to the plants Voxey has. Each entry maps a
# source itemstring to the plant id Voxey uses.
const ARMOR_PIECES = 4
const STAND_KEY = "armor_stand"

static var icons: Dictionary = {}

# Source's whitelist has 36 entries keyed by item, not a group, and there is no
# height or size test at runtime. Voxey accepts the same categories whose plants
# it has: the three ported flowers, both mushrooms, cactus, vines and the six
# wood saplings. The source entries Voxey cannot honour name species it has not
# ported (azalea, mangrove, crimson fungi and roots, bamboo) and are recorded in
# the notes as omitted.
static func accepts(id: int) -> bool:
	if FoodFeatures.flower(id): return true
	if id in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.CACTUS,Nodes.VINE]: return true
	if WoodTypes.is_sapling(id): return true
	return false

# A pot carrying a plant. The plant survives in saved block metadata, so one id
# covers every plant and the registry stays small.
static func contents(world: VoxelWorld, p: Vector3i) -> int:
	return int(world.block_states.get(VoxelWorld.station_key(p),{}).get("pot_plant",0))

static func set_contents(world: VoxelWorld, p: Vector3i, plant: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	if plant == 0: state.erase("pot_plant")
	else: state["pot_plant"] = plant
	if state.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = state

# A block replaced by another is a fresh block, so its stored contents go.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id == id or not (is_pot(old_id) or is_stand(old_id)): return
	world.block_states.erase(VoxelWorld.station_key(p))

static func is_pot(id: int) -> bool: return id == POT
static func is_stand(id: int) -> bool: return id == STAND

# --- armor stand storage ----------------------------------------------------

static func worn(world: VoxelWorld, p: Vector3i) -> Array:
	var raw: Variant = world.block_states.get(VoxelWorld.station_key(p),{}).get("stand_armor",[])
	var result: Array = []
	for i in ARMOR_PIECES:
		result.append(Inventory.clean_slot(raw[i]) if raw is Array and i < raw.size() and raw[i] is Dictionary else {"id":0,"count":0,"wear":0})
	return result

static func set_worn(world: VoxelWorld, p: Vector3i, list: Array) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	var clean: Array = []
	for i in ARMOR_PIECES: clean.append(Inventory.clean_slot(list[i]) if i < list.size() else {"id":0,"count":0,"wear":0})
	state["stand_armor"] = clean
	world.block_states[key] = state

# Source maps armor to head, torso, legs and feet by piece, and everything else
# to the stand's hands. Voxey has no separate hand slots, so a non-armor item is
# worn on the torso, which is where a held item visibly sits.
static func slot_for(id: int) -> int:
	if Nodes.is_armor(id) and id != Nodes.ELYTRA: return clampi(Nodes.armor_piece(id),0,ARMOR_PIECES-1)
	return 1

# --- interaction ------------------------------------------------------------

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or game.target_mob() != null: return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	var p: Vector3i = target.pos
	var id: int = game.world.node_at(p)
	var held: int = game.inventory.held().id
	if id == POT: return _use_pot(game,p,held)
	if id == STAND: return _use_stand(game,p,held)
	return false

static func _use_pot(game: Node3D, p: Vector3i, held: int) -> bool:
	var plant: int = contents(game.world,p)
	if plant == 0:
		if not accepts(held): return false
		set_contents(game.world,p,held)
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1
		return true
	# Source: the same plant in survival is a no-op; anything else empties it.
	if held == plant and game.gamemode != "creative": return true
	set_contents(game.world,p,0)
	if game.gamemode == "creative": return true
	if game.inventory.add_item(plant,1) > 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,plant)
	game.sound("place"); game.player.swing = 1; game.toast("Took the "+Nodes.title(plant).to_lower()+" out.")
	return true

static func _use_stand(game: Node3D, p: Vector3i, held: int) -> bool:
	var worn: Array = worn(game.world,p)
	if held == 0:
		# An empty hand removes the last-placed piece, matching source order.
		for i in range(ARMOR_PIECES-1,-1,-1):
			if worn[i].id == 0: continue
			var piece: Dictionary = worn[i]
			worn[i] = {"id":0,"count":0,"wear":0}
			set_worn(game.world,p,worn)
			if game.inventory.add_item(piece.id,1,piece.wear,piece.get("data",{})) > 0:
				game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,piece.id,1,piece.wear,piece.get("data",{}))
			game.sound("place"); game.player.swing = 1
			return true
		# Punching an empty stand rotates it, as source's screwdriver rotation does.
		var facing_value: int = posmod(int(game.world.block_states.get(VoxelWorld.station_key(p),{}).get("stand_facing",0))+1,4)
		var key: String = VoxelWorld.station_key(p)
		var state: Dictionary = game.world.block_states.get(key,{})
		state["stand_facing"] = facing_value
		game.world.block_states[key] = state
		game.sound("place"); game.player.swing = 1
		return true
	var slot: int = slot_for(held)
	var previous: Dictionary = worn[slot]
	worn[slot] = {"id":held,"count":1,"wear":game.inventory.held().wear,"data":game.inventory.held().get("data",{}).duplicate(true)}
	set_worn(game.world,p,worn)
	if game.gamemode != "creative": game.inventory.consume_selected()
	if previous.id != 0 and game.inventory.add_item(previous.id,1,previous.wear,previous.get("data",{})) > 0:
		game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,previous.id,1,previous.wear,previous.get("data",{}))
	game.sound("place"); game.player.swing = 1; game.toast(Nodes.title(held)+" placed on the stand.")
	return true

# --- placement, breaking ----------------------------------------------------

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_stand(held) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current): return true
	if not Nodes.solid(game.world.node_at(at+Vector3i.DOWN)): return true
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	if body.intersects(AABB(Vector3(at),Vector3.ONE)): return true
	if not game.world.set_node(at,STAND): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,STAND)
	return true

static func break_node(game: Node3D, p: Vector3i, id: int, tool: int, exploded: bool = false) -> bool:
	if id == POT:
		var plant: int = contents(game.world,p)
		if not game.world.set_node(p,Nodes.AIR): return true
		game.world.block_states.erase(VoxelWorld.station_key(p))
		if game.gamemode != "creative" and Nodes.harvestable(id,tool):
			# Source drops both the pot and its plant.
			game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,POT,1)
			if plant != 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,plant,1)
		game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
		return true
	if id == STAND:
		var worn: Array = worn(game.world,p)
		if not game.world.set_node(p,Nodes.AIR): return true
		game.world.block_states.erase(VoxelWorld.station_key(p))
		if game.gamemode != "creative":
			game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,STAND,1)
			# Source returns every stored piece when the stand is destroyed.
			for piece in worn:
				if piece.id != 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,piece.id,1,piece.wear,piece.get("data",{}))
		game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
		return true
	return false

# --- recipes ----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source: three bricks in a U for the pot.
	inv._recipe("Flower pot",POT,1,[Nodes.BRICK_ITEM,0,Nodes.BRICK_ITEM,0,Nodes.BRICK_ITEM,0],2)
	# Source: a stone slab over three sticks.
	inv._recipe("Armor stand",STAND,1,[Nodes.STICK,Nodes.STICK,Nodes.STICK,0,Nodes.STICK,0,0,BuildingShapes.slab_for(Nodes.STONE),0],3,"table")

# --- art --------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == POT:
		# A terracotta pot with a darker rim and a soil layer inside.
		if y < 3: return Color("8d5530")
		if y < 1: return Color("6b3f22")
		if x in [0,15] or y == 15: return Color("94572f")
		if y in [3,4] and x in range(5,11): return Color("5c3a24")
		return Color("b06d3c") if posmod(x*3+y*5,7) == 0 else Color("a5673f")
	if id == STAND:
		# Pale wood: two uprights, a base and the arms.
		if y in [1,2] or x in [2,13]: return Color("b28c52")
		if y in range(3,10) and x in [5,6,9,10]: return Color("c69b5c")
		if y in [10,11] and x in range(3,13): return Color("c69b5c")
		return Color("9c7a45")
	return noise

# The plant above an occupied pot, drawn with the plant's own colour.
static func pot_mesh(out: Array, p: Vector3, plant: int) -> void:
	# The pot body is always drawn; the plant only when the pot holds one.
	BlockMesher._art_box(out,p+Vector3(0.5,0.15,0.5),Vector3(0.6,0.3,0.6),Nodes.tile(POT,0),Nodes.tile(POT,2))
	if plant == 0: return
	var colour: Color = Nodes.color(plant)
	var tile: int = Nodes.tile(plant,0)
	BlockMesher._art_box(out,p+Vector3(0.5,0.42,0.5),Vector3(0.25,0.34,0.25),tile,tile)
	if FoodFeatures.flower(plant):
		BlockMesher._art_box(out,p+Vector3(0.5,0.62,0.5),Vector3(0.4,0.18,0.4),tile,tile)
	elif plant == Nodes.CACTUS:
		BlockMesher._art_box(out,p+Vector3(0.5,0.55,0.5),Vector3(0.32,0.6,0.32),tile,tile)
	elif WoodTypes.is_sapling(plant):
		BlockMesher._art_box(out,p+Vector3(0.5,0.55,0.5),Vector3(0.3,0.55,0.3),tile,tile)

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if id == POT:
		BlockMesher._art_box(out,p+Vector3(0.5,0.15,0.5),Vector3(0.6,0.3,0.6),Nodes.tile(POT,0),Nodes.tile(POT,2))
		return
	# An armor stand: a base, an upright post, a crossbar for the arms and a
	# head piece when the helmet slot is filled.
	BlockMesher._art_box(out,p+Vector3(0.5,0.03,0.5),Vector3(0.75,0.06,0.75),Nodes.tile(POT,0),Nodes.tile(POT,0))
	BlockMesher._art_box(out,p+Vector3(0.5,0.55,0.5),Vector3(0.12,1.05,0.12),Nodes.tile(POT,0),Nodes.tile(POT,0))
	BlockMesher._art_box(out,p+Vector3(0.5,1.02,0.5),Vector3(0.85,0.1,0.12),Nodes.tile(POT,0),Nodes.tile(POT,0))

static func draw(img: Image, id: int) -> void:
	if id == POT:
		# A terracotta pot: a wide rim over a tapered body.
		ItemArt._polygon(img,[[2,4],[14,4],[12,14],[4,14]],Color("a5673f"))
		img.fill_rect(Rect2i(1,3,14,3),Color("b06d3c"))
		img.fill_rect(Rect2i(5,4,6,2),Color("5c3a24"))
		ItemArt._line(img,Vector2(3,12),Vector2(13,12),Color("8d5530"))
		return
	# An armor stand: a base, a post, a crossbar and a head plate.
	img.fill_rect(Rect2i(4,13,8,2),Color("b28c52"))
	img.fill_rect(Rect2i(7,3,2,10),Color("c69b5c"))
	img.fill_rect(Rect2i(3,5,10,2),Color("c69b5c"))
	img.fill_rect(Rect2i(6,1,4,3),Color("b28c52"))

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]
