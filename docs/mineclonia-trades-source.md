# Mineclonia trading reference

Voxey's `scripts/village_trades.gd` adapts all 297 trade definitions in the user's local Mineclonia checkout, `mods/ENTITIES/mobs_mc/villager.lua`, rechecked on 2026-10-24. Attribution: the Mineclonia / mobs_mc contributors. The adapted data is licensed under GPL version 3; see [the complete license](licenses/Mineclonia-GPL-3.0.txt). The adaptation converts Lua item names into stable Voxey IDs and materializes the two candle colors.

Source SHA-256: `51d8e9701bea0c8cf5eedbb0f8e01f6f281439f8e91c7a2b344937ea697079aa`.

The reference includes thirteen professions and five tiers. It enables every offer in an unlocked tier. Quantities, price ranges, stock, XP and multipliers are compared against the real Lua table, including two-input trades. In this checkout, the cleric's rotten-flesh trade grants twelve villager XP.

[The trade lifecycle notes](villager-trading-source.md) describe delayed promotion, source enchanting, price refresh callbacks, restock boundaries, migration and persistence. [Typed gossip](villager-gossip-source.md) supplies trading memories, hurt and murder penalties, cure rewards and price arithmetic. Complete village schedules and navigation remain open.

Village layouts are original deterministic structures sized for Voxey's terrain. The reference for workplace assignments, houses, beds and paths was `mods/MAPGEN/mcl_villages/` and the profession definitions in `villager.lua`. No upstream textures, meshes or village schematics were imported.

Swamp and underground slime rules were checked in `mods/ENTITIES/mobs_mc/slime+magma_cube.lua` and `mods/MAPGEN/mcl_biome_dispatch/init.lua`: roughly one tenth of 16×16 chunks, underground below Y -24 regardless of light, and swamp surface spawning in darkness with moon-phase weighting. Voxey uses its own seeded chunk hash and surface height because its terrain coordinates differ.
