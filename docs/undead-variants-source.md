# Husks, drowned and strays

The zombie and the skeleton each have biome and conversion variants in
`ENTITIES/mobs_mc/`. Voxey had neither the variants nor the conversions, and it
rolled a thinner drop table for both base mobs than the source does.
[`undead_variants.gd`](../scripts/undead_variants.gd) now ports all three
variants and the conversions, and rolls the drops for both families. The local
difficulty that the husk's bite reads lives in
[`regional_difficulty.gd`](../scripts/regional_difficulty.gd). Checks:
`undead_variant` in the lifecycle suite.

| Piece | Source | Voxey |
| --- | --- | --- |
| `drops_common`, zombie drops | `zombie.lua`:14-56 | `UndeadVariants.roll_drops` |
| zombie → drowned, husk → zombie | `zombie.lua`:575-592 (`step_conversion`) | `UndeadVariants.conversion_step` |
| husk | `zombie.lua`:811-858 | `Creature.KINDS["husk"]` |
| zombie, husk spawning | `zombie.lua`:872-945 | `UndeadVariants.biome_variant` |
| drowned definition | `drowned.lua`:29-155 | `Creature.KINDS["drowned"]` |
| drowned equipment | `drowned.lua`:421-435 | `UndeadVariants.equip_drowned` |
| drowned targeting and trident | `drowned.lua`:544-561 | `drowned_targets_player`, `throw_trident` |
| drowned spawning | `drowned.lua`:774-863 | `UndeadVariants.drowned_cell` |
| skeleton → stray | `skeleton+stray.lua`:175-195 | `UndeadVariants.conversion_step` |
| stray | `skeleton+stray.lua`:367-392 | `Creature.KINDS["stray"]` |
| stray spawning | `skeleton+stray.lua`:409-496 | `UndeadVariants.biome_variant` |
| drop rolling | `mcl_mobs/physics.lua`:17-80 | `UndeadVariants.roll_entry` |
| `dealt_effect` | `mcl_mobs/combat.lua`:882-899 | `Creature.deal_effect` |
| local difficulty | `mcl_worlds/init.lua`:184-280 | `RegionalDifficulty` |

## The variants

- **Husk.** The zombie with `ignited_by_sunlight = false`, so it does not burn
  in daylight. Its drops are `drops_common`, which has no zombie head. Its
  `dealt_effect` is hunger at level one for 7 × regional difficulty seconds, so
  on a new normal world a bite lasts 10.5 seconds. Only an outdoor desert spawn
  can be a husk.
- **Drowned.** The zombie's swimming form. It holds its depth in water rather
  than bobbing up, and it rises and sinks toward its target. It still burns in
  daylight once it surfaces; the source keeps that deliberately, as its comment
  at `drowned.lua`:144-147 records. By day it only targets a player who is in
  water. When it first appears, one in ten is armed, and ten in sixteen of those
  carry a trident, the rest a fishing rod. Separately, three in a hundred hold a
  nautilus shell. A trident makes it a ranged attacker. It throws a trident every
  2 seconds inside 10 nodes, at 50 nodes/s, for 8 damage, with `14 − 4 × difficulty`
  degrees of inaccuracy. The trident cannot be picked up. Its drops are rotten
  flesh 0-2 and a copper ingot at 11 in 100 (rare looting +0.02 per level). The
  held trident or rod drops at the mob default of 8.5%, and the nautilus shell
  always drops.
- **Stray.** The skeleton in the cold biomes, firing `mcl_potions:slowness_arrow`.
  Only an outdoor cold-biome spawn can be a stray.

## Conversions

- A **zombie** whose eyes stay under water becomes a **drowned**, and a **husk**
  becomes a **zombie**. The clock runs while the eyes are submerged, and
  surfacing resets it only until 30 seconds have passed. From 30 seconds the mob
  shakes, and at 45 seconds it converts. A drowned never converts further
  (`_convert_to = false`).
- A **skeleton** in powder snow shakes after 7 seconds and becomes a **stray**
  at 22 seconds. Leaving the snow resets the clock at any point.
- The successor keeps the nametag, the persistence, the facing and the held
  items, as `mob_class:replace_with (successor, true)` passes them. Its health is
  its own, because the source creates the successor fresh.

## Drops

`mob_class:item_drop` takes `1 / chance` as the success probability. Rare
looting adds `looting_factor × level` to that probability. Common looting adds
`floor(random(0, level) + 0.5)` items, but only when the base roll succeeded.
Voxey's zombie table had rotten flesh alone and its skeleton table had bones
alone. The source zombie also drops iron, carrots and potatoes at 1 in 120 each,
and the source skeleton also drops 0-2 arrows. Both are now rolled as written.
A mob killed while burning still cooks any cookable drop, so a burning zombie's
potato drops baked.

## Source quirks ported as written

- **The stray's slowness-arrow drop never happens.** The stray is defined with
  `drops = table.insert (table.copy (skeleton.drops), {...})`. `table.insert`
  returns nothing, so the field is nil and `table.merge` keeps the skeleton's
  table. A stray drops arrows and bones, like a skeleton; it only *shoots*
  slowness arrows.
- **Skeletons do not freeze.** The skeleton carries `_can_freeze = false`, which
  the stray inherits. Powder snow never damages either one; it only runs the
  skeleton's conversion clock. Voxey's skeleton used to take freeze damage.

## Regional difficulty

`mcl_worlds.get_regional_difficulty` combines three things:

- The **inhabited time** of the player's 16×16 column: the seconds any player
  has spent there, saved per dimension.
- The **world's age**: nothing before the third day, then growing linearly up to
  0.25 at day 63.
- The **moon's brightness**, which caps the age term's contribution to the
  column term.

The result is scaled by the difficulty level (×1, ×2, ×3). The special difficulty
that mob buffs read ramps from 0 at 2.0 to 1 at 4.0. Voxey's
`game.difficulty` runs 0-2, and `source_level` maps it onto the source's 1-3.
Inhabited time is saved under `"inhabited"` with the source's own key format.
Old saves default to zero, which is the source's reading of an unvisited chunk.

## Fixes made alongside

- **The cave spider's poison was dead code.** `SpiderClimb.poison_on_hit` was
  covered by checks but never called from a real bite. The new `dealt_effect`
  hook calls it, so a cave spider's landed hit now poisons.
- **Mobs burned under water.** The sunlight rule only compared the mob's height
  with the terrain, so a zombie swimming above a sea floor burned. Water now
  puts the burn out, as `mcl_burning` does.

## Recorded deviations

- The source's 5% **baby** zombie, husk and drowned are not spawned, because
  Voxey has no baby hostile body yet.
- Spawning is a substitution within Voxey's existing hostile pool, not the
  source's weighted spawner list:
  - In the desert, an outdoor zombie becomes a husk with probability
    80 / (80 + 19).
  - In the cold highlands, an outdoor skeleton becomes a stray with probability
    80 / (80 + 20).
  - A night-time ocean column can spawn a drowned in its deep water at the
    source's 1 in 6, below the source's sea-level-minus-five.

  The source's river rule (1 in 2) has no Voxey biome to attach to.
