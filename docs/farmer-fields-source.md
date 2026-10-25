# Farmer field activities

`FarmerFields` ports the field-work activity transitions from the supplied
Mineclonia checkout's `mods/ENTITIES/mobs_mc/villager.lua`. It integrates with
the existing source-backed crop/drop rules and [private villager inventories](composters-source.md).
See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

A farmer now harvests and plants in separate actions. Harvesting a mature wheat,
carrot, potato or beetroot plant leaves air and creates normal crop pickups.
It does not reserve a drop for automatic replanting. The farmer must collect
and carry an eligible seed item before a later action can plant it. Inventory
order selects between wheat seeds, potatoes, carrots and beetroot seeds. A
single item is consumed when planting; it is returned if the soil is no longer
farmland. Occupied or immature crop cells are not harvested or replaced.

The harvestable-field sensor searches at most two blocks horizontally and two
blocks below the farmer, through its current level. It shuffles the nearby
farmland and retains at most five cells whose upper nodes are mature crops or
air. The broader farmland movement sensor searches four blocks horizontally
and two vertically in either direction. The immature-crop sensor searches two
horizontally and one vertically in either direction, limited to the four crops
for which the source farmer carries seeds.

A field-work bout starts with a list of candidates, visits them from the end
of that list, and pauses for one second after each completed attempt. Navigation
must end within 1.75 blocks to allow an action. After ten seconds, the bout ends
when no target is currently being approached. Failed navigation preserves the
source return value and state; it does not silently count as a successful action.

Fertilizing is a separate activity. It needs carried bone meal and a valid
immature crop. A bout lasts less than four seconds, selects another crop after
its one-second cooldown, and applies bone meal only when navigation finishes
within 1.5 blocks. The source tests the plant callback for a true return value.
In particular, a beetroot no-growth roll leaves the farmer's bone meal intact,
even though the player-use wrapper consumes bone meal for that same nil return.

Workday activity selection uses the source weights for pacing, moving to
farmland, farming, fertilizing, visiting the workstation and working there:
2, 5, 2, 4, 5 and 7. Each priority is `-random^weight`, sorted ascending. A newly
started activity keeps control until completion, while the order for the next
choice is refreshed. An already-running activity that is reconsidered through
the dispatch list retains the source's interruptible behavior. The existing
workstation task now runs through this dispatcher instead of competing with
field work from a separate half-second update.

Night, a nearby threat, an invalid workstation, a lead, or childhood prevents
adult work from starting. Private inventory contents persist; active field
lists, navigation state and work timers do not. The obsolete random
harvest-and-immediate-replant routine and fixed field destination were removed.

## Native adaptations and remaining work

The high-level activity transitions, inventory actions and ordering follow the
reference. Movement uses Voxey's existing bounded voxel routes, with loaded
geometry and a small vertical offset to route correctly over lowered farmland.
Navigation completion and obstruction handling therefore remain native rather
than matching the entire Mineclonia pathfinder. Pacing-target sampling and the
native workday/threat schedule are also adaptations. Full source schedules,
path costs and complete social activities remain open. [Food sharing and
inventory-based breeding](villager-social-source.md) are covered by a later batch. The current native world has no area-protection service or villager
mob-griefing rule; those global systems are not inferred from this module.

## Verification

`tools/export_farmer_fields_reference.py` invokes the real source `farm`,
`fertilize_farmland` and `get_farmable_seed` callbacks in a Luanti world. It also
extracts and executes the source's local weighted-order function. The fixture
contains 576 farm transitions, 576 fertilizer transitions, 108 seed selections
and 100 weighted orders, with source hashes. `tests/farmer_fields_reference_checks.gd`
compares all 1,360 cases, including timer and reach boundaries, empty sensors,
failed paths, existing targets and successful/unsuccessful fertilizer callbacks.

`tests/farmer_fields_checks.gd` checks real crop removal and pickups, inventory
seed use and return, occupied cells, bone-meal consumption, sensor limits,
the complete harvest/pickup/replant loop, and adult/daytime restrictions.

Validation on 2026-10-24: all 1,360 source cases pass. The combined field,
workstation, composter, zombie-target and zombie-villager integration run passes
142 checks; village and alchemy regressions pass another 903 and 239. A final
63-check focused run verifies the current activity dispatcher. The earlier
composter fixture remains green (1,536 transaction/geometry cases and 2,333 item
mappings). The field preview was rendered and reviewed, and the Linux pack
exports successfully. All three field-reference source hashes match the
supplied checkout. These results do not close the broader Mineclonia goal.
