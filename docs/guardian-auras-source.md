# Guardian auras: mining fatigue and thorns

Voxey follows the supplied Mineclonia `mods/ENTITIES/mobs_mc/guardian_elder.lua` (its `ai_step`) and `guardian.lua` (its thorns response). The implementation is original GDScript using the source as a behaviour reference.

## Why it mattered

Voxey had the guardians and their laser attack, but two of the source's rules were missing — and one of them is the **monument's real obstacle**:

| Behaviour | Source |
|---|---|
| **Elder's mining fatigue** | Every 60 s, fatigue level 3 for 5 minutes, to every player within **50 blocks** |
| **Guardian's thorns** | 2 damage back to a melee attacker, unless pacing |

The fatigue aura is what makes mining through a monument a grind rather than a fight. Without it, an ocean monument is just a room with mobs in it; with it, the elder's presence changes how the whole structure is played.

## What the source does

The elder's `ai_step` runs its own counter:

```lua
self._fatigue_counter = (self._fatigue_counter or 60) + dtime
if self._fatigue_counter > 60 then
    self._fatigue_counter = self._fatigue_counter - 60
    for player in ... do
        if vector.distance(pos, self_pos) <= 50 then
            mcl_potions.give_effect_by_level("fatigue", player, 3, 300)
```

Two details reproduced exactly:

- **The counter subtracts a whole interval** rather than resetting, so a slow frame does not lose the difference.
- **The range is fifty blocks**, so a player who has left the monument is spared.

The guardian's thorns is gated on the guardian's own **movement goal**: a guardian in `go_pos` movement (pacing) does not retaliate, which stops a pacing guardian from punishing a player who merely bumped into it.

## A supporting addition

`fatigue` was added to Voxey's effect list, and `PotionEffects.mining_speed` gives it its only real consequence — block-breaking time. The aura previously had no effect to apply, so it would have been a no-op that reported success.

## Recorded source gaps

- **No apparition or eerie sound.** The source carries a TODO for the elder's ghostly apparition and the eerie noises that accompany the fatigue. Voxey applies the effect silently.
- **No thorns against a bypassing attacker.** The source exempts damage flagged `bypasses_guardian`, which covers a few special sources. Voxey's `retaliates` accepts the flag and honours it, but nothing in Voxey yet sets it, so the exemption is present and unused.
- **The attacker is identified by proximity.** The source knows the attacker from the damage event itself. Voxey's `hit` receives a position, so the attacker is whoever is standing within 1.5 blocks of where the blow came from. That is accurate for melee, which is the only case the source retaliates against, but it is inference rather than identity.
- **Fatigue does not stack with itself.** The source re-applies the effect each cycle, which refreshes its five-minute duration. Voxey's `apply` refreshes the duration too, so repeated cycles keep a nearby player fatigued for as long as they stay — the same outcome.
