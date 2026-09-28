# Llamas

Ported in [`llamas.gd`](../scripts/llamas.gd) from `ENTITIES/mobs_mc/llama.lua`,
the llama half of `ENTITIES/mobs_mc/wandering_trader.lua`, and the llama rule in
`ENTITIES/mobs_mc/wolf.lua`. Checks: `llama` in the lifecycle suite.

Before this, Voxey had only the wandering trader's two llamas. They followed the
trader and did nothing else.

## The llama

The source builds the llama with `table.merge (horse, ...)`, so the wild llama
joins Voxey's horse family ([horses](equines-source.md)) for taming, food,
chests, breeding and saving. What is only a llama's lives in `Llamas`.

- **Stats.**
  - Health is the horse's `15 + random(0, 8) + random(0, 9)`.
  - Drops are 0-2 leather, and experience is 1-3.
- **Strength.** Strength is `1 + random(0, 2)`, or `1 + random(0, 4)` at a 4%
  chance. It sets the chest size and how readily wolves back off.
- **Coats.** There are four coats: brown, creamy, gray and white. The source's
  fifth texture is the creamy coat again, so creamy comes up twice as often.
- **Food.**

  | Food | Heal | Age (ticks) | Temper | Breeds |
  | --- | --- | --- | --- | --- |
  | wheat | 2 | 10 | 3 | |
  | hay bale | 10 | 90 | 6 | yes |

- **Taming.** Mount an untamed llama with an empty hand to start the horse's
  temper roll. A llama's temper stops at 30 (a horse's at 120), so it tames far
  sooner.
- **Riding.** A llama can be ridden but never steered (`should_drive` is false).
  A llama carrying a rider paces about on its own.
- **Chest.** A tamed llama takes a chest of strength × 3 slots, which is what the
  source's window shows. A sneaking click opens it.
- **Carpet.** A tamed adult takes a carpet as its decor, but only while it has
  none. Shears take the carpet back. A llama takes no saddle.
- **Breeding.** Only tamed llamas breed, on hay bales.
  - The cria's strength is `random(1, max(s1, s2))`, with one more at 5% up to
    five.
  - The cria takes one parent's owner but not the tamed flag, as the source does.
- **Following.** A llama follows a player holding a hay bale, from within six
  until it is within two. This batch adds the same rule for horses, donkeys and
  mules with golden carrots and golden apples.
- **Spit.**
  - A struck llama spits back rather than fleeing. It closes to within twenty,
    waits out the four-second ranged timer, spits once, and calls the attack
    off.
  - It then flees for whatever is left of the source's five-second runaway
    timer.
  - It spits at any untamed wolf within ten until the wolf leaves.
  - Spit flies at 40 under gravity, stops at the first block, and deals 1 to
    the first player or mob it meets.
  - A creative player is never spat at.
- **Wolves** run from a llama within sixteen whenever the llama's strength beats
  `random(0, 4)`. A wolf that has decided to run keeps running for two seconds.
- **Caravans.**
  - A llama that is not leashed joins the nearest llama within nine that is
    leashed. It can also join the last llama of a caravan with no more than
    seven ahead of it.
  - It walks after the llama ahead at the caravan's pace whenever it is more
    than three away.
  - Beyond 26 it speeds up by 1.2 at a time, to 3. Two seconds after that runs
    out, it gives up.
  - Releasing the lead llama breaks the caravan up, front first.
- **Spawning.** Packs of four to six in the Frostpine highlands, at weight 5
  beside the highlands' other animals. The highlands stand in for the source's
  hills.
- **Saving.** A llama is saved with the world like a horse, including its
  strength, coat, carpet, chest, contents and temper.

## The trader llama

The trader llama is `table.merge (llama, ...)`. It now rolls a llama's strength
and coat, spits back, spits at wolves, and frightens wolves. While its trader is
near, it counts as leashed, so wild llamas line up behind it. Its walking speed
is the wild llama's.

## Recorded deviations

- **Leads start caravans.** The source's `is_leashed` returns false and waits for
  leashes to exist. Voxey has leads, so a llama on a lead heads a caravan, as the
  source's comment intends. A llama put on a lead leaves the caravan it was in.
- **Chests need a tamed llama.** A llama takes a chest only once tamed, as
  donkeys and mules already do in Voxey. The source checks only that the
  inventory exists.
- **No savannah.** Voxey has no savannah biome, so the source's savannah spawner
  (weight 8, packs of four) has nowhere to run.
- **Trader llamas stay untamed.** A trader llama is not tamed or ridden. The
  source allows that only after its trader has gone, and Voxey's trader llama
  leaves on the same timer.
- **No alert receiver.** The source's alert receiver rule has nothing to receive,
  because the trader never raises an alert.
