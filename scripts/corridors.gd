class_name Corridors
extends RefCounted

# Mineclonia MAPGEN/mcl_levelgen/mineshaft.lua, GPL-3.0-or-later. Original
# GDScript port; no source code or asset is copied.
#
# Which generator this targets matters. Mineclonia ships two mineshaft
# implementations:
#   * `MAPGEN/tsm_railcorridors` — a dirt room with radiating corridor lines. It
#     begins with `if mcl_levelgen.enable_ersatz then return false end`.
#   * `MAPGEN/mcl_levelgen/mineshaft.lua` — a recursive piece-based system.
# `mcl_levelgen_enable_ersatz` defaults to TRUE in `settingtypes.txt`, and the
# installed Luanti reports the `generate_decorations_biomes` feature it also
# requires, so the tsm_railcorridors generator is dead in a default game and the
# piece-based one is what actually runs. This port therefore follows
# `mcl_levelgen/mineshaft.lua`.
#
# The structure is a parlor (a large two-to-four-block-high room) with entrances
# cut in all four cardinal directions, from each of which the generator lays a
# chain of pieces: corridors, junctions and staircases. Every piece is placed
# from a local coordinate frame rotated by its facing, so the same code produces
# a north corridor and an east one. Pieces branch recursively to a depth of eight
# and never stray more than 80 blocks from the parlor in x or z.
#
# Rails are not laid along most corridors: `create_corridor_piece` gives a
# corridor a one-in-three chance of carrying a rail run, and a corridor without
# rails may instead hide a cave-spider spawner. Chests in corridors are not chest
# blocks at all — the source places a RAIL and then constructs a chest minecart
# on top of it, which is why `CART` appears in the loot-bearing paths here.
#
# Voxey has no chunk-callback mapgen hook to write nodes from, so this follows the
# same plan/overlay split as `Dungeons` and `Bastions`: a system is planned once
# per region into a voxel dictionary, cached, then merged into a column's data as
# that column generates. Planning is pure and touches no scene tree, so it stays
# safe to run off-thread.
#
# Recorded source gaps, not repaired:
# - Mineclonia's placement is biome-driven (`has_mineshaft` on a list of biomes,
#   with badlands getting the dark-oak variant). Voxey's region planner has no
#   biome map at this stage, so both wood palettes exist and the oak one is used;
#   `is_mesa` is plumbed through for when a biome map is available.
# - The source measures `structure_biome_test` at the structure's centre and
#   shifts the whole assembly to the surface via `shift_into`. Voxey plans at the
#   fixed underground band instead, matching how the other deep structures work.
# - Voxey has no chain block, so the hanging chain supports are iron bars.

const REGION = 64
# Placement level band, from `mcl_levelgen.placement_level_min/height`.
const LEVEL_MIN = -56
const LEVEL_HEIGHT = 48
const MAX_DEPTH = 8
const PARLOR_REACH = 80
const SIDE = 16

const AIR = Nodes.AIR
const PLANKS = Nodes.PLANKS
const WOOD = Nodes.LOG
const FENCE = Barriers.FENCE_BASES[0]
const COBWEB = VillageContent.COBWEB
const RAIL = Rails.RAIL_BASE
const TORCH = Nodes.TORCH
const SPAWNER = Dungeons.SPAWNER
const CART = Rails.CHEST_CART
# Voxey has no chain block; iron bars serve as the hanging equivalent.
const CHAIN = Nodes.IRON_BARS
const SPAWNER_MOB = "spider"

# Direction names and their facing index, used for the torch wall mountings.
const NORTH = 0
const SOUTH = 1
const WEST = 2
const EAST = 3
const DIR_NAMES = ["north","south","west","east"]

# --- planning ----------------------------------------------------------------

# Plan one mineshaft whose parlor starts at `origin`, or an empty dictionary when
# the parlor cannot be placed there. The source starts a parlor at the centre of
# a chunk-scaled cell with y fixed at 50 before the assembly is shifted; the band
# here is fixed, so the parlor's own y is derived from `origin`.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"carts":{},"rng":RandomNumberGenerator.new(),
		"sample":sample,"bounds_min":origin,"bounds_max":origin,"level_min":LEVEL_MIN,"level_max":LEVEL_MIN+LEVEL_HEIGHT-1}
	state.rng.seed = seed_value
	# The source's parlor origin is the structure origin offset by (+2,+2); its y
	# is the level base. A parlor must sit where the walls are not liquid.
	var parlor: Dictionary = _parlor(state,origin+Vector3i(2,0,2))
	if not _extents_valid(state,parlor.bbox): return {}
	state.pieces = [parlor]
	_parlor_children(state,parlor)
	for piece in state.pieces:
		if piece.kind != "parlor": _place_piece(state,piece)
	_place_parlor(state,parlor)
	state.erase("rng"); state.erase("sample"); state.erase("pieces")
	return state

# --- geometry helpers --------------------------------------------------------

# The source's `reorientate_coords`: a piece's local (x,y,z) maps into the world
# rotated by its facing, so one placement routine serves all four directions.
static func reorientate(piece: Dictionary, x: int, y: int, z: int) -> Vector3i:
	var bbox: Array = piece.bbox
	var dir: int = piece.dir
	match dir:
		NORTH: return Vector3i(bbox[0]+x,bbox[1]+y,bbox[5]-z)
		SOUTH: return Vector3i(bbox[0]+x,bbox[1]+y,bbox[2]+z)
		WEST: return Vector3i(bbox[3]-z,bbox[1]+y,bbox[2]+x)
	return Vector3i(bbox[0]+z,bbox[1]+y,bbox[2]+x)

static func bbox_size(bbox: Array) -> Vector3i:
	return Vector3i(bbox[3]-bbox[0],bbox[4]-bbox[1],bbox[5]-bbox[2])

static func height(bbox: Array) -> int: return bbox[4]-bbox[1]
static func width_x(bbox: Array) -> int: return bbox[3]-bbox[0]+1
static func width_z(bbox: Array) -> int: return bbox[5]-bbox[2]+1
static func x_axis(dir: int) -> bool: return dir == WEST or dir == EAST

# --- voxel access ------------------------------------------------------------

static func node(state: Dictionary, p: Vector3i) -> int:
	if state.voxels.has(p): return int(state.voxels[p])
	return int(state.sample.call(p))

# The source's `mineshaft_writable_p` refuses only its own timber and chains, so
# terrain, air and anything else may be overwritten.
static func writable(state: Dictionary, p: Vector3i) -> bool:
	var id: int = node(state,p)
	return id != PLANKS and id != WOOD and id != FENCE and id != CHAIN

# The source's `mineshaft_air_p`, used where only air may be replaced.
static func air(state: Dictionary, p: Vector3i) -> bool: return node(state,p) == AIR

static func set_node(state: Dictionary, p: Vector3i, id: int) -> bool:
	if not writable(state,p): return false
	state.voxels[p] = id
	_extend(state,p)
	return true

# `set_block_checked` is bounded to the placement level band, which keeps a
# runaway recursion from writing far outside the mineshaft's own depth range.
static func _set_checked(state: Dictionary, p: Vector3i, id: int) -> bool:
	if p.y < state.level_min or p.y > state.level_max: return false
	return set_node(state,p,id)

static func _extend(state: Dictionary, p: Vector3i) -> void:
	var lo: Vector3i = state.bounds_min
	var hi: Vector3i = state.bounds_max
	if p.x < lo.x: state.bounds_min.x = p.x
	if p.y < lo.y: state.bounds_min.y = p.y
	if p.z < lo.z: state.bounds_min.z = p.z
	if p.x > hi.x: state.bounds_max.x = p.x
	if p.y > hi.y: state.bounds_max.y = p.y
	if p.z > hi.z: state.bounds_max.z = p.z

# --- validity ----------------------------------------------------------------

# `extents_valid_p`: the piece's padded bounding box may not sit in a biome that
# blocks mineshafts, and none of its walls may pass through water or lava.
static func _extents_valid(state: Dictionary, bbox: Array) -> bool:
	var ymin: int = maxi(state.level_min,bbox[1]-1)
	var ymax: int = mini(state.level_max,bbox[4]+1)
	# The source also tests the biome at the centre; without a biome map the
	# liquid test is what this port can enforce, and it is the decisive one.
	for x in range(bbox[0]-1,bbox[3]+2):
		for z in range(bbox[2]-1,bbox[5]+2):
			if not _valid_wall(state,Vector3i(x,ymin,z)) or not _valid_wall(state,Vector3i(x,ymax,z)): return false
	for y in range(ymin,ymax+1):
		for z in range(bbox[2]-1,bbox[5]+2):
			if not _valid_wall(state,Vector3i(bbox[0]-1,y,z)) or not _valid_wall(state,Vector3i(bbox[3]+1,y,z)): return false
		for x in range(bbox[0]-1,bbox[3]+2):
			if not _valid_wall(state,Vector3i(x,y,bbox[2]-1)) or not _valid_wall(state,Vector3i(x,y,bbox[5]+1)): return false
	return true

static func _valid_wall(state: Dictionary, p: Vector3i) -> bool:
	var id: int = node(state,p)
	return id != Nodes.WATER and id != Nodes.LAVA and not Fluids.liquid(id)

# --- piece factories ---------------------------------------------------------

static func _parlor(state: Dictionary, at: Vector3i) -> Dictionary:
	var rng: RandomNumberGenerator = state.rng
	# The source's parlor y is 50 before shifting; here it is the middle of the
	# placement band so the assembly stays inside the world it is planned for.
	var y: int = LEVEL_MIN+24
	var bbox: Array = [at.x,y,at.z,at.x+7+rng.randi_range(0,5),y+4+rng.randi_range(0,5),at.z+7+rng.randi_range(0,5)]
	return {"kind":"parlor","dir":NORTH,"bbox":bbox,"depth":0,"entrances":[]}

static func _corridor(state: Dictionary, x: int, y: int, z: int, dir: int, depth: int, length: int) -> Dictionary:
	var bbox: Array = _corridor_bbox(dir,x,y,z,length)
	var rng: RandomNumberGenerator = state.rng
	var rails: bool = rng.randi_range(0,2) == 0
	return {"kind":"corridor","dir":dir,"bbox":bbox,"depth":depth,"num":length/5,
		"rails":rails,"spiders":(not rails) and rng.randi_range(0,22) == 0}

static func _junction(state: Dictionary, x: int, y: int, z: int, dir: int, depth: int) -> Dictionary:
	var tall: bool = state.rng.randi_range(0,3) == 0
	var h: int = 6 if tall else 2
	var bbox: Array = []
	match dir:
		NORTH: bbox = [x-1,y,z-4,x+3,y+h,z]
		SOUTH: bbox = [x-1,y,z,x+3,y+h,z+4]
		WEST: bbox = [x-4,y,z-1,x,y+h,z+3]
		EAST: bbox = [x,y,z-1,x+4,y+h,z+3]
	return {"kind":"junction","dir":dir,"bbox":bbox,"depth":depth,"multistory":h > 3}

static func _staircase(x: int, y: int, z: int, dir: int, depth: int) -> Dictionary:
	var bbox: Array = []
	match dir:
		NORTH: bbox = [x,y-5,z-8,x+2,y+2,z]
		SOUTH: bbox = [x,y-5,z,x+2,y+2,z+8]
		WEST: bbox = [x-8,y-5,z,x,y+2,z+2]
		EAST: bbox = [x,y-5,z,x+8,y+2,z+2]
	return {"kind":"staircase","dir":dir,"bbox":bbox,"depth":depth}

static func _corridor_bbox(dir: int, x: int, y: int, z: int, length: int) -> Array:
	match dir:
		NORTH: return [x,y,z-length+1,x+2,y+2,z]
		SOUTH: return [x,y,z,x+2,y+2,z+length-1]
		WEST: return [x-length+1,y,z,x,y+2,z+2]
	return [x,y,z,x+length-1,y+2,z+2]

# --- piece selection and recursion -------------------------------------------

# `create_random_piece`: junctions 20%, staircases 10%, corridors otherwise. A
# candidate is rejected when its bounding box overlaps an existing piece.
static func _random_piece(state: Dictionary, x: int, y: int, z: int, dir: int, depth: int) -> Dictionary:
	var rng: RandomNumberGenerator = state.rng
	var selector: int = rng.randi_range(0,99)
	var piece: Dictionary = {}
	if selector >= 80:
		var candidate: Dictionary = _junction(state,x,y,z,dir,depth)
		if not _collides(state,candidate.bbox): piece = candidate
	elif selector >= 70:
		var candidate: Dictionary = _staircase(x,y,z,dir,depth)
		if not _collides(state,candidate.bbox): piece = candidate
	else:
		# The source's own corridor length draws from the same RNG as the piece
		# choice, so it must be consumed here rather than inside `_corridor`.
		var length: int = (rng.randi_range(0,2)+2)*5
		piece = _corridor(state,x,y,z,dir,depth,length)
	return piece

static func _collides(state: Dictionary, bbox: Array) -> bool:
	for other in state.pieces:
		var o: Array = other.bbox
		if bbox[0] <= o[3] and bbox[3] >= o[0] and bbox[1] <= o[4] and bbox[4] >= o[1] and bbox[2] <= o[5] and bbox[5] >= o[2]: return true
	return false

# `generate_random_piece`: depth-capped and confined to 80 blocks of the parlor.
static func _generate(state: Dictionary, parlor: Dictionary, x: int, y: int, z: int, dir: int, depth: int) -> Dictionary:
	if depth > MAX_DEPTH: return {}
	var origin: Array = parlor.bbox
	if absi(x-origin[0]) > PARLOR_REACH or absi(z-origin[2]) > PARLOR_REACH: return {}
	var piece: Dictionary = _random_piece(state,x,y,z,dir,depth)
	if piece.is_empty(): return {}
	if not _extents_valid(state,piece.bbox): return {}
	state.pieces.append(piece)
	return piece

# --- children ----------------------------------------------------------------

static func _parlor_children(state: Dictionary, parlor: Dictionary) -> void:
	var rng: RandomNumberGenerator = state.rng
	var bbox: Array = parlor.bbox
	var room_height: int = maxi(1,height(bbox)-4)
	# North and south exits are stepped along the x width; west and east along z.
	for axis in ["x","z"]:
		var span: int = width_x(bbox) if axis == "x" else width_z(bbox)
		for side in [0,1]:
			var spanned: int = 0
			while spanned < span:
				spanned += rng.randi_range(0,span-1)
				if spanned+3 > span: break
				var y: int = bbox[1]+rng.randi_range(0,room_height-1)+1
				var dir: int = (NORTH if side == 0 else SOUTH) if axis == "x" else (WEST if side == 1 else EAST)
				var x: int = 0
				var z: int = 0
				if axis == "x":
					x = bbox[0]+spanned
					z = bbox[2]-1 if side == 0 else bbox[5]+1
				else:
					x = bbox[0]-1 if side == 1 else bbox[3]+1
					z = bbox[2]+spanned
				var piece: Dictionary = _generate(state,parlor,x,y,z,dir,0)
				if not piece.is_empty():
					var pb: Array = piece.bbox
					# The wall between the room and the piece is vacated.
					if axis == "x" and side == 0: parlor.entrances.append([pb[0],pb[1],bbox[2],pb[3],pb[4],bbox[2]+1])
					elif axis == "x": parlor.entrances.append([pb[0],pb[1],bbox[5]-1,pb[3],pb[4],bbox[5]])
					elif side == 1: parlor.entrances.append([bbox[0],pb[1],pb[2],bbox[0]+1,pb[4],pb[5]])
					else: parlor.entrances.append([bbox[3]-1,pb[1],pb[2],bbox[3],pb[4],pb[5]])
				spanned += 4

static func _insert_children(state: Dictionary, piece: Dictionary) -> void:
	var rng: RandomNumberGenerator = state.rng
	var bbox: Array = piece.bbox
	var dir: int = piece.dir
	var depth: int = piece.depth
	match piece.kind:
		"junction":
			# A junction always continues straight on and also turns both ways.
			match dir:
				NORTH:
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[2]-1,NORTH,depth)
					_generate(state,state.pieces[0],bbox[0]-1,bbox[1],bbox[2]+1,WEST,depth)
					_generate(state,state.pieces[0],bbox[3]+1,bbox[1],bbox[2]+1,EAST,depth)
				SOUTH:
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[5]+1,SOUTH,depth)
					_generate(state,state.pieces[0],bbox[0]-1,bbox[1],bbox[2]+1,WEST,depth)
					_generate(state,state.pieces[0],bbox[3]+1,bbox[1],bbox[2]+1,EAST,depth)
				WEST:
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[2]-1,NORTH,depth)
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[5]+1,SOUTH,depth)
					_generate(state,state.pieces[0],bbox[0]-1,bbox[1],bbox[2]+1,WEST,depth)
				EAST:
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[2]-1,NORTH,depth)
					_generate(state,state.pieces[0],bbox[0]+1,bbox[1],bbox[5]+1,SOUTH,depth)
					_generate(state,state.pieces[0],bbox[3]+1,bbox[1],bbox[2]+1,EAST,depth)
			if piece.multistory:
				for d in [NORTH,WEST,EAST,SOUTH]:
					if not rng.randi_range(0,1): continue
					var x: int = bbox[0]+1
					var z: int = bbox[2]+1
					if d == EAST: x = bbox[3]+1
					elif d == WEST: x = bbox[0]-1
					elif d == NORTH: z = bbox[2]-1
					else: z = bbox[5]+1
					_generate(state,state.pieces[0],x,bbox[1]+4,z,d,depth)
		"staircase":
			match dir:
				NORTH: _generate(state,state.pieces[0],bbox[0],bbox[1],bbox[2]-1,NORTH,depth)
				SOUTH: _generate(state,state.pieces[0],bbox[0],bbox[1],bbox[5]+1,SOUTH,depth)
				WEST: _generate(state,state.pieces[0],bbox[0]-1,bbox[1],bbox[2],WEST,depth)
				EAST: _generate(state,state.pieces[0],bbox[3]+1,bbox[1],bbox[2],EAST,depth)
		"corridor":
			# A corridor keeps going two times in three; otherwise it turns.
			var rotate: int = rng.randi_range(0,3)
			var yoff: int = rng.randi_range(0,2)-1
			var nx: int = bbox[0]
			var nz: int = bbox[2]
			var ndir: int = dir
			if x_axis(dir):
				if rotate <= 1: nx = bbox[3]+1 if dir == EAST else bbox[0]-1
				elif rotate == 2: ndir = NORTH; nx = bbox[0]+(1 if dir == EAST else -3); nz = bbox[2]-1
				else: ndir = SOUTH; nx = bbox[0]+(1 if dir == EAST else -3); nz = bbox[5]+1
				if rotate > 1: return_children(state,state.pieces[0],nx,bbox[1]+yoff,nz,ndir,depth)
				else: _generate(state,state.pieces[0],nx,bbox[1]+yoff,nz,ndir,depth)
			else:
				if rotate <= 1: nz = bbox[5]+1 if dir == SOUTH else bbox[2]-1
				elif rotate == 2: ndir = WEST; nz = bbox[2]+(1 if dir == SOUTH else -3); nx = bbox[0]-1
				else: ndir = EAST; nz = bbox[2]+(1 if dir == SOUTH else -3); nx = bbox[3]+1
				if rotate > 1: return_children(state,state.pieces[0],nx,bbox[1]+yoff,nz,ndir,depth)
				else: _generate(state,state.pieces[0],nx,bbox[1]+yoff,nz,ndir,depth)
			# Side branches within eight pieces of the origin.
			if depth < 8:
				if x_axis(dir):
					var x: int = bbox[0]+3
					while x+3 <= bbox[3]:
						var selector: int = rng.randi_range(0,4)
						if selector == 0: _generate(state,state.pieces[0],x,bbox[1],bbox[2]-1,NORTH,depth+1)
						elif selector == 1: _generate(state,state.pieces[0],x,bbox[1],bbox[5]+1,SOUTH,depth+1)
						x += 5
				else:
					var z: int = bbox[2]+3
					while z+3 <= bbox[5]:
						var selector: int = rng.randi_range(0,4)
						if selector == 0: _generate(state,state.pieces[0],bbox[0]-1,bbox[1],z,WEST,depth+1)
						elif selector == 1: _generate(state,state.pieces[0],bbox[3]+1,bbox[1],z,EAST,depth+1)
						z += 5

# A corridor turning away from its own axis needs its child placed at the side
# offset, which the source expresses inline; kept separate for readability.
static func return_children(state: Dictionary, parlor: Dictionary, x: int, y: int, z: int, dir: int, depth: int) -> void:
	_generate(state,parlor,x,y,z,dir,depth)

# --- placement ---------------------------------------------------------------

static func _place_parlor(state: Dictionary, parlor: Dictionary) -> void:
	var bbox: Array = parlor.bbox
	# Hollow the interior two blocks high, then the rounded ceiling above it.
	for x in range(bbox[0],bbox[3]+1):
		for z in range(bbox[2],bbox[5]+1):
			for y in range(bbox[1]+1,bbox[1]+4):
				_set_checked(state,Vector3i(x,y,z),AIR)
	_rounded_ceiling(state,bbox)
	for entrance in parlor.entrances: _clear_box(state,entrance)

# The source's `generate_rounded_ceiling` hollows an elliptical arch: a cell is
# removed when its normalised x/z radius is inside the ellipse at that height.
static func _rounded_ceiling(state: Dictionary, bbox: Array) -> void:
	var x1: int = bbox[0]; var z1: int = bbox[2]
	var y1: int = bbox[1]+4; var y2: int = bbox[4]
	var x2: int = bbox[3]; var z2: int = bbox[5]
	var xtotal: float = x2-x1+1
	var ztotal: float = z2-z1+1
	var ytotal: float = y2-y1+1
	var xcenter: float = x1+xtotal/2.0
	var zcenter: float = z1+ztotal/2.0
	for y in range(y1,y2+1):
		var ry: float = (y-y1+1)/ytotal
		for x in range(x1,x2+1):
			for z in range(z1,z2+1):
				var dx: float = (x+0.5-xcenter)/(xtotal/2.0)
				var dz: float = (z+0.5-zcenter)/(ztotal/2.0)
				if dx*dx+dz*dz <= (1.0-ry)*(1.0-ry)+0.35:
					_set_checked(state,Vector3i(x,y,z),AIR)

static func _clear_box(state: Dictionary, box: Array) -> void:
	for x in range(mini(box[0],box[3]),maxi(box[0],box[3])+1):
		for y in range(box[1],box[4]+1):
			for z in range(mini(box[2],box[5]),maxi(box[2],box[5])+1):
				_set_checked(state,Vector3i(x,y,z),AIR)

static func _place_piece(state: Dictionary, piece: Dictionary) -> void:
	match piece.kind:
		"junction": _place_junction(state,piece)
		"staircase": _place_staircase(state,piece)
		"corridor": _place_corridor(state,piece)

# `junction_place`: a cross-shaped aerated passage, four corner pillars, and a
# floored platform underneath.
static func _place_junction(state: Dictionary, piece: Dictionary) -> void:
	var bbox: Array = piece.bbox
	var multistory: bool = piece.multistory
	if multistory:
		# Two storeys: an east-west and a south-north passage on each level, with
		# a slab between them.
		_aerate(state,piece,1,0,0,bbox[3]-bbox[0]-1,2,bbox[5]-bbox[2])
		_aerate(state,piece,0,0,1,bbox[3]-bbox[0],2,bbox[5]-bbox[2]-1)
		_aerate(state,piece,1,3,0,bbox[3]-bbox[0]-1,5,bbox[5]-bbox[2])
		_aerate(state,piece,0,3,1,bbox[3]-bbox[0],5,bbox[5]-bbox[2]-1)
		_aerate(state,piece,1,3,1,bbox[3]-bbox[0]-1,3,bbox[5]-bbox[2]-1)
	else:
		_aerate(state,piece,1,0,0,bbox[3]-bbox[0]-1,bbox[4]-bbox[1],bbox[5]-bbox[2])
		_aerate(state,piece,0,0,1,bbox[3]-bbox[0],bbox[4]-bbox[1],bbox[5]-bbox[2]-1)
	# Corner pillars stand only where the ceiling is solid above them.
	for corner in [[1,1],[1,bbox[5]-bbox[2]-1],[bbox[3]-bbox[0]-1,1],[bbox[3]-bbox[0]-1,bbox[5]-bbox[2]-1]]:
		_pillar(state,piece,corner[0],0,corner[1],bbox[4]-bbox[1])
	# A platform beneath the junction, patched only where the floor is missing.
	for x in range(bbox[0],bbox[3]+1):
		for z in range(bbox[2],bbox[5]+1):
			_patch_floor(state,Vector3i(x,bbox[1]-1,z))

# `junction_aerate`: carve a local-space box, clipped to the chunk that asked.
static func _aerate(state: Dictionary, piece: Dictionary, x1: int, y1: int, z1: int, x2: int, y2: int, z2: int) -> void:
	for x in range(mini(x1,x2),maxi(x1,x2)+1):
		for y in range(y1,y2+1):
			for z in range(mini(z1,z2),maxi(z1,z2)+1):
				_set_checked(state,reorientate(piece,x,y,z),AIR)

static func _pillar(state: Dictionary, piece: Dictionary, x: int, y: int, z: int, ceiling: int) -> void:
	var at: Vector3i = reorientate(piece,x,ceiling+1,z)
	if node(state,at) == AIR: return
	for level in range(y,ceiling+1):
		_set_checked(state,reorientate(piece,x,level,z),PLANKS)

# `patch_up_floor`: a missing floor under a piece is filled with planks.
static func _patch_floor(state: Dictionary, p: Vector3i) -> void:
	if node(state,p) != AIR: return
	if node(state,p-Vector3i(0,1,0)) == AIR: return
	_set_checked(state,p,PLANKS)

# `staircase_place`: a descending stair cut in five steps.
static func _place_staircase(state: Dictionary, piece: Dictionary) -> void:
	_fill(state,piece,0,5,0,2,7,1,AIR)
	_fill(state,piece,0,0,7,2,2,8,AIR)
	for i in range(1,6):
		_fill(state,piece,0,maxi(1,5-i),2+i-1,2,7-i+1,2+i-1,AIR)

static func _fill(state: Dictionary, piece: Dictionary, x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, id: int) -> void:
	for x in range(mini(x1,x2),maxi(x1,x2)+1):
		for y in range(y1,y2+1):
			for z in range(mini(z1,z2),maxi(z1,z2)+1):
				_set_checked(state,reorientate(piece,x,y,z),id)

# `corridor_place`: a three-wide, two-high tube with an arched roof, timber
# arches every fifth block, cobwebs, occasional chests and spiders, and — for the
# one corridor in three that asks for it — a rail run down the middle.
static func _place_corridor(state: Dictionary, piece: Dictionary) -> void:
	var rng: RandomNumberGenerator = state.rng
	var num: int = int(piece.num)
	var length: int = num*5-1
	_fill(state,piece,0,0,0,2,1,length,AIR)
	_fill(state,piece,0,2,0,2,2,length,AIR)
	if piece.spiders:
		for x in range(0,3):
			for y in range(0,2):
				for z in range(0,length+1):
					if rng.randf() <= 0.6: _set_checked(state,reorientate(piece,x,y,z),COBWEB)
	var spider_created: bool = false
	for section in num:
		var start_z: int = section*5+2
		_supports(state,piece,rng,0,0,start_z,2,2)
		# Cobwebs beside the arches, at descending chances.
		for chance in [0.1,0.05]:
			for x in [0,2]:
				for dz in [-1,1,-2,2]:
					if absi(dz) == 1 and chance != 0.1: continue
					if absi(dz) == 2 and chance != 0.05: continue
					_essay_cobweb(state,piece,rng,chance,x,2,start_z+dz)
		if rng.randi_range(0,99) == 0: _chest(state,piece,rng,2,0,start_z-1)
		if rng.randi_range(0,99) == 0: _chest(state,piece,rng,0,0,start_z+1)
		if piece.spiders and not spider_created: spider_created = _spider(state,piece,rng,start_z)
	# Patch the floor, then hang chains and raise pillars beside the arches.
	for z in range(length+1):
		_patch_floor(state,reorientate(piece,1,-1,z))
	_chains(state,piece,0,-1,2)
	if num > 1: _chains(state,piece,0,-1,length-2)
	if piece.rails:
		for z in range(length+1):
			var at: Vector3i = reorientate(piece,1,-1,z)
			if node(state,at) == AIR: continue
			# The source lowers the rail chance under the surface height.
			var chance: float = 0.9
			if rng.randf() < chance: _set_checked(state,at+Vector3i.UP,RAIL)

# `generate_supports`: a timber arch across the corridor, with fences down each
# side, and occasional torches on the arch. Only built where the roof is solid.
static func _supports(state: Dictionary, piece: Dictionary, rng: RandomNumberGenerator, min_x: int, min_y: int, z: int, max_y: int, max_x: int) -> void:
	for x in range(min_x,max_x+1):
		if node(state,reorientate(piece,x,max_y+1,z)) == AIR: return
	if rng.randi_range(0,3) == 0:
		# A broken arch leaves only its two ends.
		_set_checked(state,reorientate(piece,min_x,max_y,z),PLANKS)
		_set_checked(state,reorientate(piece,max_x,max_y,z),PLANKS)
	else:
		for x in range(min_x,max_x+1):
			_set_checked(state,reorientate(piece,x,max_y,z),PLANKS)
		var wall: int = _torch_param(piece,true)
		if rng.randf() <= 0.05: _set_checked(state,reorientate(piece,min_x+1,max_y,z+1),TORCH)
		if rng.randf() <= 0.05: _set_checked(state,reorientate(piece,min_x+1,max_y,z-1),TORCH)
	for y in range(min_y,max_y):
		_set_checked(state,reorientate(piece,min_x,y,z),FENCE)
		_set_checked(state,reorientate(piece,max_x,y,z),FENCE)

static func _torch_param(piece: Dictionary, reverse: bool) -> int: return 0

# `essay_cobweb`: a cobweb only where the cell is buried and two neighbours are
# sturdy enough to hold it.
static func _essay_cobweb(state: Dictionary, piece: Dictionary, rng: RandomNumberGenerator, chance: float, x: int, y: int, z: int) -> void:
	if rng.randf() >= chance: return
	var at: Vector3i = reorientate(piece,x,y,z)
	if node(state,at) != AIR: return
	var sturdy: int = 0
	for side in [Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if Nodes.solid(node(state,at+side)): sturdy += 1
	if sturdy >= 2: _set_checked(state,at,COBWEB)

# `create_chest`: the source sets a rail and constructs a chest minecart on it,
# so the plan records a rail with a cart on top rather than a chest block.
static func _chest(state: Dictionary, piece: Dictionary, rng: RandomNumberGenerator, x: int, y: int, z: int) -> void:
	var at: Vector3i = reorientate(piece,x,y,z)
	if node(state,at) != AIR: return
	if node(state,at-Vector3i(0,1,0)) == AIR: return
	_set_checked(state,at,RAIL)
	state.carts[at] = rng.randi()
	_extend(state,at)

# `create_spider`: a cave-spider spawner in the corridor's centre line.
static func _spider(state: Dictionary, piece: Dictionary, rng: RandomNumberGenerator, start_z: int) -> bool:
	var z: int = start_z+rng.randi_range(0,2)
	var at: Vector3i = reorientate(piece,1,0,z)
	if node(state,at) != AIR: return false
	_set_checked(state,at,SPAWNER)
	state.spawners[at] = SPAWNER_MOB
	return true

# `build_chains_or_pillars`: from a planks cell, either raise a wooden pillar
# down to the next solid floor or hang a chain up to the next solid ceiling.
static func _build_chain_or_pillar(state: Dictionary, at: Vector3i) -> void:
	var pillars: bool = true
	var chains: bool = true
	var progress: int = 1
	while pillars or chains:
		if pillars:
			var down: Vector3i = at-Vector3i(0,progress,0)
			var below: int = node(state,down)
			if (below == AIR or below == Nodes.WATER) and Nodes.solid(node(state,down-Vector3i(0,1,0))):
				for y in range(down.y,at.y):
					_set_checked(state,Vector3i(at.x,y,at.z),WOOD)
				pillars = false
			else: pillars = progress < 20
		if chains:
			var up: Vector3i = at+Vector3i(0,progress,0)
			var above: int = node(state,up)
			if (above == AIR or above == Nodes.WATER) and Nodes.solid(node(state,up+Vector3i(0,1,0))):
				_set_checked(state,at+Vector3i(0,1,0),FENCE)
				for y in range(at.y+2,up.y+1):
					_set_checked(state,Vector3i(at.x,y,at.z),CHAIN)
				chains = false
			else: chains = progress < 50
		progress += 1
		if progress > 50: break

static func _chains(state: Dictionary, piece: Dictionary, x: int, y: int, z: int) -> void:
	for lx in [x,x+2]:
		var at: Vector3i = reorientate(piece,lx,y,z)
		if node(state,at) == PLANKS: _build_chain_or_pillar(state,at)

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.corridor_cache.has(region): return gen.corridor_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20131,region.y)
	var result: Array = []
	# Mineclonia's placement is `R(0.004, ...)`: roughly one attempt in 250 chunks.
	if rng.randf() < 0.05:
		var origin := Vector3i(region.x*REGION+rng.randi_range(8,REGION-24),LEVEL_MIN+24,region.y*REGION+rng.randi_range(8,REGION-24))
		if WorldBounds.horizontal(origin) and WorldBounds.horizontal(origin+Vector3i(64,0,64)):
			var candidate: Dictionary = plan(gen,origin,rng.randi())
			if not candidate.is_empty(): result.append(candidate)
	if gen.corridor_cache.size() >= 16: gen.corridor_cache.erase(gen.corridor_cache.keys()[0])
	gen.corridor_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	var result: Array = []
	for rx in range(floori((base.x-96)/float(REGION)),floori((base.x+17)/float(REGION))+1):
		for rz in range(floori((base.y-96)/float(REGION)),floori((base.y+17)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var lo: Vector3i = candidate.bounds_min
				var hi: Vector3i = candidate.bounds_max
				if hi.x >= base.x and lo.x <= base.x+17 and hi.z >= base.y and lo.z <= base.y+17: result.append(candidate)
	return result

# Merge every mineshaft voxel into this column's data. Only geological terrain is
# replaced, so a structure or player edit already present keeps priority.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"carts":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			if existing != Nodes.AIR and not Dungeons.ground(existing): continue
			if existing in [Nodes.CHEST,RAIL] or Rails.is_rail(existing): continue
			if p.y < 0: deep[index] = candidate.voxels[p]
			else: data[index] = candidate.voxels[p]
			if x in range(1,17) and z in range(1,17):
				if candidate.spawners.has(p): result.spawners[p] = str(candidate.spawners[p])
		if candidate.carts.is_empty(): continue
		for p in candidate.carts:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 1 or x > 16 or z < 1 or z > 16: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			if (deep[index] if p.y < 0 else data[index]) != RAIL: continue
			result.carts[p] = int(candidate.carts[p])
	return result

# The source's `minecart_loot` table, filled into a chest cart's 27 slots.
static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[TREASURE,1,1],[SUPPLIES,2,4],[SUPPLY_RAILS,3,3]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Mineshaft chest"

# item, weight, minimum, maximum. Zero ids keep unavailable source entries'
# weight rather than redistributing it, matching Voxey's other loot tables.
const TREASURE = [[1200,30,1,1],[Nodes.GOLDEN_APPLE,20,1,1],[VillageContent.ENCHANTED_BOOK,10,1,1],[0,5,1,1],[Nodes.TOOLS+10,5,1,1],[0,1,1,1]]
const SUPPLIES = [[Nodes.BREAD,15,1,3],[Nodes.COAL,10,3,8],[VillageContent.BEETROOT_SEEDS,10,2,4],[FruitCrops.MELON_SEEDS,10,2,4],[FruitCrops.PUMPKIN_SEEDS,10,2,4],[Nodes.IRON,10,1,5],[Nodes.LAPIS,5,4,9],[Nodes.REDSTONE_WIRE,5,4,9],[Nodes.GOLD,5,1,3],[Nodes.DIAMOND,3,1,2]]
const SUPPLY_RAILS = [[RAIL,20,4,8],[Nodes.TORCH,15,1,16],[Rails.ACTIVATOR,5,1,4],[Rails.DETECTOR,5,1,4],[Rails.POWERED,5,1,4]]
