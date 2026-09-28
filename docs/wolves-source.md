# Wolves

`mobs_mc:wolf` (`ENTITIES/mobs_mc/wolf.lua`) and the owner rules it uses from
`ENTITIES/mcl_mobs/breeding.lua`, ported in [`wolves.gd`](../scripts/wolves.gd).
Checks: `wolf` in the lifecycle suite.

## The animal

A wild wolf has 8 health and a tamed one 40 (`after_tame`). It deals 4 damage at
reach 2, leaps at its target, pays 1-3 experience and drops nothing. Like every
source animal it does not despawn. Voxey registers wolves with the farm-animal
registry, so wild and tamed wolves are both saved with the world.

## Taming and orders

A **bone** on a wild wolf that is not attacking tames it at 1 in 3, and the bone
is used either way. A new pet is owned by the player, sits, and heals to 40.

A tamed wolf's right-click runs through these cases in the source's order:

1. Food heals a hurt wolf by the food's value from `wolf_food`: 1 for
   pufferfish and tropical fish, up to 8 for cooked beef or pork and 10 for
   rabbit stew.
2. The owner's dye recolours the collar. The same colour again uses no dye.
   The sixteen collar colours are the source's `unicolor_*` table.
3. `feed_tame`: food grows a pup, or at full health puts a standing wolf in
   love.
4. Otherwise the owner's click toggles sitting.

## Who a wolf fights

The targeting rules, in order:

1. Whoever hurt the owner in the last five seconds, by melee or by projectile.
2. Whatever the owner struck in the last five seconds, by hand or by arrow.
   Creepers, ghasts, the owner's own wolves and tamed mobs are never followed.
3. Its own attacker. A wolf struck by the player turns on the player if it is
   wild, and calls every wild wolf within 16 to do the same. A tamed wolf never
   turns on its owner.
4. Sheep and rabbits, but only while wild.
5. Skeletons, wither skeletons and strays, always. In turn, skeletons and
   strays keep away from any wolf within six (`runaway_from`).

## Following

A tamed wolf that is not sitting walks back to its owner once further than 10.
It keeps coming until within 2. Beyond 12 it teleports to a walkable,
non-leaf floor cell within ±3 of the owner, taking ten tries as
`teleport_to_owner` does. A sitting wolf stays put, but it gets up to fight if
something other than its owner struck it in the last five seconds while the
owner is within 12 (`sit_if_ordered`).

## Breeding

Only tamed, standing wolves breed. The pup is born tamed to the owner, standing,
and takes one parent's coat and collar (`on_breed`).

## Look

- **Coat.** The coat is one of the source's nine variants, chosen by spawn
  biome. Voxey's meadow is the source's Forest (`woods`) and its cold highlands
  the SnowyTaiga (`ashen`). Everything else is `pale`. Voxey draws each variant
  as its own colour pair rather than using the source's textures.
- **Collar and tail.** A tamed wolf shows its collar, and its tail rises with
  its health (`get_tail_height`).
- **Angry.** An angry wolf's eyes glow red.
- **Wet.** Water or rain darkens the coat. On dry ground the wolf shakes for a
  second and dries.

## Spawning

Packs of four on grass, snow blocks or dirt. The source's weights are taiga 8
and forest 5, against a combined 40 for sheep, pigs, chickens and cows in the
same biomes. Voxey applies them as a share of the passive spawns in its cold
highlands and its meadow.

## Recorded deviations

- The source has wolves run from llamas by llama strength. Voxey has no llama
  mob yet (only the trader's escort), so there is nothing to run from.
- Wolf armour is a `TODO` in the checkout itself and is not invented here.
- The pup's begging head tilt is not drawn.
