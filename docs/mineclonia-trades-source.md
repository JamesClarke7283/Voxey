# Mineclonia trading reference

Voxey's `scripts/village_trades.gd` adapts the 297 trade definitions in the user's local Mineclonia checkout, `mods/ENTITIES/mobs_mc/villager.lua`, read on 2026-09-07. Attribution: the Mineclonia / mobs_mc contributors. This adapted data is licensed under GPL version 3; see [the complete license](licenses/Mineclonia-GPL-3.0.txt). The adaptation converts the Lua item names into stable Voxey IDs and materializes candle colors. The GDScript simulation and procedural visuals were implemented for Voxey.

Source SHA-256: `692674eb05094e20a02f7e53f3cc6f99f03d6f1781ad2010cb5abea29d65e7f6`.

The reference includes all 13 professions and all five tiers. It unlocks **every** offer in a tier, rather than choosing two. We retain the source input and output quantities, randomized price ranges, stock limits, villager XP, default 0.05 and equipment 0.2 price multipliers, and level thresholds 0/10/70/150/250. Two-input offers are preserved. In this checkout, the cleric's rotten-flesh offer gives 12 villager XP.

Voxey gives 4–6 player XP per trade and five additional XP on level-up. Work restores stock twice per day, with over 120 active seconds before a second restock and a 600-second fallback to a new working day. Demand is adjusted by `2 * uses - stock`. Reputation is stored per session player identity (`player` offline), with trading discounts and penalties for hitting villagers. Voxey also has a three-wave pillager raid and Hero of the Village discounts; multiplayer gossip and zombie curing are not implemented. Enchanted offers draw from the full enchantment catalog, respecting equipment compatibility and source maximum levels.

Village layouts are original deterministic structures sized for Voxey's terrain. The reference for workplace assignments, houses, beds and paths was `mods/MAPGEN/mcl_villages/` and the profession definitions in `villager.lua`. No upstream textures, meshes or village schematics were imported.

Swamp and underground slime rules were checked in `mods/ENTITIES/mobs_mc/slime+magma_cube.lua` and `mods/MAPGEN/mcl_biome_dispatch/init.lua`: roughly one tenth of 16×16 chunks, underground below Y -24 regardless of light, and swamp surface spawning in darkness with moon-phase weighting. Voxey uses its own seeded chunk hash and surface height because its terrain coordinates differ.
