class_name Decor
extends RefCounted

# Mineclonia mcl_flowerpots/init.lua and mcl_armor_stand/init.lua,
# GPL-3.0-or-later. Original procedural art.
#
# Source rules reproduced here:
# - The flowerpot holds exactly the 36 plants in the checkout's
#   `registered_pots` table; it is a whitelist keyed by item, not a group, and
#   there is no height or size test at runtime despite the in-game text.
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
# Exact source itemstring -> Voxey id mapping, inverted for the runtime lookup.
# Ordinary vines and the two legacy nether "saplings" are deliberately absent:
# neither occurs in `registered_pots` in this checkout.
const POTTABLE = {
	5610:"mcl_flowers:poppy",5611:"mcl_flowers:dandelion",5612:"mcl_flowers:oxeye_daisy",
	11400:"mcl_flowers:tulip_orange",11401:"mcl_flowers:tulip_pink",11402:"mcl_flowers:tulip_red",
	11403:"mcl_flowers:tulip_white",11404:"mcl_flowers:allium",11405:"mcl_flowers:azure_bluet",
	11406:"mcl_flowers:blue_orchid",11407:"mcl_flowers:wither_rose",11408:"mcl_flowers:lily_of_the_valley",
	11409:"mcl_flowers:cornflower",11410:"mcl_flowers:fern",
	13601:"mcl_core:deadbush",57:"mcl_mushrooms:mushroom_red",58:"mcl_mushrooms:mushroom_brown",
	14:"mcl_core:cactus",1174:"mcl_bamboo:bamboo_small",
	23:"mcl_trees:sapling_oak",6034:"mcl_trees:sapling_spruce",6066:"mcl_trees:sapling_birch",
	6098:"mcl_trees:sapling_jungle",6130:"mcl_trees:sapling_acacia",6162:"mcl_trees:sapling_dark_oak",
	13003:"mcl_trees:sapling_cherry",13067:"mcl_trees:sapling_pale_oak",13035:"mcl_mangrove:propagule",
	11472:"mcl_lush_caves:azalea",11473:"mcl_lush_caves:azalea_flowering",
	11511:"mcl_crimson:crimson_fungus",11512:"mcl_crimson:warped_fungus",
	11513:"mcl_crimson:crimson_roots",11514:"mcl_crimson:warped_roots",
	11528:"mcl_flowers:eyeblossom",11529:"mcl_flowers:eyeblossom_open",
}

# The source's potted-eyeblossom ABMs use interval = 2 and chance = 2.
const EYEBLOSSOM_INTERVAL = 2.0
const EYEBLOSSOM_CHANCE = 2
const ARMOR_PIECES = 4
# The source stand also carries two hand slots, left and right of the four armour
# pieces. A stand saved before they existed holds four entries and is padded.
const STAND_SLOTS = ARMOR_PIECES+2
const STAND_KEY = "armor_stand"

static var icons: Dictionary = {}

# No broad flower, plant or sapling predicate belongs here: source admission is
# precisely the table above, including both azalea and eyeblossom forms.
static func accepts(id: int) -> bool:
	return POTTABLE.has(id)

# A pot carrying a plant. The plant survives in saved block metadata, so one id
# covers every plant and the registry stays small.
static func contents(world: VoxelWorld, p: Vector3i) -> int:
	return int(world.block_states.get(VoxelWorld.station_key(p),{}).get("pot_plant",0))

static func set_contents(world: VoxelWorld, p: Vector3i, plant: int) -> void:
	var previous: int = contents(world,p)
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	if plant == 0: state.erase("pot_plant")
	else: state["pot_plant"] = plant
	if state.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = state
	if PaleOak.is_eyeblossom(plant): registered(world,p)
	else: forget(world,p)
	# Contents are metadata rather than a node id in Voxey, so explicitly dirty
	# the cell for the state-aware worker mesh and for network state snapshots.
	if previous != plant and world.loaded_at(Vector3(p)): world._mark_dirty(p)

static func _runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("decor_flowerpots"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+3602
		world.set_meta("decor_flowerpots",{"cells":{},"clock":0.0,"rng":rng})
	return world.get_meta("decor_flowerpots")

static func registered(world: VoxelWorld, p: Vector3i) -> void:
	if world.node_at(p) != POT or not PaleOak.is_eyeblossom(contents(world,p)) or not world.loaded_at(Vector3(p)): return
	_runtime(world).cells[p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if world.has_meta("decor_flowerpots"): _runtime(world).cells.erase(p)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	# A saved potted plant is necessarily an edit; generated pots currently hold
	# allium, which has no timed state. Re-register only loaded saved cells.
	for p in world.column_edits(column): registered(world,p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("decor_flowerpots"): return
	var cells: Dictionary = _runtime(world).cells
	for p in cells.keys():
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: cells.erase(p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("decor_flowerpots"): world.remove_meta("decor_flowerpots")

# One source ABM attempt for a single pot. The chance roll happens before the
# action's time-of-day test, just as it does in Luanti.
static func eyeblossom_step(world: VoxelWorld, p: Vector3i, day_time: float, rng: RandomNumberGenerator) -> bool:
	var plant: int = contents(world,p)
	if world.node_at(p) != POT or not PaleOak.is_eyeblossom(plant): return false
	if rng.randi_range(1,EYEBLOSSOM_CHANCE) != 1: return false
	var desired: int = PaleOak.EYEBLOSSOM_OPEN if PaleOak.is_night(day_time) else PaleOak.EYEBLOSSOM
	if desired == plant: return false
	set_contents(world,p,desired)
	return true

static func update(game: Node3D, delta: float) -> void:
	var world: VoxelWorld = game.world
	if not world.has_meta("decor_flowerpots") or delta <= 0 or not is_finite(delta): return
	var state: Dictionary = _runtime(world)
	state.clock = float(state.clock)+delta
	while float(state.clock) >= EYEBLOSSOM_INTERVAL:
		state.clock = float(state.clock)-EYEBLOSSOM_INTERVAL
		for p in state.cells.keys(): eyeblossom_step(world,p,float(game.day_time),state.rng)

static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	# Luanti attached_node checks the supporting node's walkable flag; it does
	# not require a full cube or a particular shaped top face.
	return world.loaded_at(Vector3(below)) and Nodes.solid(world.node_at(below))

static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	for at in [p,p+Vector3i.UP]:
		if world.node_at(at) != POT or not world.loaded_at(Vector3(at)) or supported(world,at): continue
		var plant: int = contents(world,at)
		if not world.set_node(at,Nodes.AIR): continue
		# Environmental attached-node loss is not creative-mode breaking: source
		# drops both the empty pot and, when occupied, its base item.
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_drop"):
			game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,POT,1)
			if plant != 0: game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,plant,1)

# A block replaced by another is a fresh block, so its stored contents go.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id != id and (is_pot(old_id) or is_stand(old_id)): world.block_states.erase(VoxelWorld.station_key(p))
	forget(world,p)
	if id == POT: registered(world,p)
	if not PistonPush.defer_support(world,p): support_changed(world,p)

static func is_pot(id: int) -> bool: return id == POT
static func is_stand(id: int) -> bool: return id == STAND

# --- armor stand storage ----------------------------------------------------

static func worn(world: VoxelWorld, p: Vector3i) -> Array:
	var raw: Variant = world.block_states.get(VoxelWorld.station_key(p),{}).get("stand_armor",[])
	var result: Array = []
	for i in STAND_SLOTS:
		result.append(Inventory.clean_slot(raw[i]) if raw is Array and i < raw.size() and raw[i] is Dictionary else {"id":0,"count":0,"wear":0})
	return result

static func set_worn(world: VoxelWorld, p: Vector3i, list: Array) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	var clean: Array = []
	for i in STAND_SLOTS: clean.append(Inventory.clean_slot(list[i]) if i < list.size() else {"id":0,"count":0,"wear":0})
	state["stand_armor"] = clean
	world.block_states[key] = state

# Source maps armor to head, torso, legs and feet by piece, and everything else
# to the stand's hands. Voxey has no separate hand slots, so a non-armor item is
# worn on the torso, which is where a held item visibly sits.
static func slot_for(id: int) -> int:
	if Nodes.is_armor(id) and id != Nodes.ELYTRA: return clampi(Nodes.armor_piece(id),0,ARMOR_PIECES-1)
	return ARMOR_PIECES

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
		for i in range(STAND_SLOTS-1,-1,-1):
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
	if not (is_pot(held) or is_stand(held)) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current): return true
	# Both empty and occupied source pots are attached_node = 1. Keep the
	# stand's existing gate; this ticket adds the pot's attached-support rule.
	if is_pot(held) and not supported(game.world,at): return true
	if is_stand(held) and not Nodes.solid(game.world.node_at(at+Vector3i.DOWN)): return true
	if is_stand(held):
		var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
		if body.intersects(AABB(Vector3(at),Vector3.ONE)): return true
	if not game.world.set_node(at,held): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,held)
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

# Main-thread snapshot for display code, and a column/local-index form suitable
# for the detached worker mesher. Only occupied pots need entries; the ordinary
# node mesh path already draws every empty pot body.
static func pot_snapshot(world: VoxelWorld, p: Vector3i) -> Dictionary:
	return {"pot":POT,"plant":contents(world,p)}

static func plant_snapshot(world: VoxelWorld, column: Vector2i) -> Dictionary:
	var result: Dictionary = {}
	for key in world.block_states:
		var state: Variant = world.block_states[key]
		if not state is Dictionary or not state.has("pot_plant"): continue
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3: continue
		var p := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		if p.x < column.x*16-1 or p.x > column.x*16+16 or p.z < column.y*16-1 or p.z > column.y*16+16: continue
		if not world.loaded_at(Vector3(p)) or world.node_at(p) != POT: continue
		var block: Vector3i = VoxelWorld.block_coord(p)
		if not result.has(block): result[block] = {}
		result[block][VoxelWorld.local_index(p)] = contents(world,p)
	return result

static func saved_pot_mesh(out: Array, p: Vector3, world: VoxelWorld) -> void:
	pot_mesh(out,p,contents(world,Vector3i(p)))

static func pot_snapshot_mesh(out: Array, p: Vector3, snapshot: Dictionary) -> void:
	pot_mesh(out,p,int(snapshot.get("plant",0)))

static func pot_body_mesh(out: Array, p: Vector3) -> void:
	BlockMesher._art_box(out,p+Vector3(0.5,0.15,0.5),Vector3(0.6,0.3,0.6),Nodes.tile(POT,0),Nodes.tile(POT,2))

# The actual saved plant above an occupied pot, drawn with that plant's tile.
static func pot_mesh(out: Array, p: Vector3, plant: int) -> void:
	pot_body_mesh(out,p)
	if plant == 0: return
	var tile: int = Nodes.tile(plant,0)
	BlockMesher._art_box(out,p+Vector3(0.5,0.42,0.5),Vector3(0.25,0.34,0.25),tile,tile)
	if FoodFeatures.flower(plant) or PaleOak.is_eyeblossom(plant):
		BlockMesher._art_box(out,p+Vector3(0.5,0.62,0.5),Vector3(0.4,0.18,0.4),tile,tile)
	elif plant in [Nodes.CACTUS,Bamboo.BAMBOO_ITEM]:
		# These are source's two register_potted_cube entries.
		BlockMesher._art_box(out,p+Vector3(0.5,0.55,0.5),Vector3(0.32,0.6,0.32),tile,tile)
	elif WoodTypes.is_sapling(plant):
		BlockMesher._art_box(out,p+Vector3(0.5,0.55,0.5),Vector3(0.3,0.55,0.3),tile,tile)

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if id == POT:
		pot_body_mesh(out,p)
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
