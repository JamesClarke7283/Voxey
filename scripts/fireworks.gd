class_name Fireworks
extends RefCounted

# Mineclonia ITEMS/mcl_fireworks, GPL-3.0-or-later. Original GDScript using the
# source as a behaviour reference.
#
# The reference has no firework *explosion* system at all: `mcl_fireworks` is
# purely an elytra booster. Three rockets exist, differing only in how long they
# drive the wings — 2.2, 4.5 and 6 seconds — and each is three-per-craft from
# paper plus one, two or three gunpowder. `use_rocket` accepts the item only when
# the elytra is already deployed and otherwise tells the player to jump while
# falling; the same three rockets are aliased as `mcl_bows:rocket`.
#
# The boost itself is `playerphysics/elytra.lua`: while rocketing, each axis is
# set to `look * 2.0 + (look * 30.0 - velocity) * 0.5 + velocity`, which drives
# the wings hard along the player's look direction. That is the same expression
# the server-player path clamps to `30 + 2` as a speed ceiling, so both agree on
# a maximum of 32 units.

const ROCKET_1 = VillageContent.ROCKET_1
const ROCKET_2 = VillageContent.ROCKET_2
const ROCKET_3 = VillageContent.ROCKET_3
const ROCKETS = [ROCKET_1,ROCKET_2,ROCKET_3]
# Source `register_rocket(n, duration, force)`, in order.
const DURATIONS = [2.2,4.5,6.0]
const FORCES = [10.0,20.0,30.0]
const BASE_ROCKET_BOOST = 2.0
const ROCKET_BOOST_FORCE = 30.0

static func is_rocket(id: int) -> bool: return ROCKETS.has(id)

static func duration(id: int) -> float:
	var index: int = ROCKETS.find(id)
	return DURATIONS[index] if index >= 0 else 0.0

static func force(id: int) -> float:
	var index: int = ROCKETS.find(id)
	return FORCES[index] if index >= 0 else 0.0

static func title(id: int) -> String:
	var index: int = ROCKETS.find(id)
	return "Firework rocket (%s)" % String.num(DURATIONS[index],1) if index >= 0 else "Firework rocket"

# `use_rocket`: a rocket only does anything once the wings are deployed, and the
# source says so rather than silently wasting the item.
static func use(game: Node3D, id: int) -> bool:
	if not is_rocket(id): return false
	if game.player.armor_slots[1].id != Nodes.ELYTRA or game.player.armor_slots[1].wear >= Nodes.durability(Nodes.ELYTRA)-1:
		game.toast("Equip usable elytra to use a firework rocket.")
		return true
	if not game.player.gliding:
		game.toast("Elytra not deployed. Jump while falling down to deploy.")
		return true
	game.player.rocketing = maxf(game.player.rocketing,duration(id))
	game.sound_at("rocket",game.player.position,1.0)
	game.puff(game.player.position,Color("bc7a57"),8,2.0)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.player.swing = 1
	return true

# `rocket_boost`, applied per substep while `rocketing` remains positive. The
# look direction is the source's `get_look_dir`, i.e. the camera's forward axis.
static func boost(player: Node3D, delta: float) -> void:
	if player.rocketing <= 0.0: return
	var look: Vector3 = -player.camera.global_basis.z
	var v: Vector3 = player.velocity
	for axis in 3:
		v[axis] = look[axis]*BASE_ROCKET_BOOST+(look[axis]*ROCKET_BOOST_FORCE-v[axis])*0.5+v[axis]
	player.velocity = v
	player.rocketing = maxf(0.0,player.rocketing-delta)

# Original art: a paper tube with a fuse, tinted per tier.
static func draw(img: Image, id: int, tier: int) -> void:
	var body: Color = ["e8e4dc","f0d9a8","f0b48a"][clampi(tier,0,2)]
	img.fill_rect(Rect2i(6,3,4,10),body)
	img.fill_rect(Rect2i(6,13,4,2),Color("8a5a3a"))
	ItemArt._line(img,Vector2(8,1),Vector2(8,3),Color("6d6d6d"))
	img.fill_rect(Rect2i(7,6,2,1),Color("c8402f"))

static func recipes(inv: Inventory) -> void:
	var paper: int = Nodes.PAPER
	var powder: int = Nodes.GUNPOWDER
	inv._shapeless("Firework rockets",ROCKET_1,3,[paper,powder])
	inv._shapeless("Firework rockets",ROCKET_2,3,[paper,powder,powder])
	inv._shapeless("Firework rockets",ROCKET_3,3,[paper,powder,powder,powder])
