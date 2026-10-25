# Furnace cooking, fuels and inventories

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
Source-derived rules retain GPL-3.0-or-later attribution.

`FurnaceRules` uses the loaded game's recipe registry and ports the actual
`mcl_furnaces.get_timer_function`. `tools/export_furnace_reference.py` records
1,355 native item bindings, including 156 cooking inputs and 288 fuels. The
registry contains 1,612 relevant source definitions and 70 source-file hashes.
The exporter invokes real Luanti crafting, inventory and timer functions.

## Cooking and fuel

Registered recipes supply their output, quantity and cooking duration. Current
mapped recipes take ten seconds in an ordinary furnace. Smokers and blast
furnaces use their input groups, cook twice as fast and consume fuel twice as
fast. The old output-based whitelist excluded valid coal ore and equipment;
the source group checks now admit them. Wood tools, bows, slabs and other
registered fuels use their actual burn times, including 7.5 seconds for a
wooden slab (the exported JSON truncates this to 7, so the native exact value
wins for fueled half slabs).

Changing the input item resets its progress. Blocked output preserves progress
while burning fuel continues to expire. Exhausting the fuel with cookable input
resets progress, matching the source. Empty furnaces can keep burning existing
fuel. The first callback that loads new fuel advances cooking without charging
that callback's elapsed time to the new fuel; this source behavior is retained.
Long callbacks can finish multiple items and move between fuel stacks.

Lava fuel returns an empty bucket. Drying a wet sponge fills an empty bucket in
the fuel slot. The native river sponge still returns the ordinary water bucket,
because the existing native fluid system represents one water type.

Game-time callbacks retain the source's initial 0.1-second interval, repeated
timestamp handling, backward time changes and the 1.5-second interaction-reset
boundary. The real world tick reads the saved game clock, which also advances
while a furnace inventory is open. There is no wall-clock/offline progression.
Test-driven `_simulate()` calls retain explicit one-second intervals.

Saved stations retain exact fuel elapsed/total time, input identity, cooking
progress, active state and XP. Existing `burn` and `progress` fields remain
compatible: legacy fuel is migrated on first use, and direct legacy edits to
remaining fuel invalidate its derived checkpoint.

## Inventory and UI

Manual input slots accept ordinary items even when they cannot be cooked or the
output is occupied. Output slots reject insertion. The fuel callback permits
one empty bucket and limits direct insertion of replacement fuels such as lava
buckets. Quick-move follows the separate source sorter: cookable fuel goes to
input first, or to fuel if the input cannot fit the stack. The source sorter can
preserve an existing overstack in an empty destination, including lava buckets;
it does not silently reuse the stricter manual-placement rule.

Top hoppers can insert any source item, independently of output occupancy.
Side hoppers accept fuel and do not stack lava replacement containers. Droppers,
the inventory UI and network station transactions use the same rules. Any
withdrawal from output awards the whole stored XP count once. Guest withdrawals
credit the guest rather than the host and survive the existing inventory sync.
Inventory XP awards also run Mending before crediting the remaining experience.

The furnace screen lists eligible cooking recipes and registered fuels for its
device. Selecting an entry shows its result and time, with fuel duration
adjusted for fast furnaces. The display uses the current recipe duration for
progress. Active furnaces emit level-13 light from saved active state.

Two missing outputs are now real blocks: smooth stone (11597) and smooth
sandstone (11598), with source hardness and blast resistance. The blast-furnace
recipe requires three smooth-stone blocks. Their stair/slab families are now included in the [shape registry](shape-registry-source.md).

## Verification and remaining differences

`tests/furnace_reference_checks.gd` passes 40,615 comparisons: all bound recipes,
fuels and device groups, 525 timer sequences, 8,130 insertion rows, 60 sorter
cases and 84 game-clock observations. Cases include output limits, metadata
state, fuel replacement, switching input, partial fuel, multiple completions,
creative-independent cooking and forward/backward clock changes.

`tests/furnace_checks.gd` covers actual world ticks, UI insertion and guide
filtering, light, clock advancement, hopper input, XP and real save/reload.
`tests/network_runner.gd` checks partial guest withdrawal and prevents duplicate
XP. Full-size and compact recipe/fuel screens are reproduced by
`tests/furnace_tour.gd` and were visually reviewed.

Final validation on 2026-10-24: all 40,615 source comparisons pass. The combined
furnace/copper/light/sponge/wood run passes 805 checks; the furnace-Mending and
XP-orb run passes 99. The complete survival runner passes 535, village 906,
alchemy 239, steam 141 and the freed-zombie-target regression 39. Network
protocol, host and guest suites report zero failures, including partial furnace
XP withdrawal and reconnection. All 70 recorded source hashes match the supplied
checkout. The final Linux pack exports without script errors.

Items without a mapped source identity retain native recipes and fuel behavior;
this includes the old generic meat item, alongside the source-mapped beef and
other meats. Furnace blocks retain the native mesh/face presentation rather
than the source's separate animated active-node textures and sounds. General
container directionality, remaining material families and wider game parity
remain separate work in [the parity ledger](mineclonia-parity.md).
