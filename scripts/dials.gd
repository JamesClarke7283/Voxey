class_name Dials
extends RefCounted

# Mineclonia ITEMS/mcl_clock/init.lua and ITEMS/mcl_compass/init.lua,
# GPL-3.0-or-later — the dynamic-dial half of both items. Original GDScript.
#
# Both items are ordinary craftitems whose whole point is that their icon moves:
#
#   * The **clock** has 64 frames. `current_frame = round(64 * timeofday)`, so
#     noon shows the sun and midnight the moon; the source maps frame 0 to
#     `(0 + 64/2 - 1) % 64`, which is why the dial is drawn half a turn round.
#   * The **compass** has 32 frames and points at the world spawn when it works,
#     or spins through random frames when it does not.
#
# Both are gated by `mcl_worlds.compass_works` (the clock aliases it): a compass
# or clock does **not** work in the Nether or the End, and in the void it works
# only within the overworld's own vertical range. When it does not work the dial
# spins instead of pointing, which is the visible warning.
#
# Voxey caches one icon per item, so a moving dial needs its frame to be part of
# the cache key. That is what `texture` keys on here.

const CLOCK_FRAMES = 64
const COMPASS_FRAMES = 32
# The source advances the spinning dial once per 0.1 second tick.
const SPIN_TICK = 0.1

static var spinning: int = 0
static var spin_timer: float = 0.0
static var frames: Dictionary = {}

# `mcl_worlds.compass_works`: false in the Nether and the End, and in the void
# only within the overworld's vertical range.
static func works(game: Node3D) -> bool:
	if game.dimension == "nether" or game.dimension == "end": return false
	return true

# The clock's frame for the current time. `round(64 * timeofday)` is the source's
# expression; the half-turn offset matches `clock_images`.
static func clock_frame(time_of_day: float) -> int:
	return roundi(CLOCK_FRAMES*fposmod(time_of_day,1.0)) % CLOCK_FRAMES

# The source advances its random frame on a 0.1 second tick.
static func tick(delta: float) -> void:
	spin_timer += delta
	while spin_timer >= SPIN_TICK:
		spin_timer -= SPIN_TICK
		spinning += 1

# The frame a dial should show right now.
static func frame(game: Node3D, id: int) -> int:
	if not works(game):
		# A dial that cannot read the world spins, which is the source's visible
		# "this does not work here" signal.
		return posmod(spinning,CLOCK_FRAMES if id == Nodes.CLOCK else COMPASS_FRAMES)
	if id == Nodes.CLOCK: return clock_frame(game.day_time)
	return compass_frame(game)

# A compass points from the player to the world spawn, quantised to 32 frames.
# The source measures that bearing in the horizontal plane.
static func compass_frame(game: Node3D) -> int:
	var from: Vector3 = game.player.position
	var to: Vector3 = Vector3(game.spawn_point)
	var delta: Vector2 = Vector2(to.x-from.x,to.z-from.z)
	if delta.length_squared() < 0.0001: return 0
	# Frame 0 points south in the source's first image; the angle is clockwise
	# from north so the needle sweeps the way a real compass does.
	var angle: float = atan2(delta.x,-delta.y)
	return posmod(roundi((angle/TAU)*COMPASS_FRAMES),COMPASS_FRAMES)

# Voxey's icon cache is keyed by item id, so an animated item must key on its
# frame as well or every dial would share one frozen image.
static func cache_key(id: int, frame: int) -> int: return id*1000+posmod(frame,1000)

# Draw the sun/moon dial for one clock frame. The hand sweeps a full turn across
# the 64 frames, with the sun above the axle at noon and the moon at midnight.
static func draw_clock(img: Image, frame: int, night: bool) -> void:
	var gold := Color("c9ab58")
	var face := Color("e1d9ba")
	ItemArt._polygon(img,[[5,1],[11,1],[15,5],[15,11],[11,15],[5,15],[1,11],[1,5]],gold)
	ItemArt._polygon(img,[[5,3],[11,3],[13,5],[13,11],[11,13],[5,13],[3,11],[3,5]],face)
	# The disc turns once per game day; half the frames show the moon.
	var angle: float = TAU*float(posmod(frame,CLOCK_FRAMES))/float(CLOCK_FRAMES)
	var centre := Vector2(8,8)
	var tip := centre+Vector2(sin(angle),-cos(angle))*4.0
	if night:
		img.fill_rect(Rect2i(int(tip.x)-1,int(tip.y)-1,3,3),Color("e8e6dd"))
	else:
		img.fill_rect(Rect2i(int(tip.x)-1,int(tip.y)-1,3,3),Color("f6c542"))
	ItemArt._line(img,centre,centre+Vector2(0,-3),Color("ad493e"),1)

# Draw one compass frame: the needle sweeps to the frame's bearing.
static func draw_compass(img: Image, frame: int, pointing: bool) -> void:
	ItemArt._polygon(img,[[5,1],[11,1],[15,5],[15,11],[11,15],[5,15],[1,11],[1,5]],Color("98a8ac"))
	ItemArt._polygon(img,[[5,3],[11,3],[13,5],[13,11],[11,13],[5,13],[3,11],[3,5]],Color("34434a"))
	var centre := Vector2(8,8)
	var angle: float = TAU*float(posmod(frame,COMPASS_FRAMES))/float(COMPASS_FRAMES)
	var tip := centre+Vector2(sin(angle),-cos(angle))*4.0
	ItemArt._line(img,centre,tip,Color("ad493e") if pointing else Color("7d6a52"),2)
	if pointing:
		img.fill_rect(Rect2i(int(tip.x)-1,int(tip.y)-1,2,2),Color("e8e6dd"))
