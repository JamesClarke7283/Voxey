# World and Nether progression comparison

This work uses the supplied Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia`. The source manifest and hashes are in [mineclonia-audit.json](mineclonia-audit.json). Full parity remains in progress; the [module ledger](mineclonia-parity.md) tracks outstanding systems.

## World coordinates and ores

`mcl_init/init.lua` computes the default legacy map boundary from Luanti's 31000 mapgen limit, 16-node mapblocks and five-mapblock mapchunks. The resulting horizontal coordinates are **−30912 through 30927**, inclusive. The legacy Overworld starts at **−128** and permits building through **30927**. Voxey now supports that building range using implicit air and allocating upper blocks only when edited. Saved high-altitude blocks and containers stream back with their original coordinates.

Voxey uses separate dimension scenes. The source's Nether terrain range −29067…−28939 maps to local **0…128**, with its dimension extending another 128 blocks above the roof. The legacy End's −27073…−2128 range maps to local **0…24945**. The source also has an optional newer singlenode generator and an ersatz structure system; those presets have not been ported.

`tools/export_mineclonia_ores.lua` captures the registrations in `mcl_biomes/ores.lua`. `tools/build_ore_catalog.py` maps the mineral rules and adds quartz/Nether gold registrations from `mcl_biomes/init.lua`, producing **100 scatter rules** in `scripts/mineclonia_ore_rules.gd`. Each retains cluster scarcity, expected cluster count, cluster cube size, host materials, height band and biome restriction. The scatter implementation uses the clipped 80-node source mapchunk volume to determine cluster count and the source's per-voxel acceptance probability. Neighboring Voxey columns calculate identical overlapping placements.

This matches scatter parameters and distributions, **not exact source seed layouts or complete terrain generation**. Voxey still has its own noise, caves, surface heights and biome mapping; it lacks several source biomes, high mountains, most blob distributions and the new mapgen preset. Therefore total discoverable ore counts cannot yet be claimed identical. The stone/deepslate transition now spans roughly −64…−46, matching the source transition band more closely.

Natural tuff now uses the source's blob registration: Y −128…−46, scarcity 1000, a seven-node bounding cube and the five stone/deepslate hosts. Cluster count uses the clipped 80-node mapchunk volume; the source blob algorithm ignores `clust_num_ores`. Its three-octave value noise uses spread 250, persistence 0.6, lacunarity 2 and seed offset 12345, then subtracts distance from the blob center divided by cluster size. Mineral scatter follows tuff placement, retaining deepslate ore eligibility inside tuff. Column halos produce matching deposits, and saved edits still apply last.

The blob formula was checked against [Luanti's ore generator](https://github.com/luanti-org/luanti/blob/master/src/mapgen/mg_ore.cpp). `LuantiValueNoise` adapts the mathematical value-noise construction from [noise.cpp](https://github.com/luanti-org/luanti/blob/master/src/noise.cpp), with its [BSD copyright notice retained](licenses/Luanti-Noise-BSD.txt). The native reference exporter compiles the actual source functions into 28 independent test samples; the largest observed difference is 0.00000670 due to floating-point precision. Cluster seeds still use Voxey's deterministic world hash, so exact source seed layouts remain open.

The scatter algorithm was checked against Luanti's [mg_ore.cpp](https://github.com/luanti-org/luanti/blob/master/src/mapgen/mg_ore.cpp). Ore registration data is adapted from Mineclonia under GPL-3.0-or-later; see [the included license](licenses/Mineclonia-GPL-3.0.txt).

## Netherite and armor

Reference modules: `mcl_nether/init.lua`, `mcl_tools/register.lua`, `mcl_farming/hoes.lua`, and `mcl_armor/{api,register,damage}.lua`.

- Ancient debris uses the source's three bands: local Y 8…22 at scarcity 15000, expected count 3, cube size 3; Y 0…8 and 22…119 at scarcity 32000, count 2, size 3.
- Diamond or Netherite pickaxes harvest debris. Smelting yields scrap; four scrap and four gold yield one ingot. Nine ingots make a storage block.
- Smithing consumes a diamond tool/armor piece, one ingot and one upgrade template. It preserves enchantments, custom names and normalized wear. Seven diamonds, netherrack and a template duplicate the template.
- Netherite tools have 2031 uses and mining speed 9.5. Equipment damage, armor points and toughness use the source registrations. Armor uses the source's material/piece durability factors, including the source-specific 381/556/521/451 Netherite values.
- Armor reduction uses damage strength, defense points and toughness. Wear per hit is at least one and otherwise floor(damage/4). Save version 3 preserves the worn fraction of armor imported from earlier versions, including nested storage.
- Ancient debris and Netherite items survive lava/fire; ordinary drops burn after the source's two-second grace period. Debris, Netherite blocks and crying obsidian resist ordinary explosions.

## Bastions, barter, fire and lodestones

`mcl_nether_fortresses/init.lua` provides the legacy bulwark loot groups and one-in-25 mapchunk placement probability. Voxey currently has a source-sized, original blackstone layout with three accessible levels and treasure containers. It is an adaptation: the four source layouts, daughters, complete placement eligibility and all inhabitants remain outstanding. Treasure retains source item weights, quantity ranges and group roll counts. Armor trims and the snout banner pattern still await their complete consuming systems; the Mall disc now plays in a [jukebox](jukebox-source.md). Enchanted treasure selection remains simplified.

Piglin barter uses all **18 entries** from `mobs_mc/piglin.lua`, with source weights and quantity ranges. One gold ingot takes six active seconds to inspect before a ground reward appears; Soul Speed books/boots and fire resistance bottles are included. Gold armor pacifies unprovoked piglins, while brutes remain hostile. Bastion guard records keep location, health, provocation, barter progress and deaths across saves. Full piglin group AI, item admiration, conversion and hoglin behavior are still pending.

Lodestones bind individual compasses, preserving the remainder of an unbound stack. The binding stores dimension and coordinates, survives save normalization and stops tracking when a loaded lodestone is removed. A compass in another dimension spins. The lodestone recipe uses eight chiseled stone bricks and one Netherite ingot.

Fire charges and flint and steel ignite blocks, portals and TNT. Flint and steel has 65 uses. Normal fire can expire, rain/water extinguish it, and netherrack supports eternal fire. Fire spread, fuel removal and lava ignition use the source ABM intervals/chances. The current flammability mapping, light rendering and detailed fire timers remain partial.

## Offline identity

Offline play always uses the session key **`player`**, with no profile selector. Homes, villager reputation and recovery ownership remain keyed by player identity for future multiplayer. A migration reads the former selector's active identity without changing its registry: its home and reputation become available to `player`, existing `player` data takes precedence, and other identity entries remain preserved.

## Verification

`tests/parity_runner.gd` exercises sparse upper blocks, saves, ore borders and registration bands, the Netherite crafting/upgrade chain, legacy armor, lava immunity, offline identity migration, bastion loot/residents/barter, fire ignition/extinguishing and lodestone metadata. `tests/run_tests.sh` includes these checks alongside the existing gameplay suites. Automated checks establish the tested behaviors; they do not establish complete Mineclonia parity.
