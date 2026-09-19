# Ruined portals and the stone brick variants

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/ruined_portal.lua` and the `stonebrick{carved,cracked,mossy}` nodes from `mods/ITEMS/mcl_core/nodes_base.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

Two reasons beyond decoration:

1. **Obsidian is the Nether portal's material.** A ruined portal is the surface route to it, so a player can build their own portal without hunting lava lakes.
2. **Crying obsidian is the source's respawn-anchor material**, and a ruined portal is where it comes from.

The structure sat unbuildable until this session because it needs **magma** and **cracked stone bricks** for its degradation rules, and Voxey had neither. Both now exist ([magma](magma-source.md) and the brick variants below), so the portal could finally be built.

## The degradation is the structure

The source does not place a clean frame. Its `after_place` applies an **independent chance per material**:

| Material | Chance | Becomes |
|---|---|---|
| Gold block | 30% | Air — the frame's gold is partly looted |
| Lava | 20% | Magma |
| Netherrack | 7% | Magma |
| Obsidian | 15% | Crying obsidian |
| Obsidian | **10%** | Air |
| Stone bricks | 50% | Cracked stone bricks |

The obsidian has **two rolls applied in sequence**, so a frame block can become crying obsidian, vanish, or both rules can pass and it is gone. That ordering is the source's and is reproduced exactly.

Every rate was measured against the source value over 29×29 regions (441 portals):

| Rule | Source | Measured |
|---|---|---|
| Bricks → cracked | 50% | 48.9% |
| Gold → air | 30% | 29.0% |
| Lava → magma | 20% | 18.6% |
| Obsidian → crying | 15% | 12.8% |
| Obsidian → air | 10% | 8.4% |
| Netherrack → magma | 7% | 6.1% |

## The stone brick variants

The degradation needs cracked bricks, so the three source variants were added:

| Block | Voxey id | Route |
|---|---|---|
| Chiseled stone bricks | 1159 | Four plain bricks in a square, the source's own recipe |
| Cracked stone bricks | 1160 | **Smelt plain bricks**, the source's `_mcl_cooking_output` |
| Mossy stone bricks | 1161 | Registered; the crafting route needs moss, which Voxey lacks |

All three share the source's texture shape — a running bond with four-pixel courses staggered every other row — so they read as the same family as the plain bricks.

## Recorded source gaps

- **The frame is generated, not loaded from a schematic.** The source ships seven `.mts` files. Voxey has no schematic loader, so a portal is built as an obsidian frame on a stone brick base with a gold accent and a lava pool. The degradation rules and the loot are the source's exact behaviour; the block-by-block layout is not.
- **No `all_floors` placement.** The source can place a portal at several floor heights inside a chunk column. Voxey places one per region on the surface.
- **No Nether-side ruined portals.** The source registers the structure twice, once for the overworld and once for the Nether with netherrack, soul blocks, blackstone and nylium. Only the overworld variant is implemented.
- **Mossy stone bricks have no crafting route.** The source combines plain bricks with moss from `mcl_lush_caves`. Voxey has no moss item, so the block is registered but not craftable, and that is recorded rather than papered over with an invented recipe.
- **Unavailable loot entries keep their weight.** The source's chest table includes bells and four horse armours; Voxey has no items for them, so those entries carry a zero id rather than being redistributed.
