class_name Corals
extends RefCounted

# Mineclonia ITEMS/mcl_ocean/corals.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# Five coral species, each in six forms: a living and a dead block, a living and
# a dead plant, and a living and a dead fan. Thirty nodes in total, all generated
# from the source's own species table.
#
# The defining behaviour is **death without water**, and the source uses two ABMs
# with the same 17 second interval and 1-in-5 chance:
#
#   * A **plant or fan** needs a water source directly *above* it. It is
#     `plantlike_rooted`, so the node itself carries the block beneath it.
#   * A **coral block** survives while any of its six neighbours is water.
#
# Death swaps the node to its dead form, which is exactly the node's own drop.
# Breaking a living plant or block drops its dead form unless Silk Touch is used,
# which the source sets on both.
#
# Placement matters too: a plant or fan may only be placed on top of a **matching
# species** coral block, which is the source's `coral_on_place` rule.

const SPECIES = ["tube","brain","bubble","fire","horn"]
# Per species: block, dead block, plant, dead plant, fan, dead fan.
# Six forms per species, matching the source's table order.
const BLOCK = 0
const DEAD_BLOCK = 1
const PLANT = 2
const DEAD_PLANT = 3
const FAN = 4
const DEAD_FAN = 5
const STRIDE = 6

static func index(id: int) -> int:
	var i: int = id-VillageContent.CORAL_FIRST
	return i if i >= 0 and i < 30 else -1

static func is_coral(id: int) -> bool: return index(id) >= 0

# Which species (0-4) and form a node is.
static func species(id: int) -> int: return index(id)/STRIDE if is_coral(id) else -1
static func form(id: int) -> int: return index(id)%STRIDE if is_coral(id) else -1

static func is_block(id: int) -> bool:
	var f: int = form(id)
	return f == BLOCK or f == DEAD_BLOCK
static func is_plant(id: int) -> bool:
	var f: int = form(id)
	return f == PLANT or f == DEAD_PLANT
static func is_fan(id: int) -> bool:
	var f: int = form(id)
	return f == FAN or f == DEAD_FAN
static func dead(id: int) -> bool:
	var f: int = form(id)
	return f == DEAD_BLOCK or f == DEAD_PLANT or f == DEAD_FAN
# A living plant or fan dies if the water above it is gone; a living block dies
# if no neighbour is water.
static func living(id: int) -> bool: return is_coral(id) and not dead(id)

static func living_id(species_index: int, form_index: int) -> int:
	return VillageContent.CORAL_FIRST+species_index*STRIDE+form_index
static func dead_form(id: int) -> int:
	var s: int = species(id)
	if s < 0: return id
	var f: int = form(id)
	if f == BLOCK: return living_id(s,DEAD_BLOCK)
	if f == PLANT: return living_id(s,DEAD_PLANT)
	if f == FAN: return living_id(s,DEAD_FAN)
	return id

static func title(id: int) -> String:
	var s: int = species(id)
	if s < 0: return "Coral"
	var name: String = SPECIES[s].capitalize()
	if is_block(id): return ("Dead " if dead(id) else "")+name+" Coral Block"
	return ("Dead " if dead(id) else "")+name+(" Coral Fan" if is_fan(id) else " Coral")

# --- survival ----------------------------------------------------------------

# The two death rules, checked together so a caller can ask "should this die?".
static func survives(world: VoxelWorld, p: Vector3i, id: int) -> bool:
	if not living(id): return true
	if is_block(id):
		for side in [Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.DOWN]:
			if Fluids.water(world.node_at(p+side)): return true
		return false
	# A rooted plant or fan carries its block, and needs water above it.
	return Fluids.water(world.node_at(p+Vector3i.UP))

# `coral_on_place`: a plant or fan only goes on a matching species' coral block.
static func placeable_on(world: VoxelWorld, at: Vector3i, held: int) -> bool:
	if not is_coral(held): return false
	if is_block(held): return true
	var below: int = world.node_at(at-Vector3i.UP)
	return is_block(below) and species(below) == species(held)

# `coral_on_place`: a plant or fan may only go on top of a matching species'
# coral block, while a block places like any building block.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if not is_coral(held) or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current) and not Fluids.liquid(current) and not is_coral(current): return true
	if not placeable_on(world,at,held):
		# Refuse rather than dropping the item, as the source's handler does.
		if not is_block(held):
			game.toast("Coral must be placed on the matching coral block.")
			return true
	if not world.set_node(at,held): return true
	registered(world,at,held)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,held)
	return true

# Death is applied on the source's 17 second interval with a 1-in-5 chance.
const DEATH_INTERVAL = 17.0
const DEATH_CHANCE = 5

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("corals"): return
	var tracked: Dictionary = world.get_meta("corals")
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < DEATH_INTERVAL:
		tracked["clock"] = clock
		world.set_meta("corals",tracked)
		return
	tracked["clock"] = 0.0
	# A fresh roll each interval, as the source's ABM chance does.
	var rng: RandomNumberGenerator = _rng(world)
	for key in tracked.keys():
		# The clock key is a String beside Vector3i cell keys, so compare by type
		# rather than by value, which would raise on a Vector3i.
		if not key is Vector3i: continue
		var p: Vector3i = key
		var id: int = world.node_at(p)
		if not is_coral(id): tracked.erase(p); continue
		# Only living coral dies, and only some of the time.
		if not living(id): continue
		if survives(world,p,id): continue
		if rng.randi_range(1,DEATH_CHANCE) != 1: continue
		world.set_node(p,dead_form(id))
	world.set_meta("corals",tracked)

# Godot's `get_meta` returns a copy for dictionary values in this engine version,
# so every mutation must be written back or it is silently lost.
static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("corals"): world.set_meta("corals",{})
	return world.get_meta("corals")

static func _store(world: VoxelWorld, tracked: Dictionary) -> void:
	world.set_meta("corals",tracked)

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_coral(id): return
	var tracked: Dictionary = _tracked(world)
	tracked[p] = true
	_store(world,tracked)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _tracked(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	_store(world,tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("corals"): world.set_meta("corals",{})

# One RNG per world, seeded from the world so coral death is reproducible.
static func _rng(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("coral_rng"):
		var rng := RandomNumberGenerator.new()
		rng.seed = world.seed_value+20147 if "seed_value" in world else 20147
		world.set_meta("coral_rng",rng)
	return world.get_meta("coral_rng")

# --- art --------------------------------------------------------------------

# Each species has its own palette, and dead coral is a bleached grey.
const PALETTES = ["5c7fb8","c86bb0","9d5ad0","d4674f","c9a24f"]
const DEAD_COLOR = "9a9288"

static func color(id: int) -> Color:
	var s: int = species(id)
	if s < 0: return Color(DEAD_COLOR)
	return Color(DEAD_COLOR) if dead(id) else Color(PALETTES[s])

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = color(id)
	if is_block(id): return base.darkened(0.08 if (x/2+y/3)%2 == 0 else 0.0)
	if is_fan(id):
		if absf(x-7.5) > 5-y*0.0: return Color(base.r,base.g,base.b,0.0)
		return base.lightened(0.1) if (x+y)%3 == 0 else base
	# A rooted plant: a stalk with fronds.
	if x in [6,7,8,9] or absf(x-7.5) < 3: return base
	return Color(base.r,base.g,base.b,0.0)

static func draw(img: Image, id: int) -> void:
	var base: Color = color(id)
	if is_block(id):
		img.fill_rect(Rect2i(3,3,10,10),base)
		return
	if is_fan(id):
		ItemArt._polygon(img,[[8,2],[11,4],[13,7],[11,11],[8,12],[5,11],[3,7],[5,4]],base)
		ItemArt._line(img,Vector2(8,12),Vector2(8,14),base.darkened(0.3))
		return
	ItemArt._line(img,Vector2(8,14),Vector2(8,6),base.darkened(0.2),2)
	ItemArt._line(img,Vector2(8,8),Vector2(4,4),base,2)
	ItemArt._line(img,Vector2(8,8),Vector2(12,4),base,2)

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	if is_block(id):
		BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(1,1,1),tile,tile)
		return
	# The rooted plant and fan stand on the block, one cell tall.
	BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(1,1,1),tile,tile)
	BlockMesher._art_box(out,p+Vector3(0.5,1.25,0.5),Vector3(0.7,0.5,0.7) if is_fan(id) else Vector3(0.35,0.5,0.35),tile,tile)

# --- recipes ----------------------------------------------------------------

# The source has no coral crafting: coral is gathered from the ocean. Voxey has
# no ocean biome generation for it yet, so the nine dye colours are used to reach
# each species' block, which is recorded in the source notes.
static func recipes(inv: Inventory) -> void:
	var dye: Array = [VillageContent.DYE_BLUE,VillageContent.DYE_MAGENTA,VillageContent.DYE_PURPLE,VillageContent.DYE_RED,VillageContent.DYE_YELLOW]
	for s in SPECIES.size():
		var block: int = living_id(s,0)
		inv._recipe(title(block),block,1,[VillageContent.DYE_WHITE,VillageContent.DYE_WHITE,dye[s],VillageContent.DYE_WHITE,VillageContent.DYE_WHITE],2,"table")
