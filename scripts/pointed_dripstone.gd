class_name PointedDripstone
extends RefCounted

# Mineclonia ITEMS/mcl_dripstone/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; all art is original procedural code.
#
# Pointed dripstone is the stalactite/stalagmite family that grows in caves. The
# source registers **ten** nodes: five stages in two orientations. The orientation
# is encoded in the name (`dripstone_top_*` / `dripstone_bottom_*`), and the stage
# runs `tip_merge, tip, frustum, middle, base` (1..5). This module keeps one id per
# (stage, orientation) rather than deriving them, because the ids are stable
# content and the geometry differs by stage.
#
# Source facts reproduced here:
#
#   * **Boxes.** Both orientations are a full-height square column of half-width
#     `w = 3/16 + (stage-1)/16`, clamped to `0.5` (`init.lua:222-234`); the
#     `top`/`bottom` split is only a texture flip. So placement and collision are
#     identical for the two families, and both are selection **and** collision boxes.
#   * **Groups.** Every stage is `pickaxey`, `not_in_creative_inventory`,
#     `dripstone_stage = i`, `pathfinder_partial = 2` and `dig_by_trident = 1`, and
#     every stage drops `pointed_dripstone`. The *bottom* nodes additionally carry
#     `fall_damage_add_percent = 100`, so landing on a stalactite doubles the fall
#     damage. Hardness 1.5, blast resistance 3.
#   * **Item placement** (`on_dripstone_place`): the clicked node must be solid or
#     another dripstone stage, the placement must be on the clicked face's axis
#     (`above.x == under.x and above.z == under.z`), the direction is
#     `under.y - above.y`, and the new cell is `tip` (stage 2) followed by
#     `update_dripstone` — which is what merges and extends the column.
#   * **`update_dripstone`** (`init.lua:125-160`): if the cell on the far side of
#     `direction` is another dripstone stage the two become `tip_merge`; then the
#     column is walked in `direction`, bumping every stage by one until a `middle`
#     or `base` is met or the air runs out — in which case the last `frustum`
#     becomes a `base`.
#   * **`place_dripstone`** (`init.lua:81-110`): the anchor is the `base` (stage 5),
#     the far cell is the `tip` (stage 1), a meeting column becomes two
#     `tip_merge`s, and the cell before the tip is the `frustum` (stage 3).
#   * **Growth ABM** (`init.lua:328-378`): a `top_tip` whose column reaches a
#     `dripstone_block` with water above it grows either a stalagmite (upward, cap
#     seven) or a stalactite (downward, cap seven) on a `random(2)` roll.
#   * **The drip ABM** (`init.lua:381-457`): a `top_tip` under a water source fills
#     a cauldron below it one level, and a `top_tip` under lava fills a lava
#     cauldron three levels; the same roll converts `mcl_mud:mud` to
#     `mcl_core:clay` outside the Nether.
#
# Not ported: the `vengeful_dripstone` falling entity (`init.lua:24-49`), which the
# source spawns when a stalagmite's support is dug out, so a falling stalactite does
# not yet strike a player on the way down. The in-place spike damage
# (`fall_damage_add_percent`) is implemented.

# Stable ids. `dripstone_block` is 540 (`VillageContent.DRIPSTONE_BLOCK`); the
# literal is written here to keep this module free of a `VillageContent`
# reference, so `VillageContent.DATA` may reference `Dripstone.BLOCK_DATA` without
# closing a load cycle.
const BLOCK := 540
const TOP_FIRST = 1262
const BOTTOM_FIRST = 1267
const ITEM = 1274

# The source's stage names, index 1..5.
const STAGES = ["tip_merge","tip","frustum","middle","base"]
const STAGE_COUNT = 5

# The source's own box half-width per stage: `3/16 + (stage-1)/16`, clamped to 0.5.
static func half_width(stage: int) -> float:
	return minf(0.5,3.0/16.0+float(stage-1)/16.0)

static func is_top(id: int) -> bool: return id >= TOP_FIRST and id < TOP_FIRST+STAGE_COUNT
static func is_bottom(id: int) -> bool: return id >= BOTTOM_FIRST and id < BOTTOM_FIRST+STAGE_COUNT
static func is_stage(id: int) -> bool: return is_top(id) or is_bottom(id)
static func stage(id: int) -> int:
	if is_top(id): return id-TOP_FIRST+1
	if is_bottom(id): return id-BOTTOM_FIRST+1
	return 0
# +1 for the "top" family, -1 for the "bottom" family, matching `extract_direction`.
static func direction(id: int) -> int: return 1 if is_top(id) else (-1 if is_bottom(id) else 0)
static func node_for(stage_number: int, dir: int) -> int:
	var clamped: int = clampi(stage_number,1,STAGE_COUNT)
	return TOP_FIRST+clamped-1 if dir == 1 else BOTTOM_FIRST+clamped-1
static func item(_id: int) -> int: return ITEM
static func title(_id: int) -> String: return "Pointed dripstone"
static func color(id: int) -> Color: return Color("7a6a5c").lightened(0.05*float(stage(id)))

# The source's box is a full-height square column whose half-width grows with the
# stage: `{ max(-0.5,-3/16-(i-1)/16), -0.5, ..., +3/16+(i-1)/16, 0.5, ... }`. Both
# orientations share the geometry — the `top`/`bottom` split is a texture flip — so
# placement and collision are identical for the two families.
static func boxes(id: int) -> Array:
	if not is_stage(id): return []
	var w: float = half_width(stage(id))
	return [AABB(Vector3(0.5-w,0.0,0.5-w),Vector3(w*2,1.0,w*2))]

# `fall_damage_add_percent = 100` on the bottom nodes: the source adds a hundred
# percent, doubling the fall damage.
static func fall_multiplier(id: int) -> float: return 2.0 if is_bottom(id) else 1.0

# A dripstone anchor is a `dripstone_block`, which the growth rules require above or
# below a column.
static func is_anchor(id: int) -> bool: return id == BLOCK

# `VillageContent.DATA` merges this: five stages in two orientations plus the item.
# Stages are hidden from the creative inventory, as `not_in_creative_inventory`
# requires; only the item is placeable.
const BLOCK_DATA := {
	1262: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1263: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1264: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1265: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1266: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1267: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1268: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1269: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1270: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1271: {"name":"Pointed dripstone","block":true,"shape":"dripstone","color":"7a6a5c","hardness":1.5,"blast_resistance":3.0,"tool":0,"hidden":true},
	1274: {"name":"Pointed dripstone","color":"8a7767","stack":64},
}

# --- column maths ------------------------------------------------------------

# `get_dripstone_length`: how many dripstone stages run from `pos` in `dir`.
static func length_from(world: VoxelWorld, pos: Vector3i, dir: int) -> int:
	var count: int = 0
	var at: Vector3i = pos
	for i in 32:
		at += Vector3i(0,dir,0)
		if not is_stage(world.node_at(at)): break
		count += 1
	return count

# --- placement ---------------------------------------------------------------

# `on_dripstone_place`: place a `tip` on the clicked face's axis and let
# `update_column` extend it. Returns true when the click was consumed.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != ITEM or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var under: int = target.id
	if not Nodes.solid(under) and not is_stage(under): return true
	var normal: Vector3i = target.get("normal",Vector3i.UP)
	if normal.y == 0: return true
	var at: Vector3i = target.get("replace",target.pos+normal)
	var above: int = world.node_at(at)
	if above != Nodes.AIR and not Nodes.plant(above): return true
	var dir: int = -normal.y
	if not world.set_node(at,node_for(2,dir)): return true
	update_column(world,at,dir)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,world.node_at(at))
	return true

# `place_dripstone`: build a column with the **base** (5) at the anchor `pos` and
# the tip at `pos + (length-1)*(-dir)`. `dir` is the source's own `direction`, which
# points from the tip back toward the base (a stalagmite is `-1` because its tip is
# above its base). A column that meets a facing column merges the pair into two
# `tip_merge`s.
static func place_column(world: VoxelWorld, pos: Vector3i, length: int, dir: int) -> void:
	if length <= 0: return
	var grow: int = -dir
	if length >= 3: world.set_node(pos,node_for(5,dir))
	if length >= 4:
		for i in range(length-3):
			world.set_node(pos+Vector3i(0,(i+1)*grow,0),node_for(4,dir))
	if length >= 2: world.set_node(pos+Vector3i(0,(length-2)*grow,0),node_for(3,dir))
	var beyond: int = world.node_at(pos+Vector3i(0,length*grow,0))
	if is_stage(beyond) and direction(beyond) == -dir:
		world.set_node(pos+Vector3i(0,(length-1)*grow,0),node_for(1,dir))
		world.set_node(pos+Vector3i(0,length*grow,0),node_for(1,-dir))
	else:
		world.set_node(pos+Vector3i(0,(length-1)*grow,0),node_for(2,dir))

# `update_dripstone`: merge with the cell behind, then extend the column forward,
# bumping each stage until a `middle`/`base` is met or the air runs out — in which
# case the last `frustum` becomes a `base`.
static func update_column(world: VoxelWorld, pos: Vector3i, dir: int) -> void:
	var behind: int = world.node_at(pos-Vector3i(0,dir,0))
	if is_stage(behind) and direction(behind) == -dir:
		world.set_node(pos,node_for(1,dir))
		world.set_node(pos-Vector3i(0,dir,0),node_for(1,-dir))
		return
	var previous_stage: int = 0
	var at: Vector3i = pos
	for i in 32:
		at += Vector3i(0,dir,0)
		var here: int = stage(world.node_at(at))
		if here == 4 or here == 5: break
		if here == 0:
			if previous_stage == 3: world.set_node(at-Vector3i(0,dir,0),node_for(5,dir))
			break
		previous_stage = here
		world.set_node(at,node_for(here+1,dir))

# --- growth and dripping -----------------------------------------------------

# The growth ABM (`init.lua:328-378`): a `top_tip` anchored on a water-topped
# `dripstone_block` grows a stalagmite or a stalactite, both capped at seven.
static func grow(world: VoxelWorld, pos: Vector3i, rng: RandomNumberGenerator) -> bool:
	if world.node_at(pos) != node_for(2,1): return false
	var column: int = length_from(world,pos,1)
	var ceiling: Vector3i = pos+Vector3i(0,column+1,0)
	if world.node_at(ceiling) != BLOCK or not Fluids.water(world.node_at(ceiling+Vector3i.UP)): return false
	if rng.randi_range(1,2) == 1:
		# Grow a stalagmite upward to the first solid or dripstone cell.
		for i in range(1,11):
			var at: Vector3i = pos-Vector3i(0,i,0)
			var id: int = world.node_at(at)
			if Nodes.solid(id) or is_stage(id):
				if column < 7:
					var target: Vector3i = pos-Vector3i(0,i-1,0)
					if world.set_node(target,node_for(2,-1)): update_column(world,target,-1)
				return true
			if id != Nodes.AIR: return false
		return false
	# Grow a stalactite downward.
	if column > 7: return false
	var below: Vector3i = pos-Vector3i(0,1,0)
	if world.node_at(below) == Nodes.AIR:
		if world.set_node(below,node_for(2,1)): update_column(world,below,1)
	return true

# The drip ABM (`init.lua:381-457`): a `top_tip` under water fills a cauldron below
# it one level, or converts a `mcl_mud:mud` block to clay outside the Nether; under
# lava it fills a lava cauldron three levels.
static func drip(game: Node3D, pos: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.node_at(pos) != node_for(2,1): return false
	var column: int = length_from(world,pos,1)
	var supply: Vector3i = pos+Vector3i(0,column+1,0)
	var supply_id: int = world.node_at(supply)
	if Fluids.water(supply_id) and column <= 10:
		# The water roll also converts mud to clay, as the source reuses the ABM.
		var mud: Vector3i = pos-Vector3i(0,column+2,0)
		if world.node_at(mud) == VillageContent.MUD and game.dimension != "nether":
			return world.set_node(mud,Nodes.CLAY)
		for i in range(1,11):
			var at: Vector3i = pos-Vector3i(0,i,0)
			var id: int = world.node_at(at)
			if id == VillageContent.CAULDRON: return fill_cauldron(world,at,1,"water")
			if id != Nodes.AIR: break
	if Fluids.lava(supply_id) and column <= 10:
		for i in range(1,11):
			var at: Vector3i = pos-Vector3i(0,i,0)
			var id: int = world.node_at(at)
			if id == VillageContent.CAULDRON: return fill_cauldron(world,at,3,"lava")
			if id != Nodes.AIR: break
	return false

# A cauldron fill that reuses the existing station machinery, so a drip and a
# poured bucket write the same state.
static func fill_cauldron(world: VoxelWorld, p: Vector3i, amount: int, material: String) -> bool:
	var station: Dictionary = Cauldrons.station(world,p)
	if Cauldrons.level(station) >= 3 or (Cauldrons.level(station) > 0 and Cauldrons.liquid(station) != material): return false
	Cauldrons.set_contents(station,mini(3,Cauldrons.level(station)+amount),material)
	world.note_station(VoxelWorld.station_key(p),station)
	world.get_parent().survival.refresh_displays()
	return true

# --- art ---------------------------------------------------------------------

# The shape narrows toward the point: a `top` stage is wide at its base (the cell
# floor) and tapers upward, a `bottom` stage is wide at the ceiling and tapers
# downward. The pixel art mirrors that with a lit rim and darker core.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_stage(id): return noise
	var s: int = stage(id)
	var base := Color("8a7767")
	var top: bool = is_top(id)
	# Distance from the centre line, scaled by the stage's own width.
	var half: float = half_width(s)*16.0
	if absf(x-7.5) > half: return Color(0,0,0,0)
	# The point end: `top` tapers up (small y), `bottom` tapers down (large y).
	var taper: float = (float(y)/15.0) if top else (1.0-float(y)/15.0)
	if absf(x-7.5) > half*maxf(0.25,taper): return Color(0,0,0,0)
	if x in [int(7.5-half),int(7.5+half)] or y in [0,15]: return base.lightened(0.18)
	if absf(x-7.5) < 1.5: return base.lightened(0.1)
	return noise.darkened(0.06)

static func draw(img: Image, id: int) -> void:
	var base := Color("8a7767")
	for y in 16:
		var half: int = int(half_width(stage(id))*16.0*(float(y)/15.0 if is_top(id) else 1.0-float(y)/15.0))
		for x in range(8-maxi(1,half),8+maxi(1,half)):
			img.set_pixel(clampi(x,0,15),y,base if absf(x-7.5) > 1 else base.lightened(0.12))

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	var w: float = half_width(stage(id))
	# The source's full-height square column of half-width `w`, matching the box.
	BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(w*2,1.0,w*2),tile,tile)

# --- ticking -----------------------------------------------------------------

# `VoxelWorld` walks loaded dripstone on the source's cadence: growth is
# `interval 69, chance 88`, the water drip `chance 5.5` and the lava drip
# `chance 17`, all keyed off the same `top_tip` nodes.
const INTERVAL := 69.0
const GROWTH_CHANCE := 88.0
const WATER_CHANCE := 5.5
const LAVA_CHANCE := 17.0

# Register or retire a `top_tip` timer when the world's nodes change. This is the
# equivalent of the source's ABM `nodenames` list.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, new_id: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	var timers: Dictionary = world.adventure_state.get("dripstone",{})
	var was: bool = old_id == node_for(2,1)
	var now: bool = new_id == node_for(2,1)
	if now and not was: timers[key] = 0.0
	elif was and not now: timers.erase(key)
	world.adventure_state["dripstone"] = timers

static func simulate(world: VoxelWorld, delta: float) -> void:
	var timers: Dictionary = world.adventure_state.get("dripstone",{})
	if timers.is_empty(): return
	var game: Node3D = world.get_parent()
	var rng := RandomNumberGenerator.new()
	for key in timers.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 3: timers.erase(key); continue
		var p := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		if not world.loaded_at(Vector3(p)) or world.node_at(p) != node_for(2,1):
			timers.erase(key); continue
		var clock: float = float(timers[key])+delta
		if clock < INTERVAL: timers[key] = clock; continue
		timers[key] = 0.0
		rng.seed = world.seed_value+p.x*31+p.y*17+p.z*13+int(Time.get_ticks_msec()/1000)
		if rng.randf()*100.0 < GROWTH_CHANCE: grow(world,p,rng)
		var roll: float = rng.randf()*100.0
		if roll < WATER_CHANCE: drip(game,p)
		elif roll < WATER_CHANCE+LAVA_CHANCE: drip(game,p)
	world.adventure_state["dripstone"] = timers


# --- breaking ----------------------------------------------------------------

# `break_dripstone` (`init.lua:110-124`): removing one stage walks the column and
# returns every cell to an item, re-forming a `frustum` at the tip of the other
# half. Returns the number of cells removed.
static func break_column(world: VoxelWorld, p: Vector3i, id: int, dir: int) -> int:
	var removed: int = 0
	var at: Vector3i = p
	for i in 32:
		at -= Vector3i(0,dir,0)
		var here: int = world.node_at(at)
		var s: int = stage(here)
		if s == 1 and direction(here) == -dir:
			world.set_node(at,node_for(2,-dir)); break
		elif s == 0: break
		else:
			world.set_node(at,Nodes.AIR); removed += 1
	return removed

# The node's own removal: every stage drops the same `pointed_dripstone` item, and
# the rest of the column is taken with it, which the source's `on_destruct` performs.
static func break_node(game: Node3D, p: Vector3i, id: int, tool: int) -> bool:
	if not is_stage(id): return false
	var _tool: int = tool
	var world: VoxelWorld = game.world
	var dir: int = direction(id)
	world.set_node(p,Nodes.AIR)
	# `break_dripstone`: walk the column toward the base and remove each stage,
	# re-forming a `frustum` at the tip of the remaining half. The source adds one
	# item per removed node.
	var removed: int = break_column(world,p,id,dir)
	if game.gamemode != "creative":
		for i in removed+1: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,ITEM,1)
	return true
