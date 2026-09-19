# Zombie villagers and the cure

Voxey follows the supplied Mineclonia `mods/ENTITIES/mobs_mc/villager_zombie.lua`. The implementation is original GDScript using the source as a behaviour reference; the model reuses the zombie's, as the source's definition merges the zombie wholesale.

## Why it mattered

The cure is the source's most famous villager mechanic, and it is the puzzle the igloo's basement is built around: a zombie villager and a real one locked underground, with the **brewing stand** needed to make a weakness potion and a chest for the golden apple.

## The rule, and the condition that is easy to miss

| Step | Source |
|---|---|
| 1. The creature must be suffering **weakness** | `mcl_potions.has_effect(self.object, "weakness")` |
| 2. Right-click with a **golden apple** | `wielditem:get_name() == "mcl_core:apple_gold"` |
| 3. Weakness and strength are cleared | `clear_effect` for both |
| 4. A cure timer of **3–5 minutes** starts | `self._curing = math.random(3*60, 5*60)` |
| 5. The creature **shakes** while curing | `self.shaking = true` |
| 6. It becomes a **villager** and the curer earns a discount | major + minor positive gossip |

The weakness condition is the part that matters and the part a naive implementation drops: **feeding a golden apple to a healthy zombie villager must do nothing.** Without that guard, every zombie villager becomes a free villager with one apple, and the potion step — the whole reason the igloo has a brewing stand — becomes pointless.

The test asserts this explicitly: no weakness refuses the apple, applying weakness enables it, and a plain apple never works.

## Details reproduced

- **Both effects cleared.** The source clears weakness *and* strength, so a cure cannot be stacked with a strength potion.
- **The creature cannot despawn while curing** (`self.persistent = true`), or a curing zombie could vanish before it finishes.
- **A second apple is refused.** The source guards on `not self._curing`, so the cure cannot be restarted or stacked.
- **The new villager remembers the curer**, recorded as the source's major (20) and minor (25) positive gossip, which is what makes a cured villager trade cheaply for the player who did it.
- **Only a zombie villager is curable.** The test checks that an ordinary zombie with weakness and an apple is still refused.

## A supporting addition

`PotionEffects.clear_one` was added. The module previously could only clear *all* effects on a target, but the cure must clear exactly two and leave the rest alone — clearing everything would strip a creature's other effects as a side effect of being cured. That is a general capability the source's own `clear_effect` has.

## Infection: where zombie villagers come from

The cure only matters because a villager can *become* a zombie villager. The source's
`villager:on_die` does that when a **zombie landed the killing blow**:

    difficulty >= 2 and zombie_types has the killer's name
    and (difficulty > 2 or pr:next(1,2) == 1)

Three things follow from that rule, and all three are implemented:

1. **A zombie has to hunt villagers.** The source gives a zombie `attack_npcs = true`. Zombies here went only for the player, so the killing blow could never happen — the infection rule would have been dead code. A zombie now takes whichever of the player or a nearby villager is nearer, and strikes that one.
2. **The gate is difficulty-scaled.** The easier difficulties never infect; the hardest always does; the middle one is a coin flip. `game.difficulty` supplies this, the same setting the Wither's health uses.
3. **The villager is not replaced by a stranger.** The source carries `_previous_incarnation`, so curing restores the *same* villager — same key, profession, trades and home. This is why a player cures rather than kills: the villager they knew comes back.

The record key matters here. A cure that spawns a fresh villager would leave the original record marked dead *and* add a second record, so the village would hold two entries for one villager. The incarnation takes its own key back and the placeholder is dropped.

## Recorded source gaps

- **No difficulty-scaled strength.** The source grants a strength effect whose level varies by difficulty. The base level is used, which is what the source gives on its easiest setting.
- **No gossip-driven trade discount yet.** The cure records the gossip on the new villager, which is the source's own bookkeeping, but Voxey's trading does not yet read it to lower prices. The data is in place for the trade system.
- **No sound or particle for the cure.** The source plays a dedicated cure sound (`mobs_mc_zombie_villager_cure`) and the vanilla cure particles. Voxey plays its existing zombie sound and uses the shaking offset, which is the source's only other visual.

