# Cauldron liquids, washing and weather

The helper in `scripts/cauldrons.gd` adapts the user-provided Mineclonia source at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16. Source files are `mods/ITEMS/mcl_cauldrons/init.lua` and the `give_and_take` behavior in `mods/HUD/mcl_inventory/init.lua`. Attribution: Mineclonia and MineClone contributors; adapted rules are covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). No source visual assets were copied.

| Reference file | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_cauldrons/init.lua` | `cd6ebf43832bee184e5e5c4434c3bc4ff2717e3594c042aa5ec8df709047cba5` |
| `mods/HUD/mcl_inventory/init.lua` | `38e290c4ceaae45655fc8716e4d5fc711ef84b222d62f3c1a638c7456ad689e0` |
| `mods/ENVIRONMENT/mcl_weather/rain.lua` | `9fd1a690a03c6395f599ce03ad8be1ba7d2c37538e5f21449e84af42d7c143b6` |
| `mods/ITEMS/mcl_chests/init.lua` | `20e98f08ba3600295d40e75d9c31a3871657c029361979ae7b263917374c1d46` |
| `mods/ENTITIES/mcl_burning/api.lua` | `4c110158bf9f1ecc9b2f9f1f5e306962764cf97fd2554cc428222e6b012dd793` |

Water fills in three portions. A water bottle adds one; a glass bottle removes one. A water bucket fills an empty or partly water-filled cauldron, while an empty bucket retrieves water only when it is full. Lava buckets likewise fill and empty lava cauldrons. Incompatible liquids cannot mix, and glass bottles cannot collect lava. A bucket or bottle exchange preserves all remaining items, places the returned container in the selected slot when the held stack runs out, and returns overflow as a physical item drop when the inventory is full.

Creative behavior follows the source inventory modes: bucket actions change the cauldron without taking or returning containers; pouring water bottles preserves the held bottle and supplies one empty bottle only if an identical empty bottle is absent; extracting with a glass bottle preserves it and supplies each water portion. Bucket name changes preserve metadata for a single held bucket.

The existing saved `water` value remains the 0–3 fill level. A new `liquid` field distinguishes `water` and `lava`; old nonempty saves without it retain ordinary water. Comparators read the fill level directly. The optional dynamic surface helper shows each level at the source's 9/16, 12/16 or 15/16 height above the node bottom.

All fifteen noncanonical shulker colors wash back to purple using one water portion, following `mcl_chests/init.lua`. Washing changes only the held shell ID and preserves its count, wear, name, contents and item metadata. Creative washing also changes the existing box and spends water, as in the source. Empty and lava cauldrons cannot wash boxes, and purple boxes do not waste water. The transaction works in a full inventory without creating or dropping a duplicate box.

The visible shell and collision use the source's thirteen wall, floor and foot boxes. The basin floor remains at 5/16 regardless of fill. Players can enter the hollow basin while its rim and walls remain solid. Selection remains a full node, following the source selection box.

Contact checks run every half second. A burning player or creature in the basin is extinguished, consuming one water portion; actors that are not burning consume none. Lava contact refreshes five seconds of burning without consuming lava. The existing potion-effect system handles continuing damage and Fire Resistance. The highest equipped Fire Protection level reduces the initial burn duration using the source formula. Creative players and existing fireproof creature kinds are protected. Contact adapts the source's nearby-node lookup to Voxey's basin coordinates and liquid height, so standing on the rim or beside the outside wall does not reach through iron.

Exposed cauldrons gain one water portion every 56 seconds during existing rain or thunder, matching the source weather ABM interval. Eligibility uses the current weather setting, loaded chunks, immediate roof checks and existing sky-cover logic. Voxey's Sunwash desert and Frostpine highlands are its existing dry and snowy climates and do not collect rainwater. No additional weather simulation is introduced. Rain leaves lava unchanged and stops at level three. New empty cauldrons register when placed or streamed in, without first requiring player interaction. Partial rain progress is saved with the station; unloaded chunks and closed worlds do not accumulate catch-up fills.

Two source edge cases are deliberately guarded: the local Lua bottle handler permits pouring water into an already full cauldron, and its generic bottle extraction path has no defined water-bottle output for lava. Voxey refuses these actions without consuming anything. These are transaction safeguards, not claims of exact reproduction of those source bugs.

Integration calls `Cauldrons.use(game, position)` before generic potion drinking, while respecting the existing sneak bypass. `Cauldrons.level(station)` supplies comparator output. `Cauldrons.fill_model(station)` supplies the liquid surface to the existing station-display lifecycle. `Cauldrons.update(world, delta)` runs alongside existing active-world systems. `Cauldrons.boxes()` supplies matching visible geometry and collision.

`tests/cauldron_checks.gd` checks transfers, boundaries, liquid exclusion, metadata, overflow, creative behavior, serialization, recipe, all washable shulker colors, rain timing and eligibility, physical basin collision, player/creature extinguishing, ignition, resistance and source fire-protection duration. Its live checks also cover dispatch, comparators, placement registration and break/replacement behavior.

This batch does **not** establish complete `mcl_cauldrons` parity. River water and powder snow lack corresponding Voxey resource/bucket systems. Lava surfaces glow visually, but emitted block light remains separate work. `mcl_armor/leather.lua` washes dyed leather and `mcl_banners/init.lua` removes a carried banner's topmost pattern layer; Voxey currently has neither leather-dye acquisition/rendering nor portable layered banner metadata. Those washing paths depend on those missing systems and are not represented by metadata-only placeholders. A banner's base wool color is not a washable pattern. Voxey's existing globe pattern is attached to a placed banner station rather than a carried patterned item.
