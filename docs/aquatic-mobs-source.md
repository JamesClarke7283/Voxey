# Aquatic creatures

Voxey follows the supplied Mineclonia `mods/ENTITIES/mobs_mc/{cod,salmon,pufferfish,tropical_fish,squid+glow_squid}.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

Voxey had **every fish item already** — raw cod, raw salmon, pufferfish, tropical fish, ink sac — but **no fish**. The fishing table made the items obtainable while never drawing a single creature, so:

- Nothing lived in the ocean except guardians.
- A player could never see a fish, catch one, or farm one.
- The **ink sac had no mob at all**, and the glow ink sac did not exist as an item.

These are the source's own creatures, with its own sizes, health and drop chances.

## What the source does

| Creature | Health | Drops |
|---|---|---|
| Cod | 3 | Raw cod always, bone meal 1 in 20 |
| Salmon | 3 | Raw salmon always, bone meal 1 in 20 |
| Pufferfish | 3 | Pufferfish always, bone meal 1 in 20 |
| Tropical fish | 3 | Tropical fish always, bone meal 1 in 20 |
| Squid | 10 | Ink sac ×1–3 always, glow ink sac 1 in 10 |
| Glow squid | 10 | Glow ink sac ×1–3 always |

Every fish yields **its own** raw item, which is what makes catching one worthwhile.

The source's `chance` field is a **denominator**, so `chance = 20` is one in twenty. Voxey's shared creature drop table cannot express a denominator, so these rolls live in their own module — the same approach the guardian drops required.

## Behaviours ported

- **Sizes.** The source's `collisionbox` for a cod is 0.6 wide and 0.79 tall; a squid is larger at 0.8 × 0.9. Both are reproduced.
- **Swimming.** `swims = true`, so the creatures hold their depth in water instead of falling.
- **Fleeing.** `runaway_from = {"players"}` with `runaway_view_range = 8`. A fish keeps away from a nearby player *without* being provoked first. This joins Voxey's existing flee decision ahead of the velocity it feeds, rather than being a parallel rule.
- **Spawning.** Fish and squid spawn in any submerged cell with water above, beside the existing guardian spawn.

## The glow ink sac

Voxey had no glow ink sac item, so a glow squid could not have existed. It is registered at id **861** with the source's name, `Glow ink sac`. Before choosing that id I confirmed 861 was free — an earlier attempt used 793, which was already **Raw beef**, and the compiler caught the collision.

## Recorded source gaps

- **No schooling.** The source gives salmon `_school_size = 5` and a school-following `do_go_pos`, so salmon swim in groups. Voxey spawns them individually.
- **No flop-out-of-water behaviour.** The source sets `flops = true` and `breathes_in_water = true`, so a fish on land flops and suffocates. Voxey's creatures do not leave water on their own, so this has no path to trigger.
- **No squid propulsion.** The source has a scale/`liquidtype` swim model. Voxey's squid drifts with the shared swim behaviour.
- **No dolphin.** The source ships `dolphin.lua`; it is not implemented here, and it is the one aquatic creature left out of this batch.
- **Body colours are Voxey's own.** The source's fish differ by texture, which Voxey does not copy; each species gets its own procedural colour instead.
