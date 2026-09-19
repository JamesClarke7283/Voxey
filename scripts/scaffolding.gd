class_name Scaffolding
extends RefCounted

# Mineclonia ITEMS/mcl_bamboo/{nodes,recipes}.lua, GPL-3.0-or-later — the
# scaffolding half only. Original GDScript using the source as a reference.
#
# Scaffolding is a temporary climbable frame. The source registers two nodes:
# a vertical `scaffolding` and a horizontal arm `scaffolding_horizontal`, and
# both drop the vertical item. Its defining behaviour is the distance field: each
# scaffold stores its distance from the nearest support in its param2, arms may
# only reach `SCAFFOLD_BASE_AWAY_LIMIT` (6) cells from it, and anything further
# becomes a falling node and drops.
#
# Placement is direction-sensitive, and the source's rules are reproduced:
#   * clicking a scaffold's side while sneaking places a horizontal arm;
#   * looking down steeply (45-90 degrees) extends a run of arms away from you;
#   * otherwise the scaffold towers upward, and clicking a tower's top continues
#     it at the top rather than at the clicked cell.
#
# The source crafts six scaffolding from six bamboo around a string. Voxey's
# bamboo stalk now exists (see `bamboo.gd`), so the recipe uses it and no
# substitution remains. The bamboo wood family is still open and is recorded in
# that module's notes.

const ID = VillageContent.SCAFFOLDING
const HORIZONTAL = VillageContent.SCAFFOLDING_HORIZONTAL
# Source `SCAFFOLD_BASE_AWAY_LIMIT`.
const LIMIT = 6
const SIDES = [Vector3i(0,0,1),Vector3i(0,0,-1),Vector3i(1,0,0),Vector3i(-1,0,0)]

static func is_scaffolding(id: int) -> bool: return id == ID or id == HORIZONTAL

# A support is any scaffold whose stored distance is at or within the limit; the
# source's `distance > LIMIT` marker means "unsupported, fall".
static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	return distance(world,p) <= LIMIT

# The distance field lives in the circuit state table, which Voxey already keys
# per position and persists. A cell with no entry is treated as a fresh support.
static func distance(world: VoxelWorld, p: Vector3i) -> int:
	var state: Dictionary = world.block_states.get(VoxelWorld.station_key(p),{})
	return int(state.get("scaffold",0))

static func set_distance(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	world.block_states[key]["scaffold"] = value

# `update_scaffolding`: recompute distances outward from a support, then drop
# every arm that has ended up beyond the limit. Distances are recomputed rather
# than incremented, so removing a support in the middle correctly strands the far
# end instead of leaving a stale chain.
static func update(world: VoxelWorld, origin: Vector3i) -> void:
	if world.get_parent() == null: return
	var best: Dictionary = {}
	var queue: Array = []
	if is_scaffolding(world.node_at(origin)):
		best[origin] = 0
		queue.append(origin)
	var index: int = 0
	while index < queue.size():
		var at: Vector3i = queue[index]; index += 1
		var value: int = int(best[at])
		if value >= LIMIT: continue
		for side in SIDES:
			var next: Vector3i = at+side
			if not is_scaffolding(world.node_at(next)): continue
			if int(best.get(next,LIMIT+1)) <= value+1: continue
			best[next] = value+1
			queue.append(next)
		# A vertical neighbour is a support at the same distance.
		var up: Vector3i = at+Vector3i.UP
		if is_scaffolding(world.node_at(up)) and int(best.get(up,LIMIT+1)) > value:
			best[up] = value
			queue.append(up)
		var down: Vector3i = at+Vector3i.DOWN
		if is_scaffolding(world.node_at(down)) and int(best.get(down,LIMIT+1)) > value:
			best[down] = value
			queue.append(down)
	# Apply the new distances, and drop anything left unsupported.
	var drops: Array = []
	for at in best:
		set_distance(world,at,int(best[at]))
	for at in best:
		if int(best[at]) > LIMIT: drops.append(at)
	# Scaffolds the flood never reached are stranded, exactly as a removed
	# support leaves them in the source.
	for at in _tracked(world):
		if best.has(at): continue
		drops.append(at)
	for at in drops:
		if not is_scaffolding(world.node_at(at)): continue
		var id: int = world.node_at(at)
		world.set_node(at,Nodes.AIR)
		world.get_parent().spawn_drop(Vector3(at)+Vector3.ONE*0.5,ID,1)
		# The source re-checks the cell above after a fall.
		if is_scaffolding(world.node_at(at+Vector3i.UP)): update(world,at+Vector3i.UP)

# Scaffold cells this world has recorded a distance for.
static func _tracked(world: VoxelWorld) -> Array:
	var result: Array = []
	for key in world.block_states:
		if not world.block_states[key] is Dictionary: continue
		if not world.block_states[key].has("scaffold"): continue
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 3: continue
		result.append(Vector3i(int(parts[0]),int(parts[1]),int(parts[2])))
	return result

# Called when a scaffold is placed or removed, and when a neighbour changes.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if is_scaffolding(old_id) or is_scaffolding(id): update(world,p)
	# `after_destruct` and `check_for_falling` both re-update the cell above.
	if is_scaffolding(id) and is_scaffolding(world.node_at(p+Vector3i.UP)): update(world,p+Vector3i.UP)

# `on_place`: sneak-clicking a side gives an arm, a steep look-down extends a run
# of arms, and anything else towers upward from the clicked support.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != ID or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var normal: Vector3i = target.get("normal",Vector3i.UP)
	var world: VoxelWorld = game.world
	var under: Vector3i = target.pos
	var sneak: bool = Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held)
	var looking_down: float = rad_to_deg(-game.player.camera.rotation.x)
	var node: int = ID
	var dist: int = LIMIT+1
	if is_scaffolding(world.node_at(under)):
		dist = distance(world,under)
		if sneak and under.y == at.y:
			# Place an arm sideways from the clicked scaffold.
			node = HORIZONTAL
			dist += 1
		elif looking_down > 45.0 and looking_down < 90.0 and under.y != at.y:
			# Extend a run of arms away from the player, out to the limit.
			node = HORIZONTAL
			var forward: Vector3 = -game.player.camera.global_basis.z
			var step: Vector3i = Vector3i.ZERO
			if absf(forward.x) > absf(forward.z): step.x = signi(int(signf(forward.x)))
			else: step.z = signi(int(signf(forward.z)))
			var walk: Vector3i = under
			while dist <= LIMIT and is_scaffolding(world.node_at(walk)):
				var next: Vector3i = walk+step
				if world.node_at(next) != Nodes.AIR and not is_scaffolding(world.node_at(next)): break
				at = next
				walk = next
				dist += 1
			dist = distance(world,under)+1
		else:
			# Tower upward from the top of the clicked column.
			var top: Vector3i = under
			while world.node_at(top+Vector3i.UP) == ID: top += Vector3i.UP
			at = top+Vector3i.UP
	var existing: int = world.node_at(at)
	if existing != Nodes.AIR and not SnowCover.replaceable(existing) and not Nodes.plant(existing) and not Fluids.liquid(existing): return true
	if not world.set_node(at,node): return true
	set_distance(world,at,dist)
	update(world,at)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,node)
	return true

# A scaffold is climbable and its collision box is the thin top deck only, so a
# player climbs through the frame rather than standing on every cell.
static func climbable(world: VoxelWorld, cell: Vector3i) -> bool: return is_scaffolding(world.node_at(cell))

static func boxes(id: int) -> Array:
	if not is_scaffolding(id): return []
	# Top deck plus four corner posts, matching the source's node box.
	return [AABB(Vector3(0,0.875,0),Vector3(1,0.125,1)),
		AABB(Vector3(0,0,0),Vector3(0.125,1,0.125)),
		AABB(Vector3(0.875,0,0),Vector3(0.125,1,0.125)),
		AABB(Vector3(0.875,0,0.875),Vector3(0.125,1,0.125)),
		AABB(Vector3(0,0,0.875),Vector3(0.125,1,0.125))]

# --- art --------------------------------------------------------------------

# A woven deck over four corner posts.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var post: bool = (x < 3 or x > 12) and (y < 3 or y > 12)
	if post: return Color("a8894a")
	if x < 3 or x > 12 or y < 3 or y > 12: return Color("b89a58")
	return Color("c8b06a").darkened(0.08 if (x+y) % 4 == 0 else 0.0)

static func draw(img: Image, id: int) -> void:
	img.fill_rect(Rect2i(3,3,10,10),Color("c8b06a"))
	for corner in [[3,3],[11,3],[3,11],[11,11]]:
		img.fill_rect(Rect2i(corner[0],corner[1],2,2),Color("a8894a"))
	ItemArt._line(img,Vector2(3,8),Vector2(12,8),Color("b89a58"))

# The mesh is the source's node box: a thin deck at the top plus four posts.
static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	BlockMesher._art_box(out,p+Vector3(0.5,0.9375,0.5),Vector3(1,0.125,1),tile,tile)
	for corner in [Vector3(0.0625,0.5,0.0625),Vector3(0.9375,0.5,0.0625),Vector3(0.9375,0.5,0.9375),Vector3(0.0625,0.5,0.9375)]:
		BlockMesher._art_box(out,p+corner,Vector3(0.125,1,0.125),tile,tile)

# Source hardness 0 and a 2.5 second burn time.
static func recipes(inv: Inventory) -> void:
	# The source's own shape: a string between two bamboo, then two rows of bamboo
	# with an empty middle.
	inv._recipe("Scaffolding",ID,6,[Bamboo.BAMBOO_ITEM,Nodes.STRING,Bamboo.BAMBOO_ITEM,
		Bamboo.BAMBOO_ITEM,0,Bamboo.BAMBOO_ITEM,Bamboo.BAMBOO_ITEM,0,Bamboo.BAMBOO_ITEM],3,"table")
