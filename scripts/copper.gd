class_name Copper
extends RefCounted

# Mineclonia mcl_copper/{init,nodes,items,crafting,decaychains}.lua and
# mcl_lightning_rods/init.lua, GPL-3.0-or-later. Original procedural art.
#
# Source keeps a separate node name per oxidation stage and a second node name
# per waxed stage ("_preserved"). Voxey keeps one id per stage and stores wax in
# saved block metadata, so the flag travels with the block and its dropped item.
# The observable rules are unchanged: a waxed block never oxidises, an axe removes
# wax before it reverses oxidation, and crafting a waxed block keeps the flag.
#
# Source-exact rules reproduced here:
# - One oxidation ABM over every chain node: interval 500 s, chance 3, so each
#   node advances at most one stage per roll with a 1-in-3 chance per 500 s.
#   There is no exposure condition and no random-tick path. De-oxidation is
#   always direct (axe or lightning), never an ABM.
# - Axe use is mutually exclusive per click: a waxed block loses its wax and
#   keeps its stage; an unwaxed exposed-or-worse block loses exactly one stage;
#   a pristine block is unaffected.
# - Doors and trapdoors oxidise. Only a door's bottom half is processed, and the
#   top half is swapped in step so both halves always match.
# - Powered lightning rods are absent from every chain, so a powered rod cannot
#   oxidise, be waxed, or be scraped. The powered variant reverts on its own
#   four-tick pulse, which the source re-arms on construction and on load.
# - Rod attraction is a first-match scan, not a nearest-rod search, and the rod
#   must have air directly above it.
#
# Recorded source gaps, not repaired here:
# - `affected_by_lightning` is only ever set to 0, and only on the preserved
#   variants, which also clear `_on_lightning_strike`. Because a group filter
#   matches on key presence, the callback registered on the exposed/weathered/
#   oxidized cut copper stairs and slabs is unreachable dead code in the
#   checkout. `lightning_strike` implements those callbacks for the ids that
#   carry them, matching what the source intends.
# - `mcl_copper:block_raw` is marked `blast_furnace_smeltable` but declares no
#   cooking output, so it is unsmeltable; and no recipe converts cut copper back
#   into a copper block. Both are absent in Voxey for the same reason.
# - Copper lanterns, chains, bars and the copper torch belong to mcl_lanterns,
#   mcl_panes and mcl_torches rather than mcl_copper, and are not in this batch.

# Oxidation stages in source order: unaffected, exposed, weathered, oxidized.
const BLOCK_STAGES = [Nodes.COPPER_NODE,9500,9501,9502]
const CUT_STAGES = [9510,9511,9512,9513]
const CHISELED_STAGES = [9520,9521,9522,9523]
const GRATE_STAGES = [9530,9531,9532,9533]
const BULB_OFF_STAGES = [9540,9541,9542,9543]
const BULB_ON_STAGES = [9544,9545,9546,9547]
const ROD_STAGES = [9550,9551,9552,9553]
const ROD_POWERED_STAGES = [9554,9555,9556,9557]
# Copper doors and trapdoors reuse the classic sixteen-state families from Doors
# and Trapdoors through their `register_family` entry points, so their geometry,
# opening, redstone and actor recovery are not duplicated here.
const DOOR_ITEMS = [9600,9632,9664,9696]
const TRAPDOOR_ITEMS = [9760,9776,9792,9808]
# Every chain the source registers that Voxey has content for. Powered rods are
# deliberately absent: the source excludes them from every chain.
# Every chain the source registers that Voxey has content for. Powered rods are
# deliberately absent: the source excludes them from every chain. `CopperDecor`'s
# lantern, chain and bar families are members of the same engine, so they appear
# here too and oxidise, wax and scrape through the identical code path.
const CHAINS = [BLOCK_STAGES,CUT_STAGES,CHISELED_STAGES,GRATE_STAGES,BULB_OFF_STAGES,BULB_ON_STAGES,ROD_STAGES,
	[11530,11531,11532,11533],[11534,11535,11536,11537],[11538,11539,11540,11541],[11542,11543,11544,11545]]
const OXIDIZE_INTERVAL = 500.0
const OXIDIZE_CHANCE = 3
const ROD_PULSE = 0.4
const LIGHT_LEVELS = [14,12,8,4]
const ROD_BOXES = [AABB(Vector3(0.4375,0,0.4375),Vector3(0.125,0.75,0.125)),AABB(Vector3(0.375,0.75,0.375),Vector3(0.25,0.25,0.25))]
const DOOR_NAMES = ["Copper door","Exposed copper door","Weathered copper door","Oxidized copper door"]
const TRAPDOOR_NAMES = ["Copper trapdoor","Exposed copper trapdoor","Weathered copper trapdoor","Oxidized copper trapdoor"]
const DATA = {
	9500:{"name":"Exposed copper","block":true,"color":"b3876c","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9501:{"name":"Weathered copper","block":true,"color":"8aa38c","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9502:{"name":"Oxidized copper","block":true,"color":"76ab8e","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9510:{"name":"Cut copper","block":true,"color":"bd7a55","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9511:{"name":"Exposed cut copper","block":true,"color":"b0836a","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9512:{"name":"Weathered cut copper","block":true,"color":"879f8a","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9513:{"name":"Oxidized cut copper","block":true,"color":"73a88c","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9520:{"name":"Chiseled copper","block":true,"color":"b8764f","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9521:{"name":"Exposed chiseled copper","block":true,"color":"ac8064","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9522:{"name":"Weathered chiseled copper","block":true,"color":"839b86","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9523:{"name":"Oxidized chiseled copper","block":true,"color":"6fa588","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9530:{"name":"Copper grate","block":true,"color":"b9784f","hardness":3.0,"blast_resistance":6.0,"tool":0,"transparent":true},
	9531:{"name":"Exposed copper grate","block":true,"color":"ab7f63","hardness":3.0,"blast_resistance":6.0,"tool":0,"transparent":true},
	9532:{"name":"Weathered copper grate","block":true,"color":"829a85","hardness":3.0,"blast_resistance":6.0,"tool":0,"transparent":true},
	9533:{"name":"Oxidized copper grate","block":true,"color":"6ea487","hardness":3.0,"blast_resistance":6.0,"tool":0,"transparent":true},
	9540:{"name":"Copper bulb","block":true,"color":"a97a52","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9541:{"name":"Exposed copper bulb","block":true,"color":"a07d61","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9542:{"name":"Weathered copper bulb","block":true,"color":"7d9380","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9543:{"name":"Oxidized copper bulb","block":true,"color":"6a9d81","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9544:{"name":"Lit copper bulb","block":true,"color":"f0c478","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9540,"hidden":true},
	9545:{"name":"Lit exposed copper bulb","block":true,"color":"e5b578","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9541,"hidden":true},
	9546:{"name":"Lit weathered copper bulb","block":true,"color":"bfc288","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9542,"hidden":true},
	9547:{"name":"Lit oxidized copper bulb","block":true,"color":"a3c68c","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9543,"hidden":true},
	9550:{"name":"Lightning rod","block":true,"shape":"copper_rod","color":"c47f58","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9551:{"name":"Exposed lightning rod","block":true,"shape":"copper_rod","color":"b3856a","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9552:{"name":"Weathered lightning rod","block":true,"shape":"copper_rod","color":"8aa08a","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9553:{"name":"Oxidized lightning rod","block":true,"shape":"copper_rod","color":"77aa8d","hardness":3.0,"blast_resistance":6.0,"tool":0},
	9554:{"name":"Powered lightning rod","block":true,"shape":"copper_rod","color":"f2e0b4","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9550,"hidden":true},
	9555:{"name":"Powered exposed lightning rod","block":true,"shape":"copper_rod","color":"e8d3ab","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9551,"hidden":true},
	9556:{"name":"Powered weathered lightning rod","block":true,"shape":"copper_rod","color":"d3d5b6","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9552,"hidden":true},
	9557:{"name":"Powered oxidized lightning rod","block":true,"shape":"copper_rod","color":"c6dcb4","hardness":3.0,"blast_resistance":6.0,"tool":0,"drop":9553,"hidden":true},
}
static var icons: Dictionary = {}

# --- registry ---------------------------------------------------------------

static func is_bulb(id: int) -> bool: return BULB_OFF_STAGES.has(id) or BULB_ON_STAGES.has(id)
static func bulb_lit(id: int) -> bool: return BULB_ON_STAGES.has(id)
static func is_rod(id: int) -> bool: return ROD_STAGES.has(id) or ROD_POWERED_STAGES.has(id)
static func is_copper_door_item(id: int) -> bool: return DOOR_ITEMS.has(id)
static func is_copper_trapdoor_item(id: int) -> bool: return TRAPDOOR_ITEMS.has(id)
static func is_copper_door(id: int) -> bool: return Doors.is_door(id) and DOOR_ITEMS.has(Doors.item(id))
static func is_copper_trapdoor(id: int) -> bool: return Trapdoors.is_trapdoor(id) and TRAPDOOR_ITEMS.has(Trapdoors.item(id))

static func is_copper(id: int) -> bool:
	if DATA.has(id) or id == Nodes.COPPER_NODE: return true
	if is_rod(id) or is_bulb(id): return true
	if is_copper_door(id) or is_copper_door_item(id): return true
	if is_copper_trapdoor(id) or is_copper_trapdoor_item(id): return true
	return shape_id(id) != 0

# Family names, materials and state bases are handed to the classic door and
# trapdoor modules so their state encodings, geometry, opening, redstone and
# actor recovery are reused unchanged. Runs at startup from VoxelWorld.configure,
# before any door or trapdoor lookup.
static func register_families() -> void:
	for index in 4:
		Doors.register_family(DOOR_ITEMS[index],CUT_STAGES[index],DOOR_NAMES[index],DOOR_ITEMS[index])
		Trapdoors.register_family(TRAPDOOR_ITEMS[index],CUT_STAGES[index],TRAPDOOR_NAMES[index],TRAPDOOR_ITEMS[index])

# Whether the engine tracks this id as a chain member.
static func in_chain(id: int) -> bool:
	return stage(id) >= 0

# The oxidation stage of any copper id, including the powered rods that are
# excluded from the chains. Returns -1 for anything that does not oxidise.
static func stage(id: int) -> int:
	for chain in CHAINS:
		var index: int = chain.find(id)
		if index >= 0: return index
	var powered: int = ROD_POWERED_STAGES.find(id)
	if powered >= 0: return powered
	if is_copper_door(id) or is_copper_door_item(id): return DOOR_ITEMS.find(Doors.item(id)) if is_copper_door(id) else DOOR_ITEMS.find(id)
	if is_copper_trapdoor(id) or is_copper_trapdoor_item(id): return TRAPDOOR_ITEMS.find(Trapdoors.item(id) if is_copper_trapdoor(id) else id)
	var material: int = BuildingShapes.material(id) if BuildingShapes.is_shape(id) else 0
	if CUT_STAGES.has(material): return CUT_STAGES.find(material)
	return -1

# Ids excluded from oxidation: powered rods (absent from every chain) and a
# door's top half (the source processes only the bottom and syncs the top).
static func oxidizes(world: VoxelWorld, p: Vector3i, id: int) -> bool:
	if stage(id) >= 3 or stage(id) < 0: return false
	if ROD_POWERED_STAGES.has(id): return false
	if is_copper_door(id) and Doors.upper(id): return false
	return not waxed(world,p)

# The inventory item a placed state breaks into.
static func item(id: int) -> int:
	if is_copper_door(id): return Doors.item(id)
	if is_copper_trapdoor(id): return Trapdoors.item(id)
	if is_rod(id): return ROD_STAGES[clampi(stage(id),0,3)]
	if is_bulb(id): return BULB_OFF_STAGES[clampi(stage(id),0,3)]
	return id

# A bulb's lit toggle keeps its saved metadata; every other change is a new block.
static func same_family(a: int, b: int) -> bool:
	return is_bulb(a) and is_bulb(b) and stage(a) == stage(b)

# --- cut copper building shapes ---------------------------------------------

# Cut copper stairs and slabs are ordinary shape families whose material is the
# cut copper stage, so oxidation moves between the four families. The materials
# themselves are declared in BuildingShapes.MATERIALS.
static func shape_id(id: int) -> int:
	if not BuildingShapes.is_shape(id): return 0
	return id if CUT_STAGES.has(BuildingShapes.material(id)) else 0

# Moves a cut copper shape from one stage to another, keeping its variant.
static func shape_stage(id: int, index: int) -> int:
	return BuildingShapes.family(id)+BuildingShapes.variant(id)-BuildingShapes.MATERIALS.find(BuildingShapes.material(id))*16+BuildingShapes.MATERIALS.find(CUT_STAGES[clampi(index,0,3)])*16

# --- wax --------------------------------------------------------------------

static func waxed(world: VoxelWorld, p: Vector3i) -> bool:
	return bool(world.block_states.get(VoxelWorld.station_key(p),{}).get("copper_waxed",false))

static func set_waxed(world: VoxelWorld, p: Vector3i, value: bool) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	if value: state["copper_waxed"] = true
	else: state.erase("copper_waxed")
	if state.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = state

static func waxed_item(slot: Dictionary) -> bool:
	return bool(slot.get("data",{}).get("copper_waxed",false))

# Source breaks a waxed block into its "_preserved" item, so wax travels with the
# dropped item and returns when it is placed again. Voxey stores the same flag in
# the item's slot metadata. `drop_metadata` is what the break path should attach.
static func drop_metadata(world: VoxelWorld, p: Vector3i) -> Dictionary:
	return {"copper_waxed":true} if waxed(world,p) else {}

# Applies the held item's wax flag to a freshly placed block.
static func placed_wax(game: Node3D, p: Vector3i, slot: Dictionary) -> void:
	if waxed_item(slot): set_waxed(game.world,p,true)

# --- runtime index ----------------------------------------------------------

# Whether p is in this module's index, without creating the index.
static func tracks(world: VoxelWorld, p: Vector3i) -> bool:
	return world.has_meta("copper") and runtime(world).cells.has(p)

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("copper"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+9500
		world.set_meta("copper",{"cells":{},"columns":{},"rng":rng,"clock":0.0})
	return world.get_meta("copper")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if stage(id) < 0 or not world.loaded_at(Vector3(p)): return
	var data: Dictionary = runtime(world)
	data.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("copper"): return
	var data: Dictionary = runtime(world); data.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.columns.has(column):
		data.columns[column].erase(p)
		if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if is_copper(old_id) and is_copper(id) and not same_family(old_id,id): set_waxed(world,p,false)
	forget(world,p); registered(world,p,id)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("copper"): return
	for p in runtime(world).columns.get(column,{}).keys(): forget(world,p)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("copper"): return
	for p in world.column_edits(column):
		if stage(world.edits[p]) >= 0 and world.loaded_at(Vector3(p)): registered(world,p,world.edits[p])

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("copper"): world.remove_meta("copper")

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("copper"): return
	var data: Dictionary = runtime(world)
	data.clock = float(data.clock)+maxf(0,delta)
	if float(data.clock) < OXIDIZE_INTERVAL: return
	data.clock = 0.0
	var rng: RandomNumberGenerator = data.rng
	for p in data.cells.keys():
		var id: int = world.node_at(p)
		if id != data.cells[p] or not oxidizes(world,p,id): continue
		if rng.randi_range(1,OXIDIZE_CHANCE) == 1: set_stage(world,p,id,stage(id)+1)

# Moves a block to an absolute oxidation stage, preserving its orientation and
# keeping a door's two halves in step. Returns false when nothing changed.
static func set_stage(world: VoxelWorld, p: Vector3i, id: int, index: int) -> bool:
	index = clampi(index,0,3)
	if stage(id) == index: return false
	var next: int = 0
	if is_copper_door(id):
		next = Doors.state_id(DOOR_ITEMS[index],Doors.facing(id),Doors.mirrored(id),Doors.opened(id),Doors.upper(id))
	elif is_copper_trapdoor(id):
		next = Trapdoors.state_id(TRAPDOOR_ITEMS[index],Trapdoors.facing(id),Trapdoors.upper(id),Trapdoors.open(id))
	elif BuildingShapes.is_shape(id) and CUT_STAGES.has(BuildingShapes.material(id)):
		next = shape_stage(id,index)
	elif is_rod(id):
		# A powered rod is outside every chain and is left untouched.
		if ROD_POWERED_STAGES.has(id): return false
		next = ROD_STAGES[index]
	elif is_bulb(id):
		next = BULB_ON_STAGES[index] if bulb_lit(id) else BULB_OFF_STAGES[index]
	else:
		for chain in CHAINS:
			if chain.has(id): next = chain[index]; break
	if next == 0 or next == id: return false
	if not world.set_node(p,next): return false
	# The new stage is a different block, so its wax flag does not carry over.
	set_waxed(world,p,false)
	registered(world,p,next)
	# A door is one block in two halves; the source swaps both so they never
	# disagree about their stage. The partner is matched on the pre-change id,
	# because after the write the two halves are momentarily different families.
	if is_copper_door(next):
		var other: Vector3i = Doors.other(p,id)
		if Doors.same_family(id,world.node_at(other)):
			var other_next: int = Doors.state_id(DOOR_ITEMS[index],Doors.facing(next),Doors.mirrored(next),Doors.opened(next),not Doors.upper(next))
			if world.set_node(other,other_next):
				set_waxed(world,other,false)
				registered(world,other,other_next)
	return true

# --- interaction ------------------------------------------------------------

static func is_axe(id: int) -> bool: return Nodes.is_tool_id(id) and Nodes.tool_kind(id) == 1

# Source `_on_axe_place`. Wax removal and stage reduction are mutually exclusive
# per click: a waxed block loses its wax and keeps its stage; an unwaxed block
# loses exactly one stage; a pristine block is unaffected.
static func use_axe(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	if not is_axe(game.inventory.held().id): return false
	var p: Vector3i = target.pos
	var id: int = game.world.node_at(p)
	if not is_copper(id): return false
	if waxed(game.world,p):
		set_waxed(game.world,p,false)
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("888888"),8)
		game.toast("Wax scraped off.")
		if game.gamemode != "creative": game.achievements.award("wax_off")
		game.inventory.damage_tool(); game.sound("place"); game.player.swing = 1
		return true
	var index: int = stage(id)
	if index <= 0: return false
	if not set_stage(game.world,p,id,index-1): return false
	game.puff(Vector3(p)+Vector3.ONE*0.5,Color("888888"),8)
	game.sound("place"); game.player.swing = 1
	return true

# Honeycomb with sneak waxes a placed copper block in place, matching the source
# `register_preserve` on_place branch: the node keeps its stage, one item is
# consumed in survival, and yellow particles play.
static func use_honeycomb(game: Node3D, target: Dictionary) -> bool:
	if game.inventory.held().id != Beehives.COMB or target.is_empty(): return false
	if not Input.is_physical_key_pressed(KEY_CTRL): return false
	var p: Vector3i = target.pos
	var id: int = game.world.node_at(p)
	if stage(id) < 0 or waxed(game.world,p): return false
	set_waxed(game.world,p,true)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.puff(Vector3(p)+Vector3.ONE*0.5,Color("fcbf3c"),8)
	game.toast("Waxed. This block will not oxidize.")
	if game.gamemode != "creative": game.achievements.award("wax_on")
	game.sound("place"); game.player.swing = 1
	return true

# --- lightning --------------------------------------------------------------

# Source `on_lightning_strike` on cut copper stairs and slabs. `get_undecayed`
# clamps to the first entry, so any amount always lands on the pristine stage;
# the distance test and random amount therefore only choose the same result.
static func lightning_strike(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if stage(id) <= 0 or ROD_POWERED_STAGES.has(id) or waxed(world,p): return false
	return set_stage(world,p,id,0)

# A rod mounts on any solid neighbour face, like the source's facedir mesh.
static func supported(world: VoxelWorld, p: Vector3i, placing: bool = false) -> bool:
	for side in [Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var at: Vector3i = p+side
		if not world.loaded_at(Vector3(at)): return not placing
		if Nodes.solid(world.node_at(at)) and not Nodes.transparent(world.node_at(at)): return true
	return false

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not ROD_STAGES.has(held) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos if SnowCover.replaceable(int(target.id)) else target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current) and not Fluids.liquid(current): return true
	if not supported(game.world,at,true): return true
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in ROD_BOXES:
		if body.intersects(AABB(Vector3(at)+box.position,box.size)): return true
	if game.world.set_node(at,held):
		placed_wax(game,at,game.inventory.held())
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,held)
	return true

# A rod needs a solid neighbour; losing it drops the rod.
static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	for side in [Vector3i.ZERO,Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var at: Vector3i = p+side
		var id: int = world.node_at(at)
		if not is_rod(id) or supported(world,at): continue
		if world.set_node(at,Nodes.AIR):
			world.get_parent().spawn_drop(Vector3(at)+Vector3.ONE*0.5,item(id),1)

# The first rod in source scan order (x outer, z middle, y ascending) whose cell
# has air directly above it becomes its powered variant and emits a 15-strength
# strong pulse for four redstone ticks.
static func strike_rod(world: VoxelWorld, strike: Vector3) -> Vector3i:
	var origin := Vector3i(strike.floor())
	for x in range(-64,65):
		for z in range(-64,65):
			for y in range(-32,65):
				var p := origin+Vector3i(x,y,z)
				var id: int = world.node_at(p)
				if not ROD_STAGES.has(id): continue
				if world.node_at(p+Vector3i.UP) != Nodes.AIR: continue
				var index: int = clampi(stage(id),0,3)
				if not world.set_node(p,ROD_POWERED_STAGES[index]): return Vector3i.ZERO
				var state: Dictionary = world.circuits.state(p)
				state["out"] = 15; state["rod_pulse"] = ROD_PULSE; state["powered"] = true
				world.circuits.refresh(p); world.circuits.notify_observers(p)
				return p
	return Vector3i.ZERO

# The powered rod reverts when its pulse expires. Called by the redstone solver.
static func tick_rod(world: VoxelWorld, p: Vector3i, state: Dictionary, delta: float) -> void:
	var remaining: float = float(state.get("rod_pulse",0.0))-delta
	if remaining > 0.00001:
		state["rod_pulse"] = remaining; return
	state.erase("rod_pulse"); state["out"] = 0; state["powered"] = false
	var id: int = world.node_at(p)
	if ROD_POWERED_STAGES.has(id): world.set_node(p,ROD_STAGES[clampi(ROD_POWERED_STAGES.find(id),0,3)])
	world.circuits.refresh(p)

# --- bulbs ------------------------------------------------------------------

# Source `bulb_update`: the lit state toggles on a rising redstone edge and is
# remembered after power is removed, so holding power does not re-toggle.
static func bulb(world: VoxelWorld, p: Vector3i, id: int, state: Dictionary, power: int) -> void:
	if not is_bulb(id): return
	if bool(state.get("bulb_latched",false)):
		if power == 0: state["bulb_latched"] = false
		return
	if power == 0: return
	state["bulb_latched"] = true
	var index: int = clampi(stage(id),0,3)
	var next: int = BULB_OFF_STAGES[index] if bulb_lit(id) else BULB_ON_STAGES[index]
	if world.set_node(p,next):
		state["out"] = 15 if bulb_lit(next) else 0
		world.circuits.refresh(p)

static func light_level(id: int) -> int:
	return LIGHT_LEVELS[clampi(stage(id),0,3)] if is_bulb(id) and bulb_lit(id) else 0

# A struck rod flashes as a light source for its pulse, matching the brightened
# source texture; the powered variant is not otherwise a light emitter.
static func rod_powered_light(id: int) -> bool: return ROD_POWERED_STAGES.has(id)

# Comparator strength: the source `comparator_signal` group is 15 lit and 0 unlit.
static func signal_strength(id: int) -> int:
	return 15 if is_bulb(id) and bulb_lit(id) else 0

# A lit bulb is never an inventory item; it breaks into its unlit form.
static func is_hidden(id: int) -> bool:
	return BULB_ON_STAGES.has(id) or ROD_POWERED_STAGES.has(id)

# --- recipes ----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	for index in 4:
		var block: int = BLOCK_STAGES[index]
		var cut: int = CUT_STAGES[index]
		inv._recipe(Nodes.title(cut),cut,4,[block,block,block,block],2)
		inv._recipe(Nodes.title(GRATE_STAGES[index]),GRATE_STAGES[index],4,[0,block,0,block,0,block,0,block,0],3,"table")
		inv._recipe(Nodes.title(CHISELED_STAGES[index]),CHISELED_STAGES[index],4,[BuildingShapes.slab_for(cut),BuildingShapes.slab_for(cut)],2)
		inv._recipe(Nodes.title(BULB_OFF_STAGES[index]),BULB_OFF_STAGES[index],4,[0,block,0,block,Nodes.BLAZE_ROD,block,0,Nodes.REDSTONE_WIRE,0],3,"table")
		inv._recipe(Nodes.title(ROD_STAGES[index]),ROD_STAGES[index],1,[Nodes.COPPER,0,0,Nodes.COPPER,0,0,Nodes.COPPER],2)
		inv._recipe(DOOR_NAMES[index],DOOR_ITEMS[index],3,[Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER],2,"table")
		inv._recipe(TRAPDOOR_NAMES[index],TRAPDOOR_ITEMS[index],1,[Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER],2)
		# Source waxes by crafting: base plus one honeycomb, one output.
		for base in [block,cut,CHISELED_STAGES[index],GRATE_STAGES[index],BULB_OFF_STAGES[index],ROD_STAGES[index],DOOR_ITEMS[index],TRAPDOOR_ITEMS[index]]:
			inv._shapeless("Waxed "+Nodes.title(base).to_lower(),base,1,[base,Beehives.COMB])
	# Only the pristine block converts back into ingots, as in source.
	inv._recipe("Copper ingots",Nodes.COPPER,9,[Nodes.COPPER_NODE],1)

# --- art --------------------------------------------------------------------

# The base colour of any copper id. DATA holds the decorative stages; the
# remaining chains (block, bulbs, rods, doors, trapdoors, shapes) reuse the
# matching oxidised copper tint.
const BLOCK_COLORS = ["c17e58","b3876c","8aa38c","76ab8e"]
static func tint(id: int) -> Color:
	if DATA.has(id): return Color(DATA[id].color)
	var index: int = clampi(stage(id),0,3)
	return Color(BLOCK_COLORS[index])

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == Nodes.COPPER_NODE:
		var rock: Color = Color("898b87")*(0.9+float((x/3*3+y/2*7)%5)*0.03)
		return Color("c17e58") if (x/2*7+y/2*11)%13 < 4 else rock
	var index: int = clampi(stage(id),0,3)
	var base: Color = tint(id)
	if is_bulb(id) and bulb_lit(id):
		if maxi(absi(x-7),absi(y-7)) <= 3: return Color("fff0bd") if (x+y)%3 else Color("ffd171")
		return base.darkened(0.08)
	if GRATE_STAGES.has(id):
		# An open lattice; the terrain shader's alpha scissor removes the holes.
		if x%4 == 0 or y%4 == 0: return base
		if (x/2+y/2)%3 == 0 and x%4 != 1 and y%4 != 1: return base.darkened(0.12)
		return Color(base.r,base.g,base.b,0.0)
	if is_rod(id): return base.lightened(0.18) if x in [6,7,8,9] else base.darkened(0.2)
	if CHISELED_STAGES.has(id):
		if x in [0,15] or y in [0,15]: return base.darkened(0.24)
		if x in range(2,14) and y in range(2,14) and (x in [2,13] or y in [2,13]): return base.lightened(0.16)
		return base.darkened(0.1) if (x+y)%5 == 0 else base
	if CUT_STAGES.has(id):
		if x%8 in [0,1] or y%8 in [0,1]: return base.darkened(0.2)
		if x%8 in [3,4] or y%8 in [3,4]: return base.lightened(0.14)
		return base
	if index == 3: return base.lightened(0.06) if (x*3+y)%11 == 0 else base
	if index == 2: return base.darkened(0.1) if (x/2+y/2)%3 == 0 else base
	if index == 1: return base.lightened(0.08) if (x+y*2)%7 == 0 else base
	return base.lightened(0.1) if x%4 == 0 or y%4 == 0 else base

static func draw(img: Image, id: int) -> void:
	if not is_copper(id): return
	var base: Color = tint(id)
	if is_rod(id):
		img.fill_rect(Rect2i(6,2,4,12),base.darkened(0.15))
		img.fill_rect(Rect2i(4,1,8,4),base.lightened(0.2)); return
	if GRATE_STAGES.has(id):
		img.fill_rect(Rect2i(2,2,12,12),base.darkened(0.12))
		for i in 4: img.fill_rect(Rect2i(3+i*3,3,1,10),base.lightened(0.2))
		return
	ItemArt._polygon(img,[[2,4],[13,2],[15,6],[12,13],[4,14],[1,9]],base)
	ItemArt._line(img,Vector2(3,6),Vector2(13,4),base.lightened(0.32))
	ItemArt._line(img,Vector2(4,12),Vector2(12,10),base.darkened(0.28))
	if is_bulb(id) and bulb_lit(id): img.fill_rect(Rect2i(5,5,6,6),Color("fff0bd"))

static func boxes(id: int) -> Array:
	return ROD_BOXES if is_rod(id) else [AABB(Vector3.ZERO,Vector3.ONE)]

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if not is_rod(id):
		BlockMesher._art_box(out,p+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(id,0),Nodes.tile(id,2)); return
	for box in ROD_BOXES:
		BlockMesher._art_box(out,p+box.get_center(),box.size,Nodes.tile(id,0),Nodes.tile(id,2))

static func icon_faces(id: int) -> Array:
	id = item(id)
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]
