# Canonical biome map

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-25.
Source-derived registrations and filter data retain GPL-3.0-or-later attribution.

`BiomeMap` is a pure `RefCounted` registry for the 64 canonical biome names in
`MAPGEN/mcl_levelgen/biomes.lua:1712-6601`. It provides the string identities,
base climate values, groups, legacy-name resolution and source structure-filter
membership needed by the plant-generation and structure slices. It does not
choose a biome at a position.

## Parent API

The script has no scene, world, file, RNG or engine-noise dependency and can be
used from a generation worker. Constants and definitions are read-only. The ID
and group-list queries return new arrays, so a caller may sort or edit those
results without changing the registry.

- `DEFINITIONS: Dictionary` — canonical ID → source registration subset:
  `temperature`, `downfall`, base `groups`, and underground metadata where
  applicable. There are deliberately no numeric IDs.
- `ALIASES: Dictionary` and `LEGACY_SUFFIXES: Array` — read-only legacy input
  mappings. Their keys are not canonical biome registrations.
- `GROUP_RULES` / `TAG_RULES` — source post-registration group and structure-tag
  selectors. `groups()` includes their effective results; `DEFINITIONS.groups`
  retains the original base registration groups.
- `canonical(id: String) -> String` — exact, case-sensitive canonical ID, or
  `""` for an unknown name. Canonical names pass through unchanged.
- `is_canonical(id) -> bool` / `known(id) -> bool` — exact-registration and
  canonical-or-alias recognition respectively.
- `definition(id) -> Dictionary` — resolved definition, or `{}`. Treat the
  returned dictionary and its nested values as read-only.
- `temperature(id) -> Variant` / `downfall(id) -> Variant` — source value, or
  `null` for an unknown ID. These are biome properties, not a temperature/noise
  sampling API.
- `is_underground(id) -> bool` — distinguishes the three underground biome
  registrations (`DripstoneCaves`, `LushCaves`, `DeepDark`).
- `canonical_ids() -> Array` — sorted canonical names only.
- `groups(id) -> Array` — sorted effective base, derived and structure groups;
  empty for unknown IDs.
- `allows(filter: String, biome_id: String) -> bool` — **filter first, biome
  second**. The filter can be an exact canonical/legacy ID, `#is_taiga`, bare
  `is_taiga`, or a structure tag such as `#has_trail_ruins`. Unknown filters fail
  closed.
- `build_biome_list(filters: Array) -> Array` — sorted, de-duplicated canonical
  expansion, corresponding to `mcl_levelgen.build_biome_list` for recognized
  inputs.
- `members(group_name: String) -> Array` — convenience expansion with or
  without the leading `#`.

Typical integration is therefore:

```gdscript
var id := BiomeMap.canonical(raw_id)
if BiomeMap.allows("#has_jungle_temple", id):
    pass
var climate: Dictionary = BiomeMap.definition(id)
```

Structure planners must still sample the biome at the source-required final
candidate position. `allows()` only evaluates an already sampled identity; it
does not turn a chunk-origin or surface query into a 3D query.

## Source distinctions retained

The audited plant biomes are `Taiga`, `OldGrowthPineTaiga`,
`OldGrowthSpruceTaiga`, `MushroomIslands`, `BambooJungle`, and `LushCaves`.
Their temperature/downfall pairs are respectively `0.25/0.8`, `0.3/0.8`,
`0.25/0.8`, `0.9/1.0`, `0.95/0.9`, and `0.5/0.5`.

- Ordinary and old-growth taigas share `is_taiga`, but remain separate exact
  IDs. Only ordinary `Taiga` has `has_village_taiga`; the old-growth pair and
  `SnowyTaiga` do not acquire it. Outposts likewise name ordinary `Taiga`, not
  every taiga. Trail ruins explicitly include ordinary, snowy and both
  old-growth taigas.
- `BambooJungle`, `Jungle`, and `SparseJungle` share `is_jungle`. Jungle temples
  include only the first two. Trail ruins include `Jungle`, not
  `BambooJungle`. Jungle ruined portals use the whole group.
- `LushCaves` is underground metadata, not a surface alias. Its source
  multi-noise registration uses depth `0.2..0.9` and humidity `0.7..1.0`
  (`biomes.lua:1551-1572`). `DeepDark` is separately underground at depth 1.1
  and receives `mineshaft_blocking`, not `has_mineshaft`.
- `MushroomIslands` has only the base `is_overworld` group. It is not inserted
  into ocean, river, jungle, taiga, forest, hill or mountain groups. Thus it is
  excluded from outposts, villages, trail ruins, jungle temples and monument
  surroundings, while retaining its explicit mineshaft/standard-portal and
  overworld-wide stronghold/trial-chamber eligibility.
- `is_mountain` is exactly `CherryGrove`, `FrozenPeaks`, `JaggedPeaks`,
  `Meadow`, `SnowySlopes`, and `StonyPeaks`. Windswept hills use `is_hill`.
  Outposts combine the mountain group with explicit biomes including `Grove`;
  mountain ruined portals include both mountain and hill groups.

The registry also preserves two source details rather than “repairing” them:
`ColdOcean` lacks `is_overworld`, and `FrozenRiver` lacks `is_river` in this
checkout. Deep oceans acquire `is_ocean` through the post-registration rule at
`biomes.lua:6655-6658`.

Structure selectors come from the actual `modify_biome_groups` calls in
`mcl_levelgen`, `mcl_villages/lg_register.lua`, `mcl_end/end_city.lua`, and the
relevant mob registration. They describe the non-ersatz structure forms. For
example, buried treasure uses `#is_beach`, and End cities use End Highlands and
End Midlands; the conditional ersatz broadening is not mixed into those rules.

## Legacy aliases

`MAPGEN/mcl_levelgen/ersatz.lua:70-137` and
`MAPGEN/mcl_biome_dispatch/init.lua:135-167,225-308` define the compatibility
boundary. Required mappings include:

| Legacy input | Canonical result |
|---|---|
| `MegaTaiga` | `OldGrowthPineTaiga` |
| `MegaSpruceTaiga` | `OldGrowthSpruceTaiga` |
| `MushroomIsland`, `MushroomIslandShore` | `MushroomIslands` |
| `ColdTaiga` | `SnowyTaiga` |
| `LushCaves_underground`, `LushCaves_ocean` | `LushCaves` |
| `BambooJungle_ocean` | `BambooJungle` |

The other executable base aliases (for example `ExtremeHills`, `JungleM`,
`RoofedForest`, and `Savanna`) are included as well. Registered source suffixes
such as `_deep_ocean` and `_underground` resolve through their base name.
Aliases never appear in `canonical_ids()` and never create independent biome
entries. There is no guessed `MushroomFields` registration.

## Registry parity is not climate-layout parity

This slice completes registry and filter behavior only. Mineclonia selects
surface biomes with seven-parameter multi-noise extents and registers separate
surface and underground nodes (`biomes.lua:813-1572`). The small spatial values
stored here are source metadata needed to preserve identity; they are not a
selector.

`BiomeMap` intentionally has no `biome(x,y,z)`, noise channels, seed handling,
Voxey climate table, numeric-ID assignment, or `TerrainGenerator` edits. The
parent owns that integration and any engine-specific layout. Such a layout may
be deterministic and use these canonical IDs, but must be documented as a
Voxey adaptation rather than reproduction of Mineclonia's climate map or seeds.
In particular, reaching `LushCaves` requires a real 3D query; renaming a surface
biome or detecting an azalea is not equivalent.

`tests/biome_map_checks.gd` exercises exact IDs, all required aliases, unknown input behavior, climate fields, effective groups, taiga/old-growth and Bamboo/Jungle distinctions, LushCaves underground metadata, MushroomIslands structure exclusions, mountain groups, deep-ocean derivation, duplicate-free list expansion, and mutation isolation. The suite is registered in the lifecycle runner and passes 39 checks.
