class_name PowderSnow
extends RefCounted

# Mineclonia ITEMS/mcl_powder_snow/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; art is original procedural code.
#
# Powder snow is the trap block of a snowy biome: it **looks like snow and is not
# solid**. Walk into it and you sink in and start to freeze. The source's rule is
# precise, and every part of it matters:
#
#   * The player accumulates `time_in_snow` at **0.5 per slow tick**, capped at 7.
#   * Past **5** the freeze starts doing damage — half a heart per tick — and the
#     screen shows the third and deepest frost stage.
#   * The frost has **three visual stages** at 1, 3 and 5.
#   * Leaving the snow **drains** the meter at the same rate, so brief contact is
#     harmless and the frost recedes.
#   * **Leather armour prevents it entirely**, which is why leather boots are worth
#     making in a snowy world.
#   * A **bucket** scoops it up, and the bucket can pour it back.
#
# The trap matters because the block is deliberately indistinguishable from snow,
# so a player crossing a snowfield can drop into one without warning.

# A non-solid, non-walkable block: the source's `walkable = false`.
const ID = 1175
# The bucket of powder snow, which is how the block is carried.
const BUCKET = 1176
const BLOCKS = [ID]

# Source `time_in_snow = math.min(time_in_snow + 0.5, 7)`.
const STEP = 0.5
const MAX_TIME = 7.0
# Source `if time_in_snow > 5 then` — the freeze begins past this.
const DAMAGE_THRESHOLD = 5.0
# Source `mcl_damage.damage_player(player, 0.5, {type = "freeze"})`.
const FREEZE_DAMAGE = 0.5
# Source shows stages at 1, 3 and 5.
const STAGE_LEVELS = [1.0,3.0,5.0]
# Source `damage * 5.0` for fire-type mobs.
const FIRE_MOB_MULTIPLIER = 5.0
# The mobs the source lists as taking extra freeze damage.
const FIRE_MOBS = ["strider","blaze","magma_cube"]

static func is_powder_snow(id: int) -> bool: return id == ID
static func is_bucket(id: int) -> bool: return id == BUCKET

# --- the freeze meter --------------------------------------------------------

# The meter's value for a player, which the source keeps in the player's metadata
# so it survives a reload.
static func time_in_snow(player: VoxeyPlayer) -> float:
	return float(player.get_meta("time_in_snow",0.0))

static func set_time_in_snow(player: VoxeyPlayer, value: float) -> void:
	player.set_meta("time_in_snow",clampf(value,0.0,MAX_TIME))

# Which frost stage a meter value shows, or 0 for none. The stages deepen at 1, 3
# and 5, so the screen frosts over gradually rather than all at once.
static func stage(value: float) -> int:
	var result: int = 0
	for i in STAGE_LEVELS.size():
		if value >= float(STAGE_LEVELS[i]): result = i+1
	return result

# Whether the player is wearing leather armour, which the source checks across the
# whole set: any leather piece prevents the freeze entirely.
static func insulated(player: VoxeyPlayer) -> bool:
	for slot in player.armor_slots:
		if Nodes.armor_material(int(slot.id)) == 0 and Nodes.is_armor(int(slot.id)): return true
	return false

# Whether the player's feet are in powder snow, which is the source's check on the
# node at the player's own position.
static func submerged(world: VoxelWorld, player: VoxeyPlayer) -> bool:
	return is_powder_snow(world.node_at(Vector3i(player.position.floor())))

# --- the freeze tick ---------------------------------------------------------

# Advance the freeze meter for a player, which is the source's slow globalstep.
# Returns the damage the player should take, so the caller applies it where damage
# is handled.
static func step(world: VoxelWorld, player: VoxeyPlayer) -> float:
	var inside: bool = submerged(world,player) and not insulated(player)
	var value: float = time_in_snow(player)
	if inside:
		# Source accumulates by a fixed step per slow tick and caps the meter, so a
		# player cannot freeze faster by entering twice.
		value = minf(value+STEP,MAX_TIME)
		set_time_in_snow(player,value)
		# Past the threshold the freeze does damage, half a heart at a time.
		if value > DAMAGE_THRESHOLD: return FREEZE_DAMAGE
		return 0.0
	if value <= 0.0: return 0.0
	# Leaving the snow drains the meter at the same rate, so the frost recedes.
	value -= STEP
	if value <= 0.0:
		set_time_in_snow(player,0.0)
		player.set_meta("frost_stage",0)
		return 0.0
	set_time_in_snow(player,value)
	return 0.0

# --- mobs --------------------------------------------------------------------

# The freeze damage a creature takes, which the source multiplies for the fire
# mobs it lists.
static func mob_damage(kind: String, base: float) -> float:
	return base*FIRE_MOB_MULTIPLIER if FIRE_MOBS.has(kind) else base

# --- buckets -----------------------------------------------------------------

# Scoop powder snow into an empty bucket, which is the source's click behaviour.
# Returns true when the scoop happened.
static func scoop(game: Node3D, p: Vector3i) -> bool:
	if not is_powder_snow(game.world.node_at(p)): return false
	var held: int = game.inventory.held().id
	if held != Nodes.BUCKET: return false
	if not game.world.set_node(p,Nodes.AIR): return false
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		if game.inventory.add_item(BUCKET,1) > 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,BUCKET,1)
	return true

# Pour a powder snow bucket back out, which places the block again.
static func pour(game: Node3D, at: Vector3i) -> bool:
	if game.world.node_at(at) != Nodes.AIR: return false
	if not game.world.set_node(at,ID): return false
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		if game.inventory.add_item(Nodes.BUCKET,1) > 0: game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,Nodes.BUCKET,1)
	return true

# --- art ---------------------------------------------------------------------

# Powder snow looks like a snow block, which is the point: the trap must not be
# distinguishable by looking at it.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == BUCKET:
		# A bucket filled with powder snow: the source's own item.
		return Color("b9c4cc") if y > 10 else (Color("c9ced6") if y > 6 else Color("8a9099"))
	if not is_powder_snow(id): return Color(0,0,0,0)
	return noise.lightened(0.02)
