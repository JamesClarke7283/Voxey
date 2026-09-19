class_name Totems
extends RefCounted

# Mineclonia ITEMS/mcl_totems/init.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# A totem of undying is a lethal-damage interception. The source registers a
# damage modifier that fires when a hit would take the holder to zero or below:
#
#   * The totem must be **wielded**, and the source checks the offhand when the
#     main hand does not hold one. Voxey has no offhand, so the main hand is the
#     only place it can be carried.
#   * The hit is replaced with **exactly 1 HP** — `math.max(0, hp - 1)` — so the
#     holder is left at one health rather than the damage being cancelled.
#   * **All effects are cleared first**, then three are applied: regeneration at
#     level 2 for 45 seconds, fire resistance for 40, and absorption at level 2
#     for 5.
#   * Breath is topped up to 10 if it had fallen below 11, which matters when the
#     lethal hit was drowning.
#   * The totem is consumed, and is **not** consumed in creative.
#
# One reason bypasses the totem in the reference: `out_of_world`, which is the
# void. That is reproduced, so falling out of the world cannot be saved.

const ID = VillageContent.TOTEM
const USES = 1
# `out_of_world` is the only source reason that bypasses a totem.
const BYPASSING = ["out_of_world","void"]
# The source's own effect set, in its own order and with its own durations.
const REGEN_DURATION = 45.0
const FIRE_DURATION = 40.0
const ABSORPTION_DURATION = 5.0

static func is_totem(id: int) -> bool: return id == ID

# Whether a damage reason may be intercepted at all.
static func bypasses(reason: String) -> bool: return BYPASSING.has(reason)

# `get_wielditem` plus the offhand fallback: the totem must be carried in either
# hand. The offhand is a real slot now, so a totem can be held there while a
# weapon stays in the main hand, which is how the source uses it.
static func held(player: VoxeyPlayer) -> bool:
	return is_totem(player.game.inventory.held().id) or is_totem(player.offhand_id())

# The interception itself. Returns true when the totem saved the holder, so the
# caller applies 1 HP instead of the lethal damage.
static func intercept(player: VoxeyPlayer, damage: float, reason: String) -> bool:
	if damage <= 0.0: return false
	if bypasses(reason): return false
	if player.health-damage > 0.0: return false
	if not held(player): return false
	# Breath is topped up, which the source does before anything else.
	if player.breath < 11.0: player.breath = 10.0
	# The source clears every effect before applying the totem's own.
	PotionEffects.clear(player)
	PotionEffects.apply(player,"regeneration",REGEN_DURATION,2)
	PotionEffects.apply(player,"fire_resistance",FIRE_DURATION,1)
	PotionEffects.apply(player,"absorption",ABSORPTION_DURATION,2)
	# The totem is destroyed, unless the holder is in creative.
	# The source replaces the hit with `math.max(0, hp - 1)`, which is what leaves
	# the holder at exactly one health.
	player.health = 1.0
	if player.game.gamemode != "creative":
		# Consume from whichever hand carried it.
		player.consume_carried(ID)
	player.game.sound_at("totem",player.position,1.0)
	player.game.puff(player.position+Vector3.UP,Color("98bf22"),40,3.0)
	player.game.achievements.award("post_mortal")
	return true

# --- art ---------------------------------------------------------------------

# A golden figure with green gemstone eyes, as the reference's totem depicts.
static func draw(img: Image) -> void:
	var gold := Color("e8c44a")
	var dark := Color("8a6f1e")
	var gem := Color("4fbf3a")
	img.fill_rect(Rect2i(6,2,4,3),gold)
	img.fill_rect(Rect2i(5,5,6,6),gold)
	img.fill_rect(Rect2i(4,11,8,2),gold)
	img.fill_rect(Rect2i(7,5,1,1),gem); img.fill_rect(Rect2i(6,7,1,1),gem)
	ItemArt._line(img,Vector2(5,6),Vector2(10,6),dark)
	img.fill_rect(Rect2i(9,3,1,3),dark)
	img.fill_rect(Rect2i(4,9,2,2),gem)
