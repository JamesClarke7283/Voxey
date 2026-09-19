# Desert temples

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/desert_temple.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or schematic is copied.

## Why it mattered

The desert temple is the **desert route into archaeology**, and it exposed a real bug behind it: **pottery sherds could not be obtained in survival at all.**

The source does not draw a suspicious node's loot from one generic table. It reads the `structure` tag the placing structure wrote into the node, looks that structure's own table up, and falls back to a default list otherwise. Those per-structure tables are where the sherds live — several carry four different sherds each. Voxey's generic tables held no sherds, and the only other place a sherd appeared was as the drop from **breaking a decorated pot**, which itself is crafted **from sherds**. That is a closed loop: the first sherd was unobtainable.

The fix is the source's own mechanism. Suspicious nodes now carry the name of the structure that placed them, and the draw uses that structure's table, which contains sherds.

## What the source does

The temple's `after_place` does three things, in this order:

| Step | Behaviour |
|---|---|
| Cacti | Removes leftover cacti standing on sandstone inside the footprint |
| **Conversion** | Converts up to **250** of the temple's own sand/sandstone cells into **suspicious sand**, tagged `structure = desert_temple` |
| Trap | Removes up to **five** of the temple's stone pressure plates, each at 50% |

The conversion is the archaeology. The trap removal is why the temple's TNT trap is partly missing — the source's own design, reproduced exactly.

The chest holds the source's table: bones, rotten flesh, spider eyes, leather, gold, iron, emeralds, four horse armours, an enchanted golden apple and the dune armour trim, plus four rolls of sand and monster parts.

## Sherds by structure

Each table carries the sherds the source put in it, with source weights:

| Structure table | Sherds present in Voxey |
|---|---|
| `desert_temple` | skull |
| `ocean_ruins_warm` | angler |
| `ocean_ruins_cold` | blade, explorer |

An unavailable source sherd — archer, miner, prize, shelter, snort, mourner, plenty — keeps its weight with a **zero id** rather than being remapped onto a different Voxey sherd. Remapping would be worse than dropping: it would put the wrong motif on a pot face while appearing to work.

## Recorded source gaps

- **The pyramid is generated, not loaded from a schematic.** The source ships one `.mts` file. Voxey has no schematic loader, so the temple is built as a stepped sandstone pyramid over a floor plate with a shaft to the vault. The conversion rule, the cap, the plate removal and the loot table are the source's exact behaviour; the block-by-block layout is not.
- **No desert biome test.** The source restricts placement to the `Desert` biome. Voxey has no such biome map, so a temple is placed where the ground is sand, which is what the source's `place_on` requires.
- **Nineteen of twenty-three sherds remain unregistered.** Voxey registers four, one per motif family, to keep the atlas bounded. Their absence is why the tables above carry zero-id entries.
- **No horse armour or armour-trim items.** The source's chest table includes four horse armours and the dune trim, which Voxey has no items for, so those entries keep their weight with a zero id.
- **No cacti cleanup step.** Voxey's temples are placed into sand rather than over an existing desert surface with cacti, so there are no leftovers to remove. The rule is named here rather than silently dropped.
