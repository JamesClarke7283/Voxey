# Cats and parrots

Ported in [`cats.gd`](../scripts/cats.gd) (`ENTITIES/mobs_mc/ocelot.lua`, the cat
half) and [`parrots.gd`](../scripts/parrots.gd) (`ENTITIES/mobs_mc/parrot.lua`).
Checks: `companion` in the lifecycle suite.

Before this, Voxey had a black cat standing in each witch hut and parrots
perched in outposts and cabins. Neither did anything else.

## Cat

- **Stats.** 10 health, 0-2 string, 1-3 experience.
- **Despawning.** A wild cat may despawn. A tamed, fed or named one is kept with
  the world.
- **Coats.** Ten ordinary coats. Under a full moon the all-black coat joins them.
  A witch hut's cat is always all black.
- **Taming.** Raw cod or salmon tames a wild cat at one in three, and the fish is
  eaten either way. Feeding it at all makes it persistent. A new pet sits.
- **The owner's click.**
  - A dye recolours the collar, with the same sixteen colours as the wolf's.
  - Fish heals it by two while it is hurt. At full health, fish breeds a
    standing cat, and the kitten is born tamed with one parent's coat and
    collar.
  - Otherwise the click toggles sitting.
- **Following.** A tamed cat walks to its owner beyond ten and keeps coming to
  within five. Beyond twelve it teleports.
- **Resting.** An idle tamed cat picks a bed within three, or a chest or furnace
  within four, with room above. It walks there and sits for up to a minute.
- **Sleeping.** When its owner sleeps, every standing tamed cat within ten curls
  up on the bed. If the wake falls in the day's 0.25-0.30 window, seven times in
  ten it leaves a gift: rabbit hide, a rabbit's foot, raw chicken, a feather,
  rotten flesh or string, each equally likely.
- **Hunting.** A wild cat hunts rabbits.
- **Creepers** keep away from cats and ocelots (`creeper.lua`:27), through the
  same `runaway_from` rule that keeps skeletons away from wolves.
- **Village cats.** Every sixty seconds a cat may appear 8-31 nodes from the
  player, where there are at least five homes and no more than four cats within
  48. Voxey's villages each have thirteen homes at fixed places, and those are
  the homes counted.

## Parrot

- **Stats.** 6 health, 1-2 feathers, 1-3 experience, and five colours.
- **Taming.** Seeds tame a parrot at one in ten, and each seed is eaten. Parrots
  never breed.
- **Cookies.** A cookie kills any parrot outright and poisons it.
- **The owner's click** toggles sitting.
- **Following.** A tamed parrot follows its owner, beyond five until within one.
- **Perching.** Within reach of its standing owner, a tamed parrot perches on
  a free shoulder: left first, then right, and no more than two parrots. It
  rides there, and hops off when the owner is over air or in water or lava,
  waiting a second before it perches again.
- **Dancing.** Within three of a playing jukebox it dances and stays put.
- **Imitation.** Every thirty seconds it imitates a mob within twenty at 2.5
  times the pitch. One time in twenty it uses any mob's voice instead.

## Recorded deviations

- The ocelot, which shares the cat's file, is not ported, because it spawns only
  in the source's jungles and Voxey has no jungle biome.
- A parrot flies as Voxey's gliding bird rather than with the source's airborne
  pacing between leaves.
- A cat sitting on a chest does not stop the chest opening; the checkout does not
  implement that either.
