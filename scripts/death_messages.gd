class_name DeathMessages
extends RefCounted

# Mineclonia HUD/mcl_death_messages/init.lua — the reason table at :4-144 and its
# dispatch at :146-215 — and CORE/mcl_damage/init.lua :5-39, the per-type flags.
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Voxey's death screen printed one static line ("A new beginning.") while every
# `hurt()` call site invented its own cause string. The source instead keys a
# message on the damage reason and takes the first variant that applies. This
# module is that table, the flag table the reasons are classified by, and an audit
# of Voxey's own causes against it. Nothing here registers content.
#
# Source rules reproduced:
#
#  * Dispatch order (init.lua:198-203): killer, then assist, then plain, then the
#    fallback. The killer variant needs a `reason.source`; the **item** variant
#    needs that source to be wielding something with a name, which the source
#    renders in brackets and colours aqua when the tool is enchanted
#    (init.lua:146-158). Voxey's death label is plain text, so the aqua is dropped
#    and the brackets kept: `message("mob","Zombie","Diamond Sword")` gives
#    "… was slain by Zombie using [Diamond Sword]".
#  * `@1` is the victim's object name. Voxey is single-player and the player has no
#    name field, so `VICTIM` stands in. It is a third-person subject because
#    several of the source's lines are only grammatical in the third person
#    ("@1 was struck by lightning"); the one line the choice would break for a
#    second-person subject is unreachable in Voxey anyway, since no Voxey path
#    passes a lightning cause to the player.
#  * A reason with no message falls back to the source's own translation key and
#    the name (init.lua:180-182), kept verbatim rather than replaced with invented
#    text, so an un-transcribed reason is visibly un-translated.
#  * Two entries declare `escape`, not `assist` (wither at :76, anvil at :84), and
#    the source's dispatch reads only `assist` (init.lua:168-172), so those two
#    variants can never fire. They are transcribed and unreachable, which is the
#    source's own behaviour.
#  * The assist variant needs `mcl_death_messages.assist[obj]`, cached by the
#    damage callback for five seconds (init.lua:217-232). Voxey has no per-player
#    assist cache, so `message` takes no assist argument and the assist texts are
#    transcribed but unreachable here.
#
# Flag table: `mcl_damage.types` declares eleven flag names; six describe how a hit
# is mitigated, and those are what `flags` reports. The other five — is_magic,
# is_lightning, bypasses_guardian, bypasses_invulnerability, scales,
# always_affects_dragons — are kept in DECLARED, where they are visible, but Voxey
# has no counterpart to compare them against.
#
# Voxey findings (`audit`): Voxey does not carry flags through its damage pipeline.
# `hurt(amount,bypass_armor,source,cause)` decides mitigation per call, and
# `bypass_armor` skips `Totems.intercept` outright (player.gd:952), so **every**
# armor-bypassing cause also bypasses a totem, while the source sets
# `bypasses_totem` for `out_of_world` alone. That is the systematic difference; the
# per-cause table is IMPLEMENTED below. The causes that already agree are void,
# sweet_berry, explosion, mob, projectile, anvil and falling_node. `magic` is
# armor-reduced in Voxey but bypasses armor in the source, `hot_floor` and
# `generic` disagree on armor, and `fire` has no source entry at all: Voxey merges
# the source's in_fire, on_fire, lava and hot_floor into one cause, and the sites
# that pass it are split on armor (false at magic_projectile.gd:78, true
# everywhere else), so the audit reports it as unknown rather than guessing.

# `@1` in every source line is the victim's object name. Voxey is single-player
# and has no name field, so this stands in.
const VICTIM = "The player"

# The source's own last resort (init.lua:180-182) is the **translation key** plus the
# victim's name, because every other string in that file goes through the engine's
# translator. Voxey has no translation layer, so a key would render as
# `mcl_death_messages.messages.arrow The player` on the death screen — visibly
# broken text rather than a message. The keys are kept so the shape is the source's,
# but a killer-only entry with no killer to name falls back to a readable line built
# from `_cause_label` instead. The check asserts both halves: the source's key is
# reproduced when a caller asks for it, and the screen never shows one.
const FALLBACK_PREFIX = "mcl_death_messages.messages."

# `mcl_death_messages.messages`, transcribed from init.lua:6-143 in the source's
# own order. Every value is a `NS()` literal there, so the text is final and no
# translation key is involved.
const MESSAGES = {
	"in_fire": {"plain":"@1 went up in flames","assist":"@1 walked into fire whilst fighting @2"},
	"lightning_bolt": {"plain":"@1 was struck by lightning","assist":"@1 was struck by lightning whilst fighting @2"},
	"on_fire": {"plain":"@1 burned to death","assist":"@1 was burnt to a crisp whilst fighting @2"},
	"lava": {"plain":"@1 tried to swim in lava","assist":"@1 tried to swim in lava to escape @2"},
	"hot_floor": {"plain":"@1 discovered the floor was lava","assist":"@1 walked into danger zone due to @2"},
	"in_wall": {"plain":"@1 suffocated in a wall","assist":"@1 suffocated in a wall whilst fighting @2"},
	"drown": {"plain":"@1 drowned","assist":"@1 drowned whilst trying to escape @2"},
	"starve": {"plain":"@1 starved to death","assist":"@1 starved to death whilst fighting @2"},
	"cactus": {"plain":"@1 was pricked to death","assist":"@1 walked into a cactus whilst trying to escape @2"},
	# The source lists seven further fall wordings in comments (:44-50) for fall
	# distance, climbing and the vine/ladder states, and reads none of them.
	"fall": {"plain":"@1 hit the ground too hard","assist":"@1 hit the ground too hard whilst trying to escape @2"},
	"fly_into_wall": {"plain":"@1 experienced kinetic energy","assist":"@1 experienced kinetic energy whilst trying to escape @2"},
	"out_of_world": {"plain":"@1 fell out of the world","assist":"@1 didn't want to live in the same world as @2"},
	"generic": {"plain":"@1 died","assist":"@1 died because of @2"},
	"magic": {"plain":"@1 was killed by magic","assist":"@1 was killed by magic whilst trying to escape @2",
		"killer":"@1 was killed by @2 using magic","item":"@1 was killed by @2 using @3"},
	"dragon_breath": {"plain":"@1 was roasted in dragon breath","killer":"@1 was roasted in dragon breath by @2"},
	"wither": {"plain":"@1 withered away","escape":"@1 withered away whilst fighting @2"},
	"wither_skull": {"plain":"@1 was killed by magic","killer":"@1 was shot by a skull from @2"},
	"anvil": {"plain":"@1 was squashed by a falling anvil","escape":"@1 was squashed by a falling anvil whilst fighting @2"},
	"falling_node": {"plain":"@1 was squashed by a falling block","assist":"@1 was squashed by a falling block whilst fighting @2"},
	"mob": {"killer":"@1 was slain by @2","item":"@1 was slain by @2 using @3"},
	"player": {"killer":"@1 was slain by @2","item":"@1 was slain by @2 using @3"},
	"arrow": {"killer":"@1 was shot by @2","item":"@1 was shot by @2 using @3"},
	"spit": {"killer":"@1 was spitballed by @2","item":"@1 was spitballed by @2 using @3"},
	"fireball": {"killer":"@1 was fireballed by @2","item":"@1 was fireballed by @2 using @3"},
	"thorns": {"killer":"@1 was killed trying to hurt @2","item":"@1 tried to hurt @2 and died by @3"},
	# The source comments a further nether/end bed wording at :120 and reads none of it.
	"explosion": {"plain":"@1 blew up","killer":"@1 was blown up by @2","item":"@1 was blown up by @2 using @3"},
	"cramming": {"plain":"@1 was squished too much","assist":"@1 was squashed by @2"},
	"fireworks": {"plain":"@1 went off with a bang","item":"@1 went off with a bang due to a firework fired by @2 from @3"},
	"sweet_berry": {"plain":"@1 was poked to death by a sweet berry bush","assist":"@1 was poked to death by a sweet berry bush whilst trying to escape @2"},
	"freeze": {"plain":"@1 froze to death","assist":"@1 was frozen to death by @2"},
	"trident": {"killer":"@1 was impaled by @2","item":"@1 was impaled by @2 with @3"},
}

# `mcl_damage.types`, transcribed from CORE/mcl_damage/init.lua:5-39 in the
# source's own order, with the source's own comments carried where they matter:
#
#  * `dragon_breath` is "only used for dragon fireball; dragon fireball does not
#    actually deal impact damage tho, so this is unreachable".
#  * `falling_node` is `falling_block` in Minecraft.
#  * `fireworks` is marked unused.
#  * `lightning_bolt` declares `is_lightning`, which is not one of the six flags.
const DECLARED = {
	"in_fire": {"is_fire":true},
	"lightning_bolt": {"is_lightning":true},
	"on_fire": {"is_fire":true,"bypasses_armor":true},
	"lava": {"is_fire":true},
	"hot_floor": {"is_fire":true},
	"in_wall": {"bypasses_armor":true},
	"drown": {"bypasses_armor":true},
	"freeze": {"bypasses_armor":true},
	"starve": {"bypasses_armor":true,"bypasses_magic":true},
	"cactus": {},
	"sweet_berry": {},
	"fall": {"bypasses_armor":true},
	"fly_into_wall": {},
	"out_of_world": {"bypasses_armor":true,"bypasses_magic":true,"bypasses_invulnerability":true,"bypasses_totem":true},
	"generic": {"bypasses_armor":true},
	"magic": {"is_magic":true,"bypasses_armor":true,"bypasses_guardian":true},
	"dragon_breath": {"is_magic":true,"bypasses_armor":true},
	"wither": {"bypasses_armor":true},
	"wither_skull": {"is_magic":true,"is_explosion":true},
	"anvil": {},
	"falling_node": {},
	"spit": {"is_projectile":true},
	"mob": {},
	"player": {},
	"arrow": {"is_projectile":true},
	"fireball": {"is_projectile":true,"is_fire":true},
	"thorns": {"is_magic":true,"bypasses_guardian":true},
	"explosion": {"is_explosion":true,"scales":true,"always_affects_dragons":true},
	"cramming": {"bypasses_armor":true},
	"fireworks": {"is_explosion":true},
	"environment": {},
	"light": {},
	"trident": {},
}

# The six flags `flags` reports, in the order the audit compares them. The flags
# a reason does not declare default to false, which is how the source reads them
# (`reason.flags.bypasses_armor` is nil, and therefore falsy, when undeclared).
const FLAG_NAMES = ["bypasses_armor","is_fire","is_projectile","is_explosion","bypasses_totem","bypasses_magic"]

# Voxey cause -> source reason, where the two names differ.
#
#  * `void` is Voxey's name for the source's `out_of_world`: `mcl_void_damage`
#    deals that reason (ENVIRONMENT/mcl_void_damage/init.lua:70) and `Totems`
#    already makes the same identification (scripts/totems.gd:27).
#  * `projectile` is Voxey's single cause for `arrow.gd:102` and for the non-fire
#    fireballs at `magic_projectile.gd:78`. The source declares three projectile
#    reasons with that one flag (spit, arrow, fireball) plus `trident`, which
#    declares none; `arrow` is the entry Voxey's hits correspond to.
# A Voxey cause that names the same event under a different word than the source's
# `mcl_damage` type. `void` is the source's `out_of_world`; a Voxey `explosion`
# carries the source's `charged_explosion` too, because the source's creeper blast is
# the same reason with a different source object; `fire` is the one Voxey cause the
# source splits three ways (`in_fire`, `on_fire`, `lava`), and it resolves to the
# plainest of them so a burning death reads sensibly rather than falling through.
const ALIASES = {"void":"out_of_world","projectile":"arrow","charged_explosion":"explosion",
	"fire":"in_fire","lightning":"lightning_bolt"}

# Every cause Voxey passes to `VoxeyPlayer.hurt()` (player.gd:946), with the sites
# that pass it. This is the list the audit is meant to be handed.
const VOXEY_CAUSES = [
	"void",          # player.gd:152 (void_clock tick below the generator floor)
	"starve",        # hunger.gd:109
	"fall",          # player.gd:355
	"in_wall",       # hazards.gd:59
	"freeze",        # player.gd:175
	"hot_floor",     # magma.gd:56
	"fire",          # player.gd:278 (lava), player.gd:282 (burning), campfires.gd:234, potion_effects.gd:95, magic_projectile.gd:78
	"sweet_berry",   # sweet_berry_thorns.gd:102
	"explosion",     # game.gd:796
	"thorns",        # guardian_auras.gd:82
	"magic",         # creature.gd:806
	"mob",           # beehives.gd:222, beehives.gd:235
	"projectile",    # arrow.gd:102, magic_projectile.gd:78
	"anvil",         # falling_damage.gd:64
	"falling_node",  # falling_damage.gd:64
	"generic",       # the default at player.gd:946, also passed explicitly by potion_effects.gd:95
]

# What Voxey actually does for each cause the audit can resolve, as the six flags.
# Derived from the call sites above, not declared anywhere in Voxey:
#
#  * `bypasses_armor` is the call's own `bypass_armor` argument.
#  * `bypasses_totem` is true whenever that argument is true, because
#    `Totems.intercept` is only consulted under `if not bypass_armor`
#    (player.gd:952); `Totems.bypasses` adds `void`/`out_of_world` on top.
#  * `bypasses_magic` is true for `void` and `starve` only, the two causes that
#    skip `PotionEffects.resistance`/`absorb` (player.gd:957, :960); `void` also
#    gets no Protection enchantment at all (enchantments.gd:111).
#  * the three class flags are the cause's class in Voxey's own consumers:
#    `Enchantments.protection` splits off `fall`, `fire`, `explosion` and
#    `projectile` (enchantments.gd:113-116) and `Shields.BLOCKABLE` blocks
#    `explosion` (shields.gd:34). Voxey carries no flag through `hurt`, so the
#    class is a property of the cause string.
#
# `fire` has no entry: the source table has no such reason, so there is nothing to
# compare it against. `generic` records its default (`bypass_armor` false), which
# is what the argument-less sites get; several sites pass true instead
# (adventure.gd:60, boats.gd:194, magic_projectile.gd:101, potion_effects.gd:19,
# potion_effects.gd:95), so a per-cause flag is only ever an approximation in a
# pipeline that decides mitigation per call.
const IMPLEMENTED = {
	"void": {"bypasses_armor":true,"bypasses_magic":true,"bypasses_totem":true},
	"starve": {"bypasses_armor":true,"bypasses_magic":true,"bypasses_totem":true},
	"fall": {"bypasses_armor":true,"bypasses_totem":true},
	"in_wall": {"bypasses_armor":true,"bypasses_totem":true},
	"freeze": {"bypasses_armor":true,"bypasses_totem":true},
	"hot_floor": {"bypasses_armor":true,"bypasses_totem":true},
	"sweet_berry": {},
	"explosion": {"is_explosion":true},
	"thorns": {"bypasses_armor":true,"bypasses_totem":true},
	"magic": {},
	"mob": {},
	"projectile": {"is_projectile":true},
	"anvil": {},
	"falling_node": {},
	"generic": {},
}

# The reason's source entry, following an alias when Voxey's name differs.
static func _source_reason(cause: String) -> String:
	return str(ALIASES.get(cause,cause))

# `@1`/`@2`/`@3`, with the source's item brackets (init.lua:151).
static func _fill(text: String, killer: String = "", item: String = "") -> String:
	return text.replace("@1",VICTIM).replace("@2",killer).replace("@3",item)

# The source's dispatch (init.lua:198-203): killer, then plain, then the fallback.
# The assist step is out of reach here because it needs the source's five-second
# per-object assist cache, which `hurt` does not carry.
static func message(reason: String, killer: String = "", item: String = "") -> String:
	var entry: Dictionary = MESSAGES.get(_source_reason(reason),{})
	if not killer.is_empty():
		if entry.has("item") and not item.is_empty():
			# The source brackets the item name (init.lua:151).
			return _fill(str(entry["item"]),killer,"["+item+"]")
		if entry.has("killer"):
			return _fill(str(entry["killer"]),killer)
	if entry.has("plain"):
		return _fill(str(entry["plain"]))
	# `entry` exists but its only form needs a killer, and none was supplied. The
	# source would emit its translation key here; a single-player screen with no
	# translator cannot, so the cause is named in prose instead.
	if not entry.is_empty(): return VICTIM+" "+_cause_label(reason)
	return FALLBACK_PREFIX+_source_reason(reason)+" "+VICTIM

# A readable name for a cause whose source entry has no killer-free form. Every cause
# Voxey passes that reaches this point is a projectile, an explosion or a mob hit.
static func _cause_label(reason: String) -> String:
	match _source_reason(reason):
		"arrow","projectile","trident": return "was shot"
		"fireball","wither_skull","dragon_breath": return "was struck by a projectile"
		"explosion","charged_explosion","fireworks": return "was blown up"
		"spit": return "was spitballed"
		"mob": return "was slain"
		"player": return "was slain in combat"
		"thorns": return "was killed by thorns"
	return "died"

# One dictionary per flag name, so a caller never has to test for a missing key.
static func _project(declared: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name in FLAG_NAMES:
		result[name] = bool(declared.get(name,false))
	return result

# The six flags the source classifies the reason by, all false when the reason
# declares none — or is not in the source's table at all.
static func flags(reason: String) -> Dictionary:
	return _project(DECLARED.get(_source_reason(reason),{}))

# Whether the source's table covers the reason, directly or through an alias.
static func known(reason: String) -> bool:
	return DECLARED.has(_source_reason(reason))

# Every reason the flag table covers, in the source's order.
static func causes() -> Array:
	return DECLARED.keys()

static func _same(left: Dictionary, right: Dictionary) -> bool:
	for name in FLAG_NAMES:
		if bool(left[name]) != bool(right[name]):
			return false
	return true

# Compare Voxey's causes against the source's table. A cause the table covers —
# `void` through `out_of_world`, for instance — lands in `known`; one it does not
# (`fire`, whose four source reasons Voxey merges) lands in `unknown`. A known
# cause whose implemented flags differ from the source's also lands in
# `mismatched`, with both flag sets, so `known` stays the answer to "is this a
# reason the source knows?" and `mismatched` the answer to "does Voxey agree?".
# A cause with no IMPLEMENTED entry is recognised but not compared.
static func audit(voxey_causes: Array) -> Dictionary:
	var result: Dictionary = {"known":[],"unknown":[],"mismatched":[]}
	for entry in voxey_causes:
		var cause: String = str(entry)
		var reason: String = _source_reason(cause)
		if not DECLARED.has(reason):
			result.unknown.append(cause)
			continue
		result.known.append(cause)
		if not IMPLEMENTED.has(cause):
			continue
		var voxey: Dictionary = _project(IMPLEMENTED[cause])
		var source: Dictionary = flags(reason)
		if not _same(voxey,source):
			result.mismatched.append({"cause":cause,"reason":reason,"voxey":voxey,"source":source})
	return result

# --- PARENT WIRING -------------------------------------------------------------
# Main owns these files. The exact lines to add:
#
# scripts/player.gd, `hurt()`, the last line (currently line 985):
#     if health <= 0: game.die(cause)
#
# scripts/game.gd, `die()`'s signature (currently line 952):
#     func die(reason: String = "generic") -> void:
#   and, immediately before `hud.show_death()` (currently line 975):
#     death_reason = reason
#
# scripts/game.gd, a new field beside `var world_name: String = "New world"` (line 68):
#     var death_reason: String = "generic"
#
# scripts/hud.gd, `show_death()`, replacing the static line (currently line 827):
#     _label(panel,DeathMessages.message(game.death_reason),Vector2(32,53),32)
#
# The killer and item arguments stay "" until a name is threaded through: Voxey's
# `hurt()` carries the attacker as a position, not a name, so naming one means
# looking the creature up at `source` (`Creature.custom_name` or the kind) and the
# item up from the killer's own held slot. Neither is needed for the message table
# to work, and `DeathMessages.message` treats both as optional.
