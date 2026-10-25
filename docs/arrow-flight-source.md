# Arrow flight, impacts and recovery

This batch follows the installed
`/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_bows/arrow.lua`.
See the existing [GPL attribution](licenses/Mineclonia-GPL-3.0.txt),
[bow](bows-source.md), [crossbow](crossbows-source.md) and
[shield](shields-source.md) comparisons.

The previous native arrow had a 30-second flight limit, ten-minute embedded
lifetime, no drag or liquid traversal, and no stored support block. It now uses
the source's state transitions:

- Flight expires after 120 seconds, embedded arrows after 60, and arrows
  attached to a struck player after 30. The boundary is strictly greater than
  the limit. Menus and inactive dimensions retain Voxey's paused-time behavior.
- Drag multiplies all three velocity components by 0.99 every 0.05 seconds,
  including multiple ticks in one frame. Gravity remains 9.81.
- Crossing a liquid voxel multiplies velocity by 0.74. Each voxel is processed
  only once until an embedded arrow is released. Water extinguishes arrows;
  lava and fire ignite them, and exposed rain extinguishes them.
- Swept box intersections order block and actor hits. A forward 0.05-second
  prediction handles actors and liquids, but stops at a solid barrier instead
  of damaging through it. Native voxel collision boxes supply the geometry.
- A block impact places the arrow 0.15 blocks into the impact direction, clears
  velocity, critical state and Piercing, records the support voxel, and starts
  a short visual shake. Burning impacts activate TNT, campfires and candles;
  the existing target and wooden-button hooks still receive the impact.
- Embedded arrows check for pickup or missing support every 0.25 seconds.
  Only replacing support with air releases an arrow; replacing it with another
  node retains it, matching the source's explicit test. Released arrows fall
  and restart their flight lifetime and drag clock.
- A collectible arrow within two blocks of a player's position becomes a
  stationary item with immediate pickup eligibility, even if the inventory is
  full. Creative removes the arrow without creating an item. Ammunition type
  and metadata survive the conversion. Normal item collection and capacity
  rules apply to the resulting drop.
- A non-piercing hit attaches the visual arrow to the player. It follows body
  movement/turning, expires after thirty seconds, and is removed on respawn.
  Endermen are excluded from ordinary arrow damage, as in the source callback.

Arrow saves now contain flying as well as embedded arrows: velocity, age, drag
clock, damage, critical/Flame/Punch/Piercing state, origin, shooter provenance,
item metadata and embedded support. Attached visual arrows are omitted, as the
source deletes them on reactivation. Restoring an arrow is silent. Legacy
ten-minute embedded ages are divided by ten to preserve their elapsed fraction
under the one-minute rule. Older saves lack a support voxel and retain pickup
and expiry behavior until those arrows are gone.

`tools/export_arrow_flight_reference.py` runs the installed callbacks in a
temporary Luanti world. The fixture supplies engine object/world boundaries;
it does not replace the arrow's state logic. It records twelve drag sequences,
ten liquid/fire sequences, fifteen support/lifetime states, and eight pickup
cases. `tests/arrow_flight_reference_checks.gd` compares these 45 scenarios.
The `arrow_flight` lifecycle group additionally exercises real voxel sweeps,
prediction barriers, burning block impacts, recovery with a full inventory,
attachments, and actual save/reload of both flight and embedded states.

Validation on 2026-10-24: all 45 reference scenarios, 804 shield-combat
comparisons, 271 flight/bow/sensor/candle checks, 71 Nether checks and 534
survival checks passed. Import, Linux export and visual inspection passed.

Native adaptations remain explicit: motion integration uses Godot's physics
step and native collision geometry rather than Luanti's C++ movement solver.
Player attachment placement uses the native body's hit position rather than
the source character's named skeletal bones. Original critical/fire particles
and impact shake use native graphics. Existing gunshot and incoming-trident
adapters retain their separate physics. [Pillager crossbow combat](mob-crossbows-source.md)
has a subsequent source comparison. Complete mob projectile knockback and
remote projectile synchronization remain open.
