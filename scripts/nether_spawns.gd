class_name NetherSpawns
extends RefCounted

# The Nether's natural spawn tables, per biome and inside fortresses, from the
# source's `mcl_mobs.register_spawner` calls. Each entry is
# `[kind, weight, pack_min, pack_max]`.
#
# Monster spawners:
# * Nether wastes: zombified piglin 100 (piglin.lua:1998-2006), ghast 50
#   (ghast.lua:249-260), piglin 15 (piglin.lua:1955-1964), magma cube 2
#   (slime+magma_cube.lua:590-600), enderman 1 (enderman.lua:774-786).
# * Crimson forest: hoglin 9 (hoglin+zoglin.lua:522-532), piglin 5, zombified
#   piglin 1.
# * Warped forest: enderman 1.
# * Soul sand valley: ghast 50, skeleton 20 (skeleton+stray.lua:436-446),
#   enderman 1.
# * Basalt deltas: magma cube 100 (slime+magma_cube.lua:633-641), ghast 40 in
#   packs of one.
# * Nether fortress (a structure spawner, whatever the biome): blaze 10
#   (blaze.lua:303-313), wither skeleton 8 (skeleton_wither.lua:170-180),
#   zombified piglin 5, magma cube 3, skeleton 2.
#
# The creature category has one spawner: the strider, weight 60, in packs of
# one or two, on lava with air above, in every Nether biome (strider.lua:524-541).
#
# A ghast's own position test also passes only one time in twenty
# (ghast.lua:262-272), and a hoglin or piglin never spawns on a nether wart block.
# Voxey's old Nether pool drew blazes and wither skeletons anywhere in the
# dimension; they now spawn only inside a fortress, as the source's
# structure-only spawners have it.

const MONSTERS = {
	"Nether wastes":[["zombified_piglin",100,4,4],["ghast",50,4,4],["piglin",15,4,4],["magma_cube",2,4,4],["enderman",1,1,4]],
	"Crimson forest":[["hoglin",9,3,4],["piglin",5,3,4],["zombified_piglin",1,2,4]],
	"Warped forest":[["enderman",1,1,4]],
	"Soul sand valley":[["ghast",50,4,4],["skeleton",20,5,5],["enderman",1,1,4]],
	"Basalt deltas":[["magma_cube",100,2,5],["ghast",40,1,1]],
}
const FORTRESS = [["blaze",10,2,3],["wither_skeleton",8,5,5],["zombified_piglin",5,4,4],["magma_cube",3,4,4],["skeleton",2,5,5]]
const STRIDER = ["strider",60,1,2]
const GHAST_ODDS = 20
const NO_WART = ["hoglin","piglin"]

static func table_for(biome: String, in_fortress: bool) -> Array:
	return FORTRESS if in_fortress else MONSTERS.get(biome,MONSTERS["Nether wastes"])

# A weighted draw from a table; `roll` is uniform in [0, 1).
static func pick(table: Array, roll: float) -> Array:
	var total: int = 0
	for entry in table: total += int(entry[1])
	var target: float = roll*float(total)
	for entry in table:
		target -= float(entry[1])
		if target < 0.0: return entry
	return table.back()

# `fortress_node`'s footprint: the crossing corridors and the central tower of the
# 160-node fortress lattice, between its floor and its roof.
static func in_fortress(p: Vector3i) -> bool:
	var q := Vector3i(posmod(p.x,160)-60,p.y,posmod(p.z,160)-60)
	if absi(q.x) > 28 or absi(q.z) > 28 or q.y < 27 or q.y > 41: return false
	return absi(q.x) <= 3 or absi(q.z) <= 3 or (absi(q.x) <= 9 and absi(q.z) <= 9)

# The per-mob position test the table's spawners add.
static func allowed(kind: String, world: VoxelWorld, cell: Vector3i, rng: RandomNumberGenerator) -> bool:
	if kind == "ghast" and rng.randi_range(1,GHAST_ODDS) != 1: return false
	if kind in NO_WART and world.node_at(cell+Vector3i.DOWN) == NetherBlocks.NETHER_WART_BLOCK: return false
	return true

# A lava cell with air above, which is where a strider may appear.
static func strider_cell(world: VoxelWorld, near: Vector3, rng: RandomNumberGenerator) -> Vector3i:
	for attempt in 8:
		var column := Vector3i(floori(near.x)+rng.randi_range(-8,8),0,floori(near.z)+rng.randi_range(-8,8))
		for y in range(floori(near.y)+8,floori(near.y)-16,-1):
			var cell := Vector3i(column.x,y,column.z)
			if not world.loaded_at(Vector3(cell)): break
			if Fluids.lava(world.node_at(cell)) and world.node_at(cell+Vector3i.UP) == Nodes.AIR: return cell+Vector3i.UP
	return Vector3i.MAX

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("nether_spawns_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+7919
		world.set_meta("nether_spawns_rng",rng)
	return world.get_meta("nether_spawns_rng")

# One Nether spawn attempt at `pos`: the pack spawned, possibly empty.
static func spawn(game: Node3D, pos: Vector3, rng: RandomNumberGenerator, cap_room: int) -> Array:
	var made: Array = []
	if cap_room <= 0: return made
	var world: VoxelWorld = game.world
	var cell := Vector3i(pos.floor())
	var entry: Array = pick(table_for(world.generator.biome(cell.x,cell.z),in_fortress(cell)),rng.randf())
	var kind: String = entry[0]
	var size: int = mini(rng.randi_range(int(entry[2]),int(entry[3])),cap_room)
	for i in size:
		var at: Vector3 = pos+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2)) if i > 0 else pos
		if kind == "ghast": at = pos+Vector3(rng.randf_range(-4,4),rng.randf_range(6,12),rng.randf_range(-4,4))
		var here := Vector3i(at.floor())
		if not world.loaded_at(at) or world.intersects(at,0.4,1.8 if kind != "ghast" else 4.0): continue
		if not allowed(kind,world,here,rng): continue
		var mob: Node3D = game.spawn_creature(kind,at)
		if mob == null: continue
		if kind == "hoglin" and rng.randf() < Hoglins.BABY_SHARE: Hoglins.make_baby(mob)
		made.append(mob)
	return made
