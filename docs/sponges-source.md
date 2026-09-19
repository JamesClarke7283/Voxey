# Sponges

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_sponges/init.lua`. The implementation is original GDScript using the source as a behavioral reference; all art is original procedural code.

## Absorption

Absorbing scans the inclusive 7×7×7 cube centred on the sponge — 343 cells, of which the sponge itself occupies the centre, so 342 can ever hold water — and removes every water node it finds. There is no partial or gradual absorption: one successful pass clears the whole volume.

Source counts river water separately from normal water and produces the river-waterlogged variant only when river water *strictly* outnumbers normal water, so a tie favours ordinary water. Voxey has a single water fluid and no node carrying the source's river-water group, so `Sponges.river_water` always answers false and the river variant is registered for save compatibility but is unreachable. That is recorded rather than faked: the source could not produce it here either.

## Placement and drying

| Action | Result |
| --- | --- |
| Dry sponge placed into or beside water | Absorbs first, places the wet variant, consumes one sponge |
| Dry sponge placed away from water | Plain sponge |
| Wet sponge placed in the Nether | Dries instantly into a plain sponge, no bucket produced |
| Wet sponge smelted | Plain sponge |
| Wet sponge smelted with an empty bucket in the fuel slot | Plain sponge, and the bucket becomes a water bucket |
| Any variant broken | Drops a plain sponge |

Absorption on placement reaches one node in every direction, matching the source's proximity check, so a sponge dropped beside a stream clears it.

## The active sweep

One sweep visits every tracked dry sponge once per second, exactly the source's interval-1, chance-1 ABM. A sponge that gains an adjacent water node — from a flow, a bucket, or a neighbour's removal — is converted on the next pass. A converted node leaves the tracking index, since the source registers no ABM for the wet variants.

The index is per loaded column: unloading a column removes its sponges from simulation, and reloading it restores each exactly once without duplicating entries. Wet and dry state persists through saves because it is a node id, not metadata.

## Verification

`godot --headless --path . --script res://tests/lifecycle_runner.gd -- sponge`

The fixture checks the exact 342-cell absorption volume against a 9×9×9 water body, that water outside the volume survives, that an empty region absorbs nothing, the tie-break rule, immediate absorption on placement with the correct item cost in both survival and creative, the Nether drying rule against the same placement outside the Nether, the one-second sweep converting a sponge that gains adjacent water and retiring it from the index, furnace drying with and without an empty bucket in the fuel slot, a save round trip, unload and reload of the tracking index without duplication, and that both variants build a mesh, produce an inventory icon and render visibly different textures. Final focused result: **37 passed, 0 failed**.

## Remaining differences

- **The elder guardian now supplies wet sponges.** The checkout registers no crafting recipe for a dry sponge; its sources are an elder guardian drop and an ocean monument room. [Guardians](guardians-source.md) are now implemented, and an elder guardian **always drops one wet sponge**, which smelts into a dry sponge. The monument room remains absent, so guardians spawn in open ocean water instead, but the sponge's survival route is closed.
- **Ocean monuments are still absent.** In the reference they are where guardians concentrate and where sponge rooms generate. Voxey spawns guardians in deep ocean water, which gives the same materials without the structure.
- **No river-waterlogged variant.** Voxey has one water fluid, so the source's river-water distinction has nothing to attach to. The variant is registered so saves and ids stay stable.
- **The bucket replacement lives in the furnace tick, not in a generic replacement table.** Source expresses it as `_mcl_cooking_replacements` metadata consumed by its shared furnace; Voxey's furnace owns its slots directly, so the rule is applied there and exposed through `Sponges.cooking_replacement` for testing.
- **Absorption is not protection- or region-aware.** Source checks construction protection before placing; Voxey is single-player and has no protection system, so there is nothing to consult.
- **Sponges do not absorb flowing water progressively.** They remove flowing and source water alike in one pass, which is what the source's `group:water` scan does; there is no distinct behaviour for flowing versus source nodes to reproduce.
