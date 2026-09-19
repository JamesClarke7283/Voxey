class_name Dripstones
extends RefCounted

# Mineclonia MAPGEN/mcl_terrain_features/init.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# Dripstone is what gives a cave a *shape* rather than a ceiling. The source
# registers three formations, and each one hangs from a ceiling or rises from a
# floor:
#
#   * A **stalactite** hangs *down* (`direction = -1`) from a cave ceiling.
#   * A **stalagmite** rises *up* (`direction = 1`) from a cave floor.
#   * A **column** is both at once, meeting in the middle.
#
# The source's own length rule is reproduced exactly:
#
#   * A stalactite is `min(20, air * random(0.2, 0.6))` — so it is a fraction of
#     the gap it hangs in, never reaching the floor.
#   * A stalagmite is `min(20, air * random(0.4, 0.8))` — a taller fraction.
#   * A column uses `min(20, air * random(0.4, 6))` from both ends, so the two
#     halves usually meet and occasionally overrun.
#
# And its taper formula, which is what makes a dripstone a cone rather than a
# pillar: for each offset `offset_r` from the centre, the length is
# `max_length * (r^2 - offset_r^2) / r^2`. So the centre is longest and the rim is
# shortest, giving the formation its point.
#
# Voxey had the dripstone *block* but nothing that placed it, so caves had no
# dripstone at all.

# Source `r = ceil(max_length / 8)`, the formation's radius.
const RADIUS_DIVISOR = 8
# Source caps every formation at twenty blocks.
const MAX_LENGTH = 20
# Source requires five air neighbours before it places.
const AIR_NEIGHBOURS = 5
# Source `fill_ratio = 0.005`.
const FILL_RATIO = 0.005

# The three formation kinds, as the source registers them.
const STALACTITE = "stalactite"
const STALAGMITE = "stalagmite"
const COLUMN = "column"
const KINDS = [STALACTITE,STALAGMITE,COLUMN]

const BLOCK = VillageContent.DRIPSTONE_BLOCK

# --- the source's shape ------------------------------------------------------

# The length of a dripstone column at a given offset from its centre, which is
# the source's own taper: `max_length * (r^2 - offset_r^2) / r^2`.
static func taper_length(max_length: float, radius: int, offset: float) -> float:
	if radius <= 0: return max_length
	var r2: float = float(radius*radius)
	return max_length*(r2-offset*offset)/r2

# The length a formation grows, which the source rolls per kind.
static func roll_length(kind: String, air: float, rng: RandomNumberGenerator) -> float:
	match kind:
		STALACTITE: return minf(MAX_LENGTH,air*rng.randf_range(0.2,0.6))
		STALAGMITE: return minf(MAX_LENGTH,air*rng.randf_range(0.4,0.8))
		COLUMN: return minf(MAX_LENGTH,air*rng.randf_range(0.4,6.0))
	return 0.0

# --- generation --------------------------------------------------------------

# Build one formation at `origin`, which is the ceiling or floor cell it starts
# from. `direction` is -1 for a stalactite and +1 for a stalagmite, as the source
# passes it. Returns the cells it would place.
static func generate(world: VoxelWorld, origin: Vector3i, max_length: float, direction: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	if max_length < 1.0: return cells
	# Source offsets the formation's centre slightly, so it is asymmetric like a
	# real one rather than a perfect cone.
	var x_offset: float = rng.randf_range(-0.2,0.2)
	var z_offset: float = rng.randf_range(-0.2,0.2)
	var radius: int = int(ceil(max_length/float(RADIUS_DIVISOR)))
	if radius < 1: radius = 1
	for x in range(origin.x-radius,origin.x+radius+1):
		for z in range(origin.z-radius,origin.z+radius+1):
			var offset: float = sqrt(pow(origin.x-(x+x_offset),2.0)+pow(origin.z-(z+z_offset),2.0))
			var length: float = taper_length(max_length,radius,offset)
			var y: int = origin.y
			var placed: int = 0
			# The column extends up to its tapered length in the direction given.
			while placed <= int(length):
				var at := Vector3i(x,y,z)
				# Only air is replaced, so a formation never eats the cave wall.
				if world.node_at(at) != Nodes.AIR: break
				cells.append(at)
				y += direction
				placed += 1
	return cells

# Whether a formation may be placed here: the source requires air at the origin
# and a solid block beyond it in the growth direction.
static func placement_ok(world: VoxelWorld, origin: Vector3i, direction: int) -> bool:
	if world.node_at(origin) != Nodes.AIR: return false
	# The source counts five air neighbours before it will place anything.
	var air: int = 0
	for d in [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP]:
		if world.node_at(origin+d) == Nodes.AIR: air += 1
	if air < AIR_NEIGHBOURS: return false
	# The anchor: a ceiling above a stalactite, or a floor below a stalagmite.
	var anchor: Vector3i = origin-Vector3i(0,direction,0)
	return Nodes.solid(world.node_at(anchor))

# The height of the open gap from a cell, which is what the source measures before
# choosing a length.
static func gap_height(world: VoxelWorld, from: Vector3i, direction: int) -> int:
	var height: int = 0
	while height <= MAX_LENGTH:
		if world.node_at(from+Vector3i(0,height*direction,0)) != Nodes.AIR: break
		height += 1
	return height

# --- placement ---------------------------------------------------------------

# Try to place one formation of a kind at a site, returning the cells placed.
static func place(world: VoxelWorld, origin: Vector3i, kind: String, rng: RandomNumberGenerator) -> Array:
	if not KINDS.has(kind): return []
	var direction: int = -1 if kind == STALACTITE else 1
	if not placement_ok(world,origin,direction): return []
	var air: int = gap_height(world,origin,direction)
	if kind == COLUMN:
		# Source anchors a column at the floor and grows one half from each end.
		var floor_at: Vector3i = origin+Vector3i(0,air,0)
		if not placement_ok(world,floor_at,-1): return []
		var length: float = roll_length(kind,float(air),rng)
		var cells: Array = generate(world,origin,length,1,rng)
		cells.append_array(generate(world,floor_at,length,-1,rng))
		return cells
	var length: float = roll_length(kind,float(air),rng)
	return generate(world,origin,length,direction,rng)

# Place every cell of a formation, which is the world-writing step.
static func apply(world: VoxelWorld, cells: Array) -> int:
	var placed: int = 0
	for p in cells:
		if world.node_at(p) != Nodes.AIR: continue
		if world.set_node(p,BLOCK): placed += 1
	return placed

# --- the generation pass -----------------------------------------------------

# Decorate a column's caves with dripstone. The column's own data is read, so a
# formation never crosses a chunk boundary, and only air is ever replaced, so the
# cave keeps its shape and dripstone is added to it.
static func decorate(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.hash_at(coord.x,20287,coord.y)
	var base: Vector2i = coord*16
	# The caves worth decorating are underground but above the deep bedrock, which
	# is the source's own `y_min`/`y_max` band.
	var ceiling: int = mini(gen.terrain_ceiling()-8,0)
	var floor: int = TerrainGenerator.OVERWORLD_MIN+4
	for x in range(1,17):
		for z in range(1,17):
			var wx: int = base.x+x-1
			var wz: int = base.y+z-1
			for y in range(floor,ceiling):
				if rng.randf() > FILL_RATIO: continue
				var index: int = x+z*18+(y-gen.min_y() if y < 0 else y)*324
				var id: int = deep[index] if y < 0 else data[index]
				if id != Nodes.AIR: continue
				var at := Vector3i(wx,y,wz)
				# A stalactite hangs from a ceiling, a stalagmite rises from a floor,
				# and a column does both. Only one is attempted per site.
				var kind: String = KINDS[rng.randi_range(0,KINDS.size()-1)]
				var direction: int = -1 if kind == STALACTITE else 1
				if not placement_ok_in_column(gen,data,deep,base,at,direction): continue
				var air: int = gap_in_column(gen,data,deep,base,at,direction)
				if air < 2: continue
				var length: float = roll_length(kind,float(air),rng)
				for p in generate_in_column(gen,data,deep,base,at,length,direction,rng):
					var pi: int = p.x-base.x+1+(p.z-base.y+1)*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
					if p.y < 0: deep[pi] = BLOCK
					else: data[pi] = BLOCK

# The column-safe versions of the placement checks, which read the column's own
# arrays rather than the live world so generation stays on the worker.
static func placement_ok_in_column(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, at: Vector3i, direction: int) -> bool:
	if node_in_column(gen,data,deep,base,at) != Nodes.AIR: return false
	var anchor: Vector3i = at-Vector3i(0,direction,0)
	return Nodes.solid(node_in_column(gen,data,deep,base,anchor))

static func gap_in_column(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, from: Vector3i, direction: int) -> int:
	var height: int = 0
	while height <= MAX_LENGTH:
		if node_in_column(gen,data,deep,base,from+Vector3i(0,height*direction,0)) != Nodes.AIR: break
		height += 1
	return height

static func node_in_column(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, p: Vector3i) -> int:
	var x: int = p.x-base.x+1
	var z: int = p.z-base.y+1
	if x < 0 or x >= 18 or z < 0 or z >= 18: return Nodes.BEDROCK
	if p.y < gen.min_y() or p.y >= gen.terrain_ceiling(): return Nodes.BEDROCK
	return deep[x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324]

static func generate_in_column(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, origin: Vector3i, max_length: float, direction: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	if max_length < 1.0: return cells
	var x_offset: float = rng.randf_range(-0.2,0.2)
	var z_offset: float = rng.randf_range(-0.2,0.2)
	var radius: int = maxi(1,int(ceil(max_length/float(RADIUS_DIVISOR))))
	for x in range(origin.x-radius,origin.x+radius+1):
		for z in range(origin.z-radius,origin.z+radius+1):
			var offset: float = sqrt(pow(origin.x-(x+x_offset),2.0)+pow(origin.z-(z+z_offset),2.0))
			var length: float = taper_length(max_length,radius,offset)
			var y: int = origin.y
			var placed: int = 0
			while placed <= int(length):
				var at := Vector3i(x,y,z)
				if node_in_column(gen,data,deep,base,at) != Nodes.AIR: break
				cells.append(at)
				y += direction
				placed += 1
	return cells
