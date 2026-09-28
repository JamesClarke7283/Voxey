# Bats, endermites and polar bears

Three `mobs_mc` creatures that Voxey lacked. Checks: `cave_fauna` in the lifecycle
suite.

| Mob | Source | Voxey |
| --- | --- | --- |
| bat | `ENTITIES/mobs_mc/bat.lua` | [`bats.gd`](../scripts/bats.gd) |
| endermite | `ENTITIES/mobs_mc/endermite.lua`, `ITEMS/mcl_throwing/register.lua`:294-297 | [`endermites.gd`](../scripts/endermites.gd) |
| polar bear | `ENTITIES/mobs_mc/polar_bear.lua` | [`polar_bears.gd`](../scripts/polar_bears.gd) |

## Bat

An ambient flyer: six health, no drops, no experience, no attack, and it
despawns. Its whole behaviour is `motion_step` (bat.lua:61-145):

- **Flight.** It flies toward a target cell: its own cell plus
  `random(0,6) − random(0,6)` on x and z and `random(0,5) − 2` on y. It picks a
  new target when it has none, when the target has become solid, at 1 in 30 per
  tick, or when it comes within 2 nodes of the target. Each tick the velocity
  moves a tenth of the way toward `sign(d) × 10` horizontally and `sign(d) × 14`
  vertically.
- **Hanging.** Under an opaque solid ceiling, a flying bat starts hanging at
  1 in 100 per tick. It hangs 0.9 below the ceiling, facing a random way at
  1 in 200 per tick. It lets go when the ceiling goes or a player comes within
  four nodes.
- **Spawning.** Only below the source's sea level, at light 3 or less (6 from
  20 October to 3 November), and never where the sky can be seen. Bats arrive in
  packs of up to 8.

Voxey steps once per frame, so each per-tick chance is scaled by
`mcl_mobs.scale_chance`. Bats are counted in their own **ambient** category,
outside the monster/animal cap. The cap is the source's `min_chunk_mob_cap` of
5, because Voxey loads far fewer chunks than a server view distance.

## Endermite

A small hostile arthropod: eight health, two damage at reach one, three
experience, and no drops. Its armour group is arthropod, so Bane of Arthropods
applies. The source gives it no natural spawner. Its only source is the ender
pearl, which leaves an endermite where the thrower stood at 1 in 10. Endermen
hunt endermites (`enderman.lua`:710-712). Voxey expresses that through a new
`hunts` list on a creature kind, which generalises the zombie's existing
villager hunt.

## Polar bear

A neutral animal of the cold biomes: 30 health, 6 damage at reach 2, and 1-3
experience (`xp_min`/`xp_max` is now supported as a range). It has
`_can_freeze = false`.

- **Targeting** (254-260):
  - A bear retaliates on whatever hits it.
  - An adult goes for the player while a cub is within ±8 nodes horizontally
    and ±4 vertically.
  - A struck **cub** runs, and alerts every adult within the bear's view range
    of 20.
  - A struck adult alerts nobody.
  - A cub never attacks.
- **Rearing.** A chasing adult just outside its reach rears up on its hind legs.
- **Drops.** Raw cod 0-2 at 1 in 2 and raw salmon 0-2 at 1 in 4, both with common
  looting. A cub drops nothing, because `item_drop` skips a child that is not a
  monster.
- **Spawning.** On grass or a snow block in the cold biome, at weight 1 against
  the rabbit's 10, in packs of one or two. The second bear of a pack is always a
  cub, and a cub grows up after twenty minutes.
