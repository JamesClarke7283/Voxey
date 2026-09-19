# Shields

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_shields/init.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## The blocking rule

A shield blocks the player's **frontal half**. The source decides that with a dot product:

```lua
local SHIELD_BLOCK_ARC = 180
local SHIELD_BLOCK_COSINE = -math.cos(SHIELD_BLOCK_ARC/2)   -- -cos(90°) ≈ 0
```

An attack is blocked when `dot(attack_direction, look_direction) <= 0` — exactly the hemisphere the player is facing. The attack direction is measured from the **shield centre**, which the source approximates as the eye height times two thirds, not from the player's feet.

Both values are reproduced: a 180° arc and a threshold of zero. An attack from straight ahead is dead centre; one exactly at the 90° edge is still blocked, because the source compares with `<=`.

## Only listed types are blockable

The source's `types` table is reproduced exactly. A shield blocks:

**mob · player · arrow · generic · explosion · dragon_breath · trident**

Everything else — fire, void, starvation, drowning, falling — passes straight through, whatever the angle.

## Raised, not timed

The shield is carried in the [second hand](offhand-source.md). Voxey previously borrowed the head armor slot as a stand-in, so a worn helmet could silently disable a shield; the real slot removes that conflict.

The earlier Voxey implementation raised the shield for **one second** on use. That is not the source's behaviour: the source holds the shield up for as long as the player keeps it raised. A shield is now raised while the player holds it and keeps sneak held, and read each step rather than set by a timer.

A shield that has been disabled — by an axe, in the reference — blocks nothing until it recovers.

## Wear

`add_wear` has two rules, both reproduced:

- A hit of **less than 3 damage** costs nothing at all.
- A hit of 3 or more costs durability equal to the **ceiling** of the damage.

The source's `_mcl_uses` of **336** is the durability. A shield that reaches it breaks and is removed.

## Recorded source gaps

- **Second hand, not main hand, is where it belongs.** The reference carries the shield in the dedicated [second hand](offhand-source.md) and `mcl_shields` reads whichever hand holds one. Voxey now has that slot and reads both hands, so the earlier main-hand-only limitation is closed.
- **No axe disable.** The source lets an axe disable a shield for a period; Voxey has the disabled state and honours it, but nothing currently disables a shield because there is no axe-versus-shield rule.
- **No blockable-projectile interception.** The reference intercepts arrows and tridents at the projectile level and deflects them. Voxey resolves the block at damage time instead, which leaves health untouched but does not physically deflect the projectile.
- **No shield model or HUD.** The source ships a 3D shield model and a blocking HUD overlay; Voxey draws the shield as an item icon only.
- The source's `_mcl_wieldview_item`, `_placement_class` and enchantability metadata have no equivalent here.
