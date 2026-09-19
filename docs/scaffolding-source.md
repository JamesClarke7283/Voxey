# Scaffolding

Voxey follows the scaffolding half of the supplied Mineclonia `mods/ITEMS/mcl_bamboo`. The implementation is original GDScript using the source as a behaviour reference; no source code or asset is copied.

## Two nodes, one item

The reference registers a vertical `scaffolding` and a horizontal arm `scaffolding_horizontal`. Both are climbable frames with the source's node box — a thin deck at the top plus four corner posts — and **both drop the plain vertical item**, so an arm returns a scaffold.

Hardness is 0, so it breaks instantly, and it burns for 2.5 seconds.

## The distance field

This is what makes scaffolding behave. Every scaffold stores, in its `param2` in the reference, its distance from the nearest support. The rules:

- A scaffold placed on the ground is its own support at distance 0.
- Horizontal arms may reach **`SCAFFOLD_BASE_AWAY_LIMIT` = 6** cells from a support.
- Anything left beyond that limit is not supported: it becomes a falling node and drops as an item.
- Removing a support in the middle re-runs the field, so the far end is stranded and drops rather than floating.

Voxey recomputes the field by flood fill from the support rather than incrementing in place. That is behaviourally what the source's clear-then-fill queue pair achieves, and it is why deleting a support correctly strands the whole chain beyond it rather than leaving a stale chain of valid-looking distances.

## Placement

Placement is direction-sensitive, and the source's three branches are reproduced:

| Input | Result |
|---|---|
| Click a scaffold's side while sneaking | One horizontal arm, one cell further out |
| Look down steeply (45–90°) at a scaffold | A **run** of arms extending away from you, out to the limit |
| Anything else on a scaffold | Towers the column upward from its **top**, not from the clicked cell |
| A solid block | A fresh support |

## Recorded source gaps

- **The bamboo stalk is implemented.** [Bamboo](bamboo-source.md) now grows: a shoot becomes a stalk, one segment at a time, up to a per-stalk height, with a light requirement and two thicknesses. The rest of the bamboo **wood family** (planks, doors, trapdoors, fences, signs, raft) and its natural generation remain open and are recorded in that module's notes.
- **The recipe uses real bamboo.** The source crafts six scaffolding from six bamboo around a string, and that is now the recipe. The plank substitute is gone.
- The source's `on_place` prediction string and its `check_single_for_falling` integration are engine concerns with no equivalent, since Voxey applies falling behaviour directly.
