# Magma blocks

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_nether/init.lua` (`mcl_nether:magma`). The implementation is original GDScript using the source as a behaviour reference; the texture is original procedural art.

## Why it mattered

Magma was absent, and it is not a decorative block — the source gives it real behaviour that makes it dangerous to walk on:

| Behaviour | Source |
|---|---|
| Burns whoever stands on it | `register_globalstep_slow`, one damage per slow tick |
| **Sneaking prevents the burn** | `player:get_player_control().sneak` |
| **Fire resistance prevents it** | `mcl_potions.has_effect(player, "fire_resistance")` |
| **Frost Walker boots prevent it** | `mcl_enchanting.has_enchantment(armor_feet, "frost_walker")` |
| Eternal fire | `_on_ignite = eternal_on_ignite` |
| Light | `light_source = 3` |
| Crafting | Four magma cream in a square |

The three exemptions are the interesting part: all three are implemented, so a player has three distinct ways to cross a magma field — sneak, drink fire resistance, or wear Frost Walker boots. That is the source's own design, not a simplification.

## Eternal fire

A fire lit on magma becomes **eternal** fire, exactly as it does on netherrack. Voxey's fire system already modelled that rule for netherrack and bedrock, so magma joins the same check rather than getting a parallel path.

## The recipe

Four magma cream in a square, which is the source's `_mcl_crafting_output = {square2 = {output = "mcl_nether:magma"}}`. Magma cream is already obtainable from magma cubes and from brewing, so the block is reachable in survival.

## Recorded source gaps

- **No animated texture.** The source's magma texture is a 1.5-second vertical animation. Voxey's block art is a static procedural crust with molten veins, which is the animation's middle frame rather than a moving image.
- **No `_mcl_blast_resistance`.** Voxey's block table does not carry blast resistance as a per-block field.
- **Not a group member for other source rules.** The source places magma in the `fire` and `material_stone` groups, which other mods read (for example fire spread). Voxey's block table has no group registry, so those consumers do not see it; the eternal-fire rule is wired directly instead.
- **No soul-fire variant.** The source has no magma variant, so there is nothing to port here.
