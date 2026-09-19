# Conduits and prismarine

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_conduits` and the prismarine half of `mods/ITEMS/mcl_ocean/prismarine.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## The conduit is an underwater beacon

The heart of the sea comes from [buried treasure](buried-treasure-source.md) or from [shipwrecks](shipwrecks-source.md), so a conduit is reachable by two independent routes.

Its whole mechanic is the source's `check_conduit`, which has three parts:

1. **Water.** The 3×3×3 volume around the conduit must contain enough water:

   ```lua
   if #water < 26 or (cname ~= "mcl_conduits:conduit" and #water < 27) then return false end
   ```

   A conduit still sitting as a **node** needs 26 water cells around it; once it has activated, its own cell turns to water and the requirement becomes all 27. Both thresholds are reproduced exactly.

2. **Frame.** The source lists **42 specific offset positions** and counts how many hold prismarine, prismarine bricks, dark prismarine or a sea lantern. Fewer than **16** and the conduit does not activate.

3. **Power.** The effective range is `floor(frame_count / 7) * 16`. A 16-block frame reaches 32 blocks, and a 21-block frame reaches 48.

## What an active conduit does

- **Conduit power** to players within its range, but only while they are in water — the source checks the feet node's water group first. Voxey applies the same 17-second `conduit_power` the source grants.
- **Damage** of 4 to hostile creatures in water within 9 blocks.
- It reverts to a plain node the moment its water or frame is broken, because the check simply fails on the next pass.

The source tracks active conduits as entities and re-checks every **5 seconds**; Voxey keeps that cadence over its registered conduit cells.

## Prismarine

The frame's materials, all craftable from prismarine shards:

| Block/Item | Recipe |
|---|---|
| Prismarine | 2×2 prismarine shards |
| Prismarine bricks | 3×3 prismarine shards |
| Dark prismarine | 3×3 shards around a black dye |
| Sea lantern | shards and crystals in the source's alternating pattern |
| Conduit | eight nautilus shells around a heart of the sea |

The conduit and sea lantern both light at the source maximum of 15.

## Recorded source gaps

- **Guardians now supply the frame materials.** The reference obtains prismarine shards and crystals from guardians, and [guardians](guardians-source.md) are implemented with the source's own drop table: shards always rolled over a 0-2 range, crystals one in four. With [buried treasure](buried-treasure-source.md) supplying the guaranteed heart of the sea and the nautilus shell already a fishing-treasure drop, the conduit and its frame are now reachable in survival.
- **The animated prismarine texture is drawn procedurally.** The source's prismarine cycles through 22 texture frames and its sea lantern through an animated frame set; Voxey draws both from its own pixel-sprite system, so the blocks do not visibly cycle colour.
- The source's conduit *entity* (a rotating mesh with an immortal armour group) is replaced by a node-driven timer. The visual result is a static conduit rather than a spinning one.
- Prismarine stairs, slabs and walls are not registered; Voxey's building-shape families are a separate system and are not extended here.
