class_name RaidMobs
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/ravager.lua and vex.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# Both are the remaining illager-side raid roles. Voxey had pillagers, vindicators
# and evokers; a raid is composed of all five, and the two missing ones are the
# heaviest and the lightest:
#
# **Ravager** — a beast, not a humanoid. 100 health and 12 melee damage with
# `knockback_resistance = 0.75` and `_attack_knockback = 1.5`, so it is hard to
# stagger and throws what it hits. It drops a saddle at `chance = 1`, and it is
# explicitly **not** captain-eligible (`_can_serve_as_captain = false`).
#
# **Vex** — a summoned flyer. 14 health and 4 damage, `physical = false` (it passes
# through blocks), no fall damage and no environmental damage at all. It carries a
# `_lifetimer` of `30 + random(90)` seconds and takes constant damage once it runs
# out, which is how the source disposes of it rather than despawning. It is only
# summoned by an evoker.
#
# The source's vex `attack_type = "null"` means it does not use the melee attack
# path; its damage comes from the `_on_attack`/collision branch, so this module
# exposes the contact rule rather than a swing.

const RAVAGER = "ravager"
const VEX = "vex"

# Source `ravager.lua`: `hp_min`/`hp_max`, `damage`, `knockback_resistance`,
# `_attack_knockback`, `reach` and the saddle drop.
const RAVAGER_HEALTH = 100.0
const RAVAGER_DAMAGE = 12.0
const RAVAGER_KNOCKBACK_RESISTANCE = 0.75
const RAVAGER_ATTACK_KNOCKBACK = 1.5
const RAVAGER_REACH = 2.0
# Source `ravager.lua`'s `drops`: a saddle at `chance = 1`.
const RAVAGER_DROPS = [[Nodes.SADDLE,1,1,1]]
# The source's `_can_serve_as_captain` is false for a ravager.
const RAVAGER_CAPTAIN = false
# Source `ravager.lua`'s roar, whose knockback the source applies to everything in
# reach. It is not a damage source, so it is a pure push.
const ROAR_KNOCKBACK = 0.5
const ROAR_COOLDOWN = 6.0

# Source `vex.lua`: `hp_min`/`hp_max = 14`, `damage = 4`, `xp_min = 6`, and a
# `_lifetimer` of `30 + math.random(90)` seconds.
const VEX_HEALTH = 14.0
const VEX_DAMAGE = 4.0
const VEX_XP = 6
const VEX_LIFE_MIN = 30.0
const VEX_LIFE_SPAN = 90.0
# The source's air friction, `_no_fall_damage` and `physical = false`.
const VEX_PHYSICAL = false
const VEX_FALL_DAMAGE = false

static func is_raid_mob(kind: String) -> bool: return kind == RAVAGER or kind == VEX
static func is_ravager(kind: String) -> bool: return kind == RAVAGER
static func is_vex(kind: String) -> bool: return kind == VEX

# The two `Creature.KINDS` rows, kept here so the table's values and this module's
# constants cannot drift apart.
static func ravager_kind() -> Dictionary:
	return {"hostile":true,"health":RAVAGER_HEALTH,"speed":2.6,"width":0.6,"height":1.6,"damage":12,
		"drops":RAVAGER_DROPS,"voice":"zombie","pitch":0.55,"xp":20,"armor":{"fleshy":100}}
static func vex_kind() -> Dictionary:
	return {"hostile":true,"health":VEX_HEALTH,"speed":4.5,"width":0.2,"height":0.8,"damage":4,
		"drops":[],"voice":"zombie","pitch":1.35,"xp":VEX_XP,"armor":{"fleshy":100}}

# --- ravager ----------------------------------------------------------------

# `_attack_knockback = 1.5`: what the ravager's blow does to whatever it hits. The
# source applies it as a multiplier on the normal knockback.
static func attack_knockback() -> float: return RAVAGER_ATTACK_KNOCKBACK

# The source's `knockback_resistance = 0.75`: incoming knockback is reduced to a
# quarter, which is what makes a ravager hard to push.
static func resist_knockback(amount: float) -> float:
	return amount*(1.0-RAVAGER_KNOCKBACK_RESISTANCE)

# `ravager_knockback`: the roar pushes everything within `reach` away from the
# ravager without damaging it.
static func roar_targets(center: Vector3, bodies: Array, reach: float = 4.0) -> Array:
	var hit: Array = []
	for body in bodies:
		if body == null or not is_instance_valid(body): continue
		if center.distance_to(body.position) <= reach: hit.append(body)
	return hit

# --- vex --------------------------------------------------------------------

# `_lifetimer = (20 * (30 + math.random(90))) / 20`, i.e. `30 + random(90)` seconds.
static func life_timer(rng: RandomNumberGenerator = null) -> float:
	var span: int = rng.randi_range(0,int(VEX_LIFE_SPAN)) if rng != null else randi_range(0,int(VEX_LIFE_SPAN))
	return VEX_LIFE_MIN+float(span)

# The source's own disposal: once the clock runs out the vex takes constant damage
# until it dies, rather than being removed outright.
static func expired(timer: float) -> bool: return timer <= 0.0
# `apply_environment_damage` is overridden to do nothing, so no source of
# environmental damage affects a vex.
static func environmental_damage() -> float: return 0.0

# --- raid composition -------------------------------------------------------

# The source's `mobs_and_spawn_count_by_wave` for the two roles this module owns.
# The pillager, vindicator, evoker and witch columns live with their own modules;
# this table exists so the raid can include the ravager's own band.
const RAVAGER_BY_WAVE = [0,0,1,0,1,0,2]

static func ravagers_for_wave(wave: int) -> int:
	return RAVAGER_BY_WAVE[clampi(wave,1,RAVAGER_BY_WAVE.size())-1]

# `RAVAGER_ATTACHMENT_POS`: a ravager may carry a rider from wave five (a pillager)
# or wave seven and beyond (an evoker or vindicator), which the source's jockey
# rule arranges.
static func jockey_allowed(wave: int) -> bool: return wave >= 5

# --- raid composition --------------------------------------------------------

# `mcl_raids`' own `mobs_and_spawn_count_by_wave`, per role, for waves one to seven.
# The pillager, vindicator, evoker and witch columns are the source's own numbers.
const WAVE_TABLE = {
	"pillager":[4,3,3,4,4,4,2],
	"vindicator":[0,2,0,1,4,2,5],
	"evoker":[0,0,0,0,1,1,2],
	"witch":[0,0,0,3,0,0,1],
	"ravager":[0,0,1,0,1,0,2],
}

# `num_ordinary_waves = 1 + mcl_vars.difficulty * 2`, so a normal-difficulty raid
# runs three ordinary waves and then its bonus wave.
static func ordinary_waves(difficulty: int) -> int:
	return 1+clampi(difficulty,0,3)*2

# `num_ordinary_spawns`: the table entry for the wave, capped at the raid's own wave
# count. Beyond the table a wave brings nothing of that role.
static func count_for(role: String, wave: int) -> int:
	var column: Array = WAVE_TABLE.get(role,[])
	if column.is_empty() or wave < 1: return 0
	return int(column[clampi(wave,1,column.size())-1])
