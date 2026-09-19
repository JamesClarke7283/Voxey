class_name Conduits
extends RefCounted

# Mineclonia ITEMS/mcl_conduits/init.lua and ITEMS/mcl_ocean/prismarine.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# The conduit is an underwater beacon. The reference's `check_conduit` is the
# whole mechanic and it has three parts:
#
#   1. **Water** — the 3x3x3 volume around the conduit must be at least 26 water
#      cells when the conduit is already an entity, or 27 when it is still a
#      node (the conduit's own cell counts once it has become an entity).
#   2. **Frame** — the source lists 42 exact offset positions and counts how many
#      hold prismarine or a sea lantern. Fewer than 16 means no activation.
#   3. **Power** — the active range is `floor(frame_count / 7) * 16`, so the
#      frame's size sets how far the effect reaches.
#
# An active conduit also damages hostile creatures in the water within 9 blocks,
# and it reverts to a plain node the moment its frame or water is broken.
#
# The prismarine family supplies the frame: prismarine, prismarine bricks, dark
# prismarine and the sea lantern. Prismarine shards and crystals come from
# guardians and sea lanterns in the reference; Voxey has neither guardian nor
# ocean monument, so the crafting route is used, and that is recorded below.

const CONDUIT = VillageContent.CONDUIT
const PRISMARINE = VillageContent.PRISMARINE
const PRISMARINE_BRICK = VillageContent.PRISMARINE_BRICK
const PRISMARINE_DARK = VillageContent.PRISMARINE_DARK
const SEA_LANTERN = VillageContent.SEA_LANTERN
const SHARD = VillageContent.PRISMARINE_SHARD
const CRYSTALS = VillageContent.PRISMARINE_CRYSTALS

# Source `check_interval`.
const INTERVAL = 5.0
# Source `conduit_nodes`: which blocks count as frame.
const FRAME_BLOCKS = [PRISMARINE,PRISMARINE_BRICK,PRISMARINE_DARK,SEA_LANTERN]
# Source `frame_offsets`, all 42 positions.
const FRAME_OFFSETS = [
	Vector3i(1,2,0),Vector3i(2,2,0),Vector3i(-1,2,0),Vector3i(-2,2,0),Vector3i(0,2,0),
	Vector3i(0,2,1),Vector3i(0,2,2),Vector3i(0,2,-1),Vector3i(0,2,-2),
	Vector3i(2,1,0),Vector3i(-2,1,0),Vector3i(0,1,2),Vector3i(0,1,-2),
	Vector3i(2,0,0),Vector3i(2,0,1),Vector3i(2,0,2),
	Vector3i(-2,0,0),Vector3i(-2,0,1),Vector3i(-2,0,2),
	Vector3i(2,0,-1),Vector3i(2,0,-2),Vector3i(-2,0,-1),Vector3i(-2,0,-2),
	Vector3i(0,0,2),Vector3i(1,0,2),
	Vector3i(0,0,-2),Vector3i(1,0,-2),
	Vector3i(-1,0,2),Vector3i(-1,0,-2),
	Vector3i(2,-1,0),Vector3i(-2,-1,0),Vector3i(0,-1,2),Vector3i(0,-1,-2),
	Vector3i(1,-2,0),Vector3i(2,-2,0),Vector3i(-1,-2,0),Vector3i(-2,-2,0),Vector3i(0,-2,0),
	Vector3i(0,-2,1),Vector3i(0,-2,2),Vector3i(0,-2,-1),Vector3i(0,-2,-2),
]
# The frame must reach 16 blocks before the conduit activates.
const MIN_FRAME = 16
const MIN_WATER = 26
# Source `conduit_damage`: hostile creatures in water within nine blocks.
const DAMAGE_RADIUS = 9.0
const DAMAGE = 4.0

static func is_conduit(id: int) -> bool: return id == CONDUIT

# The prismarine family, its decorative blocks and the two crafting items.
const OCEAN_IDS = [CONDUIT,PRISMARINE,PRISMARINE_BRICK,PRISMARINE_DARK,SEA_LANTERN,SHARD,CRYSTALS]
static func is_ocean(id: int) -> bool: return OCEAN_IDS.has(id)

static func title(id: int) -> String:
	match id:
		CONDUIT: return "Conduit"
		PRISMARINE: return "Prismarine"
		PRISMARINE_BRICK: return "Prismarine bricks"
		PRISMARINE_DARK: return "Dark prismarine"
		SEA_LANTERN: return "Sea lantern"
		SHARD: return "Prismarine shard"
		CRYSTALS: return "Prismarine crystals"
	return "Prismarine"

static func color(id: int) -> Color:
	match id:
		CONDUIT: return Color("2f6f66")
		PRISMARINE: return Color("63a89c")
		PRISMARINE_BRICK: return Color("4f8f88")
		PRISMARINE_DARK: return Color("1f4f47")
		SEA_LANTERN: return Color("b8e6dc")
		SHARD: return Color("4f8f88")
		CRYSTALS: return Color("7fd8c8")
	return Color("63a89c")

static func is_frame(id: int) -> bool: return id in FRAME_BLOCKS

# `check_conduit`: returns the effect range when the conduit is active, or 0.
#
# The source's water test is exactly:
#   if #water < 26 or (cname ~= "mcl_conduits:conduit" and #water < 27) then
#     return false
# so a cell still holding the conduit NODE needs 26 water cells around it, while
# an activated conduit (whose own cell has become water) needs all 27.
static func power(world: VoxelWorld, p: Vector3i) -> int:
	var water: int = 0
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				if Fluids.water(world.node_at(p+Vector3i(x,y,z))): water += 1
	if water < MIN_WATER: return 0
	if world.node_at(p) != CONDUIT and water < 27: return 0
	var frame: int = 0
	for offset in FRAME_OFFSETS:
		if is_frame(world.node_at(p+offset)): frame += 1
	if frame < MIN_FRAME: return 0
	# Source `math.floor(pn / 7) * 16`.
	return (frame/7)*16

# `mcl_conduits.player_effect`: conduit power only applies while in water.
static func apply_to(game: Node3D, p: Vector3i, reach: int) -> void:
	if reach <= 0: return
	if not Fluids.water(game.world.node_at(Vector3i(game.player.position.floor()))): return
	if game.player.position.distance_to(Vector3(p)+Vector3(0.5,0.5,0.5)) > reach: return
	PotionEffects.apply(game.player,"conduit_power",17.0,1)

# `mcl_conduits.conduit_damage`: hostile creatures in water take magic damage.
static func damage_hostiles(game: Node3D, p: Vector3i) -> void:
	var centre: Vector3 = Vector3(p)+Vector3(0.5,0.5,0.5)
	for mob in game.creatures.get_children():
		if not mob is Creature or mob.is_queued_for_deletion(): continue
		if not mob.hostile: continue
		if mob.center().distance_to(centre) >= DAMAGE_RADIUS: continue
		if not Fluids.water(game.world.node_at(Vector3i(mob.position.floor()))): continue
		mob.hit(DAMAGE,centre)

# The source tracks active conduits as entities and re-checks every five seconds;
# Voxey keeps the same five-second cadence over the registered conduit cells.
static func update(world: VoxelWorld, delta: float) -> void:
	var game: Node3D = world.get_parent()
	if game == null: return
	var tracked: Dictionary = _tracked(world)
	tracked["clock"] = float(tracked.get("clock",0.0))+delta
	if float(tracked["clock"]) < INTERVAL: return
	tracked["clock"] = 0.0
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		if world.node_at(p) != CONDUIT: tracked.erase(p); continue
		var reach: int = power(world,p)
		if reach <= 0: continue
		apply_to(game,p,reach)
		damage_hostiles(game,p)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("conduits"): world.set_meta("conduits",{})
	return world.get_meta("conduits")

# A placed conduit registers itself for the five-second cadence.
static func registered(world: VoxelWorld, p: Vector3i) -> void:
	_tracked(world)[p] = true

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("conduits"): world.set_meta("conduits",{})

# --- art --------------------------------------------------------------------

# A dark prismarine frame around a glowing eye.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == SEA_LANTERN:
		return Color("dff6f0") if (x*3+y*5) % 7 == 0 else Color("b8e6dc")
	if id == PRISMARINE_DARK: return Color("1f4f47").darkened(0.08 if (x+y) % 3 == 0 else 0.0)
	return Color("63a89c").lightened(0.06 if (x/3+y/3) % 2 == 0 else 0.0)

static func draw(img: Image, id: int) -> void:
	if id == CONDUIT:
		ItemArt._polygon(img,[[8,1],[14,6],[14,11],[8,15],[2,11],[2,6]],Color("2f6f66"))
		ItemArt._polygon(img,[[8,4],[11,7],[11,10],[8,12],[5,10],[5,7]],Color("8fe0d0"))
		img.fill_rect(Rect2i(7,7,3,3),Color("e8fff6"))
		return
	if id in [SHARD,CRYSTALS]:
		ItemArt._polygon(img,[[8,2],[13,7],[11,13],[6,13],[3,8]],Color("7fd8c8") if id == CRYSTALS else Color("4f8f88"))
		ItemArt._line(img,Vector2(7,4),Vector2(6,11),Color("c9f6ec") if id == CRYSTALS else Color("86bdb4"))
		return
	VillageItemArt.draw(img,id,Nodes.color(id))

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if id == CONDUIT:
		var tile: int = Nodes.tile(id,0)
		BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(0.5,0.5,0.5),tile,tile)
		return

# --- recipes ----------------------------------------------------------------

# Source: the conduit is eight nautilus shells around a heart of the sea.
static func recipes(inv: Inventory) -> void:
	var shell: int = VillageContent.NAUTILUS_SHELL
	var heart: int = VillageContent.HEART_OF_THE_SEA
	inv._recipe("Conduit",CONDUIT,1,[shell,shell,shell,shell,heart,shell,shell,shell,shell],3,"table")
	# Source prismarine chain: a 2x2 of shards makes prismarine, a 3x3 of shards
	# makes prismarine bricks, and shards around a dye make dark prismarine.
	inv._recipe("Prismarine",PRISMARINE,1,[SHARD,SHARD,SHARD,SHARD],2,"table")
	inv._recipe("Prismarine bricks",PRISMARINE_BRICK,1,[SHARD,SHARD,SHARD,SHARD,SHARD,SHARD,SHARD,SHARD,SHARD],3,"table")
	inv._recipe("Dark prismarine",PRISMARINE_DARK,1,[SHARD,SHARD,SHARD,SHARD,VillageContent.INK_SAC,SHARD,SHARD,SHARD,SHARD],3,"table")
	inv._recipe("Sea lantern",SEA_LANTERN,1,[SHARD,CRYSTALS,SHARD,CRYSTALS,CRYSTALS,CRYSTALS,SHARD,CRYSTALS,SHARD],3,"table")
