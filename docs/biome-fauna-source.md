# Biome-only fauna

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-25.
Source-derived spawn tables and behavior retain GPL-3.0-or-later attribution.

Canonical biome selection made two previously unreachable source creatures
possible. Their rules are implemented in `scripts/biome_fauna.gd` and connect
to the existing cow/stew and cat systems rather than duplicating them.

## Mooshrooms

`MushroomIslands` now generates mycelium on its exposed surface and down three
blocks. The source spawner (`cow+mooshroom.lua:243-261`) names only that biome,
uses weight 8, packs of four to eight, and requires a mycelium support block;
the shared animal spawner also requires light above eight. `BiomeFauna` applies
those conditions and spawns packs through `Game.spawn_creature`.

Mooshrooms keep the already-tested cow lifecycle: wheat breeding and growth,
bucketing, bowl stew, brown/red flower storage, suspicious stew, shearing into
a cow, and lightning colour changes. No second stew or breeding implementation
was added.

## Ocelots

The source registers an infrequent monster-category jungle spawner
(`ocelot.lua:1110-1156`): weight 2, a one-in-three position roll, a grass or
leaves floor, and packs of one to three in `Jungle` or one in `BambooJungle`.
Ocelots are ten-health animals with no drops and one-to-three experience.

An untrusted ocelot flees a player within eight nodes and has no tame flag. A
player holding raw cod or salmon within six draws a shy follow; between two and
six nodes it walks after them. A click while it follows consumes one fish and
gains trust one time in three; every attempt keeps the ocelot persistent.

A trusting ocelot no longer follows shyly. Fish heals it by two, and fish at
full health starts breeding. Its child is a tamed cat owned by the player,
using the existing `Cats` model, coat, collar, persistence and interaction.
Trust and the following flag have a bounded saved record.

## Verification

```sh
godot --headless --path . --script tests/lifecycle_runner.gd -- biome_fauna
godot --headless --path . --script tests/lifecycle_runner.gd -- biome_fauna companion biome_map mooshroom_stew
```

The focused suite covers real `MushroomIslands` and `Jungle` generators, loaded
column support, light and obstruction, pack bounds, the one-in-three roll,
follow/stop ranges, trust attempts and fish consumption, healing, breeding,
cat offspring, and saved trust. It passes 27 checks; the combined adjacent set
passes 148.

This does not add natural mushroom-island vegetation, ocelot avoidance animation,
or source pathfinding. Ocelots use Voxey movement and the existing cat renderer
for their offspring.
