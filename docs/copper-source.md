# Copper

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_copper/` (`init.lua`, `nodes.lua`, `items.lua`, `crafting.lua`, `decaychains.lua`) and `mods/ITEMS/mcl_lightning_rods/init.lua`. The implementation is original GDScript using the source as a behavioral reference; all art is original procedural code.

## Oxidation

Every copper block has four stages: unaffected, exposed, weathered, oxidized. One active sweep covers them all and mirrors the source's single ABM: a 500-second interval with a 1-in-3 chance per node, so a given block advances at most one stage per roll and averages one stage per 25 active minutes. There is no exposure condition — buried copper oxidizes exactly like exposed copper — and there is no random-tick path.

Waxing freezes a block permanently. Source models this with a separate `_preserved` node per stage; Voxey stores a `copper_waxed` flag in the block's saved metadata instead, so one id covers both states. The flag also travels with the item: breaking a waxed block drops a waxed item, and placing that item restores the flag on the new block. A waxed block is skipped by the oxidation sweep, is not scraped by lightning, and keeps its flag through a save.

An axe is the only tool that reverses oxidation, and each use is exactly one action:

| Block state | Axe result |
| --- | --- |
| Waxed, any stage | Wax removed, stage unchanged |
| Unwaxed, exposed or worse | Exactly one stage reversed |
| Unwaxed, pristine | Nothing happens; the axe is not worn |

Use honeycomb while sneaking on a placed copper block to wax it in place; one honeycomb is consumed in survival. Waxing by crafting — base block plus one honeycomb — is also registered for each block form, as in the source.

## Blocks

| Family | Stages | Notes |
| --- | --- | --- |
| Block of copper | 4 | Smelts back into nine ingots; only the pristine stage converts, as in source |
| Cut copper | 4 | Also provides stairs and slabs through the shared shape families |
| Chiseled copper | 4 | Crafted from two cut copper slabs |
| Copper grate | 4 | Open lattice with alpha-clipped holes; not a solid cube |
| Copper bulb | 8 | Lit and unlit per stage |
| Lightning rod | 8 | Unpowered and powered per stage |
| Copper door | 4 | Reuses the classic two-block door family |
| Copper trapdoor | 4 | Reuses the classic sixteen-state trapdoor family |

Cut copper stairs and slabs are ordinary members of the shared building-shape materials, so they inherit placement, corner resolution, collision and crafting, and oxidation moves a stair between the four cut copper families while keeping its facing.

Copper doors are hand-openable — the source sets the `door_iron` group for mob pathfinding but does not set `only_redstone_can_open` — and both halves oxidize together: only the bottom half is processed, and the top half is swapped in step.

## Bulbs

A bulb toggles its lit state on each rising redstone edge and remembers it after power is removed, so holding power does not re-toggle. A lit bulb lights its stage's level (14, 12, 8 or 4) and reports 15 to a comparator; an unlit bulb reports 0. A bulb emits no redstone power to its neighbours. Breaking one always returns its unlit item.

## Lightning rods

A rod mounts on any solid neighbour face. A strike powers the first rod in source scan order — not the nearest one — within 64 blocks horizontally and from 32 below to 64 above, and only if that rod has air directly above it. The powered rod emits a strong 15 in every direction for four redstone ticks, then reverts.

Powered rods are absent from every oxidation chain, so a powered rod cannot oxidize, be waxed, or be scraped, exactly as in the source.

## Verification

`godot --headless --path . --script res://tests/lifecycle_runner.gd -- copper`

The fixture exercises stage resolution for all eight chains, the one-stage-per-roll limit and the terminal oxidized stage, wax persistence across many rolls, both axe rules and the pristine no-op, bulb edge-toggling and the remembered lit state, rod strike and revert, rod support loss, door two-half synchronization, trapdoor facing retention, wax travelling through a break-and-replace cycle, and a real save/reload of an oxidized waxed block. It also checks every recipe yield and grid, that every copper node builds a non-empty mesh with a valid inventory icon, and that the grate texture keeps its holes. Final focused result: **95 passed, 0 failed**.

Full regression: `./tests/run_tests.sh` passes **4,919 checks across nine suites** with no failures and no script diagnostics.

## Remaining differences

- **Wax and oxidation are metadata, not node names.** Source registers a distinct `_preserved` node per stage and kind (108 of them). Voxey keeps one id per stage and stores the flag, which is why a waxed block's item keeps its flag through inventory moves. Behaviour is equivalent; the registry is smaller.
- **No river water.** Source distinguishes river-waterlogged from waterlogged sponges and registers separate copper decay chains for river variants. Voxey has one water fluid, so only the ordinary chains exist.
- **Copper lanterns, chains, bars and the copper torch are absent.** Those nodes are registered by `mcl_lanterns`, `mcl_panes` and `mcl_torches` in the source rather than by `mcl_copper`, so they belong to those modules' batches.
- **`mcl_copper:block_raw` and ore processing are unchanged.** Voxey already had copper ore, ingot and block; the source's raw-copper storage block is not part of this batch.
- **Source gap carried over.** The `affected_by_lightning` group is only ever set to 0 in the checkout — and only on the preserved variants, which also clear their `_on_lightning_strike` callback. Because a group filter matches on key presence, the callback registered on exposed, weathered and oxidized cut copper stairs and slabs is unreachable there. Voxey implements the callback for the ids that carry it and does not pretend the group is reachable.
- **Weather-driven lightning is wired.** `Weather` schedules strikes while thundering and calls `Copper.strike_rod` for rod attraction and `Copper.lightning_strike` for cut copper de-oxidation. See [weather rules](weather-source.md).
- **Fully oxidized copper is a distinct block, not a texture variant.** Source behaves the same way, so this is parity rather than a difference; it is noted because it means oxidation cannot be reversed by any crafting recipe.
