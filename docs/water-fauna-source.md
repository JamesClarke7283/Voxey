# Dolphins and axolotls

Checks: `water_fauna` in the lifecycle suite.

| Mob | Source | Voxey |
| --- | --- | --- |
| dolphin | `ENTITIES/mobs_mc/dolphin.lua` | [`dolphins.gd`](../scripts/dolphins.gd) |
| axolotl | `ENTITIES/mobs_mc/axolotl.lua` | [`axolotls.gd`](../scripts/axolotls.gd) |

## Dolphin

- **Stats.** 10 health, 2.5 damage at reach 2, 1-3 experience, and 0-1 raw cod.
- **Fighting.** It is neutral. It retaliates on whatever strikes it except a
  guardian, and calls the dolphins within 16 to join.
- **Air.** It holds 240 seconds of air under water and refills at the surface.
  Below five seconds it heads straight up.
- **Moisture.** Out of water and out of the rain it dries for 120 seconds, then
  takes one damage a second. Drying and drowning are not an attacker, so they do
  not provoke it.
- **Swimming with the player.** It joins the nearest swimming player within 16
  and stays within 2.5. Each tick, at one in six, it grants **Dolphin's Grace**
  for five seconds. Dolphin's Grace now multiplies the player's swimming speed
  by 1.6, as `mcl_potions` does. Before this it was a name with no effect.
- **Boats.** It swims alongside the player's boat while the boat is moving.
- **Treasure.** Raw cod, salmon or tropical fish feeds it. A fed dolphin with air
  leads toward the nearest chest within 64 nodes horizontally, from 16 below it
  to one above it, and stops two nodes short. Generated shipwreck and ruin
  chests qualify, because their loot stations exist from the moment their
  column loads.
- **Breaching.** Every half second, at one in ten, it leaps out of the water when
  water lies ahead with two air cells above it. The leap adds `(dx × 12, 14,
  dz × 12)` to its velocity and falls under gravity until it splashes down.
- **Spawning.** In pods of one or two in deep ocean water, at weight 1 against
  the ocean's other water creatures.

**Source quirk.** `dolphin_return_to_water_1` returns `nodes[0]`, which is always
nil in a Lua array. A beached dolphin therefore never walks back to the water
and dries out unless it rains. Ported as written.

## Axolotl

- **Stats.** 14 health, 2 damage at reach 2, 1-7 experience, no drops. It may
  despawn: a wild one is removed rather than saved once far from the player,
  unless it was bred, bucketed or named, which the source marks persistent.
- **Colours.** Seven, chosen at random when it appears, and kept through saves
  and buckets.
- **Air.** It breathes in water, and holds 300 seconds of air out of it before
  taking one damage a second. Rain keeps it wet.
- **Playing dead.** A sourced hit in water triggers it at one in two, if
  `random(0, 2) < damage` or it is below half health, and only if the hit would
  not kill it. It rolls onto its side, stops, hunts nothing and regenerates for
  ten seconds.
- **Hunting.** It always hunts guardians. It hunts dolphins, cod, salmon,
  tropical fish, squid and glow squid unless it is on its 120-second cooldown,
  which a kill starts. If the player had struck the victim and stands within 20,
  the kill gives them five more seconds of regeneration (up to 120) and clears
  their mining fatigue.
- **Feeding and buckets.** A bucket of tropical fish feeds and breeds it and
  leaves a water bucket. A water bucket catches it as a **bucket of axolotl**
  (a new item) that keeps its name and colour, and it is persistent once
  released. Catching one awards **The Cutest Predator**.
- **Spawning.** Packs of four to six in covered water, under a cap of five of
  its own.

## Recorded deviations

- The source spawns axolotls only over **clay** in its lush-cave biome. Voxey's
  lush caves carry moss rather than clay pools, so covered water over clay or
  moss qualifies.
- A dolphin's retaliation against another mob (rather than the player) is not
  drawn as a chase; only the pod call is.
