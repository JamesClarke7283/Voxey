class_name Weather
extends RefCounted

# Mineclonia mcl_weather/{weather_core,rain,snow,thunder}.lua,
# mcl_lightning/init.lua and mcl_moon/init.lua, GPL-3.0-or-later.
#
# This is the one authoritative weather state. Source registers exactly three
# states and Voxey keeps the same three, using the same words the console
# command and every existing consumer already use:
#
#   clear   (source "none") 600..9000 s   transitions {50: "rain"}
#   rain                    600..1200 s   transitions {65: "clear", 70: "rain", 100: "thunder"}
#   thunder                 600..1200 s   transitions {100: "rain"}
#
# Source evaluates its transition table with `pairs`, so which state a roll
# selects is iteration-order dependent whenever two thresholds overlap. This
# port instead walks the thresholds in ascending order and takes the first one
# strictly greater than the roll, which makes the documented table the real
# behaviour: a roll of 10 with rain's table yields clear, a roll in (65,70]
# yields rain and a roll above 70 yields thunder. That resolves a genuine
# source ambiguity deterministically rather than reproducing undefined order.
#
# A roll that matches no threshold does not end the state: the source leaves
# `end_time` in the past and simply re-rolls on its next 5-second check. That
# behaviour is reproduced, so min/max duration acts as a lower bound.
#
# Recorded source gaps carried over rather than invented:
# - "snow" is not a registered source state. Snow appears inside the rain and
#   thunder states wherever the biome is cold, which is what `snowing` below
#   implements; there is no separate snow weather.
# - `mcl_lightning.interval_low/high` (17/503) are dead in the checkout. The
#   real cadence is the thunder state's 3..12 second strike delay.
# - `mcl_weather.mode` is never assigned in the checkout; the particle mode is
#   presentation and is not ported.
# - The source fire ABM checks the target cell and its four horizontal
#   neighbours; farmland checks global rain without the snow guard, while the
#   cauldron ABM excludes cold biomes. Those differences are preserved.
#
# Cauldron filling and farmland hydration already own their own source ABMs in
# `Cauldrons.update` and `Farmland.rain_preserves`, keyed on this module's
# `weather()`. They are deliberately not duplicated here: one clock per system.
# SnowCover already owns the 16-second melt ABM, so melting is not ported either.

const STATES = ["clear","rain","thunder"]
const MIN_DURATION = 600.0
const MAX_DURATION = 9000.0
const CLOUDY_DURATION = 1200.0
const CHECK_INTERVAL = 5.0
# Thresholds in ascending order, as the source intends them to be read.
const TRANSITIONS = {
	"clear":[[50,"rain"]],
	"rain":[[65,"clear"],[70,"rain"],[100,"thunder"]],
	"thunder":[[100,"rain"]],
}
const LIGHT_FACTOR = {"clear":1.0,"rain":0.6,"thunder":0.33333}
# Source rain ABM: interval 2.0, chance 2, fire and its four horizontal neighbours.
const FIRE_INTERVAL = 2.0
const FIRE_CHANCE = 2
# Source snow ABM: interval 27, chance 33, only from rain or thunder.
const SNOW_INTERVAL = 27.0
const SNOW_CHANCE = 33
# Source thunder cadence: math.random(3, 12) seconds between strikes.
const STRIKE_MIN = 3.0
const STRIKE_MAX = 12.0
# Source mcl_lightning constants.
const RANGE_H = 100
const RANGE_V = 50
const STRIKE_DAMAGE = 5.0
const STRIKE_RADIUS = 3.5
const FIRE_SIDES = [Vector3i.ZERO,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const MOON_PHASES = 8

# --- state ------------------------------------------------------------------

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("weather"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+9700
		world.set_meta("weather",{"rng":rng,"clock":0.0,"fire_clock":0.0,"snow_clock":0.0,"strike_clock":0.0})
	return world.get_meta("weather")

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("weather"): world.remove_meta("weather")

# The single authoritative answer every consumer reads.
static func weather(world: VoxelWorld) -> String:
	if world.dimension != "overworld": return "clear"
	var stored: Variant = world.adventure_state.get("weather","")
	# A value written by the console command is authoritative, so an operator can
	# hold a state; the five-day fallback only applies when nothing is stored.
	if stored is String and STATES.has(stored): return stored
	return ["clear","clear","rain","clear","thunder"][world.get_parent().day_number()%5]

static func end_time(world: VoxelWorld) -> float:
	var stored: Variant = world.adventure_state.get("weather_end",-1.0)
	return float(stored) if (stored is float or stored is int) and is_finite(float(stored)) else -1.0

static func change(world: VoxelWorld, new_state: String, explicit_end: float = -1.0) -> bool:
	if not STATES.has(new_state): return false
	world.adventure_state["weather"] = new_state
	# An explicit end of -1 means "let update roll a fresh duration".
	world.adventure_state["weather_end"] = explicit_end
	return true

static func roll_duration(rng: RandomNumberGenerator, state: String) -> float:
	var span: float = MAX_DURATION if state == "clear" else CLOUDY_DURATION
	return rng.randf_range(MIN_DURATION,span)

# The first threshold strictly greater than the roll, in ascending order.
static func next_state(state: String, roll: int) -> String:
	for entry in TRANSITIONS.get(state,[]):
		if roll < int(entry[0]): return String(entry[1])
	return state

static func light_factor(world: VoxelWorld) -> float:
	return float(LIGHT_FACTOR.get(weather(world),1.0))

# --- predicates -------------------------------------------------------------

static func has_weather(world: VoxelWorld, p: Vector3i) -> bool:
	if world.dimension != "overworld": return false
	var generator: TerrainGenerator = world.generator
	return p.y >= generator.min_y()-64 and p.y <= generator.max_y()

# Source `is_outdoor` hard-codes noon lighting, so a roofed cell is excluded but
# glass is not. Voxey's `open_sky` tests the actual column, which is stricter;
# that difference is deliberate and recorded in the module docs.
static func outdoor(world: VoxelWorld, p: Vector3i) -> bool:
	return world.dimension == "overworld" and world.open_sky(p)

static func rainy_biome(biome: String) -> bool: return biome not in ["Sunwash desert","Frostpine highlands"]
static func snowy_biome(biome: String) -> bool: return biome == "Frostpine highlands"

# Source `has_rain`: in the weather region, not arid, and able to see outdoors.
static func has_rain(world: VoxelWorld, p: Vector3i) -> bool:
	if not has_weather(world,p): return false
	if not rainy_biome(world.generator.biome(p.x,p.z)): return false
	return outdoor(world,p)

# Source `has_snow`: the same test restricted to a cold biome.
static func has_snow(world: VoxelWorld, p: Vector3i) -> bool:
	if not has_weather(world,p): return false
	if not snowy_biome(world.generator.biome(p.x,p.z)): return false
	return outdoor(world,p)

# Source `is_exposed_to_rain`: raining, in the weather region, not arid, outdoor
# and not cold. Used by burning, Riptide and mob desiccation in the source.
static func exposed_to_rain(world: VoxelWorld, p: Vector3i) -> bool:
	if weather(world) not in ["rain","thunder"]: return false
	if not has_weather(world,p): return false
	if not rainy_biome(world.generator.biome(p.x,p.z)): return false
	return outdoor(world,p)

# --- update -----------------------------------------------------------------

static func update(world: VoxelWorld, delta: float) -> void:
	if delta <= 0 or not is_finite(delta) or not world.get_parent().playing(): return
	var data: Dictionary = runtime(world)
	data.clock = float(data.clock)+delta
	var state: String = weather(world)
	var end: float = end_time(world)
	var rng: RandomNumberGenerator = data.rng
	var game_time: float = float(Time.get_ticks_msec())/1000.0
	# A state with no recorded end gets one now; the console command stores -1.
	if end <= 0.0:
		world.adventure_state["weather_end"] = game_time+roll_duration(rng,state)
		# The fallback words rotate with the day, so adopt one explicitly.
		change(world,state,game_time+roll_duration(rng,state))
	elif float(data.clock) >= CHECK_INTERVAL:
		data.clock = 0.0
		if game_time >= end:
			var chosen: String = next_state(state,rng.randi_range(0,100))
			# A roll that matches nothing leaves the state running, as in source.
			change(world,chosen,game_time+roll_duration(rng,chosen) if chosen != state else end)
	if weather(world) not in ["rain","thunder"]: return
	_step_fire(world,data,delta)
	_step_snow(world,data,delta)
	if weather(world) == "thunder": _step_thunder(world,data,delta)

# Source fire ABM: interval 2.0, chance 2, removed when the fire cell or any of
# its four horizontal neighbours is outdoor and in rain.
static func _step_fire(world: VoxelWorld, data: Dictionary, delta: float) -> void:
	data.fire_clock = float(data.fire_clock)+delta
	if float(data.fire_clock) < FIRE_INTERVAL: return
	data.fire_clock = 0.0
	var rng: RandomNumberGenerator = data.rng
	for p in world.edits.keys():
		if world.edits[p] not in [Fire.FLAME,Fire.ETERNAL]: continue
		if not world.loaded_at(Vector3(p)) or rng.randi_range(1,FIRE_CHANCE) != 1: continue
		for side in FIRE_SIDES:
			var at: Vector3i = p+side
			if outdoor(world,at) and has_rain(world,at):
				world.set_node(p,Nodes.AIR)
				break

# Source snow ABM: interval 27, chance 33, only while raining or thundering, on
# an opaque, leaf or snow surface that has air above it, in a cold biome.
static func _step_snow(world: VoxelWorld, data: Dictionary, delta: float) -> void:
	data.snow_clock = float(data.snow_clock)+delta
	if float(data.snow_clock) < SNOW_INTERVAL: return
	data.snow_clock = 0.0
	var rng: RandomNumberGenerator = data.rng
	for p in world.edits.keys():
		if not world.loaded_at(Vector3(p)) or rng.randi_range(1,SNOW_CHANCE) != 1: continue
		var id: int = world.node_at(p)
		var piling: bool = id == Nodes.SNOW_BLOCK or Pasture.opaque(id) or WoodTypes.is_leaves(id) or SnowCover.is_snow(id)
		if not piling: continue
		var above: Vector3i = p+Vector3i.UP
		if world.node_at(above) != Nodes.AIR: continue
		if not has_snow(world,Vector3(p)+Vector3(0.5,0.5,0.5)) or not outdoor(world,p): continue
		pile(world,p,above,id)

# Source raises the layer of an existing snow cover and a full cover becomes a
# snow block; any other surface gets a single new layer above it. Voxey's cover
# has eight layers, matching the seven source height nodes plus the block.
static func pile(world: VoxelWorld, p: Vector3i, above: Vector3i, id: int) -> void:
	if SnowCover.is_snow(id):
		var layers: int = SnowCover.layers(id)
		if layers >= 8:
			world.set_node(p,Nodes.SNOW_BLOCK)
		else:
			world.set_node(p,SnowCover.BASE+layers)
		return
	world.set_node(above,SnowCover.BASE)

# Source thunder step: a strike every 3..12 seconds while thundering.
static func _step_thunder(world: VoxelWorld, data: Dictionary, delta: float) -> void:
	data.strike_clock = float(data.strike_clock)+delta
	if float(data.strike_clock) < STRIKE_MIN: return
	var rng: RandomNumberGenerator = data.rng
	if float(data.strike_clock) < rng.randf_range(STRIKE_MIN,STRIKE_MAX): return
	data.strike_clock = 0.0
	strike(world,rng)

# Source `choose_pos`: sample around the player, refuse underground, then find
# the first block below within the vertical range.
static func choose_pos(world: VoxelWorld, rng: RandomNumberGenerator) -> Dictionary:
	var game: Node3D = world.get_parent()
	var origin: Vector3 = game.player.position
	if origin.y < -20: return {}
	var x: int = floori(origin.x-RANGE_H/2.0)+rng.randi_range(1,RANGE_H)
	var z: int = floori(origin.z-RANGE_H/2.0)+rng.randi_range(1,RANGE_H)
	return choose_pos_at(world,Vector3(x,origin.y+RANGE_V/2.0,z))

# The downward search half of `choose_pos`, also used when a position is given.
static func choose_pos_at(world: VoxelWorld, top: Vector3) -> Dictionary:
	var hit: Dictionary = world.raycast(top,Vector3.DOWN,RANGE_V,true)
	if hit.is_empty(): return {}
	var cell: Vector3i = hit.pos
	if world.node_at(cell+Vector3i.UP) != Nodes.AIR: return {}
	return {"pos":cell,"strike":top}

# One full strike, in source order: the rain gate, rod attraction, creature
# damage and conversion, then fire at the strike cell.
# Source `mcl_lightning.strike(pos?, for_trap?)` accepts an optional position;
# without one a random point around the player is chosen.
static func strike(world: VoxelWorld, rng: RandomNumberGenerator, at: Vector3 = Vector3.INF) -> bool:
	var chosen: Dictionary = choose_pos_at(world,at) if not is_inf(at.x) else choose_pos(world,rng)
	if chosen.is_empty(): return false
	var cell: Vector3i = chosen.pos
	var strike_position: Vector3 = Vector3(cell)+Vector3(0.5,1.5,0.5)
	# Source thunder aborts a strike whose chosen position has no rain.
	if not has_rain(world,strike_position): return false
	var rod: Vector3i = Copper.strike_rod(world,strike_position)
	if rod != Vector3i.ZERO:
		cell = rod
		strike_position = Vector3(rod)+Vector3(0.5,1.5,0.5)
	var game: Node3D = world.get_parent()
	game.sound_at("explode",strike_position,0.6)
	game.puff(strike_position,Color("fffbe0"),12,3.0)
	for mob in game.creatures.get_children():
		if not mob is Creature or mob.is_queued_for_deletion(): continue
		if mob.center().distance_to(strike_position) > STRIKE_RADIUS: continue
		# Source `_on_lightning_strike` conversions. A struck creeper becomes
		# charged, a pig becomes a zombified piglin, and a struck villager becomes
		# a witch. Each returns true, which means the strike does *not* also damage
		# the mob it converted. A skeleton horse is immune and takes nothing.
		if mob.kind == "creeper" and not mob.charged:
			mob.charged = true
			mob.hurt_flash = 0.4
			game.puff(mob.center(),Color("7fe0ff"),14,2.5)
			continue
		if mob.kind == "pig":
			convert_mob(game,mob,"zombified_piglin")
			continue
		if mob.kind == "skeleton_horse":
			continue
		if mob is VillageMob and mob.profession != "golem":
			# The villager's record carries the profession, so it is cleared and
			# the mob is respawned as a witch - the source relinquishes the pois
			# and the villager is gone.
			var record: Dictionary = game.villages.record(mob.person_key)
			if not record.is_empty(): record.dead = true; record.health = 0.0
			convert_mob(game,mob,"witch")
			continue
		# Lightning is the source's `is_lightning` damage type rather than a punch, so it
		# is not scaled by a mob's `armor` table.
		mob.hit(STRIKE_DAMAGE,strike_position,"lightning")
	# Source sets fire at the strike cell when it is air and not over a liquid.
	var above: Vector3i = cell+Vector3i.UP
	if not Fluids.liquid(world.node_at(cell)) and world.node_at(above) == Nodes.AIR:
		Fire.ignite(world,above)
	# Copper de-oxidation, matching the source's unreachable affected_by_lightning
	# scan over cut copper stairs and slabs.
	for x in range(-5,6):
		for y in range(-5,6):
			for z in range(-5,6):
				var p := above+Vector3i(x,y,z)
				if Copper.shape_id(world.node_at(p)) == 0: continue
				Copper.lightning_strike(world,p)
	return true

# Replace one mob with another kind at the same spot, which is what the source's
# `replace_mob`/`replace_with` do. The replacement keeps the position and facing;
# the original is removed without drops, since a conversion is not a death.
static func convert_mob(game: Node3D, mob: Creature, kind: String) -> Creature:
	if mob.is_queued_for_deletion(): return null
	var spot: Vector3 = mob.position
	var facing: float = mob.rotation.y
	var was_raid: bool = mob.get_meta("raid",false)
	game.puff(mob.center(),Color("bfe6ff"),18,2.5)
	mob.queue_free()
	var replacement: Creature = game.spawn_creature(kind,spot)
	if replacement == null: return null
	replacement.rotation.y = facing
	if was_raid: replacement.set_meta("raid",true)
	return replacement

# --- moon -------------------------------------------------------------------

# Source phase: the day counter, advanced after midday, modulo eight. Source
# seeds a per-world phase offset from the mapgen seed; a single-player world has
# no such offset, so phase 0 is the first full moon.
static func moon_phase(world: VoxelWorld) -> int:
	var game: Node3D = world.get_parent()
	return posmod(game.day_number(),MOON_PHASES)

# Source brightness: 0.0 at new moon (phase 4), 1.0 at full moon (phase 0).
static func moon_brightness(world: VoxelWorld) -> float:
	return absf(float(moon_phase(world))-4.0)/4.0
