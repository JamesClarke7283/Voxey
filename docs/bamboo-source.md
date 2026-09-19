# Bamboo

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_bamboo/{init,nodes,recipes}.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

Voxey had **scaffolding**, which the source builds from bamboo — and `scaffolding.gd` recorded bamboo itself as the missing piece, so its recipe had to substitute another material. This adds the stalk, so that substitution is gone and scaffolding costs what the source says it costs.

Bamboo is also a plant with three rules that make it distinct from a tree:

| Rule | Source |
|---|---|
| Grows as a **stalk**, one segment at a time | to a per-stalk height |
| Each stalk's ceiling comes from **its own position** | `pr:next(12,16)` |
| It needs **light 9** above the tip | so bamboo stops in a cave |
| Once established it takes one of **two thicknesses** | a coin flip, `math.random() < 0.5` |

The per-stalk height is what makes a grove **uneven** rather than a field of identical poles — the source derives the ceiling from the stalk's own position hash, so two stalks side by side stop at different heights. The test asserts that different positions give different ceilings, and that every ceiling is inside the source's range.

The two thicknesses are why a bamboo grove reads as mixed. A stalk of more than one segment takes *small* or *big* by a coin flip, and the whole stalk takes it — a stalk does not change thickness partway up, which the test checks along its entire length.

## The light gate

A stalk only grows when the cell above it has light 9 or more. That is what keeps bamboo out of caves, and it is a rule a naive implementation would miss entirely — the plant would grow underground. The test drives `grow` with a dark light function and asserts the stalk **adds nothing**.

## The scaffolding recipe

The source's own shape, which I checked rather than assumed:

```
bamboo  string  bamboo
bamboo   ....   bamboo
bamboo   ....   bamboo
```

Six bamboo and a string, yielding six scaffolding. My first version wrote eight bamboo in a ring and the test caught it — the count is asserted against `SCAFFOLD_COUNT`, which is now six.

## The stalk is a column, not a wall

A bamboo stalk has a narrow collision box, so it does not block movement like a cube. The test asserts the box is narrower than half a block, alongside the mesh check, because a stalk that rendered as a cube would be a wall of bamboo.

## Recipes

Two of the source's own recipes are implemented directly from `mcl_bamboo/recipes.lua`:

| Recipe | Shape |
|---|---|
| **Sticks** | two bamboo stacked vertically → one stick (not the 2×2 the planks use) |
| **Scaffolding** | six bamboo around a string → six scaffolding |

The stick recipe is worth noting because sticks **already** had a plank recipe, so it is a second route to the same item rather than a replacement. That matters for how it is tested: `recipe_index(STICK)` returns the *plank* recipe, so the check finds the bamboo one by its own name.

## Natural groves

Bamboo grows **wild**, which the source does as a levelgen feature: a noise-based
count, then a stalk whose height is `5 + rng:next_within(12)` — five to sixteen. A
stalk taller than three cells carries the **small and large leaf forms** at its tip
rather than plain trunk, which is what gives a wild grove its ragged top.

A grove is a **run** of stalks rather than one, so a column with the right seed raises
a short line of them.

### Two gates that hid each other

Getting this working took finding that two conditions silently cancelled each other:

1. **The dry-land gate.** Everything in that decoration chain sits behind
   `if h > SEA + 1`. The swamp regions here are *below* sea level (surface at 19–20
   against a sea of 21), so a grove placed in a swamp would stand **underwater** — and
   the gate meant the code never ran there at all. Measuring the biomes showed the
   overlap: only **one** column in a 128×128 area satisfied both warm climate and
   dry land in the swamp regions.
2. **The density window.** My first attempt used two decoration ids out of a hundred,
   which is roughly one candidate per five chunks — far below the source's ~2 per
   chunk. Widening it to five ids gave **174 stalks across 81 sampled chunks** against
   the source's ~162, which is the right order.

The height had a third bug of its own: my first version filled every cell up to a
fixed sixteen, so **every stalk was exactly sixteen tall**. The source's height is a
roll, and the checks now assert both that every stalk is *within* five to sixteen and
that the heights **vary** — a fixed height would have passed a range check while being
plainly wrong.

## Recorded source gaps

- **No bamboo wood family.** The source's `mcl_bamboo` is registered as a wood family, giving bamboo planks, a mosaic plank and rafts. Voxey has the stalk, the item, the stick recipe and the scaffolding recipe; the planks, mosaic and raft are open.
- **No leaf variants.** The source has small and big leaves at a stalk's top, with three shape states each. Voxey's stalk has one top segment.
- **No podzol or moss ground.** The source's `soil_bamboo` group covers dirt, grass, podzol and moss. Voxey has neither podzol nor moss, so bamboo grows on dirt, grass and sand.
- **No `param2` orientation.** The source gives a stalk a four-direction facing. A column of revolution has nothing to orient, so Voxey stores none.
