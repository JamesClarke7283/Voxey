class_name LushCaves
extends RefCounted

# Mineclonia ITEMS/mcl_lush_caves/{nodes,crafting}.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference; art is original procedural
# code.
#
#   * **Cave vines** hang from a ceiling and are climbable. Their lit form carries
#     **glow berries** and emits light 14.
#   * **Bone meal** lights the exact unlit node clicked, preserving its age.
#   * **Right-clicking a lit vine** drops one glow berry and reverts only that node.
#   * Shears stop the lowest unlit tip growing by setting its age to 25.
#   * Loaded vines receive the source's 180-second, one-in-five growth cycle. A new
#     lowest cell has age + 1 and an 11% chance to be lit; age 25 stops growth.
#   * A glow berry is food (2 points, saturation 1.2), compostable at 50%, and can
#     be planted on an underside without also beginning the eating action.
# The rest of the set — moss, moss carpet, hanging roots and rooted dirt — is
# decorative ground cover that completes the biome's look.

# The vine's two forms, and the berry they carry.
const CAVE_VINES = 1177
const CAVE_VINES_LIT = 1178
const GLOW_BERRY = 1179
# The three ground-cover blocks of the biome.
const MOSS = 1204
const MOSS_CARPET = 1205
const HANGING_ROOTS = 1206
const BLOCKS = [CAVE_VINES,CAVE_VINES_LIT,MOSS,MOSS_CARPET,HANGING_ROOTS]

# Source ABM and param2 limits. Voxey saves param2 as `cave_vine_age` in the
# world's persistent `block_states`, keyed by `VoxelWorld.station_key`.
const INTERVAL = 180.0
const CHANCE = 5
const MAX_AGE = 25
const BERRY_CHANCE = 0.11
const LIT_LIGHT = 14
const AGE_KEY = "cave_vine_age"
const ELAPSED_KEY = "lush_cave_vine_elapsed"
const BERRY_FOOD = 2
const BERRY_SATURATION = 1.2
const BERRY_COMPOST = 50
const MOSS_COMPOST = 65

# Whether a node can be climbed. The source gives a cave vine `climbable = true`, so
# a player can hold forward against a hanging strand and go up it, exactly as with a
# ladder. A lit or unlit vine climbs alike.
static func climbable(world: VoxelWorld, cell: Vector3i) -> bool:
	return is_vine(world.node_at(cell))

static func is_vine(id: int) -> bool: return id == CAVE_VINES or id == CAVE_VINES_LIT
static func is_lit_vine(id: int) -> bool: return id == CAVE_VINES_LIT
static func is_glow_berry(id: int) -> bool: return id == GLOW_BERRY

# A constant with literal keys, so the content table can reference it without a
# const cycle.
const BLOCK_DATA = {
	1177: {"name":"Cave vines","block":true,"shape":"vine","color":"5d8b3c","hardness":0.0,"tool":2,"plant":true,"climbable":true,"drop":0,"hidden":true},
	1178: {"name":"Lit cave vines","block":true,"shape":"vine","color":"7fae4a","hardness":0.0,"tool":2,"plant":true,"climbable":true,"light":LIT_LIGHT,"emits":LIT_LIGHT,"drop":GLOW_BERRY,"hidden":true},
	1179: {"name":"Glow berry","color":"e8b34a","food":BERRY_FOOD,"saturation":BERRY_SATURATION,"compostability":BERRY_COMPOST},
	1204: {"name":"Moss block","block":true,"color":"5a7a3c","hardness":0.1,"tool":4,"compostability":MOSS_COMPOST},
	1205: {"name":"Moss carpet","block":true,"shape":"carpet","color":"5a7a3c","hardness":0.1,"tool":2},
	1206: {"name":"Hanging roots","block":true,"shape":"plant","color":"6b5636","hardness":0.0,"tool":2,"plant":true},
}

# --- the vine's light --------------------------------------------------------

# A vine's light, which is what makes a lush cave visible.
static func light_level(id: int) -> int:
	return LIT_LIGHT if is_lit_vine(id) else 0

# --- growing berries ---------------------------------------------------------

# `_on_bone_meal` changes only the clicked unlit node. It does not find the tip and
# it carries the clicked node's param2 into the lit form.
static func ripen(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != CAVE_VINES: return false
	var saved_age: int = age(world,p)
	if not world.set_node(p,CAVE_VINES_LIT): return false
	set_age(world,p,saved_age)
	return true

# The lowest vine cell of the tower a vine belongs to, which is where berries grow.
static func vine_tip(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var tip: Vector3i = p
	while is_vine(world.node_at(tip+Vector3i.DOWN)): tip += Vector3i.DOWN
	return tip

# The topmost vine cell, which is the one attached to the ceiling.
static func vine_top(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var top: Vector3i = p
	while is_vine(world.node_at(top+Vector3i.UP)): top += Vector3i.UP
	return top

# `param2` is saved independently of node id, so bone meal and harvesting preserve
# it. Zero is the default and needs no dictionary entry; non-vine changes clear it.
static func age(world: VoxelWorld, p: Vector3i) -> int:
	return maxi(0,int(world.block_states.get(VoxelWorld.station_key(p),{}).get(AGE_KEY,0)))

static func set_age(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	if value <= 0: state.erase(AGE_KEY)
	else: state[AGE_KEY] = value
	if state.is_empty(): world.block_states.erase(key)
	else: world.block_states[key] = state

# --- interactions ------------------------------------------------------------

# Lit `on_rightclick`: core.add_item creates one item entity before the node loses
# its light. This is a world drop, not a silent inventory insertion.
static func harvest(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != CAVE_VINES_LIT: return false
	var saved_age: int = age(world,p)
	game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,GLOW_BERRY,1)
	if not world.set_node(p,CAVE_VINES): return false
	set_age(world,p,saved_age)
	return true

# Unlit `_on_shears_place`: only the clicked lowest tip is accepted. Off-tip use is
# handled but does not wear the shears (the source's second return value is true).
static func shear(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != CAVE_VINES or vine_tip(world,p) != p: return false
	set_age(world,p,MAX_AGE)
	return true

# grow_vines adds only the new cell; it does not relight or age the old tip. The
# source makes its 11% roll before discovering that the cell below is occupied.
static func grow_tip(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator) -> bool:
	if not world.loaded_at(Vector3(p)) or not is_vine(world.node_at(p)) or vine_tip(world,p) != p: return false
	var old_age: int = age(world,p)
	if old_age >= MAX_AGE: return false
	var below: Vector3i = p+Vector3i.DOWN
	var new_id: int = CAVE_VINES_LIT if rng.randf() <= BERRY_CHANCE else CAVE_VINES
	if not world.loaded_at(Vector3(below)) or world.node_at(below) != Nodes.AIR: return false
	if not world.set_node(below,new_id): return false
	set_age(world,below,old_age+1)
	return true

# Voxey's shared air/snow/plant/liquid/fire replacement vocabulary corresponds to
# source buildable_to. Cave/nether vine nodes themselves are not buildable_to even
# though the renderer classifies them as plants.
static func buildable_to(id: int) -> bool:
	return not is_vine(id) and not CrimsonPlants.is_vine(id) and Doors.replaceable(id)

# Glow berries have an on_place callback even though they are food. Returning true
# for every node-targeted berry click is what keeps a failed placement from falling
# through to Eating.start; successful placement consumes one outside creative.
static func plant(game: Node3D, target: Dictionary, rng: RandomNumberGenerator = null) -> bool:
	var world: VoxelWorld = game.world
	var under: Vector3i = target.get("pos",Vector3i.ZERO)
	if target.get("normal",Vector3i.ZERO) != Vector3i.DOWN: return true
	if not world.loaded_at(Vector3(under)): return true
	var below: Vector3i = under+Vector3i.DOWN
	if not world.loaded_at(Vector3(below)): return true
	var under_id: int = world.node_at(under)
	# Source rejects every other vinelike_node=2 form: lit cave vines and weeping
	# vines. Other solid undersides are deliberately accepted.
	if under_id == CAVE_VINES_LIT or under_id == CrimsonPlants.WEEPING_VINES: return true
	var below_id: int = world.node_at(below)
	if not buildable_to(below_id): return true
	var new_age: int = age(world,under)+1 if under_id == CAVE_VINES else 0
	# Preserve nodes.lua:320 exactly: core.place_node acts on `under`, not `above`.
	# Luanti's placement honors buildable_to: on ordinary stone this unusual call is
	# a no-op, while a buildable clicked node becomes an unlit vine. The source then
	# unconditionally swaps the new cell below; it does not redirect the first call
	# to `above`, and it does not overwrite the stone support.
	if buildable_to(under_id): world.set_node(under,CAVE_VINES)
	if under_id != CAVE_VINES: set_age(world,under,0)
	if rng == null: rng = runtime(world).rng
	var new_id: int = CAVE_VINES_LIT if rng.randf() <= BERRY_CHANCE else CAVE_VINES
	if not world.set_node(below,new_id): return true
	set_age(world,below,new_age)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	if under_id != CAVE_VINES and world.node_at(under) == CAVE_VINES: game.api.emit_node_placed(under,CAVE_VINES)
	game.api.emit_node_placed(below,new_id)
	return true

# Single player-use entry point. It must run before Hunger.can_eat and before the
# generic placement path. Bone meal consumes only when its callback succeeds.
static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty(): return false
	var world: VoxelWorld = game.world
	var p: Vector3i = target.get("pos",Vector3i.ZERO)
	var id: int = world.node_at(p)
	var held: int = int(game.inventory.held().get("id",0))
	if held == Nodes.BONE_MEAL and id == CAVE_VINES:
		if ripen(world,p):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); game.player.swing = 1
		return true
	if id == CAVE_VINES_LIT:
		if harvest(game,p): game.player.swing = 1
		return true
	if held == Nodes.SHEARS and id == CAVE_VINES:
		if shear(world,p):
			if game.gamemode != "creative": game.inventory.damage_tool()
			game.sound("place"); game.player.swing = 1
		return true
	if held == GLOW_BERRY: return plant(game,target)
	return false

# --- loaded-column simulation ------------------------------------------------

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("lush_cave_vines"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+1179
		world.set_meta("lush_cave_vines",{"cells":{},"columns":{},"jobs":[],"cursor":0,"rng":rng})
	return world.get_meta("lush_cave_vines")

static func tracks(world: VoxelWorld, p: Vector3i) -> bool:
	return world.has_meta("lush_cave_vines") and runtime(world).cells.has(p)

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_vine(id) or not world.loaded_at(Vector3(p)): return
	var data: Dictionary = runtime(world)
	data.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("lush_cave_vines"): return
	var data: Dictionary = runtime(world); data.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.columns.has(column):
		data.columns[column].erase(p)
		if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i, _old: int, id: int) -> void:
	forget(world,p); registered(world,p,id)
	if not is_vine(id): set_age(world,p,0)
	validate_support(world,p)
	validate_support(world,p+Vector3i.DOWN)

# Unsupported vines are removed, not turned into collectible vine items: unlit
# drop="" while lit drop is one glow berry. set_node recursively validates the
# next cell down, so removing a support settles the hanging strand.
static func validate_support(world: VoxelWorld, p: Vector3i) -> void:
	if not world.loaded_at(Vector3(p)): return
	var id: int = world.node_at(p)
	if not is_vine(id) or supported(world,p): return
	# mcl_attached/init.lua:147-151 makes one unusual exception: a non-solid,
	# non-airlike node above does not detach a downward vine. Literal air does.
	var above: int = world.node_at(p+Vector3i.UP)
	if above != Nodes.AIR and not is_vine(above): return
	if world.set_node(p,Nodes.AIR) and id == CAVE_VINES_LIT:
		world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,GLOW_BERRY,1)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("lush_cave_vines"): return
	for p in runtime(world).columns.get(column,{}).keys(): validate_support(world,p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("lush_cave_vines"): return
	for p in runtime(world).columns.get(column,{}).keys(): forget(world,p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("lush_cave_vines"): world.remove_meta("lush_cave_vines")

static func update(world: VoxelWorld, delta: float, supplied_rng: RandomNumberGenerator = null) -> void:
	if not world.has_meta("lush_cave_vines") or not world.get_parent().playing(): return
	var data: Dictionary = runtime(world)
	var elapsed: float = float(world.adventure_state.get(ELAPSED_KEY,0.0))
	elapsed = maxf(0,elapsed) if is_finite(elapsed) else 0.0
	elapsed += maxf(0,delta)
	if elapsed >= INTERVAL and data.cursor >= data.jobs.size():
		elapsed = fmod(elapsed,INTERVAL); data.jobs.clear(); data.cursor = 0
		for p in data.cells: data.jobs.append([p,data.cells[p]])
	world.adventure_state[ELAPSED_KEY] = minf(elapsed,INTERVAL)
	var rng: RandomNumberGenerator = supplied_rng if supplied_rng != null else data.rng
	# Bound work per frame without skipping cells: unfinished jobs keep their cursor
	# and the next ABM snapshot cannot replace them.
	for i in 16:
		if data.cursor >= data.jobs.size(): break
		var entry: Array = data.jobs[data.cursor]; data.cursor += 1
		var p: Vector3i = entry[0]; var id: int = entry[1]
		if not data.cells.has(p) or world.node_at(p) != id: continue
		if rng.randi_range(1,CHANCE) == 1: grow_tip(world,p,rng)
	if data.cursor >= data.jobs.size(): data.jobs.clear(); data.cursor = 0

# --- vines need a ceiling ----------------------------------------------------

# Whether a vine may hang at `p`: the source's `vinelike_node` needs something solid
# above it, or another vine. `Vector3i.UP` is positive Y, so the cell above is `p+UP`.
static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)): return false
	var above: int = world.node_at(p+Vector3i.UP)
	return is_vine(above) or Nodes.solid(above)

# --- ground cover ------------------------------------------------------------

# The ground cover the source's biome uses: moss grows on stone or dirt, and rooted
# dirt is dirt turned by a hanging root.
static func cover_soil(id: int) -> bool:
	return id in [Nodes.DIRT,Nodes.STONE,Nodes.COBBLE,Nodes.GRASS]

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source `mcl_lush_caves/crafting.lua`: a moss block beside a cobble makes mossy
	# cobble, and a moss block beside a stone brick makes mossy stone bricks. Both
	# are the recipes Voxey previously could not offer because moss did not exist.
	inv._shapeless("Mossy cobblestone",Nodes.MOSSY_COBBLE,1,[Nodes.COBBLE,MOSS])
	inv._shapeless("Mossy stone bricks",1161,1,[Nodes.BRICKS,MOSS])
	# Source `mcl_lush_caves/nodes.lua:109`: two moss make three moss carpet, which
	# was the one missing recipe in this family.
	inv._recipe("Moss carpet",1205,3,[MOSS,MOSS],2)

# --- art ---------------------------------------------------------------------

# Inventory art is separate from the atlas pixel callback because the berry is a
# craftitem, not a placeable vine node. VillageItemArt delegates GLOW_BERRY here.
static func draw(img: Image, id: int) -> void:
	if id != GLOW_BERRY: return
	ItemArt._line(img,Vector2(7,3),Vector2(9,7),Color("52713a"),2)
	ItemArt._line(img,Vector2(8,4),Vector2(11,2),Color("6f9846"),1)
	ItemArt._polygon(img,[[3,7],[6,5],[10,6],[13,9],[12,13],[8,15],[4,13],[2,10]],Color("dba13b"))
	ItemArt._polygon(img,[[5,7],[8,6],[11,8],[10,11],[7,12],[4,10]],Color("f2c452"))
	img.set_pixel(6,8,Color("fff0a0")); img.set_pixel(7,8,Color("fff0a0"))

# A vine is a hanging strand with berries on the lit form, and moss is a rough
# green ground cover.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_vine(id):
		# Two strands with a gap between, so a vine reads as thin rather than solid.
		if x in [5,6] or x in [9,10]:
			var stem: Color = Color("5d8b3c") if id == CAVE_VINES else Color("7fae4a")
			# A lit vine carries round berries along its length.
			if id == CAVE_VINES_LIT and y%5 == 2: return Color("e8b34a")
			return stem.darkened(0.1*float((x+y)%3))
		return Color(0,0,0,0)
	if id == MOSS: return Color("5a7a3c").darkened(0.09*float((x*3+y*5)%3))
	if id == MOSS_CARPET: return Color("5a7a3c").darkened(0.06*float((x+y)%3)) if y > 3 else Color(0,0,0,0)
	if id == HANGING_ROOTS:
		return Color("6b5636").darkened(0.1*float((x*5+y)%3)) if x in [3,7,11] else Color(0,0,0,0)
	if is_glow_berry(id):
		# A berry with its own glow, which is what the item represents.
		return Color("e8b34a") if (x-7)*(x-7)+(y-9)*(y-9) < 14 else Color(0,0,0,0)
	return Color(0,0,0,0)
