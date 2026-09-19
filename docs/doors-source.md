# Paired doors

Reference: `mods/ITEMS/mcl_doors/api_doors.lua`, `register.lua`, and the door
registration in `mods/ITEMS/mcl_trees/api.lua` in the supplied Mineclonia
checkout. The gameplay translation is GPL-3.0-or-later; the procedural panel
and handle artwork is original to Voxey.

Oak keeps inventory ID549 and iron keeps228. Spruce, birch, jungle, acacia and
dark oak use6200–6204. Placed states6300–6523 encode four directions, mirrored
hinges, open/closed and upper/lower halves. Only canonical inventory items are
listed in the creative catalogue. Each six-plank species recipe produces
three matching doors; six iron ingots produce three iron doors.

Placement requires two replaceable cells and checks player overlap. The
source has no attached-ground requirement, so removing the floor does not
destroy a door. Placing the same door beside its source-left neighbor creates
the mirrored hinge and copies its current orientation. Both halves retain a
3/16-block collision and selection panel, including when open.

Right-clicking either wooden half toggles both. Ctrl/touch sneak permits
ordinary held-item use. Iron doors require redstone. Power from either half
is combined and a changed strength opens or closes both halves. Manually
overriding a powered wooden door persists until its input strength changes.
Removing either half by mining, piston destruction or explosion removes its
matching partner once. Mining respects the current wood/iron tool rules and
produces one canonical door. Wooden doors burn for ten seconds as fuel, but
retain the source's nonflammable world-node setting.

Old saved oak/iron nodes are migrated on column reconciliation or interaction,
retaining saved orientation, upper-half and power state. Migration replaces
only halves that actually exist. Current states and power metadata survive
ordinary saves and streaming.
Legacy iron directions are interpreted using the old centered renderer's
front (`-Z` rotated by `atan2(-dir.x,-dir.z)`), then placed on the matching
edge of the new source panel. This mapping differs from the source's new
placement rule, which faces the player. All four saved directions are checked
in both open and closed states against the actual old renderer and through
real old-save loading; `dir`, `upper`, and `powered` metadata are preserved.

Voxey's movement solver additionally performs bounded collision recovery when
a panel rotates into a player, mob or boat. It selects the shortest clear face
projection, checking loaded terrain and the whole swept body against nearby
walls. Both halves are treated as one panel. Fully enclosed actors are kept
in place rather than moved through walls. This compensates for collision
recovery that Luanti supplies at engine level.

Focused checks are in `tests/door_checks.gd`; wood-material crafting checks
are in `tests/wood_crafting_checks.gd`. Wind-charge callbacks, additional wood
families and exact upstream textures/sounds remain outside this batch.

Canonical held and dropped door items render both halves together in a thin, scaled model, using the same species texture as the placed door. The home/wood regression run passed all 3,010 checks with no script errors; source-oriented door checks are part of its 1,508 lifecycle checks.
