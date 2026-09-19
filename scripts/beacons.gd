class_name Beacons
extends RefCounted

# Mineclonia ITEMS/mcl_beacons/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# A beacon is a pyramid-powered effect emitter. The source's rules:
#
#   * **Pyramid.** `check_pyramid` walks four square layers beneath the beacon,
#     each `y_offset` square of radius `y_offset`. The first layer with a
#     non-beacon block stops the count, and reaching all four means power 4.
#     Every block must be in the `beacon_block` group — iron, gold, diamond and
#     emerald blocks in the reference, plus netherite.
#   * **Effects.** Six effects are offered, each requiring a minimum power:
#     swiftness and haste at 1, resistance and leaping at 2, strength at 3 and
#     regeneration at 4. Power 4 also allows a second effect, which the source
#     fixes to regeneration.
#   * **Range.** `(power_level + 1) * 10` blocks, and the effect is granted at
#     level 16 which decays normally.
#   * **Beam.** A vertical beam rises from the beacon through transparent blocks
#     and takes the colour of the stained glass directly above it.
#
# Beacons need a nether star, which the Wither drops. Voxey has no Wither, so the
# recipe is registered from the source's own shape and the acquisition gap is
# recorded rather than papered over.

const ID = VillageContent.BEACON
const BEAM = VillageContent.BEACON_BEAM
const POWER_MAX = 4
# `effect_level`: the power each effect needs.
const EFFECTS = [["swiftness",1],["haste",1],["resistance",2],["leaping",2],["strength",3],["regeneration",4]]
const EFFECT_NAMES = ["Swiftness","Haste","Resistance","Leaping","Strength","Regeneration"]
# The source always pairs a power-four beacon's second effect with regeneration.
const SECONDARY = "regeneration"
# `effect_player`: range is `(power + 1) * 10`, granted for 16 seconds.
const RANGE_PER_LEVEL = 10
const DURATION = 16.0

static func is_beacon(id: int) -> bool: return id == ID
static func is_beam(id: int) -> bool: return id == BEAM

# The blocks a pyramid accepts, which the source marks with `beacon_block`.
static func pyramid_block(id: int) -> bool:
	return id in [Nodes.IRON_BLOCK,Nodes.GOLD_BLOCK,Nodes.DIAMOND_BLOCK,VillageContent.EMERALD_BLOCK,
		VillageContent.NETHERITE_BLOCK]

# `check_pyramid`: four square layers of increasing radius beneath the beacon. The
# first layer that is not entirely beacon blocks caps the power, and completing
# all four gives the maximum.
static func power(world: VoxelWorld, p: Vector3i) -> int:
	for offset in range(1,POWER_MAX+1):
		for x in range(p.x-offset,p.x+offset+1):
			for z in range(p.z-offset,p.z+offset+1):
				if not pyramid_block(world.node_at(Vector3i(x,p.y-offset,z))): return offset-1
	return POWER_MAX

# The range a beacon at this power reaches, which is the source's own formula.
static func effect_range(power_level: int) -> float:
	return float((power_level+1)*RANGE_PER_LEVEL)

# The effects a beacon at this power may offer.
static func available(power_level: int) -> Array:
	var result: Array = []
	for entry in EFFECTS:
		if power_level >= int(entry[1]): result.append(str(entry[0]))
	return result

# --- the beam ----------------------------------------------------------------

# The source's `get_beacon_beam`: a beam stops at the first block that is neither
# transparent nor glass, and stained glass tints it.
static func beam_length(world: VoxelWorld, p: Vector3i) -> int:
	var height: int = 0
	# The source scans a fixed distance upward; the world's ceiling does not
	# bound a beacon that sits above it in the air.
	for y in range(p.y+1,p.y+1+255):
		var at: Vector3i = Vector3i(p.x,y,p.z)
		var id: int = world.node_at(at)
		# The beam passes through the beacon's own beam cells and any air.
		if id == Nodes.AIR or id == BEAM: height = y-p.y; continue
		break
	return height

# The colour the beam takes from the glass directly above the beacon, or white.
static func beam_color(world: VoxelWorld, p: Vector3i) -> Color:
	var id: int = world.node_at(p+Vector3i.UP)
	return Nodes.color(id) if VillageContent.DATA.get(id,{}).get("family","") == "glass" else Color("ffffff")

# --- simulation --------------------------------------------------------------

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("beacons"): return
	var tracked: Dictionary = world.get_meta("beacons")
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < 1.0:
		tracked["clock"] = clock
		world.set_meta("beacons",tracked)
		return
	tracked["clock"] = 0.0
	var game: Node3D = world.get_parent()
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		if world.node_at(p) != ID: tracked.erase(p); continue
		var power_level: int = power(world,p)
		if power_level <= 0: continue
		var state: Dictionary = station(world,p)
		var primary: String = str(state.get("effect",""))
		if primary.is_empty(): primary = "swiftness"
		# A completed pyramid gains the source's second effect automatically.
		if power_level >= POWER_MAX and str(state.get("secondary","")).is_empty():
			state["secondary"] = SECONDARY
		var reach: float = effect_range(power_level)
		if game.player.position.distance_to(Vector3(p)+Vector3.ONE*0.5) <= reach:
			PotionEffects.apply(game.player,primary,DURATION,1)
			# A power-four beacon grants its chosen second effect as well.
			if power_level >= POWER_MAX and str(state.get("secondary","")) == SECONDARY:
				PotionEffects.apply(game.player,SECONDARY,DURATION,1)
	world.set_meta("beacons",tracked)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("beacons"): world.set_meta("beacons",{})
	return world.get_meta("beacons")

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {"kind":"beacon","effect":"","secondary":""}
	return world.stations[key]

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_beacon(id): return
	var tracked: Dictionary = _tracked(world)
	tracked[p] = true
	world.set_meta("beacons",tracked)
	station(world,p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("beacons"): world.set_meta("beacons",{})

# --- interaction -------------------------------------------------------------

# Selecting an effect is the source's formspec action; Voxey cycles the available
# effects instead, which reaches the same stored state.
static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or game.world.node_at(target.pos) != ID: return false
	var world: VoxelWorld = game.world
	var power_level: int = power(world,target.pos)
	if power_level <= 0:
		game.toast("A beacon needs a pyramid of mineral blocks beneath it.")
		return true
	var choices: Array = available(power_level)
	var state: Dictionary = station(world,target.pos)
	var index: int = choices.find(str(state.get("effect","")))
	state["effect"] = str(choices[(index+1)%choices.size()])
	if power_level >= POWER_MAX: state["secondary"] = SECONDARY
	game.toast("Beacon: %s at range %d." % [str(state.effect).capitalize(),int(effect_range(power_level))])
	# `bring_home_the_beacon` on activation, and `beaconator` once a maximum-power
	# pyramid has granted the second effect.
	game.achievements.award("bring_home_the_beacon")
	if power_level >= POWER_MAX: game.achievements.award("beaconator")
	game.player.swing = 1
	return true

# --- art --------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if is_beam(id): return Color("ffffffcc") if x in range(6,10) else Color(1,1,1,0)
	if x < 3 or x > 12 or y < 3 or y > 13: return Color(1,1,1,0)
	return Color("6fd8d8") if (x in [7,8] or y in [7,8]) else Color("2b6f78")

static func draw(img: Image, id: int) -> void:
	ItemArt._polygon(img,[[5,13],[11,13],[14,9],[14,4],[11,2],[5,2],[2,4],[2,9]],Color("2b6f78"))
	ItemArt._polygon(img,[[6,11],[10,11],[12,8],[12,5],[10,3],[6,3],[4,5],[4,8]],Color("6fd8d8"))
	img.fill_rect(Rect2i(7,6,2,4),Color("e8ffff"))

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	if is_beam(id):
		BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(0.25,1,0.25),tile,tile)
		return
	BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(0.75,1,0.75),tile,tile)
	BlockMesher._art_box(out,p+Vector3(0.5,1.1,0.5),Vector3(0.3,0.25,0.3),tile,tile)

static func recipes(inv: Inventory) -> void:
	# The source's own shape: a nether star over three obsidian and a glass base.
	inv._recipe("Beacon",ID,1,[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,VillageContent.NETHER_STAR,Nodes.GLASS,Nodes.OBSIDIAN,Nodes.OBSIDIAN,Nodes.OBSIDIAN],3,"table")
