# Boats and chest boats

Reference: `/home/impulse/.minetest/games/mineclonia/mods/ENTITIES/mcl_boats/init.lua`, particularly `boat.on_rightclick`, `boat:on_step`, `boat:on_death`, the chest-boat entity, and `mcl_boats.register_boat`. Cargo persistence and separate cargo drops follow `mods/ENTITIES/mcl_entity_invs/init.lua` (`drop_inv`, `register_inv`). Passenger exclusions follow the matching `mods/ENTITIES/mobs_mc` definitions' `can_ride_boat` flags.

## Playable loop

- Existing boats 837–841 remain oak, acacia, spruce, dark oak and birch. Chest boats 1250–1254 match those variants; jungle uses ordinary1260 and chest1261. All boats stack to one and burn for 60 seconds.
- Make each of the six classic boats from five matching planks in a U at a table. Oak, spruce, birch, jungle, acacia and dark oak are renewable through their trees and saplings; the former dye conversions are replaced with their source material recipes. Put a chest directly above a matching boat in the hand crafting grid to make its chest boat, matching the source recipe.
- Use a boat item on water or a clear block face to place it. Placement consumes one item only after a hull has successfully spawned, except in creative. It does not immediately board the player.
- Right click the hull to board; W/S row forward/backward, A/D turn, and Ctrl leaves the boat in the world. Touch movement and sneak controls use the same path. Boats can be left, revisited and boarded again. The source's boat-relative steering means looking around does not change the hull heading.
- Ctrl + right click a chest boat opens its 27 cargo slots, including the usual drag, split and shift transfer controls. Named boats keep their item name; cargo retains supported item metadata, including books, maps, enchantments, pouches and shulker contents.
- Punch a boat to damage it. Boats have four health, receive the source's 125% fleshy damage, and regenerate one health after each half-second without a hit. Destruction releases passengers and drops the hull and each cargo stack separately. Repeated destruction cannot repeat those drops. Creative breaks retain cargo and provide a hull item only when the player does not already have one; overflow drops safely.
- Dispensers launch the exact boat variant at water or air immediately above water. Dry or obstructed outlets eject a recoverable item, and droppers continue to eject items. Explosions damage hulls using Voxey's existing entity blast falloff; destroyed chest boats retain their normal cargo drops.

## Movement and passengers

The physical hull is 1 × 0.55 × 1, matching the source collision box. Substeps resolve terrain and other boats, including thin fences, walls and trapdoors. The boat floats 0.15 below the actual water surface, moves more slowly on land, sinks slowly when fully submerged, falls under gravity, and is destroyed by fire/lava contact. Ordinary travel caps horizontal velocity at eight blocks per axis per second, ice at 57.1, following the source. The source's tick-based forces are normalized to a 20 Hz reference so rendering rate does not alter steering. Boats also uproot crossed lily pads and return their item.

An empty boat automatically takes one eligible nearby mob within 1.3 blocks. An ordinary boat then has space for the player and that mob; a chest boat has one seat. Adult horses, iron golems, spiders, ghasts, dragons, end crystals and the existing full-sized magma cube cannot board. Only tiny slimes can board. Leashed or already mounted creatures are excluded from automatic pickup to prevent two owners moving the same actor. The current single-player game does not implement a second human passenger.

Passenger movement AI is suspended while seated; farm growth, love/breeding timers, chicken eggs and global potion effects continue. Releasing the mob resumes its prior physics setting. Specialized hostile attacks and ambient AI while aboard remain a difference from the full Luanti attachment system.

## Save and streaming design

`Boats` is a per-game service; `BoatEntity` owns a live hull. Permanent IDs and records live in the current dimension's `world.adventure_state.boats`. Each record includes the item ID/name, position, heading, speed, vertical motion, health, cargo, passenger and optional saved player seat. A normal save/reload restores occupied seats. Death and teleport/dimension travel dismount the player; the boat remains in its original dimension.

Hulls farther than 90 blocks or outside loaded columns sleep as records, then wake within 80 blocks in loaded terrain. Passenger records reuse the existing farm, villager and Nether resident keys through the lead serialization/resolution helpers. Generic passenger types are owned solely by the boat record and excluded from the separate alchemy snapshot. End-city generation recognizes sleeping boat passengers' guard keys. These distinctions prevent independent population restoration from duplicating passengers. Boat snapshotting runs before other creature snapshots; streaming restoration runs before population updates.

The service sanitizes loaded hull records and all 27 cargo slots. Destruction removes the persistent record before emitting drops, and hibernation emits no items. Boats never encode their cargo in the dropped boat item.

## Remaining source dependencies

Bamboo rafts and additional wood species require their missing material sets. Separate river-water physics requires river-water nodes; current Voxey water and flowing-water levels are supported. Source multiplayer attachment negotiation and client-side Luanti steering have no counterpart in this single-player Godot game. Fishing-hook retrieval of boats, timed piglin anger on chest access, and full entity burning integration are separate dependencies rather than silently approximated here.

Focused regressions: `godot --headless --path . --script res://tests/lifecycle_runner.gd -- boats`. They exercise real crafting/guide inputs, player use/steering, cargo UI, damage, water and collision, passenger identity, streaming, actual JSON saves, dimension travel and death.
