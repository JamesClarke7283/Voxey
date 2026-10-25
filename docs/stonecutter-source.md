# Stonecutter

Reference: `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_stonecutter/init.lua`,
inspected 2026-10-24. Source-derived behavior retains GPL-3.0-or-later attribution.
Artwork and interface are native.

The stonecutter now has a real input slot, selectable cuts and a virtual output
slot. The old menu of immediate inventory exchanges is removed. Its registered
recipe table contains all 90 source inputs and 349 conversions, including the
preserved copper variants. Every output has a native item binding.

## Recipe filtering and yields

The loaded game includes a conversion only when the input has `stonecuttable`
and the output is visible in the creative catalog. A declared
`_mcl_stonecutter_recipes` list alone is insufficient. For example, resin brick
and resin-brick block fail the source input-group filter, so their declared
conversions are unavailable. This corrects the older direct-exchange menu.

Yield comes from the result's groups: slabs yield two, cut-copper blocks and
copper grates yield four, and ordinary results yield one. These multipliers are
applied exactly as registered; cut-copper slabs in this checkout yield two.
Waxed inputs produce waxed output, preserving the native `copper_waxed` metadata.
Native IDs which name the same source block share the same recipes.

## Inventory behavior

Selecting a cut initially previews one batch. Selecting the same result again
adds a batch, bounded by available input and the output stack limit. Fill Output
previews as much as the input can make, up to the output's maximum stack.
Selection never consumes material.

Taking output consumes `ceil(taken / yield)` input items and clears the remaining
preview. A partial batch therefore consumes a whole input item. Input changes
and reopening the workstation also clear the preview. Any normal item may be
stored in the input slot, but only registered materials offer cuts. Nothing can
be inserted into the output slot.

The input, output preview and facing survive saves. Breaking the workstation
drops its real input and the stonecutter item; it never drops a second copy of
the virtual output. The source does not mark this workstation as a hopper
container, so it is excluded from hopper insertion/extraction and comparator
container fullness. It remains the mason's jobsite in all 24 orientations.

Guests use server-owned slots, recipe validation and output withdrawal. The
server computes consumption and returns the resulting inventory. Selecting an
arbitrary result cannot create an unregistered conversion.

## Shape and verification

The base is 9/16 of a block high and provides all collision. The saw is a thin,
non-colliding plane above it, with original animated teeth. All 24 source
orientations are represented, using existing ID 524 and hidden
states 15300–15323 (excluding texture-only 15303). The source screwdriver
rotation table and actual engine boxes define those states. Every form drops
the canonical item.

`tools/export_stonecutter_reference.py` runs the real source callbacks and
records its filtered recipe table, protected-input permissions and inventory
sequences. `stonecutting_reference_checks.gd` compares all conversions and
selection/fill/partial-take/refresh sequences. Live tests exercise the actual UI,
virtual-output protection, wax, collision, save/reload and destruction. Network
tests exercise recipe selection and partial output withdrawal by a guest.

The UI and procedural artwork are adaptations. Protected-area enforcement
depends on the broader world permission system.

Validation on 2026-10-24: all 1,049 source comparisons pass, including the 90
input tables, 349 conversions, 30 inventory traces and 24 orientations. All 18
reference source hashes match. The 19 focused lifecycle checks, 143 combined
stonecutter/barrier/furnace/piston checks and 535 survival checks pass. Network
protocol, host and guest tests report no failures. Visual review covers the
rotated workshop, waxed-copper output, compact interface and unavailable input.
The Linux resource pack exports successfully.
