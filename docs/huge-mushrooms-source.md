# Huge mushroom cap and stem source notes

Reference: Mineclonia `mods/ITEMS/mcl_mushrooms/huge.lua` (GPL-3.0-or-later), especially `to_binary` at lines 29–42 and `register_mushroom` at lines 44–163. The existing schematic layout and growth rules remain in `scripts/huge_mushrooms.gd`; the cap layers still come from the shipped `.mts` schematics.

## State and source names

The source cap suffix is six binary digits in tile order:

| String position | Face | Bit | Value 0 | Value 1 |
| --- | --- | --- | --- | --- |
| 1 | +Y | 32 | pores | skin |
| 2 | -Y | 16 | pores | skin |
| 3 | +X | 8 | pores | skin |
| 4 | -X | 4 | pores | skin |
| 5 | +Z | 2 | pores | skin |
| 6 | -Z | 1 | pores | skin |

Thus mask zero is `cap_000000`, mask 32 is `cap_100000`, and mask 63 is the player-facing `cap_111111`. There are 64 cap IDs per species, not 63: the all-pore registration is real content too. `HugeMushrooms.cap_for(small, mask)`, `mask_of(id)`, `mask_string(mask)`, and `source_name(id)` expose the exact mapping.

Legacy IDs 1207–1212 are unchanged. The additional IDs occupy the previously unused contiguous range 16000–16125, below `NodeInfo.LIMIT` and outside `ShapeCatalog`'s 14000–15999 allocation:

- 16000/16001: brown/red `mcl_mushrooms:*_mushroom_block_stem_full`.
- 16002–16063: brown cap masks 1–62.
- 16064–16125: red cap masks 1–62.
- Existing 1211/1212 and 1209/1210 remain brown/red masks 0 and 63.

`HugeMushrooms.DATA` is the complete constant 132-entry registration table (128 caps plus four stems), mirrored by reference in `VillageContent.DATA`. Every cap below mask 63 has `hidden: true`, corresponding to the source's hidden internal registrations. The all-pore state is hidden too.

## Placement callback and permanence

Only `cap_111111` has `on_construct` in the source. It scans the six directions in the table above. A neighbor participates only when its species matches and its `huge_mushroom_cap` group is nonzero. Both touching skin bits are cleared. Different-species caps, ordinary stems, full stems, and non-mushroom blocks do not participate.

The all-pore edge case is intentional: `cap_000000` is registered with `huge_mushroom_cap = 0`, but the callback tests `~= 0`. Consequently an all-pore cap does **not** trigger a touching-face update in a newly placed all-skin cap.

The callbacks only clear bits. Removing a neighbor never sets a bit again, and placing/changing an internal mask does not rerun the all-skin construct callback. The mask is the voxel ID itself, so the ordinary voxel edit/save/network paths preserve it without `block_states` metadata.

API:

- `placed(world, p) -> bool`: source `on_construct`; reads the current ID at `p`, returns false unless it is mask 63, and applies touching updates through `VoxelWorld.set_node`.
- `changed(world, p, old_id, id) -> bool`: `VoxelWorld` integration wrapper; invokes `placed` only for a transition to mask 63.
- `face_states(id) -> Array`: six skin booleans in source tile order; ordinary stems are `[false,false,true,true,true,true]`, full stems are all true.
- `face_texture(id, source_face) -> int`: registered ID supplying that face's atlas art in source tile order.
- `render_texture(id, render_face) -> int`: the same lookup in Voxey's `+X,-X,+Y,-Y,+Z,-Z` renderer order.
- `state_snapshot(id) -> Dictionary`: `{id, source_node, species, kind, mask, skin, textures}`; `skin` is source ordered and `textures` contains the six source-ordered texture IDs.
- `silk_touch_drop(id) -> int`: every cap mask returns its species' mask-63 cap; ordinary and full stems return themselves.

## Integrated parent hooks

1. **Registration/art:** every `HugeMushrooms.DATA` entry is mirrored in `VillageContent.DATA` and the new IDs are in its block/art registration, preserving each entry's `source_node` and `hidden` values. The constant table keeps registration acyclic and avoids regenerating source names at runtime.
2. **Placement:** in `VoxelWorld.set_node`, after the new voxel ID has been written, call `HugeMushrooms.changed(self, p, old_id, id)` in the ordinary change-hook section. No removal hook is needed or wanted. The wrapper prevents recursion when `placed` replaces the caps with internal masks.
3. **Silk Touch:** in `game.gd`'s existing `HugeMushrooms.is_huge(id)` harvest branch, replace the Silk Touch drop expression `id` with `HugeMushrooms.silk_touch_drop(id)`. Keep the existing ordinary small-mushroom drop path unchanged.
4. **Rendering:** in `Nodes.uncached_tile`, before the generic `VillageContent.DATA` fallback, route huge mushroom faces through `HugeMushrooms.render_texture(id, face)` and resolve that returned ID to its atlas tile. This is required for regular stem ±Y pores and for cap faces; merely registering all mask IDs with one uniform tile would render the wrong textures.
5. **Tests:** add `mushroom_cap` to `tests/lifecycle_runner.gd`'s default check list. The focused checks use real `VoxelWorld.set_node` edits and explicitly invoke the exposed change hook until hook 2 is integrated; repeated invocation after integration is harmless.
6. **Existing mushroom assertions:** update `tests/food_feature_checks.gd`'s “all six” registration expectation to the 132-entry family. Count `is_pores` before `is_cap` (all-pore is a cap mask), and replace the one-unique-atlas-tile-per-ID assertion: correct per-face rendering intentionally resolves internal masks to the canonical skin or pore texture. The focused mushroom-cap suite covers the replacement contract.

## Drops and schematics

The source's non-Silk drop remains the corresponding small mushroom, so `species_of` covers every new cap and both full stems. Silk Touch canonicalizes only caps; full stems retain their own IDs. `shape` keeps the existing brown/red schematic layers and stem column, then assigns each cap its full six-face adjacency mask instead of collapsing covered cells into a single generic pore block.
