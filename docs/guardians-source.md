# Guardians

Voxey follows the supplied Mineclonia `mods/ENTITIES/mobs_mc/{guardian,guardian_elder}.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or mesh is copied.

## Why they mattered

Guardians were the single largest blocker in this project. Three separate systems had recorded them as a missing dependency:

| Gap | Closed by |
|---|---|
| The conduit's prismarine frame had no material | Prismarine shards and crystals |
| The sponge had no survival route | The elder guardian's wet sponge |
| The ocean had no mobs | Guardians themselves |

Implementing guards closes all three at once, which is why they were worth the creature work.

## The laser

A guardian never touches its target. The source's `attack_null` charges a laser while tracking the player and then deals magic damage plus a physical punch:

- **Charge time**: 4 seconds for a guardian, **3** for an elder (`_default_laser_delay`).
- **Damage**: 6 for a guardian, 8 for an elder. The magic component is the source's `magic_damage` of 1.0.
- **Minimum distance**: a guardian refuses to attack anything inside **three blocks**, which the source's `get_active_target` enforces as a squared distance of 9. Inside that it paces and breaks off instead.
- **`swims = true`**: guardians are aquatic, hold their depth in water rather than falling, and never drown.

## The drop table

This is the part that carries the materials. The source's `chance` field is a **denominator** — `chance = 1` is always and `chance = 4` is one in four — which Voxey's shared creature drop tuples cannot express, so the rolls live in the module.

| Drop | Chance | Range |
|---|---|---|
| Prismarine shard | always rolled | 0–2 |
| Prismarine crystals | 1 in 4 | 1–2 |
| Raw cod | 1 in 4 | 1 |
| Raw cod, salmon, pufferfish | 1 in 160 each | 1 |
| **Wet sponge** (elder only) | always | 1 |

The shard's range starting at zero is what makes "always rolled" not mean "always dropped" — some kills yield no shard, which is the source's own behaviour and is preserved rather than smoothed over.

A wet sponge smelts into a dry sponge, which completes the sponge's survival chain.

## Recorded source gaps

- **No ocean monument.** In the reference guardians concentrate in monuments and sponge rooms generate inside them. Voxey spawns guardians in deep ocean water instead, which yields the same materials without the structure. The monument is a structure batch of its own.
- **The laser is not rendered.** The source tracks the eye bone to the target and the client draws a beam; Voxey deals the damage at the end of the charge and shows a particle puff, so the charge is not visible while it builds.
- **No elder-mining-fatigue effect.** The reference's elder guardian applies Mining Fatigue to nearby players; Voxey's potion system has no mining-fatigue effect to apply.
- **The eye-tracking and pitch animation is not reproduced.** Voxey's guardian model is a spiked orb with a fixed forward eye.
- **Spawning is probabilistic in deep water** rather than tied to a monument's bounding box, so guardians are less concentrated than the reference's.
