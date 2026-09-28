# Striders, hoglins, zoglins and the Nether's spawn tables

Checks: `nether_fauna` in the lifecycle suite.

| Piece | Source | Voxey |
| --- | --- | --- |
| strider | `ENTITIES/mobs_mc/strider.lua` | [`striders.gd`](../scripts/striders.gd) |
| hoglin, zoglin | `ENTITIES/mobs_mc/hoglin+zoglin.lua` | [`hoglins.gd`](../scripts/hoglins.gd) |
| Nether spawners | the `register_spawner` calls in `mobs_mc` | [`nether_spawns.gd`](../scripts/nether_spawns.gd) |

## The spawn tables

Voxey's Nether used to draw from one flat pool: piglin, magma cube, enderman,
wither skeleton and blaze, anywhere, plus a 30% chance of a ghast. The source
spawns by biome, and treats a fortress as its own structure table:

| Where | Monsters (weight, pack) |
| --- | --- |
| Nether wastes | zombified piglin 100 ×4, ghast 50 ×4, piglin 15 ×4, magma cube 2 ×4, enderman 1 ×1-4 |
| Crimson forest | hoglin 9 ×3-4, piglin 5 ×3-4, zombified piglin 1 ×2-4 |
| Warped forest | enderman 1 ×1-4 |
| Soul sand valley | ghast 50 ×4, skeleton 20 ×5, enderman 1 ×1-4 |
| Basalt deltas | magma cube 100 ×2-5, ghast 40 ×1 |
| Nether fortress | blaze 10 ×2-3, wither skeleton 8 ×5, zombified piglin 5 ×4, magma cube 3 ×4, skeleton 2 ×5 |

Three extra rules apply:

- A ghast's own position test passes only one time in twenty.
- Hoglins and piglins never spawn on a nether wart block.
- Striders are the creature category: weight 60, in packs of one or two, on
  lava with air above.

Blazes and wither skeletons now spawn only inside a fortress's footprint, as the
source's structure-only spawners have it. Zombified piglins now spawn naturally;
before this they came only from lightning-struck pigs.

## Strider

- **Body.** 20 health, `{fleshy = 90, water_vulnerable = 90}`, 9 experience. It
  is water-sensitive and fire-resistant, and runs when struck.
- **Lava.** It stands on the lava surface. Off lava it is cold: slower (0.66),
  shaking, darker, and driven at 0.35 instead of 0.55. While cold it looks
  every half second for the nearest lava with air above, within ±8 and ±2, and
  walks to it.
- **Drops.** Two to five string, or one to three string plus the saddle when
  saddled.
- **Feeding.** Warped fungus breeds it and grows a baby, but never heals it:
  `feed_tame` is called with no heal. It follows a player holding warped fungus
  or the warped-fungus stick.
- **Riding.** It takes a saddle, and shears take it back. It is driven with the
  warped-fungus stick, which also starts the pig's timed boost, through the
  generalised `PigRiding` drive. Its rider takes no lava damage.
- **Riders.** An adult carries a zombified piglin with a warped-fungus stick one
  time in thirty, and otherwise a baby strider one time in ten. Voxey records
  the pairing, as `SpiderClimb` does for its jockey, rather than simulating a
  mounted pair.

## Hoglin

- **Body.** 40 health, `{fleshy = 90}`, 9 experience, reach 3, one swing every
  two seconds. It never despawns.
- **Attack.** An adult deals `damage / 2 + random(0, damage − 1)`, which is 3 to
  8. It throws the target sideways by up to fourteen and up by up to twenty
  (ten for a mob), scaled by one minus the target's knockback resistance. A baby
  deals 0.5, throws nothing, and swings 0.375 as often.
- **Repellents.** Warped fungus, a nether portal or a respawn anchor within ±8
  horizontally and ±4 vertically keeps it passive toward players for ten
  seconds. It walks away from one closer than eight. The sensor runs every
  0.2 seconds.
- **Group fights.** A struck hoglin calls every visible hoglin within 16 to
  retaliate. A baby, or an adult outnumbered by the piglin that struck it,
  retreats instead: for five to twenty seconds, until fifteen away, or until the
  other hoglins outnumber the piglins.
- **Breeding.** Crimson fungus breeds it and heals it by 4. It does not trail a
  player holding the fungus, because it has no `follow` list. A fifth of
  natural spawns are babies.
- **Conversion.** Fifteen seconds in the Overworld turns it into a zoglin with
  ten seconds of nausea.
- **Drops.** Two to four porkchops and up to one leather, cooked if it dies
  burning.

## Zoglin

The undead hoglin: fire-resistant, `{undead = 90, fleshy = 90}`, harmed by
healing, and it never breeds. It attacks any player and any mob except creepers
and other zoglins.

Its definition is `table.merge (hoglin, ...)` with no `drops` field, so it keeps
the hoglin's porkchops and leather. That is ported as written.

## Also changed

- **Mob tint.** Creatures now return to a **rest tint** after a hurt flash
  rather than always to white. A cold strider stays dark, and a wet wolf's
  darker coat survives being hit.
- **Wolf collar.** The wolf's collar and eye colours are now kept in the colours
  the tint rebuilds from, so a hurt flash no longer turns the collar white.

## Recorded deviations

- Piglins hunting baby hoglins, and hoglins shying from piglins outside a fight,
  live in the piglin's AI, which is not ported here.
- The cold strider's purple texture is drawn as a darker tint, because Voxey's
  skins are tinted rather than swapped.
