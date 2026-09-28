# Horses, donkeys, mules and skeleton horses

`ENTITIES/mobs_mc/horse.lua`, with the skeleton trap from
`ENVIRONMENT/mcl_lightning/init.lua`, ported in
[`equines.gd`](../scripts/equines.gd). Checks: `equine` in the lifecycle suite.

Voxey's horse was a fixed-stat animal tamed by feeding it three times. It is now
the source's horse, and it has its family around it.

## Every horse is its own animal

- **Rolled statistics.** Health is `15 + random(0, 8) + random(0, 9)`, jump
  strength `(0.4 + 3 × 0.2 × random) × 20` (8 to 20), and speed
  `(0.45 + 3 × 0.3 × random) × 20 × 0.25` (2.25 to 6.75).
- **Donkeys and mules.** They roll only health. Their speed is fixed at 3.5 and
  their jump at 10.
- **Coats.** Seven base colours (brown, dark brown, white, grey, black,
  chestnut, creamy) with five markings (none, white dots, black dots, white
  field, and stockings with a blaze).
- **Foals.** A foal's statistics are the source's `child_properties` blend of
  its parents, and it takes one parent's coat with a one-in-nine mutation of
  each part.

## Taming

Mounting an untamed horse with an empty hand starts the evaluation. On average
every 2.5 seconds it rolls `random(1, 120) <= temper + 1`. Success tames it to
the rider. Failure adds 5 temper and throws the rider. Holding any item angers
it instead of mounting it. Food adds temper as well:

| Food | Heal | Age (ticks) | Temper | Breeds |
| --- | --- | --- | --- | --- |
| wheat | 2 | 20 | 3 | |
| sugar | 1 | 30 | 3 | |
| hay bale | 2 | 20 | 3 | |
| apple | 3 | 60 | 3 | |
| golden carrot | 4 | 60 | 5 | yes |
| golden apple | 10 | 240 | 10 | yes |

Skeleton and zombie horses eat nothing.

## Equipment and riding

- **Steering.** Only a tamed, saddled horse answers the reins
  (`should_drive`). Holding jump charges it, and releasing on the ground leaps
  by the source's charge curve times that horse's own jump strength.
- **Armour.** Horse armour sets the share of fleshy damage that lands: leather
  88, copper 86, iron 85, gold 60, diamond 56. Copper, iron, gold and diamond
  horse armour are new items. They are found in dungeon chests at the source's
  weights of 15, 15, 10 and 5, which filled the placeholder entries the dungeon
  table already reserved.
- **Chests.** Donkeys and mules take no armour. A tamed one takes a chest of
  fifteen slots instead, opened with a sneaking click.
- **Shears** take the armour back first, then the saddle.
- **Death** drops the saddle, the armour, and the chest with everything in it.

## Breeding

Tamed horses and donkeys breed on golden food:

- horse and horse make a horse;
- donkey and donkey make a donkey;
- horse and donkey make a mule;
- mules never breed.

## The skeleton trap

A lightning strike onto open air becomes a trap horse, rather than a fire, at
`regional difficulty × 0.01`. A player within ten springs it: a strike, three
more tamed skeleton horses, and a skeleton rider on each. An unsprung trap
leaves after 900 seconds. Skeleton and zombie horses are undead, so healing
harms them.

## Spawning

Horses come in herds of two to six and donkeys alone, in Voxey's meadow, which
stands for the source's plains and meadow. They are no longer part of the
generic animal pool. All horses in a loaded area are saved with the world, with
their statistics, coat, temper, armour, chest and trap age.

## Recorded deviations

- **The tamed flag.** Voxey keeps its `trust` field as the tamed flag, with 3
  meaning tamed, so existing saves and leashed-animal records keep working.
- **Ride feel.** Ride speed and jump are the source's statistics scaled so an
  average horse keeps Voxey's old feel: speed × 8 / 4.5 and jump × 9.5 / 14.
- **The trap's riders.** They carry no enchanted helmet, because Voxey's mobs
  wear no armour.
- **The horse inventory.** The saddle and armour slots are not a window; they
  are equipped and removed with items and shears, as above.
