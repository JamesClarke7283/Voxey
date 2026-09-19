# The Wither

Voxey follows the supplied Mineclonia `mods/ENTITIES/mobs_mc/wither.lua` and `mods/ENTITIES/mcl_wither_spawning/init.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or mesh is copied.

## Why it mattered

The wither is the last missing link in the beacon's survival route. [Beacons](beacons-source.md) recorded the nether star as their one absent ingredient, and the star comes only from the wither. Summoning the boss closes that dependency.

## The summoning ritual

A **three-wide T of soul sand** with a **wither skeleton skull on each of its three upper cells**. The source stores the seven required cells in a schematic file and checks every one before consuming the blocks.

| Cell | Required |
|---|---|
| `(1,0,0)` | soul block |
| `(0,1,0)`, `(1,1,0)`, `(2,1,0)` | soul block |
| `(0,2,0)`, `(1,2,0)`, `(2,2,0)` | wither skeleton skull |

The source ships **two** schematics — one running along x and one along z — and accepts either orientation. Both are reproduced, and every one of the seven cells must match: a single missing skull or a stone block under a skull breaks the ritual, which the checks verify.

Placing a wither skull on a soul block attempts the ritual, matching the source's item override and its `core.after(0, ...)` deferral. Soul sand and soul soil both count, as the source's `soul_block` group covers both.

## The boss

| Property | Value |
|---|---|
| Health | 600, scaled by difficulty: easy 0.5, normal 0.75, hard 1.0 |
| Opening phase | 10 seconds, **invulnerable** |
| Phase 2 | at half health: armoured, **arrow-immune**, half firing rate |
| Drop | one **nether star**, guaranteed |
| Movement | flies, never despawns |

The invulnerable opening phase is the source's `_spawning = 10`, during which the boss rises and cannot be hurt. The armoured phase is entered below half health, exactly as `wither_register_damage` switches its phase.

## Recorded source gaps

- **No wither skull projectile.** The source fires `mobs_mc:wither_skull` entities and makes every fourth one blue; Voxey's ranged attack deals its damage directly.
- **No block destruction.** The reference destroys blocks in response to damage and on death; Voxey does neither, so the boss does not scar the terrain.
- **No descending skeleton release.** The source spawns four wither skeletons as the boss reaches the ground; Voxey registers the skeleton creature but does not release it on descent.
- **No boss health bar.** The source drives `mcl_bossbars`; Voxey has no boss bar.
- **No wither-effect aura.** The reference applies the withering effect to nearby players; Voxey's potion catalog has the effect but the aura is not wired.
- **Difficulty is a new field.** Voxey had no difficulty setting, so one was added with the source's three-tier health factors. It is not yet exposed in any menu.
