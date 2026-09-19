class_name IceSpikes
extends RefCounted

# Mineclonia `mods/MAPGEN/mcl_structures/init.lua` (the two ice-spike schematic
# registrations) and their decorations in `mods/MAPGEN/mcl_biomes/init.lua`.
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# An ice spike is a tall cone of packed ice rising out of snowy ground, and a
# spike field is what makes a frozen plain a landmark rather than a flat white
# expanse. The source registers **two** sizes and places them as biome
# decorations, each with its own noise field:
#
# | Size | Noise | Seed |
# |---|---|---|
# | Small | `offset 0.005, scale 0.001` | 1133 |
# | Large | `scale 0.001` | 1133 |
#
# Both require **snow beneath them** (`snowblock`, `snow` or snowy grass), so a
# spike never grows out of bare stone, and both rotate randomly.
#
# Voxey has a cold biome — `Frostpine highlands` — but nothing that decorates it,
# so its snowy plains were featureless.

# Source `sidelen = 6` for the large spike; the small one places on an 80-block
# decoration grid.
const GRID = 80
const LARGE_GRID = 6
# Source `y_min = 4`.
const MIN_Y = 4

# The two sizes, as the source's own pair of schematics.
const SMALL = "small"
const LARGE = "large"
const KINDS = [SMALL,LARGE]

const BLOCK = DenseMaterials.PACKED_ICE
const CORE = Nodes.ICE

# --- the spike shape ---------------------------------------------------------

# A spike's height, which is its size's own band. The source's schematics are
# fixed shapes, so these are the heights those shapes occupy: a small spike is a
# stub, a large one towers.
static func height(kind: String, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(3,6) if kind == SMALL else rng.randi_range(8,14)
# A spike's base radius, which tapers to a point at the top.
static func radius(kind: String) -> int:
	return 1 if kind == SMALL else 2

# The radius at a height fraction, which is what makes a spike a cone. The base is
# full width and the tip is a single block.
static func radius_at(kind: String, level: int, total: int) -> int:
	if total <= 0: return 0
	var base: int = radius(kind)
	# The spike narrows linearly to one block at its tip.
	var remaining: float = 1.0-float(level)/float(total)
	return maxi(1,int(round(float(base)*remaining)))

# --- generation --------------------------------------------------------------

# Build a spike at a ground position, which is where its base sits. Returns the
# cells it places, so the caller can write them into the column.
static func cells_at(ground: Vector3i, kind: String, rng: RandomNumberGenerator) -> Array:
	var total: int = height(kind,rng)
	var cells: Array = []
	for level in total:
		var r: int = radius_at(kind,level,total)
		# The tip is a single block, so the last level admits only its centre.
		if level == total-1:
			cells.append(ground+Vector3i(0,level,0))
			continue
		for x in range(-r,r+1):
			for z in range(-r,r+1):
				# The taper is circular, so a spike is a cone rather than a pyramid.
				if x*x+z*z > r*r: continue
				cells.append(ground+Vector3i(x,level,z))
	return cells

# --- the decoration pass -----------------------------------------------------

# Decorate a column with ice spikes, which is what the source's two decorations
# do over their own noise fields. Only the cold biome gets spikes, and only on
# snowy ground.
static func decorate(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array, biome_name: String) -> void:
	# A spike field belongs to the frozen plains, which is the biome the source names
	# `IcePlainsSpikes`. Voxey's equivalent is the Frostpine highlands.
	if biome_name != "Frostpine highlands": return
	var rng := RandomNumberGenerator.new()
	rng.seed = gen.hash_at(coord.x,20293,coord.y)
	var base: Vector2i = coord*16
	var base_x: int = base.x-1
	var base_z: int = base.y-1
	for x in range(1,17):
		for z in range(1,17):
			var wx: int = base.x+x-1
			var wz: int = base.y+z-1
			if rng.randf() > 0.02: continue
			# The snowy ground is read the same way every other structure reads
			# terrain, rather than by indexing the halo by hand.
			var surface: int = gen.terrain_height(wx,wz)
			if surface <= MIN_Y: continue
			var ground_id: int = Dungeons.natural(gen,Vector3i(wx,surface,wz))
			if not (ground_id == Nodes.SNOW or ground_id == Nodes.SNOW_BLOCK or ground_id == Nodes.GRASS): continue
			var kind: String = LARGE if rng.randf() < 0.25 else SMALL
			for p in cells_at(Vector3i(wx,surface+1,wz),kind,rng):
				var px: int = p.x-base_x
				var pz: int = p.z-base_z
				if px < 0 or px >= 18 or pz < 0 or pz >= 18: continue
				if p.y < 0 or p.y >= gen.terrain_ceiling(): continue
				var index: int = px+pz*18+p.y*324
				# A spike grows into air only, so it never replaces terrain.
				if data[index] != Nodes.AIR: continue
				data[index] = BLOCK
