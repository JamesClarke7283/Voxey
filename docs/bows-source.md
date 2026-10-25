# Bow drawing and release

The reference is the installed Mineclonia checkout at
`/home/impulse/.minetest/games/mineclonia`, particularly
`mods/ITEMS/mcl_bows/bow.lua`, `arrow.lua`, `mods/CORE/mcl_util/misc.lua`
and its movement settings. This work follows the repository's existing
[Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

`BowUse` now replaces the instant-click shot. Hold right-click, Z or touch Use
to draw and release to fire. Initial block interactions, such as opening a
chest, retain priority. While drawing, the bow suppresses mining and further
block interactions. The original Voxey artwork has three distinct pull sprites
in both the hand and selected inventory slot.

- Pull stages change at 200,000 and 500,000 microseconds. Speed rises linearly
  from zero to 60 nodes/second over 500,000 microseconds and then stays capped.
  Every full-charge shot is critical; this follows the executable source rather
  than its older item help text.
- A zero-duration release still shoots, consumes ammunition and wears the bow.
  The projectile starts at eye position minus 0.1 vertically. Each direction
  component receives independent triangular noise of magnitude 0.0172275,
  without renormalization.
- Drawing multiplies movement by `1.295 / 4.317`, taken from the reference's
  settings, and normal/sprint FOV by 0.8. Creative flight also slows.
- The first usable arrow in the main inventory is selected. Offhand arrows do
  not qualify. Infinity requires ammunition and preserves ordinary arrows;
  tipped arrows are consumed. Creative can shoot without ammunition and spends
  neither ammunition nor durability. Pickup eligibility is `not Infinity`,
  including tipped arrows and creative shots.
- Base damage is 2, Power adds `level / 2 + 0.5`, and Punch/Flame reach the
  projectile. [Shield/projectile rules](shields-source.md) handle speed-scaled
  impact damage, critical bonuses and deflection.
- Successful survival shots add `floor(65535 / (385 * (Unbreaking + 1)))`
  normalized wear. This is the source's manual `add_wear` path, distinct from
  its remainder-distributing `add_wear_by_uses` path. Metadata is retained.
- Releasing either RMB or Z fires even when the other remains held. Switching
  slots or replacing/removing the bow cancels the pull. Drops, menus, death and
  world loads cancel it too. Native pull state is transient player state and
  is never serialized into the item. A multiplayer inventory replacement also
  cancels the local pull rather than transferring it to another stack.

`python3 tools/export_bow_reference.py` creates a temporary, localhost Luanti
server and invokes the actual source shooting functions for 2,304 combinations
of charge, ammunition, Infinity, Power, Unbreaking, creative mode and existing
wear. A deterministic replacement for the RNG's sample stream makes spread
comparable while preserving the source distribution function. The fixture
replaces only engine player/entity boundaries, records source SHA-256 hashes,
and writes `assets/data/bow_reference.json`.

Run `tests/bow_reference_checks.gd` for the source comparison and the `bow`
lifecycle group for live controls, transactions, cancellation, movement/FOV,
and hand/hotbar visuals. `tests/bow_tour.gd` renders the four original sprites.

Validation on 2026-10-24: all 2,304 source cases, 129 combined bow/projectile/
spyglass integration checks and 534 survival checks passed. Headless import,
Linux export and visual inspection of the hand, hotbar and four sprites passed.

[Crossbow draw/loading, Multishot and its projectile trajectory](crossbows-source.md)
now have their own source comparison. [Arrow flight, impact and recovery](arrow-flight-source.md) now have their own
comparison. Full knockback and remote projectile synchronization remain open. The three pull states use elapsed-time thresholds
directly; the source's sequential callbacks can show an intermediate sprite
for one callback after an unusually long frame.

[Skeleton and stray bow combat](mob-bows-source.md) now has its own source
comparison for NPC drawing, strafing, firing, equipment and kill callbacks.
