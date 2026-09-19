# Totems of undying

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_totems/init.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## A lethal-damage interception

The reference registers a **damage modifier**, which is why the totem is not simply a "cancel the next hit" flag: the modifier *replaces* the incoming damage. The rules, all reproduced:

- The totem must be **carried**. The source checks the offhand when the main hand does not hold one, and Voxey reads both hands through the [second hand](offhand-source.md).
- The hit must be **lethal** — it only fires when the damage would take the holder to zero or below.
- The replacement is **exactly 1 HP**. The source returns `math.max(0, hp - 1)`, which is what leaves the holder alive at one health rather than at full health.
- **All effects are cleared first**, then three are applied: regeneration at level 2 for **45 seconds**, fire resistance for **40**, and absorption at level 2 for **5**.
- Breath is topped up to **10** when it had fallen below 11, which matters when the lethal hit was drowning.
- The totem is consumed — but **not in creative**. The source checks `is_creative_enabled` before taking the item.

## One reason bypasses it

A totem may be carried in either hand through the [second hand](offhand-source.md), so a weapon can stay in the main hand.

The source's `mcl_damage` flags list marks exactly one reason `bypasses_totem`: **`out_of_world`**, which is the void. Falling out of the world cannot be saved by a totem, and the totem is not consumed when it is bypassed. Both behaviours are reproduced.

## Where a totem comes from

The evoker drops one at `chance = 1`, which is always, and the [woodland cabin](woodland-cabins-source.md) is where evokers live. Before that structure existed the totem had no source at all: no drop, no recipe, no structure produced one, so the item existed and could never be obtained in survival. That is now closed.

## Recorded source gaps

- **Second hand is implemented.** The reference carries a totem in a dedicated offhand slot and checks both hands; Voxey reads both hands too.
- **No wield-view item.** The source registers a separate `totem_wielded` item so the held model differs from the inventory icon; Voxey has one icon.
- **The floating particles and HUD overlay are simplified.** The source raises four particle spawners in its own five colours and shows a three-second full-screen image. Voxey emits a single green puff and plays a sound.
- **No mob use.** The source's modifier also covers mobs, which raise their own `breath` and clear their wielded item. Voxey's totem is player-only.
- **Acquisition is absent.** In the reference a totem comes from evoker raids and woodland mansions, neither of which Voxey has, so the item is currently creative-only. That is the same dependency the raid work already records.
