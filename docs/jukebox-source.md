# Jukeboxes and music discs

Reference: local Mineclonia `mods/ITEMS/mcl_jukebox/init.lua` and `README.md`,
`mods/ITEMS/REDSTONE/mcl_comparators/init.lua`,
`mods/ITEMS/mcl_hoppers/init.lua`, `mods/CORE/mcl_util/environment.lua`, and
`mods/ENTITIES/mobs_mc/creeper.lua`.

The implementation uses all **eight actually registered** source records. Extra
unused texture names and the README's old nine-track count are not playable
registrations. Existing Mall item1107 remains unchanged for inventory/save and
Bastion-loot compatibility. Jukebox6800 and records6810–6816 are new items.

| Disc | Recording | Comparator | Acquisition |
| --- | --- | ---: | --- |
| 13 | The Evil Sister (Jordach's Mix) | 1 | Skeleton-arrow creeper; dungeon treasure |
| Wait | The Energetic Rat (Jordach's Mix) | 12 | Skeleton-arrow creeper |
| Blocks | Eastern Feeling | 3 | Skeleton-arrow creeper |
| Far | Minetest | 5 | Skeleton-arrow creeper; dungeon treasure |
| Chirp | Soaring over the sea | 4 | Dungeon treasure |
| Strad | Winter Feeling | 9 | Skeleton-arrow creeper |
| Mellohi | Synthgroove (Jordach's Mix) | 7 | Skeleton-arrow creeper; stronghold treasure |
| Mall | The Clueless Frog (Jordach's Mix) | 6 | Existing source Bastion treasure |

Eight mixed planks surrounding a diamond craft one jukebox in both the recipe
book and manual grid. Hardness2, blast resistance6, axe preference, fuel15s and
piston immovability follow the source. It does not spread fire. Records stack to
one. Original Voxey cabinet and vinyl art is generated procedurally.

Right-click inserts one record into an empty box, preserves its item metadata,
and starts its actual Ogg recording. Source insertion consumes a record even in
creative mode. Right-click an occupied box ejects exactly one stored record; it
does not swap the held record. Repeated held use is latched. Ejection, breaking
and replacement stop playback, and content removal precedes generic station
cleanup to prevent double drops. Creative breaking still returns the inserted
record. Sneaking keeps ordinary adjacent-block placement available.

Playback is spatial, one-shot and audible within65nodes. Audio settings mute active
tracks even in menus. Leaving hearing range silences a loaded box naturally;
returning hears the same recording at its current position. Finishing and world
reset remove runtime players. Column unload also stops playback as a bounded
Voxey streaming adaptation. Saved discs and names persist; source sound handles
are transient, so loading a save never auto-restarts a record. A stored record
continues to supply its comparator value after the
music ends. There is no playlist, invented looping, or hopper automation:
source container group7 blocks both insertion and extraction. Hoppers can still
collect already-ejected loose items normally.

A real skeleton arrow can strike intervening mobs. Its shooter identity is set
by the skeleton AI. Only an immediate fatal skeleton/stray arrow hit awards one
uniformly selected record from13/Wait/Blocks/Far/Strad/Mellohi. Player and
dispenser arrows are excluded, solid walls block the hit, duplicate callbacks
are guarded and nonfatal earlier hits never contaminate a later damage cause.
Voxey currently spawns skeletons; the source-compatible stray identity hook is
ready for that future species. Existing player-arrow behavior is preserved.

Stronghold Mellohi chance retains the source's full102-entry weight total and
2–3rolls rather than renormalizing around unavailable armor. It is an additional
source disc roll alongside Voxey's existing stronghold loot; replacing the
entire legacy loot pool is outside this feature. Dungeon acquisition is covered
by the companion dungeon implementation and its three source-weighted loot
pools, with unavailable entries retained as zero-output rolls.

Audio is copied byte-for-byte from the local source. Six tracks are CC0;
“Soaring over the sea” is CC BY3.0 and “Winter Feeling” is CC BY-SA3.0.
[Complete attribution and recording/license links](../assets/audio/jukebox/ATTRIBUTION.md)
are bundled, embedded in the module for exported credits, and summarized while
playing. No music was synthesized or substituted, and no source textures copied.

`tests/jukebox_checks.gd` exercises actual mouse input, mixed crafting, all eight
Ogg resources, live comparator and hopper behavior, ejection/break deduplication,
muting while paused, runtime cleanup, true skeleton firing and arrow collisions,
weighted eligibility, metadata and actual file save/load.
