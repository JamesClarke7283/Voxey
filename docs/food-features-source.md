# Placed cake, chorus fruit and suspicious stew

This implementation follows the local Mineclonia checkout in
`/home/impulse/.minetest/games/mineclonia`. The gameplay implementation is
`scripts/food_features.gd`, with meal completion in `scripts/eating.gd` and
source hunger accounting in `scripts/hunger.gd`. Pixel flowers and geometric
cake art are original Voxey artwork; no upstream image assets were copied.

## Cake

Reference: `mods/ITEMS/mcl_cake/init.lua`.

- Existing cake item ID **779** is preserved as the whole, seven-slice cake.
  New partially eaten voxel IDs **5600–5605** represent one through six
  remaining slices and are hidden from the normal item catalogue.
- Cake is placed on walkable support. Right-click eats one slice, restoring
  **2 hunger and 0.4 saturation**, with the source saturation-before-food
  ordering. A full survival hunger bar refuses a bite. Creative players can
  eat slices while full, and still remove them from the placed cake.
  Sneaking bypasses the cake callback so blocks can be placed against it;
  an animal targeted in front of a cake retains interaction priority.
- Cakes cannot be eaten directly from inventory. New cakes stack to one.
  Saved cake stacks from the previous 64-stack implementation retain their
  count during sanitation; placement consumes one at a time, and newly
  inserted items use the one-cake stack limit. This migration exception avoids
  silently deleting old cakes, including those stored in containers.
- Seven bites remove the cake. Mining, loss of support and piston destruction
  yield no cake item. Collision and selection match the source half-height
  box, narrowing by one eighth of a block per consumed slice. Comparator
  strength is twice the remaining slice count, from 14 down to 2.
- The source recipe uses three milk buckets, two sugar, an egg and three
  wheat. Both the recipe book and manual crafting grid return all three empty
  buckets; the existing Voxey `GRAIN` item represents wheat.

## Chorus fruit

Reference: `mods/ITEMS/mcl_end/chorus_plant.lua`, `random_teleport` and the
`chorus_fruit` item definition; ordinary hold-eating timing comes from
`mods/ITEMS/mcl_hunger/holdeat.lua`.

Finishing the ordinary **1.61-second** meal restores **4 hunger and 2.4
saturation**, even at full hunger, and attempts a random teleport. The source
implementation samples each axis from **−8 through +8**, up to **16 attempts**,
then scans at most **16 nodes downward**. The first walkable floor must have
two safe, non-liquid spaces above it in the scanned cells. Consequently the
landing may be lower than the initial eight-block vertical sampling range.
No extra chorus cooldown is imposed by the source item.

Voxey adapts source centered-node coordinates to its corner-based voxels,
checks the actual player collision box, and requires already loaded terrain.
Source-style failure is harmless: the meal is consumed and still restores
food even when no destination is found. Nether roof crossing is disallowed.
Waterlogged kelp is treated as water; fire, lit campfires and cactus-contact
landings are rejected. Successful teleportation clears velocity and dismounts
boats or horses, so movement cannot pull the player back or carry fall damage
into the landing. The dimension and camera direction are preserved.

## Suspicious stew and proper flowers

References: `mods/ITEMS/mcl_sus_stew/init.lua`,
`mods/ITEMS/mcl_flowers/{init,register,lg_register}.lua`, and the `saturation`
effect in `mods/ITEMS/mcl_potions/functions.lua`.

Suspicious stew remains item **780**, stack size one. Its source effect is
stored as `data.effect`, carried by both crafting paths, sanitized during
inventory/container restoration, and retained by save/load. A shapeless
recipe combines a red mushroom, brown mushroom, bowl, and one proper flower:

| Flower | ID | Source effect | Duration |
| --- | --- | --- | --- |
| Poppy | 5610 | Night vision I | 5 seconds |
| Dandelion | 5611 | Saturation I | 0.5 seconds |
| Oxeye daisy | 5612 | Regeneration I | 8 seconds |

Stew restores **6 hunger and 7.2 saturation** and can be eaten while full.
Survival eating returns a bowl; creative eating retains the stew without
duplicating bowls. Effects are applied after ordinary food restoration.
The installed source saturation effect restores **one hunger and one
saturation per second**, so the dandelion effect adds up to 0.5 of each over
its lifetime. The final update is clamped to the remaining duration, and the
effect survives saving partway through its half-second lifetime. Legacy
`jump` metadata normalizes to `leaping`; unknown effect keys and arbitrary
duration metadata are discarded.

These are distinct, naturally acquired flowers with their own original art,
placement/support checks, dyes, composting and source bone-meal propagation.
Applying bone meal scans grass under air within three blocks horizontally and
two vertically and gives each position a 20% chance to grow the same species.
The old generic `FLOWER` remains available and keeps its prior uses; it is
not assigned an invented stew effect. Other Mineclonia flower species and
their acquisition are outside this batch; the three recipes above are the
implemented survival stew variants. Existing externally supplied metadata
for other recognized source effects is retained, but an effect only runs if
Voxey implements that status effect (blindness is not currently implemented).

## Bone meal on a grass block, and tall grass

Using bone meal on a **grass block** is the source's other bone-meal rule, and it is
a different rule from the flower propagation above:

| | Flower propagation | Grass-block spread |
|---|---|---|
| Target | the flower it was used on | any grass block |
| Scan | ±3 horizontally, ±2 vertically | a **15×15** area over three heights |
| Output | the same species | **90% tall grass**, 10% a flower |
| Density | flat 20% per cell | `90 / ((|i| + |j|) / 2)` |

The density term is the interesting part: it is **zero underfoot**, so the formula
gives the block directly under the meal the highest chance and thins outward. A far
corner is far less likely than the block you are standing on, so a single use
produces a patch rather than a uniform grid.

**Tall grass** did not exist before this batch, which is why the rule was impossible
to implement: the source's spread is ninety percent tall grass, and there was
nothing to grow. It is now a real node — a non-solid, transparent plant with zero
hardness, drawn as an uneven tuft of blades, and it drops **nothing most of the
time**: the source's seed drop is one in eight, so breaking a tuft usually yields
nothing at all. Voxey's generic drop path returns the plant, which would have handed
one out on every break, so tall grass is explicitly excluded there and the seed is
rolled in `break_node` instead.

The old behaviour grew exactly one flower on the block itself, which was neither the
source's area nor its mix.

### Tall grass needs four consumers, not one

Adding a node is not adding a feature. Tall grass needed **four** separate pieces of
wiring, and missing any one leaves it visibly broken:

1. **The art**, in both the item and the world-art dispatch.
2. **The drop**, which is *not* the generic path. Voxey's `Nodes.drop` returns the
   plant by default, so a tuft would have dropped itself on **every** break. The
   source's drop is a one-in-eight seed roll, so tall grass is excluded from the
   generic path and the seed is rolled in `break_node`.
3. **Natural generation**, which is what makes it the most common surface plant —
   measured at **267 tall grass against 36 flowers** in a seeded 7×7 column sample.
4. **The support pass.** This is the subtle one. Terrain generates tall grass on
   grass, but structure overlays run *afterwards* and can replace the ground with
   brick or a barrel, stranding the plant in mid-air. Flowers already handle this by
   removing themselves when their soil changes; tall grass did not, and 8 of 267
   generated tufts sat on non-grass. It now shares that cleanup, and the `special`
   index that drives it had to learn about tall grass too.

That last point is the general lesson: a new node joins an existing mechanism only
where it is *listed*, and the listings are scattered across the drop path, the
terrain decorator, the `special` index and the support pass.

## Bone meal's other targets

The source gives `_on_bone_meal` to a long list of nodes. Three more are Voxey's:

| Target | Rule |
|---|---|
| **Sugar cane** | grows the stalk toward three, or **removes** it if it has lost its water |
| **Bamboo** | grows one segment, subject to the stalk's own height ceiling |
| **Cocoa pod** | ripens one stage; a ripe pod is left alone |

Sugar cane's removal branch is the interesting one: `grow_reeds` does not simply fail when the cane has no water, it *digs the cane up and drops it*. That makes bone meal a way to clean up cane whose water was removed, which is why the branch is implemented rather than skipped.

### A pre-existing bug: bone meal turned a cocoa pod into a cobweb

The shared crop path advances a crop by **id arithmetic**, `id + 3 - stage`, which assumes a crop occupies three consecutive ids. Cocoa's ids do not:

    687 Cocoa pod (growing)   ->  687 + 3 = 690 Cobweb
    688 Cocoa pod (ripe)

So bone meal on a cocoa pod produced a **cobweb**. The path was guarded by `not CropFarming.is_crop(id)`, but cocoa is crop-*shaped* without being in `CropFarming.INFO`, so the guard did not exclude it.

Two changes: cocoa is excluded from the shared path and ripens through its own ids, and the shared path now checks that the destination really is a later stage of the *same* crop before writing it. That second guard is the general fix — a table that is not three-wide can no longer silently produce an unrelated node.

## Huge mushrooms

Bone meal on a **small mushroom** grows a huge one, which is the source's
`mcl_mushrooms` rule: a 40% roll, a mushroom soil, and enough room. It has its own
notes at [huge mushrooms](huge-mushrooms-source.md), because the cap blocks are a
family rather than a single block.

## Recorded source gaps

- **No double tall grass.** The source's bone meal on a *tall grass* block turns it into a two-block `double_grass`. Voxey has no double-height plant node, so that conversion is not implemented. The grass-block spread above is a separate rule and is implemented.

## Validation

`tests/food_feature_checks.gd` exercises actual right-click use and hold-eating,
source cake boxes, complete seven-bite consumption, support/mining behavior,
both crafting paths, bucket/bowl returns, full-hunger and creative exceptions,
stew metadata sanitation and real save/load, deterministic chorus scan bounds,
hazards, low ceilings, waterlogged plants, unloaded terrain, Nether roof
restrictions and safe completion of a consumed chorus meal. The focused
food group passes **126 feature checks plus the loading check**; the natural
generation test verifies all three species and their supporting soil.
